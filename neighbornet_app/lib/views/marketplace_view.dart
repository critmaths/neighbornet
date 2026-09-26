import 'package:flutter/material.dart';
import '../models/neighbornet_models.dart';
import '../state/neighbornet_state.dart';

class MarketplaceView extends StatefulWidget {
  final NeighborNetState state;

  const MarketplaceView({super.key, required this.state});

  @override
  State<MarketplaceView> createState() => _MarketplaceViewState();
}

class _MarketplaceViewState extends State<MarketplaceView> {
  String _searchQuery = '';
  BarterListing? _selectedListing;

  final List<String> _categories = [
    'All',
    'fuel',
    'food_water',
    'medical',
    'tools',
    'shelter',
    'skills',
    'comms',
    'general',
  ];

  final List<String> _types = [
    'All',
    'offer',
    'request',
    'skill',
  ];

  String _formatCategoryLabel(String cat) {
    switch (cat) {
      case 'fuel':
        return 'Fuel & Power';
      case 'food_water':
        return 'Food & Water';
      case 'medical':
        return 'Medical & First Aid';
      case 'tools':
        return 'Tools & Gear';
      case 'shelter':
        return 'Shelter & Warmth';
      case 'skills':
        return 'Skills & Aid';
      case 'comms':
        return 'Comms & Electronics';
      case 'general':
        return 'General / Other';
      case 'All':
      default:
        return 'All Categories';
    }
  }

  IconData _getCategoryIcon(String cat) {
    switch (cat) {
      case 'fuel':
        return Icons.local_gas_station;
      case 'food_water':
        return Icons.water_drop;
      case 'medical':
        return Icons.medical_services;
      case 'tools':
        return Icons.build;
      case 'shelter':
        return Icons.night_shelter;
      case 'skills':
        return Icons.handyman;
      case 'comms':
        return Icons.radio;
      case 'general':
      default:
        return Icons.category;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'offer':
        return Colors.greenAccent;
      case 'request':
        return Colors.orangeAccent;
      case 'skill':
        return Colors.cyanAccent;
      default:
        return Colors.amberAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final listings = widget.state.barterListings.where((l) {
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final match = l.title.toLowerCase().contains(query) ||
            l.description.toLowerCase().contains(query) ||
            l.seeking.toLowerCase().contains(query) ||
            l.authorNickname.toLowerCase().contains(query) ||
            l.category.toLowerCase().contains(query);
        if (!match) return false;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 800;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              _buildMetricsBanner(context),
              _buildFilterBar(context),
              Expanded(
                child: isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 5,
                            child: _buildListingList(listings),
                          ),
                          const VerticalDivider(width: 1, thickness: 1, color: Colors.white10),
                          Expanded(
                            flex: 6,
                            child: _buildListingDetail(_selectedListing),
                          ),
                        ],
                      )
                    : _selectedListing == null
                        ? _buildListingList(listings)
                        : _buildListingDetail(_selectedListing),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.6),
        border: const Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.storefront, color: Colors.amber, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mutual Aid & Barter Marketplace',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
                const SizedBox(height: 2),
                Text(
                  'Decentralized peer-to-peer resource exchange, skills trade, and verified community trust ledger.',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: () => _showCreateListingDialog(context),
            icon: const Icon(Icons.add_shopping_cart, size: 18),
            label: const Text('Post Listing'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.amber.shade700,
              foregroundColor: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsBanner(BuildContext context) {
    final all = widget.state.barterListings;
    final offers = all.where((l) => l.listingType == 'offer' && l.status != 'completed').length;
    final requests = all.where((l) => l.listingType == 'request' && l.status != 'completed').length;
    final skills = all.where((l) => l.listingType == 'skill' && l.status != 'completed').length;
    final completed = all.where((l) => l.status == 'completed').length;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _buildMetricChip('Active Offers', offers.toString(), Colors.greenAccent, Icons.volunteer_activism),
          const SizedBox(width: 12),
          _buildMetricChip('Active Requests', requests.toString(), Colors.orangeAccent, Icons.pan_tool_alt),
          const SizedBox(width: 12),
          _buildMetricChip('Skills & Aid', skills.toString(), Colors.cyanAccent, Icons.engineering),
          const SizedBox(width: 12),
          _buildMetricChip('Completed Trades', completed.toString(), Colors.purpleAccent, Icons.handshake),
        ],
      ),
    );
  }

