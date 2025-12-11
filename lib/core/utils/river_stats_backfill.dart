import 'package:cloud_firestore/cloud_firestore.dart';

/// Utility to backfill river statistics from existing deployments
/// Run this once to populate total_deployments and total_trash_collected
class RiverStatsBackfill {
  static Future<void> recalculateAllRiverStats() async {
    try {
      print('Starting river statistics backfill...');
      
      // Get all rivers
      final riversSnapshot = await FirebaseFirestore.instance
          .collection('rivers')
          .get();
      
      print('Found ${riversSnapshot.docs.length} rivers to process');
      
      for (final riverDoc in riversSnapshot.docs) {
        final riverId = riverDoc.id;
        final riverName = riverDoc.data()['name'] ?? 'Unknown';
        
        print('Processing river: $riverName ($riverId)');
        
        // Get all deployments for this river
        final deploymentsSnapshot = await FirebaseFirestore.instance
            .collection('deployments')
            .where('river_id', isEqualTo: riverId)
            .get();
        
        int totalDeployments = deploymentsSnapshot.docs.length;
        double totalTrash = 0.0;
        DateTime? lastDeployment;
        
        // Calculate totals from all deployments
        for (final deploymentDoc in deploymentsSnapshot.docs) {
          final data = deploymentDoc.data();
          
          // Get trash weight
          if (data['trash_collection'] != null) {
            final trashCollection = data['trash_collection'] as Map<String, dynamic>;
            final weight = (trashCollection['total_weight'] as num?)?.toDouble() ?? 0.0;
            totalTrash += weight;
          }
          
          // Get latest deployment date
          if (data['created_at'] != null) {
            final deploymentDate = (data['created_at'] as Timestamp).toDate();
            if (lastDeployment == null || deploymentDate.isAfter(lastDeployment)) {
              lastDeployment = deploymentDate;
            }
          }
        }
        
        // Update river statistics
        await FirebaseFirestore.instance
            .collection('rivers')
            .doc(riverId)
            .update({
          'total_deployments': totalDeployments,
          'total_trash_collected': totalTrash,
          'last_deployment': lastDeployment != null ? Timestamp.fromDate(lastDeployment) : null,
          'updated_at': FieldValue.serverTimestamp(),
        });
        
        print('✓ Updated $riverName: $totalDeployments deployments, ${totalTrash.toStringAsFixed(2)} kg trash');
      }
      
      print('✅ River statistics backfill completed successfully!');
    } catch (e) {
      print('❌ Error during backfill: $e');
      rethrow;
    }
  }
}

