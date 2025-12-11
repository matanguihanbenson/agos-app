import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/app_bar.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/theme/color_palette.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/models/organization_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/user_provider.dart';
import '../../../shared/widgets/search_bar.dart' as CustomSearchBar;

class OrganizationDetailsPage extends ConsumerStatefulWidget {
  final OrganizationModel organization;

  const OrganizationDetailsPage({
    super.key,
    required this.organization,
  });

  @override
  ConsumerState<OrganizationDetailsPage> createState() => _OrganizationDetailsPageState();
}

class _OrganizationDetailsPageState extends ConsumerState<OrganizationDetailsPage>
  with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    // Load members data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(userProvider.notifier).loadUsers();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GlobalAppBar(
        title: widget.organization.name,
        showDrawer: false,
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: CustomSearchBar.SearchBar(
              controller: _searchController,
              hint: 'Search members...',
              onChanged: (value) {
                setState(() {});
              },
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Filters
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildFilters(),
          ),
          
          const SizedBox(height: 12),
          
          // Members Content
          Expanded(
            child: _buildMembersTab(),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton.extended(
      onPressed: _showAddMemberDialog,
      icon: const Icon(Icons.person_add_outlined),
      label: const Text('Add Member'),
      backgroundColor: AppColors.primary,
    );
  }

  Widget _buildFilters() {
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
          Expanded(child: _buildFilterTab('All', 'all')),
          Expanded(child: _buildFilterTab('Active', 'active')),
          Expanded(child: _buildFilterTab('Inactive', 'inactive')),
        ],
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
            style: AppTextStyles.bodyMedium.copyWith(
              color: isSelected ? Colors.white : AppColors.textSecondary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMembersTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Members List',
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(child: _buildMembersList()),
        ],
      ),
    );
  }

  Widget _buildMembersList() {
    final userState = ref.watch(userProvider);
    
    if (userState.isLoading) {
      return const Center(child: LoadingIndicator());
    }
    
    if (userState.error != null) {
      return ErrorState(
        error: userState.error!,
        onRetry: () {
          // Retry by reloading members
          ref.read(userProvider.notifier).loadUsers();
        },
      );
    }
    
    final organizationMembers = _filterUsers(userState.users.where((user) => 
        user.organizationId == widget.organization.id).toList());
    
    if (organizationMembers.isEmpty) {
      return _buildCompactEmptyState(
        icon: Icons.people,
        title: 'No Members Found',
        message: 'This organization has no members assigned.',
      );
    }
    
    return ListView.builder(
      itemCount: organizationMembers.length,
      itemBuilder: (context, index) {
        final user = organizationMembers[index];
        return _buildMemberCard(user);
      },
    );
  }

  Widget _buildMemberCard(UserModel user) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shadowColor: AppColors.primary.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary,
          child: Text(
            user.firstName.isNotEmpty ? user.firstName[0].toUpperCase() : 'U',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          user.fullName,
          style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${user.email} • ${_formatRole(user.role)}',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: user.status == 'active' ? Colors.green.shade100 : Colors.red.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                user.status.toUpperCase(),
                style: TextStyle(
                  color: user.status == 'active' ? Colors.green.shade800 : Colors.red.shade800,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.person_remove_outlined, color: Colors.red),
              onPressed: () => _removeMemberFromOrganization(user),
              tooltip: 'Remove from organization',
            ),
          ],
        ),
      ),
    );
  }

  void _removeMemberFromOrganization(UserModel user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text('Are you sure you want to remove "${user.fullName}" from this organization?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              // Update user to remove organization assignment
              final userService = ref.read(userServiceProvider);
              final updatedUser = user.copyWith(organizationId: '');
              await userService.update(user.id, updatedUser.toMap());
              
              // Refresh the list
              await ref.read(userProvider.notifier).loadUsers();
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  List<UserModel> _filterUsers(List<UserModel> users) {
    List<UserModel> filtered = users;
    
    // Filter by status
    if (_selectedFilter != 'all') {
      filtered = filtered.where((user) => user.status == _selectedFilter).toList();
    }
    
    // Filter by search
    final searchTerm = _searchController.text.toLowerCase();
    if (searchTerm.isNotEmpty) {
      filtered = filtered.where((user) {
        return user.fullName.toLowerCase().contains(searchTerm) ||
               user.email.toLowerCase().contains(searchTerm);
      }).toList();
    }
    
    return filtered;
  }

  void _showAddMemberDialog() {
    final authState = ref.read(authProvider);
    final currentUser = authState.userProfile;
    final userState = ref.read(userProvider);

    // Start from all loaded users
    List<UserModel> availableUsers = List<UserModel>.from(userState.users);

    // If we have a current admin, limit to users they created
    if (currentUser != null) {
      availableUsers = availableUsers
          .where((user) => user.createdBy == currentUser.id)
          .toList();
    }

    // Exclude users already in this organization
    availableUsers = availableUsers
        .where((user) => user.organizationId != widget.organization.id)
        .toList();

    showDialog(
      context: context,
      builder: (dialogContext) {
        if (availableUsers.isEmpty) {
          return AlertDialog(
            title: const Text('Add Member'),
            content: const Text(
              'There are no available users created by you that can be added as members.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        }

        String? selectedUserId;
        bool isSaving = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add Member'),
              content: SizedBox(
                width: double.maxFinite,
                height: 300,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select a user to add to this organization:',
                      style: AppTextStyles.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        itemCount: availableUsers.length,
                        itemBuilder: (context, index) {
                          final user = availableUsers[index];
                          final isSelected = selectedUserId == user.id;

                          return ListTile(
                            title: Text(user.fullName),
                            subtitle: Text(user.email),
                            trailing: isSelected
                                ? const Icon(Icons.check, color: AppColors.primary)
                                : null,
                            selected: isSelected,
                            onTap: () {
                              setState(() {
                                selectedUserId = user.id;
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: selectedUserId != null && !isSaving
                      ? () async {
                          setState(() {
                            isSaving = true;
                          });

                          try {
                            await ref
                                .read(userProvider.notifier)
                                .assignUserToOrganization(
                                  selectedUserId!,
                                  widget.organization.id,
                                );

                            if (mounted) {
                              Navigator.of(dialogContext).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Member added to organization'),
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to add member: $e'),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          } finally {
                            if (mounted) {
                              setState(() {
                                isSaving = false;
                              });
                            }
                          }
                        }
                      : null,
                  child: isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Add Member'),
                ),
              ],
            );
          },
        );
      },
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

  Widget _buildCompactEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 32,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: AppTextStyles.titleSmall.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              message,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
