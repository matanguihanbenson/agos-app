# User Roles & Permissions

## 👥 Overview

AGOS implements a role-based access control (RBAC) system with two primary user roles: **Admin** and **Field Operator**. Each role has specific permissions and access levels within the application.

## 🔐 User Roles

### 1. Administrator (Admin)

**Primary Responsibilities**:
- System administration and management
- User account creation and management
- Bot registration and assignment
- Organization management
- System-wide monitoring and analytics

**Key Capabilities**:
- Full access to all system features
- Create, edit, and delete users
- Register and manage all bots
- Create and manage organizations
- Assign bots to field operators
- View system-wide analytics and reports
- Access to all real-time data

### 2. Field Operator

**Primary Responsibilities**:
- Operate assigned bots
- Monitor bot performance and status
- Report bot issues and maintenance needs
- Execute assigned tasks and missions

**Key Capabilities**:
- View only assigned bots
- Control assigned bots
- Monitor real-time bot status
- Submit status reports
- View personal profile and settings
- Access to limited analytics (assigned bots only)

## 🛡️ Permission Matrix

| Feature | Admin | Field Operator |
|---------|-------|----------------|
| **Authentication** |
| Sign In/Out | ✅ | ✅ |
| Change Password | ✅ | ✅ |
| **User Management** |
| View All Users | ✅ | ❌ |
| Create Users | ✅ | ❌ |
| Edit Users | ✅ | ❌ |
| Delete Users | ✅ | ❌ |
| View Own Profile | ✅ | ✅ |
| Edit Own Profile | ✅ | ✅ |
| **Bot Management** |
| View All Bots | ✅ | ❌ |
| View Assigned Bots | ✅ | ✅ |
| Register Bots | ✅ | ❌ |
| Edit Bot Details | ✅ | ❌ |
| Delete Bots | ✅ | ❌ |
| Assign Bots | ✅ | ❌ |
| Control Bots | ✅ | ✅ |
| **Organization Management** |
| View All Organizations | ✅ | ❌ |
| Create Organizations | ✅ | ❌ |
| Edit Organizations | ✅ | ❌ |
| Delete Organizations | ✅ | ❌ |
| **Map & Monitoring** |
| View All Bot Locations | ✅ | ❌ |
| View Assigned Bot Locations | ✅ | ✅ |
| Real-time Monitoring | ✅ | ✅ |
| **Notifications** |
| View All Notifications | ✅ | ❌ |
| View Own Notifications | ✅ | ✅ |
| **Settings** |
| System Settings | ✅ | ❌ |
| App Settings | ✅ | ✅ |

## 🔒 Access Control Implementation

### Database Level Security

