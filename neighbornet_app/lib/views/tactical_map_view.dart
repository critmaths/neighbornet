import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/neighbornet_models.dart';
import '../state/neighbornet_state.dart';

class TacticalMapView extends StatefulWidget {
  const TacticalMapView({super.key});

  @override
  State<TacticalMapView> createState() => _TacticalMapViewState();
}

class _TacticalMapViewState extends State<TacticalMapView>
    with SingleTickerProviderStateMixin {
  String _selectedCategory = 'all';
  TacticalMarker? _selectedMarker;
  bool _isRulerMode = false;
  TacticalMarker? _rulerStartMarker;
  TacticalMarker? _rulerEndMarker;

  late AnimationController _pulseController;
  final TransformationController _transformController =
      TransformationController();

  // Reference origin center for spatial grid simulation (Downtown / Sector 0)
  final double _originLat = 34.0522;
  final double _originLon = -118.2437;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  // Convert lat/lon offset to canvas coordinates (center at 1000, 1000)
  Offset _gpsToCanvas(double lat, double lon, Size canvasSize) {
    const double center = 1000.0;
    const double pixelsPerDegreeLat = 111000.0 * 0.1; // ~11.1km per 1110px
    final dy = (lat - _originLat) * pixelsPerDegreeLat;
    final dx = (lon - _originLon) * (pixelsPerDegreeLat * cos(_originLat * pi / 180));
    return Offset(center + dx, center - dy);
  }

  double _calculateDistanceKm(double lat1, double lon1, double lat2, double lon2) {
    const double p = 0.017453292519943295;
    final double a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'medical':
        return Colors.redAccent;
      case 'water':
        return Colors.cyanAccent;
      case 'shelter':
        return Colors.greenAccent;
      case 'hazard':
        return Colors.amberAccent;
      case 'checkpoint':
        return Colors.purpleAccent;
      case 'relay':
        return Colors.blueAccent;
      case 'sos':
        return Colors.orangeAccent;
      default:
        return Colors.tealAccent;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'medical':
        return Icons.medical_services_rounded;
      case 'water':
        return Icons.water_drop_rounded;
      case 'shelter':
        return Icons.night_shelter_rounded;
      case 'hazard':
        return Icons.warning_amber_rounded;
      case 'checkpoint':
        return Icons.flag_rounded;
      case 'relay':
        return Icons.cell_tower_rounded;
      case 'sos':
        return Icons.emergency_rounded;
      default:
        return Icons.location_on_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<NeighborNetState>();
    final theme = Theme.of(context);
    final markers = state.markers;

    final filteredMarkers = _selectedCategory == 'all'
        ? markers
        : markers.where((m) => m.category == _selectedCategory).toList();

    return Scaffold(
      body: Stack(
        children: [
          // Tactical Map Canvas
          InteractiveViewer(
            transformationController: _transformController,
            minScale: 0.2,
            maxScale: 4.0,
            boundaryMargin: const EdgeInsets.all(2000),
            constrained: false,
            child: SizedBox(
              width: 2000,
              height: 2000,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _TacticalGridPainter(
                      pulseValue: _pulseController.value,
                      markers: filteredMarkers,
                      rulerStart: _rulerStartMarker != null
                          ? _gpsToCanvas(_rulerStartMarker!.lat, _rulerStartMarker!.lon, const Size(2000, 2000))
                          : null,
                      rulerEnd: _rulerEndMarker != null
                          ? _gpsToCanvas(_rulerEndMarker!.lat, _rulerEndMarker!.lon, const Size(2000, 2000))
                          : null,
                      originLat: _originLat,
                      originLon: _originLon,
                      getColor: _getCategoryColor,
                      selectedMarker: _selectedMarker,
                      selectedTrace: state.selectedTrace,
                    ),
                    child: Stack(
                      children: [
                        for (final marker in filteredMarkers)
                          _buildMarkerWidget(marker),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          // Top Header & Category Filter Chips
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  elevation: 6,
                  color: theme.colorScheme.surface.withValues(alpha: 0.9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Icon(Icons.map_rounded, color: theme.colorScheme.primary),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Tactical Mesh Map',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              '${filteredMarkers.length} Active Coordinates • Offline Grid (MGRS)',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(
                            _isRulerMode ? Icons.straighten : Icons.square_foot_outlined,
                            color: _isRulerMode ? Colors.amberAccent : null,
                          ),
                          tooltip: 'Ruler / Distance Calculator',
                          onPressed: () {
                            setState(() {
                              _isRulerMode = !_isRulerMode;
                              _rulerStartMarker = null;
                              _rulerEndMarker = null;
                            });
                            if (_isRulerMode) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Ruler Mode: Click two markers to measure distance.'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.center_focus_strong),
                          tooltip: 'Recenter Grid',
                          onPressed: () {
                            _transformController.value = Matrix4.identity();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('all', 'All Markers', Icons.grid_view_rounded),
                      _buildFilterChip('medical', 'Medical', Icons.medical_services_rounded),
                      _buildFilterChip('water', 'Water', Icons.water_drop_rounded),
                      _buildFilterChip('shelter', 'Shelter', Icons.night_shelter_rounded),
                      _buildFilterChip('hazard', 'Hazards', Icons.warning_amber_rounded),
                      _buildFilterChip('checkpoint', 'Checkpoints', Icons.flag_rounded),
                      _buildFilterChip('relay', 'Mesh Relays', Icons.cell_tower_rounded),
                      _buildFilterChip('sos', 'SOS Beacons', Icons.emergency_rounded),
                    ],
                  ),
                ),
                if (state.selectedTrace != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF38BDF8), width: 1.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.alt_route, size: 16, color: Color(0xFF38BDF8)),
                        const SizedBox(width: 8),
                        Text(
                          'Route to ${state.selectedTrace!.targetNickname} (${state.selectedTrace!.hops.length} hops • ${state.selectedTrace!.totalRttMs ?? "--"}ms)',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => state.selectTrace(null),
                          child: const Icon(Icons.close, size: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Ruler Distance Overlay Card
          if (_isRulerMode && _rulerStartMarker != null && _rulerEndMarker != null)
            Positioned(
              bottom: 90,
              left: 16,
              right: 16,
              child: Card(
                color: Colors.black87,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Colors.amberAccent),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.straighten, color: Colors.amberAccent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Distance: ${_calculateDistanceKm(
                            _rulerStartMarker!.lat,
                            _rulerStartMarker!.lon,
                            _rulerEndMarker!.lat,
                            _rulerEndMarker!.lon,
                          ).toStringAsFixed(2)} km  (${_rulerStartMarker!.title} ➔ ${_rulerEndMarker!.title})',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          setState(() {
                            _rulerStartMarker = null;
                            _rulerEndMarker = null;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Selected Marker Detail Sheet
          if (_selectedMarker != null)
            Positioned(
              bottom: 16,
              left: 16,
              right: 80,
              child: Card(
                elevation: 8,
                color: theme.colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: _getCategoryColor(_selectedMarker!.category),
                    width: 2,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: _getCategoryColor(_selectedMarker!.category).withValues(alpha: 0.2),
                            child: Icon(
                              _getCategoryIcon(_selectedMarker!.category),
                              color: _getCategoryColor(_selectedMarker!.category),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedMarker!.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  'GPS: ${_selectedMarker!.lat.toStringAsFixed(4)}, ${_selectedMarker!.lon.toStringAsFixed(4)} • ${_selectedMarker!.category.toUpperCase()}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(() => _selectedMarker = null),
                          ),
                        ],
                      ),
                      if (_selectedMarker!.description.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(_selectedMarker!.description),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            'Reported by ${_selectedMarker!.authorNickname}${_selectedMarker!.authorCallsign.isNotEmpty ? " [${_selectedMarker!.authorCallsign}]" : ""}',
                            style: TextStyle(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            icon: const Icon(Icons.alt_route, size: 16, color: Color(0xFF38BDF8)),
                            label: const Text('Trace Route', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12)),
                            onPressed: () {
                              final marker = _selectedMarker!;
                              state.simulateTrace(marker.authorHash.isNotEmpty ? marker.authorHash : marker.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Tracing mesh route to ${marker.title}...'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                            label: const Text('Delete', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                            onPressed: () {
                              final markerToDelete = _selectedMarker!;
                              setState(() => _selectedMarker = null);
                              state.deleteMarker(markerToDelete.id);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_location_alt_rounded),
        label: const Text('Plot Marker'),
        onPressed: () => _showAddMarkerDialog(context),
      ),
    );
  }

  Widget _buildFilterChip(String category, String label, IconData icon) {
    final isSelected = _selectedCategory == category;
    final color = category == 'all' ? Theme.of(context).colorScheme.primary : _getCategoryColor(category);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        showCheckmark: false,
        avatar: Icon(icon, size: 16, color: isSelected ? Colors.black : color),
        label: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : null,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
        selectedColor: color,
        backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        onSelected: (selected) {
          setState(() {
            _selectedCategory = category;
          });
        },
      ),
    );
  }

  Widget _buildMarkerWidget(TacticalMarker marker) {
    final pos = _gpsToCanvas(marker.lat, marker.lon, const Size(2000, 2000));
    final color = _getCategoryColor(marker.category);
    final icon = _getCategoryIcon(marker.category);
    final isSelected = _selectedMarker?.id == marker.id;

    return Positioned(
      left: pos.dx - 24,
      top: pos.dy - 24,
      child: GestureDetector(
        onTap: () {
          if (_isRulerMode) {
            setState(() {
              if (_rulerStartMarker == null) {
                _rulerStartMarker = marker;
              } else if (_rulerEndMarker == null && _rulerStartMarker!.id != marker.id) {
                _rulerEndMarker = marker;
              } else {
                _rulerStartMarker = marker;
                _rulerEndMarker = null;
              }
            });
          } else {
            setState(() {
              _selectedMarker = marker;
            });
          }
        },
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: isSelected ? 0.9 : 0.3),
            border: Border.all(
              color: isSelected ? Colors.white : color,
              width: isSelected ? 3 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.5),
                blurRadius: isSelected ? 12 : 6,
                spreadRadius: isSelected ? 3 : 1,
              ),
            ],
          ),
          child: Icon(
            icon,
            size: 24,
            color: isSelected ? Colors.black : Colors.white,
          ),
        ),
      ),
    );
  }

  void _showAddMarkerDialog(BuildContext context) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    var category = 'medical';

    // Default coordinates near center with minor randomized spread
    final rand = Random();
    final lat = _originLat + (rand.nextDouble() - 0.5) * 0.04;
    final lon = _originLon + (rand.nextDouble() - 0.5) * 0.04;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.add_location_alt_rounded, color: Colors.amberAccent),
                  SizedBox(width: 8),
                  Text('Plot Community Marker'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: const InputDecoration(
                        labelText: 'Marker Category',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'medical', child: Text('Medical Triage / First Aid')),
                        DropdownMenuItem(value: 'water', child: Text('Water Distribution / Potable Well')),
                        DropdownMenuItem(value: 'shelter', child: Text('Safe Shelter / Evac Center')),
                        DropdownMenuItem(value: 'hazard', child: Text('Hazard / Obstruction / Fire')),
                        DropdownMenuItem(value: 'checkpoint', child: Text('Checkpoint / Rally Point')),
                        DropdownMenuItem(value: 'relay', child: Text('Mesh Relay / Repeater')),
                        DropdownMenuItem(value: 'sos', child: Text('SOS Emergency Beacon')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => category = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Location / Title',
                        hintText: 'e.g. Field Hospital Alpha',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Operational Details',
                        hintText: 'e.g. Supplies, capacity, hazards, access codes',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'GPS Coordinates: ${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
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
                  icon: const Icon(Icons.check),
                  label: const Text('Broadcast Marker'),
                  onPressed: () {
                    if (titleController.text.trim().isEmpty) return;
                    final state = context.read<NeighborNetState>();
                    final newMarker = TacticalMarker(
                      id: '',
                      title: titleController.text.trim(),
                      category: category,
                      description: descController.text.trim(),
                      lat: lat,
                      lon: lon,
                      authorHash: state.status?.destHash ?? '',
                      authorNickname: state.myProfile?.nickname ?? 'Neighbor',
                      authorCallsign: state.myProfile?.callsign ?? '',
                      timestampSec: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                      isActive: true,
                    );
                    state.upsertMarker(newMarker);
                    Navigator.pop(dialogCtx);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _TacticalGridPainter extends CustomPainter {
  final double pulseValue;
  final List<TacticalMarker> markers;
  final Offset? rulerStart;
  final Offset? rulerEnd;
  final double originLat;
  final double originLon;
  final Color Function(String) getColor;
  final TacticalMarker? selectedMarker;
  final TracerouteSession? selectedTrace;

  _TacticalGridPainter({
    required this.pulseValue,
    required this.markers,
    required this.rulerStart,
    required this.rulerEnd,
    required this.originLat,
    required this.originLon,
    required this.getColor,
    required this.selectedMarker,
    this.selectedTrace,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()..color = const Color(0xFF090D16);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);

    final gridPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..strokeWidth = 1.0;

    final majorGridPaint = Paint()
      ..color = const Color(0xFF334155)
      ..strokeWidth = 1.5;

    const double step = 50.0;
    for (double x = 0; x <= size.width; x += step) {
      final isMajor = (x % 250 == 0);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), isMajor ? majorGridPaint : gridPaint);
    }
    for (double y = 0; y <= size.height; y += step) {
      final isMajor = (y % 250 == 0);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), isMajor ? majorGridPaint : gridPaint);
    }

    // Concentric Radar Rings around Center (1000, 1000)
    const center = Offset(1000, 1000);
    final radarPaint = Paint()
      ..color = const Color(0xFF0EA5E9).withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (double r = 150; r <= 800; r += 150) {
      canvas.drawCircle(center, r, radarPaint);
    }

    // Pulse wave for SOS markers
    for (final marker in markers.where((m) => m.category == 'sos')) {
      const double centerCanvas = 1000.0;
      const double pixelsPerDegreeLat = 111000.0 * 0.1;
      final dy = (marker.lat - originLat) * pixelsPerDegreeLat;
      final dx = (marker.lon - originLon) * (pixelsPerDegreeLat * cos(originLat * pi / 180));
      final pos = Offset(centerCanvas + dx, centerCanvas - dy);

      final pulsePaint = Paint()
        ..color = Colors.orangeAccent.withValues(alpha: (1.0 - pulseValue) * 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;

      canvas.drawCircle(pos, 20 + pulseValue * 60, pulsePaint);
    }

    // Traceroute Vector Hop Overlay
    if (selectedTrace != null && selectedTrace!.hops.isNotEmpty) {
      final hops = selectedTrace!.hops;
      final List<Offset> hopPositions = [];

      // Find or synthesize canvas coordinates for each hop
      final targetMarker = markers.where((m) => m.authorHash == selectedTrace!.targetHash || m.id == selectedTrace!.targetHash).firstOrNull;
      final targetPos = targetMarker != null
          ? Offset(
              1000.0 + (targetMarker.lon - originLon) * (11100.0 * cos(originLat * pi / 180)),
              1000.0 - (targetMarker.lat - originLat) * 11100.0,
            )
          : const Offset(1350, 750);

      for (int i = 0; i < hops.length; i++) {
        if (i == 0) {
          hopPositions.add(center);
        } else if (i == hops.length - 1) {
          hopPositions.add(targetPos);
        } else {
          final t = i / (hops.length - 1);
          final intermediateMarker = markers.where((m) => m.authorHash == hops[i].nodeHash).firstOrNull;
          if (intermediateMarker != null) {
            hopPositions.add(Offset(
              1000.0 + (intermediateMarker.lon - originLon) * (11100.0 * cos(originLat * pi / 180)),
              1000.0 - (intermediateMarker.lat - originLat) * 11100.0,
            ));
          } else {
            // Curvature offset for intermediate mesh relays
            final base = Offset.lerp(center, targetPos, t)!;
            final curveOffset = Offset(
              sin(i * pi / 2) * 120,
              cos(i * pi / 2) * -90,
            );
            hopPositions.add(base + curveOffset);
          }
        }
      }

      // Draw glowing vector path
      final glowPaint = Paint()
        ..color = const Color(0xFF38BDF8).withValues(alpha: 0.35)
        ..strokeWidth = 8.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final pathPaint = Paint()
        ..color = const Color(0xFF38BDF8)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      for (int i = 0; i < hopPositions.length - 1; i++) {
        canvas.drawLine(hopPositions[i], hopPositions[i + 1], glowPaint);
        canvas.drawLine(hopPositions[i], hopPositions[i + 1], pathPaint);
      }

      // Draw animated travelling signal packet
      if (hopPositions.length > 1) {
        final totalSegments = hopPositions.length - 1;
        final currentProgress = pulseValue * totalSegments;
        final segIndex = currentProgress.floor().clamp(0, totalSegments - 1);
        final segT = currentProgress - segIndex;
        final packetPos = Offset.lerp(hopPositions[segIndex], hopPositions[segIndex + 1], segT)!;

        canvas.drawCircle(packetPos, 7, Paint()..color = Colors.white);
        canvas.drawCircle(packetPos, 14, Paint()..color = const Color(0xFF38BDF8).withValues(alpha: 0.6));
      }

      // Draw hop markers & labels
      for (int i = 0; i < hopPositions.length; i++) {
        final pos = hopPositions[i];
        final hop = hops[i];
        final isFirst = i == 0;
        final isLast = i == hopPositions.length - 1;

        final nodeColor = isFirst
            ? const Color(0xFF38BDF8)
            : isLast
                ? const Color(0xFF10B981)
                : const Color(0xFFA855F7);

        canvas.drawCircle(pos, 16, Paint()..color = const Color(0xFF0F172A));
        canvas.drawCircle(
          pos,
          16,
          Paint()
            ..color = nodeColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );

        // Hop number text
        final textPainter = TextPainter(
          text: TextSpan(
            text: '$i',
            style: TextStyle(color: nodeColor, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        textPainter.paint(canvas, pos - Offset(textPainter.width / 2, textPainter.height / 2));

        // Hop Nickname label
        final labelPainter = TextPainter(
          text: TextSpan(
            text: '${hop.nickname} (${hop.interfaceType})',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              backgroundColor: Color(0xCC000000),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        labelPainter.paint(canvas, pos + const Offset(18, -6));
      }
    }

    // Ruler Line
    if (rulerStart != null && rulerEnd != null) {
      final rulerLinePaint = Paint()
        ..color = Colors.amberAccent
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;

      canvas.drawLine(rulerStart!, rulerEnd!, rulerLinePaint);
      canvas.drawCircle(rulerStart!, 6, Paint()..color = Colors.amberAccent);
      canvas.drawCircle(rulerEnd!, 6, Paint()..color = Colors.amberAccent);
    }
  }

  @override
  bool shouldRepaint(covariant _TacticalGridPainter oldDelegate) => true;
}
