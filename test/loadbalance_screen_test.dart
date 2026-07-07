import 'package:core_monitor/core/mikrotik_api.dart';
import 'package:core_monitor/providers/app_provider.dart';
import 'package:core_monitor/screens/loadbalance/loadbalance_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _LoadBalanceApi extends MikrotikApi {
  final commands = <List<String>>[];

  _LoadBalanceApi()
    : super(host: '127.0.0.1', username: 'admin', password: 'test');

  @override
  Future<List<Map<String, String>>> query(
    List<String> command, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (command.first == '/interface/print') {
      return [
        {'name': 'ether1 WAN', 'type': 'ether'},
        {'name': 'ether2 WAN', 'type': 'ether'},
        {'name': 'bridge LAN', 'type': 'ether'},
      ];
    }
    if (command.first == '/routing/table/print') return const [];
    return const [];
  }

  @override
  Future<List<Map<String, String>>> queryOrThrow(
    List<String> command, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    commands.add(command);
    return [
      {'status': 'ok'},
    ];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<_LoadBalanceApi> pumpScreen(WidgetTester tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = _LoadBalanceApi();
    final provider = AppProvider()
      ..setApi(api)
      ..setRouterInfo(name: 'Router', model: 'RB', version: '7');

    await tester.pumpWidget(
      ChangeNotifierProvider<AppProvider>.value(
        value: provider,
        child: MaterialApp(
          home: Scaffold(body: LoadBalanceScreen(api: api)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return api;
  }

  Future<void> selectDropdown(
    WidgetTester tester,
    int dropdownIndex,
    String value,
  ) async {
    await tester.tap(find.byType(DropdownButton<String>).at(dropdownIndex));
    await tester.pumpAndSettle();
    await tester.tap(find.text(value).last);
    await tester.pumpAndSettle();
  }

  testWidgets('PCC applies routes, mangle rules, and NAT with gateway params', (
    tester,
  ) async {
    final api = await pumpScreen(tester);

    await selectDropdown(tester, 0, 'ether1 WAN');
    await tester.enterText(find.byType(TextField).at(0), '10.0.0.1');
    await selectDropdown(tester, 1, 'ether2 WAN');
    await tester.enterText(find.byType(TextField).at(1), '20.0.0.1');
    await selectDropdown(tester, 2, 'bridge LAN');
    await tester.tap(find.text('Apply PCC Load Balance'));
    await tester.pumpAndSettle();

    expect(
      api.commands.where((command) => command.first == '/routing/table/add'),
      hasLength(2),
    );
    expect(
      api.commands.where((command) => command.first == '/ip/route/add'),
      hasLength(2),
    );
    expect(
      api.commands.where(
        (command) => command.first == '/ip/firewall/mangle/add',
      ),
      hasLength(4),
    );
    expect(
      api.commands.where((command) => command.first == '/ip/firewall/nat/add'),
      hasLength(2),
    );
    expect(
      api.commands.expand((command) => command),
      contains('=gateway=10.0.0.1'),
    );
    expect(
      api.commands.expand((command) => command),
      contains('=gateway=20.0.0.1'),
    );
    expect(
      api.commands.expand((command) => command),
      contains('=per-connection-classifier=both-addresses:2/0'),
    );
  });
}
