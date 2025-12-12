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
import '../../../core/utils/snackbar_util.dart';
import 'package:intl/intl.dart';
import 'river_details_page.dart';

class OrganizationRiversPage extends ConsumerStatefulWidget {
  final OrganizationModel organization;

  const OrganizationRiversPage({
    super.key,
    required this.organization,
  });

  @override
  ConsumerState<OrganizationRiversPage> createState() => _OrganizationRiversPageState();
}

class _OrganizationRiversPageState extends ConsumerState<OrganizationRiversPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  // Simple in-memory cache to avoid re-querying stats repeatedly
  final Map<String, Map<String, dynamic>> _riverStats = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(riverProvider.notifier).loadRivers();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _getRiverStats(String riverId) async {
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
        if (data['trash_collection'] != null && data['trash_collection'] is Map<String, dynamic>) {
          final trashData = data['trash_collection'] as Map<String, dynamic>;
          final weightRaw = trashData['total_weight'];
          if (weightRaw is num) {
            totalTrash += weightRaw.toDouble();
          }
        }
      }

      final stats = {
        'totalDeployments': totalDeployments,
        'totalTrashCollected': totalTrash,
      };

      _riverStats[riverId] = stats;
      return stats;
    } catch (_) {
      return {'totalDeployments': 0, 'totalTrashCollected': 0.0};
    }
  }

  @override
  Widget build(BuildContext context) {
    final riverState = ref.watch(riverProvider);
    
    // Filter rivers by this organization
    final orgRivers = riverState.rivers.where((river) {
      final matchesOrg = river.organizationId == widget.organization.id;
      final matchesSearch = river.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (river.description?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      return matchesOrg && matchesSearch;
    }).toList();

    return Scaffold(
      appBar: GlobalAppBar(
        title: widget.organization.name,
        showDrawer: false,
      ),
      body: Column(
        children: [
          // Organization header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary.withValues(alpha: 0.1), AppColors.surface],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border(
                bottom: BorderSide(color: AppColors.border),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.7)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.business, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.organization.name,
                            style: AppTextStyles.titleLarge.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (widget.organization.description.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                widget.organization.description,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.water, size: 16, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        '${orgRivers.length} ${orgRivers.length == 1 ? 'River' : 'Rivers'}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(
                bottom: BorderSide(color: AppColors.border),
              ),
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search rivers in this organization...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

          // Rivers List
          Expanded(
            child: riverState.isLoading
                ? const LoadingIndicator(message: 'Loading rivers...')
                : orgRivers.isEmpty
                    ? EmptyState(
                        icon: Icons.water,
                        title: 'No Rivers Found',
                        message: _searchQuery.isEmpty
                            ? 'No rivers in this organization yet. Add your first river.'
                            : 'No rivers match your search.',
                        actionLabel: 'Add River',
                        onAction: () => _showAddRiverDialog(context),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: orgRivers.length,
                        itemBuilder: (context, index) {
                          final river = orgRivers[index];
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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shadowColor: AppColors.primary.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border.withValues(alpha: 0.3)),
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
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.water, color: AppColors.primary, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          river.name,
                          style: AppTextStyles.bodyLarge.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (river.description != null && river.description!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              river.description!,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Statistics (computed from deployments for reliable admin view)
              FutureBuilder<Map<String, dynamic>>(
                future: _getRiverStats(river.id),
                builder: (context, snapshot) {
                  final stats = snapshot.data ?? const {
                    'totalDeployments': 0,
                    'totalTrashCollected': 0.0,
                  };
                  final totalDeployments = stats['totalDeployments'] as int? ?? 0;
                  final totalTrash = stats['totalTrashCollected'] as double? ?? 0.0;

                  return Row(
                    children: [
                      Expanded(
                        child: _buildStatChip(
                          Icons.event,
                          'Deployments',
                          '$totalDeployments',
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatChip(
                          Icons.cleaning_services,
                          'Trash',
                          '${totalTrash.toStringAsFixed(1)} kg',
                          Colors.green,
                        ),
                      ),
                    ],
                  );
                },
              ),

              if (river.lastDeployment != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Last deployment: ${DateFormat('MMM d, yyyy').format(river.lastDeployment!)}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textMuted,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddRiverDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.water, color: AppColors.primary),
            const SizedBox(width: 8),
            const Text('Add River'),
          ],
        ),
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
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This river will be added to ${widget.organization.name}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                SnackbarUtil.showError(dialogContext, 'Please enter a river name');
                return;
              }

              try {
                final riverId = await ref.read(riverProvider.notifier).createRiverByName(
                  nameController.text.trim(),
                  description: descriptionController.text.trim(),
                  organizationId: widget.organization.id,
                );
                
                if (riverId != null && dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                  SnackbarUtil.showSuccess(context, 'River added successfully');
                  // Refresh the list
                  ref.read(riverProvider.notifier).loadRivers();
                }
              } catch (e) {
                if (dialogContext.mounted) {
                  SnackbarUtil.showError(dialogContext, 'Failed to add river: $e');
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
