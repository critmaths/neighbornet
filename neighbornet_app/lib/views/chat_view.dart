import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    final messages = widget.state.currentMessages;
    final myHash = widget.state.status?.destHash ?? '';

    return Row(
      children: [
        // Channel Sub-Navigation Sidebar
        Material(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: Container(
            width: 220,
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
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'CHANNELS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _channels.length,
                    itemBuilder: (context, index) {
                      final ch = _channels[index];
                      final isSelected = widget.state.currentChannel == ch['id'];
                      final color = ch['color'] as Color? ?? Theme.of(context).colorScheme.primary;

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
                        onTap: () {
                          widget.state.selectChannel(ch['id'] as String);
                        },
                      );
                    },
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
                child: Row(
                  children: [
                    Text(
                      '# ${widget.state.currentChannel}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
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
                              'No messages in #${widget.state.currentChannel} yet.',
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
                                        msg.senderNickname,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: isMe
                                              ? Theme.of(context).colorScheme.onPrimaryContainer
                                              : Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        DateTime.fromMillisecondsSinceEpoch(msg.timestampSec * 1000)
                                            .toLocal()
                                            .toString()
                                            .substring(11, 16),
                                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    msg.content,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isMe
                                          ? Theme.of(context).colorScheme.onPrimaryContainer
                                          : Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),

              // Bottom Composer
              Container(
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
                    Expanded(
                      child: TextField(
                        controller: _msgController,
                        decoration: InputDecoration(
                          hintText: 'Message #${widget.state.currentChannel}...',
                          hintStyle: const TextStyle(fontSize: 13),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: Theme.of(context).dividerColor),
                          ),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      icon: const Icon(Icons.send_rounded, size: 18),
                      onPressed: _sendMessage,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
