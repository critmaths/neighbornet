import 'package:flutter_test/flutter_test.dart';
import 'package:neighbornet_app/models/neighbornet_models.dart';
import 'package:neighbornet_app/services/neighbornet_bridge.dart';
import 'package:neighbornet_app/state/neighbornet_state.dart';

void main() {
  group('Sovereign UserProfile Model Tests', () {
    test('UserProfile serializes to/from JSON correctly with all tactical fields', () {
      final prof = UserProfile(
        destHash: 'a1b2c3d4e5f67890a1b2c3d4e5f67890',
        nickname: 'Echo Unit 1',
        bio: 'CERT team first responder & solar technician',
        avatarBase64: 'tactical_medic',
        callsign: 'KD9XYZ',
        contactInfo: 'Signal: @echo1 / 146.520 MHz',
        neighborhoodZone: 'Sector 4 / Grid B2',
        skills: ['Medical / First Aid', 'Solar & Off-Grid Power', 'HAM Radio Operator'],
        updatedAtSec: 1700000000,
      );

      final json = prof.toJson();
      expect(json['dest_hash'], 'a1b2c3d4e5f67890a1b2c3d4e5f67890');
      expect(json['nickname'], 'Echo Unit 1');
      expect(json['bio'], 'CERT team first responder & solar technician');
      expect(json['avatar_base64'], 'tactical_medic');
      expect(json['callsign'], 'KD9XYZ');
      expect(json['contact_info'], 'Signal: @echo1 / 146.520 MHz');
      expect(json['neighborhood_zone'], 'Sector 4 / Grid B2');
      expect(json['skills'], ['Medical / First Aid', 'Solar & Off-Grid Power', 'HAM Radio Operator']);
      expect(json['updated_at_sec'], 1700000000);

      final fromJson = UserProfile.fromJson(json);
      expect(fromJson.destHash, prof.destHash);
      expect(fromJson.nickname, prof.nickname);
      expect(fromJson.bio, prof.bio);
      expect(fromJson.avatarBase64, prof.avatarBase64);
      expect(fromJson.callsign, prof.callsign);
      expect(fromJson.contactInfo, prof.contactInfo);
      expect(fromJson.neighborhoodZone, prof.neighborhoodZone);
      expect(fromJson.skills.length, 3);
      expect(fromJson.skills[0], 'Medical / First Aid');
      expect(fromJson.updatedAtSec, 1700000000);
    });

    test('UserProfile parses stringified skills JSON seamlessly', () {
      final json = {
        'dest_hash': 'abcdef123456',
        'nickname': 'Bob',
        'bio': '',
        'avatar_base64': 'tactical_radio',
        'callsign': 'W1AW',
        'contact_info': '',
        'neighborhood_zone': '',
        'skills': '["HAM Radio Operator", "Logistics & Supplies"]',
        'updated_at_sec': 1700000000,
      };

      final prof = UserProfile.fromJson(json);
      expect(prof.nickname, 'Bob');
      expect(prof.callsign, 'W1AW');
      expect(prof.skills.length, 2);
      expect(prof.skills[0], 'HAM Radio Operator');
    });

    test('UserProfile copyWith correctly clones and overrides selective fields', () {
      final prof = UserProfile(
        destHash: '112233',
        nickname: 'Original',
        callsign: 'ORIG1',
        skills: ['Medical / First Aid'],
      );

      final updated = prof.copyWith(
        nickname: 'Updated Name',
        skills: ['Medical / First Aid', 'Search & Rescue'],
      );

      expect(updated.destHash, '112233');
      expect(updated.nickname, 'Updated Name');
      expect(updated.callsign, 'ORIG1');
      expect(updated.skills.length, 2);
    });
  });

  group('NeighborNetBridge Profile Fallbacks', () {
    test('Bridge handles uninitialized profile calls gracefully', () {
      final bridge = NeighborNetBridge();
      expect(bridge.getMyProfile(), isNull);
      expect(bridge.getPeerProfile('unknown_hash'), isNull);
      expect(bridge.getAllProfiles(), isEmpty);
      expect(bridge.updateMyProfile(UserProfile(destHash: '1', nickname: 'Test')), isNull);
    });
  });

  group('NeighborNetState Profile State Management', () {
    test('Initial state has safe profile defaults', () {
      final state = NeighborNetState();
      expect(state.myProfile, isNull);
      expect(state.peerProfiles, isEmpty);
      expect(state.getProfileForPeer('nonexistent'), isNull);
    });

    test('refreshMyProfile and refreshPeerProfiles execute safely when uninitialized', () async {
      final state = NeighborNetState();
      await state.refreshMyProfile();
      await state.refreshPeerProfiles();
      expect(state.myProfile, isNull);
      expect(state.peerProfiles, isEmpty);
    });
  });
}
