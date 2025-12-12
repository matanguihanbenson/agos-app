class TrashCollectionData {
  final String id;
  final String botId;
  final String riverId;
  final DateTime timestamp;
  final double totalWeight; // kg
  final Map<String, double> trashComposition; // trash type -> weight in kg

  const TrashCollectionData({
    required this.id,
    required this.botId,
    required this.riverId,
    required this.timestamp,
    required this.totalWeight,
    required this.trashComposition,
  });

  // Get percentage of each trash type
  Map<String, double> getTrashPercentages() {
    if (totalWeight == 0) return {};
    return trashComposition.map(
      (type, weight) => MapEntry(type, (weight / totalWeight) * 100),
    );
  }

  // Get dominant trash type
  String getDominantTrashType() {
    if (trashComposition.isEmpty) return 'None';
    return trashComposition.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'botId': botId,
      'riverId': riverId,
      'timestamp': timestamp.toIso8601String(),
      'totalWeight': totalWeight,
      'trashComposition': trashComposition,
    };
  }

  factory TrashCollectionData.fromJson(Map<String, dynamic> json) {
    return TrashCollectionData(
      id: json['id'] as String,
      botId: json['botId'] as String,
      riverId: json['riverId'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      totalWeight: (json['totalWeight'] as num).toDouble(),
      trashComposition: Map<String, double>.from(
        (json['trashComposition'] as Map).map(
          (key, value) => MapEntry(key as String, (value as num).toDouble()),
        ),
      ),
    );
  }
}

// Trash types enum for consistency
class TrashTypes {
  static const String plastic = 'Plastic';
  static const String paper = 'Paper';
  static const String metal = 'Metal';
  static const String glass = 'Glass';
  static const String organic = 'Organic';

  static List<String> get all => [
        plastic,
        paper,
        metal,
        glass,
        organic,
      ];
}