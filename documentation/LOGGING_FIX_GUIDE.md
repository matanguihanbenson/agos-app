# Logging System Fix Guide

## ✅ Issues Fixed

### 1. Auth Logs Not Showing
**Problem:** Login events weren't being logged properly because the code wasn't fetching the user's name and using the proper logging methods.

**Fixed in:** `lib/core/services/auth_service.dart`
- ✅ `signInWithEmailAndPassword` now calls `logLogin()` with user name
- ✅ `signOut` now calls `logLogout()` with user name  
- ✅ `reauthenticateAndUpdatePassword` now calls `logPasswordChanged()` with user name
- ✅ `sendPasswordResetEmail` now calls `logPasswordResetRequested()`
- ✅ Failed login attempts now call `logLoginFailed()`

### 2. All Logs Showing as "System" Category
**Problem:** Services were using the legacy `logEvent()` method which defaults to "system" category.

**Partially Fixed:** Updated `bot_service.dart` to remove generic logging (it should be done at page level with user context)

## 🔧 Remaining Fixes Needed

### Fix 1: Add Proper Logging to User Creation
**File:** `lib/features/management/pages/add_user_page.dart`

Add logging after successful user creation (around line 70):

```dart
await userService.create(newUser);

// Add this logging
final loggingService = LoggingService();
await loggingService.logUserCreated(
  creatorUserId: currentUser.id,
  creatorUserName: currentUser.fullName,
  newUserId: newUser.id, // You'll need to get the created user ID
  newUserName: newUser.fullName,
  newUserEmail: newUser.email,
  role: newUser.role,
);

if (mounted) {
  SnackbarUtil.showSuccess(context, 'User created successfully!');
```

### Fix 2: Add Proper Logging to User Updates  
**File:** `lib/features/management/pages/edit_user_page.dart`

Add logging after successful user update:

```dart
await userService.update(widget.user.id, updates);

// Add this logging
final currentUser = ref.read(authProvider).userProfile;
if (currentUser != null) {
  final loggingService = LoggingService();
  await loggingService.logUserUpdated(
    updaterUserId: currentUser.id,
    updaterUserName: currentUser.fullName,
    targetUserId: widget.user.id,
    targetUserName: widget.user.fullName,
    changes: updates,
  );
}
```

### Fix 3: Add Logging to Bot Registration
**File:** Search for bot registration pages (QR scan, manual entry, etc.)

After bot is successfully registered:

```dart
final loggingService = LoggingService();
await loggingService.logBotRegistered(
  userId: currentUser.id,
  userName: currentUser.fullName,
  botId: botId,
  botName: botName,
  serialNumber: serialNumber,
);
```

### Fix 4: Add Logging to Bot Assignment
**Files:** `lib/features/bots/pages/assign_bot_page.dart`, `reassign_bot_page.dart`

After bot is assigned:

```dart
final loggingService = LoggingService();
await loggingService.logBotAssigned(
  userId: currentUser.id,
  userName: currentUser.fullName,
  botId: botId,
  botName: botName,
  operatorId: operatorId,
  operatorName: operatorName,
);
```

For reassignment:

```dart
await loggingService.logBotReassigned(
  userId: currentUser.id,
  userName: currentUser.fullName,
  botId: botId,
  botName: botName,
  oldOperatorId: oldOperatorId,
  oldOperatorName: oldOperatorName,
  newOperatorId: newOperatorId,
  newOperatorName: newOperatorName,
);
```

### Fix 5: Add Logging to Schedule Creation
**File:** `lib/features/schedule/pages/create_schedule_page.dart`

After schedule is created:

```dart
final loggingService = LoggingService();
await loggingService.logScheduleCreated(
  userId: currentUser.id,
  userName: currentUser.fullName,
  scheduleId: scheduleId,
  scheduleName: scheduleName,
  botId: botId,
  botName: botName,
  scheduledTime: scheduledTime,
);
```

### Fix 6: Add Logging to Deployment Operations
**File:** Wherever deployments are started/completed

