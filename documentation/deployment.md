# Deployment Guide

## 🚀 Overview

This guide covers the complete deployment process for the AGOS application, including environment setup, build configuration, and deployment to various platforms.

## 📋 Prerequisites

### Development Environment
- **Flutter SDK**: 3.16.0 or higher
- **Dart SDK**: 3.2.0 or higher
- **Android Studio**: Latest version with Android SDK
- **Xcode**: 14.0 or higher (for iOS)
- **VS Code**: With Flutter extension (optional)
- **Git**: For version control

### Firebase Setup
- **Firebase Project**: Created and configured
- **Authentication**: Enabled with email/password
- **Firestore**: Database created with security rules
- **Realtime Database**: Created with security rules
- **Storage**: Configured (if needed)

### Platform Requirements
- **Android**: API level 21+ (Android 5.0+)
- **iOS**: iOS 11.0+
- **Web**: Modern browsers (Chrome, Firefox, Safari)

## 🔧 Environment Configuration

### 1. Flutter Environment Setup

```bash
# Install Flutter
git clone https://github.com/flutter/flutter.git -b stable
export PATH="$PATH:`pwd`/flutter/bin"

# Verify installation
flutter doctor

# Install dependencies
flutter pub get
```

### 2. Firebase Configuration

#### Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Create a project"
3. Enter project name: "AGOS"
4. Enable Google Analytics (optional)
5. Create project

#### Enable Services
1. **Authentication**:
   - Go to Authentication > Sign-in method
   - Enable Email/Password
   - Configure authorized domains

2. **Firestore Database**:
   - Go to Firestore Database
   - Create database in production mode
   - Set up security rules (see Firebase Structure doc)

3. **Realtime Database**:
   - Go to Realtime Database
   - Create database
   - Set up security rules

#### Download Configuration Files
1. **Android**: Download `google-services.json`
2. **iOS**: Download `GoogleService-Info.plist`
3. **Web**: Copy Firebase config object

### 3. Platform-Specific Setup

#### Android Setup
```bash
# Place google-services.json in android/app/
cp google-services.json android/app/

# Update android/app/build.gradle
android {
    compileSdkVersion 34
    defaultConfig {
        minSdkVersion 21
        targetSdkVersion 34
    }
}
```

#### iOS Setup
```bash
# Place GoogleService-Info.plist in ios/Runner/
cp GoogleService-Info.plist ios/Runner/

# Update ios/Runner/Info.plist
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>REVERSED_CLIENT_ID</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>YOUR_REVERSED_CLIENT_ID</string>
        </array>
    </dict>
</array>
```

#### Web Setup
```dart
// Create lib/firebase_options.dart
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'your-api-key',
    authDomain: 'your-project.firebaseapp.com',
    projectId: 'your-project-id',
    storageBucket: 'your-project.appspot.com',
    messagingSenderId: 'your-sender-id',
    appId: 'your-app-id',
  );
}
```

## 🏗️ Build Configuration

### 1. Android Build

#### Debug Build
```bash
# Build debug APK
flutter build apk --debug

# Build debug bundle
flutter build appbundle --debug
```

#### Release Build
```bash
# Build release APK
flutter build apk --release

# Build release bundle
flutter build appbundle --release

# Build with specific target
flutter build apk --target-platform android-arm64 --release
```

#### Signing Configuration
```gradle
// android/app/build.gradle
android {
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
    }
}
```

### 2. iOS Build

#### Debug Build
```bash
# Build debug for simulator
flutter build ios --debug --simulator

# Build debug for device
flutter build ios --debug
```

#### Release Build
```bash
# Build release
flutter build ios --release

# Build for App Store
flutter build ipa --release
```

#### Code Signing
1. Open project in Xcode
2. Select project target
3. Go to Signing & Capabilities
4. Select development team
5. Configure provisioning profile

### 3. Web Build

