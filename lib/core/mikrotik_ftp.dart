import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class MikrotikFtp {
  final String host;
  final String username;
  final String password;
  final int port;

  MikrotikFtp({
    required this.host,
    required this.username,
    required this.password,
    this.port = 21,
  });

  Future<Uint8List> download(String remotePath) async {
    final session = await _connect();
    try {
      final dataSocket = await session.openPassiveDataSocket();
      await session.command(
        'RETR ${_quotePath(remotePath)}',
        expected: {125, 150},
      );
      final bytes = <int>[];
      await dataSocket.listen(bytes.addAll).asFuture<void>();
      await session.readReply(expected: {226, 250});
      return Uint8List.fromList(bytes);
    } finally {
      await session.close();
    }
  }

  Future<void> upload(String remotePath, Uint8List bytes) async {
    final session = await _connect();
    try {
      final dataSocket = await session.openPassiveDataSocket();
      await session.command(
        'STOR ${_quotePath(remotePath)}',
        expected: {125, 150},
      );
      dataSocket.add(bytes);
      await dataSocket.flush();
      await dataSocket.close();
      await session.readReply(expected: {226, 250});
    } finally {
      await session.close();
    }
  }

  Future<void> createDirectory(String remotePath) async {
    final session = await _connect();
    try {
      await session.command(
        'MKD ${_quotePath(remotePath)}',
        expected: {250, 257},
      );
    } finally {
      await session.close();
    }
  }

  Future<_FtpSession> _connect() async {
    final socket = await Socket.connect(
      host,
      port,
      timeout: const Duration(seconds: 10),
    );
    final session = _FtpSession(socket);
    try {
      await session.readReply(expected: {220});
      final userReply = await session.command(
        'USER $username',
        expected: {230, 331},
      );
      if (userReply.code == 331) {
        await session.command('PASS $password', expected: {230});
      }
      await session.command('TYPE I', expected: {200});
      return session;
    } catch (_) {
      await session.close();
      rethrow;
    }
  }

  String _quotePath(String path) {
    if (path.contains('\r') || path.contains('\n')) {
      throw ArgumentError('Path FTP tidak valid.');
    }
    return path;
  }
}

class _FtpSession {
  final Socket socket;
  final StreamIterator<String> _lines;

  _FtpSession(this.socket)
    : _lines = StreamIterator(
        socket
            .cast<List<int>>()
            .transform(utf8.decoder)
            .transform(const LineSplitter()),
      );

  Future<_FtpReply> command(
    String command, {
    required Set<int> expected,
  }) async {
    socket.write('$command\r\n');
    await socket.flush();
    return readReply(expected: expected);
  }

  Future<_FtpReply> readReply({required Set<int> expected}) async {
    if (!await _lines.moveNext()) {
      throw const SocketException('Koneksi FTP ditutup MikroTik.');
    }
    final first = _lines.current;
    if (first.length < 3) {
      throw FormatException('Respons FTP tidak valid: $first');
    }
    final code = int.tryParse(first.substring(0, 3));
    if (code == null) {
      throw FormatException('Respons FTP tidak valid: $first');
    }

    final messages = <String>[first];
    if (first.length > 3 && first[3] == '-') {
      final endPrefix = '$code ';
      while (await _lines.moveNext()) {
        final line = _lines.current;
        messages.add(line);
        if (line.startsWith(endPrefix)) break;
      }
    }

    final reply = _FtpReply(code, messages.join('\n'));
    if (!expected.contains(code)) {
      throw Exception('FTP $code: ${reply.message}');
    }
    return reply;
  }

  Future<Socket> openPassiveDataSocket() async {
    int? dataPort;
    try {
      final epsv = await command('EPSV', expected: {229});
      final match = RegExp(r'\(\|\|\|(\d+)\|\)').firstMatch(epsv.message);
      dataPort = int.tryParse(match?.group(1) ?? '');
    } catch (_) {
      final pasv = await command('PASV', expected: {227});
      final match = RegExp(
        r'\((\d+),(\d+),(\d+),(\d+),(\d+),(\d+)\)',
      ).firstMatch(pasv.message);
      final high = int.tryParse(match?.group(5) ?? '');
      final low = int.tryParse(match?.group(6) ?? '');
      if (high != null && low != null) {
        dataPort = (high * 256) + low;
      }
    }
    if (dataPort == null) {
      throw const FormatException('Port pasif FTP tidak ditemukan.');
    }
    return Socket.connect(
      socket.remoteAddress,
      dataPort,
      timeout: const Duration(seconds: 10),
    );
  }

  Future<void> close() async {
    try {
      socket.write('QUIT\r\n');
      await socket.flush();
    } catch (_) {}
    socket.destroy();
    await _lines.cancel();
  }
}

class _FtpReply {
  final int code;
  final String message;
  const _FtpReply(this.code, this.message);
}
