# Organization Management Enhancements - Implementation Plan

## Overview
This document outlines the enhancements needed for organization management across the application, focusing on better UX for admins and field operators when working with organizations.

## 1. Field Operator Creation - Add Organization Autocomplete

### Location
`lib/features/management/pages/management_page.dart` - `_showAddFieldOperatorDialog()` method

### Changes Needed
1. Add organization autocomplete field (similar to river name in schedule creation)
2. Show organization suggestions as user types
3. Add "Create New Organization" option if no match found
4. Make organization selection required for field operators

### Implementation Steps
```dart
// Add to _showAddFieldOperatorDialog:
final _orgController = TextEditingController();
bool _showOrgSuggestions = false;
List<OrganizationModel> _orgSuggestions = [];
String? _selectedOrgId;

// Add organization autocomplete field:
TextFormField(
  controller: _orgController,
  decoration: InputDecoration(
    labelText: 'Organization *',
    hintText: 'Search or create organization',
    prefixIcon: Icon(Icons.business),
  ),
  onChanged: (value) => _searchOrganizations(value),
  validator: (value) => value?.isEmpty ?? true ? 'Organization required' : null,
),

// Show suggestions dropdown:
if (_showOrgSuggestions)
  Container(
    // List of organization suggestions
    // + "Create new organization" option
  ),
```

### Files to Create/Modify
- Modify: `management_page.dart` - Update `_showAddFieldOperatorDialog()`
- Add method: `_searchOrganizations(String query)` 
- Add method: `_showCreateOrganizationDialog(String suggestedName)`

---

## 2. Edit Profile Page - Add Organization Selection

### Location
`lib/features/profile/pages/profile_page.dart`

### Changes Needed
1. Add organization field in edit mode
2. Show current organization (read-only for field operators, editable for admins)
3. Add organization autocomplete for admins to change org
4. Field operators cannot change their organization (immutable)

### Implementation Steps
```dart
// Add to profile edit form:
if (user.isAdmin)
  // Organization autocomplete (can change)
  _buildOrganizationAutocomplete()
else
  // Organization display (read-only)
  _buildOrganizationDisplay()
```

### Files to Create/Modify
- Modify: `profile_page.dart` - Add organization section to edit form
- Add widget: `_buildOrganizationAutocomplete()`
- Add widget: `_buildOrganizationDisplay()`

---

## 3. Organization Details Page - Add Quick Actions

### Location
`lib/features/management/pages/organization_details_page.dart`

### Changes Needed
1. Add "Add Bot" button that shows bot selector dialog
2. Add "Add User" button that shows user creation/assignment dialog
3. Quick assign existing bots to organization
4. Quick invite/create users for organization

### Implementation Steps
```dart
// Add quick action buttons in organization details:
Row(
  children: [
    Expanded(
      child: ElevatedButton.icon(
        icon: Icon(Icons.directions_boat),
        label: Text('Add Bot'),
        onPressed: () => _showAddBotToOrgDialog(),
      ),
    ),
    SizedBox(width: 12),
    Expanded(
      child: ElevatedButton.icon(
        icon: Icon(Icons.person_add),
        label: Text('Add User'),
        onPressed: () => _showAddUserToOrgDialog(),
      ),
    ),
  ],
),

// Dialog to select and assign bots:
void _showAddBotToOrgDialog() {
  // Show list of unassigned bots or bots from other orgs
  // Allow admin to reassign bot to this organization
}

// Dialog to create/assign users:
void _showAddUserToOrgDialog() {
  // Option 1: Create new field operator for this org
  // Option 2: Reassign existing field operator to this org
}
```

### Files to Create/Modify
- Modify: `organization_details_page.dart` - Add quick action buttons
- Add method: `_showAddBotToOrgDialog()`
- Add method: `_showAddUserToOrgDialog()`
- May need: New service methods for bot/user assignment

---

## 4. Rivers Management Page - Admin Organization View

### Location
`lib/features/rivers/pages/rivers_management_page.dart`

