import 'package:core_monitor/core/mikrotik_api.dart';
import 'package:core_monitor/core/router_alert_monitor.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _AlertApi extends MikrotikApi {
  final int cpuLoad;

  _AlertApi({this.cpuLoad = 10})
    : super(host: '127.0.0.1', username: 'admin', password: 'test');

  @override
  Future<List<Map<String, String>>> queryOrThrow(
    List<String> command, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    return switch (command.first) {
      '/system/resource/print' => [
        {
          'cpu-load': '$cpuLoad',
          'total-memory': '1000',
          'free-memory': '800',
          'total-hdd-space': '1000',
          'free-hdd-space': '900',
        },
      ],
      '/interface/print' => [
        {
          'name': 'ether1',
          'type': 'ether',
          'running': 'true',
          'disabled': 'false',
        },
      ],
      _ => const [],
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('core_monitor/downloads');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('starts without a native notification plugin', () async {
    final monitor = RouterAlertMonitor(_AlertApi());
    await monitor.start();
    monitor.dispose();
  });

  test('sends notification when CPU is high', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return true;
        });

    final monitor = RouterAlertMonitor(_AlertApi(cpuLoad: 90));
    await monitor.start();
    await monitor.check();
    monitor.dispose();

    expect(
      calls.where((call) => call.method == 'showNotification'),
      hasLength(1),
    );
  });
}
