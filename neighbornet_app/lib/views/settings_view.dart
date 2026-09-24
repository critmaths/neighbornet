import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/neighbornet_models.dart';
import '../services/tray_and_window_service.dart';
import '../state/neighbornet_state.dart';

class SettingsView extends StatefulWidget {
  final NeighborNetState state;

  const SettingsView({super.key, required this.state});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  late TextEditingController _nickCtrl;

  @override
  void initState() {
    super.initState();
    _nickCtrl = TextEditingController(text: widget.state.status?.nickname ?? '');
  }

  @override
  void didUpdateWidget(covariant SettingsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_nickCtrl.text.isEmpty && widget.state.status?.nickname != null) {
      _nickCtrl.text = widget.state.status!.nickname;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.state.status;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: ListView(
        children: [
          const Text(
            'Node & Network Settings',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Configure your community presence and inspect cryptographic Reticulum details',
            style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),

          const SizedBox(height: 24),

          // Profile Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.2)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Community Identity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nickCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Community Display Nickname',
                            hintText: 'e.g. Alice',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: () {
                          if (_nickCtrl.text.trim().isNotEmpty) {
                            final ok = widget.state.setNickname(_nickCtrl.text.trim());
                            if (ok) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Nickname updated successfully!')),
                              );
                            }
                          }
                        },
                        child: const Text('Update'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text('Reticulum Destination Hash:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: SelectableText(
                            status?.destHash ?? 'Initializing...',
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          tooltip: 'Copy Destination Hash',
                          onPressed: () {
                            if (status?.destHash != null) {
                              Clipboard.setData(ClipboardData(text: status!.destHash));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Copied hash to clipboard!')),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    'Cryptographic Key Backup & Portability',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Export your 48-word BIP-39 mnemonic paper key to survive device loss, or restore a previous identity to reclaim room stewardship and reputation.',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.key_rounded, size: 18),
                        label: const Text('View 48-Word Paper Key'),
                        onPressed: () => _showPaperKeyDialog(context),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.file_download_outlined, size: 18),
                        label: const Text('Import / Restore Identity'),
                        onPressed: () => _showRestoreIdentityDialog(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Tactical Visual Profile Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.2)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.palette_outlined, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      const Text(
                        'Tactical Visual Profile',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Adapt your display for tactical night-vision stealth or direct sunlight outdoor operations.',
                    style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      // Option 1: Default Amber
                      _buildThemeOption(
                        context,
                        title: 'Cyber Amber',
                        subtitle: 'Default Dark',
                        color: const Color(0xFFF59E0B),
                        bgColor: const Color(0xFF0B0F19),
                        profile: AppThemeProfile.defaultDark,
                        isSelected: widget.state.themeProfile == AppThemeProfile.defaultDark,
                      ),
                      // Option 2: Night Vision Red
                      _buildThemeOption(
                        context,
                        title: 'Night Vision Red',
                        subtitle: 'Aviation OLED Black',
                        color: const Color(0xFFFF1744),
                        bgColor: const Color(0xFF030000),
                        profile: AppThemeProfile.nightVisionRed,
                        isSelected: widget.state.themeProfile == AppThemeProfile.nightVisionRed,
                      ),
                      // Option 3: Sunlight High-Contrast
                      _buildThemeOption(
                        context,
                        title: 'Sunlight Glare',
                        subtitle: 'High-Contrast Daylight',
                        color: const Color(0xFF000000),
                        bgColor: const Color(0xFFFFFFFF),
                        profile: AppThemeProfile.sunlightHighContrast,
                        isSelected: widget.state.themeProfile == AppThemeProfile.sunlightHighContrast,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Desktop & System Tray Settings Card
          ListenableBuilder(
            listenable: TrayAndWindowService.instance,
            builder: (context, _) {
              final trayService = TrayAndWindowService.instance;

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.2)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.desktop_windows_outlined, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          const Text(
                            'Desktop & System Tray Options',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Control window minimization and close behavior so NeighborNet can keep Reticulum mesh routing active in the background.',
                        style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 16),

                      // Quick Action Button
                      Row(
                        children: [
                          FilledButton.icon(
                            icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                            label: const Text('Minimize to System Tray'),
                            onPressed: () {
                              trayService.minimizeToTray();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('NeighborNet minimized to tray. Reticulum node continues running in the background.'),
                                  duration: Duration(seconds: 3),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),

                      // Option 1: Minimize Just to Tray
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Minimize Just to Tray',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        subtitle: const Text(
                          'When minimizing the window, hide completely from the taskbar into the system tray. Default: shows on taskbar AND in the system tray when app is running.',
                          style: TextStyle(fontSize: 12),
                        ),
                        value: trayService.minimizeToTrayOnly,
                        onChanged: (val) {
                          trayService.setMinimizeToTrayOnly(val);
                        },
                      ),

                      // Option 2: Send to Tray on Close (X)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Send to Tray When Closing (X)',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        subtitle: const Text(
                          'When clicking the window close button (X), send the app to the system tray instead of exiting, ensuring the community mesh remains alive.',
                          style: TextStyle(fontSize: 12),
                        ),
                        value: trayService.closeToTray,
                        onChanged: (val) {
                          trayService.setCloseToTray(val);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 20),

          // Network Parameters Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.2)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Networking Substrate Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildStatusRow('Stack Engine', 'Reticulum Network Stack (Rust Core)'),
                  _buildStatusRow('Cryptographic Keys', 'Ed25519 (Signing) + X25519 (ECDH)'),
                  _buildStatusRow('Bound UDP Port', '${status?.listenPort ?? 42424} (Local Wi-Fi & LAN)'),
                  _buildStatusRow('Operating Role', status?.isTransport == true ? 'Transport Node' : 'Edge / Leaf Node'),
                  _buildStatusRow('Active Peers', '${status?.peerCount ?? 0} direct peers connected'),
                  _buildStatusRow('Cached Bulletins', '${status?.bulletinCount ?? 0} signed DAG objects'),
                  _buildStatusRow('Node Uptime', '${status?.uptimeSec ?? 0} seconds'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Emergency Duress / Panic Wipe Card
          Card(
            elevation: 0,
            color: const Color(0xFF1E0A0E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFFF1744), width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Color(0xFFFF1744)),
                      SizedBox(width: 8),
                      Text(
                        'Duress Protocol / Panic Wipe',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFF5252),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'For hostile inspection or emergency device surrender. Securely shreds your private cryptographic identity (identity.hex), drops and vacuums local SQLite databases, purges file caches, and resets this node to a clean anonymous state.',
                    style: TextStyle(fontSize: 12, height: 1.4, color: Color(0xFFFFCDD2)),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFF1744),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.delete_forever_rounded, size: 18),
                    label: const Text('EXECUTE PANIC WIPE', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () => _showPanicWipeDialog(context),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Architectural Vision Card
          Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.2)),
            ),
            child: const Padding(
              padding: EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Resilience & Sovereignty Model', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text(
                    'NeighborNet operates entirely without external servers or cloud dependencies.\n'
                    '• Leaf nodes (phones/laptops) discover peers opportunistically on Wi-Fi and Bluetooth.\n'
                    '• Community hubs (Raspberry Pis) provide neighborhood persistent caching and routing.\n'
                    '• Municipal gateways link communities across town via LoRa, radio, and fiber.\n'
                    'If the Internet fails, your community continues to communicate seamlessly.',
                    style: TextStyle(fontSize: 12, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPanicWipeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF180306),
          title: const Row(
            children: [
              Icon(Icons.report_problem_rounded, color: Color(0xFFFF1744)),
              SizedBox(width: 8),
              Text('Confirm Emergency Wipe', style: TextStyle(color: Color(0xFFFF5252), fontSize: 18)),
            ],
          ),
          content: const Text(
            'WARNING: This action is permanent and irreversible.\n\n'
            '• Cryptographic identity will be shredded.\n'
            '• All SQLite message histories will be dropped.\n'
            '• Community room credentials will be purged.\n'
            '• Node will immediately reset to an anonymous identity.',
            style: TextStyle(color: Color(0xFFFFCDD2), fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF1744),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.of(ctx).pop();
                final ok = await widget.state.executePanicWipe();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: const Color(0xFF100002),
                      content: Text(
                        ok
                            ? '🚨 Emergency Panic Wipe completed: Node state wiped clean.'
                            : 'Failed to execute complete panic wipe.',
                        style: const TextStyle(color: Color(0xFFFF5252), fontWeight: FontWeight.bold),
                      ),
                      duration: const Duration(seconds: 4),
                    ),
                  );
                }
              },
              child: const Text('WIPE EVERYTHING NOW'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildThemeOption(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Color color,
    required Color bgColor,
    required AppThemeProfile profile,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () {
        widget.state.setThemeProfile(profile);
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 180,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: profile == AppThemeProfile.sunlightHighContrast ? Colors.black : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: color,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                color: profile == AppThemeProfile.sunlightHighContrast ? Colors.black87 : Colors.white70,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPaperKeyDialog(BuildContext context) {
    final phrase = widget.state.exportIdentityMnemonic() ?? '';
    final words = phrase.trim().split(RegExp(r'\s+'));

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.vpn_key_rounded, color: Colors.amber),
              SizedBox(width: 8),
              Text('Identity Paper Key (BIP-39)', style: TextStyle(fontSize: 18)),
            ],
          ),
          content: SizedBox(
            width: 580,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Write down these 48 BIP-39 recovery words on physical paper or store in a secure off-grid location. Anyone with these words can restore your cryptographic identity and room stewardship.',
                    style: TextStyle(fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  if (words.isEmpty || phrase.isEmpty)
                    const Text('No identity key loaded.', style: TextStyle(color: Colors.red))
                  else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(words.length, (idx) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${idx + 1}. ${words[idx]}',
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          );
                        }),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Copy Seed Words'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: phrase));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied 48-word mnemonic to clipboard!')),
                );
              },
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  void _showRestoreIdentityDialog(BuildContext context) {
    final textCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.restore_page_rounded, color: Colors.teal),
              SizedBox(width: 8),
              Text('Restore Cryptographic Identity', style: TextStyle(fontSize: 18)),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Paste your 48-word BIP-39 mnemonic seed phrase or 128-character raw hexadecimal key below:',
                  style: TextStyle(fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: textCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'e.g. word1 word2 word3 ... word48  OR  3ac6f1da7de1...',
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final input = textCtrl.text.trim();
                if (input.isNotEmpty) {
                  Navigator.of(ctx).pop();
                  final ok = await widget.state.restoreIdentity(input);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(ok
                            ? '✅ Identity successfully restored!'
                            : '❌ Failed to restore identity. Please check the seed words or hex key.'),
                      ),
                    );
                  }
                }
              },
              child: const Text('Restore Identity'),
            ),
          ],
        );
      },
    );
  }
}
