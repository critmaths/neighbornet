import 'package:flutter/material.dart';
import '../state/neighbornet_state.dart';

class EmergencyView extends StatelessWidget {
  final NeighborNetState state;

  const EmergencyView({super.key, required this.state});

  void _broadcastSos(BuildContext context) {
    final alertCtrl = TextEditingController(text: 'EMERGENCY: Immediate assistance requested at this location.');
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Broadcast Emergency Alert'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will broadcast an urgent emergency bulletin to all reachable local community nodes and transport repeaters.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: alertCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Emergency Details / Location',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              state.postBulletin(
                title: 'CRITICAL EMERGENCY ALERT',
                body: alertCtrl.text.trim(),
                urgency: 'emergency',
              );
              state.sendChatMessage('[CRITICAL EMERGENCY] ${alertCtrl.text.trim()}');
              Navigator.pop(dialogCtx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Emergency alert broadcast across all mesh interfaces!'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            child: const Text('BROADCAST ALERT NOW'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: ListView(
        children: [
          // Banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.red.shade900, Colors.red.shade700],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, size: 48, color: Colors.white),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'EMERGENCY MODE ACTIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Operating 100% peer-to-peer. Reticulum cryptographic mesh is active with ${state.nearbyCount} nearby node(s).',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.red.shade900,
                  ),
                  icon: const Icon(Icons.campaign_rounded),
                  label: const Text('SEND SOS ALERT'),
                  onPressed: () => _broadcastSos(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          const Text(
            'Offline Emergency Resources & Protocols',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // Resource Cards
          Row(
            children: [
              Expanded(
                child: _buildResourceCard(
                  context,
                  icon: Icons.water_drop_outlined,
                  color: Colors.blue,
                  title: 'Water Purification',
                  body: 'Boil vigorously for 1 full minute. If fuel unavailable, use 8 drops unscented 6% household bleach per gallon; let stand 30 minutes.',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildResourceCard(
                  context,
                  icon: Icons.radio_outlined,
                  color: Colors.orange,
                  title: 'Emergency Frequencies',
                  body: 'NOAA Weather: 162.400 - 162.550 MHz\nFRS/GMRS Channel 1: 462.5625 MHz\nReticulum LoRa: 915.000 MHz (BW: 125kHz, SF: 9)',
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildResourceCard(
                  context,
                  icon: Icons.medical_services_outlined,
                  color: Colors.red,
                  title: 'Medical Triage Protocol',
                  body: 'Direct pressure for severe bleeding. Keep injured warm to prevent shock. Clean wounds with boiled water. Do not remove penetrating objects.',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildResourceCard(
                  context,
                  icon: Icons.meeting_room_outlined,
                  color: Colors.green,
                  title: 'Community Check-in',
                  body: 'Default rendezvous: Civic Center Gym & Central High. Check in via NeighborNet #emergency channel to register status.',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResourceCard(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String body,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Icon(icon, size: 18, color: color),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              body,
              style: TextStyle(fontSize: 13, height: 1.4, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
