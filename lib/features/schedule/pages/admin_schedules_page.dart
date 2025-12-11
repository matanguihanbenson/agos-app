import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/widgets/app_bar.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/theme/color_palette.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/models/schedule_model.dart';
import '../../../core/providers/schedule_provider.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/providers/bot_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../widgets/schedule_card.dart';
import 'schedule_detail_page.dart';

class AdminSchedulesPage extends ConsumerStatefulWidget {
  const AdminSchedulesPage({super.key});

  @override
  ConsumerState<AdminSchedulesPage> createState() => _AdminSchedulesPageState();
}

class _AdminSchedulesPageState extends ConsumerState<AdminSchedulesPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedStatus;
  String? _selectedUserId;
  String? _selectedBotId;
  List<ScheduleModel> _allSchedules = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final currentUser = ref.read(authProvider).userProfile;
    if (currentUser == null) return;

    // Load all schedules for the admin and their field operators
    await _loadAllRelatedSchedules();
    
    ref.read(userProvider.notifier).loadUsersByCreator(currentUser.id);
    ref.read(botProvider.notifier).loadBots();
  }

  Future<void> _loadAllRelatedSchedules() async {
    final currentUser = ref.read(authProvider).userProfile;
    if (currentUser == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Get list of user IDs to fetch schedules for
      List<String> userIdsToFetch = [currentUser.id];
      
      // Get all field operators created by this admin
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('created_by', isEqualTo: currentUser.id)
          .get();
      
      final operatorIds = usersSnapshot.docs.map((doc) => doc.id).toList();
      userIdsToFetch.addAll(operatorIds);

      // Fetch schedules for all relevant users
      List<ScheduleModel> allSchedules = [];
      for (final userId in userIdsToFetch) {
        final schedulesSnapshot = await FirebaseFirestore.instance
            .collection('schedules')
            .where('owner_admin_id', isEqualTo: userId)
            .get();
        
        final userSchedules = schedulesSnapshot.docs
            .map((doc) => ScheduleModel.fromMap(doc.data(), doc.id))
            .toList();
        
        allSchedules.addAll(userSchedules);
      }

      // Sort by date, newest first
      allSchedules.sort((a, b) => b.scheduledDate.compareTo(a.scheduledDate));

      // Update state with all schedules
      if (mounted) {
        setState(() {
          _allSchedules = allSchedules;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading schedules: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(userProvider);
    final botState = ref.watch(botProvider);

    // Filter schedules from local state
    final filteredSchedules = _filterSchedules(_allSchedules);

    // Get field operators only
    final fieldOperators = userState.users
        .where((user) => user.role == 'field_operator')
        .toList();

    return Scaffold(
      appBar: const GlobalAppBar(
        title: 'All Schedules',
        showDrawer: false,
      ),
      body: Column(
        children: [
          // Search and Filter Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(
                bottom: BorderSide(color: AppColors.border),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name, river, or bot...',
                    hintStyle: TextStyle(fontSize: 13),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ],
            ),
          ),

          // Compact Filters
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(
                bottom: BorderSide(color: AppColors.border),
              ),
            ),
            child: Column(
              children: [
                // Status Filter Row
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        value: _selectedStatus,
                        decoration: InputDecoration(
                          labelText: 'Status',
                          labelStyle: TextStyle(fontSize: 12),
                          prefixIcon: const Icon(Icons.filter_list, size: 18),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          isDense: true,
                        ),
                        style: TextStyle(fontSize: 13),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('All Statuses', style: TextStyle(fontSize: 13))),
                          DropdownMenuItem(value: 'scheduled', child: Text('Scheduled', style: TextStyle(fontSize: 13))),
                          DropdownMenuItem(value: 'active', child: Text('Active', style: TextStyle(fontSize: 13))),
                          DropdownMenuItem(value: 'completed', child: Text('Completed', style: TextStyle(fontSize: 13))),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedStatus = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        value: _selectedBotId,
                        decoration: InputDecoration(
                          labelText: 'Bot',
                          labelStyle: TextStyle(fontSize: 12),
                          prefixIcon: const Icon(Icons.directions_boat, size: 18),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          isDense: true,
                        ),
                        style: TextStyle(fontSize: 13),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('All Bots', style: TextStyle(fontSize: 13))),
                          ...botState.bots.map((bot) => DropdownMenuItem(
                                value: bot.id,
                                child: Text(
                                  bot.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 13),
                                ),
                              )),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedBotId = value;
                          });
                        },
                      ),
                    ),
                    if (_selectedStatus != null || _selectedBotId != null || _searchQuery.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _selectedStatus = null;
                            _selectedUserId = null;
                            _selectedBotId = null;
                            _searchQuery = '';
                            _searchController.clear();
                          });
                        },
                        icon: Icon(Icons.clear, size: 20, color: AppColors.error),
                        tooltip: 'Clear filters',
                        padding: EdgeInsets.all(8),
                        constraints: BoxConstraints(),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Compact Results Count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
            ),
            child: Row(
              children: [
                Icon(Icons.list_alt, size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  '${filteredSchedules.length} schedule${filteredSchedules.length == 1 ? '' : 's'}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Schedules List
          Expanded(
            child: _isLoading
                ? const LoadingIndicator(message: 'Loading schedules...')
                : filteredSchedules.isEmpty
                    ? EmptyState(
                        icon: Icons.event_busy,
                        title: 'No Schedules Found',
                        message: _hasActiveFilters()
                            ? 'No schedules match your filters. Try adjusting them.'
                            : 'No schedules found. Field operators will create schedules.',
                      )
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(10),
                          itemCount: filteredSchedules.length,
                          itemBuilder: (context, index) {
                          final schedule = filteredSchedules[index];
                            return ScheduleCard(
                              schedule: schedule,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ScheduleDetailPage(schedule: schedule),
                                  ),
                                );
                              },
                              // Admin is view-only - no edit/delete actions
                              onEdit: null,
                              onCancel: null,
                              onDelete: null,
                              onRecall: null,
                              onViewActions: schedule.isCompleted
                                  ? () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ScheduleDetailPage(schedule: schedule),
                                        ),
                                      );
                                    }
                                  : null,
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  List<ScheduleModel> _filterSchedules(List<ScheduleModel> schedules) {
    return schedules.where((schedule) {
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final matchesSearch = schedule.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (schedule.riverName?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
            (schedule.botName?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
        if (!matchesSearch) return false;
      }

      // Status filter
      if (_selectedStatus != null && schedule.status != _selectedStatus) {
        return false;
      }

      // User filter (need to check who created the schedule)
      if (_selectedUserId != null) {
        // Assuming schedules have ownerAdminId field
        // For field operator schedules, we might need to check assigned_to on bot
        // For now, skip this filter as it requires additional logic
      }

      // Bot filter
      if (_selectedBotId != null && schedule.botId != _selectedBotId) {
        return false;
      }

      return true;
    }).toList();
  }

  bool _hasActiveFilters() {
    return _selectedStatus != null || 
           _selectedUserId != null || 
           _selectedBotId != null || 
           _searchQuery.isNotEmpty;
  }
}