```dart
// On deployment start
await loggingService.logDeploymentStarted(
  userId: currentUser.id,
  userName: currentUser.fullName,
  botId: botId,
  botName: botName,
  riverId: riverId,
  riverName: riverName,
);

// On deployment complete
await loggingService.logDeploymentCompleted(
  userId: currentUser.id,
  userName: currentUser.fullName,
  botId: botId,
  botName: botName,
  riverId: riverId,
  riverName: riverName,
);
```

### Fix 7: Add Logging to Bot Updates/Edits
**File:** `lib/features/bots/pages/edit_bot_page.dart`

After bot is updated:

```dart
// You'll need a logBotUpdated method in LoggingService
final loggingService = LoggingService();
await loggingService.logActivity(ActivityLogModel(
  id: '',
  category: ActivityLogCategory.bot,
  type: ActivityLogType.botUpdated,
  severity: ActivityLogSeverity.info,
  title: 'Bot Updated',
  description: '$userName updated bot "$botName"',
  userId: currentUser.id,
  userName: currentUser.fullName,
  botId: botId,
  botName: botName,
  metadata: updates,
  timestamp: DateTime.now(),
  platform: Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'web'),
));
```

## 📋 Quick Reference: Which Method to Use

| Operation | Method to Call | Category |
|-----------|---------------|----------|
| User logs in | `logLogin()` | AUTH |
| User logs out | `logLogout()` | AUTH |
| Password changed | `logPasswordChanged()` | AUTH |
| Password reset requested | `logPasswordResetRequested()` | AUTH |
| User created | `logUserCreated()` | USER |
| User updated | `logUserUpdated()` | USER |
| User deleted | `logUserDeleted()` | USER |
| Profile updated | `logProfileUpdated()` | USER |
| Bot registered | `logBotRegistered()` | BOT |
| Bot unregistered | `logBotUnregistered()` | BOT |
| Bot assigned | `logBotAssigned()` | BOT |
| Bot reassigned | `logBotReassigned()` | BOT |
| Bot unassigned | `logBotUnassigned()` | BOT |
| Schedule created | `logScheduleCreated()` | BOT |
| Schedule canceled | `logScheduleCanceled()` | BOT |
| Deployment started | `logDeploymentStarted()` | BOT |
| Deployment completed | `logDeploymentCompleted()` | BOT |
| System error | `logError()` | SYSTEM |
| System warning | `logSystemWarning()` | SYSTEM |

## 🎯 Testing Checklist

After implementing the fixes, test each operation and verify logs appear with the correct category:

- [ ] Login shows in activity logs with AUTH category
- [ ] Logout shows in activity logs with AUTH category
- [ ] Creating a user shows in activity logs with USER category
- [ ] Editing a user shows in activity logs with USER category
- [ ] Registering a bot shows in activity logs with BOT category
- [ ] Assigning a bot shows in activity logs with BOT category
- [ ] Creating a schedule shows in activity logs with BOT category
- [ ] Starting a deployment shows in activity logs with BOT category

## 💡 Important Notes

1. **Always get user context first:** Most logging methods need userId and userName, so fetch the current user profile before logging.

2. **Use proper log types:** Each operation has its own ActivityLogType enum value for consistency.

3. **Include relevant metadata:** Pass bot names, email addresses, and other relevant info to make logs more useful.

4. **Handle errors gracefully:** Wrap logging calls in try-catch to prevent logging failures from breaking your app flow.

5. **Platform info:** The platform field is automatically populated in LoggingService based on the device (android/ios/web).

## 🔍 Debugging Tips

If logs still aren't showing:

1. Check Firestore console to see if documents are being created in `activity_logs` collection
2. Verify the user profile exists and has firstName/lastName populated
3. Check console for any logging errors
4. Ensure you're importing `LoggingService` from the correct path
5. Make sure you're passing all required parameters to logging methods

---

**Status:** Auth logging is fixed ✅, bot/user logging needs implementation in UI pages ⏳
