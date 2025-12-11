import 'package:cloud_firestore/cloud_firestore.dart';
import 'base_model.dart';

class BotRegistryModel extends BaseModel {
  final bool isRegistered;
  final String? registeredBy;
  final DateTime? registeredAt;
  
  BotRegistryModel({
    required String id, // This is the bot ID (document ID)
    required this.isRegistered,
    this.registeredBy,
    this.registeredAt,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : super(
          id: id,
          createdAt: createdAt,
          updatedAt: updatedAt,
        );

  // Getter for bot ID (which is the document ID)
  String get botId => id;

  factory BotRegistryModel.fromMap(Map<String, dynamic> map, String id) {
    return BotRegistryModel(
      id: id, // Document ID is the bot ID
      isRegistered: map['is_registered'] ?? false,
      registeredBy: map['registered_by'],
      registeredAt: (map['registered_at'] as Timestamp?)?.toDate(),
      createdAt: (map['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      // Note: bot_id is not included as it's the document ID
      'is_registered': isRegistered,
      'registered_by': registeredBy,
      'registered_at': registeredAt != null ? Timestamp.fromDate(registeredAt!) : null,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
    };
  }

  @override
  BotRegistryModel copyWith({
    bool? isRegistered,
    String? registeredBy,
    DateTime? registeredAt,
    DateTime? updatedAt,
  }) {
    return BotRegistryModel(
      id: id, // Bot ID remains the same (document ID)
      isRegistered: isRegistered ?? this.isRegistered,
      registeredBy: registeredBy ?? this.registeredBy,
      registeredAt: registeredAt ?? this.registeredAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'BotRegistryModel(id: $id, botId: $botId, isRegistered: $isRegistered, registeredBy: $registeredBy, registeredAt: $registeredAt)';
  }
}