### Changes Needed for Admin View
1. Show organization cards instead of direct river list
2. Display river count per organization
3. Clicking org card navigates to org-specific river list
4. Add search bar within org-specific view
5. Add "Add River" button within org context

### New Structure for Admins
```
Rivers Management (Admin View)
├── Search Organizations
├── Organization Cards Grid
│   ├── [Org 1 Card] - 5 rivers
│   ├── [Org 2 Card] - 12 rivers
│   └── [Org 3 Card] - 3 rivers
└── Floating Action Button: "Create Organization"

When Org Card Clicked → Organization Rivers View
├── Org Header (name, description)
├── Quick Actions
│   ├── Add River (to this org)
│   └── Manage Organization
├── Search Rivers in this org
└── River List (filtered by org)
```

### Implementation Steps

#### Step 4.1: Create Organization Card Widget
```dart
Widget _buildOrganizationCard(OrganizationModel org, int riverCount) {
  return Card(
    child: InkWell(
      onTap: () => _navigateToOrgRivers(org),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.business, size: 48),
            SizedBox(height: 8),
            Text(org.name, style: AppTextStyles.titleMedium),
            SizedBox(height: 4),
            Text('$riverCount rivers', style: AppTextStyles.bodySmall),
          ],
        ),
      ),
    ),
  );
}
```

#### Step 4.2: Create Organization Rivers View Page
```dart
class OrganizationRiversPage extends ConsumerStatefulWidget {
  final OrganizationModel organization;
  
  const OrganizationRiversPage({required this.organization});
  
  // Show:
  // - Org header
  // - Search bar
  // - Add River button (scoped to this org)
  // - Rivers list (filtered by org)
}
```

#### Step 4.3: Add Organization Selection to Add River Dialog (Admin Only)
```dart
void _showAddRiverDialog(BuildContext context, {OrganizationModel? preselectedOrg}) {
  final orgController = TextEditingController(
    text: preselectedOrg?.name ?? '',
  );
  String? selectedOrgId = preselectedOrg?.id;
  
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Add River'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // River Name Field
          TextField(
            controller: nameController,
            decoration: InputDecoration(labelText: 'River Name *'),
          ),
          SizedBox(height: 16),
          
          // Organization Selection (REQUIRED for admins)
          TextFormField(
            controller: orgController,
            decoration: InputDecoration(
              labelText: 'Organization *',
              hintText: 'Select organization',
              prefixIcon: Icon(Icons.business),
            ),
            readOnly: preselectedOrg != null, // Read-only if pre-selected
            onTap: preselectedOrg == null ? () => _showOrgSelector() : null,
            validator: (value) => selectedOrgId == null ? 'Required' : null,
          ),
          SizedBox(height: 16),
          
          // Description Field
          TextField(
            controller: descriptionController,
            decoration: InputDecoration(labelText: 'Description (Optional)'),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
        ElevatedButton(
          onPressed: () async {
            if (selectedOrgId == null) {
              SnackbarUtil.showError(context, 'Please select an organization');
              return;
            }
            // Create river with orgId
            await ref.read(riverProvider.notifier).createRiverByName(
              nameController.text.trim(),
              description: descriptionController.text.trim(),
              orgId: selectedOrgId,
            );
          },
          child: Text('Add'),
        ),
      ],
    ),
  );
}
```

### Files to Create/Modify
- Modify: `rivers_management_page.dart` - Add organization grid view for admins
- Create: `organization_rivers_page.dart` - New page for org-specific river list
- Modify: `river_provider.dart` - Add `createRiverByName` with orgId parameter (already exists)
- Modify: `river_service.dart` - Support org-scoped river counts

---

## 5. Supporting Service Methods

