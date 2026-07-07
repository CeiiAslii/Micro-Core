import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no empty Dart feature files remain in lib', () {
    final emptyFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart') && file.lengthSync() == 0)
        .map((file) => file.path)
        .toList();

    expect(emptyFiles, isEmpty);
  });

  test('literal RouterOS write commands use queryOrThrow', () {
    final riskyCalls = <String>[];
    final writeCommand = RegExp(
      r'''await\s+(?:widget\.)?api\.query\(\s*\[\s*['"][^'"]+/(?:add|set|remove|enable|disable|export|save|run|reset-counters)['"]''',
      multiLine: true,
    );

    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final content = file.readAsStringSync();
      for (final match in writeCommand.allMatches(content)) {
        riskyCalls.add('${file.path}: ${match.group(0)}');
      }
    }

    expect(riskyCalls, isEmpty);
  });
}
