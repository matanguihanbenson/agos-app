import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Query;
import 'package:cloud_firestore/cloud_firestore.dart' as firestore show Query;
import 'dart:async';
import '../../../core/widgets/app_bar.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/theme/color_palette.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/providers/auth_provider.dart';

class WasteAnalyticsPage extends ConsumerStatefulWidget {
  const WasteAnalyticsPage({super.key});

  @override
  ConsumerState<WasteAnalyticsPage> createState() =>
      _WasteAnalyticsPageState();
}

class _WasteAnalyticsPageState extends ConsumerState<WasteAnalyticsPage> {
  bool _isLoading = true;
  String _timeRange = '30d'; // 7d, 30d, 90d, all
  String? _selectedRiver;
  
  // Analytics data
  Map<String, double> _wasteByType = {};
  Map<String, double> _wasteByRiver = {};
  List<TrendData> _trendData = [];
  double _totalWeight = 0.0;
  int _totalItems = 0;
  String? _mostCommonType;
  String? _mostPollutedRiver;

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
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);

    try {
      final auth = ref.read(authProvider);
      final userId = auth.currentUser?.uid;
      final isAdmin = auth.userProfile?.isAdmin ?? false;

      if (userId == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Calculate time range
      DateTime? startDate;
      final now = DateTime.now();
      switch (_timeRange) {
        case '7d':
          startDate = now.subtract(const Duration(days: 7));
          break;
        case '30d':
          startDate = now.subtract(const Duration(days: 30));
          break;
        case '90d':
          startDate = now.subtract(const Duration(days: 90));
          break;
        case 'all':
        default:
          startDate = null;
      }

      // Aggregate from completed deployments (Firestore)
      final firestoreInstance = FirebaseFirestore.instance;
      firestore.Query query = firestoreInstance
          .collection('deployments')
          .where('status', isEqualTo: 'completed')
          .where('owner_admin_id', isEqualTo: userId);

      if (startDate != null) {
        query = query.where('completed_at',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (_selectedRiver != null) {
        query = query.where('river_id', isEqualTo: _selectedRiver);
      }

      final deploymentsSnapshot = await query.get();

      Map<String, double> wasteByType = {};
      Map<String, double> wasteByRiver = {};
      Map<DateTime, double> dailyWaste = {};
      double totalWeight = 0.0;
      int totalItems = 0;

      for (var doc in deploymentsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final trashSummary = data['trash_collection_summary'];
        final riverId = data['river_id'] as String?;
        final riverName = data['river_name'] as String? ?? riverId ?? 'Unknown';
        final completedAt = (data['completed_at'] as Timestamp?)?.toDate();

        if (trashSummary != null) {
          final weight = (trashSummary['total_weight'] as num?)?.toDouble() ?? 0.0;
          final items = (trashSummary['total_items'] as int?) ?? 0;
          totalWeight += weight;
          totalItems += items;

          // By type
          final trashByType = trashSummary['trash_by_type'] as Map?;
          if (trashByType != null) {
            trashByType.forEach((type, countValue) {
              final typeStr = type.toString().toLowerCase();
              wasteByType[typeStr] = (wasteByType[typeStr] ?? 0.0) + (countValue as num).toDouble();
            });
          }

          // By river
          wasteByRiver[riverName] = (wasteByRiver[riverName] ?? 0.0) + weight;

          // Daily trend
          if (completedAt != null) {
            final dayKey = DateTime(completedAt.year, completedAt.month, completedAt.day);
            dailyWaste[dayKey] = (dailyWaste[dayKey] ?? 0.0) + weight;
          }
        }
      }

      // Also aggregate from real-time data for active deployments
      final db = FirebaseDatabase.instance.ref();
      final botsSnapshot = await db.child('bots').get();

      if (botsSnapshot.exists && botsSnapshot.value is Map) {
        final botsData = Map<String, dynamic>.from(botsSnapshot.value as Map);

        for (var botEntry in botsData.entries) {
          final botData = Map<String, dynamic>.from(botEntry.value as Map);

          // Role-based filtering
          if (!isAdmin) {
            final assignedTo = botData['assigned_to'] as String?;
            if (assignedTo != userId) continue;
          }

          final riverId = botData['river_id'] as String?;
          final riverName = botData['river_name'] as String? ?? riverId ?? 'Unknown';

          // Filter by selected river
          if (_selectedRiver != null && riverId != _selectedRiver) continue;

          // Check for trash_collection array
          if (botData.containsKey('trash_collection') && botData['trash_collection'] is Map) {
            final trashData = Map<String, dynamic>.from(botData['trash_collection'] as Map);

            for (var trashEntry in trashData.values) {
              final item = Map<String, dynamic>.from(trashEntry as Map);
              final type = (item['type'] as String?)?.toLowerCase() ?? 'other';
              final weight = (item['weight'] ?? item['weight_kg']) as num?;
              final timestamp = item['timestamp'] as int?;

              // Apply time filter
              if (startDate != null && timestamp != null) {
                final itemDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
                if (itemDate.isBefore(startDate)) continue;
              }

              if (weight != null) {
                final weightDouble = weight.toDouble();
                totalWeight += weightDouble;
                totalItems++;
                wasteByType[type] = (wasteByType[type] ?? 0.0) + 1;
                wasteByRiver[riverName] = (wasteByRiver[riverName] ?? 0.0) + weightDouble;

                // Daily trend
                if (timestamp != null) {
                  final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
                  final dayKey = DateTime(date.year, date.month, date.day);
                  dailyWaste[dayKey] = (dailyWaste[dayKey] ?? 0.0) + weightDouble;
                }
              }
            }
          }
        }
      }

      // Calculate most common type
      String? mostCommonType;
      double maxTypeCount = 0;
      wasteByType.forEach((type, typeCount) {
        if (typeCount > maxTypeCount) {
          maxTypeCount = typeCount;
          mostCommonType = type;
        }
      });

      // Calculate most polluted river
      String? mostPollutedRiver;
      double maxRiverWeight = 0;
      wasteByRiver.forEach((river, weight) {
        if (weight > maxRiverWeight) {
          maxRiverWeight = weight;
          mostPollutedRiver = river;
        }
      });

      // Build trend data (sorted by date)
      final sortedDates = dailyWaste.keys.toList()..sort();
      List<TrendData> trendData = sortedDates
          .map((date) => TrendData(date: date, weight: dailyWaste[date]!))
          .toList();

      if (mounted) {
        setState(() {
          _wasteByType = wasteByType;
          _wasteByRiver = wasteByRiver;
          _trendData = trendData;
          _totalWeight = totalWeight;
          _totalItems = totalItems;
          _mostCommonType = mostCommonType;
          _mostPollutedRiver = mostPollutedRiver;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading analytics: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const GlobalAppBar(
        title: 'Waste Analytics',
        showDrawer: false,
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: _isLoading
                ? const LoadingIndicator()
                : _totalWeight == 0
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadAnalytics,
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            _buildSummaryCards(),
                            const SizedBox(height: 16),
                            _buildWasteByTypeChart(),
                            const SizedBox(height: 16),
                            _buildWasteByRiverChart(),
                            const SizedBox(height: 16),
                            _buildTrendChart(),
                            const SizedBox(height: 16),
                            _buildInsights(),
                          ],
                        ),
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
      child: Row(
        children: [
          Expanded(
            child: _buildDropdown<String>(
              value: _timeRange,
              items: const ['7d', '30d', '90d', 'all'],
              onChanged: (v) {
                if (v != null) {
                  setState(() => _timeRange = v);
                  _loadAnalytics();
                }
              },
              labelBuilder: (v) {
                switch (v) {
                  case '7d':
                    return 'Last 7 Days';
                  case '30d':
                    return 'Last 30 Days';
                  case '90d':
                    return 'Last 90 Days';
                  case 'all':
                    return 'All Time';
                  default:
                    return v;
                }
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildDropdown<String?>(
              value: _selectedRiver,
              items: [null, ..._wasteByRiver.keys.toList()],
              onChanged: (v) {
                setState(() => _selectedRiver = v);
                _loadAnalytics();
              },
              labelBuilder: (v) => v ?? 'All Rivers',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    required String Function(T) labelBuilder,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          isDense: true,
          items: items
              .map((e) => DropdownMenuItem<T>(
                    value: e,
                    child: Text(
                      labelBuilder(e),
                      style: AppTextStyles.bodySmall,
                    ),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 64,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 16),
          Text(
            'No Waste Data',
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Analytics will appear when waste is collected',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textMuted,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            icon: Icons.scale,
            label: 'Total Weight',
            value: '${_totalWeight.toStringAsFixed(1)} kg',
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            icon: Icons.category,
            label: 'Total Items',
            value: '$_totalItems',
            color: AppColors.success,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: AppTextStyles.headlineSmall.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWasteByTypeChart() {
    if (_wasteByType.isEmpty) return const SizedBox.shrink();

    final sortedEntries = _wasteByType.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final maxValue = sortedEntries.first.value;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Waste Distribution by Type',
            style: AppTextStyles.titleSmall.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...sortedEntries.map((entry) {
            final percentage = (entry.value / maxValue * 100);
            final color = _trashColors[entry.key] ?? Colors.grey;
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          entry.key.toUpperCase(),
                          style: AppTextStyles.labelMedium,
                        ),
                      ),
                      Text(
                        '${entry.value.toStringAsFixed(0)} items',
                        style: AppTextStyles.labelSmall.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Stack(
                    children: [
                      Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: percentage / 100,
                        child: Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildWasteByRiverChart() {
    if (_wasteByRiver.isEmpty) return const SizedBox.shrink();

    final sortedEntries = _wasteByRiver.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final maxValue = sortedEntries.first.value;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Waste Distribution by Location',
            style: AppTextStyles.titleSmall.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...sortedEntries.take(5).map((entry) {
            final percentage = (entry.value / maxValue * 100);
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          entry.key,
                          style: AppTextStyles.labelMedium,
                        ),
                      ),
                      Text(
                        '${entry.value.toStringAsFixed(1)} kg',
                        style: AppTextStyles.labelSmall.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Stack(
                    children: [
                      Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: percentage / 100,
                        child: Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTrendChart() {
    if (_trendData.isEmpty) return const SizedBox.shrink();

    final maxWeight = _trendData.map((d) => d.weight).reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Collection Trend',
            style: AppTextStyles.titleSmall.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _trendData.asMap().entries.map((entry) {
                final index = entry.key;
                final data = entry.value;
                final height = (data.weight / maxWeight * 130).clamp(5.0, 130.0);
                
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          height: height,
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (index % 3 == 0 || index == _trendData.length - 1)
                          Text(
                            '${data.date.day}/${data.date.month}',
                            style: AppTextStyles.labelSmall.copyWith(
                              fontSize: 8,
                              color: AppColors.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsights() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: AppColors.info, size: 20),
              const SizedBox(width: 8),
              Text(
                'Key Insights',
                style: AppTextStyles.titleSmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.info,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_mostCommonType != null)
            _buildInsightRow(
              Icons.category,
              'Most Common Waste',
              _mostCommonType!.toUpperCase(),
            ),
          if (_mostPollutedRiver != null) ...[
            const SizedBox(height: 8),
            _buildInsightRow(
              Icons.location_on,
              'Most Polluted Location',
              _mostPollutedRiver!,
            ),
          ],
          const SizedBox(height: 8),
          _buildInsightRow(
            Icons.show_chart,
            'Average Daily Collection',
            _trendData.isNotEmpty
                ? '${(_totalWeight / _trendData.length).toStringAsFixed(1)} kg'
                : '0.0 kg',
          ),
        ],
      ),
    );
  }

  Widget _buildInsightRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.info),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.info,
          ),
        ),
      ],
    );
  }
}

class TrendData {
  final DateTime date;
  final double weight;

  TrendData({required this.date, required this.weight});
}

