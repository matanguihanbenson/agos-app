import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/schedule_model.dart';
import '../../../core/providers/schedule_provider.dart';
import '../../../core/theme/color_palette.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/empty_state.dart';
import '../widgets/schedule_card.dart';
import 'create_schedule_page.dart';
import 'schedule_detail_page.dart';
import 'edit_schedule_page.dart';

class SchedulePage extends ConsumerStatefulWidget {
  const SchedulePage({super.key});

  @override
  ConsumerState<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends ConsumerState<SchedulePage> {
  String? _selectedFilter;

  @override
  Widget build(BuildContext context) {
    // Watch the real-time stream of schedules
    final schedulesAsync = ref.watch(schedulesStreamProvider);
    
    return schedulesAsync.when(
      data: (schedules) => _buildScheduleView(schedules),
      loading: () => const LoadingIndicator(message: 'Loading schedules...'),
      error: (error, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text('Error: $error', style: AppTextStyles.bodyMedium),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleView(List<ScheduleModel> allSchedules) {
    // Sort by scheduled date, newest first
    final sortedSchedules = List<ScheduleModel>.from(allSchedules)
      ..sort((a, b) => b.scheduledDate.compareTo(a.scheduledDate));
    
    // Apply filter
    final filteredSchedules = _selectedFilter == null
        ? sortedSchedules
        : sortedSchedules.where((s) => s.status == _selectedFilter).toList();

    return Stack(
      children: [
        Container(
          color: AppColors.background,
          child: Column(
            children: [
              _buildFilterSection(sortedSchedules, filteredSchedules),
              _buildScheduleList(filteredSchedules),
            ],
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateSchedulePage()),
              );
              // Real-time stream will automatically update
            },
            icon: const Icon(Icons.add),
            label: const Text('New Cleanup'),
            backgroundColor: AppColors.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterSection(List<ScheduleModel> allSchedules, List<ScheduleModel> filteredSchedules) {
    final totalCount = allSchedules.length;
    final filteredCount = filteredSchedules.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.filter_list, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Text(
                'Filter Schedules',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '$filteredCount of $totalCount',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', null),
                const SizedBox(width: 8),
                _buildFilterChip('Scheduled', 'scheduled'),
                const SizedBox(width: 8),
                _buildFilterChip('Active', 'active'),
                const SizedBox(width: 8),
                _buildFilterChip('Completed', 'completed'),
                const SizedBox(width: 8),
                _buildFilterChip('Cancelled', 'cancelled'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String? filterValue) {
    final isSelected = _selectedFilter == filterValue;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = selected ? filterValue : null;
        });
      },
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.primary.withValues(alpha: 0.1),
      checkmarkColor: AppColors.primary,
      side: BorderSide(
        color: isSelected ? AppColors.primary : AppColors.border,
      ),
      labelStyle: AppTextStyles.bodySmall.copyWith(
        color: isSelected ? AppColors.primary : AppColors.textSecondary,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
      ),
    );
  }

  Widget _buildScheduleList(List<ScheduleModel> schedules) {

    if (schedules.isEmpty) {
      return Expanded(
        child: EmptyState(
          icon: Icons.event_busy,
          title: 'No Schedules',
          message: _selectedFilter == null
              ? 'No cleanup schedules found. Create your first schedule.'
              : 'No schedules found with the selected filter.',
          actionLabel: 'Create Schedule',
          onAction: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateSchedulePage()),
            );
          },
        ),
      );
    }

    return Expanded(
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: schedules.length,
        itemBuilder: (context, index) {
          final schedule = schedules[index];
          return ScheduleCard(
            schedule: schedule,
            onTap: () => _navigateToScheduleDetails(schedule),
            // Scheduled status actions
            onEdit: schedule.isScheduled
                ? () => _navigateToEditSchedule(schedule)
                : null,
            onCancel: schedule.isScheduled
                ? () => _showCancelDialog(schedule.id)
                : null,
            onDelete: schedule.isScheduled
                ? () => _showDeleteDialog(schedule.id)
                : null,
            // Active status actions (pause removed, only recall)
            onRecall: schedule.isActive
                ? () => _showRecallDialog(schedule.id)
                : null,
            // Completed status actions
            onViewActions: schedule.isCompleted
                ? () => _navigateToScheduleActions(schedule)
                : null,
          );
        },
      ),
    );
  }

  void _navigateToScheduleDetails(dynamic schedule) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScheduleDetailPage(schedule: schedule),
      ),
    );
  }

  void _navigateToEditSchedule(dynamic schedule) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditSchedulePage(schedule: schedule),
      ),
    );
    if (result == true && mounted) {
      ref.read(scheduleProvider.notifier).loadSchedules();
    }
  }

  void _navigateToScheduleActions(dynamic schedule) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScheduleDetailPage(schedule: schedule),
      ),
    );
  }

  Future<void> _showCancelDialog(String scheduleId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Schedule'),
        content: const Text('Are you sure you want to cancel this cleanup schedule?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(scheduleProvider.notifier).cancelSchedule(scheduleId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Schedule cancelled successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to cancel schedule: $e')),
          );
        }
      }
    }
  }

  Future<void> _showDeleteDialog(String scheduleId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Schedule'),
        content: const Text('Are you sure you want to permanently delete this schedule?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Yes, Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(scheduleProvider.notifier).deleteSchedule(scheduleId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Schedule deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete schedule: $e')),
          );
        }
      }
    }
  }


  Future<void> _showRecallDialog(String scheduleId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recall Bot'),
        content: const Text('Do you want to recall the bot back to base?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.info,
            ),
            child: const Text('Yes, Recall'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(scheduleProvider.notifier).recallSchedule(scheduleId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bot recalled successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to recall bot: $e')),
          );
        }
      }
    }
  }
}
