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
import 'views/ptt_walkie_talkie_view.dart';
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
              // Left Navigation Rail
              NavigationRail(
                selectedIndex: _selectedIndex,
                onDestinationSelected: (int index) {
                  setState(() {
                    _selectedIndex = index;
                  });
                },
                extended: true,
                minExtendedWidth: 230,
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
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'NeighborNet',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Community Mesh',
                                style: TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
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
                          mainAxisSize: MainAxisSize.min,
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
                            Text(
                              hasPeers
                                  ? '$peersCount nearby participant${peersCount == 1 ? '' : 's'}'
                                  : 'Searching local mesh...',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: hasPeers ? Colors.green.shade800 : Colors.amber.shade900,
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
                    icon: Icon(Icons.campaign_outlined),
                    selectedIcon: Icon(Icons.campaign),
                    label: Text('Bulletin'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.assignment_outlined),
                    selectedIcon: Icon(Icons.assignment),
                    label: Text('Community Forms'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.people_outline),
                    selectedIcon: Icon(Icons.people),
                    label: Text('People & Nodes'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.phone_outlined),
                    selectedIcon: Icon(Icons.phone),
                    label: Text('Voice Chat'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.radio_outlined),
                    selectedIcon: Icon(Icons.radio),
                    label: Text('Walkie-Talkie (PTT)'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.menu_book_outlined),
                    selectedIcon: Icon(Icons.menu_book),
                    label: Text('Survival Manual'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.shield_outlined),
                    selectedIcon: Icon(Icons.shield, color: Colors.red),
                    label: Text('Emergency Mode'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.settings_outlined),
                    selectedIcon: Icon(Icons.settings),
                    label: Text('Settings'),
                  ),
                ],
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
        return FormsView(state: widget.state);
      case 3:
        return PeopleView(state: widget.state);
      case 4:
        return const VoiceChatView();
      case 5:
        return PttWalkieTalkieView(state: widget.state);
      case 6:
        return SurvivalManualView(state: widget.state);
      case 7:
        return EmergencyView(state: widget.state);
      case 8:
        return SettingsView(state: widget.state);
      default:
        return ChatView(state: widget.state);
    }
  }
}
