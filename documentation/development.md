# Development Guide

## 👨‍💻 Overview

This guide provides comprehensive information for developers working on the AGOS application. It covers development setup, coding standards, testing practices, and contribution guidelines.

## 🚀 Getting Started

### Prerequisites
- **Flutter SDK**: 3.16.0 or higher
- **Dart SDK**: 3.2.0 or higher
- **Git**: For version control
- **IDE**: VS Code or Android Studio with Flutter extensions
- **Firebase Account**: For backend services

### Development Environment Setup

#### 1. Clone Repository
```bash
git clone https://github.com/your-org/agos-app.git
cd agos-app
```

#### 2. Install Dependencies
```bash
flutter pub get
```

#### 3. Configure Firebase
```bash
# Copy Firebase configuration files
cp firebase-config/google-services.json android/app/
cp firebase-config/GoogleService-Info.plist ios/Runner/
```

#### 4. Run Application
```bash
# Debug mode
flutter run

# Release mode
flutter run --release

# Specific platform
flutter run -d chrome
flutter run -d android
flutter run -d ios
```

## 🏗️ Project Structure

### Directory Organization
```
lib/
├── core/                    # Core functionality
│   ├── constants/          # App constants
│   ├── models/             # Data models
│   ├── providers/          # State management
│   ├── services/           # Business logic
│   ├── theme/              # UI theming
│   ├── utils/              # Utilities
│   └── widgets/            # Reusable components
├── features/               # Feature modules
│   ├── auth/              # Authentication
│   ├── bots/              # Bot management
│   ├── map/               # Map functionality
│   ├── management/        # User/Org management
│   ├── monitoring/        # System monitoring
│   ├── profile/           # User profile
│   └── settings/          # App settings
├── shared/                # Shared components
│   ├── navigation/        # Navigation logic
│   └── widgets/           # Shared widgets
└── main.dart              # App entry point
```

### File Naming Conventions
- **Files**: `snake_case.dart`
- **Classes**: `PascalCase`
- **Variables**: `camelCase`
- **Constants**: `UPPER_SNAKE_CASE`
- **Private members**: `_camelCase`

## 📝 Coding Standards

### Dart Style Guide

#### 1. Formatting
```dart
// Use dart format
dart format lib/

// Or use IDE formatting
// VS Code: Shift + Alt + F
// Android Studio: Ctrl + Alt + L
```

#### 2. Naming Conventions
```dart
// Classes
class BotService {
  // Methods
  Future<void> createBot(BotModel bot) async {
    // Variables
    final botId = bot.id;
    final isOnline = bot.isOnline;
    
    // Constants
    static const String collectionName = 'bots';
  }
}

// Private members
class _BotServiceState {
  final String _botId;
  bool _isLoading = false;
}
```

#### 3. Documentation
```dart
/// Service for managing bot operations
/// 
/// This service provides methods for creating, reading, updating,
/// and deleting bots in the Firestore database.
class BotService {
  /// Creates a new bot in the database
  /// 
  /// [bot] The bot model to create
  /// Returns the ID of the created bot
  /// Throws [FirebaseException] if creation fails
  Future<String> createBot(BotModel bot) async {
    // Implementation
  }
}
```

### Widget Guidelines

#### 1. Widget Structure
```dart
class BotCard extends ConsumerWidget {
  final BotModel bot;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const BotCard({
    super.key,
    required this.bot,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      // Widget implementation
    );
  }
}
```

#### 2. State Management
```dart
// Use Consumer for Riverpod
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

// Use ref.read for one-time reads
final botService = ref.read(botServiceProvider);
```

#### 3. Error Handling
```dart
try {
  await botService.createBot(bot);
  SnackbarUtil.showSuccess(context, 'Bot created successfully');
} on FirebaseException catch (e) {
  SnackbarUtil.showError(context, 'Failed to create bot: ${e.message}');
} catch (e) {
  SnackbarUtil.showError(context, 'Unexpected error: $e');
}
```

## 🧪 Testing

### Unit Testing

#### 1. Test Structure
```dart
// test/services/bot_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:agos_app/core/services/bot_service.dart';

void main() {
  group('BotService Tests', () {
    late BotService botService;
    late MockFirebaseFirestore mockFirestore;
    
    setUp(() {
      mockFirestore = MockFirebaseFirestore();
      botService = BotService();
    });
    
    test('should create bot successfully', () async {
      // Arrange
      final bot = BotModel(
        id: 'bot-1',
        name: 'Test Bot',
        // ... other fields
      );
      
      // Act
      final result = await botService.createBot(bot);
      
      // Assert
      expect(result, isA<String>());
      expect(result, isNotEmpty);
    });
  });
}
```

#### 2. Mocking
```dart
// test/mocks/mock_services.dart
import 'package:mockito/mockito.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}
class MockCollectionReference extends Mock implements CollectionReference {}
class MockDocumentReference extends Mock implements DocumentReference {}
class MockQuerySnapshot extends Mock implements QuerySnapshot {}
```

