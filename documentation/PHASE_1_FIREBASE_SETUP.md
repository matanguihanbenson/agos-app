# Phase 1: Firebase Setup Guide

## What to Add to Firebase for Live Deployments

---

## 🔥 **Firestore: No Changes Needed!**

Your existing Firestore structure already has everything we need:

### ✅ **schedules** collection (Already exists)
```javascript
schedules/{scheduleId}
{
  name: string,
  bot_id: string,
  bot_name: string,
  river_id: string,
  river_name: string,
  owner_admin_id: string,
  operation_area: { ... },
  docking_point: { ... },
  scheduled_date: timestamp,
  scheduled_end_date: timestamp,
  status: 'scheduled' | 'active' | 'completed' | 'cancelled',  // ← KEY FIELD
  started_at: timestamp | null,
  completed_at: timestamp | null,
  created_at: timestamp,
  updated_at: timestamp
}
```

**What we use**:
- We query `schedules.where('status', '==', 'active')` to find active deployments
- All data is already there! ✅

---

## ⚡ **Firebase RTDB: Check These Fields**

Make sure your RTDB `bots/{botId}` path has these fields:

### **bots/{botId}** structure
```javascript
bots/{botId}
{
  // REQUIRED fields for Phase 1:
  lat: number,              // ← Latitude (e.g., 14.5995)
  lng: number,              // ← Longitude (e.g., 120.9842)
  battery: number,          // ← Battery level 0-100 (e.g., 75)
  status: string,           // ← Status: 'active', 'idle', 'deployed', etc.
  
  // OPTIONAL but recommended:
  trash_collected: number,  // ← Current trash collected in kg
  current_deployment_id: string | null,  // ← Link to deployment
  current_schedule_id: string | null,    // ← Link to schedule
  
  // Other telemetry (nice to have):
  ph_level: number | null,
  temp: number | null,
  turbidity: number | null,
  active: boolean,
  last_updated: number  // Unix timestamp
}
```

---

## 🛠️ **What to Add to RTDB** (If Missing)

### Option 1: Add fields manually in Firebase Console

1. Open **Firebase Console** → **Realtime Database**
2. Navigate to: `bots/{your-bot-id}`
3. Add these fields if missing:

```javascript
{
  "lat": 14.5995,
  "lng": 120.9842,
  "battery": 75,
  "status": "active",
  "trash_collected": 0,
  "current_deployment_id": null,
  "current_schedule_id": null,
  "last_updated": 1727811600000
}
```

### Option 2: Add via your Google Apps Script (Recommended)

Update your Apps Script that writes to RTDB to include these fields:

```javascript
function updateBotStatusBoth_(botId, statusData) {
  // ... existing code ...
  
  // Make sure to include these fields:
  const rtdbUpdate = {
    status: statusData.status,
    lat: statusData.lat || 0,
    lng: statusData.lng || 0,
    battery: statusData.battery || 100,
    trash_collected: statusData.trash_collected || 0,
    current_deployment_id: statusData.current_deployment_id || null,
    current_schedule_id: statusData.current_schedule_id || null,
    active: statusData.status === 'active',
    last_updated: Date.now()
  };
  
  rtdb.child(`bots/${botId}`).update(rtdbUpdate);
}
```

---

## ✅ **Testing the Setup**

### Test 1: Check if RTDB has required fields

1. Go to Firebase Console → Realtime Database
2. Click on `bots` node
3. Select any bot
4. Verify it has: `lat`, `lng`, `battery`, `status`

### Test 2: Test the query

Run this in your Firebase Console or test page:

```javascript
// Firestore query
firebase.firestore()
  .collection('schedules')
  .where('status', '==', 'active')
  .where('owner_admin_id', '==', 'YOUR_ADMIN_ID')
  .get()
  .then(snapshot => {
    console.log('Active schedules:', snapshot.size);
    snapshot.forEach(doc => {
      console.log('Schedule:', doc.id, doc.data());
    });
  });

// RTDB query
firebase.database()
  .ref('bots/YOUR_BOT_ID')
  .once('value')
  .then(snapshot => {
    console.log('Bot data:', snapshot.val());
  });
```