### OrganizationService Enhancements
```dart
// Add to organization_service.dart:

// Get river count per organization
Future<Map<String, int>> getRiverCountsByOrganization(String adminId) async {
  final riverService = RiverService();
  final allRivers = await riverService.getRiversByOwner(adminId);
  
  final Map<String, int> counts = {};
  for (final river in allRivers) {
    final orgId = river.organizationId ?? 'none';
    counts[orgId] = (counts[orgId] ?? 0) + 1;
  }
  return counts;
}

// Create organization if not exists (dedupe by name)
Future<String> createOrganizationIfNotExists({
  required String name,
  required String creatorUserId,
  String? description,
}) async {
  final existing = await getOrganizationByName(name);
  if (existing != null) return existing.id;
  
  final org = OrganizationModel(
    id: '',
    name: name.trim(),
    description: description?.trim(),
    creatorUserId: creatorUserId,
    status: 'active',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
  return await create(org);
}
```

### RiverService Enhancements
```dart
// Add to river_service.dart:

// Get river count by organization
Future<int> getRiverCountByOrganization(String organizationId) async {
  try {
    final snapshot = await firestore
        .collection(collectionName)
        .where('organization_id', isEqualTo: organizationId)
        .get();
    return snapshot.docs.length;
  } catch (e) {
    return 0;
  }
}

// Get rivers with organization details
Future<List<Map<String, dynamic>>> getRiversWithOrgDetails(String adminId) async {
  final rivers = await getRiversByOwner(adminId);
  final orgService = OrganizationService();
  
  final List<Map<String, dynamic>> result = [];
  for (final river in rivers) {
    final org = river.organizationId != null
        ? await orgService.getById(river.organizationId!)
        : null;
    result.add({
      'river': river,
      'organization': org,
    });
  }
  return result;
}
```

---

## Implementation Priority

### Phase 1 (High Priority)
1. ✅ Field Operator Creation - Organization Autocomplete
2. ✅ Admin Add River Dialog - Organization Selection (Required)

### Phase 2 (Medium Priority)
3. ✅ Rivers Management Page - Admin Organization View
4. ✅ Organization Details Page - Quick Actions

### Phase 3 (Lower Priority)
5. ✅ Edit Profile Page - Organization Selection

---

## Testing Checklist

### Field Operator Creation
- [ ] Can search organizations while typing
- [ ] Can select existing organization
- [ ] Can create new organization inline
- [ ] Organization is required (validation works)
- [ ] Created field operator has correct org assigned

### Rivers Management (Admin)
- [ ] Shows organization cards instead of direct river list
- [ ] River count per org is accurate
- [ ] Clicking org card navigates to org-specific view
- [ ] Can add river within org context
- [ ] Organization selection is required when adding river
- [ ] Search works within org-specific view

### Organization Details
- [ ] "Add Bot" button shows bot selector
- [ ] Can assign bot to organization
- [ ] "Add User" button allows user creation/assignment
- [ ] Quick actions work smoothly

### Edit Profile
- [ ] Admin can change their organization
- [ ] Field operator sees organization (read-only)
- [ ] Organization autocomplete works
- [ ] Changes are saved correctly

---

## Notes

- All organization autocompletes should follow the same UX pattern as river name selection in schedule creation
- Organization names should be unique (dedupe on creation)
- Field operators cannot change their own organization (only admin can)
- When creating a new organization inline, use a simple dialog with name + description fields
- All changes should maintain backward compatibility with existing data

---

## Files Summary

### Files to Modify
1. `lib/features/management/pages/management_page.dart`
2. `lib/features/profile/pages/profile_page.dart`
3. `lib/features/rivers/pages/rivers_management_page.dart`
4. `lib/features/management/pages/organization_details_page.dart`
5. `lib/core/services/organization_service.dart`
6. `lib/core/services/river_service.dart`
7. `lib/core/providers/organization_provider.dart`

### Files to Create
1. `lib/features/rivers/pages/organization_rivers_page.dart` (New page for org-specific river list)

---

## Next Steps

1. Review this plan with stakeholders
2. Implement Phase 1 (high priority items)
3. Test Phase 1 thoroughly
4. Proceed to Phase 2
5. Final testing and polish