#### 3. Provider Testing
```dart
// test/providers/bot_provider_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agos_app/core/providers/bot_provider.dart';

void main() {
  group('BotProvider Tests', () {
    late ProviderContainer container;
    
    setUp(() {
      container = ProviderContainer(
        overrides: [
          botServiceProvider.overrideWithValue(mockBotService),
        ],
      );
    });
    
    tearDown(() {
      container.dispose();
    });
    
    test('should load bots successfully', () async {
      // Arrange
      when(mockBotService.getAllBotsWithRealtimeData())
          .thenAnswer((_) async => [testBot]);
      
      // Act
      await container.read(botProvider.notifier).loadBots();
      
      // Assert
      final state = container.read(botProvider);
      expect(state.bots, isNotEmpty);
      expect(state.isLoading, false);
    });
  });
}
```

### Integration Testing

#### 1. Widget Testing
```dart
// test/widgets/bot_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agos_app/features/bots/widgets/bot_card.dart';

void main() {
  group('BotCard Widget Tests', () {
    testWidgets('should display bot information', (tester) async {
      // Arrange
      final bot = BotModel(
        id: 'bot-1',
        name: 'Test Bot',
        status: 'deployed',
        isOnline: true,
      );
      
      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BotCard(bot: bot),
          ),
        ),
      );
      
      // Assert
      expect(find.text('Test Bot'), findsOneWidget);
      expect(find.text('DEPLOYED'), findsOneWidget);
      expect(find.text('Online'), findsOneWidget);
    });
  });
}
```

#### 2. Navigation Testing
```dart
// test/navigation/navigation_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agos_app/main.dart';

void main() {
  group('Navigation Tests', () {
    testWidgets('should navigate to bot details on tap', (tester) async {
      // Arrange
      await tester.pumpWidget(MyApp());
      
      // Act
      await tester.tap(find.byType(BotCard));
      await tester.pumpAndSettle();
      
      // Assert
      expect(find.byType(BotDetailsPage), findsOneWidget);
    });
  });
}
```

### Running Tests
```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/services/bot_service_test.dart

# Run tests with coverage
flutter test --coverage

# Run integration tests
flutter test integration_test/
```

## 🔧 Development Tools

### Code Quality

#### 1. Linting
```yaml
# analysis_options.yaml
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    - avoid_print
    - avoid_unnecessary_containers
    - prefer_const_constructors
    - prefer_const_literals_to_create_immutables
```

#### 2. Code Analysis
```bash
# Run analysis
flutter analyze

# Fix issues
dart fix --apply
```

#### 3. Formatting
```bash
# Format code
dart format lib/

# Check formatting
dart format --set-exit-if-changed lib/
```

### Debugging

#### 1. Debug Mode
```bash
# Run in debug mode
flutter run --debug

# Run with verbose logging
flutter run --debug --verbose
```

#### 2. Hot Reload
```bash
# Hot reload (r)
# Hot restart (R)
# Quit (q)
```

#### 3. Debug Tools
```dart
// Add debug prints
debugPrint('Bot created: ${bot.id}');

// Use debugger
import 'dart:developer' as developer;
developer.debugger();

// Add breakpoints in IDE
```

### Performance Profiling

#### 1. Performance Overlay
```dart
// Enable performance overlay
MaterialApp(
  showPerformanceOverlay: true,
  // ... other properties
)
```

#### 2. Memory Profiling
```bash
# Run with memory profiling
flutter run --profile

# Use Flutter Inspector
# VS Code: Ctrl + Shift + P > Flutter: Open Flutter Inspector
```

## 🚀 Build & Deployment

### Development Builds

#### 1. Debug Build
```bash
# Android debug APK
flutter build apk --debug

# iOS debug
flutter build ios --debug
```

#### 2. Profile Build
```bash
# Android profile APK
flutter build apk --profile

# iOS profile
flutter build ios --profile
```

### Production Builds

#### 1. Release Build
```bash
# Android release APK
flutter build apk --release

# Android release bundle
flutter build appbundle --release

# iOS release
flutter build ios --release
```

#### 2. Web Build
```bash
# Web debug
flutter build web --debug

# Web release
flutter build web --release
```

## 📦 Dependencies

### Adding Dependencies

#### 1. Add Package
```bash
# Add package
flutter pub add package_name

# Add dev dependency
flutter pub add --dev package_name
```

#### 2. Update pubspec.yaml
```yaml
dependencies:
  flutter:
    sdk: flutter
  firebase_core: ^2.24.2
  firebase_auth: ^4.15.3
  cloud_firestore: ^4.13.6
  firebase_database: ^11.1.4
  flutter_riverpod: ^2.4.9
  flutter_map: ^7.0.2
  latlong2: ^0.9.1
  http: ^1.2.2
```

#### 3. Update Dependencies
```bash
# Update all dependencies
flutter pub upgrade

# Update specific package
flutter pub upgrade package_name
```

### Dependency Management

#### 1. Version Constraints
```yaml
dependencies:
  # Exact version
  package_name: 1.0.0
  
  # Version range
  package_name: ^1.0.0  # >=1.0.0 <2.0.0
  
  # Version range
  package_name: '>=1.0.0 <2.0.0'
```

