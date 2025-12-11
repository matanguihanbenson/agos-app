# UI Components & Design System

## 🎨 Overview

AGOS uses a comprehensive design system built on Material Design 3 principles with custom theming and reusable components. This document outlines all UI components, their usage, and design guidelines.

## 🎯 Design Principles

### Core Principles
- **Minimalistic**: Clean, uncluttered interfaces
- **Consistent**: Uniform design language across all screens
- **Accessible**: Inclusive design for all users
- **Responsive**: Adapts to different screen sizes
- **Intuitive**: Easy to understand and navigate

### Visual Identity
- **Color Palette**: Ocean-inspired blues and greens
- **Typography**: Clear, readable fonts with proper hierarchy
- **Spacing**: Consistent padding and margins
- **Shadows**: Subtle depth and elevation
- **Borders**: Rounded corners for modern feel

## 🎨 Color System

### Primary Colors (`lib/core/theme/color_palette.dart`)

```dart
class AppColors {
  // Primary Colors
  static const Color primary = Color(0xFF1976D2);        // Ocean Blue
  static const Color primaryDark = Color(0xFF1565C0);    // Darker Blue
  static const Color primaryLight = Color(0xFF42A5F5);   // Lighter Blue
  
  // Secondary Colors
  static const Color secondary = Color(0xFF4CAF50);      // Ocean Green
  static const Color secondaryDark = Color(0xFF388E3C);  // Darker Green
  static const Color secondaryLight = Color(0xFF81C784); // Lighter Green
  
  // Status Colors
  static const Color success = Color(0xFF4CAF50);        // Green
  static const Color warning = Color(0xFFFF9800);        // Orange
  static const Color error = Color(0xFFF44336);          // Red
  static const Color info = Color(0xFF2196F3);           // Blue
  
  // Neutral Colors
  static const Color surface = Color(0xFFFFFFFF);        // White
  static const Color background = Color(0xFFF5F5F5);     // Light Gray
  static const Color textPrimary = Color(0xFF212121);    // Dark Gray
  static const Color textSecondary = Color(0xFF757575);  // Medium Gray
  static const Color textMuted = Color(0xFFBDBDBD);      // Light Gray
  static const Color border = Color(0xFFE0E0E0);         // Border Gray
}
```

### Status Color Mapping
- **Deployed**: Green (`#4CAF50`)
- **Maintenance**: Blue (`#2196F3`)
- **Idle**: Orange (`#FF9800`)
- **Offline**: Red (`#F44336`)
- **Online**: Green (`#4CAF50`)

## 📝 Typography System

### Text Styles (`lib/core/theme/text_styles.dart`)

```dart
class AppTextStyles {
  // Headers
  static TextStyle get titleLarge => GoogleFonts.roboto(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );
  
  static TextStyle get titleMedium => GoogleFonts.roboto(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );
  
  static TextStyle get titleSmall => GoogleFonts.roboto(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );
  
  // Body Text
  static TextStyle get bodyLarge => GoogleFonts.roboto(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );
  
  static TextStyle get bodyMedium => GoogleFonts.roboto(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );
  
  static TextStyle get bodySmall => GoogleFonts.roboto(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.3,
  );
  
  // Labels
  static TextStyle get labelLarge => GoogleFonts.roboto(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );
  
  static TextStyle get labelMedium => GoogleFonts.roboto(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.3,
  );
  
  static TextStyle get labelSmall => GoogleFonts.roboto(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    height: 1.2,
  );
}
```

## 🧩 Core Components

### 1. Custom Text Field (`lib/core/widgets/custom_text_field.dart`)

**Purpose**: Standardized text input with consistent styling

**Features**:
- Label and hint text support
- Prefix/suffix icons
- Validation error display
- Read-only mode
- Multi-line support

**Usage**:
```dart
CustomTextField(
  controller: _nameController,
  label: 'Bot Name',
  hint: 'Enter bot name',
  prefixIcon: Icons.directions_boat,
  validator: (value) => Validators.validateRequired(value, 'Bot name'),
  maxLines: 1,
)
```

**Props**:
- `controller`: TextEditingController
- `label`: String (required)
- `hint`: String (optional)
- `prefixIcon`: IconData (optional)
- `suffixIcon`: IconData (optional)
- `validator`: String? Function(String?) (optional)
- `readOnly`: bool (default: false)
- `maxLines`: int (default: 1)
- `obscureText`: bool (default: false)

