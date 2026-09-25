import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/neighbornet_models.dart';
import '../state/neighbornet_state.dart';

class PeopleView extends StatefulWidget {
  final NeighborNetState state;

  const PeopleView({super.key, required this.state});

  @override
  State<PeopleView> createState() => _PeopleViewState();
}

class _PeopleViewState extends State<PeopleView> with SingleTickerProviderStateMixin {
  int _viewMode = 0; // 0: List, 1: Radar / Topology Map
  PeerInfo? _selectedPeer;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }


  Widget _buildTacticalAvatarBadge(String avatarKey, bool isTransport, {double radius = 20}) {
    IconData icon;
    Color color;
    switch (avatarKey) {
      case 'tactical_medic':
        icon = Icons.medical_services_outlined;
        color = Colors.redAccent;
        break;
      case 'tactical_radio':
        icon = Icons.radio_outlined;
        color = Colors.cyan;
        break;
      case 'tactical_solar':
        icon = Icons.bolt_outlined;
        color = Colors.amber;
        break;
      case 'tactical_shield':
        icon = Icons.shield_outlined;
        color = Colors.purpleAccent;
        break;
      case 'tactical_water':
        icon = Icons.water_drop_outlined;
        color = Colors.lightBlueAccent;
        break;
      case 'tactical_recon':
        icon = Icons.explore_outlined;
        color = Colors.orangeAccent;
        break;
      case 'tactical_engineer':
        icon = Icons.handyman_outlined;
        color = Colors.teal;
        break;
      default:
        icon = isTransport ? Icons.router_outlined : Icons.person_outline_rounded;
        color = isTransport ? Colors.deepPurple : Colors.blueGrey;
        break;
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withValues(alpha: 0.2),
      child: Icon(icon, color: color, size: radius * 1.1),
    );
  }

  void _showTacticalProfileDialog(BuildContext context, PeerInfo peer) {
    final profile = widget.state.getProfileForPeer(peer.destHash);
    final avatarKey = profile?.avatarBase64 ?? '';

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          title: Row(
            children: [
              _buildTacticalAvatarBadge(avatarKey, peer.isTransport, radius: 24),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            profile?.nickname.isNotEmpty == true ? profile!.nickname : peer.nickname,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (peer.isTransport) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'RELAY',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (profile?.callsign.isNotEmpty == true)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.cyan.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.cyan.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.cell_tower_rounded, size: 12, color: Colors.cyan),
                                const SizedBox(width: 4),
                                Text(
                                  profile!.callsign,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.cyan),
                                ),
                              ],
                            ),
                          ),
                        if (profile?.neighborhoodZone.isNotEmpty == true)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.location_on_outlined, size: 12, color: Colors.amber),
                                const SizedBox(width: 4),
                                Text(
                                  profile!.neighborhoodZone,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Divider(),
                  const SizedBox(height: 10),

                  // Cryptographic Sovereign Verification
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(dialogCtx).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.verified_user_rounded, color: Colors.green, size: 15),
                            SizedBox(width: 6),
                            Text(
                              'Verified Reticulum Sovereign Key',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: SelectableText(
                                peer.destHash,
                                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 16),
                              tooltip: 'Copy Key Hash',
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: peer.destHash));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Copied hash to clipboard!')),
                                );
                              },
                            ),
                          ],
                        ),
                        Text(
                          'Transport link: ${peer.addr}',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),

                  // Bio Section
                  if (profile?.bio.isNotEmpty == true) ...[
                    const SizedBox(height: 16),
                    const Text('Field Role / Mission Summary:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(dialogCtx).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        profile!.bio,
                        style: const TextStyle(fontSize: 13, height: 1.3),
                      ),
                    ),
                  ],

                  // Skills & Capabilities Matrix
                  if (profile != null && profile.skills.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text('Emergency Skills & Mutual Aid Capabilities:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: profile.skills.map((skill) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(dialogCtx).colorScheme.primaryContainer.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Theme.of(dialogCtx).colorScheme.primary.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            skill,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(dialogCtx).colorScheme.primary,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  // Alternate Contact
                  if (profile?.contactInfo.isNotEmpty == true) ...[
                    const SizedBox(height: 16),
                    const Text('Alternate Contact / Comms Channel:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    SelectableText(
                      profile!.contactInfo,
                      style: const TextStyle(fontSize: 12, color: Colors.tealAccent),
                    ),
                  ],

                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          actions: [
            FilledButton.tonalIcon(
              icon: const Icon(Icons.phone_rounded, size: 16),
              label: const Text('Voice Call'),
              onPressed: () {
                Navigator.pop(dialogCtx);
                _startCall(context, peer, withVideo: false);
              },
            ),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.videocam_rounded, size: 16),
              label: const Text('Video Call'),
              onPressed: () {
                Navigator.pop(dialogCtx);
                _startCall(context, peer, withVideo: true);
              },
            ),
            FilledButton.icon(
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
              label: const Text('Direct Whisper'),
              onPressed: () {
                Navigator.pop(dialogCtx);
                widget.state.selectDirectMessage(peer);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Switched to Direct Whisper with ${peer.nickname} (E2EE)'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _startCall(BuildContext context, PeerInfo peer, {bool withVideo = false}) {
    widget.state.startCallWithPeer(peer, withVideo: withVideo);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(withVideo ? Icons.videocam : Icons.phone, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Calling ${peer.nickname} (${withVideo ? "Video" : "Voice"})... Signaled over mesh.',
              ),
            ),
          ],
        ),
        backgroundColor: Colors.teal,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final peers = widget.state.peers;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final transportCount = peers.where((p) => p.isTransport).length;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'People & Nodes',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Discovered cryptographic participants on local Wi-Fi, Ethernet, and mesh links',
                      style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment<int>(
                    value: 0,
                    icon: Icon(Icons.format_list_bulleted_rounded, size: 18),
                    label: Text('List'),
                  ),
                  ButtonSegment<int>(
                    value: 1,
                    icon: Icon(Icons.radar_rounded, size: 18),
                    label: Text('Radar Map'),
                  ),
                ],
                selected: {_viewMode},
                onSelectionChanged: (val) {
                  setState(() {
                    _viewMode = val.first;
                    _selectedPeer = null;
                  });
                },
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: (peers.isNotEmpty ? Colors.green : Colors.amber).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: peers.isNotEmpty ? Colors.green : Colors.amber,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${peers.length} Nearby ${peers.length == 1 ? 'Peer' : 'Peers'}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: peers.isNotEmpty ? Colors.green.shade900 : Colors.amber.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Authenticity Rule Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_user_outlined, size: 18, color: Colors.blue),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Zero Fake Nodes Policy: All participants below are verified cryptographically via Reticulum Ed25519/X25519 destination hashes.',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
                if (transportCount > 0) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$transportCount Transport ${transportCount == 1 ? "Relay" : "Relays"} Active',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          Expanded(
            child: _viewMode == 0
                ? _buildListView(context, peers, now)
                : _buildRadarView(context, peers, now),
          ),
        ],
      ),
    );
  }

  Widget _buildListView(BuildContext context, List<PeerInfo> peers, int now) {
    if (peers.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(height: 16),
            const Text(
              'Listening for nearby Reticulum announcements...',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            const Text(
              'Ensure other devices on your Wi-Fi/LAN are running NeighborNet.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: peers.length,
      itemBuilder: (context, index) {
        final peer = peers[index];
        final secondsAgo = now.clamp(peer.lastSeenEpochSec, now) - peer.lastSeenEpochSec;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
            ),
          ),
          child: ListTile(
            onTap: () => _showTacticalProfileDialog(context, peer),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: _buildTacticalAvatarBadge(
              widget.state.getProfileForPeer(peer.destHash)?.avatarBase64 ?? '',
              peer.isTransport,
            ),
            title: Row(
              children: [
                Text(
                  widget.state.getProfileForPeer(peer.destHash)?.nickname.isNotEmpty == true
                      ? widget.state.getProfileForPeer(peer.destHash)!.nickname
                      : peer.nickname,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                if (widget.state.getProfileForPeer(peer.destHash)?.callsign.isNotEmpty == true)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.cyan.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      widget.state.getProfileForPeer(peer.destHash)!.callsign,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.cyan),
                    ),
                  ),
                if (peer.isTransport) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'TRANSPORT NODE',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  'RNS Hash: ${peer.destHash}',
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.grey),
                ),
                const SizedBox(height: 2),
                Text(
                  'Address: ${peer.addr} • Last seen ${secondsAgo}s ago',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton.filledTonal(
                  icon: const Icon(Icons.badge_outlined, size: 18),
                  tooltip: 'Inspect Tactical Profile',
                  onPressed: () => _showTacticalProfileDialog(context, peer),
                ),
                const SizedBox(width: 6),
                IconButton.filledTonal(
                  icon: const Icon(Icons.phone_rounded, size: 18),
                  tooltip: '1-Tap Voice Call',
                  onPressed: () => _startCall(context, peer, withVideo: false),
                ),
                const SizedBox(width: 6),
                IconButton.filledTonal(
                  icon: const Icon(Icons.videocam_rounded, size: 18),
                  tooltip: '1-Tap Video Call',
                  onPressed: () => _startCall(context, peer, withVideo: true),
                ),
                const SizedBox(width: 6),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                  label: const Text('Direct Whisper'),
                  onPressed: () {
                    widget.state.selectDirectMessage(peer);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Switched to Direct Whisper with ${peer.nickname} (E2EE)'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRadarView(BuildContext context, List<PeerInfo> peers, int now) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final center = Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);
        final maxRadius = math.min(constraints.maxWidth, constraints.maxHeight) * 0.42;

        return Stack(
          children: [
            // Canvas for radar background & links
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return CustomPaint(
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                  painter: _MeshRadarPainter(
                    pulseValue: _pulseController.value,
                    peers: peers,
                    center: center,
                    maxRadius: maxRadius,
                    theme: Theme.of(context),
                  ),
                );
              },
            ),

            // Center Node (Local Node)
            Positioned(
              left: center.dx - 32,
              top: center.dy - 32,
              child: Tooltip(
                message: 'You (${widget.state.status?.nickname ?? "Local Node"})\n${widget.state.status?.destHash ?? ""}',
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withValues(alpha: 0.4),
                        blurRadius: 16,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.hub_rounded, color: Colors.white, size: 22),
                        Text(
                          'YOU',
                          style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Orbital Peer Nodes
            ...peers.asMap().entries.map((entry) {
              final idx = entry.key;
              final peer = entry.value;
              final angle = (2 * math.pi / peers.length) * idx - (math.pi / 2);
              final distance = maxRadius * (0.55 + (idx % 3) * 0.15);
              final x = center.dx + distance * math.cos(angle);
              final y = center.dy + distance * math.sin(angle);

              final isSelected = _selectedPeer?.destHash == peer.destHash;

              return Positioned(
                left: x - 28,
                top: y - 28,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedPeer = isSelected ? null : peer;
                    });
                  },
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: peer.isTransport ? Colors.deepPurple : Colors.blue.shade700,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.amber : Colors.white,
                        width: isSelected ? 3 : 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (peer.isTransport ? Colors.deepPurple : Colors.blue).withValues(alpha: isSelected ? 0.6 : 0.3),
                          blurRadius: isSelected ? 14 : 8,
                          spreadRadius: isSelected ? 3 : 1,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            peer.isTransport ? Icons.router_outlined : Icons.person,
                            color: Colors.white,
                            size: 18,
                          ),
                          Text(
                            peer.nickname.length > 5 ? peer.nickname.substring(0, 5) : peer.nickname,
                            style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),

            // Selected Peer Details Overlay Card
            if (_selectedPeer != null)
              Positioned(
                bottom: 16,
                left: 24,
                right: 24,
                child: _buildPeerDetailCard(context, _selectedPeer!, now),
              ),

            // Empty state overlay
            if (peers.isEmpty)
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.2)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 12),
                      Text('Scanning mesh frequencies for nearby nodes...', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildPeerDetailCard(BuildContext context, PeerInfo peer, int now) {
    final secondsAgo = now.clamp(peer.lastSeenEpochSec, now) - peer.lastSeenEpochSec;

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: peer.isTransport ? Colors.deepPurple.shade100 : Colors.blue.shade100,
              child: Icon(
                peer.isTransport ? Icons.router_outlined : Icons.person,
                color: peer.isTransport ? Colors.deepPurple : Colors.blue,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(peer.nickname, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(width: 8),
                      if (peer.isTransport)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('TRANSPORT RELAY', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Hash: ${peer.destHash} • Address: ${peer.addr} • Last seen ${secondsAgo}s ago',
                    style: const TextStyle(fontSize: 11, color: Colors.grey, fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            IconButton.filledTonal(
              icon: const Icon(Icons.phone_rounded, size: 18),
              tooltip: 'Voice Call',
              onPressed: () => _startCall(context, peer, withVideo: false),
            ),
            const SizedBox(width: 6),
            IconButton.filledTonal(
              icon: const Icon(Icons.videocam_rounded, size: 18),
              tooltip: 'Video Call',
              onPressed: () => _startCall(context, peer, withVideo: true),
            ),
            const SizedBox(width: 6),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
              label: const Text('Direct Whisper'),
              onPressed: () {
                widget.state.selectDirectMessage(peer);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Switched to Direct Whisper with ${peer.nickname} (E2EE)'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
            const SizedBox(width: 6),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: () => setState(() => _selectedPeer = null),
            ),
          ],
        ),
      ),
    );
  }
}

class _MeshRadarPainter extends CustomPainter {
  final double pulseValue;
  final List<PeerInfo> peers;
  final Offset center;
  final double maxRadius;
  final ThemeData theme;

  _MeshRadarPainter({
    required this.pulseValue,
    required this.peers,
    required this.center,
    required this.maxRadius,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final ringPaint = Paint()
      ..color = theme.dividerColor.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Draw concentric radar rings
    for (int i = 1; i <= 4; i++) {
      final r = maxRadius * (i / 4.0);
      canvas.drawCircle(center, r, ringPaint);
    }

    // Draw radar crosshairs
    final crossPaint = Paint()
      ..color = theme.dividerColor.withValues(alpha: 0.1)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(center.dx - maxRadius, center.dy), Offset(center.dx + maxRadius, center.dy), crossPaint);
    canvas.drawLine(Offset(center.dx, center.dy - maxRadius), Offset(center.dx, center.dy + maxRadius), crossPaint);

    // Draw animated pulse wave
    final pulseRadius = maxRadius * pulseValue;
    final pulsePaint = Paint()
      ..color = Colors.green.withValues(alpha: 0.25 * (1.0 - pulseValue))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, pulseRadius, pulsePaint);

    // Draw connecting mesh lines to peers
    for (int idx = 0; idx < peers.length; idx++) {
      final peer = peers[idx];
      final angle = (2 * math.pi / peers.length) * idx - (math.pi / 2);
      final distance = maxRadius * (0.55 + (idx % 3) * 0.15);
      final peerPos = Offset(center.dx + distance * math.cos(angle), center.dy + distance * math.sin(angle));

      final linkPaint = Paint()
        ..color = (peer.isTransport ? Colors.deepPurple : Colors.teal).withValues(alpha: 0.4)
        ..strokeWidth = peer.isTransport ? 2.0 : 1.2;
      canvas.drawLine(center, peerPos, linkPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MeshRadarPainter oldDelegate) {
    return oldDelegate.pulseValue != pulseValue || oldDelegate.peers.length != peers.length;
  }
}
