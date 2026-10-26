import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/tray_and_window_service.dart';
import 'state/neighbornet_state.dart';
import 'models/neighbornet_models.dart';
import 'views/chat_view.dart';
import 'views/bulletin_view.dart';
import 'views/people_view.dart';
import 'views/emergency_view.dart';
import 'views/survival_manual_view.dart';
import 'views/settings_view.dart';
import 'views/voice_chat_view.dart';
import 'views/forms_view.dart';
import 'views/marketplace_view.dart';
import 'views/ptt_walkie_talkie_view.dart';
import 'views/tactical_map_view.dart';
import 'views/traceroute_view.dart';
import 'views/files_view.dart';
import 'views/help_view.dart';
import 'services/voice_chat_service.dart';
import 'widgets/qr_scanner_dialog.dart';
import 'widgets/qr_identity_dialog.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await TrayAndWindowService.instance.initialize();
  final state = NeighborNetState();
  final voiceService = VoiceChatService();
  state.attachVoiceChatService(voiceService);
  await state.initialize();
  runApp(NeighborNetApp(state: state, voiceService: voiceService));
}

class NeighborNetApp extends StatelessWidget {
  final NeighborNetState state;
  final VoiceChatService? voiceService;

  const NeighborNetApp({super.key, required this.state, this.voiceService});

