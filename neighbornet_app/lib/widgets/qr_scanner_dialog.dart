import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../models/neighbornet_models.dart';
import '../services/qr_service.dart';
import '../state/neighbornet_state.dart';

class QrScannerDialog extends StatefulWidget {
  const QrScannerDialog({super.key});

  static Future<UserProfile?> show(BuildContext context) {
    return showDialog<UserProfile>(
      context: context,
      builder: (ctx) => const QrScannerDialog(),
    );
  }

  @override
  State<QrScannerDialog> createState() => _QrScannerDialogState();
}

class _QrScannerDialogState extends State<QrScannerDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _uriInputController = TextEditingController();

  UserProfile? _decodedProfile;
  String? _errorMessage;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _uriInputController.dispose();
    super.dispose();
  }

  Future<void> _pickAndDecodeImage() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'bmp', 'webp'],
      );

      if (result == null || result.files.isEmpty) {
        setState(() {
          _isProcessing = false;
        });
        return;
      }

      final path = result.files.single.path;
      if (path == null) {
        setState(() {
          _errorMessage = 'Could not access selected file path';
          _isProcessing = false;
        });
        return;
      }

      final bytes = await File(path).readAsBytes();
      final decodedText = QrService.decodeQrFromImageBytes(bytes);

      if (decodedText == null || decodedText.isEmpty) {
        setState(() {
          _errorMessage = 'No valid QR code could be detected in this image. Ensure high contrast and clear focus.';
          _isProcessing = false;
        });
        return;
      }

      final profile = QrService.parseScannedContact(decodedText);
      if (profile == null) {
        setState(() {
          _errorMessage = 'QR code does not contain a valid NeighborNet contact format.';
          _isProcessing = false;
        });
        return;
      }

      setState(() {
        _decodedProfile = profile;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to process image: $e';
        _isProcessing = false;
      });
    }
  }

  void _parseManualUri(String input) {
    setState(() {
      _errorMessage = null;
    });

    final profile = QrService.parseScannedContact(input);
    if (profile == null) {
      setState(() {
        _errorMessage = 'Invalid contact URI or format. Expected: neighbornet://contact?dest=...';
      });
      return;
    }

    setState(() {
      _decodedProfile = profile;
    });
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      _uriInputController.text = data.text!;
      _parseManualUri(data.text!);
    }
  }

  void _confirmAndImport(UserProfile profile) {
    final state = Provider.of<NeighborNetState>(context, listen: false);
    state.importPeerContact(profile);
    Navigator.of(context).pop(profile);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.greenAccent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Contact "${profile.nickname}" (${profile.callsign.isNotEmpty ? profile.callsign : profile.destHash.substring(0, 8)}) imported to mesh address book!',
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: theme.colorScheme.primary,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withAlpha(128),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.qr_code_scanner_rounded,
                      color: theme.colorScheme.primary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Scan / Import Contact',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Optical Air-Gapped Mesh Exchange',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_decodedProfile != null) ...[
                // Decoded Contact Preview Card
                _buildDecodedProfilePreview(theme, _decodedProfile!),
              ] else ...[
                // Tab Selection for Input Methods
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withAlpha(100),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: theme.colorScheme.primaryContainer,
                    ),
                    labelColor: theme.colorScheme.onPrimaryContainer,
                    unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                    tabs: const [
                      Tab(icon: Icon(Icons.image_search_rounded, size: 20), text: 'Photo / File'),
                      Tab(icon: Icon(Icons.link_rounded, size: 20), text: 'URI / Paste'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Tab Content
                SizedBox(
                  height: 240,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Tab 1: Image File Picker
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.qr_code_2_rounded,
                              size: 56,
                              color: theme.colorScheme.primary.withAlpha(180),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Import QR Code Photo or Screenshot',
                              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Supports PNG, JPG, WebP, BMP',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 18),
                            FilledButton.icon(
                              icon: _isProcessing
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.folder_open_rounded),
                              label: Text(_isProcessing ? 'Decoding...' : 'Choose Image File'),
                              onPressed: _isProcessing ? null : _pickAndDecodeImage,
                            ),
                          ],
                        ),
                      ),

                      // Tab 2: Manual URI / Clipboard Paste
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextField(
                            controller: _uriInputController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              labelText: 'Contact URI or Raw Identity Key',
                              hintText: 'neighbornet://contact?dest=... or raw JSON',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.all(12),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.paste_rounded, size: 18),
                                  label: const Text('Paste Clipboard'),
                                  onPressed: _pasteFromClipboard,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton.icon(
                                  icon: const Icon(Icons.check_rounded, size: 18),
                                  label: const Text('Parse'),
                                  onPressed: () => _parseManualUri(_uriInputController.text),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer.withAlpha(120),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: theme.colorScheme.error.withAlpha(80)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline_rounded, color: theme.colorScheme.error, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDecodedProfilePreview(ThemeData theme, UserProfile profile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.withAlpha(30),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.green.withAlpha(100)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              Text(
                'Tactical Contact Validated!',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Profile Identity Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withAlpha(120),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Icon(Icons.person_rounded, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (profile.callsign.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  profile.callsign,
                                  style: TextStyle(
                                    color: theme.colorScheme.onPrimary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Flexible(
                              child: Text(
                                profile.nickname.isNotEmpty ? profile.nickname : 'Neighbor',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (profile.neighborhoodZone.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            profile.neighborhoodZone,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.secondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Destination Key
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(Icons.vpn_key_rounded, size: 14, color: theme.colorScheme.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        profile.destHash,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              if (profile.bio.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  profile.bio,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],

              if (profile.skills.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: profile.skills.map((skill) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withAlpha(90),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        skill,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Actions
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _decodedProfile = null;
                  });
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Scan Another'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                icon: const Icon(Icons.person_add_rounded, size: 18),
                label: const Text('Save Contact'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _confirmAndImport(profile),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
