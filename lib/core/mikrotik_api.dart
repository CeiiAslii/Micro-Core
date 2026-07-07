import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class MikrotikApi {
  final String host;
  final int port;
  final String username;
  final String password;
  bool isConnected = false;

  MikrotikApi({
    required this.host,
    required this.username,
    required this.password,
    this.port = 8728,
  });

  Future<bool> connect() async {
    try {
      await queryOrThrow([
        '/system/identity/print',
      ], timeout: const Duration(seconds: 10));
      isConnected = true;
      return true;
    } on TimeoutException {
      isConnected = false;
      throw Exception(
        'Port $host:$port terbuka, tapi RouterOS API tidak merespons. '
        'Jika host ini bisa dibuka lewat WinBox, tunnel kemungkinan diarahkan ke service WinBox 8291. '
        'Core Monitor membutuhkan tunnel ke RouterOS API 8728 atau API-SSL 8729.',
      );
    } on SocketException catch (e) {
      isConnected = false;
      throw Exception(
        'Tidak bisa membuka koneksi ke $host:$port (${e.message}).',
      );
    } catch (e) {
      isConnected = false;
      final message = _cleanError(e);
      if (_looksLikeLoginError(message)) {
        throw Exception('Login gagal: $message');
      }
      throw Exception('Gagal konek ke $host:$port: $message');
    }
  }

  bool _looksLikeLoginError(String message) {
    final lower = message.toLowerCase();
    return lower.contains('invalid user') ||
        lower.contains('invalid username') ||
        lower.contains('password') ||
        lower.contains('login gagal') ||
        lower.contains('not allowed');
  }

  String _cleanError(Object error) {
    return error
        .toString()
        .replaceFirst(RegExp(r'^Exception:\s*'), '')
        .replaceFirst(RegExp(r'^SocketException:\s*'), '')
        .trim();
  }

  Future<List<Map<String, String>>> query(
    List<String> command, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      return await queryOrThrow(command, timeout: timeout);
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, String>>> queryOrThrow(
    List<String> command, {
    Duration timeout = const Duration(seconds: 15),
  }) {
    return _runQuery(
      command,
      responseTimeout: timeout,
    ).timeout(timeout + const Duration(seconds: 2));
  }

  Future<List<Map<String, String>>> queryPageOrThrow(
    List<String> command, {
    required int offset,
    required int limit,
    Duration timeout = const Duration(seconds: 30),
  }) {
    return _runQuery(
      command,
      offset: offset,
      limit: limit,
      responseTimeout: timeout,
    ).timeout(timeout + const Duration(seconds: 2));
  }

  Future<List<Map<String, String>>> _runQuery(
    List<String> command, {
    int offset = 0,
    int? limit,
    Duration responseTimeout = const Duration(seconds: 12),
  }) async {
    Socket? socket;
    StreamIterator<Uint8List>? reader;
    try {
      socket = await _connectSocket();
      reader = StreamIterator<Uint8List>(socket);
      final words = _SocketWordReader(reader);

      await _sendPacket(socket, [
        '/login',
        '=name=$username',
        '=password=$password',
      ]);
      await _waitForDone(words, const Duration(seconds: 8));

      await _sendPacket(socket, command);
      return await _readAllResponse(
        words,
        responseTimeout,
        offset: offset,
        limit: limit,
      );
    } finally {
      await reader?.cancel();
      socket?.destroy();
    }
  }

  Future<Socket> _connectSocket() {
    const timeout = Duration(seconds: 8);
    if (port == 8729) {
      return SecureSocket.connect(
        host,
        port,
        timeout: timeout,
        onBadCertificate: (_) => true,
      );
    }
    return Socket.connect(host, port, timeout: timeout);
  }

  Future<void> _sendPacket(Socket socket, List<String> words) async {
    final data = <int>[];
    for (final word in words) {
      final bytes = utf8.encode(word);
      data
        ..addAll(_encLen(bytes.length))
        ..addAll(bytes);
    }
    data.add(0);
    socket.add(Uint8List.fromList(data));
    await socket.flush();
  }

  List<int> _encLen(int len) {
    if (len < 0x80) return [len];
    if (len < 0x4000) return [(len >> 8) | 0x80, len & 0xFF];
    if (len < 0x200000) {
      return [(len >> 16) | 0xC0, (len >> 8) & 0xFF, len & 0xFF];
    }
    return [
      (len >> 24) | 0xE0,
      (len >> 16) & 0xFF,
      (len >> 8) & 0xFF,
      len & 0xFF,
    ];
  }

  Future<void> _waitForDone(_SocketWordReader reader, Duration timeout) async {
    while (true) {
      final sentence = await reader.readSentence().timeout(timeout);
      if (sentence.isEmpty) continue;
      if (sentence.contains('!done')) return;
      if (sentence.first == '!trap' || sentence.first == '!fatal') {
        throw Exception(_errorMessage(sentence, 'Login gagal'));
      }
    }
  }

  Future<List<Map<String, String>>> _readAllResponse(
    _SocketWordReader reader,
    Duration timeout, {
    int offset = 0,
    int? limit,
  }) async {
    final results = <Map<String, String>>[];
    var rowIndex = 0;
    final deadline = DateTime.now().add(timeout);

    while (true) {
      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        throw TimeoutException('Query MikroTik timeout');
      }
      final sentence = await reader.readSentence().timeout(remaining);
      if (sentence.isEmpty) continue;
      final type = sentence.first;
      if (type == '!done') return results;
      if (type == '!trap' || type == '!fatal') {
        throw Exception(_errorMessage(sentence, 'Query MikroTik gagal'));
      }
      if (type != '!re') continue;

      final row = <String, String>{};
      for (final word in sentence.skip(1)) {
        if (!word.startsWith('=')) continue;
        final separator = word.indexOf('=', 1);
        if (separator != -1) {
          row[word.substring(1, separator)] = word.substring(separator + 1);
        }
      }
      if (rowIndex >= offset && (limit == null || results.length < limit)) {
        results.add(row);
      }
      rowIndex++;
    }
  }

  String _errorMessage(List<String> sentence, String fallback) {
    for (final word in sentence) {
      if (word.startsWith('=message=')) {
        return word.substring('=message='.length);
      }
    }
    return fallback;
  }

  void disconnect() {
    isConnected = false;
  }
}

