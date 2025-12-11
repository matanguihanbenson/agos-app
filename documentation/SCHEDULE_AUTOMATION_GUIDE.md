# Schedule Automation Guide

## Overview

Your AGOS app now has **full real-time schedule management** with automatic status transitions powered by Google Apps Script running in the background.

## How It Works

### 1. Real-Time Flutter App Updates

The schedule page now uses Firestore snapshots to instantly reflect changes:

- **Real-time streams**: Uses `schedulesStreamProvider` that watches Firestore changes
- **Instant updates**: Any status change in Firestore immediately updates the UI
- **No manual refresh needed**: Changes appear automatically without closing/reopening the app

**Key changes made:**
- Added `watchSchedulesByOwner()` method in `ScheduleService` 
- Created `schedulesStreamProvider` in `schedule_provider.dart`
- Updated `SchedulePage` to use `ref.watch(schedulesStreamProvider)`

### 2. Background Script Automation (Google Apps Script)

A Google Apps Script runs every minute to automatically manage schedule lifecycles:

**What it does:**
- **Scheduled → Active**: When `scheduled_date` <= current time
- **Active → Completed**: When `scheduled_end_date` <= current time
- **Telemetry aggregation**: Pulls data from Realtime Database on completion
- **RTDB sync**: Updates bot status and deployment records

**Script location:** Google Apps Script project (accessible at script.google.com)

## Running the Background Script

### Do you need to run it manually?

**No!** Once set up, it runs automatically. But here's how it works:

### One-Time Setup (Already Done)

1. **Service Account Created**: With Firestore and RTDB permissions
2. **Script Properties Configured**:
   - `GAS_FIREBASE_PROJECT_ID`
   - `GAS_FIREBASE_DATABASE_URL`
   - `GAS_SA_CLIENT_EMAIL`
   - `GAS_SA_PRIVATE_KEY`
3. **Time-Driven Trigger Installed**: Runs `tick()` every 1 minute

### How to Check If It's Running

1. Go to [script.google.com](https://script.google.com/)
2. Open your AGOS Schedule Automation project
3. View **Executions** (left sidebar) to see run history
4. Each minute you should see a new execution

### Manual Trigger (For Testing)

You can manually run `tick()` from the Apps Script editor:
1. Open the script
2. Select `tick` function from dropdown
3. Click **Run**
4. Check **Execution log** for output

## Database Schema Alignment

The script is configured to match your exact Firestore/RTDB field names:

### Firestore Fields (snake_case)
- `scheduled_date` (start time)
- `scheduled_end_date` (end time)
- `bot_id`
- `deployment_id`
- `started_at`
- `completed_at`
- `status`

### RTDB Bot Fields
- `status`
- `current_schedule_id`
- `current_deployment_id`
- `last_updated`

### RTDB Telemetry Fields
- `ph_level`
- `turbidity`
- `temp`
- `trash_collected`
- `battery_pct`

## Testing the Real-Time Updates

1. **Create a schedule** with start time 1 minute in the future
2. **Wait and watch** the schedule page - no need to refresh!
3. **Status changes automatically**:
   - Initially: **Scheduled** (grey)
   - At start time: **Active** (blue)
   - At end time: **Completed** (green)

## Monitoring Script Execution

### View Logs
1. Apps Script Editor → **Executions** tab
2. Shows:
   - Execution time
   - Status (success/error)
   - Logs (console output)

### Example Log Output
```
9:25:29 PM - Found 1 scheduled items
9:25:29 PM - Activated schedule 7Sf4l... (deployment 7Sf4l...)
9:25:29 PM - Found 0 active items
9:25:29 PM - tick finished in 779 ms
```

## Troubleshooting

### Schedule Not Transitioning?

**Check timezone:**
- Firestore timestamps are in UTC
- Your app might display in local time (PHT = UTC+8)
- The script compares in UTC

**Verify in Firestore console:**
1. Open schedule document
2. Check `scheduled_date` timestamp value
3. Compare with current UTC time

### Script Errors?

**401 Unauthorized on RTDB:**
- Check Realtime Database Rules allow authenticated writes
- Verify service account has Firebase Realtime Database Admin role

**Token exchange failed:**
- Verify `GAS_SA_PRIVATE_KEY` is complete PEM format
- Check service account JSON hasn't expired

**Field not found errors:**
- Verify field names in `CFG.FIELDS` match your Firestore schema
- Check RTDB telemetry keys in `CFG.TELEMETRY`

## Performance Notes

- **Script execution**: ~500-1000ms per run
- **Firestore queries**: Limited to 200 schedules per run (configurable via `BATCH_LIMIT`)
- **Real-time streams**: Minimal overhead, only updates on actual changes
- **No polling**: Flutter app uses Firestore snapshots, not periodic queries

## Security

- Service account credentials stored securely in Script Properties (not in code)
- Firestore/RTDB rules should restrict write access
- Script authenticates using service account JWT
- Access tokens cached for 55 minutes to reduce auth overhead

## Future Enhancements

Possible additions:
- Email/SMS notifications on schedule start/completion
- Cloud Functions alternative (for sub-minute precision)
- Webhook integration for external systems
- Extended telemetry analysis and reporting
- Multi-region deployment scheduling

## Summary

✅ **Flutter app**: Real-time UI updates via Firestore streams  
✅ **Background script**: Automatic status transitions every minute  
✅ **No manual intervention**: Schedules activate and complete automatically  
✅ **Telemetry sync**: Data aggregated from RTDB to Firestore on completion  

Your schedules are now fully autonomous! 🚀