#### Firestore Security Rules
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users collection
    match /users/{userId} {
      allow read, write: if request.auth != null && 
        (request.auth.uid == userId || 
         get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin');
    }
    
    // Bots collection
    match /bots/{botId} {
      allow read, write: if request.auth != null && 
        (resource.data.owner_admin_id == request.auth.uid ||
         resource.data.assigned_to == request.auth.uid);
    }
    
    // Organizations collection
    match /organizations/{orgId} {
      allow read, write: if request.auth != null && 
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
  }
}
```

#### Realtime Database Security Rules
```javascript
{
  "rules": {
    "bots": {
      "$botId": {
        ".read": "auth != null && (data.owner_admin_id == auth.uid || data.assigned_to == auth.uid)",
        ".write": "auth != null && (data.owner_admin_id == auth.uid || data.assigned_to == auth.uid)"
      }
    }
  }
}
```

### Application Level Security

#### Role-Based UI Rendering
```dart
// Example: Show different navigation items based on role
Widget buildNavigation() {
  final user = ref.watch(authProvider).userProfile;
  
  if (user?.role == 'admin') {
    return AdminNavigation();
  } else {
    return FieldOperatorNavigation();
  }
}
```

#### Data Filtering
```dart
// Example: Filter bots based on user role
Future<List<BotModel>> loadBots() async {
  final user = ref.read(authProvider).userProfile;
  
  if (user?.role == 'admin') {
    return await botService.getBotsByOwnerWithRealtimeData(user.id);
  } else {
    return await botService.getBotsAssignedToUserWithRealtimeData(user.id);
  }
}
```

## 🎯 Role-Specific Features

### Admin Features

#### 1. User Management
- **Create Users**: Add new field operators to the system
- **Edit Users**: Modify user information and permissions
- **Deactivate Users**: Temporarily disable user accounts
- **Archive Users**: Permanently remove users from active use
- **Bulk Operations**: Manage multiple users simultaneously

#### 2. Bot Management
- **Bot Registration**: Register new bots with unique identifiers
- **Bot Assignment**: Assign bots to specific field operators
- **Bot Reassignment**: Transfer bot ownership between operators
- **Bot Unregistration**: Remove bots from the system
- **Bulk Bot Operations**: Manage multiple bots simultaneously

#### 3. Organization Management
- **Create Organizations**: Set up new organizational units
- **Manage Members**: Add/remove users from organizations
- **View Statistics**: Monitor organization performance
- **Bot Distribution**: Assign bots to organizations

#### 4. System Monitoring
- **Real-time Dashboard**: Monitor all system activities
- **Analytics**: View performance metrics and trends
- **System Health**: Monitor bot status and connectivity
- **Alert Management**: Configure and manage system alerts

### Field Operator Features

#### 1. Bot Control
- **Assigned Bot View**: See only bots assigned to them
- **Real-time Status**: Monitor bot performance and location
- **Control Interface**: Send commands to assigned bots
- **Status Reporting**: Submit bot status updates

#### 2. Task Management
- **Assigned Tasks**: View tasks assigned by administrators
- **Task Execution**: Execute assigned missions
- **Progress Tracking**: Monitor task completion status
- **Issue Reporting**: Report problems or maintenance needs

#### 3. Personal Dashboard
- **Performance Metrics**: View personal performance data
- **Bot History**: Access historical bot data
- **Settings**: Manage personal preferences
- **Notifications**: Receive relevant alerts and updates

## 🔄 Role Transitions

### Admin to Field Operator
- **Not Supported**: Admins cannot be downgraded to field operators
- **Reason**: Admin privileges are permanent for security reasons

### Field Operator to Admin
- **Manual Process**: Requires existing admin to promote user
- **Steps**:
  1. Admin accesses user management
  2. Selects field operator
  3. Changes role to "admin"
  4. User gains admin privileges immediately

### User Deactivation
- **Temporary**: User account is disabled but not deleted
- **Data Retention**: All user data is preserved
- **Reactivation**: Account can be reactivated by admin

### User Archiving
- **Permanent**: User account is permanently disabled
- **Data Retention**: User data is marked as archived
- **No Reactivation**: Archived users cannot be reactivated

## 🚨 Security Considerations

### Data Isolation
- **Field Operators**: Can only access their assigned bots
- **Admins**: Can access all data within their scope
- **Cross-tenant**: No data sharing between different admin accounts

### Audit Trail
- **User Actions**: All user actions are logged
- **Data Changes**: All data modifications are tracked
- **Access Logs**: Login/logout events are recorded
- **Security Events**: Suspicious activities are flagged

### Session Management
- **Token Expiration**: JWT tokens expire after 24 hours
- **Auto-logout**: Inactive sessions are automatically terminated
- **Multi-device**: Users can be logged in on multiple devices
- **Session Invalidation**: Admins can force logout users

## 📊 Role-Based Analytics

### Admin Analytics
- **System Overview**: Total users, bots, and organizations
- **Performance Metrics**: Bot efficiency and success rates
- **User Activity**: Login patterns and usage statistics
- **Resource Utilization**: System resource consumption

### Field Operator Analytics
- **Personal Performance**: Individual bot operation metrics
- **Task Completion**: Mission success rates
- **Bot Health**: Assigned bot status and maintenance needs
- **Time Tracking**: Hours spent on bot operations

## 🔧 Configuration

### Role Permissions
```dart
class RolePermissions {
  static const Map<String, List<String>> permissions = {
    'admin': [
      'user.create',
      'user.read',
      'user.update',
      'user.delete',
      'bot.create',
      'bot.read',
      'bot.update',
      'bot.delete',
      'organization.create',
      'organization.read',
      'organization.update',
      'organization.delete',
      'system.monitor',
      'system.analytics',
    ],
    'field_operator': [
      'bot.read.assigned',
      'bot.control.assigned',
      'task.read.assigned',
      'task.execute.assigned',
      'profile.read',
      'profile.update',
    ],
  };
}
```

### Feature Flags
```dart
class FeatureFlags {
  static bool canAccessFeature(String feature, String role) {
    switch (feature) {
      case 'user_management':
        return role == 'admin';
      case 'bot_registration':
        return role == 'admin';
      case 'bot_control':
        return true; // Both roles can control bots
      case 'system_analytics':
        return role == 'admin';
      default:
        return false;
    }
  }
}
```

## 🚀 Best Practices

### For Administrators
1. **Regular Audits**: Periodically review user access and permissions
2. **Principle of Least Privilege**: Grant minimum necessary permissions
3. **User Training**: Ensure field operators understand their capabilities
4. **Security Monitoring**: Watch for unusual access patterns

### For Field Operators
1. **Secure Access**: Use strong passwords and secure devices
2. **Regular Updates**: Keep the app updated for security patches
3. **Report Issues**: Immediately report any security concerns
4. **Data Privacy**: Protect sensitive bot and location data

### For Developers
1. **Role Validation**: Always validate user roles before granting access
2. **Data Filtering**: Implement proper data filtering at the service level
3. **Security Testing**: Regularly test role-based access controls
4. **Documentation**: Keep permission documentation up to date

---

**Last Updated**: September 2024  
**Version**: 1.0.0
