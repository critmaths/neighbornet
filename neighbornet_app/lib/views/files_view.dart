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
  String _selectedCategory = 'all';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, dynamic>> _categories = [
    {'id': 'all', 'label': 'All Files', 'icon': Icons.folder_copy_outlined},
    {'id': 'documents', 'label': 'Documents', 'icon': Icons.description_outlined},
    {'id': 'maps', 'label': 'Maps & Geo', 'icon': Icons.map_outlined},
    {'id': 'media', 'label': 'Media & Audio', 'icon': Icons.perm_media_outlined},
    {'id': 'medical', 'label': 'Medical & Safety', 'icon': Icons.medical_services_outlined},
    {'id': 'vault', 'label': 'Encrypted Vault', 'icon': Icons.lock_outline},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<SharedFileInfo> _getFilteredFiles() {
    return widget.state.sharedFiles.where((file) {
      final matchesCategory = _selectedCategory == 'all' ||
          (_selectedCategory == 'vault' && file.isEncrypted) ||
          file.category.toLowerCase() == _selectedCategory.toLowerCase();

      final matchesQuery = _searchQuery.isEmpty ||
          file.fileName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          file.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          file.groupTag.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          file.authorNickname.toLowerCase().contains(_searchQuery.toLowerCase());

      return matchesCategory && matchesQuery;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final files = _getFilteredFiles();
    final allFiles = widget.state.sharedFiles;

    final totalSize = allFiles.fold<int>(0, (sum, f) => sum + f.fileSizeBytes);
    final completeFiles = allFiles.where((f) => f.isComplete).length;
    final encryptedFiles = allFiles.where((f) => f.isEncrypted).length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header & Stats Card
            _buildHeaderCard(theme, allFiles.length, completeFiles, encryptedFiles, totalSize),
            const SizedBox(height: 16),

            // Category Filter Chips & Search Bar
            _buildControlsBar(theme),
            const SizedBox(height: 16),

            // Files List or Empty State
            Expanded(
              child: files.isEmpty
                  ? _buildEmptyState(theme)
                  : ListView.builder(
                      itemCount: files.length,
                      itemBuilder: (context, index) {
                        return _buildFileCard(theme, files[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showPublishFileDialog(context),
        icon: const Icon(Icons.upload_file),
        label: const Text('Publish to Mesh'),
      ),
    );
  }

  Widget _buildHeaderCard(ThemeData theme, int total, int complete, int encrypted, int totalSize) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
              theme.colorScheme.surface,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.folder_shared, size: 36, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Decentralized Mesh Vault & File Sharing',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Store-and-forward chunked DAG distribution over LAN, Wi-Fi & LoRa mesh.',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            _buildStatBadge(theme, 'Total Files', '$total', Icons.library_books),
            const SizedBox(width: 12),
            _buildStatBadge(theme, 'Local Cached', '$complete', Icons.check_circle_outline, color: Colors.green),
            const SizedBox(width: 12),
            _buildStatBadge(theme, 'Encrypted', '$encrypted', Icons.lock_outline, color: Colors.amber),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBadge(ThemeData theme, String label, String value, IconData icon, {Color? color}) {
    final badgeColor = color ?? theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: badgeColor),
              const SizedBox(width: 4),
              Text(
                value,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: badgeColor),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsBar(ThemeData theme) {
    return Row(
      children: [
        // Category Chips
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat['id'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    avatar: Icon(
                      cat['icon'] as IconData,
                      size: 16,
                      color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.primary,
                    ),
                    label: Text(cat['label'] as String),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategory = cat['id'] as String;
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Search bar
        SizedBox(
          width: 220,
          height: 40,
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search vault...',
              hintStyle: const TextStyle(fontSize: 12),
              prefixIcon: const Icon(Icons.search, size: 18),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
              isDense: true,
            ),
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFileCard(ThemeData theme, SharedFileInfo file) {
    final progress = widget.state.getFileChunkStatus(file.fileHash);
    final isComplete = file.isComplete || (progress?.isComplete ?? false);

    IconData fileIcon;
    Color iconColor;
    if (file.isEncrypted) {
      fileIcon = Icons.lock;
      iconColor = Colors.amber;
    } else if (file.category == 'maps') {
      fileIcon = Icons.map;
      iconColor = Colors.cyan;
    } else if (file.category == 'media') {
      fileIcon = Icons.photo_library;
      iconColor = Colors.purpleAccent;
    } else if (file.category == 'medical') {
      fileIcon = Icons.medical_services;
      iconColor = Colors.redAccent;
    } else {
      fileIcon = Icons.insert_drive_file;
      iconColor = theme.colorScheme.primary;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // File Type Avatar
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(fileIcon, color: iconColor, size: 28),
                ),
                const SizedBox(width: 14),

                // File Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              file.fileName,
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          if (file.isEncrypted)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.amber.shade700),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.shield, size: 12, color: Colors.amber),
                                  SizedBox(width: 4),
                                  Text('AES Encrypted', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.amber)),
                                ],
                              ),
                            ),
                          _buildStatusChip(isComplete, progress),
                        ],
                      ),
                      if (file.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          file.description,
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          _buildMetaTag(Icons.storage, file.formattedSize),
                          _buildMetaTag(Icons.person_outline, '${file.authorNickname} (${file.groupTag})'),
                          _buildMetaTag(Icons.tag, '${file.chunkCount} chunks'),
                          _buildMetaTag(Icons.fingerprint, '${file.fileHash.substring(0, 8)}...'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Progress Bar if in transit
            if (!isComplete && progress != null && progress.downloadedChunks > 0) ...[
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Downloading chunks (${progress.downloadedChunks} / ${progress.totalChunks})...',
                        style: const TextStyle(fontSize: 11, color: Colors.amber),
                      ),
                      Text(
                        '${progress.progressPercent.toStringAsFixed(1)}%',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: progress.progressPercent / 100.0,
                    backgroundColor: Colors.grey.shade800,
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!isComplete)
                  ElevatedButton.icon(
                    onPressed: () {
                      widget.state.requestFileDownload(file.fileHash);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Requesting mesh chunks for ${file.fileName}...')),
                      );
                    },
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('Request Chunks'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      foregroundColor: theme.colorScheme.onPrimaryContainer,
                    ),
                  )
                else ...[
                  OutlinedButton.icon(
                    onPressed: () => _showExportDialog(context, file),
                    icon: Icon(file.isEncrypted ? Icons.lock_open : Icons.save_alt, size: 16),
                    label: Text(file.isEncrypted ? 'Decrypt & Export' : 'Save / Export'),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Delete from local cache',
                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                    onPressed: () => _confirmDeleteFile(context, file),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(bool isComplete, FileChunkProgress? progress) {
    if (isComplete) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 12, color: Colors.green),
            SizedBox(width: 4),
            Text('Complete', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)),
          ],
        ),
      );
    } else if (progress != null && progress.downloadedChunks > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.amber),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sync, size: 12, color: Colors.amber),
            const SizedBox(width: 4),
            Text(
              '${progress.progressPercent.toInt()}% Chunks',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_queue, size: 12, color: Colors.blue),
            SizedBox(width: 4),
            Text('On Mesh', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue)),
          ],
        ),
      );
    }
  }

  Widget _buildMetaTag(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.grey),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open, size: 48, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No files matching "$_searchQuery"'
                  : 'No files in this category',
              style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 6),
            Text(
              'Publish a file to distribute it across the decentralized mesh.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _showPublishFileDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Publish First File'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPublishFileDialog(BuildContext context) {
    final pathController = TextEditingController();
    final descController = TextEditingController();
    final groupTagController = TextEditingController(text: 'Public Vault');
    final passController = TextEditingController();
    String category = 'documents';
    bool isEncrypted = false;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.upload_file),
                  SizedBox(width: 10),
                  Text('Publish File to Mesh'),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 450,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Files are split into 64 KB chunks and distributed via store-and-forward gossip.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: pathController,
                        decoration: const InputDecoration(
                          labelText: 'File Path on Device *',
                          hintText: 'C:\\path\\to\\file.txt or /tmp/doc.pdf',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descController,
                        decoration: const InputDecoration(
                          labelText: 'Description / Purpose',
                          hintText: 'Emergency guidelines, map pack, etc.',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: category,
                              decoration: const InputDecoration(
                                labelText: 'Category',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: const [
                                DropdownMenuItem(value: 'documents', child: Text('Documents')),
                                DropdownMenuItem(value: 'maps', child: Text('Maps & Geo')),
                                DropdownMenuItem(value: 'media', child: Text('Media & Audio')),
                                DropdownMenuItem(value: 'medical', child: Text('Medical & Safety')),
                                DropdownMenuItem(value: 'archives', child: Text('Archives')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setDialogState(() => category = val);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: groupTagController,
                              decoration: const InputDecoration(
                                labelText: 'Group Tag',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Passphrase Encryption (Vault)'),
                        subtitle: const Text('Encrypts payload with AES-256 before chunking on mesh', style: TextStyle(fontSize: 11)),
                        value: isEncrypted,
                        onChanged: (val) {
                          setDialogState(() => isEncrypted = val);
                        },
                      ),
                      if (isEncrypted) ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: passController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Vault Passphrase *',
                            hintText: 'Enter shared group passphrase',
                            border: OutlineInputBorder(),
                            isDense: true,
                            prefixIcon: Icon(Icons.key),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final path = pathController.text.trim();
                    if (path.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a valid file path.')),
                      );
                      return;
                    }
                    if (isEncrypted && passController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a passphrase for encrypted file.')),
                      );
                      return;
                    }

                    final res = widget.state.publishFileExtended(
                      path: path,
                      description: descController.text.trim(),
                      category: isEncrypted ? 'vault' : category,
                      groupTag: groupTagController.text.trim(),
                      passphrase: isEncrypted ? passController.text.trim() : null,
                    );

                    Navigator.of(dialogCtx).pop();

                    if (res != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Published "${path.split(RegExp(r'[/\\]')).last}" to mesh!')),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Failed to publish file. Check file path.')),
                      );
                    }
                  },
                  child: const Text('Publish'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showExportDialog(BuildContext context, SharedFileInfo file) {
    final targetPathController = TextEditingController(text: 'C:\\NeighborNet_Exports\\${file.fileName}');
    final passController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: Text(file.isEncrypted ? 'Decrypt & Export File' : 'Export File'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: targetPathController,
                decoration: const InputDecoration(
                  labelText: 'Target File Path',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              if (file.isEncrypted) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: passController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Passphrase to Decrypt',
                    border: OutlineInputBorder(),
                    isDense: true,
                    prefixIcon: Icon(Icons.key),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final targetPath = targetPathController.text.trim();
                final pass = file.isEncrypted ? passController.text.trim() : null;
                final ok = widget.state.exportSharedFile(
                  fileHash: file.fileHash,
                  targetPath: targetPath,
                  passphrase: pass,
                );

                Navigator.of(dialogCtx).pop();

                if (ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Saved to $targetPath')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Export failed. Check passphrase or target path.')),
                  );
                }
              },
              child: const Text('Export'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteFile(BuildContext context, SharedFileInfo file) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('Delete File from Local Cache?'),
          content: Text('Are you sure you want to delete "${file.fileName}" and all stored chunks from local storage?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () {
                widget.state.deleteSharedFile(file.fileHash);
                Navigator.of(dialogCtx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Deleted "${file.fileName}" from cache.')),
                );
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
