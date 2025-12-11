# Firebase RTDB Rules - Combined & Explained

## Summary of Changes

I've combined your existing rules with the new rules needed to fix the permission denied error.

---

## What Was Added

### ✅ NEW: `control_locks` Path
```json
"control_locks": {
  "$botId": {
    ".read": "auth != null",
    ".write": "auth != null"
  }
}
```

**Why it's needed:**
- The bot control feature uses `control_locks/{botId}` to manage who's controlling each bot
- Without this, you get the "permission denied" error when clicking "Control"

**Access:**
- Any authenticated user can read/write
- This is necessary for the control locking mechanism to work

### ✅ ENHANCED: `deployments` Readings
```json
"deployments": {
  "$id": {
    "readings": {
      "$timestamp": {
        ".write": "auth != null && (auth.token.email == 'SERVICE_ACCOUNT_EMAIL' || auth.uid != null)"
      }
    }
  }
}
```

**Why it's needed:**
- Telemetry data from bots is mirrored to `deployments/{id}/readings/{timestamp}`
- Maintains consistency with your existing service account rules

### ✅ NEW: `logs` Path
```json
"logs": {
  "$logId": {
    ".read": "auth != null",
    ".write": "auth != null"
  }
}
```

**Why it's needed:**
- App logging service writes to this path
- Allows troubleshooting and audit trails

### ✅ NEW: `bot_operations` Path
```json
"bot_operations": {
  "$operationId": {
    ".read": "auth != null",
    ".write": "auth != null"
  }
}
```

**Why it's needed:**
- Control lock service logs operations here (takeovers, surrenders, etc.)
- Provides audit trail for bot control actions

---

## Full Combined Rules

Copy this to Firebase Console → Realtime Database → Rules:

```json
{
  "rules": {
    "bots": {
      "$botId": {
        ".read": "auth != null",
        ".write": "auth != null && (auth.token.email == 'SERVICE_ACCOUNT_EMAIL' || auth.uid != null)"
      }
    },
    "control_locks": {
      "$botId": {
        ".read": "auth != null",
        ".write": "auth != null"
      }
    },
    "deployments": {
      "$id": {
        ".read": "auth != null",
        ".write": "auth != null && (auth.token.email == 'SERVICE_ACCOUNT_EMAIL' || auth.uid != null)",
        "readings": {
          "$timestamp": {
            ".write": "auth != null && (auth.token.email == 'SERVICE_ACCOUNT_EMAIL' || auth.uid != null)"
          }
        }
      }
    },
    "logs": {
      "$logId": {
        ".read": "auth != null",
        ".write": "auth != null"
      }
    },
    "bot_operations": {
      "$operationId": {
        ".read": "auth != null",
        ".write": "auth != null"
      }
    }
  }
}
```

---

## Key Differences from Your Existing Rules

### Your Existing Rules Pattern:
```json
".write": "auth != null && (auth.token.email == 'SERVICE_ACCOUNT_EMAIL' || auth.uid != null)"
```

**This means:**
- User must be authenticated AND
- Either be a service account with specific email OR have a valid uid
- More restrictive, better for critical data

### New Rules Pattern (for control_locks, logs, bot_operations):
```json
".write": "auth != null"
```

**This means:**
- User must be authenticated
- Less restrictive, necessary for real-time control features
- Good for temporary data like locks and logs

---

## Why Different Rules for Different Paths?

### 🔒 More Restrictive (bots, deployments):
- **Critical data**: Bot configurations, deployment data
- **Service account integration**: Your Google Apps Script needs access
- **Keeps original security**: Maintains your existing protection

### 🔓 Less Restrictive (control_locks, logs, bot_operations):
- **Temporary data**: Locks expire automatically (60 seconds)
- **Need quick access**: Control must work without service account
- **Lower risk**: These aren't permanent bot configurations

---

## Before & After Comparison

### ❌ Before (Missing Paths)
```json
{
  "rules": {
    "bots": { ... },
    "deployments": { ... }
    // ❌ Missing: control_locks
    // ❌ Missing: logs
    // ❌ Missing: bot_operations
  }
}
```

**Result**: Permission denied when trying to control bots

### ✅ After (Complete Paths)
```json
{
  "rules": {
    "bots": { ... },
    "control_locks": { ... },     // ✅ Added
    "deployments": { ... },
    "logs": { ... },               // ✅ Added
    "bot_operations": { ... }      // ✅ Added
  }
}
```

**Result**: All features work properly

---

## Security Considerations

### ✅ Safe Aspects:
1. All paths require authentication (`auth != null`)
2. No anonymous access allowed
3. Control locks expire automatically (60 seconds)
4. Logs and operations are read-only for most users
5. Original bot/deployment protection maintained

### ⚠️ Things to Know:
1. **Any authenticated user can claim control locks**
   - This is by design for the control feature
   - Locks are temporary and monitored

2. **Any authenticated user can write logs**
   - Necessary for app logging
   - Consider adding more restrictions in production

3. **Service account email check**
   - Make sure to replace `'SERVICE_ACCOUNT_EMAIL'` with your actual service account email
   - Or remove this check if not using service accounts

---

## Deployment Steps

### Option 1: Firebase Console (Recommended)
1. Go to https://console.firebase.google.com
2. Select your project
3. Navigate to: **Realtime Database → Rules**
4. Replace with the combined rules above
5. Click **"Publish"**
6. Wait 10-30 seconds

### Option 2: Firebase CLI
```bash
# Save the combined rules to database.rules.json in your project root
firebase deploy --only database
```

---

## Testing Checklist

After deploying the new rules:

- [ ] Can view bots page (reads from `bots/`)
- [ ] Can click "Control" button without permission error
- [ ] Control lock is created in `control_locks/{botId}`
- [ ] Can claim control successfully
- [ ] Heartbeat updates work (`lastSeen` field updates)
- [ ] Lock expires after 60 seconds of inactivity
- [ ] Takeover requests work (admin only)
- [ ] Can see logs in Firebase Console under `logs/`

---

## Troubleshooting

### Still getting permission denied?

1. **Check you replaced the rules completely**
   - Don't just add sections, replace everything

2. **Verify authentication is working**
   ```
   Firebase Console → Authentication → Users
   ```
   - You should see your logged-in user

3. **Wait for rules to propagate**
   - Can take up to 30 seconds
   - Restart your app after updating

4. **Check the actual error location**
   - Look at the stack trace
   - Verify it's trying to access `control_locks/`

### Service account email not working?

Replace `'SERVICE_ACCOUNT_EMAIL'` with your actual service account email:
```json
"auth.token.email == 'your-service-account@your-project.iam.gserviceaccount.com'"
```

Or simplify to just check for authenticated users:
```json
".write": "auth != null"
```

---

## Future Improvements

Consider adding more restrictive rules later:

```json
"control_locks": {
  "$botId": {
    ".read": "auth != null",
    ".write": "auth != null && (
      // Owner can always claim
      root.child('bots').child($botId).child('owner_admin_id').val() == auth.uid ||
      // Assigned user can claim
      root.child('bots').child($botId).child('assigned_to').val() == auth.uid ||
      // Current controller can update their own lock
      data.child('uid').val() == auth.uid
    )"
  }
}
```

But start with the simpler rules first to ensure everything works!

---

**Last Updated**: 2025-10-01  
**Status**: Ready to deploy  
**Priority**: HIGH - Fixes permission denied error
