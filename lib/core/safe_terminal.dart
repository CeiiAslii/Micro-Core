class TerminalCommand {
  final String input;
  final List<String> apiWords;
  final bool writesData;
  final bool critical;

  const TerminalCommand({
    required this.input,
    required this.apiWords,
    this.writesData = false,
    this.critical = false,
  });
}

class SafeTerminalParser {
  static const _writeActions = {
    'add',
    'set',
    'remove',
    'enable',
    'disable',
    'move',
    'unset',
    'reset',
    'reset-counters',
    'reset-traffic',
    'reboot',
    'shutdown',
    'undo',
    'redo',
    'import',
    'export',
    'run',
    'execute',
    'start',
    'stop',
    'release',
    'renew',
    'make-static',
    'install',
    'uninstall',
    'upgrade',
    'downgrade',
    'make-supout',
    'generate-key',
  };

  static const _readActions = {
    'print',
    'get',
    'find',
    'monitor',
    'monitor-traffic',
    'check-for-updates',
  };
  static const _criticalActions = {
    'reset',
    'reboot',
    'shutdown',
    'import',
    'install',
    'uninstall',
    'upgrade',
    'downgrade',
  };

  const SafeTerminalParser();

  TerminalCommand parse(String rawInput) {
    final input = rawInput.trim();
    if (input.isEmpty) {
      throw const FormatException('Perintah tidak boleh kosong');
    }
    if (input.contains(';') || input.contains('\n') || input.contains('\r')) {
      throw const FormatException('Hanya satu perintah yang boleh dijalankan');
    }

    final tokens = _expandPathTokens(_tokenize(input));
    if (tokens.isEmpty) {
      throw const FormatException('Perintah tidak valid');
    }

    final normalized = tokens
        .map((token) => token.replaceFirst(RegExp(r'^/+'), ''))
        .where((token) => token.isNotEmpty)
        .toList();
    final lower = normalized.map((token) => token.toLowerCase()).toList();

    if (lower.first == 'ping' ||
        lower.first == 'tool/ping' ||
        (lower.first == 'tool' && lower.length > 1 && lower[1] == 'ping')) {
      final skip = lower.first == 'tool' ? 2 : 1;
      return TerminalCommand(
        input: input,
        apiWords: _networkTool(
          '/ping',
          normalized.skip(skip).toList(),
          'address',
        ),
      );
    }
    if (lower.first == 'tool' && lower.length > 1 && lower[1] == 'traceroute') {
      return TerminalCommand(
        input: input,
        apiWords: _networkTool(
          '/tool/traceroute',
          normalized.skip(2).toList(),
          'address',
        ),
      );
    }
    if (lower.first == 'resolve') {
      return TerminalCommand(
        input: input,
        apiWords: _networkTool(
          '/resolve',
          normalized.skip(1).toList(),
          'domain-name',
        ),
      );
    }

    final actionIndex = lower.indexWhere(
      (word) => _readActions.contains(word) || _writeActions.contains(word),
    );
    if (actionIndex <= 0) {
      throw const FormatException(
        'Action RouterOS tidak dikenali. Contoh: print, add, set, remove, enable, disable, atau reboot',
      );
    }

    final action = lower[actionIndex];
    final writesData = _writeActions.contains(action);
    final path =
        '/${normalized.take(actionIndex).join('/')}'
        '/${normalized[actionIndex]}';
    final arguments = _normalizeArguments(
      normalized.skip(actionIndex + 1).toList(),
    );
    return TerminalCommand(
      input: input,
      apiWords: [path, ...arguments.map(_argument)],
      writesData: writesData,
      critical: _criticalActions.contains(action),
    );
  }

  List<String> _networkTool(
    String path,
    List<String> arguments,
    String positionalName,
  ) {
    final words = <String>[path];
    var positionalUsed = false;
    for (final argument in arguments) {
      if (!argument.contains('=') && !argument.startsWith('?')) {
        if (positionalUsed) {
          throw const FormatException('Argumen posisi terlalu banyak');
        }
        words.add('=$positionalName=$argument');
        positionalUsed = true;
      } else {
        words.add(_argument(argument));
      }
    }
    if (!positionalUsed &&
        !words.any((word) => word.startsWith('=$positionalName='))) {
      throw FormatException('$positionalName wajib diisi');
    }
    return words;
  }

  String _argument(String token) {
    if (token.startsWith('?')) return token;
    if (token.startsWith('=')) return token;
    final separator = token.indexOf('=');
    if (separator <= 0) {
      if (token == 'once') return '=once=';
      throw FormatException('Argumen "$token" harus memakai key=value');
    }
    return '=$token';
  }

  List<String> _normalizeArguments(List<String> arguments) {
    final result = <String>[];
    var whereMode = false;
    for (final argument in arguments) {
      if (argument.toLowerCase() == 'where') {
        whereMode = true;
        continue;
      }
      if (whereMode && !argument.startsWith('?')) {
        result.add('?$argument');
      } else {
        result.add(argument);
      }
    }
    return result;
  }

  List<String> _expandPathTokens(List<String> tokens) {
    if (tokens.isEmpty) return tokens;
    final expanded = <String>[];
    var actionFound = false;
    for (final token in tokens) {
      if (!actionFound && token.contains('/')) {
        final parts = token.split('/').where((part) => part.isNotEmpty);
        for (final part in parts) {
          expanded.add(part);
          if (_readActions.contains(part.toLowerCase()) ||
              _writeActions.contains(part.toLowerCase())) {
            actionFound = true;
          }
        }
      } else {
        expanded.add(token);
      }
      if (_readActions.contains(token.toLowerCase()) ||
          _writeActions.contains(token.toLowerCase())) {
        actionFound = true;
      }
    }
    return expanded;
  }

  List<String> _tokenize(String input) {
    final tokens = <String>[];
    final buffer = StringBuffer();
    String? quote;

    for (var i = 0; i < input.length; i++) {
      final char = input[i];
      if (quote != null) {
        if (char == quote) {
          quote = null;
        } else if (char == r'\' && i + 1 < input.length) {
          i++;
          buffer.write(input[i]);
        } else {
          buffer.write(char);
        }
        continue;
      }
      if (char == '"' || char == "'") {
        quote = char;
      } else if (char.trim().isEmpty) {
        if (buffer.isNotEmpty) {
          tokens.add(buffer.toString());
          buffer.clear();
        }
      } else {
        buffer.write(char);
      }
    }
    if (quote != null) throw const FormatException('Tanda kutip belum ditutup');
    if (buffer.isNotEmpty) tokens.add(buffer.toString());
    return tokens;
  }
}

String formatTerminalRows(List<Map<String, String>> rows) {
  if (rows.isEmpty) return 'done (tidak ada data)';
  final output = StringBuffer();
  for (var index = 0; index < rows.length; index++) {
    if (index > 0) output.writeln();
    output.writeln('[${index + 1}]');
    for (final entry in rows[index].entries) {
      output.writeln('${entry.key}: ${entry.value}');
    }
  }
  return output.toString().trimRight();
}
