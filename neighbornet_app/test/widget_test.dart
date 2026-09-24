import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neighbornet_app/main.dart';
import 'package:neighbornet_app/state/neighbornet_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('NeighborNet App UI smoke test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;

    final state = NeighborNetState();

    await tester.pumpWidget(NeighborNetApp(state: state));
    await tester.pump(const Duration(milliseconds: 200));

    // Verify presence of navigation elements
    expect(find.text('NeighborNet'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Bulletin'), findsOneWidget);
    expect(find.text('People & Nodes'), findsOneWidget);
    expect(find.text('Voice Chat'), findsOneWidget);
    expect(find.text('Survival Manual'), findsOneWidget);
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

    // Switch to Survival Manual view
    await tester.tap(find.text('Survival Manual'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Civic & Collapse Survival Field Manual'), findsOneWidget);

    // Switch to Emergency Mode
    await tester.tap(find.text('Emergency Mode'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('EMERGENCY MODE ACTIVE'), findsOneWidget);

    // Switch to Settings view
    await tester.tap(find.text('Settings'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Node & Network Settings'), findsOneWidget);
    expect(find.text('Tactical Visual Profile'), findsOneWidget);

    // Scroll down in Settings
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Duress Protocol / Panic Wipe'), findsOneWidget);
    expect(find.text('EXECUTE PANIC WIPE'), findsOneWidget);

    // Clean up
    state.dispose();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