### 2. Custom Button (`lib/core/widgets/custom_button.dart`)

**Purpose**: Standardized button with consistent styling

**Features**:
- Primary and outlined variants
- Loading state support
- Icon support
- Disabled state
- Custom colors

**Usage**:
```dart
CustomButton(
  text: 'Register Bot',
  onPressed: _registerBot,
  isLoading: _isLoading,
  icon: Icons.add,
)
```

**Props**:
- `text`: String (required)
- `onPressed`: VoidCallback? (optional)
- `isLoading`: bool (default: false)
- `isOutlined`: bool (default: false)
- `icon`: IconData (optional)
- `backgroundColor`: Color (optional)
- `textColor`: Color (optional)

### 3. Loading Indicator (`lib/core/widgets/loading_indicator.dart`)

**Purpose**: Consistent loading states across the app

**Features**:
- Circular progress indicator
- Customizable size and color
- Centered positioning
- Optional message

**Usage**:
```dart
LoadingIndicator(
  message: 'Loading bots...',
  size: 40,
)
```

### 4. Empty State (`lib/core/widgets/empty_state.dart`)

**Purpose**: Display when no data is available

**Features**:
- Customizable icon and message
- Action button support
- Consistent styling

**Usage**:
```dart
EmptyState(
  icon: Icons.directions_boat,
  title: 'No Bots Found',
  message: 'No bots are currently registered.',
  actionText: 'Register Bot',
  onAction: _registerBot,
)
```

### 5. Error State (`lib/core/widgets/error_state.dart`)

**Purpose**: Display error messages with retry option

**Features**:
- Error message display
- Retry button
- Consistent styling

**Usage**:
```dart
ErrorState(
  error: 'Failed to load bots',
  onRetry: _loadBots,
)
```

## 🧭 Navigation Components

### 1. Global App Bar (`lib/core/widgets/app_bar.dart`)

**Purpose**: Consistent app bar across all screens

**Features**:
- Hamburger menu (drawer toggle)
- Page title
- Notification icon with badge
- Back button support

**Usage**:
```dart
const GlobalAppBar(
  title: 'Bot Management',
  showDrawer: true,
  showNotifications: true,
  onNotificationTap: _showNotifications,
)
```

### 2. App Sidebar (`lib/core/widgets/app_sidebar.dart`)

**Purpose**: Main navigation drawer

**Features**:
- App branding and logo
- User profile section
- Navigation links
- Footer actions (Settings, Sign Out)

**Structure**:
- Header with logo and app name
- User profile card
- Navigation items
- Footer actions

### 3. Role-Based Bottom Navigation (`lib/shared/navigation/bottom_navigation.dart`)

**Purpose**: Bottom navigation with role-specific items

**Admin Navigation**:
- Map
- Bots
- Dashboard
- Management
- Monitoring

**Field Operator Navigation**:
- Map
- Control
- Dashboard
- Schedule
- Monitoring

## 📱 Page Components

### 1. Page Wrapper (`lib/core/widgets/page_wrapper.dart`)

**Purpose**: Consistent page layout wrapper

**Features**:
- Scrollable content support
- Consistent padding
- Safe area handling

**Usage**:
```dart
PageWrapper(
  scrollable: true,
  child: Column(
    children: [
      // Page content
    ],
  ),
)
```

### 2. Search Bar (`lib/shared/widgets/search_bar.dart`)

**Purpose**: Reusable search input component

**Features**:
- Search icon
- Clear button
- Placeholder text
- On-change callback

**Usage**:
```dart
SearchBar(
  controller: _searchController,
  hint: 'Search bots...',
  onChanged: _filterBots,
)
```

## 🤖 Bot-Specific Components

### 1. Bot Card (`lib/features/bots/widgets/bot_card.dart`)

**Purpose**: Display bot information in card format

**Features**:
- Bot icon and name
- Online/offline status
- Location with reverse geocoding
- Status indicator
- Action buttons
- Assigned user display

**Layout**:
```
┌─────────────────────────────────────┐
│ [Icon] Bot Name        [Online]     │
│        ID: BOT-001                  │
│                                     │
│ Status: DEPLOYED                    │
│ Location: City, Country             │
│ Assigned to: John Doe               │
│                                     │
│ [Live Feed] [Control] [Assign]      │
└─────────────────────────────────────┘
```

