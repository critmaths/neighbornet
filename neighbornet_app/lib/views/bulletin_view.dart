import 'package:flutter/material.dart';
import '../state/neighbornet_state.dart';

class BulletinView extends StatefulWidget {
  final NeighborNetState state;

  const BulletinView({super.key, required this.state});

  @override
  State<BulletinView> createState() => _BulletinViewState();
}

class _BulletinViewState extends State<BulletinView> {
  String _selectedFilter = 'all';

  void _showPostDialog() {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    String urgency = 'normal';

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Post Community Notice'),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Headline',
                    hintText: 'e.g. Clean Water Available at Civic Gym',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bodyCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Details / Instructions',
                    hintText: 'Describe resources, location, schedule, or needs...',
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Urgency Level:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'normal', label: Text('Normal')),
                    ButtonSegment(value: 'urgent', label: Text('Urgent')),
                    ButtonSegment(value: 'emergency', label: Text('Emergency')),
                  ],
                  selected: {urgency},
                  onSelectionChanged: (val) {
                    setDialogState(() {
                      urgency = val.first;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (titleCtrl.text.trim().isNotEmpty && bodyCtrl.text.trim().isNotEmpty) {
                  widget.state.postBulletin(
                    title: titleCtrl.text.trim(),
                    body: bodyCtrl.text.trim(),
                    urgency: urgency,
                  );
                  Navigator.pop(dialogCtx);
                }
              },
              child: const Text('Broadcast Notice'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allBulletins = widget.state.bulletins;
    final filtered = allBulletins.where((b) {
      if (_selectedFilter == 'all') return true;
      if (_selectedFilter == 'urgent') return b.urgency == 'urgent' || b.urgency == 'emergency';
      return b.urgency == _selectedFilter;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Community Bulletin Board',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Persistent notices replicated peer-to-peer across all nearby nodes',
                      style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              FilledButton.icon(
                icon: const Icon(Icons.add_alert_rounded, size: 18),
                label: const Text('Post Notice'),
                onPressed: _showPostDialog,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Filters
          Wrap(
            spacing: 8,
            children: [
              FilterChip(
                label: Text('All Notices (${allBulletins.length})'),
                selected: _selectedFilter == 'all',
                onSelected: (_) => setState(() => _selectedFilter = 'all'),
              ),
              FilterChip(
                label: const Text('Urgent & Emergency'),
                selected: _selectedFilter == 'urgent',
                onSelected: (_) => setState(() => _selectedFilter = 'urgent'),
              ),
              FilterChip(
                label: const Text('General Info'),
                selected: _selectedFilter == 'normal',
                onSelected: (_) => setState(() => _selectedFilter = 'normal'),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Notices List
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.campaign_outlined, size: 54, color: Theme.of(context).disabledColor),
                        const SizedBox(height: 12),
                        Text(
                          'No bulletin notices currently posted.',
                          style: TextStyle(color: Theme.of(context).disabledColor),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: _showPostDialog,
                          child: const Text('Post the First Notice'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final post = filtered[index];
                      final isEmergency = post.urgency == 'emergency';
                      final isUrgent = post.urgency == 'urgent';

                      final badgeColor = isEmergency
                          ? Colors.red
                          : isUrgent
                              ? Colors.amber.shade800
                              : Colors.blue;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 14),
                        elevation: isEmergency ? 3 : 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isEmergency ? Colors.red.shade300 : Theme.of(context).dividerColor.withValues(alpha: 0.2),
                            width: isEmergency ? 2 : 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(18.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: badgeColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      post.urgency.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: badgeColor,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    post.authorNickname,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '(${post.authorHash.length > 8 ? post.authorHash.substring(0, 8) : post.authorHash})',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontFamily: 'monospace'),
                                  ),
                                  const Spacer(),
                                  Text(
                                    DateTime.fromMillisecondsSinceEpoch(post.timestampSec * 1000)
                                        .toLocal()
                                        .toString()
                                        .substring(0, 16),
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                post.title,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: isEmergency ? Colors.red.shade900 : null,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                post.body,
                                style: const TextStyle(fontSize: 14, height: 1.4),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(Icons.sync_rounded, size: 14, color: Colors.green.shade700),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Verified Signed DAG Object • ${post.id.substring(0, 12)}...',
                                    style: TextStyle(fontSize: 11, color: Colors.green.shade800),
                                  ),
                                ],
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
