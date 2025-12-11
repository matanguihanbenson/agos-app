import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';

// Notification Service Provider
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

// Notification State
class NotificationState {
  final List<NotificationModel> notifications;
  final bool isLoading;
  final String? error;
  final int unreadCount;

  const NotificationState({
    this.notifications = const [],
    this.isLoading = false,
    this.error,
    this.unreadCount = 0,
  });

  NotificationState copyWith({
    List<NotificationModel>? notifications,
    bool? isLoading,
    String? error,
    int? unreadCount,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

// Notification Notifier
class NotificationNotifier extends Notifier<NotificationState> {
  @override
  NotificationState build() {
    return const NotificationState();
  }

  // Load notifications for a user
  Future<void> loadNotifications(String userId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final notificationService = ref.read(notificationServiceProvider);
      final notifications = await notificationService.getNotificationsByUser(userId);
      final unreadCount = await notificationService.getUnreadCountByUser(userId);

      state = state.copyWith(
        notifications: notifications,
        unreadCount: unreadCount,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  // Load notifications by type
  Future<void> loadNotificationsByType(String userId, NotificationType type) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final notificationService = ref.read(notificationServiceProvider);
      final notifications = await notificationService.getNotificationsByUserAndType(userId, type);

      state = state.copyWith(
        notifications: notifications,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  // Load unread notifications
  Future<void> loadUnreadNotifications(String userId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final notificationService = ref.read(notificationServiceProvider);
      final notifications = await notificationService.getUnreadNotificationsByUser(userId);

      state = state.copyWith(
        notifications: notifications,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  // Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      final notificationService = ref.read(notificationServiceProvider);
      await notificationService.markAsRead(notificationId);

      // Update local state
      final updatedNotifications = state.notifications.map((notification) {
        if (notification.id == notificationId) {
          return notification.copyWith(isRead: true);
        }
        return notification;
      }).toList();

      final newUnreadCount = updatedNotifications.where((n) => !n.isRead).length;

      state = state.copyWith(
        notifications: updatedNotifications,
        unreadCount: newUnreadCount,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  // Mark all as read
  Future<void> markAllAsRead(String userId) async {
    try {
      final notificationService = ref.read(notificationServiceProvider);
      await notificationService.markAllAsReadForUser(userId);

      // Update local state
      final updatedNotifications = state.notifications.map((notification) {
        return notification.copyWith(isRead: true);
      }).toList();

      state = state.copyWith(
        notifications: updatedNotifications,
        unreadCount: 0,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  // Refresh unread count
  Future<void> refreshUnreadCount(String userId) async {
    try {
      final notificationService = ref.read(notificationServiceProvider);
      final unreadCount = await notificationService.getUnreadCountByUser(userId);

      state = state.copyWith(unreadCount: unreadCount);
    } catch (e) {
      // Silently fail for count refresh
    }
  }

  // Create bot alert notification
  Future<void> createBotAlert({
    required String userId,
    required String botId,
    required String botName,
    required String alertMessage,
  }) async {
    try {
      final notificationService = ref.read(notificationServiceProvider);
      await notificationService.createBotAlert(
        userId: userId,
        botId: botId,
        botName: botName,
        alertMessage: alertMessage,
      );

      // Refresh notifications
      await loadNotifications(userId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  // Create bot assignment notification
  Future<void> createBotAssignment({
    required String userId,
    required String botId,
    required String botName,
    required String assignedByName,
  }) async {
    try {
      final notificationService = ref.read(notificationServiceProvider);
      await notificationService.createBotAssignment(
        userId: userId,
        botId: botId,
        botName: botName,
        assignedByName: assignedByName,
      );

      // Refresh notifications
      await loadNotifications(userId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

// Notification Provider
final notificationProvider = NotifierProvider<NotificationNotifier, NotificationState>(() {
  return NotificationNotifier();
});
