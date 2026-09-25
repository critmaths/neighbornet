import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neighbornet_app/models/neighbornet_models.dart';
import 'package:neighbornet_app/services/ptt_service.dart';
import 'package:neighbornet_app/state/neighbornet_state.dart';
import 'package:neighbornet_app/views/ptt_walkie_talkie_view.dart';
import 'package:provider/provider.dart';

void main() {
  group('PttService Floor & Voice State Machine Tests', () {
    late PttService ptt;

    setUp(() {
      ptt = PttService();
    });

    tearDown(() {
      ptt.dispose();
    });

    test('Initial state is idle with default CH-01', () {
      expect(ptt.state, equals(PttState.idle));
      expect(ptt.isIdle, isTrue);
      expect(ptt.isTransmitting, isFalse);
      expect(ptt.isReceiving, isFalse);
      expect(ptt.activeChannel.id, equals('CH-01'));
      expect(ptt.availableChannels.length, equals(5));
    });

    test('Channel switching updates active channel and resets floor state', () {
      ptt.selectChannelById('CH-09');
      expect(ptt.activeChannel.id, equals('CH-09'));
      expect(ptt.activeChannel.isEmergency, isTrue);

      ptt.selectChannel(kStandardPttChannels[1]);
      expect(ptt.activeChannel.id, equals('CH-02'));
      expect(ptt.activeChannel.name, equals('Logistics & Supplies'));
    });

    test('PTT keydown transitions to transmitting, release adds log and resets to idle', () {
      final success = ptt.pressPtt();
      expect(success, isTrue);
      expect(ptt.state, equals(PttState.transmitting));
      expect(ptt.isTransmitting, isTrue);

      ptt.releasePtt();
      expect(ptt.state, equals(PttState.idle));
      expect(ptt.isIdle, isTrue);
      expect(ptt.transmissionLogs.length, equals(1));
      expect(ptt.transmissionLogs.first.channel, equals('CH-01'));
    });

    test('Incoming floor event from remote station transitions to receiving', () {
      final event = PttFloorEvent(
        channel: 'CH-01',
        speakerHash: 'aabbccdd11223344',
        speakerNickname: 'Alice',
        speakerCallsign: 'CERT-01',
        isTransmitting: true,
        priority: 'normal',
        timestampSec: 1720000000,
      );

      ptt.handleIncomingFloorEvent(event);
      expect(ptt.state, equals(PttState.receiving));
      expect(ptt.isReceiving, isTrue);
      expect(ptt.activeSpeakerNickname, equals('Alice'));
      expect(ptt.activeSpeakerCallsign, equals('CERT-01'));

      // Pressing PTT while floor is occupied results in busy rejection
      final txOk = ptt.pressPtt();
      expect(txOk, isFalse);
      expect(ptt.state, equals(PttState.busy));
      expect(ptt.lastError, contains('Channel floor is busy'));

      // Remote station releases floor
      final releaseEvent = PttFloorEvent(
        channel: 'CH-01',
        speakerHash: 'aabbccdd11223344',
        speakerNickname: 'Alice',
        speakerCallsign: 'CERT-01',
        isTransmitting: false,
        priority: 'normal',
        timestampSec: 1720000005,
      );

      ptt.handleIncomingFloorEvent(releaseEvent);
      expect(ptt.state, equals(PttState.idle));
      expect(ptt.activeSpeakerNickname, isNull);
    });

    test('Emergency override allows breaking in on occupied floor', () {
      final event = PttFloorEvent(
        channel: 'CH-01',
        speakerHash: 'aabbccdd11223344',
        speakerNickname: 'Bob',
        speakerCallsign: 'LOG-02',
        isTransmitting: true,
        priority: 'normal',
        timestampSec: 1720000000,
      );

      ptt.handleIncomingFloorEvent(event);
      expect(ptt.state, equals(PttState.receiving));

      // Normal transmission fails
      expect(ptt.pressPtt(isEmergencyOverride: false), isFalse);

      // Emergency override succeeds
      expect(ptt.pressPtt(isEmergencyOverride: true), isTrue);
      expect(ptt.state, equals(PttState.transmitting));
    });

    test('Incoming final voice chunk creates transmission log entry', () {
      final chunk1 = PttVoiceChunk(
        sessionId: 'sess_123',
        sequence: 1,
        channel: 'CH-01',
        senderHash: 'aabbccdd11223344',
        senderNickname: 'Charlie',
        senderCallsign: 'RECON-1',
        audioBase64: 'PCM_AUDIO_DATA_1',
        isFinal: false,
        timestampSec: 1720000000,
      );
      ptt.handleIncomingVoiceChunk(chunk1);
      expect(ptt.state, equals(PttState.receiving));
      expect(ptt.transmissionLogs.isEmpty, isTrue);

      final chunk2 = PttVoiceChunk(
        sessionId: 'sess_123',
        sequence: 2,
        channel: 'CH-01',
        senderHash: 'aabbccdd11223344',
        senderNickname: 'Charlie',
        senderCallsign: 'RECON-1',
        audioBase64: 'PCM_AUDIO_DATA_2',
        isFinal: true,
        timestampSec: 1720000001,
      );
      ptt.handleIncomingVoiceChunk(chunk2);
      expect(ptt.state, equals(PttState.idle));
      expect(ptt.transmissionLogs.length, equals(1));
      expect(ptt.transmissionLogs.first.senderNickname, equals('Charlie'));
      expect(ptt.transmissionLogs.first.chunkCount, equals(2));
    });

    test('Hardware controls (Volume, Squelch, VOX, Roger Beep) update correctly', () {
      ptt.setVolume(0.5);
      expect(ptt.volume, equals(0.5));

      ptt.setSquelch(0.7);
      expect(ptt.squelchLevel, equals(0.7));

      ptt.toggleVox(true);
      expect(ptt.voxEnabled, isTrue);

      ptt.toggleRogerBeep(false);
      expect(ptt.rogerBeepEnabled, isFalse);

      ptt.clearLogs();
      expect(ptt.transmissionLogs.isEmpty, isTrue);
    });
  });

  group('PttWalkieTalkieView Widget Tests', () {
    testWidgets('Renders tactical LCD readout, PTT button, controls, and channel list', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;

      final state = NeighborNetState();

      await tester.pumpWidget(
        ChangeNotifierProvider<NeighborNetState>.value(
          value: state,
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: const PttWalkieTalkieView(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // Verify Tactical Display
      expect(find.text('Tactical Walkie-Talkie (PTT)'), findsOneWidget);
      expect(find.text('SIMPLEX HALF-DUPLEX'), findsOneWidget);
      expect(find.text('STANDBY / SQUELCH OPEN'), findsOneWidget);
      expect(find.text('CH-01'), findsNWidgets(2)); // LCD + Channel list
      expect(find.text('TAC-GENERAL'), findsOneWidget);
      expect(find.text('AUDIO MODULATION (VU METER)'), findsOneWidget);

      // Verify PTT Button
      expect(find.text('PRESS & HOLD'), findsOneWidget);
      expect(find.text('PTT BUTTON'), findsOneWidget);
      expect(find.text('SPACEBAR'), findsOneWidget);

      // Verify Controls
      expect(find.text('RADIO HARDWARE SETTINGS'), findsOneWidget);
      expect(find.text('Roger Beep Tone'), findsOneWidget);
      expect(find.text('VOX (Voice Activated)'), findsOneWidget);

      // Verify Tactical Channels
      expect(find.text('TACTICAL CHANNELS'), findsOneWidget);
      expect(find.text('Logistics & Supplies'), findsOneWidget);
      expect(find.text('CERT & Medical'), findsOneWidget);
      expect(find.text('Emergency Distress Net'), findsOneWidget);
      expect(find.text('Tactical Recon'), findsOneWidget);

      // Switch to Emergency Channel
      await tester.tap(find.text('Emergency Distress Net'));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('CH-09'), findsNWidgets(2));
      expect(find.text('EMERGENCY DISTRESS NET'), findsOneWidget);

      // Press and hold PTT
      final pttBtnFinder = find.text('PRESS & HOLD');
      final gesture = await tester.startGesture(tester.getCenter(pttBtnFinder));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('TRANSMITTING'), findsOneWidget);
      expect(find.text('RELEASE TO END'), findsOneWidget);

      await gesture.up();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('PRESS & HOLD'), findsOneWidget);
      expect(find.text('CHANNEL TRAFFIC LOG'), findsOneWidget);
      expect(find.textContaining('duration'), findsOneWidget);

      state.dispose();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });
}
