import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/models/bot_model.dart';
import '../../../core/theme/color_palette.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/providers/bot_provider.dart';
import '../providers/bot_list_provider.dart';
import '../widgets/bot_card.dart';
import '../widgets/unregister_dialog.dart';

class BotsPage extends ConsumerStatefulWidget {
  const BotsPage({super.key});

  @override
  ConsumerState<BotsPage> createState() => _BotsPageState();
}

class _BotsPageState extends ConsumerState<BotsPage> {
  String _selectedFilter = 'all';
  final _searchController = TextEditingController();
  List<BotModel> _filteredBots = [];

  @override
  void initState() {
    super.initState();
    // No need to load - using real-time stream
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterBots(List<BotModel> bots) {
    setState(() {
      _filteredBots = bots.where((bot) {
        // Normalize status from RTDB
        final botStatus = (bot.status?.toLowerCase() ?? 'idle');
        final isDeployedLike = botStatus == 'deployed' || botStatus == 'active' || botStatus == 'scheduled';
        bool statusMatch = _selectedFilter == 'all' || 
            (_selectedFilter == 'deployed' && isDeployedLike) ||
            (_selectedFilter == 'idle' && botStatus == 'idle') ||
            (_selectedFilter == 'maintenance' && botStatus == 'maintenance');
        
        // Filter by search term
        bool searchMatch = _searchController.text.isEmpty ||
            bot.name.toLowerCase().contains(_searchController.text.toLowerCase()) ||
            bot.id.toLowerCase().contains(_searchController.text.toLowerCase());
        
        return statusMatch && searchMatch;
      }).toList();
    });
  }


  void _showUnregisterDialog(BotModel bot) {
    showDialog(
      context: context,
      builder: (context) => UnregisterDialog(
        bot: bot,
        onUnregistered: () {
          ref.read(botListProvider.notifier).loadBots();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final botsAsync = ref.watch(botsStreamProvider);

    return botsAsync.when(
      data: (bots) => _buildBotsView(bots),
      loading: () => const Scaffold(
        body: LoadingIndicator(message: 'Loading bots...'),
      ),
      error: (error, _) => Scaffold(
        body: ErrorState(
          error: error.toString(),
          onRetry: () => ref.invalidate(botsStreamProvider),
        ),
      ),
    );
  }

  Widget _buildBotsView(List<BotModel> bots) {
    // Filter bots on initial render
    if (_filteredBots.isEmpty && bots.isNotEmpty) {
      _filterBots(bots);
    }
    
    // Re-filter when bots change
    _filterBots(bots);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Quick Actions Label
          Text(
            'Quick Actions',
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          
        // Quick Actions Section
        Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.surface, AppColors.surface.withValues(alpha: 0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border.withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildQuickActionButton(
                      icon: Icons.add,
                      label: 'Register',
                      onPressed: () => Navigator.pushNamed(context, '/bot-registration'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildQuickActionButton(
                      icon: Icons.assignment,
                      label: 'Assign',
                      onPressed: () => Navigator.pushNamed(context, '/assign-bot'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildQuickActionButton(
                      icon: Icons.swap_horiz,
                      label: 'Reassign',
                      onPressed: () => Navigator.pushNamed(context, '/reassign-bot'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildQuickActionButton(
                      icon: Icons.remove_circle,
                      label: 'Unregister',
                      onPressed: () => Navigator.pushNamed(context, '/unregister-bot'),
                      isDestructive: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Search Section
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search bots...',
                prefixIcon: const Icon(Icons.search, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.primary),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (_) {
                if (bots.isNotEmpty) {
                  _filterBots(bots);
                }
              },
            ),
            const SizedBox(height: 16),
            
            // Filter Tabs
            Container(
              height: 44,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.background, AppColors.surface],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border.withValues(alpha: 0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(child: _buildFilterTab('All', 'all')),
                  Expanded(child: _buildFilterTab('Deployed', 'deployed')),
                  Expanded(child: _buildFilterTab('Idle', 'idle')),
                  Expanded(child: _buildFilterTab('Maintenance', 'maintenance')),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Bots List Label
            Text(
              'My Bots',
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            
            // Bot List
            Expanded(
              child: _filteredBots.isEmpty
                  ? (bots.isEmpty
                      ? const EmptyState(
                          icon: Icons.directions_boat,
                          title: 'No Bots Found',
                          message: 'You haven\'t registered any bots yet. Add your first bot to get started.',
                          actionLabel: 'Register Bot',
                        )
                      : _buildCustomEmptyState())
                  : ListView.builder(
                      itemCount: _filteredBots.length,
                      itemBuilder: (context, index) {
                        final bot = _filteredBots[index];
                        return BotCard(
                          bot: bot,
                          onTap: () {
                            // Navigate to bot details
                            Navigator.pushNamed(
                              context,
                              '/bot-view',
                              arguments: bot,
                            );
                          },
                          onEdit: () {
                            // TODO: Implement edit bot functionality
                          },
                          onDelete: () => _showUnregisterDialog(bot),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: Colors.transparent,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isDestructive ? AppColors.error : AppColors.textSecondary,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDestructive ? AppColors.error : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTab(String label, String value) {
    final isSelected = _selectedFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = value;
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          gradient: isSelected 
              ? LinearGradient(
                  colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected 
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? AppColors.surface : AppColors.textSecondary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomEmptyState() {
    switch (_selectedFilter) {
      case 'deployed':
        return const EmptyState(
          icon: Icons.rocket_launch,
          title: 'No Deployed Bots',
          message: 'You have no bots currently deployed in the field. Deploy some bots to start monitoring.',
        );
      case 'idle':
        return const EmptyState(
          icon: Icons.pause_circle,
          title: 'No Idle Bots',
          message: 'All your bots are either deployed or in maintenance. Great job keeping them active!',
        );
      case 'maintenance':
        return const EmptyState(
          icon: Icons.build,
          title: 'No Bots in Maintenance',
          message: 'None of your bots are currently under maintenance. All systems running smoothly!',
        );
      default:
        if (_searchController.text.isNotEmpty) {
          return EmptyState(
            icon: Icons.search_off,
            title: 'No Search Results',
            message: 'No bots found matching "${_searchController.text}". Try a different search term.',
          );
        } else {
          return const EmptyState(
            icon: Icons.directions_boat,
            title: 'No Bots Found',
            message: 'You haven\'t registered any bots yet. Add your first bot to get started.',
          );
        }
    }
  }

}
