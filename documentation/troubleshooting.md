# Troubleshooting Guide

## 🚨 Overview

This guide helps you diagnose and resolve common issues in the AGOS application. It covers build problems, runtime errors, Firebase issues, and performance problems.

## 🔧 Build Issues

### Flutter Build Failures

#### Issue: "No pubspec.yaml file found"
**Solution**:
```bash
# Navigate to project root
cd /path/to/agos-app

# Verify pubspec.yaml exists
ls -la pubspec.yaml

# If missing, recreate from template
flutter create --org com.agos agos-app
```

#### Issue: "Dependencies resolution failed"
**Solution**:
```bash
# Clean and reinstall dependencies
flutter clean
flutter pub get

# If still failing, check pubspec.yaml syntax
flutter pub deps

# Update Flutter
flutter upgrade
```

#### Issue: "Gradle build failed"
**Solution**:
```bash
# Clean Android build
cd android
./gradlew clean
cd ..

# Rebuild
flutter build apk --debug

# Check Android SDK version
flutter doctor -v
```

#### Issue: "Xcode build failed"
**Solution**:
```bash
# Clean iOS build
cd ios
rm -rf Pods
rm Podfile.lock
pod install
cd ..

# Rebuild
flutter build ios --debug

# Check Xcode version
xcodebuild -version
```

### Platform-Specific Build Issues

#### Android Issues

**Issue: "Google Services plugin not found"**
```gradle
// android/build.gradle
buildscript {
    dependencies {
        classpath 'com.google.gms:google-services:4.3.15'
    }
}

// android/app/build.gradle
apply plugin: 'com.google.gms.google-services'
```

**Issue: "Min SDK version mismatch"**
```gradle
// android/app/build.gradle
android {
    compileSdkVersion 34
    defaultConfig {
        minSdkVersion 21
        targetSdkVersion 34
    }
}
```

**Issue: "Signing configuration error"**
```gradle
// android/app/build.gradle
android {
    signingConfigs {
        release {
            keyAlias 'your-key-alias'
            keyPassword 'your-key-password'
            storeFile file('your-keystore.jks')
            storePassword 'your-store-password'
        }
    }
}
```

#### iOS Issues

**Issue: "Pod install failed"**
```bash
# Update CocoaPods
sudo gem install cocoapods
pod repo update

# Clean and reinstall
cd ios
rm -rf Pods
rm Podfile.lock
pod install
```

**Issue: "Code signing error"**
1. Open project in Xcode
2. Select project target
3. Go to Signing & Capabilities
4. Select development team
5. Configure provisioning profile

**Issue: "Firebase iOS SDK not found"**
```ruby
# ios/Podfile
platform :ios, '11.0'

target 'Runner' do
  use_frameworks!
  use_modular_headers!

  pod 'Firebase/Auth'
  pod 'Firebase/Firestore'
  pod 'Firebase/Database'
end
```

## 🔥 Firebase Issues

### Authentication Problems

#### Issue: "Firebase Auth not initialized"
**Solution**:
```dart
// main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}
```

#### Issue: "User not authenticated"
**Solution**:
```dart
// Check authentication state
final authState = ref.read(authProvider);
if (authState.isAuthenticated) {
  // User is authenticated
} else {
  // Redirect to login
  Navigator.pushNamed(context, '/login');
}
```

#### Issue: "Email already in use"
**Solution**:
```dart
// Handle email already in use
try {
  await authService.signUp(email, password, userProfile);
} on FirebaseAuthException catch (e) {
  if (e.code == 'email-already-in-use') {
    SnackbarUtil.showError(context, 'Email already registered');
  }
}
```

### Firestore Issues

#### Issue: "Permission denied"
**Solution**:
```javascript
// Check Firestore security rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && 
        (request.auth.uid == userId || 
         get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin');
    }
  }
}
```

#### Issue: "Document not found"
**Solution**:
```dart
// Check if document exists before reading
final doc = await FirebaseFirestore.instance
    .collection('users')
    .doc(userId)
    .get();

if (doc.exists) {
  final user = UserModel.fromMap(doc.data()!, doc.id);
} else {
  // Handle document not found
}
```

#### Issue: "Index not found"
**Solution**:
1. Go to Firebase Console
2. Navigate to Firestore Database
3. Go to Indexes tab
4. Create required composite indexes
5. Wait for index to build

### Realtime Database Issues

#### Issue: "Connection failed"
**Solution**:
```dart
// Check Realtime Database rules
{
  "rules": {
    "bots": {
      "$botId": {
        ".read": "auth != null",
        ".write": "auth != null"
      }
    }
  }
}
```

#### Issue: "Data not syncing"
**Solution**:
```dart
// Check connection state
final database = FirebaseDatabase.instance;
final connectedRef = database.ref('.info/connected');
connectedRef.onValue.listen((event) {
  if (event.snapshot.value == true) {
    print('Connected to Realtime Database');
  } else {
    print('Disconnected from Realtime Database');
  }
});
```

