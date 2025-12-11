# Updated Apps Script - Setup Guide

## What Changed

The updated script now updates bot status in **BOTH** Firestore AND Realtime Database, so bot cards in your Flutter app will update in real-time.

### Key Changes:
1. **New Function**: `updateBotStatusBoth_()` - Updates bot status in both databases
2. **Updated**: `processScheduledToActive_()` - Now calls the new function
3. **Updated**: `completeDeploymentNow_()` - Now calls the new function
4. **New Config**: Added `CFG.FS.BOTS` and `CFG.FIELDS.bot` for Firestore bot updates

## How to Update

### Option 1: Replace Entire Script (Recommended)
1. Go to your Apps Script project at script.google.com
2. Select all code in `Code.gs`
3. Delete it
4. Copy **ALL** code from `UPDATED_APPS_SCRIPT.js` in this directory
5. Paste into `Code.gs`
6. Click **Save** (💾 icon)
7. Run `tick()` manually to test

### Option 2: Partial Update (If you made custom changes)
If you customized the original script, you can manually add just the new parts:

#### 1. Update CFG (lines 20-48)
Add to your CFG object:
```javascript
FS: {
  SCHEDULES: 'schedules',
  DEPLOYMENTS: 'deployments',
  BOTS: 'bots'  // ADD THIS
},
```

And add this in FIELDS:
```javascript
bot: {
  status: 'status',
  updatedAt: 'updated_at'
}
```

#### 2. Add the new function (after line 220)
```javascript
function updateBotStatusBoth_(botId, status, scheduleId, deploymentId, token) {
  const nowIso = new Date().toISOString();
  
  // Update Firestore bot status
  const firestoreBotUrl = `https://firestore.googleapis.com/v1/projects/${CFG.PROJECT_ID}/databases/(default)/documents/${CFG.FS.BOTS}/${encodeURIComponent(botId)}?updateMask.fieldPaths=${CFG.FIELDS.bot.status}&updateMask.fieldPaths=${CFG.FIELDS.bot.updatedAt}`;
  const firestoreBotBody = {
    fields: {
      [CFG.FIELDS.bot.status]: { stringValue: status },
      [CFG.FIELDS.bot.updatedAt]: { timestampValue: nowIso }
    }
  };
  http_(firestoreBotUrl, 'patch', firestoreBotBody, token);
  console.log(`Updated Firestore bot ${botId} status to ${status}`);
  
  // Update RTDB bot status and pointers
  const rtdbUpdate = {
    [CFG.RT.botStatusKey]: status,
    [CFG.RT.botCurrentScheduleKey]: scheduleId,
    [CFG.RT.botCurrentDeploymentKey]: deploymentId,
    last_updated: nowIso
  };
  rtdbPatch_(`/${CFG.RT.BOTS_ROOT}/${botId}`, rtdbUpdate, token);
  console.log(`Updated RTDB bot ${botId} status to ${status}`);
}
```

#### 3. Update processScheduledToActive_ (around line 145)
Replace the RTDB bot update section:
```javascript
// OLD CODE (DELETE THIS):
if (botId) {
  rtdbPatch_(`/${CFG.RT.BOTS_ROOT}/${botId}`, {
    [CFG.RT.botStatusKey]: 'active',
    [CFG.RT.botCurrentScheduleKey]: scheduleId,
    [CFG.RT.botCurrentDeploymentKey]: deploymentId,
    last_updated: now.toISOString()
  }, token);
}

// NEW CODE (USE THIS):
if (botId) {
  updateBotStatusBoth_(botId, 'active', scheduleId, deploymentId, token);
}
```

#### 4. Update completeDeploymentNow_ (around line 215)
Replace the RTDB cleanup section:
```javascript
// OLD CODE (DELETE THIS):
if (botId) {
  rtdbPatch_(`/${CFG.RT.BOTS_ROOT}/${botId}`, {
    [CFG.RT.botStatusKey]: 'idle',
    [CFG.RT.botCurrentScheduleKey]: null,
    [CFG.RT.botCurrentDeploymentKey]: null,
    last_updated: nowIso
  }, token);
}

// NEW CODE (USE THIS):
if (botId) {
  updateBotStatusBoth_(botId, 'idle', null, null, token);
}
```

## Testing

After updating:

1. **Manual Test**:
   - Run `tick()` manually in Apps Script editor
   - Check the execution log for:
     - "Updated Firestore bot X status to Y"
     - "Updated RTDB bot X status to Y"

2. **Live Test**:
   - Create a schedule in your Flutter app starting in 1 minute
   - Watch the bot card - it should change to "Scheduled" then "Active" then "Idle" automatically
   - No need to close/reopen the app!

## Troubleshooting

### Error: "Property 'BOTS' doesn't exist"
- Make sure you added `BOTS: 'bots'` to CFG.FS

### Bot status not updating in app
- Verify the script logs show "Updated Firestore bot..."
- Check your bot document ID in the schedule matches the actual bot ID
- Ensure your Flutter app is using `botsStreamProvider` (real-time streams)

### Permission errors
- The service account already has Firestore access
- No new permissions needed!

## What This Fixes

✅ **Bot cards now update in real-time** when:
- A schedule is created (bot → "Scheduled")
- Schedule starts (bot → "Active")  
- Schedule completes (bot → "Idle")

✅ **No app restart needed** - changes appear instantly via Firestore streams

✅ **Works for all users** - Admin and Field Operators see updates simultaneously

## Next Steps

After updating the script:
1. Test with a quick schedule (1-2 minute duration)
2. Verify bot cards update automatically
3. Check deployment history appears in bot details

Need help? Check the logs in Apps Script → Executions tab.
