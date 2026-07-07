import 'dart:convert';

import 'package:core_monitor/providers/app_provider.dart';
import 'package:core_monitor/screens/login_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('add-router form hides saved routers and keeps fields minimal', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({
      'savedRouters': jsonEncode([
        {
          'id': 'router-1',
          'name': 'SERVER 1',
          'host': '10.142.167.165',
          'username': 'admin',
          'password': 'secret',
          'lastConnected': '2026-06-16T00:00:00.000',
        },
      ]),
    });

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppProvider(),
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('SERVER 1'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Tambah Router Baru'), findsOneWidget);
    expect(find.text('SERVER 1'), findsNothing);
    expect(find.text('Contoh: Router Kantor'), findsOneWidget);
    expect(find.text('192.168.1.1 atau api-tunnel:port'), findsNothing);
    expect(find.text('admin'), findsNothing);
  });
}
