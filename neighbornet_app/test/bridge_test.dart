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
    expect(status!.destHash.length, 32); // 16 bytes hex = 32 hex chars
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
    expect(bulletins.first.urgency, 'urgent');
    expect(bulletins.first.authorHash, status.destHash);

    // 5. Send Chat Message
    final chatSuccess = bridge.sendChat('general', 'Hello neighbors! Is power on in sector 4?');
    expect(chatSuccess, isTrue);

    final history = bridge.getChatHistory('general');
    expect(history.isNotEmpty, isTrue);
    expect(history.first.content, 'Hello neighbors! Is power on in sector 4?');
    expect(history.first.channel, 'general');

    // Clean up
    bridge.stopNode();
    expect(bridge.isReady, isFalse);
    tempDir.deleteSync(recursive: true);
  });
}
