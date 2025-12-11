import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/widgets/app_bar.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/theme/color_palette.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/models/activity_log_model.dart';
import 'activity_log_details_page.dart';

class ActivityLogsPage extends ConsumerStatefulWidget {
  const ActivityLogsPage({super.key});

  @override
  ConsumerState<ActivityLogsPage> createState() => _ActivityLogsPageState();
}

class _ActivityLogsPageState extends ConsumerState<ActivityLogsPage> {
  bool _isLoading = true;
  String? _error;
  List<ActivityLogModel> _logs = [];

  // Filters
  ActivityLogCategory? _categoryFilter;
  String _range = 'all';   // today, 7d, 30d, all (default to 'all' for better UX)
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  // Helper to chunk a list into parts of size n (used for Firestore whereIn limit)
  List<List<T>> _chunk<T>(List<T> list, int size) {
    final chunks = <List<T>>[];
    for (var i = 0; i < list.length; i += size) {
      chunks.add(list.sublist(i, i + size > list.length ? list.length : i + size));
    }
    return chunks;
  }

  @override
  void initState() {
    super.initState();
    _loadActivityLogs();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _loadActivityLogs();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const GlobalAppBar(
        title: 'Activity Logs',
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
                    : _logs.isEmpty
                        ? const EmptyState(
                            icon: Icons.history,
                            title: 'No Activity Logs',
                            message: 'Your activity history will appear here',
                          )
                        : RefreshIndicator(
                            onRefresh: _loadActivityLogs,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: _logs.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final log = _logs[index];
                                return _buildLogItem(log);
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
            width: 1,
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
          // Category chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildCategoryChip('All', null),
              _buildCategoryChip('System', ActivityLogCategory.system),
              _buildCategoryChip('Auth', ActivityLogCategory.auth),
              _buildCategoryChip('User', ActivityLogCategory.user),
              _buildCategoryChip('Bot', ActivityLogCategory.bot),
            ],
          ),
          const SizedBox(height: 12),
          
          // Search and time range
          Row(
            children: [
              // Time range dropdown
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border.withValues(alpha: 0.3)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _range,
                    isDense: true,
                    icon: Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
                    items: const [
                      DropdownMenuItem(value: 'today', child: Text('Today')),
                      DropdownMenuItem(value: '7d', child: Text('Last 7 days')),
                      DropdownMenuItem(value: '30d', child: Text('Last 30 days')),
                      DropdownMenuItem(value: 'all', child: Text('All time')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _range = v);
                        _loadActivityLogs();
                      }
                    },
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // Search field
              Expanded(
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search, size: 20, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            hintText: 'Search logs...',
                            hintStyle: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                          style: AppTextStyles.bodySmall,
                        ),
                      ),
                      if (_searchController.text.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _searchController.clear();
                          },
                          child: Icon(
                            Icons.clear,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String label, ActivityLogCategory? category) {
    final bool isSelected = _categoryFilter == category;
    final Color chipColor = _getCategoryColor(category);

    return GestureDetector(
      onTap: () {
        setState(() {
          _categoryFilter = category;
        });
        _loadActivityLogs();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? chipColor.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? chipColor : AppColors.border.withValues(alpha: 0.3),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: isSelected ? chipColor : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildLogItem(ActivityLogModel log) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ActivityLogDetailsPage(log: log),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.border.withValues(alpha: 0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _getSeverityColor(log.severity).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(
                _getTypeIcon(log.type),
                color: _getSeverityColor(log.severity),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and category badge
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          log.title,
                          style: AppTextStyles.bodyLarge.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _getCategoryColor(log.category).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _formatCategory(log.category),
                          style: AppTextStyles.labelSmall.copyWith(
                            color: _getCategoryColor(log.category),
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (log.description.isNotEmpty) ...[ 
                    const SizedBox(height: 6),
                    Text(
                      log.description,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormatter.formatDateTime(log.timestamp),
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                      if (log.userName != null) ...[
                        const SizedBox(width: 12),
                        Icon(
                          Icons.person_outline,
                          size: 14,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            log.userName!,
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.textMuted,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              color: AppColors.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getTypeIcon(ActivityLogType type) {
    switch (type) {
      case ActivityLogType.login:
        return Icons.login_rounded;
      case ActivityLogType.logout:
        return Icons.logout_rounded;
      case ActivityLogType.loginFailed:
        return Icons.error_outline_rounded;
      case ActivityLogType.passwordChanged:
      case ActivityLogType.passwordResetRequested:
      case ActivityLogType.passwordResetCompleted:
        return Icons.lock_reset_rounded;
      case ActivityLogType.userCreated:
        return Icons.person_add_rounded;
      case ActivityLogType.userUpdated:
      case ActivityLogType.profileUpdated:
        return Icons.edit_rounded;
      case ActivityLogType.userDeleted:
        return Icons.person_remove_rounded;
      case ActivityLogType.userAssignedToOrg:
        return Icons.business_rounded;
      case ActivityLogType.userBotAssigned:
      case ActivityLogType.botAssigned:
        return Icons.assignment_ind_rounded;
      case ActivityLogType.botRegistered:
        return Icons.add_circle_outline_rounded;
      case ActivityLogType.botUnregistered:
        return Icons.remove_circle_outline_rounded;
      case ActivityLogType.botReassigned:
        return Icons.swap_horiz_rounded;
      case ActivityLogType.botUnassigned:
        return Icons.link_off_rounded;
      case ActivityLogType.scheduleCreated:
        return Icons.event_available_rounded;
      case ActivityLogType.scheduleCanceled:
        return Icons.event_busy_rounded;
      case ActivityLogType.deploymentStarted:
        return Icons.rocket_launch_rounded;
      case ActivityLogType.deploymentCompleted:
        return Icons.check_circle_outline_rounded;
      case ActivityLogType.deploymentFailed:
        return Icons.error_rounded;
      case ActivityLogType.systemError:
        return Icons.bug_report_rounded;
      case ActivityLogType.systemWarning:
        return Icons.warning_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  Color _getSeverityColor(ActivityLogSeverity severity) {
    switch (severity) {
      case ActivityLogSeverity.success:
        return AppColors.success;
      case ActivityLogSeverity.info:
        return AppColors.info;
      case ActivityLogSeverity.warning:
        return AppColors.warning;
      case ActivityLogSeverity.error:
      case ActivityLogSeverity.critical:
        return AppColors.error;
    }
  }

  Color _getCategoryColor(ActivityLogCategory? category) {
    if (category == null) return AppColors.primary;
    switch (category) {
      case ActivityLogCategory.system:
        return AppColors.info;
      case ActivityLogCategory.auth:
        return AppColors.accent;
      case ActivityLogCategory.user:
        return AppColors.secondary;
      case ActivityLogCategory.bot:
        return AppColors.primary;
    }
  }

  String _formatCategory(ActivityLogCategory category) {
    switch (category) {
      case ActivityLogCategory.system:
        return 'SYSTEM';
      case ActivityLogCategory.auth:
        return 'AUTH';
      case ActivityLogCategory.user:
        return 'USER';
      case ActivityLogCategory.bot:
        return 'BOT';
    }
  }

  Future<void> _loadActivityLogs() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final auth = ref.read(authProvider);
      final String? currentUserId = auth.currentUser?.uid;
      final bool isAdmin = auth.userProfile?.isAdmin ?? false;

      if (currentUserId == null) {
        if (!mounted) return;
        setState(() {
          _error = 'User not authenticated';
          _isLoading = false;
        });
        return;
      }

      // Time range
      DateTime? start;
      final now = DateTime.now();
      switch (_range) {
        case 'today':
          start = DateTime(now.year, now.month, now.day);
          break;
        case '7d':
          start = now.subtract(const Duration(days: 7));
          break;
        case '30d':
          start = now.subtract(const Duration(days: 30));
          break;
        case 'all':
        default:
          start = null;
      }

      final String searchQuery = _searchController.text.trim().toLowerCase();

      List<ActivityLogModel> logs = [];

      if (!isAdmin) {
        // FIELD OPERATOR: only logs they generated
        Query query = FirebaseFirestore.instance
            .collection('activity_logs')
            .orderBy('timestamp', descending: true)
            .limit(100)
            .where('user_id', isEqualTo: currentUserId);

        // Filter by category if selected
        if (_categoryFilter != null) {
          query = query.where('category', isEqualTo: _categoryFilter!.name);
        }

        // Filter by time range
        if (start != null) {
          query = query.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start));
        }

        final snapshot = await query.get();
        logs = snapshot.docs.map((doc) {
          try {
            return ActivityLogModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
          } catch (e) {
            print('Error parsing log: $e');
            return null;
          }
        }).whereType<ActivityLogModel>().where((log) {
          // Filter out location-related logs
          return !_isLocationLog(log);
        }).toList();
      } else {
        // ADMIN: show latest logs across the workspace (no user_id filter), with optional time filter
        final firestore = FirebaseFirestore.instance;
        Query q = firestore
            .collection('activity_logs')
            .orderBy('timestamp', descending: true)
            .limit(200);

        // Time filter on server (requires single-field index only)
        if (start != null) {
          q = q.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start));
        }

        final snap = await q.get();
        logs = snap.docs.map((doc) {
          try {
            return ActivityLogModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
          } catch (e) {
            print('Error parsing log: $e');
            return null;
          }
        }).whereType<ActivityLogModel>().where((log) {
          // Filter out location-related logs
          return !_isLocationLog(log);
        }).toList();

        // Apply category filter client-side to avoid composite index requirements
        if (_categoryFilter != null) {
          logs = logs.where((l) => l.category.name == _categoryFilter!.name).toList();
        }
      }

      // Apply search filter locally
      if (searchQuery.isNotEmpty) {
        logs = logs.where((log) {
          return log.title.toLowerCase().contains(searchQuery) ||
                 log.description.toLowerCase().contains(searchQuery) ||
                 (log.userName?.toLowerCase().contains(searchQuery) ?? false);
        }).toList();
      }

      if (!mounted) return;
      setState(() {
        _logs = logs;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading logs: $e');
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load logs: $e';
        _isLoading = false;
      });
    }
  }

  /// Helper method to filter out location-related logs
  bool _isLocationLog(ActivityLogModel log) {
    // List of location-related event names to filter out
    const locationEvents = [
      'location_permission_granted',
      'location_permissions_denied',
      'location_permissions_permanently_denied',
      'location_permission_not_granted',
      'requesting_location_permission',
      'location_services_disabled',
      'current_position_obtained',
    ];
    
    // Check if the log title or metadata contains location events
    if (locationEvents.any((event) => log.title.toLowerCase().contains(event))) {
      return true;
    }
    
    // Check metadata for location events
    if (log.metadata['event'] != null) {
      final event = log.metadata['event'].toString().toLowerCase();
      if (locationEvents.contains(event)) {
        return true;
      }
    }
    
    return false;
  }
}
