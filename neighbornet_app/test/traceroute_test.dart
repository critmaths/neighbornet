import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neighbornet_app/models/neighbornet_models.dart';
import 'package:neighbornet_app/state/neighbornet_state.dart';
import 'package:neighbornet_app/views/traceroute_view.dart';
import 'package:provider/provider.dart';

void main() {
  group('Traceroute Model & Serialization Tests', () {
    test('TraceHop JSON serialization roundtrip', () {
      final hop = TraceHop(
        nodeHash: 'aabbcc112233',
        nickname: 'Relay-Ridge-01',
        callsign: 'W7-RLY',
        interfaceType: 'LoRa-915MHz',
        rssiDbm: -74,
        snrDb: 9.4,
        timestampMs: 1727200000000,
        deltaMs: 18,
      );

      final json = hop.toJson();
      expect(json['node_hash'], 'aabbcc112233');
      expect(json['nickname'], 'Relay-Ridge-01');
      expect(json['callsign'], 'W7-RLY');
      expect(json['interface_type'], 'LoRa-915MHz');
      expect(json['rssi_dbm'], -74);
      expect(json['snr_db'], 9.4);
      expect(json['delta_ms'], 18);

      final deserialized = TraceHop.fromJson(json);
      expect(deserialized.nodeHash, hop.nodeHash);
      expect(deserialized.nickname, hop.nickname);
      expect(deserialized.callsign, hop.callsign);
      expect(deserialized.interfaceType, hop.interfaceType);
      expect(deserialized.rssiDbm, -74);
      expect(deserialized.snrDb, 9.4);
      expect(deserialized.deltaMs, 18);
    });

    test('TracerouteSession JSON serialization roundtrip', () {
      final hop0 = TraceHop(
        nodeHash: 'origin001',
        nickname: 'Host-Local',
        callsign: 'K7-HST',
        interfaceType: 'Local Host',
        timestampMs: 1727200000000,
        deltaMs: 0,
      );

      final hop1 = TraceHop(
        nodeHash: 'relay002',
        nickname: 'Relay-01',
        callsign: 'W7-01',
        interfaceType: 'UDP/LAN',
        rssiDbm: -62,
        snrDb: 11.0,
        timestampMs: 1727200000020,
        deltaMs: 20,
      );

      final session = TracerouteSession(
        traceId: 'trace-test-888',
        originHash: 'origin001',
        originNickname: 'Host-Local',
        originCallsign: 'K7-HST',
        targetHash: 'relay002',
        targetNickname: 'Relay-01',
        ttl: 7,
        maxTtl: 8,
        hops: [hop0, hop1],
        status: 'reached_destination',
        createdAtMs: 1727200000000,
        completedAtMs: 1727200000020,
        totalRttMs: 20,
      );

      final json = session.toJson();
      expect(json['trace_id'], 'trace-test-888');
      expect(json['status'], 'reached_destination');
      expect(json['hops'].length, 2);
      expect(json['total_rtt_ms'], 20);

      final deserialized = TracerouteSession.fromJson(json);
      expect(deserialized.traceId, session.traceId);
      expect(deserialized.isSuccess, true);
      expect(deserialized.isCompleted, true);
      expect(deserialized.hops.length, 2);
      expect(deserialized.hops[1].nickname, 'Relay-01');
    });
  });

  group('TracerouteView Widget UI Tests', () {
    testWidgets('TracerouteView renders discovery card and empty state', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;

      final state = NeighborNetState();

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider.value(
            value: state,
            child: const TracerouteView(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Multi-Hop Mesh Traceroute'), findsOneWidget);
      expect(find.text('DISCOVERY TARGET'), findsOneWidget);
      expect(find.text('Trace Route'), findsOneWidget);
      expect(find.text('TRACE SESSIONS'), findsOneWidget);
      expect(find.text('Ready to Trace Mesh Network Route'), findsOneWidget);
    });

    testWidgets('Simulate trace populates waterfall cards and signal metrics', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;

      final state = NeighborNetState();

      // Create a mock simulated trace
      final hop0 = TraceHop(
        nodeHash: 'local0000',
        nickname: 'Local Host',
        callsign: 'K7-LOC',
        interfaceType: 'Local Host',
        timestampMs: 1000,
        deltaMs: 0,
      );
      final hop1 = TraceHop(
        nodeHash: 'relay1111',
        nickname: 'Relay-Ridge-01',
        callsign: 'W7-RLY',
        interfaceType: 'LoRa-915MHz',
        rssiDbm: -74,
        snrDb: 9.4,
        timestampMs: 1018,
        deltaMs: 18,
      );
      final hop2 = TraceHop(
        nodeHash: 'target2222',
        nickname: 'Field-Station-Bravo',
        callsign: 'DEST-01',
        interfaceType: 'LoRa-915MHz',
        rssiDbm: -82,
        snrDb: 7.1,
        timestampMs: 1042,
        deltaMs: 24,
      );

      final session = TracerouteSession(
        traceId: 'trace-mock-99',
        originHash: 'local0000',
        originNickname: 'Local Host',
        originCallsign: 'K7-LOC',
        targetHash: 'target2222',
        targetNickname: 'Field-Station-Bravo',
        ttl: 6,
        maxTtl: 8,
        hops: [hop0, hop1, hop2],
        status: 'reached_destination',
        createdAtMs: 1000,
        completedAtMs: 1042,
        totalRttMs: 42,
      );

      state.selectTrace(session);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider.value(
            value: state,
            child: const TracerouteView(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('DESTINATION REACHED (OPTIMAL)'), findsOneWidget);
      expect(find.text('HOP-BY-HOP ROUTE WATERFALL'), findsOneWidget);
      expect(find.text('Relay-Ridge-01'), findsOneWidget);
      expect(find.text('Field-Station-Bravo'), findsNWidgets(2)); // Target summary + Hop card
      expect(find.text('-74 dBm'), findsOneWidget);
      expect(find.text('9.4 dB SNR'), findsOneWidget);
      expect(find.text('+18 ms'), findsOneWidget);
      expect(find.text('LINK QUALITY & BOTTLENECK ANALYSIS'), findsOneWidget);
    });
  });
}
