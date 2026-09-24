import 'package:flutter/material.dart';
import '../models/neighbornet_models.dart';
import '../state/neighbornet_state.dart';

class FilesView extends StatefulWidget {
  final NeighborNetState state;

  const FilesView({super.key, required this.state});

  @override
  State<FilesView> createState() => _FilesViewState();
}

class _FilesViewState extends State<FilesView> {
  String _searchQuery = '';

  void _showPublishDialog() {
    final pathCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.upload_file, color: Colors.teal),
            SizedBox(width: 8),
            Text('Publish Document to Mesh'),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Files are split into content-addressed cryptographic chunks (SHA-256) and replicated peer-to-peer across nearby community nodes.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pathCtrl,
                decoration: const InputDecoration(
                  labelText: 'Absolute Local File Path',
                  hintText: r'e.g. C:\docs\offline_water_guide.pdf',
                  prefixIcon: Icon(Icons.insert_drive_file_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Description / Community Purpose',
                  hintText: 'e.g. Official triage protocols & boil water guidelines',
                  prefixIcon: Icon(Icons.description_outlined),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.share),
            label: const Text('Publish & Distribute'),
            onPressed: () {
              final path = pathCtrl.text.trim();
              final desc = descCtrl.text.trim();
              if (path.isNotEmpty) {
                final hash = widget.state.publishFile(path, desc);
                Navigator.pop(dialogCtx);
                if (mounted) {
                  if (hash != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('File published! SHA-256: ${hash.substring(0, 16)}...'),
                        backgroundColor: Colors.teal,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Failed to read or publish specified file.'),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                }
              }
            },
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.pdf')) return Icons.picture_as_pdf;
    if (lower.endsWith('.txt') || lower.endsWith('.md')) return Icons.article;
    if (lower.endsWith('.jpg') || lower.endsWith('.png') || lower.endsWith('.jpeg')) return Icons.image;
    if (lower.endsWith('.zip') || lower.endsWith('.tar') || lower.endsWith('.gz')) return Icons.folder_zip;
    if (lower.endsWith('.kml') || lower.endsWith('.gpx') || lower.contains('map')) return Icons.map;
    return Icons.insert_drive_file;
  }

  @override
  Widget build(BuildContext context) {
    final files = widget.state.sharedFiles.where((f) {
      if (_searchQuery.isEmpty) return true;
      return f.fileName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          f.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          f.fileHash.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            child: Row(
              children: [
                Expanded(
                  child: SearchBar(
                    hintText: 'Search community files & offline maps...',
                    leading: const Icon(Icons.search),
                    elevation: const WidgetStatePropertyAll(0),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _showPublishDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Share File'),
                  style: FilledButton.styleFrom(backgroundColor: Colors.teal),
                ),
              ],
            ),
          ),
          Expanded(
            child: files.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.folder_shared_outlined, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? 'No Shared Files on Local Mesh Yet'
                              : 'No files match "$_searchQuery"',
                          style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Share survival manuals, offline maps, and emergency resources\nwith your neighborhood without central servers.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _showPublishDialog,
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Share First Document'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: files.length,
                    itemBuilder: (context, index) {
                      final item = files[index];
                      return _FileCard(
                        file: item,
                        state: widget.state,
                        icon: _getFileIcon(item.fileName),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _FileCard extends StatelessWidget {
  final SharedFileInfo file;
  final NeighborNetState state;
  final IconData icon;

  const _FileCard({
    required this.file,
    required this.state,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shortHash = file.fileHash.length >= 12 ? file.fileHash.substring(0, 12) : file.fileHash;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: file.isComplete
              ? Colors.teal.withValues(alpha: 0.3)
              : theme.colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: file.isComplete
                      ? Colors.teal.withValues(alpha: 0.15)
                      : Colors.blueGrey.withValues(alpha: 0.15),
                  child: Icon(
                    icon,
                    color: file.isComplete ? Colors.teal : Colors.blueGrey,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.fileName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            file.formattedSize,
                            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(width: 8),
                          Text('•', style: TextStyle(color: Colors.grey.shade400)),
                          const SizedBox(width: 8),
                          Text(
                            '${file.chunkCount} ${file.chunkCount == 1 ? "chunk" : "chunks"}',
                            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(width: 8),
                          Text('•', style: TextStyle(color: Colors.grey.shade400)),
                          const SizedBox(width: 8),
                          Text(
                            'SHA: $shortHash...',
                            style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (file.isComplete)
                  Chip(
                    avatar: const Icon(Icons.check_circle, size: 16, color: Colors.teal),
                    label: const Text('Stored Locally', style: TextStyle(fontSize: 11, color: Colors.teal)),
                    backgroundColor: Colors.teal.withValues(alpha: 0.1),
                    side: BorderSide.none,
                    visualDensity: VisualDensity.compact,
                  )
                else
                  Chip(
                    avatar: const Icon(Icons.cloud_download, size: 16, color: Colors.indigo),
                    label: const Text('Available on Mesh', style: TextStyle(fontSize: 11, color: Colors.indigo)),
                    backgroundColor: Colors.indigo.withValues(alpha: 0.1),
                    side: BorderSide.none,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            if (file.description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                file.description,
                style: const TextStyle(fontSize: 13),
              ),
            ],
            const Divider(height: 20),
            Row(
              children: [
                Icon(Icons.person_pin_circle_outlined, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  'Shared by ${file.authorNickname}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const Spacer(),
                if (file.isComplete)
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.folder_open, size: 16),
                    label: const Text('Show Stored File'),
                    onPressed: () {
                      final path = state.getCompletedFilePath(file.fileHash);
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('File Available on Local Device'),
                          content: SelectableText(
                            path ?? 'Stored in NeighborNet local files directory.',
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      );
                    },
                  )
                else
                  FilledButton.icon(
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('Download / Replicate'),
                    onPressed: () {
                      final success = state.requestFile(file.fileHash);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(success
                              ? 'Requesting chunks for "${file.fileName}" across mesh peers...'
                              : 'Could not send request.'),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
