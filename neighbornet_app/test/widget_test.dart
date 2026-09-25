import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neighbornet_app/main.dart';
import 'package:neighbornet_app/state/neighbornet_state.dart';

void main() {
  testWidgets('NeighborNet App UI smoke test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;

    final state = NeighborNetState();


    await tester.pumpWidget(NeighborNetApp(state: state));
    await tester.pump(const Duration(milliseconds: 200));

    // Verify presence of navigation elements
    expect(find.text('NeighborNet'), findsOneWidget);
    expect(find.text('CHANNELS'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Bulletin'), findsOneWidget);
    expect(find.text('Community Forms'), findsOneWidget);
    expect(find.text('Tactical Map'), findsOneWidget);
    expect(find.text('People & Nodes'), findsOneWidget);
    expect(find.text('Voice Chat'), findsOneWidget);
    expect(find.text('Walkie-Talkie (PTT)'), findsOneWidget);
    expect(find.text('Emergency Mode'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    // Switch to Bulletin view
    await tester.tap(find.text('Bulletin'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Community Bulletin Board'), findsOneWidget);

    // Switch to Community Forms view
    await tester.tap(find.text('Community Forms'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Community Forms & Micro-Apps'), findsOneWidget);

    // Switch to Tactical Map view
    await tester.tap(find.text('Tactical Map'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Tactical Mesh Map'), findsOneWidget);
    expect(find.text('Plot Marker'), findsOneWidget);

    // Switch to People & Nodes view
    await tester.tap(find.text('People & Nodes'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('People & Nodes'), findsNWidgets(2)); // Rail label + view header

    // Switch to Walkie-Talkie (PTT)
    await tester.tap(find.text('Walkie-Talkie (PTT)'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Tactical Walkie-Talkie (PTT)'), findsOneWidget);
    expect(find.text('SIMPLEX HALF-DUPLEX'), findsOneWidget);

    // Switch to Emergency Mode
    await tester.tap(find.text('Emergency Mode'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('EMERGENCY MODE ACTIVE'), findsOneWidget);

    // Switch to Settings view
    await tester.tap(find.text('Settings'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Node & Network Settings'), findsOneWidget);
    expect(find.text('Sovereign Profile & Tactical Identity'), findsOneWidget);

    // Scroll down to view LoRa & desktop settings
    await tester.drag(find.byType(ListView).first, const Offset(0, -600));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('LoRa Tactical Radio (KISS / RNode)'), findsOneWidget);

    await tester.drag(find.byType(ListView).first, const Offset(0, -800));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Desktop & System Tray Options'), findsOneWidget);
    expect(find.text('Minimize to System Tray'), findsOneWidget);
    expect(find.text('Minimize Just to Tray'), findsOneWidget);
    expect(find.text('Send to Tray When Closing (X)'), findsOneWidget);

    // Clean up
    state.dispose();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}