#### Debug Build
```bash
# Build debug web
flutter build web --debug
```

#### Release Build
```bash
# Build release web
flutter build web --release

# Build with specific base href
flutter build web --release --base-href /agos/
```

## 📱 Platform Deployment

### 1. Android Deployment

#### Google Play Store
1. **Create Developer Account**:
   - Go to [Google Play Console](https://play.google.com/console/)
   - Pay registration fee ($25)
   - Complete developer profile

2. **Upload APK/AAB**:
   - Go to Release > Production
   - Upload release bundle
   - Fill in release notes
   - Submit for review

3. **App Store Listing**:
   - App name: "AGOS - Ocean Guardian"
   - Short description: "Autonomous garbage-cleaning bot management"
   - Full description: Detailed app description
   - Screenshots: App screenshots
   - Icon: App icon (512x512)

#### Internal Testing
```bash
# Build for internal testing
flutter build appbundle --release

# Upload to Play Console
# Go to Testing > Internal testing
# Upload AAB file
# Add testers
```

### 2. iOS Deployment

#### App Store
1. **Apple Developer Account**:
   - Go to [Apple Developer](https://developer.apple.com/)
   - Enroll in Apple Developer Program ($99/year)
   - Complete enrollment process

2. **App Store Connect**:
   - Go to [App Store Connect](https://appstoreconnect.apple.com/)
   - Create new app
   - Fill in app information
   - Upload build via Xcode or Transporter

3. **App Review**:
   - Submit for review
   - Wait for approval (1-7 days)
   - Release to App Store

#### TestFlight
```bash
# Build for TestFlight
flutter build ipa --release

# Upload via Xcode
# Archive and upload to App Store Connect
# Add testers in TestFlight
```

### 3. Web Deployment

#### Firebase Hosting
```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize hosting
firebase init hosting

# Build web app
flutter build web --release

# Deploy to Firebase
firebase deploy --only hosting
```

#### Custom Domain
```bash
# Add custom domain
firebase hosting:sites:create agos-app

# Configure domain
firebase hosting:sites:get agos-app
```

#### Other Hosting Options
- **Netlify**: Drag and drop build folder
- **Vercel**: Connect GitHub repository
- **AWS S3**: Upload build files
- **GitHub Pages**: Deploy from repository

## 🔐 Security Configuration

### 1. Firebase Security Rules

#### Firestore Rules
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

#### Realtime Database Rules
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

### 2. App Security

#### Code Obfuscation
```bash
# Build with obfuscation
flutter build apk --release --obfuscate --split-debug-info=debug-info
```

#### API Key Protection
```dart
// Use environment variables
const String apiKey = String.fromEnvironment('API_KEY', defaultValue: '');
```

#### Certificate Pinning
```dart
// Implement certificate pinning for API calls
class CertificatePinning {
  static bool validateCertificate(X509Certificate cert) {
    // Implement certificate validation
    return true;
  }
}
```

## 📊 Monitoring & Analytics

### 1. Firebase Analytics

```dart
// Initialize analytics
await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);

// Track events
await FirebaseAnalytics.instance.logEvent(
  name: 'bot_created',
  parameters: {
    'bot_id': botId,
    'user_role': userRole,
  },
);
```

### 2. Crashlytics

```dart
// Initialize crashlytics
await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);

// Log errors
FirebaseCrashlytics.instance.recordError(
  error,
  stackTrace,
  reason: 'Bot creation failed',
);
```

### 3. Performance Monitoring

```dart
// Track performance
final trace = FirebasePerformance.instance.newTrace('bot_loading');
await trace.start();
// ... perform operation
await trace.stop();
```

## 🧪 Testing Before Deployment

### 1. Unit Tests
```bash
# Run unit tests
flutter test

# Run with coverage
flutter test --coverage
```

### 2. Integration Tests
```bash
# Run integration tests
flutter test integration_test/

# Run on specific device
flutter test integration_test/ -d chrome
```

### 3. Manual Testing
- **Authentication**: Test login/logout flows
- **Bot Management**: Test CRUD operations
- **Real-time Updates**: Test live data synchronization
- **Map Functionality**: Test map interactions
- **Role-based Access**: Test different user roles

## 🚀 CI/CD Pipeline

### 1. GitHub Actions

```yaml
# .github/workflows/deploy.yml
name: Deploy AGOS

on:
  push:
    branches: [main]

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v2
    
    - name: Setup Flutter
      uses: subosito/flutter-action@v2
      with:
        flutter-version: '3.16.0'
        
    - name: Install dependencies
      run: flutter pub get
      
    - name: Run tests
      run: flutter test
      
    - name: Build APK
      run: flutter build apk --release
      
    - name: Deploy to Firebase
      run: firebase deploy --only hosting
```

### 2. Automated Testing

```yaml
# .github/workflows/test.yml
name: Test AGOS

on:
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v2
    
    - name: Setup Flutter
      uses: subosito/flutter-action@v2
      
    - name: Install dependencies
      run: flutter pub get
      
    - name: Run tests
      run: flutter test
      
    - name: Run integration tests
      run: flutter test integration_test/
```

## 📈 Performance Optimization

### 1. Build Optimization

```bash
# Build with optimizations
flutter build apk --release --split-per-abi --obfuscate --split-debug-info=debug-info

# Build for specific architectures
flutter build apk --target-platform android-arm64 --release
```

### 2. Asset Optimization

```yaml
# pubspec.yaml
flutter:
  assets:
    - assets/images/
    - assets/icons/
  
  # Optimize images
  fonts:
    - family: Roboto
      fonts:
        - asset: assets/fonts/Roboto-Regular.ttf
        - asset: assets/fonts/Roboto-Bold.ttf
          weight: 700
```

### 3. Code Splitting

```dart
// Lazy load pages
Widget _buildPage(int index) {
  switch (index) {
    case 0: return const MapPage();
    case 1: return const BotsPage();
    // ... other pages
    default: return const SizedBox();
  }
}
```

## 🔄 Update Strategy

### 1. Version Management

```yaml
# pubspec.yaml
version: 1.0.0+1
# Format: version+build_number
```

### 2. Hot Updates

```dart
// Check for updates
void _checkForUpdates() async {
  final updateInfo = await _updateChecker.checkForUpdate();
  if (updateInfo.updateAvailable) {
    _showUpdateDialog(updateInfo);
  }
}
```

### 3. Rollback Strategy

```bash
# Rollback to previous version
firebase hosting:rollback

# Rollback app version
# Use previous APK/AAB file
```

## 📋 Deployment Checklist

### Pre-Deployment
- [ ] All tests passing
- [ ] Security rules configured
- [ ] API keys secured
- [ ] Build optimized
- [ ] Assets optimized
- [ ] Version number updated

### Deployment
- [ ] Build created successfully
- [ ] Uploaded to app stores
- [ ] Firebase deployed
- [ ] Domain configured
- [ ] SSL certificate valid

### Post-Deployment
- [ ] App store listing live
- [ ] Analytics working
- [ ] Crashlytics enabled
- [ ] Performance monitoring active
- [ ] User feedback collected

## 🆘 Troubleshooting

### Common Issues

#### Build Failures
```bash
# Clean build
flutter clean
flutter pub get
flutter build apk --release
```

#### Firebase Connection Issues
```dart
// Check Firebase initialization
await Firebase.initializeApp();
print('Firebase initialized: ${Firebase.apps.isNotEmpty}');
```

#### Platform-Specific Issues
- **Android**: Check `google-services.json` placement
- **iOS**: Check `GoogleService-Info.plist` and signing
- **Web**: Check Firebase config and CORS settings

---

**Last Updated**: September 2024  
**Version**: 1.0.0
