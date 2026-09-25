import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/neighbornet_models.dart';
import '../state/neighbornet_state.dart';

class TracerouteView extends StatefulWidget {
  final VoidCallback? onSwitchToMap;

  const TracerouteView({super.key, this.onSwitchToMap});

  @override
  State<TracerouteView> createState() => _TracerouteViewState();
}

class _TracerouteViewState extends State<TracerouteView> {
  final TextEditingController _targetController = TextEditingController();
  int _selectedTtl = 8;
  String? _selectedPeerHash;

  @override
  void dispose() {
    _targetController.dispose();
    super.dispose();
  }

  void _runTrace(NeighborNetState state, {bool simulate = false}) async {
    final targetHash = _targetController.text.trim();
    if (targetHash.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a peer or enter a target hash')),
      );
      return;
    }

    if (simulate) {
      await state.simulateTrace(targetHash);
    } else {
      await state.initiateTraceroute(targetHash, maxTtl: _selectedTtl);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<NeighborNetState>();
    final activeTrace = state.selectedTrace ?? (state.traceroutes.isNotEmpty ? state.traceroutes.first : null);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.alt_route, color: Color(0xFF38BDF8)),
            SizedBox(width: 8),
            Text('Multi-Hop Mesh Traceroute'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Traces',
            onPressed: () => state.refreshTraceroutes(),
          ),
          if (widget.onSwitchToMap != null)
            IconButton(
              icon: const Icon(Icons.map_outlined),
              tooltip: 'View on Tactical Map',
              onPressed: widget.onSwitchToMap,
            ),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Sidebar: Target Selector & History
          SizedBox(
            width: 320,
            child: Container(
              decoration: BoxDecoration(
                border: Border(right: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.1))),
              ),
              child: Column(
                children: [
                  _buildTargetInputCard(state),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'TRACE SESSIONS',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1, color: Colors.grey.shade400),
                        ),
                        Text(
                          '${state.traceroutes.length}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: state.traceroutes.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                'No traceroutes initiated yet.\nSelect a target above to discover mesh hops.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: state.traceroutes.length,
                            itemBuilder: (context, index) {
                              final trace = state.traceroutes[index];
                              final isSelected = activeTrace?.traceId == trace.traceId;
                              return _buildTraceSessionTile(trace, isSelected, state);
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),

          // Right Area: Live Hop Waterfall & Diagnostic Details
          Expanded(
            child: activeTrace == null
                ? _buildEmptyState(state)
                : _buildTraceDetailView(activeTrace, state),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetInputCard(NeighborNetState state) {
    final availablePeers = state.peers;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('DISCOVERY TARGET', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1, color: Color(0xFF38BDF8))),
          const SizedBox(height: 10),
          if (availablePeers.isNotEmpty) ...[
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _selectedPeerHash,
              decoration: const InputDecoration(
                labelText: 'Select Mesh Peer',
                prefixIcon: Icon(Icons.people_outline, size: 20),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: availablePeers.map((p) {
                return DropdownMenuItem<String>(
                  value: p.destHash,
                  child: Text(
                    '${p.nickname} (${p.destHash.substring(0, 6)}...)',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedPeerHash = val;
                    _targetController.text = val;
                  });
                }
              },
            ),
            const SizedBox(height: 10),
          ],
          TextField(
            controller: _targetController,
            decoration: InputDecoration(
              labelText: 'Target Node Hash',
              hintText: 'e.g. f0e1d2c3...',
              prefixIcon: const Icon(Icons.tag, size: 20),
              suffixIcon: _targetController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => setState(() {
                        _targetController.clear();
                        _selectedPeerHash = null;
                      }),
                    )
                  : null,
            ),
            style: const TextStyle(fontFamily: 'Courier', fontSize: 12),
            onChanged: (val) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Max TTL:', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: _selectedTtl,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 4, child: Text('4 Hops')),
                  DropdownMenuItem(value: 8, child: Text('8 Hops')),
                  DropdownMenuItem(value: 12, child: Text('12 Hops')),
                  DropdownMenuItem(value: 16, child: Text('16 Hops')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedTtl = val);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: state.isTracing ? null : () => _runTrace(state, simulate: false),
                  icon: state.isTracing
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.radar, size: 16),
                  label: const Text('Trace Route'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                icon: const Icon(Icons.science_outlined, size: 18),
                tooltip: 'Simulate Multi-Hop Path',
                onPressed: state.isTracing ? null : () => _runTrace(state, simulate: true),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTraceSessionTile(TracerouteSession trace, bool isSelected, NeighborNetState state) {
    Color statusColor;
    IconData statusIcon;
    switch (trace.status) {
      case 'reached_destination':
        statusColor = const Color(0xFF10B981);
        statusIcon = Icons.check_circle_outline;
        break;
      case 'ttl_expired':
        statusColor = const Color(0xFFF59E0B);
        statusIcon = Icons.timer_off_outlined;
        break;
      case 'in_transit':
        statusColor = const Color(0xFF38BDF8);
        statusIcon = Icons.sync;
        break;
      default:
        statusColor = const Color(0xFFEF4444);
        statusIcon = Icons.error_outline;
    }

    return ListTile(
      selected: isSelected,
      selectedTileColor: const Color(0xFF38BDF8).withValues(alpha: 0.1),
      leading: Icon(statusIcon, color: statusColor, size: 20),
      title: Text(
        trace.targetNickname,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
      subtitle: Text(
        '${trace.hops.length} hops • ${trace.totalRttMs != null ? "${trace.totalRttMs} ms" : "measuring..."}',
        style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
      ),
      trailing: const Icon(Icons.chevron_right, size: 16),
      onTap: () => state.selectTrace(trace),
    );
  }

  Widget _buildEmptyState(NeighborNetState state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.alt_route, size: 64, color: Colors.grey.shade600),
          const SizedBox(height: 16),
          const Text(
            'Ready to Trace Mesh Network Route',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Discover hop-by-hop latency, SNR/RSSI signal margins, and interface types.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            icon: const Icon(Icons.science_outlined),
            label: const Text('Simulate 4-Hop Route Demo'),
            onPressed: () => state.simulateTrace('sim-target-node-77'),
          ),
        ],
      ),
    );
  }

  Widget _buildTraceDetailView(TracerouteSession trace, NeighborNetState state) {
    return ListView(
      padding: const EdgeInsets.all(24.0),
      children: [
        // Summary Header Card
        _buildSummaryHeaderCard(trace, state),
        const SizedBox(height: 24),

        // Route Waterfall Section
        const Row(
          children: [
            Icon(Icons.waterfall_chart, size: 18, color: Color(0xFF38BDF8)),
            SizedBox(width: 8),
            Text(
              'HOP-BY-HOP ROUTE WATERFALL',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1, color: Color(0xFF38BDF8)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildHopWaterfall(trace),
        const SizedBox(height: 24),

        // Link Health & Performance Analytics
        _buildRouteAnalyticsCard(trace),
      ],
    );
  }

  Widget _buildSummaryHeaderCard(TracerouteSession trace, NeighborNetState state) {
    Color statusColor;
    String statusLabel;
    switch (trace.status) {
      case 'reached_destination':
        statusColor = const Color(0xFF10B981);
        statusLabel = 'DESTINATION REACHED (OPTIMAL)';
        break;
      case 'ttl_expired':
        statusColor = const Color(0xFFF59E0B);
        statusLabel = 'TTL EXPIRED (HOPS EXCEEDED)';
        break;
      case 'in_transit':
        statusColor = const Color(0xFF38BDF8);
        statusLabel = 'IN TRANSIT...';
        break;
      default:
        statusColor = const Color(0xFFEF4444);
        statusLabel = 'TRACE TIMEOUT';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Text(
                  'ID: ${trace.traceId}',
                  style: TextStyle(fontFamily: 'Courier', fontSize: 11, color: Colors.grey.shade400),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ORIGIN NODE', style: TextStyle(fontSize: 10, color: Colors.grey.shade400, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(trace.originNickname, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text('${trace.originHash.substring(0, trace.originHash.length.clamp(0, 10))}...', style: const TextStyle(fontFamily: 'Courier', fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward, color: Color(0xFF38BDF8), size: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('TARGET DESTINATION', style: TextStyle(fontSize: 10, color: Colors.grey.shade400, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(trace.targetNickname, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text('${trace.targetHash.substring(0, trace.targetHash.length.clamp(0, 10))}...', style: const TextStyle(fontFamily: 'Courier', fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatColumn('Total Round-Trip', '${trace.totalRttMs ?? "--"} ms', Icons.speed),
                _buildStatColumn('Hop Count', '${trace.hops.length} Hops', Icons.route),
                _buildStatColumn('Remaining TTL', '${trace.ttl} / ${trace.maxTtl}', Icons.hourglass_bottom),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String title, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF38BDF8)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        Text(title, style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
      ],
    );
  }

  Widget _buildHopWaterfall(TracerouteSession trace) {
    return Column(
      children: List.generate(trace.hops.length, (index) {
        final hop = trace.hops[index];
        final isFirst = index == 0;
        final isLast = index == trace.hops.length - 1;

        return Column(
          children: [
            _buildHopCard(hop, index, isFirst, isLast),
            if (!isLast) _buildHopConnector(trace.hops[index + 1].deltaMs),
          ],
        );
      }),
    );
  }

  Widget _buildHopCard(TraceHop hop, int index, bool isFirst, bool isLast) {
    Color badgeColor;
    String hopLabel;
    if (isFirst) {
      badgeColor = const Color(0xFF38BDF8);
      hopLabel = 'Hop $index • Origin Host';
    } else if (isLast) {
      badgeColor = const Color(0xFF10B981);
      hopLabel = 'Hop $index • Destination Target';
    } else {
      badgeColor = const Color(0xFFA855F7);
      hopLabel = 'Hop $index • Mesh Relay';
    }

    IconData ifaceIcon;
    if (hop.interfaceType.contains('LoRa')) {
      ifaceIcon = Icons.settings_input_antenna;
    } else if (hop.interfaceType.contains('BLE')) {
      ifaceIcon = Icons.bluetooth;
    } else if (hop.interfaceType.contains('UDP')) {
      ifaceIcon = Icons.lan;
    } else {
      ifaceIcon = Icons.laptop;
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: badgeColor.withValues(alpha: 0.15),
              child: Text('$index', style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(hop.nickname, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      if (hop.callsign.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(hop.callsign, style: const TextStyle(fontSize: 10, fontFamily: 'Courier', fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(hopLabel, style: TextStyle(fontSize: 11, color: badgeColor)),
                  const SizedBox(height: 4),
                  Text('${hop.nodeHash.substring(0, hop.nodeHash.length.clamp(0, 16))}...', style: const TextStyle(fontFamily: 'Courier', fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(ifaceIcon, size: 12, color: Colors.blueGrey.shade200),
                      const SizedBox(width: 4),
                      Text(hop.interfaceType, style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hop.rssiDbm != null) ...[
                      _buildSignalBadge('${hop.rssiDbm} dBm', _getRssiColor(hop.rssiDbm!)),
                      const SizedBox(width: 6),
                    ],
                    if (hop.snrDb != null)
                      _buildSignalBadge('${hop.snrDb} dB SNR', _getSnrColor(hop.snrDb!)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHopConnector(int deltaMs) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(width: 2, height: 24, color: const Color(0xFF38BDF8).withValues(alpha: 0.5)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF38BDF8).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
            ),
            child: Text(
              '+$deltaMs ms',
              style: const TextStyle(fontSize: 11, fontFamily: 'Courier', color: Color(0xFF38BDF8), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignalBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold, fontFamily: 'Courier'),
      ),
    );
  }

  Color _getRssiColor(int rssi) {
    if (rssi >= -70) return const Color(0xFF10B981);
    if (rssi >= -85) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  Color _getSnrColor(double snr) {
    if (snr >= 9.0) return const Color(0xFF10B981);
    if (snr >= 5.0) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  Widget _buildRouteAnalyticsCard(TracerouteSession trace) {
    TraceHop? bottleneckHop;
    int maxDelta = -1;
    for (int i = 1; i < trace.hops.length; i++) {
      if (trace.hops[i].deltaMs > maxDelta) {
        maxDelta = trace.hops[i].deltaMs;
        bottleneckHop = trace.hops[i];
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.analytics_outlined, size: 18, color: Color(0xFF38BDF8)),
                SizedBox(width: 8),
                Text('LINK QUALITY & BOTTLENECK ANALYSIS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1, color: Color(0xFF38BDF8))),
              ],
            ),
            const SizedBox(height: 12),
            if (bottleneckHop != null) ...[
              Row(
                children: [
                  const Icon(Icons.warning_amber, size: 16, color: Color(0xFFF59E0B)),
                  const SizedBox(width: 6),
                  Text('Bottleneck Link: ${bottleneckHop.nickname} (+$maxDelta ms)', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Interface: ${bottleneckHop.interfaceType} • Signal: ${bottleneckHop.rssiDbm ?? "N/A"} dBm',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
              ),
            ] else ...[
              const Text('Single-hop direct link. Zero routing delay observed.', style: TextStyle(fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }
}
