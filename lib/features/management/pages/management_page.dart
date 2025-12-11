import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/color_palette.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/snackbar_util.dart';
import '../../../core/models/user_model.dart';
import '../../../core/models/organization_model.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/providers/organization_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/bot_provider.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../shared/widgets/search_bar.dart' as CustomSearchBar;
import 'organization_details_page.dart';
import 'user_details_page.dart';

class ManagementPage extends ConsumerStatefulWidget {
  const ManagementPage({super.key});

  @override
  ConsumerState<ManagementPage> createState() => _ManagementPageState();
}

class _ManagementPageState extends ConsumerState<ManagementPage> with TickerProviderStateMixin {
  late TabController _tabController;
  final _usersSearchController = TextEditingController();
  String _selectedUsersFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Load data when page initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }
  
  void _loadData() {
    final authState = ref.read(authProvider);
    final currentUser = authState.userProfile;
    
    if (currentUser != null) {
      // Load users created by current admin
      ref.read(userProvider.notifier).loadUsersByCreator(currentUser.id);
      
      // Load organizations created by current admin  
      ref.read(organizationProvider.notifier).loadOrganizationsByCreator(currentUser.id);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _usersSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tab Bar
        Container(
          height: 44,
          margin: const EdgeInsets.symmetric(horizontal: 16),
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
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            labelColor: Colors.white,
            unselectedLabelColor: AppColors.textSecondary,
            dividerColor: Colors.transparent,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            splashFactory: NoSplash.splashFactory,
            overlayColor: WidgetStateProperty.all(Colors.transparent),
            tabs: const [
              Tab(text: 'Users'),
              Tab(text: 'Organizations'),
            ],
          ),
        ),
        
        // Tab Views
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildUsersTab(),
              _buildOrganizationsTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUsersTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
          
          // Quick Actions
          _buildUsersQuickActions(),
          const SizedBox(height: 24),
          
          // Search Bar
          CustomSearchBar.SearchBar(
            controller: _usersSearchController,
            hint: 'Search users...',
            onChanged: (value) {
              setState(() {
                // Trigger rebuild to filter users
              });
            },
          ),
          const SizedBox(height: 16),
          
          // Filters
          _buildUsersFilters(),
          const SizedBox(height: 16),
          
          // Users List Label
          Text(
            'Users',
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          
          // Users List
          Expanded(
            child: _buildUsersList(),
          ),
        ],
      ),
    );
  }

  Widget _buildOrganizationsTab() {
    final orgState = ref.watch(organizationProvider);
    final hasOrganization = orgState.organizations.isNotEmpty;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick Actions (includes label) - only shown when no organization
          _buildOrgsQuickActions(),
          
          // Organization Statistics - only shown when organization exists
          if (hasOrganization) _buildOrganizationStats(),
          if (hasOrganization) const SizedBox(height: 24),
          
          // Organizations List Label
          Text(
            'My Organization',
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          
          // Organizations List - Now properly scrollable
          Expanded(
            child: _buildOrganizationsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersQuickActions() {
    return Container(
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
              icon: Icons.person_add,
              label: 'Add User',
              onPressed: () {
                Navigator.pushNamed(context, '/add-user');
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildQuickActionButton(
              icon: Icons.archive,
              label: 'Archived',
              onPressed: () {
                setState(() {
                  _selectedUsersFilter = 'archived';
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrgsQuickActions() {
    final orgState = ref.watch(organizationProvider);
    final hasOrganization = orgState.organizations.isNotEmpty;
    
    // If admin already has an organization, don't show anything
    if (hasOrganization) {
      return const SizedBox.shrink();
    }
    
    // Show both label and button only when no organization exists
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
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
                  icon: Icons.business,
                  label: 'Add Organization',
                  onPressed: () {
                    Navigator.pushNamed(context, '/add-organization');
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.background, AppColors.surface.withValues(alpha: 0.5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.w500,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersFilters() {
    return Container(
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
          Expanded(child: _buildFilterTab('All', 'all', _selectedUsersFilter, (filter) {
            setState(() {
              _selectedUsersFilter = filter;
            });
          })),
          Expanded(child: _buildFilterTab('Active', 'active', _selectedUsersFilter, (filter) {
            setState(() {
              _selectedUsersFilter = filter;
            });
          })),
          Expanded(child: _buildFilterTab('Inactive', 'inactive', _selectedUsersFilter, (filter) {
            setState(() {
              _selectedUsersFilter = filter;
            });
          })),
          Expanded(child: _buildFilterTab('Archived', 'archived', _selectedUsersFilter, (filter) {
            setState(() {
              _selectedUsersFilter = filter;
            });
          })),
        ],
      ),
    );
  }


  Widget _buildFilterTab(String label, String value, String selectedFilter, Function(String) onTap) {
    final isSelected = selectedFilter == value;
    return GestureDetector(
      onTap: () => onTap(value),
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

  Widget _buildUsersList() {
    final userState = ref.watch(userProvider);
    
    if (userState.isLoading) {
      return const Center(child: LoadingIndicator());
    }
    
    if (userState.error != null) {
      return ErrorState(
        error: userState.error!,
        onRetry: _loadData,
      );
    }
    
    final filteredUsers = _filterUsers(userState.users);
    
    if (filteredUsers.isEmpty) {
      return const EmptyState(
        icon: Icons.people,
        title: 'No Users Found',
        message: 'There are no users matching your criteria.',
      );
    }
    
    return ListView.builder(
      itemCount: filteredUsers.length,
      itemBuilder: (context, index) {
        final user = filteredUsers[index];
        return _buildUserCard(user);
      },
    );
  }

  Widget _buildUserCard(UserModel user) {
    final bool isArchived = _selectedUsersFilter == 'archived';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shadowColor: AppColors.primary.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border.withValues(alpha: 0.3)),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, AppColors.surface.withValues(alpha: 0.3)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Info Row
              Row(
                children: [
                  // Avatar
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      backgroundColor: Colors.transparent,
                      radius: 20,
                      child: Text(
                        user.firstName.isNotEmpty ? user.firstName[0].toUpperCase() : 'U',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // User Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.fullName,
                          style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user.email,
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              _formatRole(user.role),
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: _getStatusColors(user.status),
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _getStatusBorderColor(user.status),
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                _formatStatus(user.status),
                                style: TextStyle(
                                  color: _getStatusTextColor(user.status),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: _buildUserActionButton(
                      icon: Icons.visibility,
                      label: 'View',
                      onPressed: () => _viewUser(user),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildUserActionButton(
                      icon: Icons.edit,
                      label: 'Edit',
                      onPressed: () => _editUser(user),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (isArchived)
                    Expanded(
                      child: _buildUserActionButton(
                        icon: Icons.restore,
                        label: 'Restore',
                        onPressed: () => _restoreUser(user),
                        color: Colors.green,
                      ),
                    )
                  else ...[
                    Expanded(
                      child: _buildUserActionButton(
                        icon: user.status == 'active' ? Icons.person_off : Icons.person,
                        label: user.status == 'active' ? 'Deactivate' : 'Activate',
                        onPressed: () => _toggleUserStatus(user),
                        color: user.status == 'active' ? Colors.orange : Colors.green,
                      ),
                    ),
                    if (user.status == 'inactive') ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildUserActionButton(
                          icon: Icons.archive,
                          label: 'Archive',
                          onPressed: () => _archiveUser(user),
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color? color,
  }) {
    final buttonColor = color ?? AppColors.primary;
    
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        side: BorderSide(color: buttonColor.withValues(alpha: 0.3)),
        backgroundColor: buttonColor.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: buttonColor),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: buttonColor,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatRole(String role) {
    switch (role) {
      case 'field_operator':
        return 'Field Operator';
      case 'admin':
        return 'Administrator';
      default:
        return role.replaceAll('_', ' ').split(' ')
            .map((word) => word.isNotEmpty 
                ? word[0].toUpperCase() + word.substring(1).toLowerCase() 
                : '')
            .join(' ');
    }
  }

  String _formatStatus(String status) {
    switch (status) {
      case 'active':
        return 'ACTIVE';
      case 'inactive':
        return 'INACTIVE';
      case 'archived':
        return 'ARCHIVED';
      default:
        return status.toUpperCase();
    }
  }

  List<Color> _getStatusColors(String status) {
    switch (status) {
      case 'active':
        return [Colors.green.shade100, Colors.green.shade50];
      case 'inactive':
        return [Colors.orange.shade100, Colors.orange.shade50];
      case 'archived':
        return [Colors.red.shade100, Colors.red.shade50];
      default:
        return [Colors.grey.shade100, Colors.grey.shade50];
    }
  }

  Color _getStatusBorderColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green.shade200;
      case 'inactive':
        return Colors.orange.shade200;
      case 'archived':
        return Colors.red.shade200;
      default:
        return Colors.grey.shade200;
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green.shade800;
      case 'inactive':
        return Colors.orange.shade800;
      case 'archived':
        return Colors.red.shade800;
      default:
        return Colors.grey.shade800;
    }
  }

  void _viewUser(UserModel user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserDetailsPage(user: user),
      ),
    );
  }

  void _editUser(UserModel user) {
    Navigator.pushNamed(
      context,
      '/edit-user',
      arguments: user,
    );
  }

  void _toggleUserStatus(UserModel user) {
    final newStatus = user.status == 'active' ? 'inactive' : 'active';
    final action = newStatus == 'active' ? 'activate' : 'deactivate';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${action[0].toUpperCase()}${action.substring(1)} User'),
        content: Text('Are you sure you want to $action "${user.fullName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final userService = ref.read(userServiceProvider);
                
                await userService.update(user.id, {
                  'status': newStatus,
                  'updated_at': DateTime.now(),
                });
                
                final currentUser = ref.read(authProvider).userProfile;
                if (currentUser != null) {
                  ref.read(userProvider.notifier).loadUsersByCreator(currentUser.id);
                }
                
                if (mounted) {
                  SnackbarUtil.showSuccess(
                    context, 
                    'User ${newStatus == 'active' ? 'activated' : 'deactivated'} successfully'
                  );
                }
              } catch (e) {
                if (mounted) {
                  SnackbarUtil.showError(context, 'Failed to update user status');
                }
              }
            },
            child: Text(
              action[0].toUpperCase() + action.substring(1),
              style: TextStyle(
                color: newStatus == 'active' ? Colors.green : Colors.orange,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _archiveUser(UserModel user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive User'),
        content: Text('Are you sure you want to archive "${user.fullName}"? This user will no longer be able to access the system.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final userService = ref.read(userServiceProvider);
                
                await userService.update(user.id, {
                  'status': 'archived',
                  'updated_at': DateTime.now(),
                });
                
                final currentUser = ref.read(authProvider).userProfile;
                if (currentUser != null) {
                  ref.read(userProvider.notifier).loadUsersByCreator(currentUser.id);
                }
                
                if (mounted) {
                  SnackbarUtil.showSuccess(context, 'User archived successfully');
                }
              } catch (e) {
                if (mounted) {
                  SnackbarUtil.showError(context, 'Failed to archive user');
                }
              }
            },
            child: const Text('Archive', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _restoreUser(UserModel user) async {
    try {
      final userService = ref.read(userServiceProvider);
      
      await userService.update(user.id, {
        'status': 'active',
        'updated_at': DateTime.now(),
      });
      
      final currentUser = ref.read(authProvider).userProfile;
      if (currentUser != null) {
        ref.read(userProvider.notifier).loadUsersByCreator(currentUser.id);
      }
      
      SnackbarUtil.showSuccess(context, 'User restored successfully');
    } catch (e) {
      SnackbarUtil.showError(context, 'Failed to restore user');
    }
  }

  Widget _buildOrganizationsList() {
    final orgState = ref.watch(organizationProvider);
    final botState = ref.watch(botProvider);
    
    if (orgState.isLoading) {
      return const Center(child: LoadingIndicator());
    }
    
    if (orgState.error != null) {
      return ErrorState(
        error: orgState.error!,
        onRetry: _loadData,
      );
    }
    
    final filteredOrgs = orgState.organizations; // No filtering needed for single org
    
    if (filteredOrgs.isEmpty) {
      return const EmptyState(
        icon: Icons.business,
        title: 'No Organization Found',
        message: 'You haven\'t created an organization yet.',
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16), // Add bottom padding
      physics: const AlwaysScrollableScrollPhysics(), // Ensure it's always scrollable
      itemCount: filteredOrgs.length,
      itemBuilder: (context, index) {
        final org = filteredOrgs[index];
        
        // Count actual bots from botProvider
        final orgBotCount = botState.bots.where((bot) => 
          bot.organizationId == org.id
        ).length;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 2,
          shadowColor: AppColors.primary.withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppColors.border.withValues(alpha: 0.3)),
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white, AppColors.surface.withValues(alpha: 0.3)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Organization Info Row
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.7)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const CircleAvatar(
                          backgroundColor: Colors.transparent,
                          radius: 20,
                          child: Icon(Icons.business, color: Colors.white, size: 20),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              org.name,
                              style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$orgBotCount bots assigned',
                              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: org.status == 'active' 
                                ? [Colors.green.shade100, Colors.green.shade50]
                                : [Colors.red.shade100, Colors.red.shade50],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: org.status == 'active' 
                                ? Colors.green.shade200
                                : Colors.red.shade200,
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          org.status.toUpperCase(),
                          style: TextStyle(
                            color: org.status == 'active' ? Colors.green.shade800 : Colors.red.shade800,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: _buildOrgActionButton(
                          icon: Icons.visibility,
                          label: 'View',
                          onPressed: () => _navigateToOrganizationDetails(org),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildOrgActionButton(
                          icon: Icons.edit,
                          label: 'Edit',
                          onPressed: () => _editOrganization(org),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildOrgActionButton(
                          icon: Icons.delete,
                          label: 'Delete',
                          onPressed: () => _deleteOrganization(org),
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<dynamic> _filterUsers(List<dynamic> users) {
    final currentUser = ref.read(authProvider).userProfile;
    if (currentUser == null) return [];
    
    List<dynamic> filtered = users;
    
    // IMPORTANT: Only show field operators created by the current admin
    // Do NOT show:
    // - Other administrators
    // - Field operators created by other admins
    filtered = filtered.where((user) {
      // Must be a field operator
      final isFieldOperator = user.role == 'field_operator';
      // Must be created by the current logged-in admin
      final createdByCurrentAdmin = user.createdBy == currentUser.id;
      
      return isFieldOperator && createdByCurrentAdmin;
    }).toList();
    
    // Filter by status
    if (_selectedUsersFilter != 'all') {
      filtered = filtered.where((user) => user.status == _selectedUsersFilter).toList();
    }
    
    // Filter by search
    final searchTerm = _usersSearchController.text.toLowerCase();
    if (searchTerm.isNotEmpty) {
      filtered = filtered.where((user) {
        return user.fullName.toLowerCase().contains(searchTerm) ||
               user.email.toLowerCase().contains(searchTerm);
      }).toList();
    }
    
    return filtered;
  }


  Widget _buildOrganizationStats() {
    final orgState = ref.watch(organizationProvider);
    final botState = ref.watch(botProvider);
    final userState = ref.watch(userProvider);
    
    if (orgState.isLoading || orgState.organizations.isEmpty) {
      return const SizedBox.shrink();
    }

    final organization = orgState.organizations.first; // Admin can only have one organization
    
    // Count total bots under this organization
    final totalBots = botState.bots.where((bot) => 
      bot.organizationId == organization.id
    ).length;
    
    // Count total members (users) under this organization
    final totalMembers = userState.users.where((user) => 
      user.organizationId == organization.id
    ).length;
    
    // Calculate total trash collected (mock for now - would come from deployment history)
    // This would be calculated from all deployment records for bots in this organization
    final totalTrashCollected = 0.0; // TODO: Calculate from deployment history

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary.withValues(alpha: 0.1), AppColors.primary.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.analytics,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Organization Overview',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Total Trash Collected',
                  '${totalTrashCollected.toStringAsFixed(1)} kg',
                  Icons.delete_outline,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatItem(
                  'Total Bots',
                  totalBots.toString(),
                  Icons.directions_boat,
                  AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatItem(
                  'Total Members',
                  totalMembers.toString(),
                  Icons.people,
                  Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textMuted,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildOrgActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color? color,
  }) {
    final buttonColor = color ?? AppColors.primary;
    
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        side: BorderSide(color: buttonColor.withValues(alpha: 0.3)),
        backgroundColor: buttonColor.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: buttonColor),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: buttonColor,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToOrganizationDetails(OrganizationModel organization) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrganizationDetailsPage(organization: organization),
      ),
    );
  }

  void _editOrganization(OrganizationModel org) {
    Navigator.pushNamed(
      context,
      '/edit-organization',
      arguments: org,
    );
  }

  void _deleteOrganization(OrganizationModel org) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Organization'),
        content: Text(
          'Are you sure you want to delete "${org.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final orgService = ref.read(organizationServiceProvider);
        await orgService.delete(org.id);
        
        final currentUser = ref.read(authProvider).userProfile;
        if (currentUser != null) {
          ref.read(organizationProvider.notifier).loadOrganizationsByCreator(currentUser.id);
        }
        
        if (mounted) {
          SnackbarUtil.showSuccess(context, 'Organization deleted successfully');
        }
      } catch (e) {
        if (mounted) {
          SnackbarUtil.showError(context, 'Failed to delete organization: $e');
        }
      }
    }
  }
}
