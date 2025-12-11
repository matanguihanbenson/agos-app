# Schedule and River Management Implementation Guide

This document contains all the remaining files needed to complete the Schedule and River Management features.

## Files Created ✅
- ✅ `lib/core/models/river_model.dart`
- ✅ `lib/core/models/schedule_model.dart`
- ✅ `lib/core/services/river_service.dart`
- ✅ `lib/core/services/schedule_service.dart`
- ✅ `lib/core/providers/river_provider.dart`
- ✅ `lib/core/providers/schedule_provider.dart`
- ✅ `lib/features/schedule/widgets/schedule_card.dart`

## Files to Create

### 1. Schedule Page (`lib/features/schedule/pages/schedule_page.dart`)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/schedule_provider.dart';
import '../../../core/theme/color_palette.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/empty_state.dart';
import '../widgets/schedule_card.dart';
import 'create_schedule_page.dart';

class SchedulePage extends ConsumerStatefulWidget {
  const SchedulePage({super.key});

  @override
  ConsumerState<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends ConsumerState<SchedulePage> {
  String? _selectedFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(scheduleProvider.notifier).loadSchedules();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheduleState = ref.watch(scheduleProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('River Cleanup Schedules'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              ref.read(scheduleProvider.notifier).loadSchedules();
            },
          ),
        ],
      ),
      body: scheduleState.isLoading
          ? const LoadingIndicator(message: 'Loading schedules...')
          : Column(
              children: [
                _buildFilterSection(),
                _buildScheduleList(scheduleState),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateSchedulePage()),
          );
          if (result == true) {
            ref.read(scheduleProvider.notifier).loadSchedules();
          }
        },
        icon: Icon(Icons.add),
        label: Text('New Cleanup'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Widget _buildFilterSection() {
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
                '4 of 4',
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
        ref.read(scheduleProvider.notifier).setFilter(_selectedFilter);
      },
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.primary.withOpacity(0.1),
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

  Widget _buildScheduleList(ScheduleState state) {
    final schedules = state.filteredSchedules;

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
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateSchedulePage()),
            );
            if (result == true) {
              ref.read(scheduleProvider.notifier).loadSchedules();
            }
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
            onTap: () {
              // Navigate to schedule details
            },
            onEdit: schedule.isScheduled
                ? () {
                    // Navigate to edit schedule
                  }
                : null,
            onCancel: schedule.isScheduled
                ? () {
                    _showCancelDialog(schedule.id);
                  }
                : null,
            onViewMap: () {
              // Navigate to map view
            },
          );
        },
      ),
    );
  }

  Future<void> _showCancelDialog(String scheduleId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cancel Schedule'),
        content: Text('Are you sure you want to cancel this cleanup schedule?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(scheduleProvider.notifier).cancelSchedule(scheduleId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Schedule cancelled successfully')),
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
}
```

### 2. Create Schedule Page (`lib/features/schedule/pages/create_schedule_page.dart`)

This will be a continuation document. Due to file length constraints, I'll provide the key structure and you can request specific sections.

The Create Schedule Page needs:
1. River name input with auto-suggestions
2. Bot selection
3. Date/Time picker
4. Operation Area section (lat/lng + view map button)
5. Docking Point section (lat/lng + view map button)
6. Map Selection Page for both operation and docking

### 3. Map Selection Page Structure

The map selection page should include:
- flutter_map integration
- Radius slider (for operation area only)
- Current location button
- Zoom controls (+/-)
- Selected location display (lat/lng)
- Reverse geocoding display
- Coverage area display (for operation area)
- Done button to confirm selection

## Next Steps

To complete the implementation, I recommend:

1. **Update schedule_page.dart** - Replace the existing file
2. **Create create_schedule_page.dart** - With form for schedule creation
3. **Create map_selection_page.dart** - With interactive map
4. **Create river_management_page.dart** - For river CRUD
5. **Update sidebar navigation** - Add river management link

Would you like me to continue with the detailed implementation of any specific page? I can create them one at a time to avoid message length issues.

## Key Features to Implement

### Create Schedule Page Features:
- ✅ River name autocomplete
- ✅ Bot selection from available bots
- ✅ Date and time picker
- ✅ Operation area with map selection
- ✅ Docking point with map selection
- ✅ Reverse geocoding for locations
- ✅ Coverage radius for operation area

### Map Selection Page Features:
- ✅ Interactive flutter_map
- ✅ Tap to select location
- ✅ Radius adjustment slider
- ✅ Current location button
- ✅ Zoom controls
- ✅ Reverse geocoding display
- ✅ Confirmation button

### River Management Page Features:
- ✅ List of all rivers
- ✅ Add new river
- ✅ Edit river details
- ✅ View deployment history
- ✅ Analytics per river
- ✅ Bots deployed on river

## Database Collections

### Rivers Collection:
```
rivers/
  {riverId}/
    name: string
    description: string?
    owner_admin_id: string
    organization_id: string?
    total_deployments: number
    active_deployments: number
    total_trash_collected: number?
    last_deployment: timestamp?
    created_at: timestamp
    updated_at: timestamp
```

### Schedules Collection:
```
schedules/
  {scheduleId}/
    name: string
    bot_id: string
    bot_name: string?
    river_id: string
    river_name: string?
    owner_admin_id: string
    assigned_operator_id: string?
    assigned_operator_name: string?
    operation_area: {
      center: {
        latitude: number
        longitude: number
        location_name: string?
      }
      radius_in_meters: number
      location_name: string?
    }
    docking_point: {
      latitude: number
      longitude: number
      location_name: string?
    }
    scheduled_date: timestamp
    status: string
    started_at: timestamp?
    completed_at: timestamp?
    trash_collected: number?
    area_cleaned_percentage: number?
    notes: string?
    created_at: timestamp
    updated_at: timestamp
```
