import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/app_bar.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/theme/color_palette.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/models/river_model.dart';
import '../../../core/providers/river_provider.dart';
import '../../../core/utils/snackbar_util.dart';
import 'river_details_page.dart';

class ArchivedRiversPage extends ConsumerStatefulWidget {
  const ArchivedRiversPage({super.key});

  @override
  ConsumerState<ArchivedRiversPage> createState() => _ArchivedRiversPageState();
}

class _ArchivedRiversPageState extends ConsumerState<ArchivedRiversPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  final Map<String, Map<String, dynamic>> _riverStats = {};

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
        if (data['trash_collection'] != null) {
          final trashData = data['trash_collection'] as Map<String, dynamic>;
          totalTrash += (trashData['total_weight'] ?? 0).toDouble();
        }
      }

      final stats = {
        'totalDeployments': totalDeployments,
        'totalTrashCollected': totalTrash,
      };

      _riverStats[riverId] = stats;
      return stats;
    } catch (e) {
      print('Error fetching river stats: $e');
      return {'totalDeployments': 0, 'totalTrashCollected': 0.0};
    }
  }

  Future<void> _restoreRiver(RiverModel river) async {
    try {
      await ref.read(riverProvider.notifier).updateRiver(river.id, {
        'is_archived': false,
      });
      if (mounted) {
        SnackbarUtil.showSuccess(context, '${river.name} restored successfully');
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtil.showError(context, 'Failed to restore river: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final riverState = ref.watch(riverProvider);
    
    // Filter archived rivers only
    final archivedRivers = riverState.rivers
        .where((river) => river.isArchived)
        .where((river) {
          final matchesSearch = river.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              (river.description?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
          return matchesSearch;
        })
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Archived Rivers'),
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.15))),
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search archived rivers...',
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

          // Rivers list
          Expanded(
            child: riverState.isLoading
                ? const LoadingIndicator(message: 'Loading archived rivers...')
                : archivedRivers.isEmpty
                    ? EmptyState(
                        icon: Icons.archive_outlined,
                        title: 'No Archived Rivers',
                        message: _searchQuery.isEmpty
                            ? 'No rivers have been archived yet.'
                            : 'No archived rivers match your search.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: archivedRivers.length,
                        itemBuilder: (context, index) {
                          final river = archivedRivers[index];
                          return _buildArchivedRiverCard(river);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildArchivedRiverCard(RiverModel river) {
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
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.archive_rounded, color: Colors.grey.shade700, size: 20),
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

                // Statistics
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
                            Colors.grey,
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
                            Colors.grey,
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 10),
                Divider(height: 1, color: AppColors.border.withValues(alpha: 0.2)),
                const SizedBox(height: 10),
                
                // Footer with archived date and restore button
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.archive_outlined, size: 12, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            'Archived',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildIconButton(
                      Icons.unarchive_rounded,
                      () => _restoreRiver(river),
                      Colors.green,
                    ),
                    const SizedBox(width: 6),
                    _buildIconButton(
                      Icons.visibility_outlined,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RiverDetailsPage(river: river),
                          ),
                        );
                      },
                      AppColors.primary,
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
}
