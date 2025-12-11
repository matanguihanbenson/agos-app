# AGOS - Autonomous Garbage Observation System

A comprehensive Flutter application for managing river cleaning bots, built following clean architecture principles with Riverpod state management.

## Features

- **Authentication**: Firebase Auth with role-based access control
- **Bot Management**: Registration, monitoring, and control of cleaning bots
- **User Management**: Admin and field operator roles with permissions
- **Organization Management**: Multi-tenant organization support
- **Real-time Monitoring**: Live bot status and location tracking
- **QR Code Scanning**: Easy bot registration via QR codes
- **Modern UI**: Material Design 3 with custom theming

## Architecture

This app follows the AGOS Architecture Blueprint with:

- **Clean Architecture**: Separation of presentation, business logic, and data layers
- **State Management**: Riverpod for centralized, reactive state management
- **Modular Design**: Feature-based organization with reusable components
- **Scalable Structure**: Easy to add new features and maintain

## Project Structure

```
lib/
├── core/                    # Core functionality
│   ├── constants/          # App constants and configurations
│   ├── models/             # Data models (User, Bot, Organization)
│   ├── providers/          # Riverpod providers for state management
│   ├── services/           # Business logic and data operations
│   ├── theme/              # Theming system (colors, text styles)
│   ├── utils/              # Utility functions (validators, error handling)
│   ├── widgets/            # Reusable UI components
│   └── routes/             # App routing and navigation
├── features/               # Feature modules
│   ├── auth/               # Authentication feature
│   └── bots/               # Bot management feature
├── shared/                 # Shared components
│   ├── navigation/         # Navigation components
│   └── widgets/            # Shared UI widgets
├── main.dart               # App entry point
└── app.dart                # Main app widget
```

## Setup Instructions

### Prerequisites

- Flutter SDK (>=3.0.0)
- Dart SDK
- Firebase project
- Android Studio / VS Code

### 1. Clone and Install Dependencies

```bash
git clone <repository-url>
cd agos_app
flutter pub get
```

### 2. Firebase Setup

1. Create a new Firebase project at [Firebase Console](https://console.firebase.google.com/)
2. Enable Authentication (Email/Password)
3. Create a Firestore database
4. Run FlutterFire CLI to configure Firebase:

```bash
flutterfire configure
```

This will generate the `firebase_options.dart` file with your project configuration.

### 3. Firestore Security Rules

Set up the following Firestore security rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can read/write their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Organizations
    match /organizations/{orgId} {
      allow read, write: if request.auth != null;
    }
    
    // Bots
    match /bots/{botId} {
      allow read, write: if request.auth != null;
    }
    
    // Logs (read-only for users)
    match /{collection}/{document} {
      allow read: if request.auth != null;
      allow write: if false; // Only server-side writes
    }
  }
}
```

### 4. Run the App

```bash
flutter run
```

## Key Components

### State Management

The app uses Riverpod for state management with the following providers:

- `authProvider`: Authentication state
- `botProvider`: Bot management state
- `userProvider`: User management state
- `organizationProvider`: Organization state

### Theming

Custom theming system with:
- Consistent color palette
- Typography using Google Fonts (Inter)
- Reusable component styles
- Material Design 3 compliance

### Services

- `AuthService`: Firebase Authentication
- `BotService`: Bot CRUD operations
- `UserService`: User management
- `OrganizationService`: Organization management
- `LoggingService`: Centralized logging

### Models

- `UserModel`: User data with role-based permissions
- `BotModel`: Bot information and status
- `OrganizationModel`: Organization data
- `BaseModel`: Common model functionality

## Development Guidelines

### Adding New Features

1. Create feature directory under `lib/features/`
2. Follow the structure: `providers/`, `pages/`, `widgets/`, `services/`
3. Use existing patterns for state management
4. Follow naming conventions (snake_case for files, PascalCase for classes)

### Code Style

- Follow Flutter/Dart conventions
- Use meaningful variable and function names
- Add comments for complex logic
- Keep functions small and focused
- Use const constructors where possible

### Testing

```bash
# Run tests
flutter test

# Run integration tests
flutter test integration_test/
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Follow the coding standards
4. Add tests for new functionality
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support and questions, please open an issue in the repository or contact the development team.