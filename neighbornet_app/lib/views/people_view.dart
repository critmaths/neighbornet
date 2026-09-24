import 'package:flutter/material.dart';
import '../models/neighbornet_models.dart';
import '../state/neighbornet_state.dart';

class PeopleView extends StatelessWidget {
  final NeighborNetState state;

  const PeopleView({super.key, required this.state});

  void _startCall(BuildContext context, PeerInfo peer, {bool withVideo = false}) {
    state.startCallWithPeer(peer, withVideo: withVideo);
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
    final peers = state.peers;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

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

          const SizedBox(height: 20),

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
              ],
            ),
          ),

          const SizedBox(height: 16),

          Expanded(
            child: peers.isEmpty
                ? Center(
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
                  )
                : ListView.builder(
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
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: peer.isTransport ? Colors.deepPurple.shade100 : Colors.blue.shade100,
                            child: Icon(
                              peer.isTransport ? Icons.router_outlined : Icons.person_outline,
                              color: peer.isTransport ? Colors.deepPurple : Colors.blue,
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(
                                peer.nickname,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 8),
                              if (peer.isTransport)
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
                                  state.selectDirectMessage(peer);
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
                  ),
          ),
        ],
      ),
    );
  }
}
