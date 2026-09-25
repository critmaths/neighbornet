import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neighbornet_app/models/neighbornet_models.dart';
import 'package:neighbornet_app/state/neighbornet_state.dart';
import 'package:neighbornet_app/views/tactical_map_view.dart';
import 'package:provider/provider.dart';

void main() {
  group('Tactical Map & Community Markers Tests', () {
    test('TacticalMarker serialization and deserialization', () {
      final marker = TacticalMarker(
        id: 'marker-1234',
        title: 'Safe Evacuation Point',
        category: 'shelter',
        description: 'Underground reinforced shelter with solar battery bank.',
        lat: 34.0522,
        lon: -118.2437,
        authorHash: 'abc1234567890',
        authorNickname: 'Sgt_Miller',
        authorCallsign: 'STRIKE-1',
        timestampSec: 1700000000,
        isActive: true,
      );

      final json = marker.toJson();
      expect(json['id'], 'marker-1234');
      expect(json['category'], 'shelter');
      expect(json['lat'], 34.0522);

      final rehydrated = TacticalMarker.fromJson(json);
      expect(rehydrated.id, marker.id);
      expect(rehydrated.title, marker.title);
      expect(rehydrated.category, 'shelter');
      expect(rehydrated.authorCallsign, 'STRIKE-1');
      expect(rehydrated.isActive, true);
    });

    testWidgets('TacticalMapView renders grid, filters, and plot marker button',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;

      final state = NeighborNetState();

      await tester.pumpWidget(
        ChangeNotifierProvider<NeighborNetState>.value(
          value: state,
          child: const MaterialApp(
            home: TacticalMapView(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Tactical Mesh Map'), findsOneWidget);
      expect(find.text('Plot Marker'), findsOneWidget);
      expect(find.text('All Markers'), findsOneWidget);
      expect(find.text('Medical'), findsOneWidget);
      expect(find.text('Water'), findsOneWidget);
      expect(find.text('Shelter'), findsOneWidget);
      expect(find.text('Hazards'), findsOneWidget);
      expect(find.text('Checkpoints'), findsOneWidget);
      expect(find.text('Mesh Relays'), findsOneWidget);
      expect(find.text('SOS Beacons'), findsOneWidget);

      // Open Plot Marker Dialog
      await tester.tap(find.text('Plot Marker'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Plot Community Marker'), findsOneWidget);
      expect(find.text('Marker Category'), findsOneWidget);
      expect(find.text('Location / Title'), findsOneWidget);
      expect(find.text('Broadcast Marker'), findsOneWidget);

      // Cancel dialog
      await tester.tap(find.text('Cancel'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Plot Community Marker'), findsNothing);

      state.dispose();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });
}
