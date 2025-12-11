import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../../core/widgets/app_bar.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/theme/color_palette.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/utils/date_formatter.dart';

class DetectionEventsPage extends ConsumerStatefulWidget {
  const DetectionEventsPage({super.key});

  @override
  ConsumerState<DetectionEventsPage> createState() => _DetectionEventsPageState();
}

class _DetectionEventsPageState extends ConsumerState<DetectionEventsPage> {
  List<WasteDetectionEvent> _events = [];
  List<WasteDetectionEvent> _filteredEvents = [];
  bool _isLoading = true;
  String? _selectedType;
  String? _selectedLocation;
  DateTime? _startDate;
  DateTime? _endDate;
  String _sortBy = 'recent'; // recent, type, location, confidence

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
    _loadDetectionEvents();
  }

  Future<void> _loadDetectionEvents() async {
    setState(() => _isLoading = true);

    try {
      final auth = ref.read(authProvider);
      final userId = auth.currentUser?.uid;
      final isAdmin = auth.userProfile?.isAdmin ?? false;

      if (userId == null) {
        setState(() => _isLoading = false);
        return;
      }

      final db = FirebaseDatabase.instance.ref();
      final botsSnapshot = await db.child('bots').get();
      
      List<WasteDetectionEvent> allEvents = [];
      
      if (botsSnapshot.exists && botsSnapshot.value is Map) {
        final botsData = Map<String, dynamic>.from(botsSnapshot.value as Map);
        
        for (var botEntry in botsData.entries) {
          final botId = botEntry.key;
          final botData = Map<String, dynamic>.from(botEntry.value as Map);
          final botName = botData['name'] as String? ?? 'Unknown Bot';
          
          // Role-based filtering
          if (!isAdmin) {
            final assignedTo = botData['assigned_to'] as String?;
            if (assignedTo != userId) continue;
          }
          
          // Get trash collection data
          if (botData.containsKey('trash_collection') && botData['trash_collection'] is Map) {
            final trashData = Map<String, dynamic>.from(botData['trash_collection'] as Map);
            
            for (var trashEntry in trashData.entries) {
              final item = Map<String, dynamic>.from(trashEntry.value as Map);
              
              final type = (item['type'] as String?)?.toLowerCase() ?? 'other';
              final lat = (item['latitude'] ?? item['lat']) as num?;
              final lng = (item['longitude'] ?? item['lng']) as num?;
              final timestamp = item['timestamp'] as int?;
              final confidence = (item['confidence_level'] ?? item['confidence']) as num?;
              final weight = (item['weight'] ?? item['weight_kg']) as num?;
              final imageUrl = item['image_url'] as String?;
              
              if (lat != null && lng != null) {
                final detectionTime = timestamp != null 
                    ? DateTime.fromMillisecondsSinceEpoch(timestamp)
                    : DateTime.now();
                
                allEvents.add(WasteDetectionEvent(
                  id: trashEntry.key,
                  botId: botId,
                  botName: botName,
                  type: type,
                  latitude: lat.toDouble(),
                  longitude: lng.toDouble(),
                  timestamp: detectionTime,
                  confidence: confidence?.toDouble(),
                  weight: weight?.toDouble(),
                  imageUrl: imageUrl,
                ));
              }
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _events = allEvents;
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _applyFilters() {
    List<WasteDetectionEvent> filtered = List.from(_events);

    // Filter by type
    if (_selectedType != null) {
      filtered = filtered.where((event) => event.type == _selectedType).toList();
    }

    // Filter by date range
    if (_startDate != null) {
      filtered = filtered.where((event) => event.timestamp.isAfter(_startDate!)).toList();
    }
    if (_endDate != null) {
      filtered = filtered.where((event) => event.timestamp.isBefore(_endDate!.add(const Duration(days: 1)))).toList();
    }

    // Sort
    switch (_sortBy) {
      case 'recent':
        filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        break;
      case 'type':
        filtered.sort((a, b) => a.type.compareTo(b.type));
        break;
      case 'location':
        filtered.sort((a, b) => a.botName.compareTo(b.botName));
        break;
      case 'confidence':
        filtered.sort((a, b) => (b.confidence ?? 0).compareTo(a.confidence ?? 0));
        break;
    }

    setState(() {
      _filteredEvents = filtered;
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedType = null;
      _selectedLocation = null;
      _startDate = null;
      _endDate = null;
      _sortBy = 'recent';
      _applyFilters();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GlobalAppBar(
        title: 'Detection Events',
        showDrawer: false,
      ),
      body: _isLoading
          ? const LoadingIndicator(message: 'Loading detection events...')
          : Column(
              children: [
                _buildFilterSection(),
                _buildStatsBar(),
                Expanded(
                  child: _filteredEvents.isEmpty
                      ? const EmptyState(
                          icon: Icons.search_off,
                          title: 'No Detection Events',
                          message: 'No waste detections found matching your filters.',
                        )
                      : _buildEventsList(),
                ),
              ],
            ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
              const Icon(Icons.filter_list, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Filters & Sorting',
                style: AppTextStyles.titleSmall.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (_selectedType != null || _startDate != null || _endDate != null)
                TextButton(
                  onPressed: _clearFilters,
                  child: const Text('Clear All'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Type filter
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFilterChip('All Types', _selectedType == null, () {
                setState(() => _selectedType = null);
                _applyFilters();
              }),
              ..._trashColors.keys.map((type) => _buildFilterChip(
                    type.toUpperCase(),
                    _selectedType == type,
                    () {
                      setState(() => _selectedType = type);
                      _applyFilters();
                    },
                    color: _trashColors[type],
                  )),
            ],
          ),
          const SizedBox(height: 12),
          // Sort dropdown
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _sortBy,
                      isDense: true,
                      items: const [
                        DropdownMenuItem(value: 'recent', child: Text('Most Recent')),
                        DropdownMenuItem(value: 'type', child: Text('By Type')),
                        DropdownMenuItem(value: 'location', child: Text('By Location')),
                        DropdownMenuItem(value: 'confidence', child: Text('By Confidence')),
                      ],
                      onChanged: (value) {
                        setState(() => _sortBy = value!);
                        _applyFilters();
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _loadDetectionEvents,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap, {Color? color}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? (color ?? AppColors.primary) : Colors.transparent,
            border: Border.all(
              color: isSelected ? (color ?? AppColors.primary) : AppColors.border,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: isSelected ? Colors.white : AppColors.textSecondary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsBar() {
    final totalWeight = _filteredEvents.fold<double>(
      0,
      (sum, event) => sum + (event.weight ?? 0),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        border: const Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            icon: Icons.category,
            label: 'Events',
            value: '${_filteredEvents.length}',
          ),
          Container(width: 1, height: 30, color: AppColors.border),
          _buildStatItem(
            icon: Icons.scale,
            label: 'Total Weight',
            value: '${totalWeight.toStringAsFixed(1)} kg',
          ),
          Container(width: 1, height: 30, color: AppColors.border),
          _buildStatItem(
            icon: Icons.schedule,
            label: 'Period',
            value: _startDate != null && _endDate != null
                ? '${_startDate!.day}/${_startDate!.month} - ${_endDate!.day}/${_endDate!.month}'
                : 'All time',
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textMuted,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildEventsList() {
    return RefreshIndicator(
      onRefresh: _loadDetectionEvents,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredEvents.length,
        itemBuilder: (context, index) {
          final event = _filteredEvents[index];
          return _buildEventCard(event);
        },
      ),
    );
  }

  Widget _buildEventCard(WasteDetectionEvent event) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _showEventDetails(event),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Type indicator
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: _trashColors[event.type]?.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.delete_outline,
                  color: _trashColors[event.type],
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              // Event details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _trashColors[event.type],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            event.type.toUpperCase(),
                            style: AppTextStyles.bodySmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (event.confidence != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: event.confidence! >= 0.8
                                  ? Colors.green.withOpacity(0.2)
                                  : Colors.orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.verified,
                                  size: 10,
                                  color: event.confidence! >= 0.8 ? Colors.green : Colors.orange,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '${(event.confidence! * 100).toStringAsFixed(0)}%',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: event.confidence! >= 0.8 ? Colors.green : Colors.orange,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.directions_boat, size: 12, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          event.botName,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 12, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          '${event.latitude.toStringAsFixed(4)}, ${event.longitude.toStringAsFixed(4)}',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textMuted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Timestamp and weight
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatTimestamp(event.timestamp),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 10,
                    ),
                  ),
                  if (event.weight != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${event.weight!.toStringAsFixed(2)} kg',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEventDetails(WasteDetectionEvent event) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _trashColors[event.type]?.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.delete_outline,
                      color: _trashColors[event.type],
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Detection Event',
                          style: AppTextStyles.titleMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          event.type.toUpperCase(),
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: _trashColors[event.type],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            
            const Divider(height: 24),
            
            // Details
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('Bot', event.botName, Icons.directions_boat),
                    _buildDetailRow('Location', '${event.latitude.toStringAsFixed(6)}, ${event.longitude.toStringAsFixed(6)}', Icons.location_on),
                    _buildDetailRow('Detected', DateFormatter.formatDateTime(event.timestamp), Icons.schedule),
                    if (event.confidence != null)
                      _buildDetailRow('Confidence', '${(event.confidence! * 100).toStringAsFixed(1)}%', Icons.verified),
                    if (event.weight != null)
                      _buildDetailRow('Weight', '${event.weight!.toStringAsFixed(2)} kg', Icons.scale),
                    
                    // Image placeholder
                    if (event.imageUrl != null) ...[
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          event.imageUrl!,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            height: 200,
                            color: AppColors.surface,
                            child: const Center(
                              child: Icon(Icons.broken_image, size: 48, color: AppColors.textMuted),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}

// Detection Event Model
class WasteDetectionEvent {
  final String id;
  final String botId;
  final String botName;
  final String type;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double? confidence;
  final double? weight;
  final String? imageUrl;

  WasteDetectionEvent({
    required this.id,
    required this.botId,
    required this.botName,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.confidence,
    this.weight,
    this.imageUrl,
  });
}