## 🐛 Runtime Errors

### State Management Issues

#### Issue: "Provider not found"
**Solution**:
```dart
// Ensure provider is properly registered
final container = ProviderContainer(
  overrides: [
    botServiceProvider.overrideWithValue(mockBotService),
  ],
);

// Or use in widget tree
Consumer(
  builder: (context, ref, child) {
    final botState = ref.watch(botProvider);
    return Text('Bots: ${botState.bots.length}');
  },
)
```

#### Issue: "State not updating"
**Solution**:
```dart
// Check if state is immutable
class BotState {
  final List<BotModel> bots;
  final bool isLoading;
  
  BotState copyWith({
    List<BotModel>? bots,
    bool? isLoading,
  }) {
    return BotState(
      bots: bots ?? this.bots,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}
```

### UI Issues

#### Issue: "Widget not rebuilding"
**Solution**:
```dart
// Use Consumer to watch state changes
Consumer(
  builder: (context, ref, child) {
    final botState = ref.watch(botProvider);
    return ListView.builder(
      itemCount: botState.bots.length,
      itemBuilder: (context, index) {
        return BotCard(bot: botState.bots[index]);
      },
    );
  },
)
```

#### Issue: "Layout overflow"
**Solution**:
```dart
// Wrap in SingleChildScrollView
SingleChildScrollView(
  child: Column(
    children: [
      // Your widgets
    ],
  ),
)

// Or use Flexible/Expanded
Row(
  children: [
    Expanded(
      child: Text('Long text that might overflow'),
    ),
  ],
)
```

#### Issue: "Image not loading"
**Solution**:
```dart
// Check image path and format
Image.asset(
  'assets/images/logo.png',
  errorBuilder: (context, error, stackTrace) {
    return Icon(Icons.error);
  },
)

// For network images
Image.network(
  'https://example.com/image.jpg',
  loadingBuilder: (context, child, loadingProgress) {
    if (loadingProgress == null) return child;
    return CircularProgressIndicator();
  },
)
```

### Navigation Issues

#### Issue: "Route not found"
**Solution**:
```dart
// Check route registration
MaterialApp(
  routes: {
    '/login': (context) => LoginPage(),
    '/home': (context) => HomePage(),
    '/bot-details': (context) => BotDetailsPage(
      bot: ModalRoute.of(context)!.settings.arguments as BotModel,
    ),
  },
)
```

#### Issue: "Navigation stack overflow"
**Solution**:
```dart
// Use pushReplacement instead of push
Navigator.pushReplacementNamed(context, '/home');

// Or clear stack
Navigator.pushNamedAndRemoveUntil(
  context,
  '/home',
  (route) => false,
);
```

## 🗺️ Map Issues

### Flutter Maps Problems

#### Issue: "Map not displaying"
**Solution**:
```dart
// Check map configuration
FlutterMap(
  options: MapOptions(
    initialCenter: LatLng(14.5995, 120.9842),
    initialZoom: 13.0,
  ),
  children: [
    TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.agos.app',
    ),
  ],
)
```

#### Issue: "Markers not showing"
**Solution**:
```dart
// Check marker configuration
MarkerLayer(
  markers: bots.map((bot) {
    return Marker(
      point: LatLng(bot.lat!, bot.lng!),
      width: 50,
      height: 50,
      child: Icon(Icons.directions_boat),
    );
  }).toList(),
)
```

#### Issue: "Map performance issues"
**Solution**:
```dart
// Limit marker count
final visibleBots = bots.take(100).toList();

// Use marker clustering
MarkerClusterLayer(
  markers: markers,
  builder: (context, markers) {
    return Container(
      child: Text('${markers.length}'),
    );
  },
)
```

### Geocoding Issues

#### Issue: "Reverse geocoding failed"
**Solution**:
```dart
// Add error handling
try {
  final address = await ReverseGeocodingService.getAddressFromCoordinates(
    latitude: lat,
    longitude: lng,
  );
  if (address != null) {
    // Use address
  } else {
    // Use coordinates as fallback
  }
} catch (e) {
  print('Geocoding error: $e');
  // Handle error
}
```

#### Issue: "API rate limit exceeded"
**Solution**:
```dart
// Implement rate limiting
class RateLimiter {
  static final Map<String, DateTime> _lastCall = {};
  static const Duration _cooldown = Duration(seconds: 1);
  
  static bool canCall(String key) {
    final now = DateTime.now();
    final lastCall = _lastCall[key];
    
    if (lastCall == null || now.difference(lastCall) > _cooldown) {
      _lastCall[key] = now;
      return true;
    }
    return false;
  }
}
```

## 📱 Platform-Specific Issues

### Android Issues

