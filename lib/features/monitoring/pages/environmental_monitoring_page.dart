import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../../../core/widgets/app_bar.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/theme/color_palette.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/utils/date_formatter.dart';

class EnvironmentalMonitoringPage extends ConsumerStatefulWidget {
  const EnvironmentalMonitoringPage({super.key});

  @override
  ConsumerState<EnvironmentalMonitoringPage> createState() =>
      _EnvironmentalMonitoringPageState();
}

class _EnvironmentalMonitoringPageState
    extends ConsumerState<EnvironmentalMonitoringPage> {
  List<BotEnvironmentalData> _activeBots = [];
  bool _isLoading = true;
  String? _selectedRiver;
  StreamSubscription<DatabaseEvent>? _realtimeSubscription;
  List<HistoricalReading> _historicalData = [];
  bool _showHistorical = false;
  String? _selectedBotForHistory;

  @override
  void initState() {
    super.initState();
    _loadEnvironmentalData();
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadEnvironmentalData() async {
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

      // Get active bots with environmental sensors
      final botsSnapshot = await db.child('bots').get();

      List<BotEnvironmentalData> activeBots = [];

      if (botsSnapshot.exists && botsSnapshot.value is Map) {
        final botsData = Map<String, dynamic>.from(botsSnapshot.value as Map);

        for (var botEntry in botsData.entries) {
          final botId = botEntry.key;
          final botData = Map<String, dynamic>.from(botEntry.value as Map);

          // Role-based filtering
          if (!isAdmin) {
            final assignedTo = botData['assigned_to'] as String?;
            if (assignedTo != userId) continue;
          }

          // Only show active/deployed bots
          final status = (botData['status'] as String?)?.toLowerCase();
          if (status != 'active' && status != 'deployed') continue;

          // Extract environmental data
          final phLevel = (botData['ph_level'] ?? botData['ph']) as num?;
          final turbidity = (botData['turbidity'] ?? botData['turb']) as num?;
          final temperature =
              (botData['temp'] ?? botData['temperature']) as num?;
          final dissolvedOxygen =
              (botData['dissolved_oxygen'] ?? botData['do']) as num?;
          final riverId = botData['river_id'] as String?;
          final riverName = botData['river_name'] as String?;
          final lastUpdated = botData['last_updated'] as int?;

          // Apply river filter
          if (_selectedRiver != null && riverId != _selectedRiver) continue;

          activeBots.add(BotEnvironmentalData(
            botId: botId,
            botName: botData['name'] as String? ?? botId,
            riverId: riverId,
            riverName: riverName,
            phLevel: phLevel?.toDouble(),
            turbidity: turbidity?.toDouble(),
            temperature: temperature?.toDouble(),
            dissolvedOxygen: dissolvedOxygen?.toDouble(),
            lastUpdated: lastUpdated != null
                ? DateTime.fromMillisecondsSinceEpoch(lastUpdated)
                : null,
            status: status ?? 'unknown',
          ));
        }
      }

      if (mounted) {
        setState(() {
          _activeBots = activeBots;
          _isLoading = false;
        });

        // Start real-time updates
        _startRealtimeMonitoring();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading environmental data: $e')),
        );
      }
    }
  }

  void _startRealtimeMonitoring() {
    _realtimeSubscription?.cancel();

    final db = FirebaseDatabase.instance.ref();
    _realtimeSubscription = db.child('bots').onValue.listen((event) {
      if (!mounted) return;
      _loadEnvironmentalData();
    });
  }

  Future<void> _loadHistoricalData(String botId) async {
    setState(() {
      _showHistorical = true;
      _selectedBotForHistory = botId;
    });

    try {
      final firestore = FirebaseFirestore.instance;

      // Get historical readings from completed deployments
      final deploymentsSnapshot = await firestore
          .collection('deployments')
          .where('bot_id', isEqualTo: botId)
          .where('status', isEqualTo: 'completed')
          .orderBy('completed_at', descending: true)
          .limit(50)
          .get();

      List<HistoricalReading> readings = [];

      for (var doc in deploymentsSnapshot.docs) {
        final data = doc.data();
        final waterQuality = data['water_quality_snapshot'];

        if (waterQuality != null) {
          final completedAt = (data['completed_at'] as Timestamp?)?.toDate() ??
              DateTime.now();

          readings.add(HistoricalReading(
            timestamp: completedAt,
            phLevel: (waterQuality['avg_ph_level'] as num?)?.toDouble(),
            turbidity: (waterQuality['avg_turbidity'] as num?)?.toDouble(),
            temperature:
                (waterQuality['avg_temperature'] as num?)?.toDouble(),
            dissolvedOxygen:
                (waterQuality['avg_dissolved_oxygen'] as num?)?.toDouble(),
            deploymentId: doc.id,
          ));
        }
      }

      if (mounted) {
        setState(() {
          _historicalData = readings;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading historical data: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const GlobalAppBar(
        title: 'Environmental Monitoring',
        showDrawer: false,
      ),
      body: Column(
        children: [
          _buildFilters(),
          if (_showHistorical)
            _buildHistoricalHeader()
          else
            _buildLiveHeader(),
          Expanded(
            child: _isLoading
                ? const LoadingIndicator()
                : _showHistorical
                    ? _buildHistoricalView()
                    : _buildLiveView(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    // Get unique rivers from active bots
    final rivers = _activeBots
        .where((b) => b.riverId != null)
        .map((b) => MapEntry(b.riverId!, b.riverName ?? b.riverId!))
        .toSet()
        .toList();

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
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border.withValues(alpha: 0.3)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: _selectedRiver,
                  hint: Text('All Rivers', style: AppTextStyles.bodySmall),
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All Rivers'),
                    ),
                    ...rivers.map((entry) {
                      return DropdownMenuItem<String?>(
                        value: entry.key,
                        child: Text(entry.value),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedRiver = value);
                    _loadEnvironmentalData();
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _loadEnvironmentalData,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.surface,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Real-Time Monitoring',
            style: AppTextStyles.titleSmall.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Text(
            '${_activeBots.length} Active Bots',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoricalHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.info.withValues(alpha: 0.1),
      child: Row(
        children: [
          Icon(Icons.history, size: 20, color: AppColors.info),
          const SizedBox(width: 8),
          Text(
            'Historical Data - ${_activeBots.firstWhere((b) => b.botId == _selectedBotForHistory, orElse: () => _activeBots.first).botName}',
            style: AppTextStyles.titleSmall.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _showHistorical = false;
                _selectedBotForHistory = null;
                _historicalData.clear();
              });
            },
            icon: const Icon(Icons.close, size: 18),
            label: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveView() {
    if (_activeBots.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.water_drop_outlined,
              size: 64,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              'No Active Monitoring',
              style: AppTextStyles.titleMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Deploy bots to start environmental monitoring',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadEnvironmentalData,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _activeBots.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final bot = _activeBots[index];
          return _buildBotEnvironmentalCard(bot);
        },
      ),
    );
  }

  Widget _buildBotEnvironmentalCard(BotEnvironmentalData bot) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.directions_boat,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bot.botName,
                        style: AppTextStyles.titleSmall.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (bot.riverName != null)
                        Text(
                          bot.riverName!,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _loadHistoricalData(bot.botId),
                  icon: const Icon(Icons.history),
                  tooltip: 'View History',
                  color: AppColors.info,
                ),
              ],
            ),
          ),

          // Sensor Readings
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildSensorCard(
                        icon: Icons.water_drop,
                        label: 'pH Level',
                        value: bot.phLevel?.toStringAsFixed(2) ?? '--',
                        status: _getPhStatus(bot.phLevel),
                        unit: '',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSensorCard(
                        icon: Icons.blur_on,
                        label: 'Turbidity',
                        value: bot.turbidity?.toStringAsFixed(1) ?? '--',
                        status: _getTurbidityStatus(bot.turbidity),
                        unit: 'NTU',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildSensorCard(
                        icon: Icons.thermostat,
                        label: 'Temperature',
                        value: bot.temperature?.toStringAsFixed(1) ?? '--',
                        status: _getTemperatureStatus(bot.temperature),
                        unit: '°C',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSensorCard(
                        icon: Icons.air,
                        label: 'Dissolved O₂',
                        value:
                            bot.dissolvedOxygen?.toStringAsFixed(1) ?? '--',
                        status: _getDOStatus(bot.dissolvedOxygen),
                        unit: 'mg/L',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Footer
          if (bot.lastUpdated != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 14,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Last updated: ${DateFormatter.formatDateTime(bot.lastUpdated!)}',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSensorCard({
    required IconData icon,
    required String label,
    required String value,
    required String status,
    required String unit,
  }) {
    final Color statusColor = _getStatusColor(status);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: statusColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: AppTextStyles.headlineSmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    unit,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status,
              style: AppTextStyles.labelSmall.copyWith(
                color: statusColor,
                fontWeight: FontWeight.w600,
                fontSize: 9,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoricalView() {
    if (_historicalData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              'No Historical Data',
              style: AppTextStyles.titleMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Historical readings will appear here',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _historicalData.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final reading = _historicalData[index];
        return _buildHistoricalReadingCard(reading);
      },
    );
  }

  Widget _buildHistoricalReadingCard(HistoricalReading reading) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Text(
                DateFormatter.formatDateTime(reading.timestamp),
                style: AppTextStyles.labelMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildHistoricalMetric(
                  'pH',
                  reading.phLevel?.toStringAsFixed(2) ?? '--',
                ),
              ),
              Expanded(
                child: _buildHistoricalMetric(
                  'Turbidity',
                  reading.turbidity != null
                      ? '${reading.turbidity!.toStringAsFixed(1)} NTU'
                      : '--',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildHistoricalMetric(
                  'Temp',
                  reading.temperature != null
                      ? '${reading.temperature!.toStringAsFixed(1)}°C'
                      : '--',
                ),
              ),
              Expanded(
                child: _buildHistoricalMetric(
                  'DO',
                  reading.dissolvedOxygen != null
                      ? '${reading.dissolvedOxygen!.toStringAsFixed(1)} mg/L'
                      : '--',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoricalMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _getPhStatus(double? ph) {
    if (ph == null) return 'Unknown';
    if (ph >= 6.5 && ph <= 8.5) return 'Normal';
    if (ph >= 6.0 && ph <= 9.0) return 'Acceptable';
    return 'Poor';
  }

  String _getTurbidityStatus(double? turbidity) {
    if (turbidity == null) return 'Unknown';
    if (turbidity < 5) return 'Excellent';
    if (turbidity < 25) return 'Good';
    if (turbidity < 50) return 'Fair';
    return 'Poor';
  }

  String _getTemperatureStatus(double? temp) {
    if (temp == null) return 'Unknown';
    if (temp >= 15 && temp <= 30) return 'Normal';
    if (temp < 15) return 'Cold';
    return 'Warm';
  }

  String _getDOStatus(double? dissolvedOxygen) {
    if (dissolvedOxygen == null) return 'Unknown';
    if (dissolvedOxygen >= 6) return 'Good';
    if (dissolvedOxygen >= 4) return 'Acceptable';
    return 'Poor';
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'excellent':
      case 'normal':
      case 'good':
        return AppColors.success;
      case 'acceptable':
      case 'fair':
        return AppColors.warning;
      case 'poor':
        return AppColors.error;
      case 'cold':
      case 'warm':
        return AppColors.info;
      default:
        return AppColors.textMuted;
    }
  }
}

class BotEnvironmentalData {
  final String botId;
  final String botName;
  final String? riverId;
  final String? riverName;
  final double? phLevel;
  final double? turbidity;
  final double? temperature;
  final double? dissolvedOxygen;
  final DateTime? lastUpdated;
  final String status;

  BotEnvironmentalData({
    required this.botId,
    required this.botName,
    this.riverId,
    this.riverName,
    this.phLevel,
    this.turbidity,
    this.temperature,
    this.dissolvedOxygen,
    this.lastUpdated,
    required this.status,
  });
}

class HistoricalReading {
  final DateTime timestamp;
  final double? phLevel;
  final double? turbidity;
  final double? temperature;
  final double? dissolvedOxygen;
  final String deploymentId;

  HistoricalReading({
    required this.timestamp,
    this.phLevel,
    this.turbidity,
    this.temperature,
    this.dissolvedOxygen,
    required this.deploymentId,
  });
}