### Test 3: Create a test active schedule

1. Go to Firestore Console → `schedules` collection
2. Find or create a schedule document
3. Set these fields:
   ```javascript
   {
     status: 'active',  // ← Change to 'active'
     owner_admin_id: 'YOUR_USER_ID',
     bot_id: 'YOUR_BOT_ID',
     bot_name: 'Test Bot',
     river_id: 'RIVER_ID',
     river_name: 'Test River',
     // ... other fields
   }
   ```
4. Open your app dashboard
5. You should see it appear in "Live River Deployments"! 🎉

---

## 📝 **Field Mapping Reference**

| Dashboard Display | Source | Field Name |
|------------------|--------|------------|
| Schedule Name | Firestore schedules | `name` |
| Bot Name | Firestore schedules | `bot_name` |
| River Name | Firestore schedules | `river_name` |
| Status Badge | RTDB bots | `status` |
| Location (Lat/Lng) | RTDB bots | `lat`, `lng` |
| Battery % | RTDB bots | `battery` |
| Trash Collected | RTDB bots | `trash_collected` |
| Started Time | Firestore schedules | `scheduled_date` |

---

## 🚨 **Common Issues**

### Issue: "No active deployments" even though I have schedules

**Solution**:
1. Check schedule `status` field is exactly `'active'` (lowercase)
2. Check `owner_admin_id` matches your logged-in user ID
3. Check you're logged in as admin

### Issue: Bot shows but no location/battery

**Solution**:
1. Check RTDB `bots/{botId}` has `lat`, `lng`, `battery` fields
2. Check values are numbers, not strings
3. Check bot_id in schedule matches bot_id in RTDB

### Issue: Permission denied when reading RTDB

**Solution**:
1. Check your RTDB rules allow authenticated reads
2. See `database.rules.combined.json` for correct rules
3. Make sure you're authenticated

---

## 🎯 **Quick Setup Checklist**

**Firestore**:
- [x] `schedules` collection exists
- [ ] At least one schedule with `status: 'active'`
- [ ] Schedule has valid `bot_id`, `river_id`
- [ ] Schedule has `owner_admin_id` matching your user

**RTDB**:
- [ ] `bots/{botId}` path exists
- [ ] Bot has `lat`, `lng` fields (numbers)
- [ ] Bot has `battery` field (0-100)
- [ ] Bot has `status` field (string)
- [ ] RTDB security rules allow authenticated read

**App**:
- [ ] User is logged in
- [ ] User role is 'admin'
- [ ] Dashboard page uses `LiveDeploymentsWidget`

---

## 📊 **Example Complete Bot Data**

Here's what a complete bot entry should look like in RTDB:

```javascript
bots/bot-123
{
  "active": true,
  "battery": 85,
  "current_deployment_id": "deployment-456",
  "current_schedule_id": "schedule-789",
  "last_updated": 1727811600000,
  "lat": 14.5995,
  "lng": 120.9842,
  "ph_level": 7.2,
  "status": "active",
  "temp": 25.5,
  "trash_collected": 2.5,
  "turbidity": 10.2
}
```

---

## 🎉 **Success Criteria**

You'll know Phase 1 is working when:

1. ✅ Dashboard shows "Live River Deployments" section
2. ✅ Active schedules appear as cards
3. ✅ Cards show real-time location from RTDB
4. ✅ Cards show real-time battery from RTDB
5. ✅ Cards show bot and river names
6. ✅ "LIVE" indicator is green and visible
7. ✅ Data updates automatically (no refresh needed)

---

## 📞 **Need Help?**

If you encounter issues:

1. Check browser console for errors
2. Check Firebase Console → Firestore → schedules
3. Check Firebase Console → RTDB → bots
4. Verify RTDB security rules
5. Verify user is authenticated

---

**Last Updated**: 2025-10-01  
**Version**: Phase 1  
**Status**: Ready to test
