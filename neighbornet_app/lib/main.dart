import 'package:flutter/material.dart';
import 'services/tray_and_window_service.dart';
import 'state/neighbornet_state.dart';
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

        return Scaffold(
          body: Row(
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
                                  label: const Text('Settings'),
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
        );
      },
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
