import 'dart:io';
import 'package:flutter/material.dart';
import '../state/neighbornet_state.dart';

class EmergencyView extends StatefulWidget {
  final NeighborNetState state;

  const EmergencyView({super.key, required this.state});

  @override
  State<EmergencyView> createState() => _EmergencyViewState();
}

class _EmergencyViewState extends State<EmergencyView> {
  final List<Map<String, dynamic>> _manualChapters = [
    {
      'id': '72hr',
      'title': '1. The 72-Hour Rapid Protocol',
      'icon': Icons.timer_outlined,
      'color': Colors.red,
      'summary': 'Immediate action steps when the grid drops or civil breakdown begins.',
      'content': '''
• EMERGENCY WATER CAPTURE:
  Immediately fill all bathtubs, clean sinks, and large storage totes.
  Close the home's water main shutoff valve to prevent contaminated back-siphonage from municipal pipes.
  Drain clean potable water from your water heater tank (30-50 gallons) using the bottom brass drain valve.

• OPSEC & BLACKOUT DISCIPLINE:
  Hang heavy wool blankets or cardboard over outward-facing windows after dark to prevent light leaks.
  Silence non-essential generators and chimes.
  Secure ground-floor entry points (deadbolts, interior jams, dowels in sliding door tracks).

• INFORMATION & RALLY:
  Tune battery/crank radios to NOAA Weather and local FRS/GMRS emergency channels.
  Check NeighborNet #emergency channel to identify nearby neighbors and establish rendezvous points.
''',
    },
    {
      'id': 'water',
      'title': '2. Water Procurement & Purification Cascade',
      'icon': Icons.water_drop_outlined,
      'color': Colors.blue,
      'summary': 'Bleach purification ratios, DIY bio-sand filtration, and safe storage.',
      'content': '''
• MECHANICAL SEDIMENT FILTRATION:
  Pre-filter cloudy or turbid water through layers of clean cotton cloth or bandanas to remove sediment and debris.

• PURIFICATION METHODS (Choose ONE):
  1. BOILING: Bring water to a rolling boil for 60 seconds (3 minutes at elevations above 6,500 ft).
  2. SODIUM HYPOCHLORITE (Unscented 6% Household Bleach):
     • 1 Gallon Clear Water: 8 drops (approx. 1/8 teaspoon).
     • 1 Gallon Cloudy Water: 16 drops (approx. 1/4 teaspoon).
     • 5 Gallons Clear Water: 40 drops (approx. 1/2 teaspoon).
     • Stir and let stand for 30 minutes. Water should have a faint chlorine smell.
  3. SODIS (Solar Disinfection):
     • Fill clear PET plastic bottles with water and expose to direct midday sunlight for 6 hours.

• DIY GRAVITY BIO-SAND FILTER:
  In a 5-gallon bucket with drainage holes, layer from bottom to top:
  1. 2 inches of clean gravel/pebbles.
  2. 2 inches of coarse sand.
  3. 3 inches of crushed activated charcoal (from clean campfire embers).
  4. 4 inches of fine sand.
  5. Top cloth layer.
  Always boil or chlorinate filtered output!
''',
    },
    {
      'id': 'medical',
      'title': '3. Trauma Triage & Disease Prevention',
      'icon': Icons.medical_services_outlined,
      'color': Colors.redAccent,
      'summary': 'Stop-the-bleed protocols, wound irrigation, and the life-saving WHO rehydration formula.',
      'content': '''
• MASS HEMORRHAGE (STOP THE BLEED):
  1. Apply firm direct pressure with clean cloth or gloved hand.
  2. For catastrophic extremity bleeding: apply commercial tourniquet (CAT/SOFT-T) 2-3 inches above wound (never over a joint).
  3. Tighten windlass until bleeding stops. Mark time on patient forehead: e.g. "TK 14:30".

• WOUND CLEANSING:
  Irrigate heavily with clean boiled water or sterile saline.
  Do NOT pour straight hydrogen peroxide or isopropyl alcohol into deep wounds (destroys healthy granulation tissue).

• WHO ORAL REHYDRATION SALTS (ORS) FORMULA:
  Dysentery and waterborne diarrhea are the #1 killers during infrastructure collapse.
  Mix in 1 Liter (approx. 4 cups) of clean boiled water:
  • 6 level teaspoons of Sugar
  • 1/2 level teaspoon of Salt
  Stir until dissolved. Have patient sip slowly throughout the day to prevent fatal electrolyte shock.
''',
    },
    {
      'id': 'sanitation',
      'title': '4. Two-Bucket Sanitation (Preventing Cholera)',
      'icon': Icons.cleaning_services_outlined,
      'color': Colors.teal,
      'summary': 'Separate liquid and solid human waste to eliminate odor and disease when sewers fail.',
      'content': '''
• DO NOT FLUSH TOILETS:
  When municipal water pressure drops, sewer mains lose gravity and back up into ground-floor bathtubs and drains.

• THE TWO-BUCKET LATRINE PROTOCOL:
  Never mix urine and feces. Mixing creates anaerobic decomposition, noxious odors, and pathogen spread.

  • BUCKET 1 (Urine Only):
    Urine is generally sterile. Dilute 1:10 with water and dispose of away from wells, or use as garden nitrogen.

  • BUCKET 2 (Feces Only):
    Line bucket with heavy-duty contractor trash bag.
    After every bowel movement, cover completely with a scoop of DRY CARBON:
    - Dry sawdust, peat moss, crushed dry leaves, or wood ash.
    Carbon material neutralizes odors immediately and desiccates pathogens.
    Keep tightly sealed with snap lid.
''',
    },
    {
      'id': 'food',
      'title': '5. Food Security & Haybox Cooking',
      'icon': Icons.restaurant_outlined,
      'color': Colors.green,
      'summary': 'Preserving perishable foods, complete protein ratios, and fuel-saving thermal cooking.',
      'content': '''
• SPOILAGE SEQUENCE:
  1. Refrigerator items first (Day 1-2).
  2. Freezer meats next (cook large communal stews before thawing spoilage).
  3. Pantry dry bulk staples (rice, dry beans, oats, honey, canned goods).

• COMPLETE PROTEIN RATIO:
  Mix 1 part dry beans (pinto, black, kidney) with 2 parts white rice to provide complete human amino acid profile.

• FUEL-SAVING HAYBOX / THERMAL RETENTION COOKING:
  1. Bring stew or beans to a rolling boil for 5 minutes in a lidded heavy pot.
  2. Remove from heat and immediately wrap pot in wool blankets or place inside cardboard box tightly packed with hay, foam, or crumpled newspapers.
  3. Trapped thermal mass cooks food to tenderness over 4-6 hours using zero additional fuel!
''',
    },
    {
      'id': 'economy',
      'title': '6. Economic Collapse, Barter & Ledgers',
      'icon': Icons.currency_exchange_outlined,
      'color': Colors.amber,
      'summary': 'High-value commodities, pre-1965 silver, and NeighborNet mutual credit ledgers.',
      'content': '''
• TOP BARTER COMMODITIES:
  1. Fuel & Fire: Lighters (Bic), strike-anywhere matches, lamp oil, candles.
  2. Medicine: OTC pain relievers (ibuprofen/acetaminophen), antibiotics, antiseptic, soap.
  3. Comfort & Morale: Ground coffee, black tea, iodized salt, sugar, small spirits bottles.
  4. Hardware: Paracord, duct tape, AA/AAA batteries, water purification tabs.
  5. Hard Money: Pre-1965 90% silver US coins (dimes, quarters, halves) and 1 oz silver rounds.

• MUTUAL AID LEDGER OVER NEIGHBORNET:
  Avoid carrying physical assets. Use NeighborNet's signed DAG as a community credit ledger:
  "Node A provided 5 gal water to Node B. Node B owes Node A 2 hours carpentry."
  Replicated transparently across local mesh nodes.
''',
    },
    {
      'id': 'defense',
      'title': '7. Civil Defense & Neighborhood Watch',
      'icon': Icons.shield_outlined,
      'color': Colors.indigo,
      'summary': 'Forming community councils, roving watch shifts, and conflict de-escalation rules.',
      'content': '''
• NEIGHBORHOOD COUNCIL STRUCTURE:
  Organize into specialized teams:
  - Perimeter Watch: Manning street checkpoints and roving nighttime foot patrols.
  - Resource Coordination: Supervising community water points and shared food distribution.
  - Medical/Triage: Consolidating first-aid supplies and managing sanitation.
  - Communications: Manning the NeighborNet base station and monitoring emergency radio nets.

• CONFLICT DE-ESCALATION RULES:
  1. Post polite, visible checkpoint signage: "Community Checkpoint Ahead. Please dim lights and approach on foot."
  2. Maintain calm, open posture with hands visible. Speak slowly and respectfully.
  3. Never brandish weapons prematurely: escalate only upon direct lethal threat.
  4. Compassionate firmness resolves 95% of civilian distress encounters.
''',
    },
    {
      'id': 'comms',
      'title': '8. Emergency Radio Frequencies & Signals',
      'icon': Icons.radio_outlined,
      'color': Colors.deepOrange,
      'summary': 'National hailing channels, NOAA weather frequencies, and non-verbal whistle codes.',
      'content': '''
• STANDARD RADIO FREQUENCIES:
  • NOAA Weather: 162.400 - 162.550 MHz
  • FRS/GMRS Channel 1: 462.5625 MHz (Standard consumer walkie-talkie hailing)
  • FRS/GMRS Channel 20: 462.6750 MHz (Emergency travel channel)
  • MURS Channel 3: 151.940 MHz (VHF unlicensed neighborhood net)
  • Ham 2-Meter Simplex: 146.520 MHz (National amateur VHF hailing)
  • Reticulum LoRa: 915.000 MHz (US) / 868.000 MHz (EU)

• NON-VERBAL WHISTLE & FLASHLIGHT CODES:
  • 1 Short Blast: "Where are you? / Report status."
  • 2 Short Blasts: "Come to my location / All clear."
  • 3 Blasts (Whistle or Light): "EMERGENCY / IMMEDIATE ASSISTANCE REQUIRED."
''',
    },
    {
      'id': 'thermal',
      'title': '9. Thermal Regulation & Cold Weather',
      'icon': Icons.ac_unit_outlined,
      'color': Colors.cyan,
      'summary': 'Creating indoor micro-climates and safe heating without grid power.',
      'content': '''
• INDOOR MICRO-CLIMATE ROOM:
  Pick a single interior room with few windows. Hang wool blankets over doors and windows.
  Confine entire household to this space; shared body heat will warm the room 10-15°F above ambient.
  Pitch an indoor camping tent inside the room and sleep on insulated foam/wool sleeping pads off cold floors.

• CARBON MONOXIDE FATAL HAZARD:
  NEVER use charcoal grills, unvented camp stoves, or gas generators indoors.
  Carbon monoxide (CO) is odorless, invisible, and fatal within minutes.
''',
    },
  ];

