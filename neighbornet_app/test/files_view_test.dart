import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neighbornet_app/models/neighbornet_models.dart';
import 'package:neighbornet_app/state/neighbornet_state.dart';
import 'package:neighbornet_app/views/files_view.dart';

void main() {
  group('SharedFileInfo & FileChunkProgress Model Tests', () {
    test('SharedFileInfo correctly parses standard and encrypted files', () {
      final json = {
        'file_hash': 'a1b2c3d4e5f6',
        'filename': 'evacuation_map.pdf',
        'file_size': 2048576,
        'chunk_count': 32,
        'chunk_size': 65536,
        'description': 'Sector 4 Evacuation Routes',
        'author_hash': 'peer123',
        'author_nickname': 'Steward-Alpha',
        'timestamp_sec': 1700000000,
        'is_complete': true,
        'category': 'maps',
        'group_tag': 'Emergency Ops',
        'is_encrypted': true,
        'mime_type': 'application/pdf',
        'encryption_salt': '0123456789abcdef',
      };

      final file = SharedFileInfo.fromJson(json);

      expect(file.fileHash, 'a1b2c3d4e5f6');
      expect(file.fileName, 'evacuation_map.pdf');
      expect(file.fileSizeBytes, 2048576);
      expect(file.formattedSize, '2.0 MB');
      expect(file.chunkCount, 32);
      expect(file.chunkSize, 65536);
      expect(file.description, 'Sector 4 Evacuation Routes');
      expect(file.authorNickname, 'Steward-Alpha');
      expect(file.category, 'maps');
      expect(file.groupTag, 'Emergency Ops');
      expect(file.isEncrypted, true);
      expect(file.isComplete, true);
      expect(file.encryptionSalt, '0123456789abcdef');
    });

    test('FileChunkProgress accurately calculates download metrics', () {
      final json = {
        'file_hash': 'chunkhash789',
        'filename': 'audio_briefing.mp3',
        'downloaded_chunks': 8,
        'total_chunks': 10,
        'progress_percent': 80.0,
        'is_complete': false,
        'file_path': null,
      };

      final progress = FileChunkProgress.fromJson(json);

      expect(progress.fileHash, 'chunkhash789');
      expect(progress.downloadedChunks, 8);
      expect(progress.totalChunks, 10);
      expect(progress.progressPercent, 80.0);
      expect(progress.isComplete, false);
      expect(progress.filePath, isNull);
    });
  });

  group('FilesView Widget UI Tests', () {
    testWidgets('FilesView renders header, categories, search, and empty state', (WidgetTester tester) async {
      final state = NeighborNetState();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: Scaffold(
            body: FilesView(state: state),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Decentralized Mesh Vault & File Sharing'), findsOneWidget);
      expect(find.text('Total Files'), findsOneWidget);
      expect(find.text('Local Cached'), findsOneWidget);
      expect(find.text('Encrypted'), findsOneWidget);

      expect(find.text('All Files'), findsOneWidget);
      expect(find.text('Documents'), findsOneWidget);
      expect(find.text('Maps & Geo'), findsOneWidget);
      expect(find.text('Media & Audio'), findsOneWidget);
      expect(find.text('Medical & Safety'), findsOneWidget);
      expect(find.text('Encrypted Vault'), findsOneWidget);

      expect(find.text('Publish to Mesh'), findsOneWidget);
    });
  });
}
