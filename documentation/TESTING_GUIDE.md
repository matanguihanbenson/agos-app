# Testing Guide - Real-Time RTDB Updates

## Quick Test Steps

### 1. Test Real-Time Status Updates

1. **Start the app** and navigate to the Bots page
2. **Open Firebase Console** → Realtime Database
3. **Navigate to**: `bots/{your-bot-id}/status`
4. **Change the value** from `idle` to `deployed` (or any other status)
5. **Watch the UI** - The bot card should update immediately with the new status color and label

### 2. Test Real-Time Battery Updates

1. Keep the Bots page open
2. In Firebase Console → RTDB: `bots/{your-bot-id}/battery`
3. Change the value (e.g., from `75` to `50`)
4. The battery indicator should update immediately in the UI

### 3. Test Real-Time Location Updates

1. Keep the Bots page open
2. In Firebase Console → RTDB: 
   - `bots/{your-bot-id}/lat` → change latitude
   - `bots/{your-bot-id}/lng` → change longitude
3. The location should update in real-time (may need to refresh geocoding)

### 4. Test Assigned User Display

1. In Firestore Console → `bots` collection
2. Edit a bot document and set `assigned_to` to a valid user ID
3. Refresh the bots page
4. The bot card should show the actual user's name (not "Unknown User")

### 5. Test Bluetooth Simulation Mode

1. Navigate to Bot Control page (click "Control" button on any bot card)
2. You should see:
   - Quick scanning animation (~800ms)
   - Automatic connection to simulated device
   - "Connected" state with joystick enabled
3. Toggle manual mode ON/OFF
4. Try moving the joystick (won't send real commands in simulation mode)

---

## Expected Behavior

### ✅ Real-Time Updates Should:
- Update **instantly** when RTDB data changes (no page refresh needed)
- Work for **all fields**: status, battery, location, active, etc.
- Continue working even if you switch tabs and come back
- Clean up listeners when you navigate away

### ✅ Assigned User Should:
- Show "Loading..." briefly when fetching from Firestore
- Display the full name once loaded
- Cache the result to avoid repeated fetches
- Fall back to "Unknown User" if user doesn't exist

### ✅ Bluetooth Simulation Should:
- Connect quickly without real Bluetooth hardware
- Show "(Simulated)" in device name
- Allow manual mode toggle
- Enable joystick controls when connected

---

## Troubleshooting

### Real-Time Updates Not Working?

1. **Check RTDB Connection**:
   ```
   Firebase Console → Realtime Database → Check if data exists
   ```

2. **Check Console Logs**:
   - Look for "DEBUG: Bot doc..." messages
   - Look for "DEBUG: Realtime data for..." messages

3. **Verify Bot ID**:
   - Make sure the bot ID in Firestore matches the path in RTDB
   - Path should be: `bots/{firestore-bot-doc-id}`

4. **Check Firebase Rules**:
   - Ensure RTDB read rules allow access
   - Check if authentication is required

### "Unknown User" Still Showing?

1. **Check User Exists**:
   ```
   Firestore → users → {user-id}
   ```

2. **Verify Fields**:
   - User document should have `firstName` and `lastName` fields
   - Fields should not be empty

3. **Check Bot Assignment**:
   ```
   Firestore → bots → {bot-id} → assigned_to field
   ```

### Bluetooth Simulation Not Working?

1. **Verify Simulation Mode is Enabled**:
   ```dart
   // In bot_control_page.dart
   static const bool _simulationMode = true;
   
   // In bot_control_provider.dart
   static const bool simulationMode = true;
   ```

2. **Check Console Logs**:
   - Look for "Simulation mode: ..." messages

3. **Try Reconnecting**:
   - Go back and navigate to control page again

---

## Known Limitations

1. **RTDB Updates Frequency**: 
   - Very rapid updates (> 10/second) might cause UI jank
   - Consider adding debouncing if needed

2. **Firestore User Cache**:
   - User names are fetched once per bot card render
   - Won't update if user name changes in Firestore (requires page refresh)

3. **Simulation Mode**:
   - Commands sent via joystick are not actually transmitted
   - Battery level is hardcoded to 75 in simulation
   - No actual telemetry data in simulation mode

---

## Production Checklist

Before deploying to production:

- [ ] Set simulation mode to `false` in both files
- [ ] Remove or comment out debug `print` statements
- [ ] Test with real Bluetooth hardware
- [ ] Verify RTDB security rules are properly configured
- [ ] Test with multiple concurrent users
- [ ] Verify memory cleanup (no leaks from RTDB listeners)
- [ ] Test offline behavior (RTDB connection loss)

---

## Firebase RTDB Structure

For reference, your RTDB structure should look like:

```
bots/
  {bot-id}/
    status: "idle" | "deployed" | "active" | "scheduled" | "recalling" | "maintenance"
    battery: 75
    lat: 14.5995
    lng: 120.9842
    active: true
    ph_level: 7.2
    temp: 25.5
    turbidity: 10.2
    trash_collected: 5.5
    current_deployment_id: "deployment-123"
    last_updated: 1234567890
```

---

**Last Updated**: 2025-10-01  
**Version**: 1.0
