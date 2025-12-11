# River Management Fixes

## Issues Fixed

### 1. **River Creation Failing**
**Problem:** Users couldn't create rivers because the system required an `organizationId`, but many users didn't have one set.

**Solution:**
- Modified `createRiverIfNotExists()` to gracefully handle missing `organizationId`
- Falls back to user's own ID as a "personal group" if no organization is assigned
- This ensures rivers can always be created, even for users without formal organizations

### 2. **Rivers Not Showing in List**
**Problem:** Rivers management page was empty because the visibility query was too strict.

**Solution:**
- **For Admins:** Now shows ALL rivers they own across all their organizations (uses `owner_admin_id` query)
- **For Field Operators with Organization:** Shows rivers shared within their organization (uses `organization_id` query)
- **For Users without Organization:** Shows rivers they personally created (uses `created_by` query)

### 3. **Context and Clarity**
**Added:** An informational banner at the top of the Rivers Management page that tells users what they're viewing:
- Admins: "Viewing all rivers you own across your organizations"
- Field Operators with org: "Viewing rivers shared in your organization"
- Users without org: "Viewing your personal rivers"

## Updated Files

### `lib/core/services/river_service.dart`
- **`getRiversVisibleToUser()`**: Now has three-tier logic:
  1. Admin → show all owned rivers
  2. Field Operator with org → show org rivers
  3. Fallback → show personally created rivers
  
- **`createRiverIfNotExists()`**: Gracefully handles missing `organizationId` by falling back to `creator.id`

### `lib/features/rivers/pages/rivers_management_page.dart`
- Added context banner showing current view scope

## How It Works Now

### River Visibility Model

#### For Admins
```dart
// Query: where('owner_admin_id', isEqualTo: adminUserId)
// Shows: ALL rivers the admin created, across all their organizations
```

#### For Field Operators (with organizationId)
```dart
// Query: where('organization_id', isEqualTo: userOrgId)
// Shows: Rivers shared within their organization
// Includes: Rivers created by admin or other FOs in the same org
```

#### For Users Without Organization
```dart
// Query: where('created_by', isEqualTo: userId)
// Shows: Only rivers they personally created
```

### River Creation Flow

1. **User enters river name in:**
   - Rivers Management page (Add River button)
   - Schedule creation page (river autocomplete)

2. **System checks for duplicates:**
   - Scoped by `organization_id` + `name_lower`
   - Prevents duplicate rivers within the same org

3. **System creates river with:**
   - `organizationId`: User's org, or user's ID as fallback
   - `ownerAdminId`: Resolved admin ID (admin's ID or field operator's creator)
   - `createdBy`: Actual user who created it
   - `nameLower`: Lowercase name for deduplication and search

4. **River is now visible to:**
   - Admin who owns it
   - All field operators in the same organization
   - The creator (if no org assigned)

## Testing Checklist

✅ **As Admin:**
- [ ] Can create rivers on Rivers Management page
- [ ] Can create rivers from Schedule creation page
- [ ] Can see all rivers I've created across all my orgs
- [ ] Rivers are properly grouped and searchable

✅ **As Field Operator (with organization):**
- [ ] Can create rivers on Rivers Management page
- [ ] Can create rivers from Schedule creation page
- [ ] Can see rivers created by my admin
- [ ] Can see rivers created by other FOs in my org
- [ ] Cannot see rivers from other organizations

✅ **As User (without organization):**
- [ ] Can still create rivers (uses my user ID as personal group)
- [ ] Can see rivers I created
- [ ] Cannot see other users' rivers

## Benefits

1. **No more blank pages**: Rivers management page always shows relevant rivers
2. **Graceful fallback**: System works even if organizations aren't fully set up
3. **Clear context**: Users understand what they're viewing
4. **Proper sharing**: Field operators within the same org share rivers
5. **Admin oversight**: Admins see all rivers they own across their ecosystem

## Future Enhancements

Consider these improvements:
- [ ] Allow admins to transfer river ownership
- [ ] Add organization selector for admins managing multiple orgs
- [ ] Bulk river import/export
- [ ] River templates (e.g., common rivers pre-populated)
- [ ] Analytics dashboard showing river usage across organizations
