import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
                ],
              ),
            ),
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
}
