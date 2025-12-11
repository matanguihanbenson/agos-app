import 'package:flutter/material.dart' hide DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/color_palette.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/providers/auth_provider.dart';
import '../providers/monitoring_provider.dart';
import '../models/monitoring_filters.dart';
import '../models/water_quality_data.dart';
import '../models/trash_collection_data.dart';

class MonitoringPage extends ConsumerStatefulWidget {
  const MonitoringPage({super.key});

  @override
  ConsumerState<MonitoringPage> createState() => _MonitoringPageState();
}

class _MonitoringPageState extends ConsumerState<MonitoringPage> with SingleTickerProviderStateMixin {
  int _waterQualityPageIndex = 0;
  final PageController _waterQualityController = PageController();
  String? _selectedRiverTab; // For when All Rivers is selected
  TabController? _scopeTabController;

  @override
  void initState() {
    super.initState();
    final auth = ref.read(authProvider);
    final isAdmin = auth.userProfile?.isAdmin ?? false;
    // Only create tab controller for field operators (non-admins)
    if (!isAdmin) {
      _scopeTabController = TabController(length: 2, vsync: this);
      _scopeTabController!.addListener(() {
        if (!_scopeTabController!.indexIsChanging) {
          final newScope = _scopeTabController!.index == 0 
              ? MonitoringScope.individual 
              : MonitoringScope.organization;
          ref.read(monitoringProvider.notifier).setScope(newScope);
        }
      });
    }
  }