  Widget _buildMetricChip(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
          const Text(': ', style: TextStyle(fontSize: 12, color: Colors.white70)),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search barter items, skills, authors...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              IconButton.outlined(
                tooltip: 'Refresh Listings',
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: () {
                  widget.state.refreshBarterListings();
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ..._categories.map((cat) {
                  final isSelected = (widget.state.barterFilterCategory == null && cat == 'All') ||
                      widget.state.barterFilterCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      selected: isSelected,
                      label: Text(_formatCategoryLabel(cat), style: const TextStyle(fontSize: 11)),
                      avatar: Icon(_getCategoryIcon(cat), size: 14),
                      onSelected: (selected) {
                        widget.state.setBarterFilters(
                          category: (selected && cat != 'All') ? cat : null,
                          listingType: widget.state.barterFilterType,
                        );
                      },
                    ),
                  );
                }),
                const SizedBox(width: 10),
                Container(height: 20, width: 1, color: Colors.white24),
                const SizedBox(width: 10),
                ..._types.map((type) {
                  final isSelected = (widget.state.barterFilterType == null && type == 'All') ||
                      widget.state.barterFilterType == type;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      selected: isSelected,
                      label: Text(
                        type == 'All' ? 'All Types' : type.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          color: isSelected ? Colors.black : _getTypeColor(type),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      selectedColor: _getTypeColor(type),
                      onSelected: (selected) {
                        widget.state.setBarterFilters(
                          category: widget.state.barterFilterCategory,
                          listingType: (selected && type != 'All') ? type : null,
                        );
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListingList(List<BarterListing> listings) {
    if (listings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.storefront_outlined, size: 64, color: Colors.white24),
              const SizedBox(height: 16),
              const Text('No Barter Listings Found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text(
                'Publish an offer, request aid, or offer a survival skill to the mesh network.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.white54),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: listings.length,
      itemBuilder: (context, index) {
        final item = listings[index];
        final isSelected = _selectedListing?.id == item.id;
        final typeColor = _getTypeColor(item.listingType);

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: isSelected ? 3 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: isSelected ? Colors.amber : Colors.white10,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            onTap: () {
              setState(() {
                _selectedListing = item;
              });
              widget.state.refreshProposalsForListing(item.id);
              widget.state.refreshVouchesForNode(item.authorHash);
            },
            leading: CircleAvatar(
              backgroundColor: typeColor.withValues(alpha: 0.2),
              child: Icon(_getCategoryIcon(item.category), color: typeColor, size: 20),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: typeColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    item.listingType.toUpperCase(),
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: typeColor),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  'Seeking: ${item.seeking}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.amberAccent),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      'By ${item.authorNickname}',
                      style: const TextStyle(fontSize: 11, color: Colors.white54),
                    ),
                    if (item.locationHint.isNotEmpty) ...[
                      const Text(' • ', style: TextStyle(color: Colors.white24)),
                      Icon(Icons.place, size: 12, color: Colors.white54),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          item.locationHint,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: Colors.white54),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: item.status == 'active' ? Colors.green.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                item.status.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: item.status == 'active' ? Colors.greenAccent : Colors.white70,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildListingDetail(BarterListing? listing) {
    if (listing == null) {
      return const Center(
        child: Text('Select a listing from the catalog to view trade details and submit proposals.',
            style: TextStyle(color: Colors.white54)),
      );
    }

    final proposals = widget.state.getProposalsForListing(listing.id);
    final vouches = widget.state.getVouchesForNode(listing.authorHash);
    final isAuthor = widget.state.status?.destHash != null && widget.state.status!.destHash == listing.authorHash;

    final avgRating = vouches.isEmpty ? 0.0 : vouches.map((v) => v.rating).reduce((a, b) => a + b) / vouches.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing.title,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Category: ${_formatCategoryLabel(listing.category)} • Condition: ${listing.itemCondition.toUpperCase()}',
                      style: const TextStyle(fontSize: 12, color: Colors.white60),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _selectedListing = null),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('DESCRIPTION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white54)),
                const SizedBox(height: 4),
                Text(listing.description, style: const TextStyle(fontSize: 13, height: 1.4)),
                const Divider(height: 20, color: Colors.white10),
                const Text('SEEKING / TERMS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amberAccent)),
                const SizedBox(height: 4),
                Text(listing.seeking, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.amber)),
                if (listing.locationHint.isNotEmpty) ...[
                  const Divider(height: 20, color: Colors.white10),
                  const Text('RENDEZVOUS / LOCATION HINT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white54)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.place, size: 14, color: Colors.white70),
                      const SizedBox(width: 4),
                      Text(listing.locationHint, style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Author & Trust Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blueGrey.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.blueGrey,
                  radius: 18,
                  child: Icon(Icons.person, size: 20, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        listing.authorNickname,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.star, size: 14, color: Colors.amber.shade400),
                          const SizedBox(width: 4),
                          Text(
                            vouches.isEmpty ? 'No vouches yet' : '${avgRating.toStringAsFixed(1)} / 5.0 (${vouches.length} vouches)',
                            style: const TextStyle(fontSize: 11, color: Colors.white70),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _showCommunityVouchDialog(context, listing.authorHash, listing.authorNickname),
                  icon: const Icon(Icons.verified_user, size: 14),
                  label: const Text('Vouch Node', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Proposals Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Trade Counter-Offers (${proposals.length})',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              if (!isAuthor)
                FilledButton.icon(
                  onPressed: () => _showSubmitProposalDialog(context, listing.id),
                  icon: const Icon(Icons.local_offer, size: 14),
                  label: const Text('Make Offer', style: TextStyle(fontSize: 12)),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.amber.shade700,
                    foregroundColor: Colors.black,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (proposals.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white10),
              ),
              child: const Center(
                child: Text('No counter-offers submitted for this listing yet.', style: TextStyle(fontSize: 12, color: Colors.white54)),
              ),
            )
          else
            ...proposals.map((p) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(p.proposerNickname, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: p.status == 'accepted'
                                  ? Colors.green.withValues(alpha: 0.2)
                                  : p.status == 'declined'
                                      ? Colors.red.withValues(alpha: 0.2)
                                      : Colors.amber.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              p.status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: p.status == 'accepted'
                                    ? Colors.greenAccent
                                    : p.status == 'declined'
                                        ? Colors.redAccent
                                        : Colors.amberAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('Offered: ${p.offeredItems}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      if (p.counterMessage.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text('Note: ${p.counterMessage}', style: const TextStyle(fontSize: 11, color: Colors.white70)),
                      ],
                      if (isAuthor && p.status == 'proposed') ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              onPressed: () {
                                widget.state.updateProposalStatus(p.id, listing.id, 'declined');
                              },
                              icon: const Icon(Icons.close, size: 14, color: Colors.redAccent),
                              label: const Text('Decline', style: TextStyle(fontSize: 11, color: Colors.redAccent)),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.icon(
                              onPressed: () {
                                widget.state.updateProposalStatus(p.id, listing.id, 'accepted');
                                widget.state.updateBarterStatus(listing.id, 'pending');
                              },
                              icon: const Icon(Icons.check, size: 14),
                              label: const Text('Accept Offer', style: TextStyle(fontSize: 11)),
                              style: FilledButton.styleFrom(backgroundColor: Colors.green),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  void _showCreateListingDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final seekingCtrl = TextEditingController();
    final locCtrl = TextEditingController();
    String type = 'offer';
    String category = 'food_water';
    String condition = 'good';

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            return AlertDialog(
              title: const Text('Create Barter Listing / Aid Request'),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: type,
                        decoration: const InputDecoration(labelText: 'Listing Type'),
                        items: const [
                          DropdownMenuItem(value: 'offer', child: Text('Resource Offer (Have item)')),
                          DropdownMenuItem(value: 'request', child: Text('Resource Request (Need item)')),
                          DropdownMenuItem(value: 'skill', child: Text('Skill / Labor Aid')),
                        ],
                        onChanged: (val) => setDlgState(() => type = val ?? 'offer'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(labelText: 'Title (e.g. 5 Gal Gasoline, Solar Setup)'),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: category,
                        decoration: const InputDecoration(labelText: 'Category'),
                        items: _categories
                            .where((c) => c != 'All')
                            .map((c) => DropdownMenuItem(value: c, child: Text(_formatCategoryLabel(c))))
                            .toList(),
                        onChanged: (val) => setDlgState(() => category = val ?? 'general'),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: condition,
                        decoration: const InputDecoration(labelText: 'Condition'),
                        items: const [
                          DropdownMenuItem(value: 'new', child: Text('New / Sealed')),
                          DropdownMenuItem(value: 'good', child: Text('Good Condition')),
                          DropdownMenuItem(value: 'fair', child: Text('Fair / Functional')),
                          DropdownMenuItem(value: 'poor', child: Text('Poor / Needs Repair')),
                          DropdownMenuItem(value: 'na', child: Text('N/A (Skill or Service)')),
                        ],
                        onChanged: (val) => setDlgState(() => condition = val ?? 'good'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: seekingCtrl,
                        decoration: const InputDecoration(labelText: 'Seeking in Exchange / Counter Terms'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: locCtrl,
                        decoration: const InputDecoration(labelText: 'Rendezvous / Grid Coordinate Hint'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: descCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(labelText: 'Detailed Description / Specifications'),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (titleCtrl.text.trim().isEmpty) return;
                    await widget.state.createBarterListing(
                      listingType: type,
                      title: titleCtrl.text.trim(),
                      description: descCtrl.text.trim(),
                      category: category,
                      itemCondition: condition,
                      seeking: seekingCtrl.text.trim(),
                      locationHint: locCtrl.text.trim(),
                    );
                    if (context.mounted) Navigator.of(dialogCtx).pop();
                  },
                  child: const Text('Post to Mesh'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSubmitProposalDialog(BuildContext context, String listingId) {
    final offerCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('Submit Counter-Offer / Proposal'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: offerCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Items / Skills Offered in Trade',
                    hintText: 'e.g. 2x MREs + Sawyer water filter',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: noteCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Rendezvous Terms / Note',
                    hintText: 'e.g. Can meet near checkpoint tomorrow at noon',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (offerCtrl.text.trim().isEmpty) return;
                await widget.state.submitBarterProposal(
                  listingId: listingId,
                  offeredItems: offerCtrl.text.trim(),
                  counterMessage: noteCtrl.text.trim(),
                );
                if (context.mounted) Navigator.of(dialogCtx).pop();
              },
              child: const Text('Send Proposal'),
            ),
          ],
        );
      },
    );
  }

  void _showCommunityVouchDialog(BuildContext context, String targetHash, String nickname) {
    int rating = 5;
    final commentCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            return AlertDialog(
              title: Text('Vouch for $nickname'),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Rate this neighbor based on honesty, item condition, and trade punctuality:'),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final star = index + 1;
                        return IconButton(
                          icon: Icon(
                            star <= rating ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 28,
                          ),
                          onPressed: () => setDlgState(() => rating = star),
                        );
                      }),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: commentCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Community Trust Note',
                        hintText: 'e.g. Reliable trade, goods were in advertised condition',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    await widget.state.submitCommunityVouch(
                      targetNodeHash: targetHash,
                      rating: rating,
                      reviewComment: commentCtrl.text.trim(),
                    );
                    if (context.mounted) Navigator.of(dialogCtx).pop();
                  },
                  child: const Text('Record Vouch'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
