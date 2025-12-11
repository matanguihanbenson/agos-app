import 'base_model.dart';

enum NotificationType {
  botAlert,
  botUpdate,
  userActivity,
  system,
  assignment,
  maintenance
}

class NotificationModel extends BaseModel {
  final String title;
  final String message;
  final NotificationType type;
  final String userId; // User who should receive the notification
  final bool isRead;
  final String? relatedEntityId; // Bot ID, User ID, etc.
  final String? relatedEntityType; // 'bot', 'user', 'organization'
  final Map<String, dynamic>? metadata;

  NotificationModel({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    required this.title,
    required this.message,
    required this.type,
    required this.userId,
    this.isRead = false,
    this.relatedEntityId,
    this.relatedEntityType,
    this.metadata,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map, String id) {
    return NotificationModel(
      id: id,
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      type: NotificationType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => NotificationType.system,
      ),
      userId: map['user_id'] ?? '',
      isRead: map['is_read'] ?? false,
      relatedEntityId: map['related_entity_id'],
      relatedEntityType: map['related_entity_type'],
      metadata: map['metadata'],
      createdAt: map['created_at']?.toDate() ?? DateTime.now(),
      updatedAt: map['updated_at']?.toDate() ?? DateTime.now(),
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'message': message,
      'type': type.name,
      'user_id': userId,
      'is_read': isRead,
      'related_entity_id': relatedEntityId,
      'related_entity_type': relatedEntityType,
      'metadata': metadata,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  @override
  NotificationModel copyWith({
    String? id,
    String? title,
    String? message,
    NotificationType? type,
    String? userId,
    bool? isRead,
    String? relatedEntityId,
    String? relatedEntityType,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      userId: userId ?? this.userId,
      isRead: isRead ?? this.isRead,
      relatedEntityId: relatedEntityId ?? this.relatedEntityId,
      relatedEntityType: relatedEntityType ?? this.relatedEntityType,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Helper getters
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return '${(difference.inDays / 7).floor()}w';
    }
  }

  String get dateGroup {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inHours < 1) {
      return 'New';
    } else if (difference.inHours < 24) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return 'This Week';
    } else {
      return 'Older';
    }
  }

  bool get hasAction {
    return type == NotificationType.assignment ||
           type == NotificationType.botAlert ||
           type == NotificationType.maintenance ||
           type == NotificationType.userActivity;
  }

  String get actionLabel {
    switch (type) {
      case NotificationType.botAlert:
        return 'View Bot';
      case NotificationType.assignment:
        return 'View Assignment';
      case NotificationType.maintenance:
        return 'Schedule Maintenance';
      case NotificationType.userActivity:
        return 'View Profile';
      default:
        return 'View';
    }
  }

  @override
  String toString() {
    return 'NotificationModel(id: $id, title: $title, type: $type, userId: $userId, isRead: $isRead)';
  }
}