  @override
  Widget build(BuildContext context) {
    final vService = voiceService ?? VoiceChatService();
    state.attachVoiceChatService(vService);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: state),
        ChangeNotifierProvider.value(value: vService),
      ],
      child: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          return MaterialApp(
            title: 'NeighborNet',
            debugShowCheckedModeBanner: false,
            theme: state.themeData,
            home: MainShell(state: state),
          );
        },
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  final NeighborNetState state;

  const MainShell({super.key, required this.state});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  final ScrollController _navScrollController = ScrollController();

  @override
  void dispose() {
    _navScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final peersCount = widget.state.nearbyCount;
        final hasPeers = peersCount > 0;

        return CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            const SingleActivator(LogicalKeyboardKey.keyN, control: true): () => setState(() => _selectedIndex = 0),
            const SingleActivator(LogicalKeyboardKey.keyO, control: true): () => setState(() => _selectedIndex = 2),
            const SingleActivator(LogicalKeyboardKey.keyQ, control: true): () => exit(0),
            const SingleActivator(LogicalKeyboardKey.comma, control: true): () => setState(() => _selectedIndex = 12),
            const SingleActivator(LogicalKeyboardKey.f1): () => setState(() => _selectedIndex = 13),
            const SingleActivator(LogicalKeyboardKey.digit1, control: true): () => setState(() => _selectedIndex = 0),
            const SingleActivator(LogicalKeyboardKey.digit2, control: true): () => setState(() => _selectedIndex = 1),
            const SingleActivator(LogicalKeyboardKey.digit3, control: true): () => setState(() => _selectedIndex = 2),
            const SingleActivator(LogicalKeyboardKey.digit4, control: true): () => setState(() => _selectedIndex = 3),
            const SingleActivator(LogicalKeyboardKey.digit5, control: true): () => setState(() => _selectedIndex = 4),
            const SingleActivator(LogicalKeyboardKey.digit6, control: true): () => setState(() => _selectedIndex = 5),
            const SingleActivator(LogicalKeyboardKey.digit7, control: true): () => setState(() => _selectedIndex = 6),
            const SingleActivator(LogicalKeyboardKey.digit8, control: true): () => setState(() => _selectedIndex = 7),
            const SingleActivator(LogicalKeyboardKey.digit9, control: true): () => setState(() => _selectedIndex = 8),
          },
          child: Focus(
            autofocus: true,
            child: Scaffold(
          body: Column(
            children: [
              _buildDesktopMenuBar(context),
              const Divider(height: 1, thickness: 1),
              Expanded(
                child: Row(
                  children: [
                    // Left Navigation Sidebar with Scrollbar & Disconnected Help Button
                    SizedBox(
                      width: 255,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Scrollbar(
                      controller: _navScrollController,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: _navScrollController,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: constraints.maxHeight),
                          child: IntrinsicHeight(
                            child: NavigationRail(
                              selectedIndex: _selectedIndex >= 13 ? null : _selectedIndex,
                              onDestinationSelected: (int index) {
                                setState(() {
                                  _selectedIndex = index;
                                });
                              },
                              extended: true,
                              minExtendedWidth: 235,
                              leading: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.primary,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: const Icon(Icons.hub_rounded, color: Colors.white, size: 22),
                                        ),
                                        const SizedBox(width: 10),
                                        const Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'NeighborNet',
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                              ),
                                              Text(
                                                'Community Mesh',
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(fontSize: 11, color: Colors.grey),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    // Live Nearby Status Pill
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: (hasPeers ? Colors.green : Colors.amber).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: (hasPeers ? Colors.green : Colors.amber).withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: hasPeers ? Colors.green : Colors.amber,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              hasPeers
                                                  ? '$peersCount nearby participant${peersCount == 1 ? '' : 's'}'
                                                  : 'Searching local mesh...',
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: hasPeers ? Colors.green.shade800 : Colors.amber.shade900,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              destinations: [
                                NavigationRailDestination(
                                  icon: Badge(
                                    isLabelVisible: widget.state.totalUnreadCount > 0,
                                    label: Text('${widget.state.totalUnreadCount}'),
                                    child: const Icon(Icons.chat_bubble_outline),
                                  ),
                                  selectedIcon: Badge(
                                    isLabelVisible: widget.state.totalUnreadCount > 0,
                                    label: Text('${widget.state.totalUnreadCount}'),
                                    child: const Icon(Icons.chat_bubble),
                                  ),
                                  label: const Text('Chat'),
                                ),
                                NavigationRailDestination(
                                  icon: const Icon(Icons.campaign_outlined),
                                  selectedIcon: const Icon(Icons.campaign),
                                  label: const Text('Bulletin'),
                                ),
                                NavigationRailDestination(
                                  icon: const Icon(Icons.folder_shared_outlined),
                                  selectedIcon: const Icon(Icons.folder_shared),
                                  label: const Text('Files & Vault'),
                                ),
                                NavigationRailDestination(
                                  icon: const Icon(Icons.assignment_outlined),
                                  selectedIcon: const Icon(Icons.assignment),
                                  label: const Text('Community Forms'),
                                ),
                                NavigationRailDestination(
                                  icon: const Icon(Icons.storefront_outlined),
                                  selectedIcon: const Icon(Icons.storefront),
                                  label: const Text('Market & Barter'),
                                ),
                                NavigationRailDestination(
                                  icon: const Icon(Icons.map_outlined),
                                  selectedIcon: const Icon(Icons.map),
                                  label: const Text('Tactical Map'),
                                ),
                                NavigationRailDestination(
                                  icon: const Icon(Icons.alt_route),
                                  selectedIcon: const Icon(Icons.alt_route, color: Color(0xFF38BDF8)),
                                  label: const Text('Mesh Traceroute'),
                                ),
                                NavigationRailDestination(
                                  icon: const Icon(Icons.people_outline),
                                  selectedIcon: const Icon(Icons.people),
                                  label: const Text('People & Nodes'),
                                ),
                                NavigationRailDestination(
                                  icon: const Icon(Icons.phone_outlined),
                                  selectedIcon: const Icon(Icons.phone),
                                  label: const Text('Voice Chat'),
                                ),
                                NavigationRailDestination(
                                  icon: const Icon(Icons.radio_outlined),
                                  selectedIcon: const Icon(Icons.radio),
                                  label: const Text('Walkie-Talkie (PTT)'),
                                ),
                                NavigationRailDestination(
                                  icon: const Icon(Icons.menu_book_outlined),
                                  selectedIcon: const Icon(Icons.menu_book),
                                  label: const Text('Survival Manual'),
                                ),
                                NavigationRailDestination(
                                  icon: const Icon(Icons.shield_outlined),
                                  selectedIcon: const Icon(Icons.shield, color: Colors.red),
                                  label: const Text('Emergency Mode'),
                                ),
                                NavigationRailDestination(
                                  icon: const Icon(Icons.settings_outlined),
                                  selectedIcon: const Icon(Icons.settings),
                                  label: const Text('Preferences'),
                                ),
                              ],
                              trailing: Expanded(
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 24, bottom: 16, left: 12, right: 12),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Divider(height: 1),
                                        const SizedBox(height: 10),
                                        InkWell(
                                          borderRadius: BorderRadius.circular(12),
                                          onTap: () {
                                            setState(() {
                                              _selectedIndex = 13;
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                            decoration: BoxDecoration(
                                              color: _selectedIndex == 13
                                                  ? Theme.of(context).colorScheme.secondaryContainer
                                                  : Colors.transparent,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(5),
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: _selectedIndex == 13
                                                        ? Theme.of(context).colorScheme.primary
                                                        : Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                                                  ),
                                                  child: Icon(
                                                    Icons.question_mark_rounded,
                                                    size: 15,
                                                    color: _selectedIndex == 13
                                                        ? Colors.white
                                                        : Theme.of(context).colorScheme.primary,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        'Help & How-To',
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          fontWeight: _selectedIndex == 13
                                                              ? FontWeight.bold
                                                              : FontWeight.w600,
                                                          color: _selectedIndex == 13
                                                              ? Theme.of(context).colorScheme.onSecondaryContainer
                                                              : null,
                                                        ),
                                                      ),
                                                      const Text(
                                                        'User guide & manual',
                                                        style: TextStyle(fontSize: 10, color: Colors.grey),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const VerticalDivider(thickness: 1, width: 1),

              // Content Area
              Expanded(
                child: _buildCurrentView(),
              ),
            ],
          ),
        ),
      ],
    ),
  ),
),
);
      },
    );
  }

  Widget _buildDesktopMenuBar(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      child: MenuBar(
        style: MenuStyle(
          backgroundColor: WidgetStateProperty.all(Colors.transparent),
          elevation: WidgetStateProperty.all(0),
          padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 4)),
        ),
        children: [
          // FILE MENU
          SubmenuButton(
            menuChildren: [
              MenuItemButton(
                leadingIcon: const Icon(Icons.add_comment_outlined, size: 18),
                shortcut: const SingleActivator(LogicalKeyboardKey.keyN, control: true),
                onPressed: () {
                  setState(() => _selectedIndex = 0);
                },
                child: const Text('New Chat Channel / Room'),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.upload_file_outlined, size: 18),
                shortcut: const SingleActivator(LogicalKeyboardKey.keyO, control: true),
                onPressed: () {
                  setState(() => _selectedIndex = 2);
                },
                child: const Text('Share File / Add to Vault...'),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.qr_code_2_rounded, size: 18),
                onPressed: () {
                  final status = widget.state.status;
                  final myProf = widget.state.myProfile ??
                      UserProfile(
                        destHash: status?.destHash ?? '',
                        nickname: status?.nickname ?? 'Neighbor',
                      );
                  QrIdentityDialog.show(context, myProf);
                },
                child: const Text('My Tactical QR Identity...'),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                onPressed: () => QrScannerDialog.show(context),
                child: const Text('Scan QR / Add Peer...'),
              ),
              const Divider(),
              MenuItemButton(
                leadingIcon: const Icon(Icons.delete_sweep_outlined, size: 18),
                onPressed: () {
                  final ch = widget.state.activeChannel;
                  showDialog(
                    context: context,
                    builder: (dCtx) => AlertDialog(
                      title: const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                          SizedBox(width: 8),
                          Text('Clear Chat Channel'),
                        ],
                      ),
                      content: Text('Clear all message history for #$ch on this node?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dCtx),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: Colors.red),
                          onPressed: () {
                            widget.state.clearChat(ch);
                            Navigator.pop(dCtx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Chat history cleared for #$ch')),
                            );
                          },
                          child: const Text('Clear Chat'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('Clear Active Channel History...'),
              ),
              const Divider(),
              MenuItemButton(
                leadingIcon: const Icon(Icons.close_rounded, size: 18, color: Colors.redAccent),
                shortcut: const SingleActivator(LogicalKeyboardKey.keyQ, control: true),
                onPressed: () => exit(0),
                child: const Text('Exit NeighborNet'),
              ),
            ],
            child: const Text('File'),
          ),

          // EDIT MENU
          SubmenuButton(
            menuChildren: [
              MenuItemButton(
                leadingIcon: const Icon(Icons.copy_rounded, size: 18),
                onPressed: () {
                  final hash = widget.state.status?.destHash ?? '';
                  if (hash.isNotEmpty) {
                    Clipboard.setData(ClipboardData(text: hash));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied sovereign key hash to clipboard!')),
                    );
                  }
                },
                child: const Text('Copy Sovereign Key Hash'),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.cleaning_services_outlined, size: 18),
                onPressed: () {
                  widget.state.clearChat(widget.state.activeChannel);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Cleared local buffer for #${widget.state.activeChannel}')),
                  );
                },
                child: const Text('Clear Active Channel Buffer'),
              ),
            ],
            child: const Text('Edit'),
          ),

          // VIEW MENU
          SubmenuButton(
            menuChildren: [
              MenuItemButton(
                leadingIcon: const Icon(Icons.chat_bubble_outline, size: 18),
                shortcut: const SingleActivator(LogicalKeyboardKey.digit1, control: true),
                onPressed: () => setState(() => _selectedIndex = 0),
                child: const Text('1. Chat & Channels'),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.campaign_outlined, size: 18),
                shortcut: const SingleActivator(LogicalKeyboardKey.digit2, control: true),
                onPressed: () => setState(() => _selectedIndex = 1),
                child: const Text('2. Emergency Bulletin'),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.folder_shared_outlined, size: 18),
                shortcut: const SingleActivator(LogicalKeyboardKey.digit3, control: true),
                onPressed: () => setState(() => _selectedIndex = 2),
                child: const Text('3. Files & Vault'),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.assignment_outlined, size: 18),
                shortcut: const SingleActivator(LogicalKeyboardKey.digit4, control: true),
                onPressed: () => setState(() => _selectedIndex = 3),
                child: const Text('4. Community Forms'),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.storefront_outlined, size: 18),
                shortcut: const SingleActivator(LogicalKeyboardKey.digit5, control: true),
                onPressed: () => setState(() => _selectedIndex = 4),
                child: const Text('5. Barter Marketplace'),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.radar_rounded, size: 18),
                shortcut: const SingleActivator(LogicalKeyboardKey.digit6, control: true),
                onPressed: () => setState(() => _selectedIndex = 5),
                child: const Text('6. Mesh Radar Map'),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.alt_route_rounded, size: 18),
                shortcut: const SingleActivator(LogicalKeyboardKey.digit7, control: true),
                onPressed: () => setState(() => _selectedIndex = 6),
                child: const Text('7. Traceroute Diagnostic'),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.people_outline_rounded, size: 18),
                shortcut: const SingleActivator(LogicalKeyboardKey.digit8, control: true),
                onPressed: () => setState(() => _selectedIndex = 7),
                child: const Text('8. People & Nodes'),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.phone_in_talk_outlined, size: 18),
                shortcut: const SingleActivator(LogicalKeyboardKey.digit9, control: true),
                onPressed: () => setState(() => _selectedIndex = 8),
                child: const Text('9. Live Audio & Video Calls'),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.radio_outlined, size: 18),
                onPressed: () => setState(() => _selectedIndex = 9),
                child: const Text('10. Walkie-Talkie (PTT)'),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.medical_services_outlined, size: 18),
                onPressed: () => setState(() => _selectedIndex = 10),
                child: const Text('11. Survival Manual'),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.warning_amber_rounded, size: 18),
                onPressed: () => setState(() => _selectedIndex = 11),
                child: const Text('12. Emergency Broadcast Beacon'),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.settings_outlined, size: 18),
                onPressed: () => setState(() => _selectedIndex = 12),
                child: const Text('13. Settings'),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.help_outline_rounded, size: 18),
                onPressed: () => setState(() => _selectedIndex = 13),
                child: const Text('14. Help & Documentation'),
              ),
            ],
            child: const Text('View'),
          ),

          // PEERS & GROUPS MENU
          SubmenuButton(
            menuChildren: [
              MenuItemButton(
                leadingIcon: const Icon(Icons.people_alt_outlined, size: 18),
                onPressed: () => setState(() => _selectedIndex = 7),
                child: const Text('Discovered Peers List'),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.favorite_border_rounded, size: 18),
                onPressed: () => setState(() => _selectedIndex = 7),
                child: const Text('Manage Relationship Groups (Friends/Family)'),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.shield_outlined, size: 18),
                onPressed: () => setState(() => _selectedIndex = 7),
                child: const Text('Safety & Moderation Lists (Blocked/Restricted)'),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.group_work_outlined, size: 18),
                onPressed: () => setState(() => _selectedIndex = 7),
                child: const Text('Community Groups'),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.lock_outline_rounded, size: 18),
                onPressed: () => setState(() => _selectedIndex = 0),
                child: const Text('Direct Whispers (E2EE)'),
              ),
            ],
            child: const Text('Peers & Groups'),
          ),

          // PREFERENCES MENU
          SubmenuButton(
            menuChildren: [
              MenuItemButton(
                leadingIcon: const Icon(Icons.palette_outlined, size: 18),
                onPressed: () {
                  setState(() => _selectedIndex = 12);
                },
                child: const Text('App Theme & Tactical Profiles'),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.router_outlined, size: 18),
                onPressed: () {
                  setState(() => _selectedIndex = 12);
                },
                child: const Text('Network Port & Mesh Transport Roles'),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.settings_input_antenna_rounded, size: 18),
                onPressed: () {
                  setState(() => _selectedIndex = 12);
                },
                child: const Text('LoRa Tactical Radio Hardware Interface'),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.language_rounded, size: 18),
                onPressed: () {
                  setState(() => _selectedIndex = 12);
                },
                child: const Text('Local Web Gateway & Captive DNS'),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.badge_outlined, size: 18),
                onPressed: () {
                  setState(() => _selectedIndex = 12);
                },
                child: const Text('Tactical Sovereign Profile & Identity'),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.key_rounded, size: 18),
                onPressed: () {
                  setState(() => _selectedIndex = 12);
                },
                child: const Text('Backup 48-Word BIP-39 Seed Phrase'),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.cleaning_services_outlined, size: 18, color: Colors.redAccent),
                onPressed: () {
                  setState(() => _selectedIndex = 12);
                },
                child: const Text('Storage Wipe & Emergency Purge'),
              ),
              const Divider(),
              MenuItemButton(
                leadingIcon: const Icon(Icons.settings_suggest_outlined, size: 18),
                shortcut: const SingleActivator(LogicalKeyboardKey.comma, control: true),
                onPressed: () {
                  setState(() => _selectedIndex = 12);
                },
                child: const Text('All Preferences & Node Configuration'),
              ),
            ],
            child: const Text('Preferences'),
          ),

          // HELP MENU (Rightmost menu item)
          SubmenuButton(
            menuChildren: [
              MenuItemButton(
                leadingIcon: const Icon(Icons.cable_rounded, size: 18, color: Colors.teal),
                onPressed: () => setState(() => _selectedIndex = 13),
                child: const Text('1. Connecting Two Machines Guide'),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.lock_rounded, size: 18, color: Colors.blue),
                onPressed: () => setState(() => _selectedIndex = 13),
                child: const Text('2. Direct Whispers (E2EE 1-on-1)'),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.alt_route_rounded, size: 18, color: Colors.indigo),
                onPressed: () => setState(() => _selectedIndex = 13),
                child: const Text('3. Mesh Relaying (Multi-Hop Relays)'),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.medical_services_outlined, size: 18, color: Colors.redAccent),
                onPressed: () => setState(() => _selectedIndex = 10),
                child: const Text('4. Emergency Survival Field Manual'),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.settings_input_antenna_rounded, size: 18, color: Colors.cyan),
                onPressed: () => setState(() => _selectedIndex = 13),
                child: const Text('5. LoRa Radio Hardware Setup'),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.build_circle_rounded, size: 18, color: Colors.amber),
                onPressed: () => setState(() => _selectedIndex = 13),
                child: const Text('6. Troubleshooting & Firewall Rules'),
              ),
              const Divider(),
              MenuItemButton(
                leadingIcon: const Icon(Icons.help_center_outlined, size: 18),
                shortcut: const SingleActivator(LogicalKeyboardKey.f1),
                onPressed: () => setState(() => _selectedIndex = 13),
                child: const Text('Help Center & Documentation'),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.network_check_rounded, size: 18),
                onPressed: () => _showConnectivityDiagnosticDialog(context),
                child: const Text('Mesh Socket & Connectivity Diagnostic...'),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.keyboard_outlined, size: 18),
                onPressed: () => _showKeyboardShortcutsDialog(context),
                child: const Text('Desktop Keyboard Shortcuts Reference...'),
              ),
              const Divider(),
              MenuItemButton(
                leadingIcon: const Icon(Icons.forum_outlined, size: 18, color: Colors.blueAccent),
                onPressed: () => _showFeedbackAndDiscussionsDialog(context),
                child: const Text('Community Discussions & Feedback...'),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.info_outline_rounded, size: 18),
                onPressed: () {
                  showAboutDialog(
                    context: context,
                    applicationName: 'NeighborNet',
                    applicationVersion: '1.0.1',
                    applicationIcon: const Icon(Icons.hub_rounded, size: 40, color: Colors.blue),
                    children: const [
                      SizedBox(height: 10),
                      Text(
                        'Decentralized Off-Grid Sovereign Mesh Communication Platform.\n\n'
                        'Zero Cloud • Pure Local-First Reticulum Cryptographic Mesh • LoRa Ready\n\n'
                        'Open source software under the MIT License.',
                      ),
                    ],
                  );
                },
                child: const Text('About NeighborNet'),
              ),
            ],
            child: const Text('Help'),
          ),
        ],
      ),
    );
  }

  void _launchExternalUrl(String url) {
    if (Platform.isWindows) {
      Process.run('cmd', ['/c', 'start', '', url]);
    } else if (Platform.isMacOS) {
      Process.run('open', [url]);
    } else if (Platform.isLinux) {
      Process.run('xdg-open', [url]);
    }
  }

  void _showFeedbackAndDiscussionsDialog(BuildContext context) {
    const feedbackUrl = 'https://github.com/criticallabs/neighbornet/discussions';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.forum_outlined, color: Colors.blueAccent),
            SizedBox(width: 10),
            Text('Community Discussions & Feedback'),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'NeighborNet is 100% decentralized, zero-cloud open source software.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Join the GitHub community discussions to:\n'
                '• Propose new mesh features and protocol ideas\n'
                '• Report bugs, UI glitches, or hardware compatibility issues\n'
                '• Discuss LoRa transceivers (Heltec, T-Beam, SX1262) and antenna setups\n'
                '• Share disaster preparedness drills and off-grid community tests',
                style: TextStyle(fontSize: 13, height: 1.45),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.2)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.link_rounded, size: 20, color: Colors.blueAccent),
                    SizedBox(width: 8),
                    Expanded(
                      child: SelectableText(
                        feedbackUrl,
                        style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.blueAccent),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy Link'),
            onPressed: () {
              Clipboard.setData(const ClipboardData(text: feedbackUrl));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Discussions URL copied to clipboard!')),
              );
            },
          ),
          FilledButton.icon(
            icon: const Icon(Icons.open_in_browser_rounded, size: 16),
            label: const Text('Open in Browser'),
            onPressed: () {
              _launchExternalUrl(feedbackUrl);
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  void _showKeyboardShortcutsDialog(BuildContext context) {
    const shortcuts = [
      {'key': 'Ctrl + N', 'desc': 'New Chat Channel / Room'},
      {'key': 'Ctrl + O', 'desc': 'Share File / Add to Vault'},
      {'key': 'Ctrl + Q', 'desc': 'Exit NeighborNet'},
      {'key': 'Ctrl + ,', 'desc': 'Open Preferences & Settings'},
      {'key': 'F1', 'desc': 'Help Center & Documentation'},
      {'key': 'Ctrl + 1', 'desc': 'Chat & Channels'},
      {'key': 'Ctrl + 2', 'desc': 'Emergency Bulletin Board'},
      {'key': 'Ctrl + 3', 'desc': 'Files & Encrypted Vault'},
      {'key': 'Ctrl + 4', 'desc': 'Community Forms & Micro-Apps'},
      {'key': 'Ctrl + 5', 'desc': 'Barter & Resource Marketplace'},
      {'key': 'Ctrl + 6', 'desc': 'Tactical Mesh Radar Map'},
      {'key': 'Ctrl + 7', 'desc': 'Mesh Traceroute Diagnostic'},
      {'key': 'Ctrl + 8', 'desc': 'People & Nodes Roster'},
      {'key': 'Ctrl + 9', 'desc': 'Live Audio & Video Calls'},
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.keyboard_outlined, color: Colors.teal),
            SizedBox(width: 10),
            Text('Desktop Keyboard Shortcuts'),
          ],
        ),
        content: SizedBox(
          width: 480,
          height: 380,
          child: ListView.separated(
            itemCount: shortcuts.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (c, idx) {
              final s = shortcuts[idx];
              return ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                title: Text(s['desc']!, style: const TextStyle(fontSize: 13)),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    s['key']!,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showConnectivityDiagnosticDialog(BuildContext context) {
    final status = widget.state.status;
    final peers = widget.state.peers;
    final lora = widget.state.loraStatus;
    final myHash = status?.destHash ?? 'Unknown';
    final myNick = status?.nickname ?? 'Neighbor';
    final isGatewayRunning = widget.state.isWebGatewayRunning;
    final gwPort = widget.state.webGatewayPort;

    final report = 'NeighborNet v1.0.1 Connectivity Report\n'
        'Node: $myNick\n'
        'Hash: $myHash\n'
        'UDP Mesh Port: 42424 (Active)\n'
        'Active Peers: ${peers.length}\n'
        'LoRa Hardware: ${lora?.isConnected == true ? "Connected (${lora?.portName})" : "Disconnected"}\n'
        'Web Gateway: ${isGatewayRunning ? "Running on :$gwPort" : "Offline"}';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.network_check_rounded, color: Colors.green),
            SizedBox(width: 10),
            Text('Mesh Diagnostic & Telemetry'),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: peers.isNotEmpty ? Colors.green.withValues(alpha: 0.2) : Colors.amber.withValues(alpha: 0.2),
                  child: Icon(
                    peers.isNotEmpty ? Icons.check_circle_outline : Icons.sensors_rounded,
                    color: peers.isNotEmpty ? Colors.green : Colors.amber,
                  ),
                ),
                title: Text(
                  peers.isNotEmpty ? '${peers.length} Nearby Peer(s) Connected' : 'Searching for Nearby Mesh Peers...',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('UDP Port 42424 multicast / broadcast socket active'),
              ),
              const Divider(height: 16),
              Text('Node Identity: $myNick', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              SelectableText('Address Hash: $myHash', style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('LoRa Radio', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          const SizedBox(height: 2),
                          Text(
                            lora?.isConnected == true ? 'Connected' : 'Disconnected',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: lora?.isConnected == true ? Colors.green : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Web Gateway', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          const SizedBox(height: 2),
                          Text(
                            isGatewayRunning ? 'Port :$gwPort' : 'Disabled',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: isGatewayRunning ? Colors.green : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy Diagnostic Report'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: report));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Diagnostic report copied to clipboard!')),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentView() {
    switch (_selectedIndex) {
      case 0:
        return ChatView(state: widget.state);
      case 1:
        return BulletinView(state: widget.state);
      case 2:
        return FilesView(state: widget.state);
      case 3:
        return FormsView(state: widget.state);
      case 4:
        return MarketplaceView(state: widget.state);
      case 5:
        return const TacticalMapView();
      case 6:
        return const TracerouteView();
      case 7:
        return PeopleView(state: widget.state);
      case 8:
        return const VoiceChatView();
      case 9:
        return PttWalkieTalkieView(state: widget.state);
      case 10:
        return SurvivalManualView(state: widget.state);
      case 11:
        return EmergencyView(state: widget.state);
      case 12:
        return SettingsView(state: widget.state);
      case 13:
        return HelpView(state: widget.state);
      default:
        return ChatView(state: widget.state);
    }
  }
}