  @override
  void dispose() {
    _waterQualityController.dispose();
    _scopeTabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final monitoringState = ref.watch(monitoringProvider);
    final auth = ref.watch(authProvider);
    final isAdmin = auth.userProfile?.isAdmin ?? false;
    
    return Container(
      color: AppColors.background,
      child: CustomScrollView(
        slivers: [
          // Header with Filters
          SliverToBoxAdapter(
            child: _buildHeader(context, ref, monitoringState, isAdmin),
          ),
          
          // Scope Tabs for Field Operators (Individual vs Organization-wide)
          if (!isAdmin && _scopeTabController != null)
            SliverToBoxAdapter(
              child: _buildScopeTabs(),
            ),
          
          // Loading state
          if (monitoringState.isLoading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (monitoringState.error != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.error_outline, size: 48, color: AppColors.error),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading data',
                        style: AppTextStyles.titleMedium.copyWith(color: AppColors.error),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        monitoringState.error!,
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else ...[
          // River Selection Tabs (when All Rivers selected)
          if (monitoringState.filters.selectedRiverId == null && monitoringState.availableRivers.isNotEmpty)
            SliverToBoxAdapter(
              child: _buildRiverTabs(monitoringState),
            ),
            
          // Key Metrics Summary
          SliverToBoxAdapter(
            child: _buildKeyMetrics(monitoringState),
          ),
            
            // Water Quality Report (Swipeable)
            SliverToBoxAdapter(
              child: _buildWaterQualityReport(monitoringState),
            ),
            
            // Trash Collection Overview
            SliverToBoxAdapter(
              child: _buildTrashCollectionOverview(monitoringState),
            ),
            
            // Trash Composition
            SliverToBoxAdapter(
              child: _buildTrashComposition(monitoringState),
            ),
            
            // Bot Performance Comparison
            SliverToBoxAdapter(
              child: _buildBotPerformance(monitoringState),
            ),
          ],
          
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],
      ),
    );
  }

  Widget _buildScopeTabs() {
    return Container(
      color: AppColors.surface,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: TabBar(
        controller: _scopeTabController,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.primary,
        indicatorWeight: 3,
        tabs: const [
          Tab(
            text: 'Individual',
            icon: Icon(Icons.person, size: 20),
          ),
          Tab(
            text: 'Organization',
            icon: Icon(Icons.business, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, MonitoringState state, bool isAdmin) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.15), width: 1),
                ),
                child: Icon(Icons.analytics_outlined, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Monitoring & Analytics', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w600, fontSize: 16)),
                  Text('Track water quality and collection data', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildFilters(context, ref, state),
        ],
      ),
    );
  }

  Widget _buildFilters(BuildContext context, WidgetRef ref, MonitoringState state) {
    return Column(
      children: [
        // Time Period Chips
        SizedBox(
          height: 32,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: TimePeriod.values.map((period) {
              final isSelected = state.filters.timePeriod == period;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(period.displayName),
                  selected: isSelected,
                  onSelected: (_) async {
                    if (period == TimePeriod.custom) {
                      // Show date picker for custom range
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: ColorScheme.light(primary: AppColors.primary),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        final customRange = DateTimeRange(
                          start: picked.start,
                          end: picked.end,
                        );
                        ref.read(monitoringProvider.notifier).updateFilters(
                          state.filters.copyWith(
                            timePeriod: period,
                            customDateRange: customRange,
                          ),
                        );
                      }
                    } else {
                      ref.read(monitoringProvider.notifier).setTimePeriod(period);
                    }
                  },
                  backgroundColor: Colors.white,
                  selectedColor: AppColors.primary.withValues(alpha: 0.12),
                  checkmarkColor: AppColors.primary,
                  labelStyle: AppTextStyles.bodySmall.copyWith(
                    color: isSelected ? AppColors.primary : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    fontSize: 11,
                  ),
                  side: BorderSide(color: isSelected ? AppColors.primary : AppColors.border, width: 1),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  visualDensity: VisualDensity.compact,
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        // River and Bot Filters
        Row(
          children: [
            Expanded(
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: state.filters.selectedRiverId,
                    hint: Text('All Rivers', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted, fontSize: 11)),
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down, size: 18),
                    style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
                    items: [
                      DropdownMenuItem<String?>(value: null, child: Text('All Rivers', style: AppTextStyles.bodySmall.copyWith(fontSize: 11))),
                      ...state.availableRivers.map((river) => DropdownMenuItem<String?>(value: river, child: Text(river, style: AppTextStyles.bodySmall.copyWith(fontSize: 11)))),
                    ],
                    onChanged: (value) => ref.read(monitoringProvider.notifier).setRiverFilter(value),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: state.filters.selectedBotId,
                    hint: Text('All Bots', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted, fontSize: 11)),
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down, size: 18),
                    style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
                    items: [
                      DropdownMenuItem<String?>(value: null, child: Text('All Bots', style: AppTextStyles.bodySmall.copyWith(fontSize: 11))),
                      ...state.availableBots.map((bot) => DropdownMenuItem<String?>(value: bot, child: Text(bot, style: AppTextStyles.bodySmall.copyWith(fontSize: 11)))),
                    ],
                    onChanged: (value) => ref.read(monitoringProvider.notifier).setBotFilter(value),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRiverTabs(MonitoringState state) {
    // Initialize selected tab
    _selectedRiverTab ??= state.availableRivers.isNotEmpty ? state.availableRivers.first : null;
    
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.water, color: AppColors.info, size: 16),
              const SizedBox(width: 8),
              Text(
                'Select River',
                style: AppTextStyles.titleSmall.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: state.availableRivers.map((river) {
              final isSelected = river == _selectedRiverTab;
              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedRiverTab = river;
                  });
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : const Color(0xFFE0E0E0),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    river,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Text(
            'View data specific to each river. Rivers have different water quality parameters.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyMetrics(MonitoringState state) {
    // Filter data by selected river tab if All Rivers is selected
    var waterData = state.filteredWaterQuality;
    var trashData = state.filteredTrashCollection;
    
    if (state.filters.selectedRiverId == null && _selectedRiverTab != null) {
      waterData = waterData.where((d) => d.riverId == _selectedRiverTab).toList();
      trashData = trashData.where((d) => d.riverId == _selectedRiverTab).toList();
    }
    
    if (waterData.isEmpty && trashData.isEmpty) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.info_outline, color: AppColors.textMuted, size: 32),
              const SizedBox(height: 8),
              Text('No data available', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
              Text('Try adjusting your filters', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted, fontSize: 11)),
            ],
          ),
        ),
      );
    }
    
    final totalTrash = trashData.fold<double>(0, (sum, data) => sum + data.totalWeight);
    final avgTurbidity = waterData.isEmpty ? 0.0 : waterData.fold<double>(0, (sum, data) => sum + data.turbidity) / waterData.length;
    final avgPhLevel = waterData.isEmpty ? 0.0 : waterData.fold<double>(0, (sum, data) => sum + data.phLevel) / waterData.length;
    final avgDO = waterData.isEmpty ? 0.0 : waterData.fold<double>(0, (sum, data) => sum + data.dissolvedOxygen) / waterData.length;
    
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: Row(
        children: [
          Expanded(child: _buildMetricCard('Trash Removed', '${totalTrash.toStringAsFixed(1)}kg', Icons.delete_outline, AppColors.success)),
          const SizedBox(width: 7),
          Expanded(child: _buildMetricCard('Avg Turbidity', avgTurbidity.toStringAsFixed(1), Icons.water_drop_outlined, _getTurbidityColor(avgTurbidity))),
          const SizedBox(width: 7),
          Expanded(child: _buildMetricCard('Avg pH', avgPhLevel.toStringAsFixed(1), Icons.science_outlined, _getPhColor(avgPhLevel))),
          const SizedBox(width: 7),
          Expanded(child: _buildMetricCard('Avg DO', avgDO.toStringAsFixed(1), Icons.air, _getDOColor(avgDO))),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 2, offset: const Offset(0, 1))],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(value, style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
          Text(title, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 9), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildWaterQualityReport(MonitoringState state) {
    final waterData = state.filteredWaterQuality;
    if (waterData.isEmpty) return const SizedBox.shrink();

    // Calculate overall water quality score (0-100)
    final avgTurbidity = waterData.fold<double>(0, (sum, d) => sum + d.turbidity) / waterData.length;
    final avgPh = waterData.fold<double>(0, (sum, d) => sum + d.phLevel) / waterData.length;
    final avgDO = waterData.fold<double>(0, (sum, d) => sum + d.dissolvedOxygen) / waterData.length;
    
    double turbidityScore = avgTurbidity < 5 ? 100 : avgTurbidity < 25 ? 75 : avgTurbidity < 50 ? 50 : 25;
    double phScore = (avgPh >= 6.5 && avgPh <= 8.5) ? 100 : (avgPh >= 6.0 && avgPh <= 9.0) ? 70 : 40;
    double doScore = avgDO >= 6 ? 100 : avgDO >= 4 ? 70 : 40;
    
    final overallScore = (turbidityScore + phScore + doScore) / 3;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 2, offset: const Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.waves, color: AppColors.primary, size: 16),
                const SizedBox(width: 8),
                Text('Water Quality Report', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w600, fontSize: 14)),
              ],
            ),
          ),
          SizedBox(
            height: 200,
            child: PageView(
              controller: _waterQualityController,
              onPageChanged: (index) => setState(() => _waterQualityPageIndex = index),
              children: [
                _buildPhLevelChart(waterData, state.filters.timePeriod),
                _buildTurbidityChart(waterData, state.filters.timePeriod),
                _buildDissolvedOxygenChart(waterData, state.filters.timePeriod),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              children: [
                // Page Indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: _waterQualityPageIndex == index ? 20 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _waterQualityPageIndex == index ? AppColors.primary : AppColors.border,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  )),
                ),
                const SizedBox(height: 12),
                // Overall Quality Progress
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Overall Water Quality', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600, fontSize: 11)),
                        Text('${overallScore.toStringAsFixed(0)}%', style: AppTextStyles.bodySmall.copyWith(color: _getQualityColor(overallScore), fontWeight: FontWeight.bold, fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: overallScore / 100,
                        backgroundColor: AppColors.border.withValues(alpha: 0.3),
                        valueColor: AlwaysStoppedAnimation<Color>(_getQualityColor(overallScore)),
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhLevelChart(List<WaterQualityData> data, TimePeriod period) {
    return _buildLineChart(
      data.map((d) => d.phLevel).toList(),
      'pH Level',
      AppColors.info,
      minY: 0,
      maxY: 14,
      period: period,
    );
  }

  Widget _buildTurbidityChart(List<WaterQualityData> data, TimePeriod period) {
    return _buildLineChart(
      data.map((d) => d.turbidity).toList(),
      'Turbidity (NTU)',
      AppColors.warning,
      minY: 0,
      maxY: 60,
      period: period,
    );
  }

  Widget _buildDissolvedOxygenChart(List<WaterQualityData> data, TimePeriod period) {
    return _buildLineChart(
      data.map((d) => d.dissolvedOxygen).toList(),
      'Dissolved Oxygen (mg/L)',
      AppColors.success,
      minY: 0,
      maxY: 10,
      period: period,
    );
  }

  Widget _buildLineChart(List<double> values, String title, Color color, {double minY = 0, double maxY = 100, required TimePeriod period}) {
    // Get all time labels for the selected period
    final allLabels = period.getTimeLabels();
    final totalSlots = period.getTimeSlotCount();
    
    if (totalSlots == 0 || allLabels.isEmpty) return const SizedBox.shrink();
    
    // Create data map with all slots initialized to 0 (not null)
    final Map<int, double> dataMap = {};
    for (int i = 0; i < totalSlots; i++) {
      dataMap[i] = 0.0; // Default to 0 instead of null
    }
    
    // Fill in actual data values (assuming values are in chronological order)
    if (values.isNotEmpty) {
      final sortedValues = List<double>.from(values.reversed);
      for (int i = 0; i < sortedValues.length && i < totalSlots; i++) {
        dataMap[i] = sortedValues[i];
      }
    }
    
    // Create spots for all values (including zeros)
    final spots = dataMap.entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();
    
    if (spots.isEmpty) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600, fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: (maxY - minY) / 4, getDrawingHorizontalLine: (_) => FlLine(color: AppColors.border.withValues(alpha: 0.3), strokeWidth: 0.5)),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    interval: totalSlots > 8 ? (totalSlots / 6).ceilToDouble() : 1,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= allLabels.length) return const Text('');
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(allLabels[index], style: AppTextStyles.bodySmall.copyWith(fontSize: 9)),
                      );
                    },
                  )),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32, getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: AppTextStyles.bodySmall.copyWith(fontSize: 9)))),
                ),
                borderData: FlBorderData(show: true, border: Border(bottom: BorderSide(color: AppColors.border), left: BorderSide(color: AppColors.border))),
                minX: 0,
                maxX: (totalSlots - 1).toDouble(),
                minY: minY,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    preventCurveOverShooting: true,
                    color: color,
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: spots.length < 20),
                    belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.08)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }


  Color _getTurbidityColor(double turbidity) {
    if (turbidity < 5) return AppColors.success;
    if (turbidity < 25) return const Color(0xFF4CAF50);
    if (turbidity < 50) return AppColors.warning;
    return AppColors.error;
  }

  Color _getPhColor(double ph) {
    if (ph >= 6.5 && ph <= 8.5) return AppColors.success;
    if (ph >= 6.0 && ph <= 9.0) return AppColors.warning;
    return AppColors.error;
  }

  Color _getDOColor(double dO) {
    if (dO >= 6) return AppColors.success;
    if (dO >= 4) return AppColors.warning;
    return AppColors.error;
  }

  Color _getQualityColor(double score) {
    if (score >= 80) return AppColors.success;
    if (score >= 60) return const Color(0xFF8BC34A);
    if (score >= 40) return AppColors.warning;
    return AppColors.error;
  }

  Widget _buildTrashCollectionOverview(MonitoringState state) {
    final trashData = state.filteredTrashCollection;
    if (trashData.isEmpty) return const SizedBox.shrink();

    final sortedData = List<TrashCollectionData>.from(trashData)..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final weights = sortedData.map((e) => e.totalWeight).toList();
    final period = state.filters.timePeriod;
    final allLabels = period.getTimeLabels();
    final totalSlots = period.getTimeSlotCount();
    
    // Calculate min and max for Y-axis with nice intervals
    final minWeight = weights.reduce((a, b) => a < b ? a : b);
    final maxWeight = weights.reduce((a, b) => a > b ? a : b);
    
    // Calculate dynamic headroom to prevent curve clipping
    final headroom = (maxWeight * 0.12).clamp(2.0, 30.0);
    // Round to nice intervals (multiples of 5) with extra padding for curve overshoot
    final yAxisMin = ((minWeight / 5).floor() * 5.0).clamp(0.0, double.infinity).toDouble();
    final yAxisMax = (((maxWeight + headroom) / 5).ceil()) * 5.0;
    final yAxisInterval = 5.0;

    // Create line chart spots based on time period
    List<FlSpot> spots;
    if (totalSlots > 0 && allLabels.isNotEmpty) {
      // Map data to time slots
      final Map<int, double> dataMap = {};
      for (int i = 0; i < totalSlots; i++) {
        dataMap[i] = 0.0;
      }
      
      // Fill in actual data (distribute based on timestamps)
      for (final data in sortedData) {
        final slotIndex = _getTimeSlotIndex(data.timestamp, period);
        if (slotIndex >= 0 && slotIndex < totalSlots) {
          dataMap[slotIndex] = (dataMap[slotIndex] ?? 0) + data.totalWeight;
        }
      }
      
      spots = dataMap.entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList();
    } else {
      // Fallback to using data indices
      spots = sortedData.asMap().entries.map((entry) {
        return FlSpot(entry.key.toDouble(), entry.value.totalWeight);
      }).toList();
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 2, offset: const Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.delete_sweep, color: AppColors.success, size: 16),
              const SizedBox(width: 8),
              Text('Trash Collection Trends', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w600, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 160,
              child: Padding(
                padding: const EdgeInsets.only(right: 12, top: 8, bottom: 4, left: 4),
                child: LineChart(
                  LineChartData(
                clipData: FlClipData.all(),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: yAxisInterval,
                  getDrawingHorizontalLine: (_) => FlLine(color: AppColors.border.withValues(alpha: 0.3), strokeWidth: 0.5),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: totalSlots > 0 ? (totalSlots > 8 ? (totalSlots / 6).ceilToDouble() : 1) : 1,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (totalSlots > 0 && allLabels.isNotEmpty) {
                          if (index < 0 || index >= allLabels.length) return const Text('');
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              allLabels[index],
                              style: AppTextStyles.bodySmall.copyWith(fontSize: 8),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        } else {
                          if (index < 0 || index >= sortedData.length) return const Text('');
                          final data = sortedData[index];
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              '${data.timestamp.month}/${data.timestamp.day}',
                              style: AppTextStyles.bodySmall.copyWith(fontSize: 8),
                              maxLines: 1,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: yAxisInterval,
                      getTitlesWidget: (value, meta) => Text('${value.toInt()}kg', style: AppTextStyles.bodySmall.copyWith(fontSize: 9)),
                    ),
                  ),
                ),
                borderData: FlBorderData(show: true, border: Border(bottom: BorderSide(color: AppColors.border), left: BorderSide(color: AppColors.border))),
                minX: 0,
                maxX: totalSlots > 0 ? (totalSlots - 1).toDouble() : (sortedData.length - 1).toDouble(),
                minY: yAxisMin,
                maxY: yAxisMax,
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => AppColors.textPrimary,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        return LineTooltipItem(
                          '${spot.y.toStringAsFixed(1)}kg',
                          AppTextStyles.bodySmall.copyWith(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 10),
                        );
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.15,
                    preventCurveOverShooting: true,
                    color: AppColors.success,
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: spots.length < 20,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 3.5,
                          color: AppColors.success,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(show: true, color: AppColors.success.withValues(alpha: 0.08)),
                  ),
                ],
              ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrashComposition(MonitoringState state) {
    final trashData = state.filteredTrashCollection;
    if (trashData.isEmpty) return const SizedBox.shrink();

    final Map<String, double> totalComposition = {};
    for (final data in trashData) {
      data.trashComposition.forEach((type, weight) {
        totalComposition[type] = (totalComposition[type] ?? 0) + weight;
      });
    }

    final totalWeight = totalComposition.values.fold<double>(0, (a, b) => a + b);
    final sections = totalComposition.entries.map((entry) {
      final percentage = (entry.value / totalWeight) * 100;
      return {'type': entry.key, 'weight': entry.value, 'percentage': percentage, 'color': _getTrashTypeColor(entry.key)};
    }).toList()..sort((a, b) => (b['percentage'] as double).compareTo(a['percentage'] as double));

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 2, offset: const Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pie_chart_outline, color: AppColors.warning, size: 16),
              const SizedBox(width: 8),
              Text('Waste Composition', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w600, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 32,
                    sections: sections.map((data) {
                      return PieChartSectionData(
                        value: data['weight'] as double,
                        title: '${(data['percentage'] as double).toStringAsFixed(0)}%',
                        color: data['color'] as Color,
                        radius: 44,
                        titleStyle: AppTextStyles.bodySmall.copyWith(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 10),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: sections.map((data) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: data['color'] as Color,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              data['type'] as String,
                              style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
                            ),
                          ),
                          Text(
                            '${(data['weight'] as double).toStringAsFixed(1)}kg',
                            style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600, fontSize: 11),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBotPerformance(MonitoringState state) {
    final trashData = state.filteredTrashCollection;
    if (trashData.isEmpty) return const SizedBox.shrink();

    // Group by bot
    final Map<String, double> botTotals = {};
    for (final data in trashData) {
      botTotals[data.botId] = (botTotals[data.botId] ?? 0) + data.totalWeight;
    }

    final sortedBots = botTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 2, offset: const Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.leaderboard, color: AppColors.info, size: 16),
              const SizedBox(width: 8),
              Text('Bot Performance', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w600, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 14),
          ...sortedBots.map((entry) {
            final percentage = (entry.value / botTotals.values.reduce((a, b) => a + b)) * 100;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(entry.key, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600, fontSize: 11)),
                      Text('${entry.value.toStringAsFixed(1)}kg', style: AppTextStyles.bodySmall.copyWith(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percentage / 100,
                      backgroundColor: AppColors.border.withValues(alpha: 0.3),
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.success),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }


  // Helper function to map timestamp to time slot index
  int _getTimeSlotIndex(DateTime timestamp, TimePeriod period) {
    switch (period) {
      case TimePeriod.today:
        return timestamp.hour; // 0-23
      case TimePeriod.week:
        return timestamp.weekday - 1; // 0-6 (Monday=0)
      case TimePeriod.month:
        // Map to week number (0-3)
        final dayOfMonth = timestamp.day;
        return ((dayOfMonth - 1) / 7).floor().clamp(0, 3);
      case TimePeriod.year:
        return timestamp.month - 1; // 0-11
      case TimePeriod.custom:
        return -1;
    }
  }

  Color _getTrashTypeColor(String type) {
    switch (type) {
      case TrashTypes.plastic: return const Color(0xFFE91E63);
      case TrashTypes.paper: return const Color(0xFF8D6E63);
      case TrashTypes.cardboard: return const Color(0xFFBCAAA4);
      case TrashTypes.biodegradable: return const Color(0xFF4CAF50);
      case TrashTypes.metal: return const Color(0xFF9E9E9E);
      case TrashTypes.glass: return const Color(0xFF00BCD4);
      default: return const Color(0xFFFF9800);
    }
  }
}