class _SocketWordReader {
  final StreamIterator<Uint8List> _stream;
  Uint8List _chunk = Uint8List(0);
  int _position = 0;

  _SocketWordReader(this._stream);

  Future<int> _readByte() async {
    while (_position >= _chunk.length) {
      if (!await _stream.moveNext()) {
        throw const SocketException('Koneksi MikroTik terputus');
      }
      _chunk = _stream.current;
      _position = 0;
    }
    return _chunk[_position++];
  }

  Future<int> _readLength() async {
    final first = await _readByte();
    if (first < 0x80) return first;
    if (first < 0xC0) {
      return ((first & 0x3F) << 8) | await _readByte();
    }
    if (first < 0xE0) {
      return ((first & 0x1F) << 16) |
          ((await _readByte()) << 8) |
          await _readByte();
    }
    if (first < 0xF0) {
      return ((first & 0x0F) << 24) |
          ((await _readByte()) << 16) |
          ((await _readByte()) << 8) |
          await _readByte();
    }
    if (first == 0xF0) {
      return ((await _readByte()) << 24) |
          ((await _readByte()) << 16) |
          ((await _readByte()) << 8) |
          await _readByte();
    }
    throw const FormatException('Panjang paket MikroTik tidak valid');
  }

  Future<List<String>> readSentence() async {
    final sentence = <String>[];
    while (true) {
      final length = await _readLength();
      if (length == 0) return sentence;

      final bytes = Uint8List(length);
      for (var i = 0; i < length; i++) {
        bytes[i] = await _readByte();
      }
      sentence.add(utf8.decode(bytes, allowMalformed: true));
    }
  }
}
