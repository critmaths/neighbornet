import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:neighbornet_app/models/neighbornet_models.dart';
import 'package:neighbornet_app/services/qr_service.dart';
import 'package:neighbornet_app/state/neighbornet_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Tactical Contact URI & QR Encoding Tests', () {
    test('UserProfile toContactUri encodes all parameters correctly', () {
      final profile = UserProfile(
        destHash: 'a1b2c3d4e5f60718293a4b5c6d7e8f90',
        nickname: 'Alice Alpha',
        callsign: 'KD9XYZ',
        neighborhoodZone: 'Sector-4 / Grid B2',
        bio: 'Emergency CERT responder',
        contactInfo: 'Signal: @alice.44',
        avatarBase64: 'tactical_medic',
        skills: ['Medical / First Aid', 'HAM Radio Operator'],
        updatedAtSec: 1700000000,
      );

      final uriString = profile.toContactUri();
      expect(uriString.startsWith('neighbornet://contact?'), isTrue);

      final decoded = UserProfile.fromContactUri(uriString);
      expect(decoded, isNotNull);
      expect(decoded!.destHash, 'a1b2c3d4e5f60718293a4b5c6d7e8f90');
      expect(decoded.nickname, 'Alice Alpha');
      expect(decoded.callsign, 'KD9XYZ');
      expect(decoded.neighborhoodZone, 'Sector-4 / Grid B2');
      expect(decoded.bio, 'Emergency CERT responder');
      expect(decoded.contactInfo, 'Signal: @alice.44');
      expect(decoded.avatarBase64, 'tactical_medic');
      expect(decoded.skills, ['Medical / First Aid', 'HAM Radio Operator']);
      expect(decoded.updatedAtSec, 1700000000);
    });

    test('UserProfile.fromContactUri parses raw JSON fallback', () {
      final jsonPayload = '''
      {
        "dest_hash": "fe9876543210abcdef0123456789abcd",
        "nickname": "Bob Bravo",
        "callsign": "W1AW",
        "skills": ["Solar & Off-Grid Power"],
        "updated_at_sec": 1700001111
      }
      ''';

      final profile = UserProfile.fromContactUri(jsonPayload);
      expect(profile, isNotNull);
      expect(profile!.destHash, 'fe9876543210abcdef0123456789abcd');
      expect(profile.nickname, 'Bob Bravo');
      expect(profile.callsign, 'W1AW');
      expect(profile.skills, ['Solar & Off-Grid Power']);
    });

    test('UserProfile.fromContactUri returns null for invalid input', () {
      expect(UserProfile.fromContactUri(''), isNull);
      expect(UserProfile.fromContactUri('https://google.com'), isNull);
      expect(UserProfile.fromContactUri('not a valid payload'), isNull);
    });

    test('QR Code image generation and pure-Dart decoding round-trip', () async {
      final originalProfile = UserProfile(
        destHash: '0123456789abcdef0123456789abcdef',
        nickname: 'Tactical Recon',
        callsign: 'K7NV',
        neighborhoodZone: 'Zone-North',
        skills: ['Comms & Security'],
      );

      final contactUri = originalProfile.toContactUri();

      // Render QR code to raster image using QrPainter
      final painter = QrPainter(
        data: contactUri,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
        gapless: true,
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: Color(0xFF000000),
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: Color(0xFF000000),
        ),
      );

      final pictureRecorder = ui.PictureRecorder();
      final canvas = Canvas(pictureRecorder);
      // Draw quiet zone background
      canvas.drawRect(const Rect.fromLTWH(0, 0, 400, 400), Paint()..color = const Color(0xFFFFFFFF));
      canvas.save();
      canvas.translate(50, 50);
      painter.paint(canvas, const Size(300, 300));
      canvas.restore();

      final picture = pictureRecorder.endRecording();
      final img = await picture.toImage(400, 400);
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      expect(byteData, isNotNull);

      final pngBytes = byteData!.buffer.asUint8List();

      // Decode with QrService (pure-Dart ZXing)
      final decodedPayload = QrService.decodeQrFromImageBytes(pngBytes);
      expect(decodedPayload, isNotNull);
      expect(decodedPayload, contactUri);

      // Parse decoded string to UserProfile
      final parsedProfile = QrService.parseScannedContact(decodedPayload!);
      expect(parsedProfile, isNotNull);
      expect(parsedProfile!.destHash, '0123456789abcdef0123456789abcdef');
      expect(parsedProfile.nickname, 'Tactical Recon');
      expect(parsedProfile.callsign, 'K7NV');
      expect(parsedProfile.neighborhoodZone, 'Zone-North');
      expect(parsedProfile.skills, ['Comms & Security']);
    });

    test('NeighborNetState importPeerContact updates state and contact lists', () {
      final state = NeighborNetState();

      final scannedPeer = UserProfile(
        destHash: '99887766554433221100aabbccddeeff',
        nickname: 'Doc Green',
        callsign: 'MEDIC-1',
        neighborhoodZone: 'Field Hospital',
        skills: ['Medical / First Aid', 'Water Purification'],
      );

      final imported = state.importPeerContact(scannedPeer);
      expect(imported, isTrue);

      final retrieved = state.getProfileForPeer('99887766554433221100aabbccddeeff');
      expect(retrieved, isNotNull);
      expect(retrieved!.nickname, 'Doc Green');
      expect(retrieved.callsign, 'MEDIC-1');
      expect(retrieved.neighborhoodZone, 'Field Hospital');
      expect(retrieved.skills.length, 2);

      expect(state.peers.any((p) => p.destHash == '99887766554433221100aabbccddeeff'), isTrue);
    });
  });
}
