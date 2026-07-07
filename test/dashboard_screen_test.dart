import 'package:core_monitor/core/mikrotik_api.dart';
import 'package:core_monitor/providers/app_provider.dart';
import 'package:core_monitor/screens/dashboard/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _FakeMikrotikApi extends MikrotikApi {
  _FakeMikrotikApi()
    : super(host: '127.0.0.1', username: 'admin', password: 'test');

  @override
  Future<List<Map<String, String>>> queryOrThrow(
    List<String> command, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    return switch (command.first) {
      '/system/identity/print' => [
        {'name': 'Router Test'},
      ],
      '/system/resource/print' => [
        {
          'board-name': 'RB5009',
          'version': '7.20',
          'platform': 'MikroTik',
          'uptime': '1d2h3m',
          'cpu-load': '12',
          'total-memory': '1000',
          'free-memory': '700',
        },
      ],
      '/system/health/print' => [
        {'name': 'temperature', 'value': '42'},
      ],
      '/interface/print' => [
        {'name': 'ether1', 'disabled': 'false'},
      ],
      '/interface/monitor-traffic' => [
        {'rx-bits-per-second': '1200000', 'tx-bits-per-second': '450000'},
      ],
      '/ip/hotspot/active/print' => [
        {'user': 'hotspot-user'},
      ],
      '/ppp/active/print' => [
        {'name': 'pppoe-user'},
      ],
      '/ip/dhcp-server/lease/print' => [
        {'status': 'bound'},
      ],
      _ => [],
    };
  }
}

void main() {
  testWidgets('dashboard renders router data without Flutter errors', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppProvider(),
        child: MaterialApp(
          home: Scaffold(
            body: DashboardScreen(
              api: _FakeMikrotikApi(),
              onOpenInterface: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Router Test'), findsWidgets);
    expect(find.text('1'), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });
}
