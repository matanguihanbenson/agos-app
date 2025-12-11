import '../models/organization_model.dart';
import 'base_service.dart';

class OrganizationService extends BaseService<OrganizationModel> {
  @override
  String get collectionName => 'organizations';

  @override
  OrganizationModel fromMap(Map<String, dynamic> map, String id) {
    return OrganizationModel.fromMap(map, id);
  }

  // Get active organizations
  Stream<List<OrganizationModel>> getActiveOrganizations() {
    return getByField('status', 'active');
  }

  // Get organizations created by specific user
  Stream<List<OrganizationModel>> getOrganizationsByCreator(String createdBy) {
    return getByField('created_by', createdBy);
  }

  // Update organization status
  Future<void> updateOrganizationStatus(String organizationId, String status) async {
    await update(organizationId, {'status': status});
  }

  // Search organizations by name
  Future<List<OrganizationModel>> searchOrganizationsByName(String searchTerm) async {
    try {
      final allOrganizations = await getAllOnce();
      return allOrganizations.where((org) {
        final name = org.name.toLowerCase();
        final search = searchTerm.toLowerCase();
        return name.contains(search);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // Get organization by name
  Future<OrganizationModel?> getOrganizationByName(String name) async {
    try {
      final organizations = await getByFieldOnce('name', name);
      return organizations.isNotEmpty ? organizations.first : null;
    } catch (e) {
      return null;
    }
  }

  // Get organizations count
  Future<int> getOrganizationsCount() async {
    try {
      final organizations = await getAllOnce();
      return organizations.length;
    } catch (e) {
      return 0;
    }
  }

  // Get active organizations count
  Future<int> getActiveOrganizationsCount() async {
    try {
      final organizations = await getByFieldOnce('status', 'active');
      return organizations.length;
    } catch (e) {
      return 0;
    }
  }

  // Create organization if not exists (dedupe by name)
  Future<String> createOrganizationIfNotExists({
    required String name,
    required String createdBy,
    String? description,
  }) async {
    // Check if organization exists
    final existing = await getOrganizationByName(name.trim());
    if (existing != null) return existing.id;
    
    // Create new organization
    final org = OrganizationModel(
      id: '',
      name: name.trim(),
      description: (description == null || description.trim().isEmpty) ? '' : description.trim(),
      createdBy: createdBy,
      status: 'active',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    return await create(org);
  }
}
