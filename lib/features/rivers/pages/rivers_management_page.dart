import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/widgets/app_bar.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/theme/color_palette.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/models/river_model.dart';
import '../../../core/models/organization_model.dart';
import '../../../core/providers/river_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/organization_provider.dart';
import '../../../core/utils/snackbar_util.dart';
import '../../../core/utils/river_stats_backfill.dart';
import 'package:intl/intl.dart';
import 'river_details_page.dart';
import 'organization_rivers_page.dart';
import 'archived_rivers_page.dart';
import 'archived_rivers_page.dart';

class RiversManagementPage extends ConsumerStatefulWidget {
  const RiversManagementPage({super.key});

  @override
  ConsumerState<RiversManagementPage> createState() => _RiversManagementPageState();
}

class _RiversManagementPageState extends ConsumerState<RiversManagementPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  final Map<String, Map<String, dynamic>> _riverStats = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentUser = ref.read(authProvider).userProfile;
      if (currentUser != null) {
        ref.read(riverProvider.notifier).loadRivers();
        // Load only organizations created by current admin
        ref.read(organizationProvider.notifier).loadOrganizationsByCreator(currentUser.id);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _getRiverStats(String riverId) async {
    // Check cache first
    if (_riverStats.containsKey(riverId)) {
      return _riverStats[riverId]!;
    }

    try {
      final deploymentsSnapshot = await FirebaseFirestore.instance
          .collection('deployments')
          .where('river_id', isEqualTo: riverId)
          .get();

      final deployments = deploymentsSnapshot.docs;
      final totalDeployments = deployments.length;
      
      double totalTrash = 0.0;
      for (final doc in deployments) {
        final data = doc.data();
        if (data['trash_collection'] != null) {
          final trashData = data['trash_collection'] as Map<String, dynamic>;
          totalTrash += (trashData['total_weight'] ?? 0).toDouble();
        }
      }

      final stats = {
        'totalDeployments': totalDeployments,
        'totalTrashCollected': totalTrash,
      };

      // Cache the stats
      _riverStats[riverId] = stats;
      return stats;
    } catch (e) {
      print('Error fetching river stats: $e');
      return {'totalDeployments': 0, 'totalTrashCollected': 0.0};
    }
  }

  Widget _buildAdminOrganizationView(BuildContext context, RiverState riverState, OrganizationState orgState) {
    // Group rivers by organization
    final Map<String, int> riverCountByOrg = {};
    for (final river in riverState.rivers) {
      final orgId = river.organizationId;
      if (orgId != null) {
        riverCountByOrg[orgId] = (riverCountByOrg[orgId] ?? 0) + 1;
      }
    }

    // Get organizations created by admin (already filtered in provider)
    final adminOrgs = orgState.organizations;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rivers Management'),
      ),
      body: Column(
        children: [
          // Compact header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.2))),
            ),
            child: Row(
              children: [
                Icon(Icons.business_rounded, size: 20, color: AppColors.primary),
                const SizedBox(width: 10),
                Text(
                  'Organizations',
                  style: AppTextStyles.titleSmall.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${adminOrgs.length}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Organizations List (compact cards)
          Expanded(
            child: orgState.isLoading
                ? const LoadingIndicator(message: 'Loading...')
                : adminOrgs.isEmpty
                    ? const EmptyState(
                        icon: Icons.business_outlined,
                        title: 'No Organizations',
                        message: 'Create an organization to manage rivers.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: adminOrgs.length,
                        itemBuilder: (context, index) {
                          final org = adminOrgs[index];
                          final riverCount = riverCountByOrg[org.id] ?? 0;
                          return _buildCompactOrganizationCard(org, riverCount);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactOrganizationCard(OrganizationModel org, int riverCount) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: AppColors.border.withValues(alpha: 0.2)),
        ),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => OrganizationRiversPage(organization: org),
              ),
            );
          },
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Simple icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.business_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),

                // Organization info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        org.name,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (org.description.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          org.description,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.water, size: 14, color: AppColors.info),
                          const SizedBox(width: 4),
                          Text(
                            '$riverCount ${riverCount == 1 ? 'river' : 'rivers'}',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.info,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios,
                  color: AppColors.textMuted,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final riverState = ref.watch(riverProvider);
    final authState = ref.watch(authProvider);
    final orgState = ref.watch(organizationProvider);
    final isAdmin = authState.userProfile?.isAdmin ?? false;

    // If admin, show organization cards view instead
    if (isAdmin) {
      return _buildAdminOrganizationView(context, riverState, orgState);
    }

    // Field operator view: Filter rivers by search query and exclude archived
    final filteredRivers = riverState.rivers.where((river) {
      if (river.isArchived) return false;
      final matchesSearch = river.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (river.description?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      return matchesSearch;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rivers Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.archive_outlined),
            tooltip: 'Archived Rivers',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ArchivedRiversPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Compact search bar
          Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.15))),
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search rivers...',
                hintStyle: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
                prefixIcon: Icon(Icons.search, size: 20, color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.primary, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              style: AppTextStyles.bodyMedium.copyWith(fontSize: 13),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          const Divider(height: 1),

          // Rivers List
          Expanded(
            child: riverState.isLoading
                ? const LoadingIndicator(message: 'Loading rivers...')
                : filteredRivers.isEmpty
                    ? EmptyState(
                        icon: Icons.water,
                        title: 'No Rivers Found',
                        message: _searchQuery.isEmpty
                            ? 'No rivers found. Create your first river.'
                            : 'No rivers match your search.',
                        actionLabel: 'Add River',
                        onAction: () => _showAddRiverDialog(context),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredRivers.length,
                        itemBuilder: (context, index) {
                          final river = filteredRivers[index];
                          return _buildRiverCard(river);
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddRiverDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add River'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Widget _buildRiverCard(RiverModel river) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppColors.border.withValues(alpha: 0.2)),
        ),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RiverDetailsPage(river: river),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with icon and name
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.water_rounded, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            river.name,
                            style: AppTextStyles.bodyLarge.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          if (river.description != null && river.description!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              river.description!,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 10),
                Divider(height: 1, color: AppColors.border.withValues(alpha: 0.2)),
                const SizedBox(height: 10),

                // Statistics with FutureBuilder
                FutureBuilder<Map<String, dynamic>>(
                  future: _getRiverStats(river.id),
                  builder: (context, snapshot) {
                    final stats = snapshot.data ?? {'totalDeployments': 0, 'totalTrashCollected': 0.0};
                    final totalDeployments = stats['totalDeployments'] as int;
                    final totalTrash = stats['totalTrashCollected'] as double;

                    return Row(
                      children: [
                        Expanded(
                          child: _buildInlineStat(
                            Icons.event_rounded,
                            '$totalDeployments',
                            'Deployments',
                            Colors.blue,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 24,
                          color: AppColors.border.withValues(alpha: 0.2),
                        ),
                        Expanded(
                          child: _buildInlineStat(
                            Icons.delete_sweep_rounded,
                            '${totalTrash.toStringAsFixed(1)} kg',
                            'Trash',
                            Colors.green,
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 10),
                Divider(height: 1, color: AppColors.border.withValues(alpha: 0.2)),
                const SizedBox(height: 10),
                
                // Footer with last deployment and actions
                Row(
                  children: [
                    Expanded(
                      child: river.lastDeployment != null
                          ? Row(
                              children: [
                                Icon(Icons.schedule_rounded, size: 12, color: AppColors.textMuted),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Last: ${DateFormat('MMM d').format(river.lastDeployment!)}',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.textMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                Icon(Icons.info_outline, size: 12, color: AppColors.textMuted),
                                const SizedBox(width: 4),
                                Text(
                                  'No deployments',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                    ),
                    _buildIconButton(
                      Icons.edit_outlined,
                      () => _showEditRiverDialog(context, river),
                      AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    _buildIconButton(
                      Icons.archive_outlined,
                      () => _showArchiveConfirmation(context, river),
                      Colors.orange,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInlineStat(IconData icon, String value, String label, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 14,
              ),
            ),
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onPressed, Color color) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }

  void _showAddRiverDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add River'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'River Name *',
                hintText: 'e.g., Pasig River',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                hintText: 'Brief description...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                SnackbarUtil.showError(context, 'Please enter a river name');
                return;
              }

              final currentUser = ref.read(authProvider).userProfile;
              if (currentUser == null) return;

              final river = RiverModel(
                id: '',
                name: nameController.text.trim(),
                description: descriptionController.text.trim().isEmpty
                    ? null
                    : descriptionController.text.trim(),
                ownerAdminId: currentUser.id,
                organizationId: currentUser.organizationId,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );

              try {
                final riverId = await ref.read(riverProvider.notifier).createRiverByName(
                  nameController.text.trim(),
                  description: descriptionController.text.trim(),
                );
                if (riverId != null && context.mounted) {
                  Navigator.pop(context);
                  SnackbarUtil.showSuccess(context, 'River added successfully');
                }
              } catch (e) {
                if (context.mounted) {
                  SnackbarUtil.showError(context, 'Failed to add river: $e');
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditRiverDialog(BuildContext context, RiverModel river) {
    final nameController = TextEditingController(text: river.name);
    final descriptionController = TextEditingController(text: river.description ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit River'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'River Name *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                SnackbarUtil.showError(context, 'Please enter a river name');
                return;
              }

              try {
                await ref.read(riverProvider.notifier).updateRiver(river.id, {
                  'name': nameController.text.trim(),
                  'description': descriptionController.text.trim().isEmpty
                      ? null
                      : descriptionController.text.trim(),
                });
                if (context.mounted) {
                  Navigator.pop(context);
                  SnackbarUtil.showSuccess(context, 'River updated successfully');
                }
              } catch (e) {
                if (context.mounted) {
                  SnackbarUtil.showError(context, 'Failed to update river: $e');
                }
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showArchiveConfirmation(BuildContext context, RiverModel river) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive River'),
        content: Text('Are you sure you want to archive "${river.name}"? You can restore it later from the archived rivers page.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await ref.read(riverProvider.notifier).updateRiver(river.id, {
                  'is_archived': true,
                });
                if (context.mounted) {
                  Navigator.pop(context);
                  SnackbarUtil.showSuccess(context, 'River archived successfully');
                }
              } catch (e) {
                if (context.mounted) {
                  SnackbarUtil.showError(context, 'Failed to archive river: $e');
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
  }

  Future<void> _recalculateRiverStats(BuildContext context) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recalculate Statistics'),
        content: const Text(
          'This will recalculate total deployments and trash collected for all rivers based on existing deployment records. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Recalculate'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Recalculating statistics...'),
                ],
              ),
            ),
          ),
        ),
      );

      try {
        await RiverStatsBackfill.recalculateAllRiverStats();
        
        if (context.mounted) {
          Navigator.pop(context); // Close loading dialog
          SnackbarUtil.showSuccess(context, 'River statistics updated successfully');
          
          // Reload rivers to show updated stats
          ref.read(riverProvider.notifier).loadRivers();
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.pop(context); // Close loading dialog
          SnackbarUtil.showError(context, 'Failed to recalculate statistics: $e');
        }
      }
    }
  }
}
