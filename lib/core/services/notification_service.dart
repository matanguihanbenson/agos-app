import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';
import 'base_service.dart';

class NotificationService extends BaseService<NotificationModel> {
  @override
  String get collectionName => 'notifications';

  @override
  NotificationModel fromMap(Map<String, dynamic> map, String id) {
    return NotificationModel.fromMap(map, id);
  }

  // Get notifications for a specific user
  Future<List<NotificationModel>> getNotificationsByUser(String userId) async {
    try {
      final snapshot = await firestore
          .collection(collectionName)
          .where('user_id', isEqualTo: userId)
          .orderBy('created_at', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      await loggingService.logError(
        error: e.toString(),
        context: '${collectionName}_getNotificationsByUser',
      );
      rethrow;
    }
  }

  // Get unread notifications for a specific user
  Future<List<NotificationModel>> getUnreadNotificationsByUser(String userId) async {
    try {
      final snapshot = await firestore
          .collection(collectionName)
          .where('user_id', isEqualTo: userId)
          .where('is_read', isEqualTo: false)
          .orderBy('created_at', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      await loggingService.logError(
        error: e.toString(),
        context: '${collectionName}_getUnreadNotificationsByUser',
      );
      rethrow;
    }
  }

  // Get notifications by type for a specific user
  Future<List<NotificationModel>> getNotificationsByUserAndType(
    String userId,
    NotificationType type,
  ) async {
    try {
      final snapshot = await firestore
          .collection(collectionName)
          .where('user_id', isEqualTo: userId)
          .where('type', isEqualTo: type.name)
          .orderBy('created_at', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      await loggingService.logError(
        error: e.toString(),
        context: '${collectionName}_getNotificationsByUserAndType',
      );
      rethrow;
    }
  }

  // Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await firestore
          .collection(collectionName)
          .doc(notificationId)
          .update({
        'is_read': true,
        'updated_at': FieldValue.serverTimestamp(),
      });

      await loggingService.logEvent(
        event: 'notification_marked_read',
        parameters: {'notification_id': notificationId},
      );
    } catch (e) {
      await loggingService.logError(
        error: e.toString(),
        context: '${collectionName}_markAsRead',
      );
      rethrow;
    }
  }

  // Mark all notifications as read for a user
  Future<void> markAllAsReadForUser(String userId) async {
    try {
      final batch = firestore.batch();
      final snapshot = await firestore
          .collection(collectionName)
          .where('user_id', isEqualTo: userId)
          .where('is_read', isEqualTo: false)
          .get();

      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {
          'is_read': true,
          'updated_at': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      await loggingService.logEvent(
        event: 'notifications_marked_all_read',
        parameters: {'user_id': userId, 'count': snapshot.docs.length},
      );
    } catch (e) {
      await loggingService.logError(
        error: e.toString(),
        context: '${collectionName}_markAllAsReadForUser',
      );
      rethrow;
    }
  }

  // Create notification for bot alert
  Future<void> createBotAlert({
    required String userId,
    required String botId,
    required String botName,
    required String alertMessage,
  }) async {
    final notification = NotificationModel(
      id: '',
      title: 'Bot Alert: $botName',
      message: alertMessage,
      type: NotificationType.botAlert,
      userId: userId,
      relatedEntityId: botId,
      relatedEntityType: 'bot',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await create(notification);
  }

  // Create notification for bot assignment
  Future<void> createBotAssignment({
    required String userId,
    required String botId,
    required String botName,
    required String assignedByName,
  }) async {
    final notification = NotificationModel(
      id: '',
      title: 'Bot Assignment',
      message: '$botName has been assigned to you by $assignedByName',
      type: NotificationType.assignment,
      userId: userId,
      relatedEntityId: botId,
      relatedEntityType: 'bot',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await create(notification);
  }

  // Create notification for maintenance reminder
  Future<void> createMaintenanceReminder({
    required String userId,
    required String botId,
    required String botName,
  }) async {
    final notification = NotificationModel(
      id: '',
      title: 'Maintenance Required',
      message: '$botName requires scheduled maintenance',
      type: NotificationType.maintenance,
      userId: userId,
      relatedEntityId: botId,
      relatedEntityType: 'bot',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await create(notification);
  }

  // Create notification for system updates
  Future<void> createSystemNotification({
    required String userId,
    required String title,
    required String message,
  }) async {
    final notification = NotificationModel(
      id: '',
      title: title,
      message: message,
      type: NotificationType.system,
      userId: userId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await create(notification);
  }

  // Get notification count by user
  Future<int> getUnreadCountByUser(String userId) async {
    try {
      final snapshot = await firestore
          .collection(collectionName)
          .where('user_id', isEqualTo: userId)
          .where('is_read', isEqualTo: false)
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      await loggingService.logError(
        error: e.toString(),
        context: '${collectionName}_getUnreadCountByUser',
      );
      return 0;
    }
  }

  // Get notifications with pagination
  Future<List<NotificationModel>> getNotificationsByUserPaginated({
    required String userId,
    DocumentSnapshot? lastDocument,
    int limit = 20,
  }) async {
    try {
      Query query = firestore
          .collection(collectionName)
          .where('user_id', isEqualTo: userId)
          .orderBy('created_at', descending: true)
          .limit(limit);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final snapshot = await query.get();

      return snapshot.docs
          .map((doc) => fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      await loggingService.logError(
        error: e.toString(),
        context: '${collectionName}_getNotificationsByUserPaginated',
      );
      rethrow;
    }
  }
}
