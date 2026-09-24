import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../state/neighbornet_state.dart';

class SurvivalManualView extends StatefulWidget {
  final NeighborNetState state;

  const SurvivalManualView({super.key, required this.state});

  @override
  State<SurvivalManualView> createState() => _SurvivalManualViewState();
}

class _SurvivalManualViewState extends State<SurvivalManualView> {
  String _searchQuery = '';
  String _selectedCategory = 'All';
  final Set<String> _bookmarkedIds = {};
  String? _expandedChapterId;

  // Interactive Calculator States
  double _waterCalcGallons = 1.0;
  bool _waterCalcIsCloudy = false;
  double _orsWaterLiters = 1.0;

  final List<Map<String, dynamic>> _chapters = [
    {
      'id': 'anatomy',
      'category': 'Overview',
      'title': '1. The Anatomy of Civic & Economic Collapse',
      'icon': Icons.public_off_outlined,
      'color': Colors.blueGrey,
      'summary': 'Cascade failure sequence of modern just-in-time logistics, banking, and municipal utilities.',
      'content': '''
Civic and economic collapse rarely looks like Hollywood cinema. Instead, it manifests as the cascade failure of interdependent critical supply chains:

• Day 1–3:
  Banking holidays, ATM failure, digital payment terminals go dark. Fuel stations pump dry due to grid loss or panic buying.

• Day 4–7:
  Grocery distribution centers exhaust inventory (just-in-time logistics fail). Municipal water treatment plants lose pressure as backup generator fuel depletes.

• Day 8–14:
  Emergency services (police, EMT, fire) transition to static defensive triage or cease responding to non-catastrophic calls. Municipal sewage pumps back up.

• Day 15+:
  Long-term plateau. Society fragments into local neighborhoods. Safety, nourishment, and health depend entirely on hyper-local cooperation, trust, and shared preparation.
''',
    },
    {
      'id': '72hr',
      'category': 'First 72 Hours',
      'title': '2. Phase 1: The First 72 Hours (Immediate Triage)',
      'icon': Icons.timer_outlined,
      'color': Colors.red,
      'summary': 'Rapid protocol for emergency water capture, home plumbing isolation, and blackout OPSEC discipline.',
      'content': '''
When the grid drops or civil breakdown is declared, execute the 72-Hour Rapid Protocol:

Step 1: Emergency Water Reservoir Capture
• Immediately fill every bathtub, clean sink, plastic tote, and container.
• Close the home water main shutoff valve to prevent contaminated municipal back-siphonage from draining your water heater or indoor plumbing.
• Hidden Water Sources in Homes:
  - Hot water heater tanks (30–50 gallons of pure potable water via bottom drain valve).
  - Toilet upper tanks (clean freshwater; do NOT use if chemical disinfectant tablets were added).
  - Internal plumbing pipes (open top faucets, drain lowest faucet into clean buckets).

Step 2: Information & Neighborhood Rally
• Power on battery/crank radios to local emergency frequencies (NOAA / FRS / GMRS).
• Open NeighborNet on your phone or laptop. Check #emergency for nearby participant announcements.
• Coordinate with immediate neighbors to establish an initial rendezvous point.

Step 3: Operational Security (OPSEC) & Blackout Discipline
• Prevent light leaks after sunset: hang heavy blankets or cardboard over outward-facing windows.
• Silence non-essential audible generators and outdoor chime devices.
• Secure ground-floor entry points (deadbolts, interior door jams, dowels in sliding door tracks).
''',
    },
    {
      'id': 'water',
      'category': 'Water',
      'title': '3. Water Procurement, Purification & Storage',
      'icon': Icons.water_drop_outlined,
      'color': Colors.blue,
      'summary': 'Bleach purification ratios, DIY emergency bio-sand gravity filter, and storage protocols.',
      'hasWaterCalc': true,
      'content': '''
The human body can survive 3 weeks without food, but only 3 days without water. Dehydration degrades cognitive decision-making within 24 hours.

WATER PURIFICATION CASCADE:
1. Mechanical Sediment Filtration:
   Pre-filter turbid water through layers of clean cotton cloth, bandanas, or bio-sand to remove suspended sediment and debris.

2. Microbial Purification (Choose ONE):
   A. Boiling: Rolling boil for 60 seconds (3 minutes at elevations above 6,500 ft).
   B. Sodium Hypochlorite (Unscented 6% Household Bleach):
      • Clear Water: 8 drops per gallon (approx. 1/8 tsp).
      • Cloudy Water: 16 drops per gallon (approx. 1/4 tsp).
      • Stir and let stand 30 minutes. Should have a faint chlorine aroma.
   C. SODIS (Solar Disinfection):
      • Fill clear PET plastic bottles with water and expose to direct midday sunlight for 6 hours.

DIY EMERGENCY BIO-SAND GRAVITY FILTER:
Construct in a 5-gallon bucket or 2-liter bottle with drainage holes:
1. Layer 1 (Bottom): 2 inches clean gravel or small pebbles.
2. Layer 2: 2 inches coarse sand.
3. Layer 3: 3 inches crushed activated charcoal (from non-toxic campfire embers).
4. Layer 4: 4 inches fine clean sand.
5. Layer 5 (Top): Clean cotton cloth to catch large particulate.
* Always boil or chlorinate filtered output!
''',
    },
    {
      'id': 'food',
      'category': 'Food',
      'title': '4. Food Security, Preservation & Haybox Cooking',
      'icon': Icons.restaurant_outlined,
      'color': Colors.green,
      'summary': 'Prioritizing spoilage sequence, complete amino acid profiles, and fuel-saving thermal retention cooking.',
      'content': '''
PRIORITIZING SPOILAGE SEQUENCE:
1. Refrigerator Contents (Day 1–2): Dairy, poultry, cut fruits. Keep doors closed as much as possible.
2. Freezer Contents (Day 2–5): Meat and frozen meals. Cook remaining meats in large stews and share with neighbors before spoilage begins.
3. Pantry Dry Goods (Weeks to Months): Rice, dry beans, pasta, rolled oats, peanut butter, canned tuna, honey.

THE COMPLETE PROTEIN RATIO:
Dry beans and white rice stored in bulk provide a complete human amino acid profile:
• Optimal Nutritional Ratio: 1 part dry legumes to 2 parts white rice.

FUEL-SAVING HAYBOX COOKING (Thermal Retention Cooking):
1. Bring beans or stew to a vigorous boil for 5 minutes in a lidded heavy pot.
2. Remove from heat and immediately wrap tightly in wool blankets or place inside a cardboard box packed with crumpled paper, hay, or foam.
3. The trapped thermal mass continues cooking the contents for 4–6 hours without using another drop of precious fuel.
''',
    },
    {
      'id': 'medical',
      'category': 'Medical',
      'title': '5. Emergency Medicine, Trauma & WHO Rehydration',
      'icon': Icons.medical_services_outlined,
      'color': Colors.redAccent,
      'summary': 'Stop-the-Bleed mass hemorrhage protocols, wound irrigation, and life-saving WHO ORS recipe.',
      'hasOrsCalc': true,
      'content': '''
In a collapse, hospital emergency rooms are either overwhelmed or locked down. The priority shifts from advanced medical intervention to field stabilization, infection prevention, and hydration maintenance.

MASS TRAUMA & HEMORRHAGE CONTROL (STOP THE BLEED):
• Life-Threatening Arterial Bleed (Spurting bright red blood):
  1. Apply immediate firm direct pressure with clean cloth or gloved hand.
  2. If on an extremity and direct pressure fails: apply an authentic commercial tourniquet (CAT or SOFT-T) 2–3 inches above the wound (never over a joint).
  3. Tighten windlass until bleeding stops completely. Note the exact time applied on the patient's forehead (e.g. "TK 14:30").
• Wound Cleansing:
  Irrigate heavily with clean boiled water or sterile saline. Never pour straight hydrogen peroxide or isopropyl alcohol directly into deep open wounds (destroys healthy granulation tissue).

WORLD HEALTH ORGANIZATION (WHO) ORAL REHYDRATION SALTS (ORS):
Dysentery and waterborne diarrhea are historically the #1 killers during infrastructure collapse. Dehydration kills faster than starvation.

Combine in 1 Liter (approx. 4 cups) of clean boiled water:
• 6 level teaspoons of Sugar (Sucrose / Glucose)
• 1/2 level teaspoon of Salt (Sodium Chloride)
Mix until fully dissolved. Have patient sip slowly throughout the day.
''',
    },
    {
      'id': 'sanitation',
      'category': 'Sanitation',
      'title': '6. Sanitation & The Two-Bucket Latrine System',
      'icon': Icons.cleaning_services_outlined,
      'color': Colors.teal,
      'summary': 'Preventing municipal sewage backups, cholera, and managing waste through dry carbon separation.',
      'content': '''
When municipal sewer pipes lose gravity or water pressure, toilets cannot be flushed. Flushing without municipal water causes sewage backups into ground-floor bathtubs and floor drains.

THE TWO-BUCKET EMERGENCY LATRINE SYSTEM:
Never mix liquid and solid human waste. Mixing urine and feces produces anaerobic decomposition, horrific odors, and disease-harboring pathogens. Separating them prevents odor and renders both easily manageable.

• Bucket 1 (Urine Only):
  - Collects pure liquid waste.
  - Urine is generally sterile upon discharge.
  - Dilute 1:10 with water and dispose of away from ground water supplies or use as a nitrogen garden fertilizer.

• Bucket 2 (Feces Only):
  - Line bucket with a heavy-duty contractor trash bag.
  - After every bowel movement, cover completely with a scoop of dry carbon material: dry sawdust, peat moss, crushed dry leaves, or wood ash.
  - Keep tightly sealed with a snap-on lid. The dry carbon material neutralizes odor within seconds and allows safe long-term composting or deep pit burial.
''',
    },
    {
      'id': 'economy',
      'category': 'Economy',
      'title': '7. Economic Collapse, Barter & Community Ledgers',
      'icon': Icons.currency_exchange_outlined,
      'color': Colors.amber,
      'summary': 'High-value universal commodities, junk silver, and cryptographic mutual aid ledgers on NeighborNet.',
      'content': '''
When paper fiat currency loses purchasing power and credit card networks are disabled, economic exchange shifts to physical commodities and reputation-based credit.

HIGH-VALUE UNIVERSAL BARTER COMMODITIES:
1. Consumable Fuel & Fire: Lighters (Bic), wooden matches, candles, lamp oil, propane canisters.
2. Medical & Hygiene: OTC pain relievers (ibuprofen, acetaminophen), antibiotics (amoxicillin), soap bars, feminine hygiene products, isopropyl alcohol.
3. Nutritional & Comfort Luxuries: Ground coffee, black tea bags, salt (vital for electrolyte preservation and curing), white sugar, honey, small liquor bottles.
4. Hardware & Tools: Paracord, duct tape, rechargeable AA/AAA batteries, hand-crank radios, water filtration cartridges.
5. Hard Currency: Pre-1965 90% silver US coinage ("junk silver"), 1 oz silver rounds.

MUTUAL AID LEDGERS OVER NEIGHBORNET:
Physical bartering carries personal security risks. NeighborNet's signed Directed Acyclic Graph (DAG) can operate as a Local Mutual Credit Ledger:
• Node A provides 5 gallons of water to Node B.
• Node B signs an acknowledgement: "Node B owes Node A 2 hours of carpentry work or 5 eggs".
• Replicated transparently across the neighborhood mesh. No bank or cash required; trust is preserved cryptographically within the community.
''',
    },
    {
      'id': 'defense',
      'category': 'Defense',
      'title': '8. Civil Defense, Watch & Conflict De-escalation',
      'icon': Icons.shield_outlined,
      'color': Colors.indigo,
      'summary': 'Structuring neighborhood councils, checkpoint protocols, and non-hostile de-escalation rules.',
      'content': '''
A lone household, no matter how heavily provisioned, cannot survive prolonged civil collapse in isolation. Community cooperation is the ultimate survival tool.

STRUCTURING THE NEIGHBORHOOD COUNCIL:
Organize neighbors into specialized functional roles:
• Watch & Perimeter Security: Man daytime entry observation and nighttime roving patrols.
• Medical & Triage: Consolidate first-aid equipment, manage sanitization, care for injured.
• Resource & Water Coordination: Supervise shared rainwater collection, well pumping, and boil-water points.
• Communications Coordinator: Operates the NeighborNet base node and monitors emergency radio channels.

CONFLICT DE-ESCALATION RULES OF ENGAGEMENT:
• Visibility & Perimeter Boundaries: Mark clear, polite signage at street intersections: "Community Checkpoint Ahead. Please dim headlights and approach on foot."
• Verbal De-escalation: Always maintain calm, non-confrontational posture with hands visible. Speak slowly: "We have no fuel or commercial supplies, but we have clean water and emergency medical assistance available."
• Never Display Hostility Prematurely: Escalating to weapons turns frightened, hungry citizens into desperate, violent adversaries. Compassionate firmness resolves 95% of encounters.
''',
    },
    {
      'id': 'power',
      'category': 'Power',
      'title': '9. Off-Grid Power, Micro-Climates & CO Hazards',
      'icon': Icons.bolt_outlined,
      'color': Colors.orange,
      'summary': 'Cold-weather survival rooms, folding solar maintenance, and preventing fatal carbon monoxide poisoning.',
      'content': '''
COLD-WEATHER SURVIVAL WITHOUT GRID HEATING:
• Create a Micro-Climate Room: Choose a single interior room with few windows. Hang blankets over entryways and windows. Confine the entire family to this space. Body heat alone will raise room temperature 10°F–15°F above outside ambient.
• Improvised Tent Shelter: Pitch an indoor camping tent inside the room and sleep inside it with wool blankets and sleeping pads (insulating the body from cold concrete/wood floors is critical).
• Carbon Monoxide Warning: Never burn charcoal grills, unvented camp stoves, or gas generators indoors. Carbon monoxide (CO) is odorless, colorless, and fatal.

LOW-COST SOLAR & BATTERY MAINTENANCE:
• Small 50W–100W portable folding solar panels paired with 12V LiFePO4 battery banks can keep communication devices, USB radios, and LED lanterns running indefinitely.
• Store emergency lithium batteries at 50%–70% charge in a cool, dry area away from direct sunlight.
''',
    },
    {
      'id': 'comms',
      'category': 'Comms',
      'title': '10. Radio Nets, Frequencies & Distress Signals',
      'icon': Icons.radio_outlined,
      'color': Colors.deepOrange,
      'summary': 'Standard emergency frequency table, NOAA weather nets, and non-verbal whistle/light distress codes.',
      'hasRadioTable': true,
      'content': '''
STANDARD EMERGENCY FREQUENCIES & BANDS:
• NOAA Weather Radio: 162.400 - 162.550 MHz (Continuous official broadcasts)
• FRS / GMRS Channel 1: 462.5625 MHz (Standard consumer walkie-talkie hailing channel)
• FRS / GMRS Emergency: Channel 20 (462.6750 MHz) (National emergency assistance)
• MURS Channel 3: 151.940 MHz (VHF unlicensed neighborhood net)
• Ham 2-Meter Simplex: 146.520 MHz (National amateur VHF hailing frequency)
• Reticulum Mesh (LoRa): 915.000 MHz (US) / 868.000 MHz (EU) (NeighborNet off-grid packet data)

NON-VERBAL WHISTLE & LIGHT SIGNALS:
When radio silence is required or batteries are exhausted:
• 1 Short Blast: "Where are you? / Report status."
• 2 Short Blasts: "Come to my location / All clear."
• 3 Blasts (Whistle or Flashlight): "EMERGENCY / IMMEDIATE ASSISTANCE REQUIRED." (Standard international distress code).
''',
    },
  ];

