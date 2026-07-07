import 'package:core_monitor/widgets/router_choice_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('selects a RouterOS option', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RouterChoiceField(
            controller: controller,
            label: 'Chain',
            options: const ['input', 'forward', 'output'],
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.arrow_drop_down_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('forward'));
    await tester.pumpAndSettle();

    expect(controller.text, 'forward');
  });

  testWidgets('supports multiple RouterOS values', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RouterChoiceField(
            controller: controller,
            label: 'Connection State',
            options: const ['established', 'related', 'new'],
            multiSelect: true,
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.arrow_drop_down_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('established'));
    await tester.tap(find.text('related'));
    await tester.tap(find.text('Selesai'));
    await tester.pumpAndSettle();

    expect(controller.text, 'established,related');
  });

  testWidgets('selection-only field cannot be typed manually', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RouterChoiceField(
            controller: controller,
            label: 'Interface',
            options: const ['ether1', 'ether2'],
            allowCustom: false,
          ),
        ),
      ),
    );

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.readOnly, isTrue);

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ether2'));
    await tester.pumpAndSettle();

    expect(controller.text, 'ether2');
  });
}
