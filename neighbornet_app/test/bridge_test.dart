import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:neighbornet_app/services/neighbornet_bridge.dart';

void main() {
  test('NeighborNet Bridge FFI Initialization and Functions', () {
    final tempDir = Directory.systemTemp.createTempSync('neighbornet_dart_test_');
    final bridge = NeighborNetBridge();

    // 1. Initialize node
    final success = bridge.initNode(
      dataDir: tempDir.path,
      listenPort: 46001,
      isTransport: false,
    );
    expect(success, isTrue);
    expect(bridge.isReady, isTrue);

    // 2. Query Status
    final status = bridge.getStatus();
    expect(status, isNotNull);
    expect(status!.destHash.length, 32);
    expect(status.nickname, startsWith('Neighbor-'));
    expect(status.listenPort, 46001);
    expect(status.isTransport, isFalse);

    // 3. Customize nickname
    final nickSuccess = bridge.setNickname('Bob Mobile');
    expect(nickSuccess, isTrue);
    final updatedStatus = bridge.getStatus();
    expect(updatedStatus!.nickname, 'Bob Mobile');

    // 4. Post Bulletin Notice
    final bulletinSuccess = bridge.postBulletin(
      'Shelter Open at Lincoln Middle School',
      'Cots, emergency meals, and Wi-Fi available.',
      'urgent',
    );
    expect(bulletinSuccess, isTrue);

    final bulletins = bridge.getBulletins();
    expect(bulletins.isNotEmpty, isTrue);
    expect(bulletins.first.title, 'Shelter Open at Lincoln Middle School');

    // 5. Send Chat Message
    final chatSuccess = bridge.sendChat('general', 'Hello neighbors! Is power on in sector 4?');
    expect(chatSuccess, isTrue);

    final history = bridge.getChatHistory('general');
    expect(history.isNotEmpty, isTrue);
    expect(history.first.content, 'Hello neighbors! Is power on in sector 4?');

    // 6. Test File Publishing
    final sampleFile = File('${tempDir.path}${Platform.pathSeparator}test_manual.txt');
    sampleFile.writeAsStringSync('Emergency water filtration guidelines for neighborhood distribution.');
    final fileHash = bridge.publishFile(sampleFile.path, 'Community filtration guidelines');
    expect(fileHash, isNotNull);
    expect(fileHash!.length, 64);

    final sharedFiles = bridge.getSharedFiles();
    expect(sharedFiles.isNotEmpty, isTrue);
    expect(sharedFiles.first.fileHash, fileHash);

    // 7. Test Dynamic Room Creation & Democratic Stewardship
    final room = bridge.createRoom('water-station', 'Community clean water distribution point');
    expect(room, isNotNull);
    expect(room!.name, 'water-station');
    expect(room.stewards.length, 1);
    expect(room.stewards.first, status.destHash);

    final rooms = bridge.getRooms();
    expect(rooms.any((r) => r.id == room.id), isTrue);

    // Propose vote on single-node room (self promotes or records vote)
    final propId = bridge.proposeStewardVote(
      roomId: room.id,
      targetHash: '11223344556677889900aabbccddeeff',
      targetNickname: 'Alice Volunteer',
      action: 'promote',
      reasonCategory: 'Community Support',
      reasonDetails: 'Coordinates relief supplies',
    );
    expect(propId, isNotNull);

    final proposals = bridge.getProposals(room.id);
    expect(proposals.isNotEmpty, isTrue);
    expect(proposals.first.targetNickname, 'Alice Volunteer');

    // Clean up
    bridge.stopNode();
    expect(bridge.isReady, isFalse);
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });
}
