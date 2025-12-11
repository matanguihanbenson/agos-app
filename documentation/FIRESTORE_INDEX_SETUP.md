# Firestore Index Setup for Activity Logs

This document explains how to set up the required Firestore indexes for the activity logs feature.

## Why Indexes Are Needed

Firestore requires composite indexes when you:
- Query with multiple `where` clauses
- Combine `where` clauses with `orderBy`
- Use inequality operators on different fields

Our activity logs queries use these patterns, so we need indexes.

## Method 1: Deploy Using Firebase CLI (Fastest)

### Prerequisites
1. Install Firebase CLI if not already installed:
```bash
npm install -g firebase-tools
```

2. Login to Firebase:
```bash
firebase login
```

3. Initialize Firebase in your project (if not done):
```bash
firebase init firestore
```
- Select your Firebase project
- Keep default `firestore.rules` file or specify your own
- Use the `firestore.indexes.json` file we created

### Deploy the Indexes

Run this command from your project root:

```bash
firebase deploy --only firestore:indexes
```

This will automatically create all the required indexes from `firestore.indexes.json`.

**Build time**: Indexes typically take 5-15 minutes to build, depending on existing data.

---

## Method 2: Create Indexes Manually via Firebase Console

If you prefer to create indexes manually or don't have Firebase CLI:

### Step 1: Access Firebase Console
1. Go to https://console.firebase.google.com
2. Select your project
3. Navigate to **Firestore Database** → **Indexes** tab
4. Click **Create Index**

### Step 2: Create the Following Indexes

#### Index 1: User Logs with Timestamp
```
Collection ID: activity_logs
Fields to index:
  - user_id (Ascending)
  - timestamp (Descending)
Query scope: Collection
```

#### Index 2: User Logs with Category Filter
```
Collection ID: activity_logs
Fields to index:
  - user_id (Ascending)
  - category (Ascending)
  - timestamp (Descending)
Query scope: Collection
```

#### Index 3: Category Logs with Timestamp
```
Collection ID: activity_logs
Fields to index:
  - category (Ascending)
  - timestamp (Descending)
Query scope: Collection
```

#### Index 4: Simple Timestamp Sort
```
Collection ID: activity_logs
Fields to index:
  - timestamp (Descending)
Query scope: Collection
```

### Step 3: Wait for Build Completion
- Each index will show "Building" status
- Wait until all indexes show "Enabled" (green checkmark)
- This usually takes 5-15 minutes

---

## Method 3: Automatic Index Creation (Development Only)

### Easy Way (During Development)
1. Run your app
2. Navigate to Activity Logs page
3. Try different filters (All, System, Auth, User, Bot)
4. When you see a Firestore error in console, it will include a link
5. Click the link - it takes you directly to create the missing index
6. Click "Create Index" and wait for it to build

**Note**: This method works but requires creating indexes one by one as errors occur.

---

## Verify Indexes Are Working

After indexes are created and built:

1. Open your app
2. Go to Activity Logs
3. Try filtering by different categories
4. Try different time ranges
5. Search for logs

If everything works without console errors, your indexes are properly configured!

---

## Troubleshooting

### Error: "The query requires an index"
**Solution**: The index hasn't been created yet. Use one of the methods above.

### Error: "Index is still building"
**Solution**: Wait a few more minutes. Index building takes time.

### Indexes show "Error" status
**Solution**: 
1. Delete the failed index
2. Recreate it
3. Check that field names match exactly (case-sensitive)

### Query is slow even with indexes
**Solution**:
1. Check you're not fetching too many documents (we limit to 100)
2. Consider adding pagination if needed
3. Review time range filters

---

## Index Maintenance

### When to Update Indexes

You'll need to update indexes if you:
- Add new query patterns to the activity logs
- Add new filter combinations
- Change the sort order

### How to Update

1. Edit `firestore.indexes.json`
2. Run `firebase deploy --only firestore:indexes`
3. Wait for new indexes to build

### Monitoring

Check index usage in Firebase Console:
- Firestore → Usage tab
- Look for slow queries
- Review index hit rates

---

## Cost Considerations

**Good News**: Firestore indexes are FREE to create and maintain!

**What costs money**:
- Document reads (we limit queries to 100 docs)
- Document writes (each log entry)
- Storage (for log documents)

**Cost optimization tips**:
1. Keep the 100 document limit per query
2. Don't log excessively (current implementation is fine)
3. Consider setting up automatic log deletion for old logs (e.g., after 90 days)

---

## Required Indexes Summary

| Index | Fields | Purpose |
|-------|--------|---------|
| 1 | user_id ↑, timestamp ↓ | User's logs sorted by time |
| 2 | user_id ↑, category ↑, timestamp ↓ | User's logs filtered by category |
| 3 | category ↑, timestamp ↓ | All logs filtered by category |
| 4 | timestamp ↓ | All logs sorted by time |

**Legend**: ↑ = Ascending, ↓ = Descending

---

## Next Steps

1. ✅ Choose your preferred method above
2. ✅ Create the indexes
3. ✅ Wait for indexes to build (5-15 minutes)
4. ✅ Test the activity logs in your app
5. ✅ Verify no console errors appear

---

## Questions?

If you encounter issues:
1. Check Firebase Console for index status
2. Look at browser console for specific error messages
3. Verify field names in queries match the indexed fields
4. Ensure you're using the correct collection name: `activity_logs`
