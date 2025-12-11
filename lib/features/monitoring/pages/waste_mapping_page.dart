import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import '../../../core/widgets/app_bar.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/theme/color_palette.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/utils/date_formatter.dart';

class WasteMappingPage extends ConsumerStatefulWidget {
  const WasteMappingPage({super.key});

  @override
  ConsumerState<WasteMappingPage> createState() => _WasteMappingPageState();
}

class _WasteMappingPageState extends ConsumerState<WasteMappingPage> {
  final MapController _mapController = MapController();
  List<WasteDetection> _detections = [];
  List<WasteAreaSummary> _areaSummaries = [];
  bool _isLoading = true;
  String? _selectedType;
  DateTime? _startDate;
  DateTime? _endDate;

  final Map<String, Color> _trashColors = {
    'plastic': Colors.orange,
    'metal': Colors.grey,
    'paper': Colors.brown,
    'glass': Colors.cyan,
    'organic': Colors.green,
    'fabric': Colors.purple,
    'rubber': Colors.black87,
    'electronic': Colors.red,
    'other': Colors.blueGrey,
  };

  @override
  void initState() {
    super.initState();
    _subscribeWasteDetections();
  }

  StreamSubscription<DatabaseEvent>? _botsSubscription;
  StreamSubscription<fs.QuerySnapshot<Map<String, dynamic>>>? _deploymentsSubscription;
  Map<String, dynamic>? _botsCache;