  final List<String> _categories = [
    'All',
    'First 72 Hours',
    'Water',
    'Food',
    'Medical',
    'Sanitation',
    'Economy',
    'Defense',
    'Power',
    'Comms',
  ];

  void _broadcastChapterToBulletin(Map<String, dynamic> chapter) {
    final title = 'ADVISORY: ${chapter['title']}';
    final content = chapter['content'] as String;

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.campaign_rounded, color: chapter['color'] as Color? ?? Colors.amber),
            const SizedBox(width: 8),
            const Text('Broadcast Manual Section to Mesh'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Publish "${chapter['title']}" to the neighborhood community bulletin board for all local nodes to reference offline.',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                chapter['summary'] as String,
                style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.send_rounded),
            label: const Text('Broadcast Bulletin'),
            onPressed: () {
              widget.state.postBulletin(
                title: title,
                body: content,
                urgency: 'HIGH',
              );
              Navigator.pop(dialogCtx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Broadcasted "${chapter['title']}" to community bulletin!'),
                  backgroundColor: Colors.teal,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied $label to clipboard!'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredChapters = _chapters.where((ch) {
      final matchesCat = _selectedCategory == 'All' || ch['category'] == _selectedCategory;
      final query = _searchQuery.trim().toLowerCase();
      if (query.isEmpty) return matchesCat;

      final title = (ch['title'] as String).toLowerCase();
      final summary = (ch['summary'] as String).toLowerCase();
      final content = (ch['content'] as String).toLowerCase();
      final matchesQuery = title.contains(query) || summary.contains(query) || content.contains(query);
      return matchesCat && matchesQuery;
    }).toList();

