import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/neighbornet_models.dart';
import '../services/tray_and_window_service.dart';
import '../state/neighbornet_state.dart';
import '../widgets/qr_identity_dialog.dart';
import '../widgets/qr_scanner_dialog.dart';

class SettingsView extends StatefulWidget {
  final NeighborNetState state;

  const SettingsView({super.key, required this.state});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  late TextEditingController _nickCtrl;
  late TextEditingController _callsignCtrl;
  late TextEditingController _zoneCtrl;
  late TextEditingController _contactCtrl;
  late TextEditingController _bioCtrl;
  late TextEditingController _customSkillCtrl;
  late TextEditingController _webGatewayPortCtrl;
  late TextEditingController _dnsPortCtrl;
  List<String> _selectedSkills = [];
  String _selectedAvatar = 'default';

  String? _selectedPort;
  int _selectedFreqHz = 915000000;
  int _selectedSf = 10;
  final int _selectedBaud = 115200;

  @override
  void initState() {
    super.initState();
    final prof = widget.state.myProfile;
    _nickCtrl = TextEditingController(text: prof?.nickname ?? widget.state.status?.nickname ?? '');
    _callsignCtrl = TextEditingController(text: prof?.callsign ?? '');
    _zoneCtrl = TextEditingController(text: prof?.neighborhoodZone ?? '');
    _contactCtrl = TextEditingController(text: prof?.contactInfo ?? '');
    _bioCtrl = TextEditingController(text: prof?.bio ?? '');
    _customSkillCtrl = TextEditingController();
    _webGatewayPortCtrl = TextEditingController(text: widget.state.webGatewayPort.toString());
    _dnsPortCtrl = TextEditingController(text: widget.state.dnsServerPort.toString());
    _selectedSkills = List.from(prof?.skills ?? []);
    _selectedAvatar = (prof?.avatarBase64.isNotEmpty == true) ? prof!.avatarBase64 : 'default';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.state.refreshSerialPorts();
        widget.state.refreshMyProfile();
        widget.state.refreshWebGatewayStatus();
        widget.state.refreshDnsServerStatus();
      }
    });
  }

  @override
  void dispose() {
    _nickCtrl.dispose();
    _callsignCtrl.dispose();
    _zoneCtrl.dispose();
    _contactCtrl.dispose();
    _bioCtrl.dispose();
    _customSkillCtrl.dispose();
    _webGatewayPortCtrl.dispose();
    _dnsPortCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SettingsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final prof = widget.state.myProfile;
    if (_nickCtrl.text.isEmpty && prof != null) {
      _nickCtrl.text = prof.nickname;
      _callsignCtrl.text = prof.callsign;
      _zoneCtrl.text = prof.neighborhoodZone;
      _contactCtrl.text = prof.contactInfo;
      _bioCtrl.text = prof.bio;
      _selectedSkills = List.from(prof.skills);
      _selectedAvatar = prof.avatarBase64.isNotEmpty ? prof.avatarBase64 : 'default';
    }
  }


  Widget _buildAvatarOption(String key, IconData icon, Color color, String label) {
    final isSelected = _selectedAvatar == key;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedAvatar = key;
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.25) : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : Theme.of(context).dividerColor.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? color : Theme.of(context).colorScheme.onSurfaceVariant, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.state.status;
    final lora = widget.state.loraStatus;
    final ports = widget.state.serialPorts;

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
            'Configure your community presence, LoRa hardware transceiver, and cryptographic keys',
            style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),

          const SizedBox(height: 24),

          // Sovereign Profile & Tactical Identity Card
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
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.badge_outlined, color: Colors.amber, size: 22),
                          SizedBox(width: 10),
                          Text(
                            'Sovereign Profile & Tactical Identity',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_outline_rounded, color: Colors.green, size: 14),
                            SizedBox(width: 4),
                            Text(
                              'Cryptographically Signed',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Your local-first profile broadcasted across the mesh DAG to peers. All fields are optional and stored on your hardware.',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 20),

                  // Avatar preset selector
                  const Text('Tactical Avatar Badge:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _buildAvatarOption('default', Icons.person_outline_rounded, Colors.blueGrey, 'Standard'),
                      _buildAvatarOption('tactical_medic', Icons.medical_services_outlined, Colors.redAccent, 'Medic / CERT'),
                      _buildAvatarOption('tactical_radio', Icons.radio_outlined, Colors.cyan, 'Radio Comms'),
                      _buildAvatarOption('tactical_solar', Icons.bolt_outlined, Colors.amber, 'Solar / Power'),
                      _buildAvatarOption('tactical_shield', Icons.shield_outlined, Colors.purpleAccent, 'Security'),
                      _buildAvatarOption('tactical_water', Icons.water_drop_outlined, Colors.lightBlueAccent, 'Water / Supply'),
                      _buildAvatarOption('tactical_recon', Icons.explore_outlined, Colors.orangeAccent, 'Recon / Scout'),
                      _buildAvatarOption('tactical_engineer', Icons.handyman_outlined, Colors.teal, 'Engineer'),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Form Fields
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nickCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Display Nickname',
                            hintText: 'e.g. Alice Alpha',
                            prefixIcon: Icon(Icons.person_rounded, size: 18),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _callsignCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Radio / Tactical Callsign',
                            hintText: 'e.g. KD9XYZ / Unit-4',
                            prefixIcon: Icon(Icons.cell_tower_rounded, size: 18),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _zoneCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Neighborhood Sector / Grid Square',
                            hintText: 'e.g. Oak Ridge / Grid B-4',
                            prefixIcon: Icon(Icons.location_on_outlined, size: 18),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _contactCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Alternate Contact / Comms Channel',
                            hintText: 'e.g. Signal: @alice / 146.520 MHz',
                            prefixIcon: Icon(Icons.contact_mail_outlined, size: 18),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  TextField(
                    controller: _bioCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Bio / Mission & Capabilities',
                      hintText: 'Brief summary of your field role, capabilities, equipment, or mutual aid offerings...',
                      prefixIcon: Icon(Icons.description_outlined, size: 18),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Skills & Capabilities Matrix
                  Row(
                    children: [
                      const Text(
                        'Skills & Mutual Aid Capabilities:',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      Text(
                        '${_selectedSkills.length} selected',
                        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: kStandardTacticalSkills.map((skill) {
                      final isSelected = _selectedSkills.contains(skill);
                      return FilterChip(
                        label: Text(skill, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedSkills.add(skill);
                            } else {
                              _selectedSkills.remove(skill);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 12),

                  // Custom Skill Adder
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _customSkillCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Add Custom Skill or Equipment Tag',
                            hintText: 'e.g. Chainsaw / Drone Pilot / Generator',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onSubmitted: (val) {
                            final trimmed = val.trim();
                            if (trimmed.isNotEmpty && !_selectedSkills.contains(trimmed)) {
                              setState(() {
                                _selectedSkills.add(trimmed);
                                _customSkillCtrl.clear();
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        icon: const Icon(Icons.add_rounded),
                        tooltip: 'Add Custom Skill',
                        onPressed: () {
                          final trimmed = _customSkillCtrl.text.trim();
                          if (trimmed.isNotEmpty && !_selectedSkills.contains(trimmed)) {
                            setState(() {
                              _selectedSkills.add(trimmed);
                              _customSkillCtrl.clear();
                            });
                          }
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Destination Hash container
                  const Text('Reticulum Sovereign Address Hash:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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
                                const SnackBar(content: Text('Copied sovereign address to clipboard!')),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Actions: QR Identity Card, Scan QR, and Save & Broadcast
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    alignment: WrapAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                        label: const Text('Air-Gapped QR Card'),
                        onPressed: () {
                          final currentProf = widget.state.myProfile ??
                              UserProfile(
                                destHash: status?.destHash ?? '',
                                nickname: _nickCtrl.text.trim().isEmpty ? (status?.nickname ?? 'Neighbor') : _nickCtrl.text.trim(),
                                callsign: _callsignCtrl.text.trim(),
                                neighborhoodZone: _zoneCtrl.text.trim(),
                                contactInfo: _contactCtrl.text.trim(),
                                bio: _bioCtrl.text.trim(),
                                skills: _selectedSkills,
                                avatarBase64: _selectedAvatar,
                              );
                          QrIdentityDialog.show(context, currentProf);
                        },
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                        label: const Text('Scan / Import QR'),
                        onPressed: () {
                          QrScannerDialog.show(context);
                        },
                      ),
                      FilledButton.icon(
                        icon: const Icon(Icons.cell_tower_rounded, size: 18),
                        label: const Text('Save & Broadcast Profile to Mesh'),
                        onPressed: () {
                          final nick = _nickCtrl.text.trim().isEmpty ? (status?.nickname ?? 'Neighbor') : _nickCtrl.text.trim();
                          final newProf = UserProfile(
                            destHash: status?.destHash ?? '',
                            nickname: nick,
                            callsign: _callsignCtrl.text.trim(),
                            neighborhoodZone: _zoneCtrl.text.trim(),
                            contactInfo: _contactCtrl.text.trim(),
                            bio: _bioCtrl.text.trim(),
                            skills: _selectedSkills,
                            avatarBase64: _selectedAvatar,
                            updatedAtSec: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                          );
                          final ok = widget.state.updateMyProfile(newProf);
                          if (ok) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Tactical Profile saved and broadcasted to mesh peers!'),
                                backgroundColor: Colors.teal,
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // LoRa Tactical Mesh Radio Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: lora?.isConnected == true
                    ? Colors.greenAccent.withValues(alpha: 0.6)
                    : Theme.of(context).dividerColor.withValues(alpha: 0.2),
                width: lora?.isConnected == true ? 1.5 : 1.0,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.settings_input_antenna_rounded,
                            color: lora?.isConnected == true ? Colors.greenAccent : Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'LoRa Tactical Radio (KISS / RNode)',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: lora?.isConnected == true
                              ? Colors.green.withValues(alpha: 0.2)
                              : Colors.grey.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: lora?.isConnected == true ? Colors.greenAccent : Colors.grey,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: lora?.isConnected == true ? Colors.greenAccent : Colors.grey,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              lora?.isConnected == true ? 'CONNECTED & TRANSCEIVING' : 'DISCONNECTED',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: lora?.isConnected == true ? Colors.greenAccent : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Direct long-range sovereign RF mesh communications without internet, Wi-Fi, or cellular infrastructure. Connect a Heltec, T-Beam, or SX1262 USB transceiver.',
                    style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),

                  // Serial Port Selector & Refresh
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: _selectedPort ?? (ports.isNotEmpty ? ports.first.portName : null),
                          decoration: const InputDecoration(
                            labelText: 'Serial Port / USB Hardware Interface',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: ports.isEmpty
                              ? [
                                  const DropdownMenuItem(
                                    value: null,
                                    child: Text('No serial devices detected (Click Scan)', overflow: TextOverflow.ellipsis),
                                  )
                                ]
                              : ports.map((p) {
                                  return DropdownMenuItem(
                                    value: p.portName,
                                    child: Text(p.displayName, overflow: TextOverflow.ellipsis),
                                  );
                                }).toList(),
                          onChanged: lora?.isConnected == true
                              ? null
                              : (val) {
                                  setState(() {
                                    _selectedPort = val;
                                  });
                                },
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton.filledTonal(
                        icon: widget.state.isLoraScanning
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh_rounded),
                        tooltip: 'Scan Serial Ports',
                        onPressed: lora?.isConnected == true
                            ? null
                            : () {
                                widget.state.refreshSerialPorts();
                              },
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Frequency & Spreading Factor Selectors
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          isExpanded: true,
                          initialValue: _selectedFreqHz,
                          decoration: const InputDecoration(
                            labelText: 'Region / Frequency Band',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: const [
                            DropdownMenuItem(value: 915000000, child: Text('915.0 MHz (US / Americas ISM)', overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 868000000, child: Text('868.0 MHz (EU / UK ISM)', overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 433000000, child: Text('433.0 MHz (Asia / Ham radio)', overflow: TextOverflow.ellipsis)),
                          ],
                          onChanged: lora?.isConnected == true
                              ? null
                              : (val) {
                                  if (val != null) setState(() => _selectedFreqHz = val);
                                },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          isExpanded: true,
                          initialValue: _selectedSf,
                          decoration: const InputDecoration(
                            labelText: 'Spreading Factor (RF Modulation)',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: const [
                            DropdownMenuItem(value: 7, child: Text('SF7 (Fastest / Short Range)', overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 10, child: Text('SF10 (Standard / High Reliability)', overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 12, child: Text('SF12 (Maximum Distance Penetration)', overflow: TextOverflow.ellipsis)),
                          ],
                          onChanged: lora?.isConnected == true
                              ? null
                              : (val) {
                                  if (val != null) setState(() => _selectedSf = val);
                                },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Connect / Disconnect Action and Telemetry
                  Row(
                    children: [
                      if (lora?.isConnected != true)
                        FilledButton.icon(
                          icon: const Icon(Icons.cable_rounded, size: 18),
                          label: const Text('Connect LoRa Radio'),
                          onPressed: () async {
                            final port = _selectedPort ?? (ports.isNotEmpty ? ports.first.portName : null);
                            if (port == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please select or scan a serial port first.')),
                              );
                              return;
                            }
                            final ok = await widget.state.connectLoraRadio(
                              portName: port,
                              baudRate: _selectedBaud,
                              freqHz: _selectedFreqHz,
                              sf: _selectedSf,
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(ok
                                      ? '✅ Connected to LoRa hardware on $port (${_selectedFreqHz ~/ 1000000} MHz)!'
                                      : '❌ Failed to connect to LoRa radio on $port.'),
                                ),
                              );
                            }
                          },
                        )
                      else
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.power_settings_new_rounded, size: 18),
                          label: const Text('Disconnect LoRa Radio'),
                          onPressed: () async {
                            await widget.state.disconnectLoraRadio();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Disconnected LoRa transceiver.')),
                              );
                            }
                          },
                        ),
                      const SizedBox(width: 16),
                      if (lora != null && lora.isConnected) ...[
                        Text(
                          'TX: ${lora.txPackets} pkts | RX: ${lora.rxPackets} pkts | RSSI: ${lora.lastRssi} dBm | SNR: ${lora.lastSnr} dB',
                          style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Cryptographic Key Backup & Portability Card
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
                      Icon(Icons.vpn_key_rounded, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      const Text(
                        'Cryptographic Key Backup & Portability',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Export your sovereign Reticulum private identity as a human-readable BIP-39 mnemonic seed phrase ("Paper Key") or restore an existing identity from words or raw hex.',
                    style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.tonalIcon(
                        icon: const Icon(Icons.description_outlined, size: 18),
                        label: const Text('Backup Paper Key (48 BIP-39 Words)'),
                        onPressed: () => _showPaperKeyDialog(context),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.restore_rounded, size: 18),
                        label: const Text('Restore Identity from Seed / Hex'),
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
                      _buildThemeOption(
                        context,
                        title: 'Cyber Amber',
                        subtitle: 'Default Dark',
                        color: const Color(0xFFF59E0B),
                        bgColor: const Color(0xFF0B0F19),
                        profile: AppThemeProfile.defaultDark,
                        isSelected: widget.state.themeProfile == AppThemeProfile.defaultDark,
                      ),
                      _buildThemeOption(
                        context,
                        title: 'Night Vision Red',
                        subtitle: 'Aviation OLED Black',
                        color: const Color(0xFFFF1744),
                        bgColor: const Color(0xFF030000),
                        profile: AppThemeProfile.nightVisionRed,
                        isSelected: widget.state.themeProfile == AppThemeProfile.nightVisionRed,
                      ),
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
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Minimize Just to Tray',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        subtitle: const Text(
                          'When minimizing the window, hide completely from the taskbar into the system tray.',
                          style: TextStyle(fontSize: 12),
                        ),
                        value: trayService.minimizeToTrayOnly,
                        onChanged: (val) {
                          trayService.setMinimizeToTrayOnly(val);
                        },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Send to Tray When Closing (X)',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        subtitle: const Text(
                          'When clicking the window close button (X), send the app to the system tray instead of exiting.',
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

          // Zero-Install Web Gateway & Captive Portal Card
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.wifi_tethering_rounded,
                            color: widget.state.isWebGatewayRunning ? Colors.greenAccent : Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Zero-Install Web Gateway & Captive Portal',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: widget.state.isWebGatewayRunning
                              ? Colors.green.withValues(alpha: 0.2)
                              : Colors.grey.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: widget.state.isWebGatewayRunning ? Colors.greenAccent : Colors.grey,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: widget.state.isWebGatewayRunning ? Colors.greenAccent : Colors.grey,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              widget.state.isWebGatewayRunning ? 'PORTAL ACTIVE' : 'PORTAL STOPPED',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: widget.state.isWebGatewayRunning ? Colors.greenAccent : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Allows neighborhood residents without NeighborNet installed to join mesh communications through any web browser. Captive Portal Probe Interception redirects iOS, Android, and Windows devices automatically.',
                    style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      SizedBox(
                        width: 140,
                        child: TextField(
                          controller: _webGatewayPortCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'HTTP Port',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (val) {
                            final p = int.tryParse(val);
                            if (p != null) {
                              widget.state.setWebGatewayPort(p);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        icon: Icon(widget.state.isWebGatewayRunning ? Icons.stop_rounded : Icons.play_arrow_rounded),
                        label: Text(widget.state.isWebGatewayRunning ? 'Stop Gateway' : 'Start Web Gateway'),
                        style: FilledButton.styleFrom(
                          backgroundColor: widget.state.isWebGatewayRunning ? Colors.redAccent : null,
                        ),
                        onPressed: () {
                          final p = int.tryParse(_webGatewayPortCtrl.text) ?? 8080;
                          if (widget.state.isWebGatewayRunning) {
                            widget.state.stopWebGateway();
                          } else {
                            widget.state.startWebGateway(p);
                          }
                        },
                      ),
                      if (widget.state.isWebGatewayRunning) ...[
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          label: Text(widget.state.webGatewayUrl),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: widget.state.webGatewayUrl));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Web Gateway URL copied to clipboard!')),
                            );
                          },
                        ),
                      ],
                    ],
                  ),

                  const Divider(height: 32),

                  // Captive DNS Redirection Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.dns_rounded,
                            color: widget.state.isDnsServerRunning ? Colors.cyanAccent : Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Hotspot Captive DNS Auto-Redirect',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: widget.state.isDnsServerRunning
                              ? Colors.cyan.withValues(alpha: 0.2)
                              : Colors.grey.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: widget.state.isDnsServerRunning ? Colors.cyanAccent : Colors.grey,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: widget.state.isDnsServerRunning ? Colors.cyanAccent : Colors.grey,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              widget.state.isDnsServerRunning ? 'DNS ACTIVE' : 'DNS STOPPED',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: widget.state.isDnsServerRunning ? Colors.cyanAccent : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Embedded RFC 1035 UDP DNS server that redirects all domain queries (* -> ${widget.state.dnsTargetIp}) on field Wi-Fi hotspots, prompting iOS, Android, and Windows devices to open the NeighborNet portal automatically.',
                    style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      SizedBox(
                        width: 140,
                        child: TextField(
                          controller: _dnsPortCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'UDP DNS Port',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (val) {
                            final p = int.tryParse(val);
                            if (p != null) {
                              widget.state.setDnsServerPort(p);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        icon: Icon(widget.state.isDnsServerRunning ? Icons.stop_rounded : Icons.play_arrow_rounded),
                        label: Text(widget.state.isDnsServerRunning ? 'Stop DNS' : 'Start DNS Redirect'),
                        style: FilledButton.styleFrom(
                          backgroundColor: widget.state.isDnsServerRunning ? Colors.redAccent : Colors.cyan.shade800,
                        ),
                        onPressed: () {
                          final p = int.tryParse(_dnsPortCtrl.text) ?? 53;
                          if (widget.state.isDnsServerRunning) {
                            widget.state.stopDnsServer();
                          } else {
                            widget.state.startDnsServer(port: p);
                          }
                        },
                      ),
                      if (widget.state.isDnsServerRunning) ...[
                        const SizedBox(width: 12),
                        Chip(
                          avatar: const Icon(Icons.check_circle_outline_rounded, size: 16, color: Colors.cyanAccent),
                          label: Text('Answered: ${widget.state.dnsServerStatus?.queriesAnswered ?? 0} queries'),
                        ),
                      ],
                    ],
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

  void _showPaperKeyDialog(BuildContext context) {
    final mnemonic = widget.state.exportIdentityMnemonic();
    if (mnemonic == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to read cryptographic identity mnemonic.')),
      );
      return;
    }

    final words = mnemonic.split(' ');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.vpn_key_rounded, color: Colors.amber),
              SizedBox(width: 8),
              Text('48-Word Paper Key'),
            ],
          ),
          content: SizedBox(
            width: 540,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Write down these 48 BIP-39 words on paper. Store them safely in a secure, waterproof location. This seed phrase will restore your entire cryptographic address and private key if your device is destroyed.',
                  style: TextStyle(fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                  ),
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(words.length, (idx) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${idx + 1}. ${words[idx]}',
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Copy to Clipboard'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: mnemonic));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('48-word mnemonic copied to clipboard!')),
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
    final ctrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Restore Cryptographic Identity'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enter your 48-word BIP-39 mnemonic seed phrase (or 128-character raw hex private key):',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'word1 word2 word3 ... or raw hex',
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
              onPressed: () {
                final input = ctrl.text.trim();
                if (input.isEmpty) return;
                Navigator.of(ctx).pop();
                final newHash = widget.state.restoreIdentity(input);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(newHash != null
                          ? '✅ Identity successfully restored! New address hash: $newHash'
                          : '❌ Failed to restore identity. Invalid seed phrase or hex key.'),
                    ),
                  );
                }
              },
              child: const Text('Restore Identity'),
            ),
          ],
        );
      },
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
}