### 2. Bot Status Indicator (`lib/features/bots/widgets/bot_status_indicator.dart`)

**Purpose**: Visual status representation

**Status Types**:
- **Deployed**: Green circle with checkmark
- **Idle**: Orange circle with pause icon
- **Maintenance**: Blue circle with wrench icon
- **Offline**: Red circle with X icon

## 🗺️ Map Components

### 1. Realtime Map (`lib/features/map/pages/realtime_map_page.dart`)

**Purpose**: Interactive map with real-time bot locations

**Features**:
- Flutter Maps integration
- Real-time bot markers
- Status color indicators
- Bot name labels
- Zoom controls
- Active bot counter

### 2. Bot Markers

**Design**:
- Status color indicator (top)
- Bot icon (center)
- Bot name label (bottom)
- Online/offline status
- Tap interaction for details

## 📊 Data Display Components

### 1. Statistics Cards

**Purpose**: Display numerical data in card format

**Features**:
- Icon and value
- Label and description
- Color coding
- Responsive layout

**Usage**:
```dart
_buildStatCard(
  icon: Icons.directions_boat,
  value: '12',
  label: 'Total Bots',
  color: AppColors.primary,
)
```

### 2. Info Cards

**Purpose**: Display information in structured format

**Features**:
- Icon and label
- Value display
- Consistent styling
- Responsive design

## 🎛️ Form Components

### 1. Dropdown Selector

**Purpose**: Custom dropdown with consistent styling

**Features**:
- Label and hint text
- Icon support
- Validation
- Disabled state

**Usage**:
```dart
Container(
  decoration: BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: AppColors.border),
  ),
  child: DropdownButtonHideUnderline(
    child: DropdownButton<String>(
      value: _selectedValue,
      hint: Text('Select option'),
      items: options.map((option) {
        return DropdownMenuItem<String>(
          value: option,
          child: Text(option),
        );
      }).toList(),
      onChanged: (value) => setState(() => _selectedValue = value),
    ),
  ),
)
```

### 2. Tab Bar

**Purpose**: Custom tab bar with sliding indicator

**Features**:
- Sliding background
- Smooth animations
- Custom styling
- Responsive design

## 🔔 Notification Components

### 1. Notification List Item

**Purpose**: Display individual notifications

**Features**:
- Notification type icon
- Title and message
- Timestamp
- Read/unread indicator
- Action buttons

### 2. Notification Badge

**Purpose**: Show unread notification count

**Features**:
- Red circle with count
- Animated updates
- Positioned on icons

## 📱 Responsive Design

### Breakpoints
- **Mobile**: < 600px
- **Tablet**: 600px - 1024px
- **Desktop**: > 1024px

### Layout Adaptations
- **Mobile**: Single column, stacked components
- **Tablet**: Two columns, side-by-side components
- **Desktop**: Multi-column, complex layouts

## 🎨 Animation Guidelines

### Transitions
- **Page Navigation**: 300ms ease-in-out
- **Modal Appearance**: 250ms ease-out
- **Button Press**: 150ms ease-in
- **Loading States**: 500ms linear

### Micro-interactions
- **Button Hover**: Scale 1.05
- **Card Hover**: Elevation increase
- **Icon Tap**: Scale 0.95
- **Swipe Gestures**: Smooth following

## ♿ Accessibility

### Guidelines
- **Color Contrast**: WCAG AA compliance
- **Touch Targets**: Minimum 44px
- **Screen Reader**: Semantic labels
- **Keyboard Navigation**: Full support
- **Focus Indicators**: Clear visibility

### Implementation
```dart
// Example: Accessible button
Semantics(
  label: 'Register new bot',
  button: true,
  child: CustomButton(
    text: 'Register Bot',
    onPressed: _registerBot,
  ),
)
```

## 🚀 Performance Optimization

### Component Optimization
- **Lazy Loading**: Load components on demand
- **Memoization**: Cache expensive calculations
- **Image Optimization**: Compress and resize images
- **State Management**: Efficient state updates

### Best Practices
- Use `const` constructors where possible
- Implement `shouldRebuild` for custom widgets
- Optimize list rendering with `ListView.builder`
- Minimize widget rebuilds

---

**Last Updated**: September 2024  
**Version**: 1.0.0