#### 2. Dependency Overrides
```yaml
dependency_overrides:
  package_name: 1.0.0
```

## 🔄 Git Workflow

### Branch Strategy

#### 1. Branch Naming
```bash
# Feature branches
feature/bot-management
feature/user-authentication
feature/real-time-updates

# Bug fix branches
bugfix/login-error
bugfix/map-display-issue

# Hotfix branches
hotfix/critical-security-fix
```

#### 2. Commit Messages
```bash
# Format: type(scope): description
feat(bots): add bot registration functionality
fix(auth): resolve login validation error
docs(readme): update installation instructions
test(bots): add unit tests for bot service
refactor(ui): improve bot card layout
```

### Pull Request Process

#### 1. Create Pull Request
```bash
# Create feature branch
git checkout -b feature/new-feature

# Make changes
git add .
git commit -m "feat: add new feature"

# Push branch
git push origin feature/new-feature

# Create pull request on GitHub
```

#### 2. Code Review
- **Review Checklist**:
  - [ ] Code follows style guidelines
  - [ ] Tests are included
  - [ ] Documentation is updated
  - [ ] No breaking changes
  - [ ] Performance is acceptable

#### 3. Merge Process
```bash
# Squash and merge
# Or rebase and merge
# Or merge commit
```

## 📚 Documentation

### Code Documentation

#### 1. Class Documentation
```dart
/// Service for managing bot operations in the AGOS application
/// 
/// This service provides comprehensive bot management functionality including
/// creation, retrieval, updating, and deletion of bot records. It integrates
/// with Firebase Firestore for persistent storage and Firebase Realtime Database
/// for live status updates.
/// 
/// Example usage:
/// ```dart
/// final botService = BotService();
/// final bot = BotModel(id: 'bot-1', name: 'Test Bot');
/// await botService.createBot(bot);
/// ```
class BotService {
  // Implementation
}
```

#### 2. Method Documentation
```dart
/// Creates a new bot in the database
/// 
/// [bot] The bot model containing all necessary bot information
/// Returns a [Future<String>] that completes with the bot ID
/// 
/// Throws [FirebaseException] if the operation fails
/// Throws [ArgumentError] if the bot data is invalid
/// 
/// Example:
/// ```dart
/// final bot = BotModel(
///   id: 'bot-001',
///   name: 'Ocean Cleaner 1',
///   status: 'idle',
/// );
/// final botId = await botService.createBot(bot);
/// print('Created bot with ID: $botId');
/// ```
Future<String> createBot(BotModel bot) async {
  // Implementation
}
```

### API Documentation

#### 1. Generate Documentation
```bash
# Generate API documentation
dart doc

# Serve documentation locally
dart doc --serve
```

#### 2. Documentation Comments
```dart
/// {@template bot_service}
/// A service class that handles all bot-related operations
/// {@endtemplate}
class BotService {
  /// {@macro bot_service}
  BotService();
}
```

## 🐛 Bug Reporting

### Issue Template

#### 1. Bug Report
```markdown
## Bug Description
Brief description of the bug

## Steps to Reproduce
1. Go to '...'
2. Click on '....'
3. Scroll down to '....'
4. See error

## Expected Behavior
What you expected to happen

## Actual Behavior
What actually happened

## Environment
- Flutter version: 3.16.0
- Dart version: 3.2.0
- Platform: Android/iOS/Web
- Device: [e.g., iPhone 12, Samsung Galaxy S21]

## Screenshots
If applicable, add screenshots

## Additional Context
Any other context about the problem
```

#### 2. Feature Request
```markdown
## Feature Description
Brief description of the feature

## Use Case
Why is this feature needed?

## Proposed Solution
How should this feature work?

## Alternatives
Any alternative solutions considered

## Additional Context
Any other context about the feature request
```

## 🤝 Contributing

### Contribution Guidelines

#### 1. Code Standards
- Follow Dart style guide
- Write comprehensive tests
- Document all public APIs
- Use meaningful commit messages
- Keep PRs focused and small

#### 2. Testing Requirements
- Unit tests for all services
- Widget tests for UI components
- Integration tests for user flows
- Maintain test coverage > 80%

#### 3. Documentation Requirements
- Update README if needed
- Document new APIs
- Update architecture docs
- Add code comments

### Getting Help

#### 1. Development Resources
- **Flutter Docs**: https://flutter.dev/docs
- **Dart Docs**: https://dart.dev/guides
- **Firebase Docs**: https://firebase.google.com/docs
- **Riverpod Docs**: https://riverpod.dev/docs

#### 2. Community
- **Flutter Discord**: https://discord.gg/flutter
- **Stack Overflow**: Tag with `flutter` and `firebase`
- **GitHub Discussions**: Use repository discussions

#### 3. Team Communication
- **Slack**: #agos-development
- **Email**: dev-team@agos.com
- **Meetings**: Weekly standup on Mondays

---

**Last Updated**: September 2024  
**Version**: 1.0.0