    // Sort bookmarked chapters to the top
    filteredChapters.sort((a, b) {
      final aBookmarked = _bookmarkedIds.contains(a['id']);
      final bBookmarked = _bookmarkedIds.contains(b['id']);
      if (aBookmarked && !bBookmarked) return -1;
      if (!aBookmarked && bBookmarked) return 1;
      return 0;
    });

    return Scaffold(
      body: Column(
        children: [
          // Header banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.15),
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.menu_book_rounded, color: Colors.teal, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Civic & Collapse Survival Field Manual',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Offline-first protocols, purification calculators, triage & emergency radio codes',
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
                    hintText: 'Search survival protocols, bleach ratios, radio frequencies, WHO ORS...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setState(() => _searchQuery = ''),
                          )
                        : null,
                    isDense: true,
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
                const SizedBox(height: 10),

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

          // Chapter List
          Expanded(
            child: filteredChapters.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          'No protocols match "$_searchQuery"',
                          style: const TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredChapters.length,
                    itemBuilder: (context, index) {
                      final ch = filteredChapters[index];
                      final isBookmarked = _bookmarkedIds.contains(ch['id']);
                      final isExpanded = _expandedChapterId == ch['id'];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: isExpanded ? 2 : 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isBookmarked
                                ? Colors.amber.withValues(alpha: 0.6)
                                : Theme.of(context).dividerColor.withValues(alpha: 0.15),
                            width: isBookmarked ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: (ch['color'] as Color).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(ch['icon'] as IconData, color: ch['color'] as Color, size: 22),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      ch['title'] as String,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                  ),
                                  if (isBookmarked)
                                    const Icon(Icons.bookmark_rounded, color: Colors.amber, size: 18),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  ch['summary'] as String,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                  ),
                                ),
                              ),
                              trailing: IconButton(
                                icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
                                onPressed: () {
                                  setState(() {
                                    _expandedChapterId = isExpanded ? null : ch['id'] as String;
                                  });
                                },
                              ),
                              onTap: () {
                                setState(() {
                                  _expandedChapterId = isExpanded ? null : ch['id'] as String;
                                });
                              },
                            ),

                            // Expanded Content & Calculators
                            if (isExpanded) ...[
                              const Divider(height: 1),
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Interactive Water Calc
                                    if (ch['hasWaterCalc'] == true) ...[
                                      _buildWaterPurificationCalculator(context),
                                      const SizedBox(height: 16),
                                    ],

                                    // Interactive ORS Calc
                                    if (ch['hasOrsCalc'] == true) ...[
                                      _buildOrsCalculator(context),
                                      const SizedBox(height: 16),
                                    ],

                                    // Interactive Radio Freq Table
                                    if (ch['hasRadioTable'] == true) ...[
                                      _buildRadioFrequenciesTable(context),
                                      const SizedBox(height: 16),
                                    ],

                                    // Full Text Content
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                                        ),
                                      ),
                                      child: SelectableText(
                                        ch['content'] as String,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          height: 1.5,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),

                                    // Action Bar
                                    Row(
                                      children: [
                                        OutlinedButton.icon(
                                          icon: Icon(
                                            isBookmarked ? Icons.bookmark_remove : Icons.bookmark_add_outlined,
                                            size: 16,
                                          ),
                                          label: Text(isBookmarked ? 'Unpin' : 'Pin Protocol'),
                                          style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                                          onPressed: () {
                                            setState(() {
                                              if (isBookmarked) {
                                                _bookmarkedIds.remove(ch['id']);
                                              } else {
                                                _bookmarkedIds.add(ch['id'] as String);
                                              }
                                            });
                                          },
                                        ),
                                        const SizedBox(width: 8),
                                        OutlinedButton.icon(
                                          icon: const Icon(Icons.copy_rounded, size: 16),
                                          label: const Text('Copy Text'),
                                          style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                                          onPressed: () => _copyToClipboard(ch['content'] as String, ch['title'] as String),
                                        ),
                                        const Spacer(),
                                        FilledButton.tonalIcon(
                                          icon: const Icon(Icons.campaign_outlined, size: 16),
                                          label: const Text('Broadcast to Mesh'),
                                          style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                                          onPressed: () => _broadcastChapterToBulletin(ch),
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

  Widget _buildWaterPurificationCalculator(BuildContext context) {
    final dropsPerGallon = _waterCalcIsCloudy ? 16 : 8;
    final totalDrops = (_waterCalcGallons * dropsPerGallon).round();
    final tsp = totalDrops / 64.0;
    final ml = totalDrops * 0.05;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.calculate_outlined, color: Colors.blue, size: 20),
              SizedBox(width: 8),
              Text(
                'Interactive Bleach Dosage Calculator (6% Sodium Hypochlorite)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Volume: ${_waterCalcGallons.toStringAsFixed(1)} Gallons (${(_waterCalcGallons * 3.785).toStringAsFixed(1)} Liters)',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                    Slider(
                      value: _waterCalcGallons,
                      min: 0.5,
                      max: 20.0,
                      divisions: 39,
                      label: '${_waterCalcGallons.toStringAsFixed(1)} gal',
                      onChanged: (v) => setState(() => _waterCalcGallons = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilterChip(
                label: Text(_waterCalcIsCloudy ? 'Turbid / Cloudy' : 'Clear Water', style: const TextStyle(fontSize: 11)),
                selected: _waterCalcIsCloudy,
                selectedColor: Colors.amber.withValues(alpha: 0.3),
                onSelected: (v) => setState(() => _waterCalcIsCloudy = v),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildDosageStat('Total Drops', '$totalDrops drops', Colors.blue),
                _buildDosageStat('Teaspoons', '${tsp.toStringAsFixed(2)} tsp', Colors.teal),
                _buildDosageStat('Volume (mL)', '${ml.toStringAsFixed(1)} mL', Colors.purple),
                _buildDosageStat('Wait Time', '30 min', Colors.deepOrange),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrsCalculator(BuildContext context) {
    final sugarTsp = _orsWaterLiters * 6;
    final saltTsp = _orsWaterLiters * 0.5;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.local_pharmacy_outlined, color: Colors.redAccent, size: 20),
              SizedBox(width: 8),
              Text(
                'WHO Oral Rehydration Salts (ORS) Ratio Scale',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.redAccent),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Boiled Water: ${_orsWaterLiters.toStringAsFixed(1)} Liters (${(_orsWaterLiters * 4.22).toStringAsFixed(1)} Cups)',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                    Slider(
                      value: _orsWaterLiters,
                      min: 0.5,
                      max: 10.0,
                      divisions: 19,
                      label: '${_orsWaterLiters.toStringAsFixed(1)} L',
                      onChanged: (v) => setState(() => _orsWaterLiters = v),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildDosageStat('Sugar (Sucrose)', '${sugarTsp.toStringAsFixed(1)} tsp', Colors.amber.shade800),
                _buildDosageStat('Salt (NaCl)', '${saltTsp.toStringAsFixed(2)} tsp', Colors.blueGrey),
                _buildDosageStat('Boiled Clean Water', '${_orsWaterLiters.toStringAsFixed(1)} L', Colors.blue),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadioFrequenciesTable(BuildContext context) {
    final freqs = [
      {'service': 'NOAA Weather', 'freq': '162.400 - 162.550 MHz', 'desc': 'Continuous 24/7 disaster & weather broadcasts'},
      {'service': 'FRS / GMRS Ch 1', 'freq': '462.5625 MHz', 'desc': 'National walkie-talkie hailing channel'},
      {'service': 'FRS / GMRS Ch 20', 'freq': '462.6750 MHz', 'desc': 'National emergency & highway assistance'},
      {'service': 'MURS Channel 3', 'freq': '151.940 MHz', 'desc': 'VHF unlicensed neighborhood net'},
      {'service': 'Ham 2m Simplex', 'freq': '146.520 MHz', 'desc': 'National amateur VHF calling frequency'},
      {'service': 'Reticulum LoRa', 'freq': '915.000 MHz (US)', 'desc': 'NeighborNet off-grid packet data'},
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.deepOrange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.deepOrange.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.cell_tower_rounded, color: Colors.deepOrange, size: 20),
              SizedBox(width: 8),
              Text(
                'Emergency Radio Frequencies Quick Reference',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.deepOrange),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Table(
            border: TableBorder.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.2)),
            columnWidths: const {
              0: FlexColumnWidth(1.2),
              1: FlexColumnWidth(1.3),
              2: FlexColumnWidth(2.0),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface),
                children: const [
                  Padding(padding: EdgeInsets.all(6), child: Text('Service', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                  Padding(padding: EdgeInsets.all(6), child: Text('Frequency', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                  Padding(padding: EdgeInsets.all(6), child: Text('Purpose', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                ],
              ),
              ...freqs.map(
                (f) => TableRow(
                  children: [
                    Padding(padding: const EdgeInsets.all(6), child: Text(f['service']!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: InkWell(
                        onTap: () => _copyToClipboard(f['freq']!, f['service']!),
                        child: Row(
                          children: [
                            Text(f['freq']!, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.deepOrange)),
                            const SizedBox(width: 4),
                            const Icon(Icons.copy_rounded, size: 12, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                    Padding(padding: const EdgeInsets.all(6), child: Text(f['desc']!, style: const TextStyle(fontSize: 11))),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDosageStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}
