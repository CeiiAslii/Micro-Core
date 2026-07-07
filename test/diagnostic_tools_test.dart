import 'package:core_monitor/core/mikrotik_api.dart';
import 'package:core_monitor/providers/app_provider.dart';
import 'package:core_monitor/screens/tools/diagnostic_tools_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _DiagnosticApi extends MikrotikApi {
  final commands = <List<String>>[];

  _DiagnosticApi()
    : super(host: '127.0.0.1', username: 'admin', password: 'test');

  @override
  Future<List<Map<String, String>>> queryOrThrow(
    List<String> command, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    commands.add(command);
    return [
      {'address': '8.8.8.8', 'status': 'ok'},
    ];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<_DiagnosticApi> pumpScreen(WidgetTester tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    final api = _DiagnosticApi();
    final provider = AppProvider()
      ..setApi(api)
      ..setRouterInfo(name: 'Router', model: 'RB', version: '7');

    await tester.pumpWidget(
      ChangeNotifierProvider<AppProvider>.value(
        value: provider,
        child: MaterialApp(
          home: Scaffold(body: DiagnosticToolsScreen(api: api)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return api;
  }

  testWidgets('runs ping with address and count parameters', (tester) async {
    final api = await pumpScreen(tester);

    await tester.tap(find.text('Jalankan'));
    await tester.pumpAndSettle();

    expect(api.commands.single, ['/ping', '=address=8.8.8.8', '=count=5']);
  });

  testWidgets('runs DNS resolve with domain-name parameter', (tester) async {
    final api = await pumpScreen(tester);

    await tester.tap(find.text('DNS Resolve'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jalankan'));
    await tester.pumpAndSettle();

    expect(api.commands.single, ['/resolve', '=domain-name=google.com']);
  });

  testWidgets('requires interface before running IP Scan', (tester) async {
    final api = await pumpScreen(tester);

    await tester.tap(find.text('IP Scan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jalankan'));
    await tester.pumpAndSettle();

    expect(api.commands, isEmpty);
    expect(find.text('Interface wajib diisi'), findsOneWidget);
  });
}
