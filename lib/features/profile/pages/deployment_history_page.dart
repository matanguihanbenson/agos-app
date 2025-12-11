import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/widgets/app_bar.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/theme/color_palette.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/models/deployment_model.dart';
import 'deployment_details_page.dart';
import 'grouped_deployment_details_page.dart';

class DeploymentHistoryPage extends ConsumerStatefulWidget {
  const DeploymentHistoryPage({super.key});

  @override
  ConsumerState<DeploymentHistoryPage> createState() =>
      _DeploymentHistoryPageState();
}

class _DeploymentHistoryPageState
    extends ConsumerState<DeploymentHistoryPage> {
  List<DeploymentModel> _deployments = [];
  List<DeploymentGroup> _groupedDeployments = [];
  bool _isLoading = true;
  String? _error;
  String _statusFilter = 'all'; // all, completed, active, cancelled
  String _timeRange = '30d'; // 7d, 30d, 90d, all

  @override
  void initState() {
    super.initState();
    _loadDeploymentHistory();
  }

  Future<void> _loadDeploymentHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final auth = ref.read(authProvider);
      final userId = auth.currentUser?.uid;
      final isAdmin = auth.userProfile?.isAdmin ?? false;

      if (userId == null) {
        setState(() {
          _error = 'User not authenticated';
          _isLoading = false;
        });
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

      print('Loading deployment history - userId: $userId, isAdmin: $isAdmin, statusFilter: $_statusFilter, timeRange: $_timeRange');
      
      final firestore = FirebaseFirestore.instance;
      Query query = firestore.collection('deployments').orderBy('created_at', descending: true);

      // Role-based filter
      if (!isAdmin) {
        // Field operator: show only deployments they were involved in
        query = query.where('owner_admin_id', isEqualTo: userId);
      } else {
        // Admin: show deployments they own
        query = query.where('owner_admin_id', isEqualTo: userId);
      }

      // Status filter
      if (_statusFilter != 'all') {
        query = query.where('status', isEqualTo: _statusFilter);
      }

      // Time range filter
      if (startDate != null) {
        query = query.where('created_at',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      query = query.limit(100);

      final snapshot = await query.get();
      
      print('Deployment history query returned ${snapshot.docs.length} documents');

      final deployments = snapshot.docs
          .map((doc) {
            try {
              final deployment = DeploymentModel.fromMap(
                  doc.data() as Map<String, dynamic>, doc.id);
              print('Loaded deployment: ${deployment.id}, status: ${deployment.status}, bot: ${deployment.botId}');
              return deployment;
            } catch (e) {
              print('Error parsing deployment ${doc.id}: $e');
              return null;
            }
          })
          .whereType<DeploymentModel>()
          .toList();
      
      print('Successfully loaded ${deployments.length} deployments');

      if (mounted) {
        setState(() {
          _deployments = deployments;
          _groupedDeployments = _buildDeploymentGroups(deployments);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading deployment history: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load deployment history: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const GlobalAppBar(
        title: 'Deployment History',
        showDrawer: false,
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: _isLoading
                ? const LoadingIndicator()
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 48,
                                color: AppColors.error,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _error!,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.error,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : _groupedDeployments.isEmpty
                        ? const EmptyState(
                            icon: Icons.history,
                            title: 'No Deployment History',
                            message:
                                'Your deployment history will appear here',
                          )
                        : RefreshIndicator(
                            onRefresh: _loadDeploymentHistory,
                            child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _groupedDeployments.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final group = _groupedDeployments[index];
                              return _buildGroupedDeploymentCard(group);
                            },
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
              value: _statusFilter,
              items: const ['all', 'active', 'completed', 'cancelled', 'scheduled'],
              onChanged: (v) {
                if (v != null) {
                  setState(() => _statusFilter = v);
                  _loadDeploymentHistory();
                }
              },
              labelBuilder: (v) {
                if (v == 'all') return 'All Status';
                return v.toUpperCase();
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildDropdown<String>(
              value: _timeRange,
              items: const ['7d', '30d', '90d', 'all'],
              onChanged: (v) {
                if (v != null) {
                  setState(() => _timeRange = v);
                  _loadDeploymentHistory();
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

  List<DeploymentGroup> _buildDeploymentGroups(
      List<DeploymentModel> deployments) {
    final Map<String, List<DeploymentModel>> grouped = {};

    for (final d in deployments) {
      // Group key: same bot, same river, same calendar day
      final day = DateTime(d.createdAt.year, d.createdAt.month, d.createdAt.day);
      final key = '${d.botId}|${d.riverId}|${day.toIso8601String()}';
      grouped.putIfAbsent(key, () => []).add(d);
    }

    final List<DeploymentGroup> result = [];
    grouped.forEach((key, list) {
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final first = list.first;
      final totalWeight = list.fold<double>(
        0.0,
        (sum, d) => sum + (d.trashCollection?.totalWeight ?? 0.0),
      );
      result.add(
        DeploymentGroup(
          botId: first.botId,
          botName: first.botName,
          riverId: first.riverId,
          riverName: first.riverName,
          day: DateTime(first.createdAt.year, first.createdAt.month, first.createdAt.day),
          deployments: list,
          totalWeight: totalWeight,
        ),
      );
    });

    // Newest groups first
    result.sort((a, b) => b.day.compareTo(a.day));
    return result;
  }

  Widget _buildGroupedDeploymentCard(DeploymentGroup group) {
    // Use status of latest deployment in the group for color/icon
    final latest = group.deployments.last;
    final Color statusColor = _getStatusColor(latest.status);
    final IconData statusIcon = _getStatusIcon(latest.status);
    final trashWeight = group.totalWeight;
    final hasTrash = trashWeight > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shadowColor: statusColor.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: statusColor.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                GroupedDeploymentDetailsPage(group: group),
          ),
        ),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with river and status
              Row(
                children: [
                  // River icon
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          statusColor.withOpacity(0.2),
                          statusColor.withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.water,
                      color: statusColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // River and bot info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.riverName,
                          style: AppTextStyles.titleSmall.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.directions_boat,
                              size: 12,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              group.botName,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 12, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          latest.status.toUpperCase(),
                          style: AppTextStyles.labelSmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 14),
              
              // Location and date
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.place, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            latest.operationLocation ?? 'Unknown location',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textPrimary,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          DateFormatter.formatDateTime(group.day),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Quick stats (if has trash or water data)
              if (hasTrash || latest.waterQuality != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (hasTrash)
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.green.withOpacity(0.2),
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.delete_sweep, size: 16, color: Colors.green),
                              const SizedBox(height: 3),
                              Text(
                                '${trashWeight.toStringAsFixed(1)} kg',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                'Trash',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (hasTrash && latest.waterQuality != null)
                      const SizedBox(width: 6),
                    if (latest.waterQuality != null)
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.blue.withOpacity(0.2),
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.water_drop, size: 16, color: Colors.blue),
                              const SizedBox(height: 3),
                              Text(
                                'pH ${latest.waterQuality!.avgPhLevel.toStringAsFixed(1)}',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                'Water',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (latest.waterQuality != null)
                      const SizedBox(width: 6),
                    if (latest.waterQuality != null)
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.orange.withOpacity(0.2),
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.thermostat, size: 16, color: Colors.orange),
                              const SizedBox(height: 3),
                              Text(
                                '${latest.waterQuality!.avgTemperature.toStringAsFixed(1)}°C',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                'Temp',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (latest.waterQuality != null)
                      const SizedBox(width: 6),
                    if (latest.waterQuality != null)
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                          decoration: BoxDecoration(
                            color: Colors.brown.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.brown.withOpacity(0.2),
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.opacity, size: 16, color: Colors.brown),
                              const SizedBox(height: 3),
                              Text(
                                '${latest.waterQuality!.avgTurbidity.toStringAsFixed(0)}',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.brown,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                'NTU',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              
              // View details prompt
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Tap for details',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.primary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textMuted,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTextStyles.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildMetric(String label, String value) {
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
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }

  void _showDeploymentDetails(DeploymentModel deployment) {
    // Navigate to new deployment details page instead of showing popup
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DeploymentDetailsPage(deployment: deployment),
      ),
    );
  }

  void _showDeploymentDetailsOld(DeploymentModel deployment) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.all(24),
                  children: [
                    Text(
                      deployment.scheduleName ?? 'Deployment Details',
                      style: AppTextStyles.headlineSmall.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildDetailSection('Bot Information', [
                      _buildDetailRow('Bot Name', deployment.botName),
                      _buildDetailRow('Bot ID', deployment.botId),
                    ]),
                    const SizedBox(height: 16),
                    _buildDetailSection('Location', [
                      _buildDetailRow(
                          'River', deployment.riverName ?? deployment.riverId),
                      _buildDetailRow(
                          'Area', deployment.operationLocation ?? 'Unknown'),
                      if (deployment.operationRadius != null)
                        _buildDetailRow('Radius',
                            '${deployment.operationRadius!.toStringAsFixed(0)}m'),
                    ]),
                    const SizedBox(height: 16),
                    _buildDetailSection('Timeline', [
                      _buildDetailRow('Status', deployment.status.toUpperCase()),
                      _buildDetailRow('Scheduled Start',
                          DateFormatter.formatDateTime(deployment.scheduledStartTime)),
                      _buildDetailRow('Scheduled End',
                          DateFormatter.formatDateTime(deployment.scheduledEndTime)),
                      if (deployment.actualStartTime != null)
                        _buildDetailRow('Actual Start',
                            DateFormatter.formatDateTime(deployment.actualStartTime!)),
                      if (deployment.actualEndTime != null)
                        _buildDetailRow('Actual End',
                            DateFormatter.formatDateTime(deployment.actualEndTime!)),
                    ]),
                    if (deployment.trashCollection != null) ...[
                      const SizedBox(height: 16),
                      _buildDetailSection('Waste Collection', [
                        _buildDetailRow('Total Weight',
                            '${deployment.trashCollection!.totalWeight.toStringAsFixed(2)} kg'),
                        _buildDetailRow('Total Items',
                            '${deployment.trashCollection!.totalItems}'),
                        const SizedBox(height: 8),
                        Text(
                          'By Type:',
                          style: AppTextStyles.labelMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ...deployment.trashCollection!.trashByType.entries
                            .map((e) => Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 2),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('  ${e.key}:',
                                          style: AppTextStyles.bodySmall),
                                      Text('${e.value} items',
                                          style: AppTextStyles.bodySmall
                                              .copyWith(
                                                  fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                )),
                      ]),
                    ],
                    if (deployment.waterQuality != null) ...[
                      const SizedBox(height: 16),
                      _buildDetailSection('Water Quality', [
                        _buildDetailRow('pH Level',
                            deployment.waterQuality!.avgPhLevel.toStringAsFixed(2)),
                        _buildDetailRow('Turbidity',
                            '${deployment.waterQuality!.avgTurbidity.toStringAsFixed(1)} NTU'),
                        _buildDetailRow('Temperature',
                            '${deployment.waterQuality!.avgTemperature.toStringAsFixed(1)}°C'),
                        _buildDetailRow('Dissolved O₂',
                            '${deployment.waterQuality!.avgDissolvedOxygen.toStringAsFixed(1)} mg/L'),
                        _buildDetailRow('Samples',
                            '${deployment.waterQuality!.sampleCount}'),
                      ]),
                    ],
                    if (deployment.notes != null &&
                        deployment.notes!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildDetailSection('Notes', [
                        Text(
                          deployment.notes!,
                          style: AppTextStyles.bodyMedium,
                        ),
                      ]),
                    ],
                    const SizedBox(height: 24),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.titleSmall.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return AppColors.success;
      case 'completed':
        return AppColors.info;
      case 'cancelled':
        return AppColors.error;
      case 'scheduled':
        return AppColors.warning;
      default:
        return AppColors.textMuted;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Icons.rocket_launch;
      case 'completed':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      case 'scheduled':
        return Icons.schedule;
      default:
        return Icons.help_outline;
    }
  }
}

