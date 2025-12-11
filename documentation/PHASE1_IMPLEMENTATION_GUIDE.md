# Phase 1 Implementation Guide - Quick Reference

This guide provides ready-to-use code snippets for implementing Phase 1 of the organization enhancements.

## Status Summary

✅ **Completed:**
- River creation and visibility fixes
- RTDB deployment updates with botId
- Google Apps Script updates

🔄 **Phase 1 To Implement:**
1. Field Operator Creation - Organization Autocomplete
2. Admin Add River Dialog - Organization Selection

---

## 1. Field Operator Creation - Organization Autocomplete

### Prerequisites
First, add helper method to OrganizationService:

```dart
// File: lib/core/services/organization_service.dart
// Add this method:

Future<String> createOrganizationIfNotExists({
  required String name,
  required String creatorUserId,
  String? description,
}) async {
  // Check if organization exists
  final existing = await getOrganizationByName(name.trim());
  if (existing != null) return existing.id;
  
  // Create new organization
  final org = OrganizationModel(
    id: '',
    name: name.trim(),
    description: description?.trim().isEmpty == true ? null : description?.trim(),
    creatorUserId: creatorUserId,
    status: 'active',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
  return await create(org);
}
```

### Add to OrganizationProvider:

```dart
// File: lib/core/providers/organization_provider.dart
// Add this method to OrganizationNotifier class:

Future<String?> createOrganizationByName(String name, {String? description}) async {
  state = state.copyWith(isLoading: true, error: null);
  try {
    final organizationService = ref.read(organizationServiceProvider);
    final currentUser = ref.read(authProvider).userProfile;
    if (currentUser == null) throw Exception('No user');
    
    final id = await organizationService.createOrganizationIfNotExists(
      name: name,
      creatorUserId: currentUser.id,
      description: description,
    );
    await loadOrganizationsByCreator(currentUser.id);
    return id;
  } catch (e) {
    state = state.copyWith(isLoading: false, error: e.toString());
    return null;
  }
}
```

### Main Implementation

In `management_page.dart`, you need to find where field operators are created. Since the exact location isn't visible in the file, look for:
- A route like `/add-field-operator` or `/register-user`
- Or a dialog/bottom sheet for adding users
- Check the routes file: `lib/core/routes/app_routes.dart`

**Once you find the field operator creation form, add this organization autocomplete widget:**

```dart
// Add these to your StatefulWidget's state:
final TextEditingController _organizationController = TextEditingController();
String? _selectedOrganizationId;
bool _showOrgSuggestions = false;
List<OrganizationModel> _orgSuggestions = [];

// Dispose in dispose():
@override
void dispose() {
  _organizationController.dispose();
  // ... other disposals
  super.dispose();
}

// Method to search organizations:
Future<void> _searchOrganizations(String query) async {
  if (query.trim().isEmpty) {
    setState(() {
      _showOrgSuggestions = false;
      _orgSuggestions = [];
    });
    return;
  }

  final suggestions = await ref.read(organizationProvider.notifier).searchOrganizations(query);
  setState(() {
    _orgSuggestions = suggestions;
    _showOrgSuggestions = true;
  });
}

// Method to show create organization dialog:
void _showCreateOrganizationDialog(String suggestedName) {
  final nameController = TextEditingController(text: suggestedName);
  final descriptionController = TextEditingController();

  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.business, color: AppColors.primary),
          const SizedBox(width: 8),
          const Text('Create Organization'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Organization Name *',
              hintText: 'e.g., Metro Manila Team',
              border: OutlineInputBorder(),
            ),
            autofocus: false,
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
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (nameController.text.trim().isEmpty) {
              SnackbarUtil.showError(dialogContext, 'Please enter an organization name');
              return;
            }

            try {
              final orgId = await ref.read(organizationProvider.notifier).createOrganizationByName(
                nameController.text.trim(),
                description: descriptionController.text.trim(),
              );
              
              if (orgId != null && dialogContext.mounted) {
                Navigator.pop(dialogContext);
                // Update the field operator form with the new organization
                setState(() {
                  _organizationController.text = nameController.text.trim();
                  _selectedOrganizationId = orgId;
                  _showOrgSuggestions = false;
                });
                SnackbarUtil.showSuccess(context, 'Organization created successfully');
              }
            } catch (e) {
              if (dialogContext.mounted) {
                SnackbarUtil.showError(dialogContext, 'Failed to create organization: $e');
              }
            }
          },
          child: const Text('Create'),
        ),
      ],
    ),
  );
}

// Add this widget to your form (after email, before submit button):
Widget _buildOrganizationField() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextFormField(
        controller: _organizationController,
        decoration: InputDecoration(
          labelText: 'Organization *',
          hintText: 'Search or create organization',
          prefixIcon: const Icon(Icons.business),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        onChanged: (value) => _searchOrganizations(value),
        validator: (value) {
          if (_selectedOrganizationId == null) {
            return 'Please select an organization';
          }
          return null;
        },
      ),
      
      // Suggestions dropdown
      if (_showOrgSuggestions)
        Container(
          margin: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          constraints: const BoxConstraints(maxHeight: 200),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Existing organization suggestions
              if (_orgSuggestions.isNotEmpty)
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _orgSuggestions.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.border),
                    itemBuilder: (context, index) {
                      final org = _orgSuggestions[index];
                      return ListTile(
                        dense: true,
                        leading: Icon(Icons.business, size: 20, color: AppColors.primary),
                        title: Text(org.name),
                        subtitle: org.description != null
                            ? Text(
                                org.description!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )
                            : null,
                        onTap: () {
                          setState(() {
                            _organizationController.text = org.name;
                            _selectedOrganizationId = org.id;
                            _showOrgSuggestions = false;
                          });
                        },
                      );
                    },
                  ),
                ),
              
              // "Create New Organization" option
              if (_organizationController.text.trim().isNotEmpty)
                Column(
                  children: [
                    if (_orgSuggestions.isNotEmpty)
                      Divider(height: 1, color: AppColors.border),
                    Container(
                      color: AppColors.primary.withValues(alpha: 0.05),
                      child: ListTile(
                        dense: true,
                        leading: Icon(
                          Icons.add_circle_outline,
                          size: 20,
                          color: AppColors.primary,
                        ),
                        title: Text(
                          'Create "${_organizationController.text.trim()}"',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          'Add as a new organization',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        onTap: () => _showCreateOrganizationDialog(_organizationController.text.trim()),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
    ],
  );
}
```

