import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/neighbornet_models.dart';
import '../services/voice_memo_service.dart';
import '../state/neighbornet_state.dart';

class ChatView extends StatefulWidget {
  final NeighborNetState state;

  const ChatView({super.key, required this.state});

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, dynamic>> _channels = [
    {'id': 'general', 'label': 'General', 'icon': Icons.chat_bubble_outline},
    {'id': 'emergency', 'label': 'Emergency', 'icon': Icons.warning_amber_rounded, 'color': Colors.redAccent},
    {'id': 'neighborhood', 'label': 'Neighborhood', 'icon': Icons.home_work_outlined},
    {'id': 'help', 'label': 'Help & Mutual Aid', 'icon': Icons.volunteer_activism_outlined},
    {'id': 'buysell', 'label': 'Buy / Sell / Trade', 'icon': Icons.storefront_outlined},
    {'id': 'technical', 'label': 'Technical', 'icon': Icons.terminal_outlined},
  ];

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _attachFile() async {
    try {
      final result = await FilePicker.platform.pickFiles();
      if (result != null && result.files.isNotEmpty && result.files.single.path != null) {
        final pickedFile = result.files.single;
        final hash = widget.state.publishFile(
          pickedFile.path!,
          'Shared in #${widget.state.currentChannel}',
        );

        if (hash != null) {
          final sizeStr = _formatBytes(pickedFile.size);
          widget.state.sendChatMessage(
            '📎 [Shared File] ${pickedFile.name} ($sizeStr) • Hash: $hash',
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('File "${pickedFile.name}" published to mesh!'),
                backgroundColor: Colors.teal,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting file: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _sendMessage() {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    final sent = widget.state.sendChatMessage(text);
    if (sent) {
      _msgController.clear();
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _showCreateRoomDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.add_circle_outline, color: Colors.teal),
            SizedBox(width: 8),
            Text('Create Community Room'),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Create a sovereign community room. You will automatically become the initial Genesis Steward.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Room Name',
                  hintText: 'e.g. water-distribution, first-responders',
                  prefixText: '# ',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Description / Purpose',
                  hintText: 'e.g. Daily tanker schedules and water filtration points',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.check),
            label: const Text('Create Room'),
            onPressed: () {
              final rawName = nameCtrl.text.trim().replaceAll(' ', '-').toLowerCase();
              final desc = descCtrl.text.trim();
              if (rawName.isNotEmpty) {
                final room = widget.state.createRoom(rawName, desc);
                Navigator.pop(ctx);
                if (room != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Created room #${room.name}! You are Genesis Steward.'),
                      backgroundColor: Colors.teal,
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  void _showGovernanceDialog(RoomInfo room) {
    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final proposals = widget.state.getProposals(room.id);
          final auditLog = widget.state.getAuditLog(room.id);

          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.how_to_vote_outlined, color: Colors.indigo),
                const SizedBox(width: 8),
                Text('#${room.name} Governance'),
              ],
            ),
            content: SizedBox(
              width: 540,
              height: 480,
              child: DefaultTabController(
                length: 3,
                child: Column(
                  children: [
                    const TabBar(
                      tabs: [
                        Tab(text: 'Stewards'),
                        Tab(text: 'Active Votes'),
                        Tab(text: 'Audit Log'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: TabBarView(
                        children: [
                          // Tab 1: Stewards
                          ListView(
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'ACTIVE STEWARDS (${room.stewards.length})',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                                  ),
                                  const Spacer(),
                                  TextButton.icon(
                                    icon: const Icon(Icons.how_to_vote, size: 16),
                                    label: const Text('Propose Vote', style: TextStyle(fontSize: 12)),
                                    onPressed: () {
                                      _showProposeVoteDialog(room);
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ...room.stewards.map((hash) {
                                final isCreator = hash == room.creatorHash;
                                final short = hash.length >= 12 ? hash.substring(0, 12) : hash;
                                return ListTile(
                                  dense: true,
                                  leading: CircleAvatar(
                                    radius: 14,
                                    backgroundColor: Colors.indigo.withValues(alpha: 0.2),
                                    child: Icon(isCreator ? Icons.star : Icons.shield, size: 14, color: Colors.indigo),
                                  ),
                                  title: Text(
                                    isCreator ? '${room.creatorNickname} (Genesis Steward)' : 'Steward ($short...)',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text(
                                    hash,
                                    style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                                  ),
                                );
                              }),
                            ],
                          ),

                          // Tab 2: Active Votes
                          proposals.isEmpty
                              ? const Center(
                                  child: Text('No active governance proposals.', style: TextStyle(color: Colors.grey)),
                                )
                              : ListView.builder(
                                  itemCount: proposals.length,
                                  itemBuilder: (ctx, idx) {
                                    final p = proposals[idx];
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Chip(
                                                  label: Text(
                                                    p.action.toUpperCase(),
                                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                                  ),
                                                  backgroundColor: p.action == 'promote'
                                                      ? Colors.green.withValues(alpha: 0.15)
                                                      : Colors.red.withValues(alpha: 0.15),
                                                  visualDensity: VisualDensity.compact,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'Target: ${p.targetNickname}',
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                                ),
                                                const Spacer(),
                                                Text(
                                                  'Status: ${p.status.toUpperCase()}',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: p.status == 'passed' ? Colors.green : Colors.amber.shade900,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              'Reason: ${p.reasonCategory} — ${p.reasonDetails}',
                                              style: const TextStyle(fontSize: 12),
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Text(
                                                  'Votes For: ${p.votesFor.length} | Against: ${p.votesAgainst.length}',
                                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                                ),
                                                const Spacer(),
                                                if (p.status == 'pending') ...[
                                                  FilledButton.tonal(
                                                    onPressed: () {
                                                      widget.state.castVote(p.proposalId, true);
                                                      setDialogState(() {});
                                                    },
                                                    child: const Text('Vote Yes'),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  OutlinedButton(
                                                    onPressed: () {
                                                      widget.state.castVote(p.proposalId, false);
                                                      setDialogState(() {});
                                                    },
                                                    child: const Text('Vote No'),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),

                          // Tab 3: Transparent Audit Log
                          auditLog.isEmpty
                              ? const Center(
                                  child: Text('No historical governance events recorded.', style: TextStyle(color: Colors.grey)),
                                )
                              : ListView.builder(
                                  itemCount: auditLog.length,
                                  itemBuilder: (ctx, idx) {
                                    final ev = auditLog[idx];
                                    return ListTile(
                                      dense: true,
                                      leading: const Icon(Icons.gavel, color: Colors.amber, size: 20),
                                      title: Text(ev.summary, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      subtitle: Text(
                                        'Reason: ${ev.reason}',
                                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                                      ),
                                    );
                                  },
                                ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showProposeVoteDialog(RoomInfo room) {
    final nicknameCtrl = TextEditingController();
    final hashCtrl = TextEditingController();
    final detailsCtrl = TextEditingController();
    String action = 'promote';
    String reasonCategory = 'Community Support';

    final peers = widget.state.peers;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setVoteState) => AlertDialog(
          title: const Text('Propose Democratic Steward Vote'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'promote', label: Text('Promote to Steward')),
                    ButtonSegment(value: 'demote', label: Text('Demote from Steward')),
                  ],
                  selected: {action},
                  onSelectionChanged: (val) {
                    setVoteState(() {
                      action = val.first;
                      reasonCategory = action == 'promote' ? 'Community Support' : 'Inactivity';
                    });
                  },
                ),
                const SizedBox(height: 16),
                if (peers.isNotEmpty) ...[
                  const Text('Select Connected Peer:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  DropdownButton<PeerInfo>(
                    isExpanded: true,
                    hint: const Text('Choose a neighbor...'),
                    items: peers.map((p) {
                      return DropdownMenuItem(
                        value: p,
                        child: Text('${p.nickname} (${p.destHash.substring(0, 8)}...)'),
                      );
                    }).toList(),
                    onChanged: (selected) {
                      if (selected != null) {
                        setVoteState(() {
                          nicknameCtrl.text = selected.nickname;
                          hashCtrl.text = selected.destHash;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: nicknameCtrl,
                  decoration: const InputDecoration(labelText: 'Target Nickname'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: hashCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Target Reticulum Hash',
                    hintText: '32-character hexadecimal destination hash',
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Reason Category:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                DropdownButton<String>(
                  value: reasonCategory,
                  isExpanded: true,
                  items: (action == 'promote'
                          ? ['Community Support', 'Active Volunteer', 'Technical Expertise', 'Other']
                          : ['Inactivity', 'Spam / Disruption', 'Misinformation', 'Abuse of Power', 'Other'])
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setVoteState(() {
                        reasonCategory = val;
                      });
                    }
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: detailsCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Details / Justification',
                    hintText: 'Explain the reason for this democratic vote proposal...',
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
              icon: const Icon(Icons.how_to_vote),
              label: const Text('Submit Ballot Proposal'),
              onPressed: () {
                final targetHash = hashCtrl.text.trim();
                final targetNick = nicknameCtrl.text.trim().isEmpty ? 'Neighbor' : nicknameCtrl.text.trim();
                final details = detailsCtrl.text.trim();
                if (targetHash.isNotEmpty) {
                  widget.state.proposeStewardVote(
                    roomId: room.id,
                    targetHash: targetHash,
                    targetNickname: targetNick,
                    action: action,
                    reasonCategory: reasonCategory,
                    reasonDetails: details,
                  );
                  Navigator.pop(dialogCtx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Proposal broadcast to mesh! Quorum voting active.'),
                      backgroundColor: Colors.indigo,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messages = widget.state.currentMessages;
    final myHash = widget.state.status?.destHash ?? '';
    final rooms = widget.state.rooms;
    final isCustomRoom = widget.state.currentChannel.startsWith('room_');
    final currentRoom = isCustomRoom
        ? rooms.firstWhere(
            (r) => r.id == widget.state.currentChannel,
            orElse: () => RoomInfo(
              id: '',
              name: widget.state.currentChannel,
              description: '',
              creatorHash: '',
              creatorNickname: '',
              createdSec: 0,
              isPrivate: false,
              stewards: [],
            ),
          )
        : null;

    return Row(
      children: [
        // Channel Sub-Navigation Sidebar
        Material(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: Container(
            width: 230,
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                  child: Row(
                    children: [
                      Text(
                        'CHANNELS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.add, size: 18),
                        tooltip: 'Create Community Room',
                        onPressed: _showCreateRoomDialog,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      ..._channels.map((ch) {
                        final isSelected = widget.state.currentChannel == ch['id'];
                        final color = ch['color'] as Color? ?? Theme.of(context).colorScheme.primary;
                        final unread = widget.state.getUnreadCount(ch['id'] as String);

                        return ListTile(
                          dense: true,
                          selected: isSelected,
                          selectedTileColor: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.5),
                          leading: Icon(
                            ch['icon'] as IconData,
                            size: 18,
                            color: isSelected ? color : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          title: Text(
                            ch['label'] as String,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              color: isSelected ? Theme.of(context).colorScheme.onSecondaryContainer : null,
                            ),
                          ),
                          trailing: unread > 0
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.error,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$unread',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              : null,
                          onTap: () {
                            widget.state.selectChannel(ch['id'] as String);
                          },
                        );
                      }),
                      if (rooms.isNotEmpty) ...[
                        const Divider(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: Text(
                            'COMMUNITY ROOMS',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        ...rooms.map((r) {
                          final isSelected = widget.state.currentChannel == r.id;
                          final unread = widget.state.getUnreadCount(r.id);

                          return ListTile(
                            dense: true,
                            selected: isSelected,
                            selectedTileColor: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.5),
                            leading: Icon(
                              Icons.tag,
                              size: 18,
                              color: isSelected ? Colors.teal : Colors.grey,
                            ),
                            title: Text(
                              r.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (unread > 0) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.error,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '$unread',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Text(
                                  '${r.stewards.length}👑',
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                              ],
                            ),
                            onTap: () {
                              widget.state.selectChannel(r.id);
                            },
                          );
                        }),
                      ],
                      if (widget.state.peers.isNotEmpty) ...[
                        const Divider(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: Text(
                            'DIRECT WHISPERS (E2EE)',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        ...widget.state.peers.map((p) {
                          final dmChannel = 'dm_${p.destHash}';
                          final isSelected = widget.state.currentChannel == dmChannel;
                          final unread = widget.state.getUnreadCount(dmChannel);

                          return ListTile(
                            dense: true,
                            selected: isSelected,
                            selectedTileColor: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.5),
                            leading: Stack(
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: Colors.blue.withValues(alpha: 0.15),
                                  child: const Icon(Icons.lock_outline, size: 14, color: Colors.blue),
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.green,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            title: Text(
                              p.nickname,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                            subtitle: Text(
                              '${p.destHash.length > 8 ? p.destHash.substring(0, 8) : p.destHash}...',
                              style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.grey),
                            ),
                            trailing: unread > 0
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.error,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '$unread',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                : null,
                            onTap: () {
                              widget.state.selectDirectMessage(p);
                            },
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Chat Message Timeline & Composer
        Expanded(
          child: Column(
            children: [
              // Channel Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                    ),
                  ),
                ),
                child: Builder(
                  builder: (context) {
                    final isDm = widget.state.isDirectMessageChannel(widget.state.currentChannel);
                    final dmPeer = isDm ? widget.state.getPeerForChannel(widget.state.currentChannel) : null;

                    return Row(
                      children: [
                        if (isDm) ...[
                          const Icon(Icons.lock_rounded, color: Colors.blue, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Whisper: ${dmPeer?.nickname ?? widget.state.currentChannel.substring(3)}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'E2EE',
                              style: TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold),
                            ),
                          ),
                          if (dmPeer != null) ...[
                            const SizedBox(width: 12),
                            IconButton(
                              icon: const Icon(Icons.phone_rounded, size: 18, color: Colors.green),
                              tooltip: 'Voice Call ${dmPeer.nickname}',
                              onPressed: () => widget.state.startCallWithPeer(dmPeer, withVideo: false),
                            ),
                            IconButton(
                              icon: const Icon(Icons.videocam_rounded, size: 18, color: Colors.blue),
                              tooltip: 'Video Call ${dmPeer.nickname}',
                              onPressed: () => widget.state.startCallWithPeer(dmPeer, withVideo: true),
                            ),
                          ],
                        ] else ...[
                          Text(
                            isCustomRoom ? '# ${currentRoom?.name ?? widget.state.currentChannel}' : '# ${widget.state.currentChannel}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          if (isCustomRoom && currentRoom != null) ...[
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.shield_outlined, size: 14, color: Colors.indigo),
                              label: Text(
                                '${currentRoom.stewards.length} Stewards • Governance',
                                style: const TextStyle(fontSize: 11, color: Colors.indigo),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () => _showGovernanceDialog(currentRoom),
                            ),
                          ],
                        ],
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'P2P Encrypted Mesh',
                            style: TextStyle(fontSize: 11, color: Colors.green.shade800, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              // Messages
              Expanded(
                child: messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.forum_outlined, size: 48, color: Theme.of(context).disabledColor),
                            const SizedBox(height: 12),
                            Text(
                              'No messages in #${isCustomRoom ? currentRoom?.name : widget.state.currentChannel} yet.',
                              style: TextStyle(color: Theme.of(context).disabledColor),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Say hello to nearby community participants!',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages[index];
                          final isMe = msg.senderHash == myHash;

                          return Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              constraints: const BoxConstraints(maxWidth: 520),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isMe
                                    ? Theme.of(context).colorScheme.primaryContainer
                                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        isMe ? 'You' : msg.senderNickname,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: isMe
                                              ? Theme.of(context).colorScheme.onPrimaryContainer
                                              : Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '(${msg.senderHash.length >= 8 ? msg.senderHash.substring(0, 8) : msg.senderHash})',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontFamily: 'monospace',
                                          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  _buildMessageContent(context, msg, isMe),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),

              // Message Input Box
              AnimatedBuilder(
                animation: VoiceMemoService(),
                builder: (context, _) {
                  final memoService = VoiceMemoService();
                  if (memoService.isRecording) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.15),
                        border: Border(
                          top: BorderSide(
                            color: Colors.redAccent.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.mic, color: Colors.redAccent, size: 24),
                          const SizedBox(width: 8),
                          Text(
                            'Recording Voice Memo: ${memoService.recordingDuration}s',
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Live waveform bars
                          Expanded(
                            child: SizedBox(
                              height: 24,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  for (final amp in memoService.liveWaveform.take(24))
                                    Container(
                                      width: 3,
                                      height: (amp * 24).clamp(4.0, 24.0),
                                      margin: const EdgeInsets.symmetric(horizontal: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.redAccent,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.grey),
                            tooltip: 'Cancel Recording',
                            onPressed: () => memoService.cancelRecording(),
                          ),
                          IconButton.filled(
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.send_rounded),
                            tooltip: 'Send Voice Memo',
                            onPressed: () async {
                              final result = await memoService.stopRecording();
                              if (result != null) {
                                widget.state.sendVoiceMemo(
                                  channel: widget.state.currentChannel,
                                  base64Audio: result.base64Audio,
                                  durationSec: result.durationSec,
                                  content: '🎙️ Voice Memo (${result.durationSec}s)',
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  }

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      border: Border(
                        top: BorderSide(
                          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.attach_file_rounded),
                          tooltip: 'Attach & Publish File to Mesh',
                          onPressed: _attachFile,
                        ),
                        IconButton(
                          icon: const Icon(Icons.mic_none_rounded),
                          tooltip: 'Record Voice Memo',
                          onPressed: () => memoService.startRecording(),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: TextField(
                            controller: _msgController,
                            decoration: InputDecoration(
                              hintText: 'Message #${isCustomRoom ? currentRoom?.name : widget.state.currentChannel}...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                            ),
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          icon: const Icon(Icons.send_rounded),
                          onPressed: _sendMessage,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessageContent(BuildContext context, ChatMessage msg, bool isMe) {
    if (msg.isVoiceMemo) {
      return _buildVoiceMemoBubble(context, msg, isMe);
    }

    if (msg.content.startsWith('📎 [Shared File]')) {
      final raw = msg.content.substring('📎 [Shared File]'.length).trim();
      final parts = raw.split(' • ');
      final fileInfo = parts.isNotEmpty ? parts[0] : 'File Attachment';
      final hashPart = parts.length > 1 ? parts.last.replaceAll('Hash: ', '').trim() : '';

      final isCompleted = hashPart.isNotEmpty && widget.state.getCompletedFilePath(hashPart) != null;

      return Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe
              ? Colors.white.withValues(alpha: 0.15)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.insert_drive_file_outlined, color: Colors.teal, size: 22),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileInfo,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      if (hashPart.isNotEmpty)
                        Text(
                          'Hash: ${hashPart.length > 16 ? "${hashPart.substring(0, 16)}..." : hashPart}',
                          style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.grey),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                  icon: Icon(isCompleted ? Icons.check_circle_outline : Icons.download_rounded, size: 16),
                  label: Text(isCompleted ? 'File Ready' : 'Replicate Chunks (8KB)'),
                  onPressed: hashPart.isEmpty
                      ? null
                      : () {
                          widget.state.requestFileDownload(hashPart);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Requesting 8KB file chunks for $fileInfo across mesh...'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                ),
              ],
            ),
          ],
        ),
      );
    }

    return SelectableText(
      msg.content,
      style: TextStyle(
        fontSize: 14,
        color: isMe
            ? Theme.of(context).colorScheme.onPrimaryContainer
            : Theme.of(context).colorScheme.onSurface,
      ),
    );
  }

  Widget _buildVoiceMemoBubble(BuildContext context, ChatMessage msg, bool isMe) {
    return AnimatedBuilder(
      animation: VoiceMemoService(),
      builder: (context, _) {
        final memoService = VoiceMemoService();
        final isPlaying = memoService.isPlaying(msg.id);
        final progress = isPlaying ? memoService.playbackProgress : 0.0;
        final durationSec = msg.audioDurationSec ?? 3;

        return Container(
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isMe
                ? Colors.white.withValues(alpha: 0.15)
                : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isPlaying
                  ? Colors.tealAccent.withValues(alpha: 0.6)
                  : Theme.of(context).dividerColor.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton.filledTonal(
                    icon: Icon(
                      isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.tealAccent,
                    ),
                    onPressed: () {
                      memoService.playMemo(
                        msg.id,
                        msg.audioBase64 ?? '',
                        durationSec,
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.mic, size: 14, color: Colors.tealAccent),
                          const SizedBox(width: 4),
                          Text(
                            'Voice Memo (${durationSec}s)',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Interactive waveform progress bar
                      SizedBox(
                        width: 160,
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.grey.withValues(alpha: 0.3),
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.tealAccent),
                          minHeight: 4,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
