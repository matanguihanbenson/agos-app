# Firebase Database Structure

## 📊 Overview

AGOS uses Firebase for backend services including Authentication, Firestore (NoSQL), and Realtime Database. This document outlines the complete database structure, collections, fields, and relationships.

## 🔐 Authentication

### User Types
- **Admin**: Full system access, can manage all entities
- **Field Operator**: Limited access, manages assigned bots only

### Authentication Flow
1. User signs up/in via Firebase Auth
2. User profile created in Firestore `users` collection
3. Role-based access control applied
4. JWT tokens managed automatically

## 🗄️ Firestore Collections

### 1. Users Collection (`users`)

**Purpose**: Store user profiles and authentication data

```javascript
users/
├── {userId}/
    ├── id: string                    // Document ID (same as Firebase Auth UID)
    ├── first_name: string           // User's first name
    ├── last_name: string            // User's last name
    ├── email: string                // User's email address
    ├── role: string                 // "admin" or "field_operator"
    ├── status: string               // "active", "inactive", "archived"
    ├── created_by: string           // ID of admin who created this user
    ├── organization_id: string      // ID of assigned organization (optional)
    ├── created_at: timestamp        // Account creation date
    └── updated_at: timestamp        // Last modification date
```

**Indexes Required**:
- `role` (ascending)
- `status` (ascending)
- `created_by` (ascending)
- `organization_id` (ascending)

### 2. Organizations Collection (`organizations`)

**Purpose**: Manage organizational structure and bot assignments

```javascript
organizations/
├── {organizationId}/
    ├── id: string                   // Document ID
    ├── name: string                 // Organization name
    ├── description: string          // Organization description
    ├── status: string               // "active" or "inactive"
    ├── creator_user_id: string      // ID of admin who created this org
    ├── bot_ids: array<string>       // Array of bot IDs (optional)
    ├── created_at: timestamp        // Creation date
    └── updated_at: timestamp        // Last modification date
```

**Indexes Required**:
- `creator_user_id` (ascending)
- `status` (ascending)

### 3. Bots Collection (`bots`)

**Purpose**: Store bot information and assignments

```javascript
bots/
├── {botId}/
    ├── id: string                   // Document ID (bot identifier)
    ├── name: string                 // Bot display name
    ├── assigned_to: string          // User ID of assigned operator (optional)
    ├── assigned_at: timestamp       // Assignment date (optional)
    ├── organization_id: string      // ID of assigned organization (optional)
    ├── owner_admin_id: string       // ID of admin who owns this bot
    ├── created_at: timestamp        // Registration date
    └── updated_at: timestamp        // Last modification date
```

**Indexes Required**:
- `owner_admin_id` (ascending)
- `assigned_to` (ascending)
- `organization_id` (ascending)

### 4. Bot Registry Collection (`bot_registry`)

**Purpose**: Track bot registration status and prevent duplicates

```javascript
bot_registry/
├── {botId}/
    ├── id: string                   // Document ID (bot identifier)
    ├── is_registered: boolean       // Registration status
    ├── registered_by: string        // User ID who registered the bot
    ├── registered_at: timestamp     // Registration date
    ├── created_at: timestamp        // Registry entry creation
    └── updated_at: timestamp        // Last modification date
```

**Indexes Required**:
- `is_registered` (ascending)
- `registered_by` (ascending)

### 5. Notifications Collection (`notifications`)

**Purpose**: Store system notifications and alerts

```javascript
notifications/
├── {notificationId}/
    ├── id: string                   // Document ID
    ├── title: string                // Notification title
    ├── message: string              // Notification content
    ├── type: string                 // "bot_alert", "assignment", "system", "maintenance"
    ├── is_read: boolean             // Read status
    ├── timestamp: timestamp         // Notification time
    ├── user_id: string              // Target user ID
    ├── related_entity_id: string    // Related bot/user/org ID (optional)
    ├── related_entity_type: string  // "bot", "user", "organization"
    ├── metadata: object             // Additional data (optional)
    ├── created_at: timestamp        // Creation date
    └── updated_at: timestamp        // Last modification date
```

**Indexes Required**:
- `user_id` (ascending), `timestamp` (descending)
- `user_id` (ascending), `is_read` (ascending)
- `type` (ascending), `timestamp` (descending)

## 🔄 Realtime Database Structure

### Bot Real-time Data (`bots/{botId}`)

**Purpose**: Store live bot status and sensor data

