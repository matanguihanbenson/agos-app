# 🚀 Quick Start: Activity Logs Indexing

## Fastest Method (Recommended)

### Option A: Firebase CLI (Automated)

```bash
# 1. Install Firebase CLI (if not installed)
npm install -g firebase-tools

# 2. Login
firebase login

# 3. Deploy indexes
firebase deploy --only firestore:indexes
```

⏱️ **Time**: ~2 minutes + 5-15 minutes build time

---

### Option B: Firebase Console (Manual)

1. Go to https://console.firebase.google.com
2. Select your project → **Firestore Database** → **Indexes**
3. Click **Create Index** and add these 4 indexes:

**Index 1:**
- Collection: `activity_logs`
- Fields: `user_id` (↑), `timestamp` (↓)

**Index 2:**
- Collection: `activity_logs`
- Fields: `user_id` (↑), `category` (↑), `timestamp` (↓)

**Index 3:**
- Collection: `activity_logs`
- Fields: `category` (↑), `timestamp` (↓)

**Index 4:**
- Collection: `activity_logs`
- Fields: `timestamp` (↓)

⏱️ **Time**: ~5 minutes + 5-15 minutes build time per index

---

### Option C: Lazy Method (Click Links)

1. Run your app
2. Open Activity Logs page
3. Click different filter categories
4. When errors appear in console, **click the index creation link**
5. Wait for each index to build

⏱️ **Time**: ~10 minutes total (as you encounter errors)

---

## ✅ Verification

After indexes are built (status shows "Enabled"):

1. Open your app
2. Navigate to Activity Logs
3. Test all filters: All, System, Auth, User, Bot
4. Change time ranges
5. Search for logs
6. No errors = Success! ✨

---

## 📁 Files Created

- `firestore.indexes.json` - Index configuration
- `FIRESTORE_INDEX_SETUP.md` - Detailed documentation

---

## 💡 Pro Tip

Use **Option A** (Firebase CLI) for instant deployment of all indexes at once!
