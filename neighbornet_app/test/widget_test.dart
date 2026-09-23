import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neighbornet_app/main.dart';
import 'package:neighbornet_app/state/neighbornet_state.dart';

void main() {
  testWidgets('NeighborNet App UI smoke test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;

    final tempDir = Directory.systemTemp.createTempSync('neighbornet_ui_test_');
    final state = NeighborNetState();
    await state.initialize(port: 46002);

    await tester.pumpWidget(NeighborNetApp(state: state));
    await tester.pump(const Duration(milliseconds: 200));

    // Verify presence of navigation elements
    expect(find.text('NeighborNet'), findsOneWidget);
    expect(find.text('CHANNELS'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Bulletin'), findsOneWidget);
    expect(find.text('People & Nodes'), findsOneWidget);
    expect(find.text('Emergency Mode'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    // Switch to Bulletin view
    await tester.tap(find.text('Bulletin'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Community Bulletin Board'), findsOneWidget);

    // Switch to People & Nodes view
    await tester.tap(find.text('People & Nodes'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('People & Nodes'), findsNWidgets(2)); // Rail label + view header

    // Switch to Emergency Mode
    await tester.tap(find.text('Emergency Mode'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('EMERGENCY MODE ACTIVE'), findsOneWidget);

    // Switch to Settings view
    await tester.tap(find.text('Settings'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Node & Network Settings'), findsOneWidget);

    // Clean up
    state.dispose();
    tempDir.deleteSync(recursive: true);
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
