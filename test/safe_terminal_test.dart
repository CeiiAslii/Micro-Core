import 'package:core_monitor/core/safe_terminal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = SafeTerminalParser();

  test('parses RouterOS CLI-style print command', () {
    final command = parser.parse('/ip address print ?interface=ether1');

    expect(command.apiWords, ['/ip/address/print', '?interface=ether1']);
  });

  test('accepts slash path, no leading slash, and where syntax', () {
    expect(parser.parse('/system/resource/print').apiWords, [
      '/system/resource/print',
    ]);
    expect(parser.parse('system identity print').apiWords, [
      '/system/identity/print',
    ]);
    expect(parser.parse('/interface print where running=true').apiWords, [
      '/interface/print',
      '?running=true',
    ]);
  });

  test('parses ping with positional address', () {
    final command = parser.parse('/ping 8.8.8.8 count=4');

    expect(command.apiWords, ['/ping', '=address=8.8.8.8', '=count=4']);
  });

  test('full access parses write and critical commands', () {
    final add = parser.parse(
      '/ip firewall filter add chain=input action=accept',
    );
    final reboot = parser.parse('/system reboot');
    final move = parser.parse(
      '/ip firewall filter move numbers=1 destination=0',
    );

    expect(add.apiWords, [
      '/ip/firewall/filter/add',
      '=chain=input',
      '=action=accept',
    ]);
    expect(add.writesData, isTrue);
    expect(add.critical, isFalse);
    expect(reboot.apiWords, ['/system/reboot']);
    expect(reboot.critical, isTrue);
    expect(move.apiWords, [
      '/ip/firewall/filter/move',
      '=numbers=1',
      '=destination=0',
    ]);
  });

  test('formats response rows for terminal output', () {
    expect(
      formatTerminalRows([
        {'name': 'router', 'version': '7.20'},
      ]),
      '[1]\nname: router\nversion: 7.20',
    );
  });
}
