import '../models/river_model.dart';
import 'base_service.dart';

import '../models/user_model.dart';

class RiverService extends BaseService<RiverModel> {
  @override
  String get collectionName => 'rivers';

  @override
  RiverModel fromMap(Map<String, dynamic> map, String id) {
    return RiverModel.fromMap(map, id);
  }

  // Compute adminId for visibility (admin sees their ecosystem, FOs see admin ecosystem)
  String resolveAdminId(UserModel user) => user.isAdmin ? user.id : (user.createdBy ?? user.id);

  // Get rivers visible to a user by organization (admin can have multiple orgs; use user's orgId)
  Future<List<RiverModel>> getRiversVisibleToUser(UserModel user, {String? orgId}) async {
    try {
      final selectedOrgId = orgId ?? user.organizationId;
      
      // If user is admin, show all rivers they own (across all their orgs)
      if (user.isAdmin) {
        final snapshot = await firestore
            .collection(collectionName)
            .where('owner_admin_id', isEqualTo: user.id)
            .get();
        return snapshot.docs.map((d) => fromMap(d.data(), d.id)).toList();
      }
      
      // For field operators, show rivers in their organization
      if (selectedOrgId != null && selectedOrgId.isNotEmpty) {
        final snapshot = await firestore
            .collection(collectionName)
            .where('organization_id', isEqualTo: selectedOrgId)
            .get();
        return snapshot.docs.map((d) => fromMap(d.data(), d.id)).toList();
      }
      
      // Fallback: if no org, show rivers created by or owned by this user
      final snapshot = await firestore
          .collection(collectionName)
          .where('created_by', isEqualTo: user.id)
          .get();
      return snapshot.docs.map((d) => fromMap(d.data(), d.id)).toList();
    } catch (e) {
      await loggingService.logError(error: e.toString(), context: 'river_get_visible');
      return [];
    }
  }

  // Get rivers by owner admin (legacy)
  Future<List<RiverModel>> getRiversByOwner(String ownerAdminId) async {
    return await getByFieldOnce('owner_admin_id', ownerAdminId);
  }

  // Search rivers by name (visible)
  Future<List<RiverModel>> searchRiversVisibleByName(UserModel user, String searchTerm, {String? orgId}) async {
    try {
      final rivers = await getRiversVisibleToUser(user, orgId: orgId);
      final search = searchTerm.toLowerCase();
      return rivers.where((r) => (r.nameLower ?? r.name.toLowerCase()).contains(search)).toList();
    } catch (e) {
      await loggingService.logError(error: e.toString(), context: 'river_search_visible_by_name');
      return [];
    }
  }

  // Check if a river with name_lower exists for admin
  Future<RiverModel?> getRiverByNameLowerByOrg(String orgId, String nameLower) async {
    try {
      final snap = await firestore
          .collection(collectionName)
          .where('organization_id', isEqualTo: orgId)
          .where('name_lower', isEqualTo: nameLower)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      final doc = snap.docs.first;
      return fromMap(doc.data(), doc.id);
    } catch (e) {
      await loggingService.logError(error: e.toString(), context: 'river_get_by_name_lower');
      return null;
    }
  }

  // Create river if not exists (dedupe by admin + name_lower)
  Future<String> createRiverIfNotExists({
    required String name,
    String? description,
    required UserModel creator,
    String? orgId,
  }) async {
    final adminId = resolveAdminId(creator);
    // Use provided orgId, fall back to user's org, or use user's ID as a personal group
    final targetOrgId = orgId ?? creator.organizationId ?? creator.id;
    
    final nameLower = name.trim().toLowerCase();
    final existing = await getRiverByNameLowerByOrg(targetOrgId, nameLower);
    if (existing != null) return existing.id;

    final river = RiverModel(
      id: '',
      name: name.trim(),
      description: (description?.trim().isEmpty ?? true) ? null : description?.trim(),
      ownerAdminId: adminId,
      organizationId: targetOrgId,
      createdBy: creator.id,
      nameLower: nameLower,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    return await create(river);
  }

  // Legacy: Search rivers by name
  Future<List<RiverModel>> searchRiversByName(String searchTerm, String ownerAdminId) async {
    try {
      final rivers = await getRiversByOwner(ownerAdminId);
      final search = searchTerm.toLowerCase();
      return rivers.where((river) => (river.nameLower ?? river.name.toLowerCase()).contains(search)).toList();
    } catch (e) {
      await loggingService.logError(
        error: e.toString(),
        context: 'river_search_by_name',
      );
      return [];
    }
  }

  // Check if river name exists (legacy)
  Future<bool> riverNameExists(String riverName, String ownerAdminId) async {
    try {
      final rivers = await getRiversByOwner(ownerAdminId);
      return rivers.any((river) => (river.nameLower ?? river.name.toLowerCase()) == riverName.toLowerCase());
    } catch (e) {
      return false;
    }
  }

  // Update river analytics
  Future<void> updateRiverAnalytics(
    String riverId, {
    int? totalDeployments,
    int? activeDeployments,
    double? totalTrashCollected,
    DateTime? lastDeployment,
  }) async {
    final Map<String, dynamic> updates = {};
    
    if (totalDeployments != null) updates['total_deployments'] = totalDeployments;
    if (activeDeployments != null) updates['active_deployments'] = activeDeployments;
    if (totalTrashCollected != null) updates['total_trash_collected'] = totalTrashCollected;
    if (lastDeployment != null) updates['last_deployment'] = lastDeployment;

    await update(riverId, updates);
  }

  // Increment deployment count
  Future<void> incrementDeploymentCount(String riverId) async {
    try {
      final river = await getById(riverId);
      if (river != null) {
        await updateRiverAnalytics(
          riverId,
          totalDeployments: river.totalDeployments + 1,
          activeDeployments: river.activeDeployments + 1,
          lastDeployment: DateTime.now(),
        );
      }
    } catch (e) {
      await loggingService.logError(
        error: e.toString(),
        context: 'river_increment_deployment',
      );
      rethrow;
    }
  }

  // Decrement active deployment count
  Future<void> decrementActiveDeploymentCount(String riverId) async {
    try {
      final river = await getById(riverId);
      if (river != null && river.activeDeployments > 0) {
        await updateRiverAnalytics(
          riverId,
          activeDeployments: river.activeDeployments - 1,
        );
      }
    } catch (e) {
      await loggingService.logError(
        error: e.toString(),
        context: 'river_decrement_active_deployment',
      );
      rethrow;
    }
  }
}