```javascript
bots/
├── {botId}/
    ├── status: string               // "deployed", "idle", "maintenance"
    ├── battery_level: number        // Battery percentage (0-100)
    ├── lat: number                  // Latitude coordinate
    ├── lng: number                  // Longitude coordinate
    ├── active: boolean              // Online/offline status
    ├── ph_level: number             // Water pH level
    ├── temp: number                 // Water temperature
    ├── turbidity: number            // Water turbidity level
    └── last_updated: number         // Unix timestamp of last update
```

**Data Flow**:
1. Bot sends sensor data to Realtime Database
2. App listens for changes in real-time
3. UI updates automatically when data changes
4. Offline bots are filtered out based on `active` status

## 🔗 Data Relationships

### User → Organization
- **One-to-Many**: One organization can have multiple users
- **Field**: `users.organization_id` → `organizations.id`

### Admin → Bots
- **One-to-Many**: One admin can own multiple bots
- **Field**: `bots.owner_admin_id` → `users.id` (where role = "admin")

### Admin → Organizations
- **One-to-Many**: One admin can create multiple organizations
- **Field**: `organizations.creator_user_id` → `users.id` (where role = "admin")

### Bot → User Assignment
- **Many-to-One**: Multiple bots can be assigned to one user
- **Field**: `bots.assigned_to` → `users.id` (where role = "field_operator")

### Bot → Organization
- **Many-to-One**: Multiple bots can belong to one organization
- **Field**: `bots.organization_id` → `organizations.id`

### Bot Registry → Bot
- **One-to-One**: Each bot has one registry entry
- **Field**: `bot_registry.id` = `bots.id`

## 📋 Security Rules

### Firestore Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can read their own data and admins can read all
    match /users/{userId} {
      allow read, write: if request.auth != null && 
        (request.auth.uid == userId || 
         get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin');
    }
    
    // Only admins can manage organizations
    match /organizations/{orgId} {
      allow read, write: if request.auth != null && 
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
    
    // Bot access based on ownership and assignment
    match /bots/{botId} {
      allow read, write: if request.auth != null && 
        (resource.data.owner_admin_id == request.auth.uid ||
         resource.data.assigned_to == request.auth.uid);
    }
    
    // Bot registry - admins only
    match /bot_registry/{botId} {
      allow read, write: if request.auth != null && 
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
    
    // Notifications - users can read their own
    match /notifications/{notificationId} {
      allow read, write: if request.auth != null && 
        resource.data.user_id == request.auth.uid;
    }
  }
}
```

### Realtime Database Security Rules

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

## 🔍 Query Patterns

### Common Queries

1. **Get bots for admin**:
   ```javascript
   db.collection('bots').where('owner_admin_id', '==', adminId)
   ```

2. **Get bots assigned to user**:
   ```javascript
   db.collection('bots').where('assigned_to', '==', userId)
   ```

3. **Get users created by admin**:
   ```javascript
   db.collection('users').where('created_by', '==', adminId)
   ```

4. **Get organizations by creator**:
   ```javascript
   db.collection('organizations').where('creator_user_id', '==', adminId)
   ```

5. **Get unread notifications**:
   ```javascript
   db.collection('notifications')
     .where('user_id', '==', userId)
     .where('is_read', '==', false)
     .orderBy('timestamp', 'desc')
   ```

## 📊 Data Validation

### Required Fields
- **Users**: `first_name`, `last_name`, `email`, `role`, `status`
- **Organizations**: `name`, `creator_user_id`, `status`
- **Bots**: `name`, `owner_admin_id`
- **Bot Registry**: `is_registered`

### Data Types
- **Timestamps**: Use Firestore `Timestamp` type
- **Booleans**: Use `true`/`false` (not strings)
- **Arrays**: Use Firestore arrays for `bot_ids`
- **Numbers**: Use appropriate numeric types

### Constraints
- **Email**: Must be unique and valid format
- **Role**: Must be "admin" or "field_operator"
- **Status**: Must be "active", "inactive", or "archived"
- **Bot ID**: Must be unique across both Firestore and Realtime DB

## 🚀 Performance Optimization

### Indexing Strategy
1. **Single Field Indexes**: For simple queries
2. **Composite Indexes**: For complex queries with multiple fields
3. **Array Indexes**: For array-contains queries

### Caching Strategy
1. **Local Caching**: Use Riverpod for state management
2. **Offline Support**: Firestore offline persistence
3. **Real-time Updates**: Efficient listeners for live data

### Data Pagination
- Use `limit()` and `startAfter()` for large datasets
- Implement cursor-based pagination for better performance
- Cache frequently accessed data locally

---

**Last Updated**: September 2024  
**Version**: 1.0.0
