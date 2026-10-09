import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../state/neighbornet_state.dart';

class HelpView extends StatefulWidget {
  final NeighborNetState state;

  const HelpView({super.key, required this.state});

  @override
  State<HelpView> createState() => _HelpViewState();
}

class _HelpViewState extends State<HelpView> {
  String _searchQuery = '';
  String _selectedCategory = 'All';
  String? _expandedTopicId;

  final List<String> _categories = [
    'All',
    'Quick Start',
    'Direct Whispers',
    'Mesh Networking',
    'Channels & Rooms',
    'Bulletins & Alerts',
    'Files & Vault',
    'Tactical Map',
    'Voice & Walkie-Talkie',
    'Barter Market',
    'LoRa Hardware',
    'Troubleshooting',
  ];

  final List<Map<String, dynamic>> _topics = [
    {
      'id': 'quickstart_2machines',
      'category': 'Quick Start',
      'title': '1. Connecting Two Machines on Local Network',
      'icon': Icons.cable_rounded,
      'color': Colors.teal,
      'summary': 'How to connect your desktop, laptop, or phone over Wi-Fi, mobile hotspot, or Ethernet.',
      'content': '''
### Step-by-Step Two-Machine Setup:

1. **Connect Both Machines to the Same Local Network**:
   • Connect both computers (or phone and PC) to the same Wi-Fi router, a phone's portable mobile hotspot, or direct Ethernet cable.
   • Internet access is **not required** — NeighborNet operates entirely offline on local subnet broadcast.

2. **Launch NeighborNet on Both Machines**:
   • Open NeighborNet on Machine 1 and Machine 2.
   • Look at the bottom-left status indicator pill:
     - 🟡 *Searching local mesh...* (Initial beacon scan)
     - 🟢 *1 nearby participant* (Discovered and paired!)

3. **How Discovery Works (Zero Configuration)**:
   • NeighborNet sends cryptographic UDP discovery packets on port **42424**.
   • When Machine 1 hears Machine 2's beacon, both nodes exchange identity hashes (`dest_hash`), nicknames, and routing metrics automatically within 5 to 10 seconds.

4. **Verify Direct Whisper Connection**:
   • Click **Chat** in the left navigation menu.
   • Look under **DIRECT WHISPERS (E2EE)** in the chat sidebar.
   • Machine 2's nickname will appear with a blue lock icon! Tap it to start a private conversation.
''',
    },
    {
      'id': 'direct_whispers',
      'category': 'Direct Whispers',
      'title': '2. Direct Whispers (E2EE 1-on-1 Messaging)',
      'icon': Icons.lock_rounded,
      'color': Colors.blue,
      'summary': 'Private end-to-end encrypted direct messaging between two sovereign mesh nodes.',
      'content': '''
### Using Direct Whispers:

• **What is a Direct Whisper?**
  A direct 1-on-1 private messaging channel between your cryptographic identity and a specific neighbor's identity.

• **Starting a Whisper**:
  1. Open the **Chat** tab.
  2. Under the channel list, look at the **DIRECT WHISPERS (E2EE)** section.
  3. Click on the neighbor you want to message.
  4. Type your message in the composer at the bottom and press Enter or Send.
  5. Alternatively, open **People & Nodes**, tap any neighbor card, and select **Direct Whisper**.

• **Unread Notifications**:
  When a neighbor sends you a Direct Whisper, a red badge counter appears next to their name in the sidebar and a desktop notification is displayed.

• **Audio Voice Memos**:
  Tap the microphone icon next to the chat composer to record an instant offline voice memo in your whisper thread.
''',
    },
    {
      'id': 'mesh_multihop',
      'category': 'Mesh Networking',
      'title': '3. Mesh Relaying: How Messages Daisy-Chain (A -> B -> C -> D)',
      'icon': Icons.alt_route_rounded,
      'color': Colors.indigo,
      'summary': 'How NeighborNet routes packets across multiple nodes in a straight line or neighborhood chain.',
      'content': '''
### Multi-Hop Relay (Bucket Brigade):

Suppose Alice (Node A) and Dave (Node D) live too far apart to reach each other directly:

```
[ Alice (A) ] ───(Wi-Fi/LoRa)───▶ [ Bob (B) ] ───(Wi-Fi/LoRa)───▶ [ Charlie (C) ] ───(Wi-Fi/LoRa)───▶ [ Dave (D) ]
```

1. **Automatic Packet Forwarding**:
   When Alice sends a message, Bob's device receives the packet. Bob's NeighborNet core automatically re-broadcasts it outward. Charlie receives Bob's relay and forwards it to Dave.

2. **Loop Prevention & Anti-Storm**:
   Every packet has a unique SHA-256 fingerprint (`seen_ids`). Once a node has processed or relayed a packet, it will never re-relay it, preventing broadcast loops and radio congestion.

3. **Delay-Tolerant Networking (Data Mules)**:
   If Charlie is away or turned off, Bob holds the message in local SQLite storage. When anyone walks or drives down the road between Bob and Dave with NeighborNet in their pocket, their device picks up the messages and delivers them to Dave as a physical "Data Mule"!

4. **Mesh Traceroute Visualizer**:
   Open **Mesh Traceroute** on the left menu, select any node, and tap **Trace Route**. The app will show each hop along the path with millisecond round-trip latencies!
''',
    },
    {
      'id': 'channels_and_rooms',
      'category': 'Channels & Rooms',
      'title': '4. Channels & Sovereign Community Rooms',
      'icon': Icons.forum_rounded,
      'color': Colors.deepPurple,
      'summary': 'Default community channels, creating custom rooms, and democratic steward moderation.',
      'content': '''
### Community Channels:
• **#general**: Public neighborhood town square for open discussion.
• **#emergency**: High-priority channel reserved for life-safety and urgent rescue alerts.
• **#neighborhood**: Community updates, block watch, utility updates.
• **#help**: Mutual aid requests, medical triage assistance, supply sharing.
• **#buysell**: Barter offers, trade proposals, equipment loans.
• **#technical**: Mesh configuration, radio frequencies, solar power tips.

### Creating Custom Rooms:
1. Tap the **+ Create Room** button in the Chat channels sidebar.
2. Enter a room name (e.g. `water-distribution`, `first-responders`) and description.
3. You automatically become the **Genesis Steward** of that room.
4. Rooms sync across the entire mesh so all neighbors can join and participate.
5. Tap **Governance** in the room header to view stewards, propose motions, or vote.
''',
    },
    {
      'id': 'bulletins_alerts',
      'category': 'Bulletins & Alerts',
      'title': '5. Life-Safety Bulletins & Priority Alerts',
      'icon': Icons.campaign_rounded,
      'color': Colors.redAccent,
      'summary': 'Posting community bulletins with urgency tiers and epidemic sync.',
      'content': '''
### Community Bulletin Board:
The Bulletin Board acts as a persistent town square notice board. Unlike rapid chat messages, bulletins stay pinned and synchronized across all nodes.

### Urgency Levels:
• 🟢 **Routine**: General community notices, lost pets, meeting schedules.
• 🟡 **Important**: Road closures, boil-water advisories, fuel ration hours.
• 🔴 **Critical Emergency**: Active fire, flood crest warnings, medical evacuation needs. Triggers loud emergency audio sirens and high-visibility red banner alerts.

### Epidemic Gossip Synchronization:
When two nodes come into radio range, they automatically compare their bulletin manifests (`SyncRequest`). Any bulletin created on the other side of town is seamlessly synchronized into your local database.
''',
    },
    {
      'id': 'files_and_vault',
      'category': 'Files & Vault',
      'title': '6. Files & Encrypted Vault (Passphrase Protection)',
      'icon': Icons.folder_special_rounded,
      'color': Colors.amber.shade800,
      'summary': 'Content-addressed 8 KB chunking, torrent-style mesh sharing, and encrypted vault files.',
      'content': '''
### Sharing Files Over the Mesh:
1. Navigate to **Files & Vault** and tap **Publish File**.
2. Select any document, map image, PDF, or APK installer from your device.
3. NeighborNet breaks the file into **8 KB content-addressed chunks** with individual SHA-256 integrity checksums.
4. A `FileAnnounce` envelope is sent across the mesh. Nearby nodes can download the chunks on-demand.

### Creating an Encrypted Vault File:
• Check the **Encrypt with Passphrase** option during upload.
• Enter a strong secret passphrase.
• The payload is encrypted with a symmetric cryptographic cipher before leaving your computer.
• Other nodes on the mesh can see the filename and hash, but **cannot view or read the contents** unless they know the secret passphrase!
''',
    },
    {
      'id': 'tactical_map',
      'category': 'Tactical Map',
      'title': '7. Tactical Mesh Map & Community Markers',
      'icon': Icons.map_rounded,
      'color': Colors.green,
      'summary': 'Plotting offline resources, hazards, medical triage points, and shared GPS markers.',
      'content': '''
### Tactical Map Features:
• **Offline Vector Mapping**: Pre-cached maps render without internet access.
• **Plotting Markers**: Tap **Plot Marker** to drop a pin with coordinates, category, and notes:
  - 💧 **Water Source**: Wells, purification stations, municipal tankers.
  - 🏥 **Medical Triage**: First aid stations, doctors, insulin storage.
  - ⚠️ **Hazard / Blockade**: Fallen trees, downed power lines, washed-out bridges.
  - 🔋 **Power / Charging**: Solar battery banks, generator hubs.
  - 🏕️ **Shelter**: Evacuation halls, heated spaces.
• **Synchronized Pins**: Markers propagate across all mesh participants in real time.
''',
    },
    {
      'id': 'voice_and_ptt',
      'category': 'Voice & Walkie-Talkie',
      'title': '8. Voice Calls & Walkie-Talkie (PTT)',
      'icon': Icons.radio_rounded,
      'color': Colors.orange,
      'summary': 'Direct WebRTC audio/video calls and half-duplex Push-to-Talk walkie-talkie.',
      'content': '''
### Two Voice Modes:

1. **Direct Voice / Video Calls (WebRTC)**:
   • In **People & Nodes** or from any Direct Whisper header, tap the **Phone** or **Video** icon.
   • A direct peer-to-peer WebRTC audio/video stream is established over the local network without external servers.

2. **Walkie-Talkie (PTT - Push to Talk)**:
   • Tap **Walkie-Talkie (PTT)** on the left menu.
   • Select a community channel (General, Emergency, Security, Medical).
   • **Hold the round PTT button** (or press and hold the Spacebar) to talk.
   • Floor arbitration prevents multiple nodes from transmitting over each other simultaneously.
   • When you release, your voice chunk broadcasts to all listening radios immediately!
''',
    },
    {
      'id': 'barter_marketplace',
      'category': 'Barter Market',
      'title': '9. Mutual Aid & Barter Marketplace',
      'icon': Icons.storefront_rounded,
      'color': Colors.brown,
      'summary': 'Off-grid resource bartering, trade proposals, and cryptographic community vouches.',
      'content': '''
### Trading Without Cash or Banks:
When the power grid is down and payment networks fail, communities rely on mutual aid and barter.

1. **Post a Listing**:
   • Tap **Market & Barter** -> **Post Listing**.
   • Select type (**Offering** or **Seeking**).
   • Choose category: Food, Water, Medical, Tools, Fuel, Skills / Labor.
   • Enter item condition and what you want in return.

2. **Submit a Trade Proposal**:
   • Browse neighborhood listings and tap **Propose Trade**.
   • Describe your offer. The seller can accept, decline, or message you directly.

3. **Community Vouches**:
   • After completing a successful trade, leave a **Community Vouch**.
   • Vouches are cryptographically signed and build neighborhood trust ratings.
''',
    },
    {
      'id': 'lora_hardware',
      'category': 'LoRa Hardware',
      'title': '10. LoRa Hardware Setup (Miles of Range)',
      'icon': Icons.settings_input_antenna_rounded,
      'color': Colors.cyan,
      'summary': 'Connecting USB LoRa transceivers (Heltec V3, LilyGO T-Beam) for multi-mile off-grid mesh.',
      'content': '''
### Hardware Setup:
• **Supported Devices**:
  - Heltec WiFi LoRa 32 (V2 / V3) (~ \$20)
  - LilyGO TTGO T-Beam / T-Echo (~ \$30)
  - Any serial KISS-compatible LoRa modem.

• **Configuration**:
  1. Plug the LoRa device into your computer via USB.
  2. Open **Settings** -> **LoRa Radio Hardware**.
  3. Enter your serial COM port (e.g. `COM3` on Windows, `/dev/ttyUSB0` on Linux).
  4. Set Baud Rate to `115200`.
  5. Select frequency: `915 MHz` (US/Americas) or `868 MHz` (Europe/UK).
  6. Tap **Connect LoRa Radio**.
  7. Packets will now transmit over sub-GHz radio waves with 1 to 5+ miles of range per hop!
''',
    },
    {
      'id': 'troubleshooting_faq',
      'category': 'Troubleshooting',
      'title': '11. Troubleshooting: Firewall, Ports & Discovery',
      'icon': Icons.build_circle_rounded,
      'color': Colors.red,
      'summary': 'Resolving network connection issues, Windows Firewall rules, and mesh discovery.',
      'content': '''
### Common Troubleshooting Steps:

1. **Both Machines Don't See Each Other**:
   • **Check Windows Defender Firewall**:
     - Press Windows Key, type `Firewall`, and open **Windows Defender Firewall with Advanced Security**.
     - Ensure NeighborNet (or `neighbornet_app.exe` / `neighbornet_node.exe`) has permission to communicate on **Private networks**.
     - UDP Port **42424** must be open for inbound and outbound traffic.
   • **Check Wi-Fi Isolation / Guest Network**:
     - Some public or guest Wi-Fi networks enable "Client Isolation" / "AP Isolation", which blocks devices on the same Wi-Fi from talking to each other.
     - Switch both machines to a regular home Wi-Fi network, mobile phone hotspot, or Ethernet switch.

2. **Direct Whispers Did Not Appear**:
   • Ensure both machines have the latest NeighborNet build.
   • Verify that the other machine's hash is listed under **DIRECT WHISPERS (E2EE)** in the Chat view.
   • Tap on the peer's name to open their conversation thread.

3. **Running a 24/7 Background Relay Daemon**:
   • Want to keep a computer or Raspberry Pi running as a continuous neighborhood mesh repeater?
   • Double-click `Run_Headless_Relay_Daemon.bat` in the NeighborNet folder.
   • It runs lightweight in the background without needing a monitor or keyboard!
''',
    },
    {
      'id': 'captive_portal',
      'category': 'Quick Start',
      'title': '12. Zero-Install Web Gateway & Mobile Sideloading',
      'icon': Icons.wifi_tethering_rounded,
      'color': Colors.purple,
      'summary': 'How neighbors without the app can join your Wi-Fi hotspot and chat immediately in their browser.',
      'content': '''
### Sideloading & Zero-Install Access:

When an emergency happens and nobody else has the app installed:

1. **Turn On Your Wi-Fi Hotspot**:
   • Enable the Mobile Hotspot on your phone, laptop, or relay station.

2. **Neighbor Connects via Phone**:
   • The neighbor connects to your Wi-Fi network with their iPhone or Android.
   • A **"Sign in to network"** popup appears automatically (via RFC 1035 UDP Captive DNS).
   • The **NeighborNet Web Portal** opens in Safari or Chrome at `http://192.168.x.x:8080`.
   • They can chat in `#general` and `#emergency` **with zero installation**!

3. **Offline App Download**:
   • In the Web Portal, they tap **"📥 Get App (Offline)"**.
   • They can download `NeighborNet.apk` (Android) or `NeighborNet.zip` (Windows) directly from your device over local Wi-Fi at 50+ Mbps with 0 cellular data!
''',
    },
  ];