  String _searchQuery = '';

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
              widget.state.postBulletin(
                title: 'CRITICAL EMERGENCY ALERT',
                body: alertCtrl.text.trim(),
                urgency: 'emergency',
              );
              widget.state.sendChatMessage('[CRITICAL EMERGENCY] ${alertCtrl.text.trim()}');
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

  void _openFullManualViewer(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setModalState) {
          final filtered = _manualChapters.where((ch) {
            if (_searchQuery.isEmpty) return true;
            return ch['title'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
                ch['content'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
                ch['summary'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
          }).toList();

          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.menu_book, color: Colors.teal),
                const SizedBox(width: 10),
                const Text('Civic & Economic Collapse Field Manual'),
                const Spacer(),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.share, size: 16),
                  label: const Text('Broadcast Manual to Mesh', style: TextStyle(fontSize: 12)),
                  onPressed: () {
                    _publishManualToMesh(context);
                  },
                ),
              ],
            ),
            content: SizedBox(
              width: 720,
              height: 580,
              child: Column(
                children: [
                  SearchBar(
                    hintText: 'Search protocols (e.g. bleach, tourniquet, ORS, bucket, radio)...',
                    leading: const Icon(Icons.search),
                    elevation: const WidgetStatePropertyAll(0),
                    onChanged: (val) {
                      setModalState(() {
                        _searchQuery = val;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(child: Text('No protocols match your search.'))
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (c, idx) {
                              final ch = filtered[idx];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                                ),
                                child: ExpansionTile(
                                  leading: CircleAvatar(
                                    backgroundColor: (ch['color'] as Color).withValues(alpha: 0.15),
                                    child: Icon(ch['icon'] as IconData, color: ch['color'] as Color, size: 20),
                                  ),
                                  title: Text(
                                    ch['title'] as String,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  subtitle: Text(
                                    ch['summary'] as String,
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                      child: SelectableText(
                                        ch['content'] as String,
                                        style: const TextStyle(fontSize: 13, height: 1.5, fontFamily: 'monospace'),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
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
            ],
          );
        },
      ),
    );
  }

  void _publishManualToMesh(BuildContext context) {
    try {
      final tempDir = Directory.systemTemp;
      final file = File('${tempDir.path}${Platform.pathSeparator}NeighborNet_Collapse_Survival_Manual.txt');
      final buffer = StringBuffer();
      buffer.writeln('=== NEIGHBORNET CIVIC & ECONOMIC COLLAPSE SURVIVAL MANUAL ===\n');
      for (final ch in _manualChapters) {
        buffer.writeln('${ch['title']}');
        buffer.writeln('${ch['content']}\n');
      }
      file.writeAsStringSync(buffer.toString());

      final hash = widget.state.publishFile(
        file.path,
        'Full 9-Chapter Civic & Economic Collapse Field Manual with water, trauma, and barter protocols.',
      );

      if (hash != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Field Manual published to mesh! (SHA-256: ${hash.substring(0, 12)}...)'),
            backgroundColor: Colors.teal,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error publishing manual: $e'), backgroundColor: Colors.red),
      );
    }
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
                        'Operating 100% peer-to-peer. Reticulum cryptographic mesh is active with ${widget.state.nearbyCount} nearby node(s).',
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

          const SizedBox(height: 20),

          // Master Manual Showcase Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.teal.withValues(alpha: 0.4)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.teal.withValues(alpha: 0.15),
                    child: const Icon(Icons.menu_book, color: Colors.teal, size: 28),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Civic & Economic Collapse Field Manual',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Complete offline 9-chapter tactical survival guide: water purification, stop-the-bleed, WHO rehydration formula, two-bucket sanitation, barter economics & civil defense.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: Colors.teal),
                    icon: const Icon(Icons.visibility),
                    label: const Text('Browse Manual'),
                    onPressed: () => _openFullManualViewer(context),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          const Text(
            'Quick-Action Protocols & Emergency Cards',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // Quick-Action Cards
          Row(
            children: [
              Expanded(
                child: _buildResourceCard(
                  context,
                  icon: Icons.water_drop_outlined,
                  color: Colors.blue,
                  title: 'Water Purification',
                  body: 'Rolling boil for 1 min. Bleach ratio: 8 drops unscented 6% household bleach per gallon of clear water; stand 30 minutes.',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildResourceCard(
                  context,
                  icon: Icons.radio_outlined,
                  color: Colors.orange,
                  title: 'Emergency Frequencies',
                  body: 'NOAA: 162.400-162.550 MHz\nFRS/GMRS Ch 1: 462.5625 MHz\nMURS Ch 3: 151.940 MHz\nHam Simplex: 146.520 MHz',
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
                  title: 'Medical Triage & ORS',
                  body: 'Direct pressure for bleeding; apply tourniquet 2" above wound. WHO ORS: 1L boiled water + 6 tsp sugar + 1/2 tsp salt.',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildResourceCard(
                  context,
                  icon: Icons.cleaning_services_outlined,
                  color: Colors.teal,
                  title: 'Two-Bucket Latrine',
                  body: 'Do not flush! Separate urine and feces into two buckets. Cover solid waste with dry sawdust or wood ash after every use.',
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