  void _subscribeWasteDetections() {
    setState(() => _isLoading = true);

    final db = FirebaseDatabase.instance.ref('bots');
    _botsSubscription?.cancel();
    _botsSubscription = db.onValue.listen((event) {
      try {
        final raw = event.snapshot.value;
        if (raw != null && raw is Map) {
          _botsCache = Map<String, dynamic>.from(raw as Map);
        } else {
          _botsCache = {};
        }
        _rebuildDetectionsFromCache();
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error reading realtime waste data: $e')),
          );
        }
      }
    }, onError: (error) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Realtime stream error: $error')),
        );
      }
    });
    _subscribeAreaSummaries();
  }

  void _rebuildDetectionsFromCache() {
    try {
      final auth = ref.read(authProvider);
      final userId = auth.currentUser?.uid;
      final isAdmin = auth.userProfile?.isAdmin ?? false;

      if (userId == null) {
        setState(() {
          _detections = [];
          _isLoading = false;
        });
        return;
      }

      final botsData = _botsCache ?? {};
      final List<WasteDetection> allDetections = [];

      for (var botEntry in botsData.entries) {
        final botId = botEntry.key;
        final value = botEntry.value;
        if (value is! Map) continue;
        final botData = Map<String, dynamic>.from(value as Map);

        if (!isAdmin) {
          final assignedTo = botData['assigned_to'] as String?;
          if (assignedTo != userId) continue;
        }

        if (botData.containsKey('trash_collection') && botData['trash_collection'] is Map) {
          final trashData = Map<String, dynamic>.from(botData['trash_collection'] as Map);
          for (var trashEntry in trashData.entries) {
            final itemRaw = trashEntry.value;
            if (itemRaw is! Map) continue;
            final item = Map<String, dynamic>.from(itemRaw as Map);

            final type = (item['type'] as String?)?.toLowerCase() ?? 'other';
            final latNum = (item['latitude'] ?? item['lat']);
            final lngNum = (item['longitude'] ?? item['lng']);
            final timestamp = item['timestamp'] as int?;
            final confidenceNum = (item['confidence_level'] ?? item['confidence']);
            final weightNum = (item['weight'] ?? item['weight_kg']);

            final lat = latNum is num ? latNum.toDouble() : null;
            final lng = lngNum is num ? lngNum.toDouble() : null;
            final confidence = confidenceNum is num ? confidenceNum.toDouble() : null;
            final weight = weightNum is num ? weightNum.toDouble() : null;

            if (lat != null && lng != null) {
              final detectionTime = timestamp != null
                  ? DateTime.fromMillisecondsSinceEpoch(timestamp)
                  : DateTime.now();

              if (_selectedType != null && type != _selectedType) continue;
              if (_startDate != null && detectionTime.isBefore(_startDate!)) continue;
              if (_endDate != null && detectionTime.isAfter(_endDate!)) continue;

              allDetections.add(WasteDetection(
                id: trashEntry.key,
                botId: botId,
                type: type,
                latitude: lat,
                longitude: lng,
                timestamp: detectionTime,
                confidenceLevel: confidence ?? 0.0,
                weight: weight,
              ));
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _detections = allDetections;
          _isLoading = false;
        });
        if (_detections.isNotEmpty) {
          final firstDetection = _detections.first;
          _mapController.move(
            LatLng(firstDetection.latitude, firstDetection.longitude),
            13.0,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error rebuilding detections: $e')),
        );
      }
    }
  }

  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const GlobalAppBar(
        title: 'Waste Mapping',
        showDrawer: false,
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: _isLoading
                ? const LoadingIndicator()
                : _detections.isEmpty
                    ? _buildEmptyState()
                    : Stack(
                        children: [
                          _buildMap(),
                          _buildLegend(),
                          _buildStats(),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(
            color: AppColors.border.withValues(alpha: 0.3),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildTypeFilter(),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _showDateRangePicker,
                icon: const Icon(Icons.date_range, size: 18),
                label: Text(
                  _startDate != null && _endDate != null
                      ? 'Custom Range'
                      : 'Date Range',
                  style: AppTextStyles.bodySmall,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _clearFilters,
                icon: const Icon(Icons.clear_all),
                tooltip: 'Clear Filters',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: _selectedType,
          hint: Text('All Waste Types', style: AppTextStyles.bodySmall),
          isExpanded: true,
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('All Waste Types'),
            ),
            ..._trashColors.keys.map((type) {
              return DropdownMenuItem<String?>(
                value: type,
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _trashColors[type],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(type.toUpperCase()),
                  ],
                ),
              );
            }),
          ],
          onChanged: (value) {
            setState(() => _selectedType = value);
            _loadWasteDetections();
          },
        ),
      ),
    );
  }

  Future<void> _showDateRangePicker() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadWasteDetections();
      _loadAreaSummaries();
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedType = null;
      _startDate = null;
      _endDate = null;
    });
    _loadWasteDetections();
    _loadAreaSummaries();
  }

  @override
  void dispose() {
    _botsSubscription?.cancel();
    _deploymentsSubscription?.cancel();
    _deploymentsSubscription = null;
    _botsSubscription = null;
    super.dispose();
  }

  Future<void> _loadWasteDetections() async {
    // When filters change, rebuild from cache; first-time call sets up subscription
    if (_botsSubscription == null) {
      _subscribeWasteDetections();
    } else {
      _rebuildDetectionsFromCache();
    }
  }

  Future<void> _loadAreaSummaries() async {
    _subscribeAreaSummaries();
  }

  void _subscribeAreaSummaries() {
    _deploymentsSubscription?.cancel();
    final auth = ref.read(authProvider);
    final profile = auth.userProfile;
    if (profile == null) {
      if (mounted) {
        setState(() => _areaSummaries = []);
      }
      return;
    }

    final fs.CollectionReference<Map<String, dynamic>> deploymentsCol =
        fs.FirebaseFirestore.instance.collection('deployments');
    fs.Query<Map<String, dynamic>> query = deploymentsCol
        .where('status', isEqualTo: 'completed');

    if (profile.isAdmin) {
      query = query.where('owner_admin_id', isEqualTo: profile.id);
    }

    final DateTime? start = _startDate;
    final DateTime? end = _endDate;
    if (start != null && end != null) {
      query = query
          .where('actual_end_time', isGreaterThanOrEqualTo: fs.Timestamp.fromDate(start))
          .where('actual_end_time', isLessThan: fs.Timestamp.fromDate(end));
    }

    _deploymentsSubscription = query
        .orderBy('actual_end_time', descending: true)
        .limit(200)
        .snapshots()
        .listen((snapshot) {
      final List<WasteAreaSummary> summaries = [];
      for (final doc in snapshot.docs) {
        final Map<String, dynamic> data = doc.data();
        final opLatNum = data['operation_lat'] as num?;
        final opLngNum = data['operation_lng'] as num?;
        if (opLatNum == null || opLngNum == null) continue;
        final opLat = opLatNum.toDouble();
        final opLng = opLngNum.toDouble();
        final locationName = data['operation_location'] as String?;
        final riverName = data['river_name'] as String?;
        final trash = (data['trash_collection'] ?? data['trash_collection_summary']) as Map<String, dynamic>?;
        final totalWeight = (trash?['total_weight'] as num?)?.toDouble() ?? 0.0;
        final totalItems = (trash?['total_items'] as num?)?.toInt() ?? 0;
        final byTypeRaw = trash?['trash_by_type'] as Map<String, dynamic>?;
        final Map<String, int> byType = byTypeRaw != null
            ? byTypeRaw.map((k, v) => MapEntry(k, (v is num) ? v.toInt() : 0))
            : <String, int>{};
        final completedAt = (data['completed_at'] as fs.Timestamp?)?.toDate() ??
            (data['actual_end_time'] as fs.Timestamp?)?.toDate() ?? DateTime.now();
        final scheduleName = data['schedule_name'] as String? ?? '';
        summaries.add(WasteAreaSummary(
          deploymentId: doc.id,
          scheduleName: scheduleName,
          locationName: locationName,
          riverName: riverName,
          latitude: opLat,
          longitude: opLng,
          totalWeight: totalWeight,
          totalItems: totalItems,
          trashByType: byType,
          completedAt: completedAt,
        ));
      }

      if (mounted) {
        setState(() {
          _areaSummaries = summaries;
          if (_detections.isEmpty && _areaSummaries.isNotEmpty) {
            final first = _areaSummaries.first;
            _mapController.move(LatLng(first.latitude, first.longitude), 13.0);
          }
        });
      }
    }, onError: (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading area summaries: $e')),
        );
      }
    });
  }

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: const LatLng(14.5995, 120.9842), // Manila default
        initialZoom: 13.0,
        minZoom: 5.0,
        maxZoom: 18.0,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.agos.app',
        ),
        MarkerLayer(
          markers: _detections.map((d) {
            return Marker(
              point: LatLng(d.latitude, d.longitude),
              width: 16,
              height: 16,
              child: GestureDetector(
                onTap: () => _showDetectionDetails(d),
                child: Container(
                  decoration: BoxDecoration(
                    color: (_trashColors[d.type] ?? Colors.grey).withValues(alpha: 0.8),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        MarkerLayer(
          markers: _areaSummaries.map((area) {
            return Marker(
              point: LatLng(area.latitude, area.longitude),
              width: 36,
              height: 36,
              child: GestureDetector(
                onTap: () => _showAreaSummaryDetails(area),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.location_on,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        MarkerLayer(
          markers: _detections.map((detection) {
            return Marker(
              point: LatLng(detection.latitude, detection.longitude),
              width: 30,
              height: 30,
              child: GestureDetector(
                onTap: () => _showDetectionDetails(detection),
                child: Container(
                  decoration: BoxDecoration(
                    color: _trashColors[detection.type] ?? Colors.grey,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.delete_outline,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildLegend() {
    return Positioned(
      top: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Waste Types',
              style: AppTextStyles.labelMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ..._trashColors.entries.map((entry) {
              final count = _detections.where((d) => d.type == entry.key).length;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: entry.value,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${entry.key.toUpperCase()}: $count',
                      style: AppTextStyles.labelSmall,
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildStats() {
    final totalWeight = _detections.fold<double>(
      0.0,
      (sum, d) => sum + (d.weight ?? 0.0),
    );
    
    final avgConfidence = _detections.isNotEmpty
        ? _detections.fold<double>(0.0, (sum, d) => sum + d.confidenceLevel) /
            _detections.length
        : 0.0;

    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(
              icon: Icons.pin_drop,
              label: 'Detections',
              value: '${_detections.length}',
            ),
            _buildStatItem(
              icon: Icons.scale,
              label: 'Total Weight',
              value: '${totalWeight.toStringAsFixed(2)} kg',
            ),
            _buildStatItem(
              icon: Icons.analytics,
              label: 'Avg Confidence',
              value: '${(avgConfidence * 100).toStringAsFixed(1)}%',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTextStyles.titleSmall.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.map_outlined,
            size: 64,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 16),
          Text(
            'No Waste Detections',
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Waste detections from deployed bots will appear here',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textMuted,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showDetectionDetails(WasteDetection detection) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: (_trashColors[detection.type] ?? Colors.grey)
                        .withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.delete_outline,
                    color: _trashColors[detection.type] ?? Colors.grey,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        detection.type.toUpperCase(),
                        style: AppTextStyles.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Bot ID: ${detection.botId}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildDetailRow(
              icon: Icons.access_time,
              label: 'Detected At',
              value: DateFormatter.formatDateTime(detection.timestamp),
            ),
            _buildDetailRow(
              icon: Icons.location_on,
              label: 'Coordinates',
              value:
                  '${detection.latitude.toStringAsFixed(6)}, ${detection.longitude.toStringAsFixed(6)}',
            ),
            _buildDetailRow(
              icon: Icons.analytics,
              label: 'Confidence',
              value: '${(detection.confidenceLevel * 100).toStringAsFixed(1)}%',
            ),
            if (detection.weight != null)
              _buildDetailRow(
                icon: Icons.scale,
                label: 'Weight',
                value: '${detection.weight!.toStringAsFixed(2)} kg',
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAreaSummaryDetails(WasteAreaSummary area) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.location_on,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        area.locationName ?? area.riverName ?? area.scheduleName,
                        style: AppTextStyles.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Completed: ${DateFormatter.formatDateTime(area.completedAt)}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildDetailRow(
              icon: Icons.scale,
              label: 'Total Weight',
              value: '${area.totalWeight.toStringAsFixed(2)} kg',
            ),
            _buildDetailRow(
              icon: Icons.inventory_2,
              label: 'Total Items',
              value: '${area.totalItems}',
            ),
            const SizedBox(height: 12),
            Text('Breakdown by Type', style: AppTextStyles.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: area.trashByType.entries.map((e) {
                return Chip(
                  label: Text('${e.key.toUpperCase()}: ${e.value}'),
                  backgroundColor: (_trashColors[e.key] ?? Colors.grey).withValues(alpha: 0.15),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
                Text(
                  value,
                  style: AppTextStyles.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class WasteDetection {
  final String id;
  final String botId;
  final String type;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double confidenceLevel;
  final double? weight;

  WasteDetection({
    required this.id,
    required this.botId,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.confidenceLevel,
    this.weight,
  });
}

class WasteAreaSummary {
  final String deploymentId;
  final String scheduleName;
  final String? locationName;
  final String? riverName;
  final double latitude;
  final double longitude;
  final double totalWeight;
  final int totalItems;
  final Map<String, int> trashByType;
  final DateTime completedAt;

  WasteAreaSummary({
    required this.deploymentId,
    required this.scheduleName,
    required this.locationName,
    required this.riverName,
    required this.latitude,
    required this.longitude,
    required this.totalWeight,
    required this.totalItems,
    required this.trashByType,
    required this.completedAt,
  });
}