  List<Map<String, dynamic>> get _filteredTopics {
    return _topics.where((t) {
      final matchesCategory = _selectedCategory == 'All' || t['category'] == _selectedCategory;
      if (!matchesCategory) return false;

      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final title = (t['title'] as String).toLowerCase();
      final summary = (t['summary'] as String).toLowerCase();
      final content = (t['content'] as String).toLowerCase();
      final category = (t['category'] as String).toLowerCase();

      return title.contains(q) || summary.contains(q) || content.contains(q) || category.contains(q);
    }).toList();
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard!'),
        backgroundColor: Colors.teal,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Column(
        children: [
          // Header & Search Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.15),
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.help_center_rounded, color: Colors.blue, size: 26),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'NeighborNet User Manual & Operational Reference',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Step-by-step how-to guides, troubleshooting, Direct Whispers, and offline mesh documentation',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Search Bar
                TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search documentation (e.g. 2 machines, Direct Whispers, firewall, LoRa, files)...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setState(() => _searchQuery = ''),
                          )
                        : null,
                    isDense: true,
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
                const SizedBox(height: 12),

                // Category Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categories.map((cat) {
                      final isSelected = _selectedCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          label: Text(cat, style: const TextStyle(fontSize: 11)),
                          selected: isSelected,
                          onSelected: (_) => setState(() => _selectedCategory = cat),
                          visualDensity: VisualDensity.compact,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Documentation Topics List
          Expanded(
            child: _filteredTopics.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off_rounded, size: 48, color: theme.disabledColor),
                        const SizedBox(height: 12),
                        Text(
                          'No documentation topics found for "$_searchQuery"',
                          style: TextStyle(color: theme.disabledColor, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => setState(() {
                            _searchQuery = '';
                            _selectedCategory = 'All';
                          }),
                          child: const Text('Reset filters'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _filteredTopics.length,
                    itemBuilder: (context, index) {
                      final topic = _filteredTopics[index];
                      final topicId = topic['id'] as String;
                      final isExpanded = _expandedTopicId == topicId;
                      final color = topic['color'] as Color;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isExpanded
                                ? color.withValues(alpha: 0.5)
                                : theme.dividerColor.withValues(alpha: 0.15),
                            width: isExpanded ? 1.5 : 1.0,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(topic['icon'] as IconData, color: color, size: 22),
                              ),
                              title: Text(
                                topic['title'] as String,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  topic['summary'] as String,
                                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      topic['category'] as String,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: color,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    isExpanded ? Icons.expand_less : Icons.expand_more,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ],
                              ),
                              onTap: () {
                                setState(() {
                                  _expandedTopicId = isExpanded ? null : topicId;
                                });
                              },
                            ),

                            if (isExpanded) ...[
                              const Divider(height: 1),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                color: isDark
                                    ? Colors.black.withValues(alpha: 0.2)
                                    : Colors.grey.withValues(alpha: 0.04),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SelectableText(
                                      topic['content'] as String,
                                      style: TextStyle(
                                        fontSize: 13,
                                        height: 1.55,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        OutlinedButton.icon(
                                          icon: const Icon(Icons.copy_rounded, size: 14),
                                          label: const Text('Copy Guide Text', style: TextStyle(fontSize: 11)),
                                          onPressed: () => _copyToClipboard(
                                            topic['content'] as String,
                                            topic['title'] as String,
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            visualDensity: VisualDensity.compact,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
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