**In your form submit/create method, pass the organizationId:**

```dart
// When creating the field operator user:
await userService.create(UserModel(
  // ... other fields
  organizationId: _selectedOrganizationId, // Add this
  // ... other fields
));
```

---

## 2. Admin Add River Dialog - Organization Selection

### Update rivers_management_page.dart

Find the `_showAddRiverDialog` method and replace it with this enhanced version:

```dart
void _showAddRiverDialog(BuildContext context, {OrganizationModel? preselectedOrg}) {
  final nameController = TextEditingController();
  final descriptionController = TextEditingController();
  final orgController = TextEditingController(text: preselectedOrg?.name ?? '');
  
  String? selectedOrgId = preselectedOrg?.id;
  bool showOrgSuggestions = false;
  List<OrganizationModel> orgSuggestions = [];
  
  // Check if user is admin
  final authState = ref.read(authProvider);
  final isAdmin = authState.userProfile?.isAdmin ?? false;

  showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.water, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text('Add River'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // River Name Field
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'River Name *',
                    hintText: 'e.g., Pasig River',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Organization Selection (Required for admins)
                if (isAdmin) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: orgController,
                        readOnly: preselectedOrg != null,
                        decoration: InputDecoration(
                          labelText: 'Organization *',
                          hintText: preselectedOrg != null ? '' : 'Select organization',
                          prefixIcon: const Icon(Icons.business),
                          border: const OutlineInputBorder(),
                          suffixIcon: preselectedOrg != null 
                              ? const Icon(Icons.lock, size: 16)
                              : null,
                        ),
                        onChanged: (value) async {
                          if (preselectedOrg == null) {
                            final suggestions = await ref.read(organizationProvider.notifier).searchOrganizations(value);
                            setDialogState(() {
                              orgSuggestions = suggestions;
                              showOrgSuggestions = value.trim().isNotEmpty;
                            });
                          }
                        },
                      ),
                      
                      // Organization suggestions
                      if (showOrgSuggestions && preselectedOrg == null)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          constraints: const BoxConstraints(maxHeight: 150),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: orgSuggestions.length,
                            separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.border),
                            itemBuilder: (context, index) {
                              final org = orgSuggestions[index];
                              return ListTile(
                                dense: true,
                                leading: Icon(Icons.business, size: 20, color: AppColors.primary),
                                title: Text(org.name),
                                onTap: () {
                                  setDialogState(() {
                                    orgController.text = org.name;
                                    selectedOrgId = org.id;
                                    showOrgSuggestions = false;
                                  });
                                },
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Description Field
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
                
                // Validate organization for admins
                if (isAdmin && selectedOrgId == null) {
                  SnackbarUtil.showError(dialogContext, 'Please select an organization');
                  return;
                }

                final currentUser = ref.read(authProvider).userProfile;
                if (currentUser == null) return;

                try {
                  final riverId = await ref.read(riverProvider.notifier).createRiverByName(
                    nameController.text.trim(),
                    description: descriptionController.text.trim(),
                  );
                  
                  if (riverId != null && dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                    SnackbarUtil.showSuccess(context, 'River added successfully');
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
        );
      },
    ),
  );
}
```

---

## Testing Phase 1

### Field Operator Creation
1. Navigate to Management > Users tab
2. Click "Add Field Operator"
3. Type an organization name
4. Verify autocomplete shows existing organizations
5. Verify "Create new" option appears
6. Create a new field operator with an organization
7. Verify organization is saved correctly

### Admin Add River
1. Navigate to Rivers Management (as admin)
2. Click "Add River"
3. Verify organization field appears (required)
4. Try to submit without organization (should fail validation)
5. Select an organization from autocomplete
6. Add the river
7. Verify river is created with correct organization

---

## Quick Checklist

- [ ] Add `createOrganizationIfNotExists` to `organization_service.dart`
- [ ] Add `createOrganizationByName` to `organization_provider.dart`
- [ ] Find field operator creation form (check routes or dialogs)
- [ ] Add organization autocomplete to field operator form
- [ ] Update `_showAddRiverDialog` in `rivers_management_page.dart`
- [ ] Test field operator creation with organization
- [ ] Test admin add river with organization selection
- [ ] Run `flutter analyze` to check for errors
- [ ] Test on device/emulator

---

## Common Issues & Solutions

**Issue:** "No route defined" when navigating
**Solution:** Check `app_routes.dart` for the correct route name

**Issue:** Organization not saving
**Solution:** Ensure you're passing `organizationId` in the user/river creation model

**Issue:** Autocomplete not showing
**Solution:** Check that `searchOrganizations` method is returning results

**Issue:** Can't create organization inline
**Solution:** Verify `createOrganizationByName` is implemented in provider

---

## Next Steps After Phase 1

Once Phase 1 is complete and tested:
1. Implement Phase 2 (Rivers Management Admin View + Org Details Quick Actions)
2. Implement Phase 3 (Edit Profile Organization Selection)
3. Final testing and polish