#### Issue: "App crashes on startup"
**Solution**:
```bash
# Check logs
flutter logs

# Run in debug mode
flutter run --debug

# Check for null safety issues
flutter analyze
```

#### Issue: "Permission denied"
**Solution**:
```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

### iOS Issues

#### Issue: "App not launching"
**Solution**:
```bash
# Check iOS deployment target
# ios/Flutter/AppFrameworkInfo.plist
<key>MinimumOSVersion</key>
<string>11.0</string>
```

#### Issue: "Build failed with Xcode 14"
**Solution**:
```ruby
# ios/Podfile
platform :ios, '11.0'

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '11.0'
    end
  end
end
```

### Web Issues

#### Issue: "CORS error"
**Solution**:
```dart
// Check Firebase config
const firebaseConfig = {
  apiKey: "your-api-key",
  authDomain: "your-project.firebaseapp.com",
  projectId: "your-project-id",
  storageBucket: "your-project.appspot.com",
  messagingSenderId: "your-sender-id",
  appId: "your-app-id"
};
```

#### Issue: "Web build not working"
**Solution**:
```bash
# Enable web support
flutter config --enable-web

# Build for web
flutter build web --release

# Serve locally
python -m http.server 8000 -d build/web
```

## ⚡ Performance Issues

### Memory Issues

#### Issue: "App running out of memory"
**Solution**:
```dart
// Dispose controllers properly
@override
void dispose() {
  _controller.dispose();
  _animationController.dispose();
  super.dispose();
}

// Use const constructors
const Text('Static text');

// Implement proper list disposal
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) {
    return ListTile(title: Text(items[index]));
  },
)
```

#### Issue: "Slow list scrolling"
**Solution**:
```dart
// Use ListView.builder for large lists
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) {
    return ListTile(title: Text(items[index]));
  },
)

// Implement pagination
class PaginatedList extends StatefulWidget {
  @override
  _PaginatedListState createState() => _PaginatedListState();
}

class _PaginatedListState extends State<PaginatedList> {
  final ScrollController _scrollController = ScrollController();
  List<Item> _items = [];
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadItems();
  }
  
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.9) {
      _loadMoreItems();
    }
  }
}
```

### Network Issues

#### Issue: "Slow data loading"
**Solution**:
```dart
// Implement caching
class DataCache {
  static final Map<String, dynamic> _cache = {};
  static const Duration _cacheTimeout = Duration(minutes: 5);
  
  static T? get<T>(String key) {
    final item = _cache[key];
    if (item != null && item['timestamp'] != null) {
      final timestamp = item['timestamp'] as DateTime;
      if (DateTime.now().difference(timestamp) < _cacheTimeout) {
        return item['data'] as T;
      }
    }
    return null;
  }
  
  static void set<T>(String key, T data) {
    _cache[key] = {
      'data': data,
      'timestamp': DateTime.now(),
    };
  }
}
```

#### Issue: "Connection timeout"
**Solution**:
```dart
// Add timeout to network requests
final response = await http.get(
  Uri.parse(url),
).timeout(
  const Duration(seconds: 30),
  onTimeout: () {
    throw TimeoutException('Request timeout', const Duration(seconds: 30));
  },
);
```

## 🔍 Debugging Tools

### Flutter Inspector
```bash
# Open Flutter Inspector
flutter run --debug
# Then open Flutter Inspector in VS Code or Android Studio
```

### Logging
```dart
// Add comprehensive logging
import 'dart:developer' as developer;

void log(String message, {String? tag}) {
  developer.log(
    message,
    name: tag ?? 'AGOS',
    time: DateTime.now(),
  );
}

// Usage
log('Bot created successfully', tag: 'BotService');
```

### Performance Monitoring
```dart
// Monitor widget rebuilds
class DebugWidget extends StatefulWidget {
  final Widget child;
  final String name;
  
  const DebugWidget({
    Key? key,
    required this.child,
    required this.name,
  }) : super(key: key);
  
  @override
  State<DebugWidget> createState() => _DebugWidgetState();
}

class _DebugWidgetState extends State<DebugWidget> {
  @override
  Widget build(BuildContext context) {
    print('${widget.name} rebuilt');
    return widget.child;
  }
}
```

## 📞 Getting Help

### Common Resources
- **Flutter Documentation**: https://flutter.dev/docs
- **Firebase Documentation**: https://firebase.google.com/docs
- **Riverpod Documentation**: https://riverpod.dev/docs
- **Flutter Maps Documentation**: https://docs.fleaflet.dev/

### Community Support
- **Flutter Discord**: https://discord.gg/flutter
- **Stack Overflow**: Tag questions with `flutter` and `firebase`
- **GitHub Issues**: Report bugs in the repository

### Professional Support
- **Flutter Consulting**: Hire Flutter experts
- **Firebase Support**: Enterprise Firebase support
- **Custom Development**: Contact development team

---

**Last Updated**: September 2024  
**Version**: 1.0.0
