import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';

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
      await _runQuery(['/system/identity/print']);
      isConnected = true;
      return true;
    } catch (e) {
      isConnected = false;
      throw Exception('Gagal konek: $e');
    }
  }

  Future<List<Map<String, String>>> query(List<String> command) async {
    try {
      return await _runQuery(command);
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, String>>> _runQuery(List<String> command) async {
    Socket? socket;
    final buffer = <int>[];
    try {
      socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 8),
      );
      socket.listen((data) => buffer.addAll(data));

      await _send(socket, ['/login', '=name=$username', '=password=$password']);
      await _waitDone(buffer, socket);
      await _send(socket, command);
      return await _readAll(buffer, socket);
    } finally {
      socket?.destroy();
    }
  }

  Future<void> _send(Socket socket, List<String> words) async {
    final data = <int>[];
    for (final w in words) {
      final bytes = utf8.encode(w);
      data.addAll(_encLen(bytes.length));
      data.addAll(bytes);
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

  Future<int> _readByte(List<int> buf, Socket socket) async {
    final deadline = DateTime.now().add(const Duration(seconds: 8));
    while (buf.isEmpty) {
      if (DateTime.now().isAfter(deadline)) throw Exception('Timeout');
      await Future.delayed(const Duration(milliseconds: 5));
    }
    return buf.removeAt(0);
  }

  Future<int> _readLen(List<int> buf, Socket socket) async {
    int b = await _readByte(buf, socket);
    if (b < 0x80) return b;
    if (b < 0xC0) {
      int b2 = await _readByte(buf, socket);
      return ((b & 0x3F) << 8) | b2;
    }
    if (b < 0xE0) {
      int b2 = await _readByte(buf, socket);
      int b3 = await _readByte(buf, socket);
      return ((b & 0x1F) << 16) | (b2 << 8) | b3;
    }
    int b2 = await _readByte(buf, socket);
    int b3 = await _readByte(buf, socket);
    int b4 = await _readByte(buf, socket);
    return ((b & 0x0F) << 24) | (b2 << 16) | (b3 << 8) | b4;
  }

  Future<String> _readWord(List<int> buf, Socket socket) async {
    final len = await _readLen(buf, socket);
    if (len == 0) return '';
    final bytes = <int>[];
    for (int i = 0; i < len; i++) {
      bytes.add(await _readByte(buf, socket));
    }
    return utf8.decode(bytes);
  }

  Future<List<String>> _readSentence(List<int> buf, Socket socket) async {
    final words = <String>[];
    while (true) {
      final w = await _readWord(buf, socket);
      if (w.isEmpty) break;
      words.add(w);
    }
    return words;
  }

  Future<void> _waitDone(List<int> buf, Socket socket) async {
    while (true) {
      final s = await _readSentence(buf, socket);
      if (s.contains('!done')) break;
      if (s.any((w) => w == '!trap' || w == '!fatal')) {
        throw Exception('Login gagal');
      }
    }
  }

  Future<List<Map<String, String>>> _readAll(
    List<int> buf,
    Socket socket,
  ) async {
    final results = <Map<String, String>>[];
    Map<String, String> current = {};
    while (true) {
      final sentence = await _readSentence(buf, socket);
      if (sentence.isEmpty) continue;
      final type = sentence[0];
      if (type == '!done') {
        if (current.isNotEmpty) results.add(current);
        break;
      }
      if (type == '!trap' || type == '!fatal') break;
      if (type == '!re') {
        if (current.isNotEmpty) results.add(current);
        current = {};
        for (int i = 1; i < sentence.length; i++) {
          final word = sentence[i];
          if (word.startsWith('=')) {
            final idx = word.indexOf('=', 1);
            if (idx != -1) {
              current[word.substring(1, idx)] = word.substring(idx + 1);
            }
          }
        }
      }
    }
    return results;
  }

  void disconnect() => isConnected = false;
}
