class WaterQualityData {
  final String id;
  final String botId;
  final String riverId;
  final DateTime timestamp;
  final double turbidity; // NTU (Nephelometric Turbidity Units)
  final double waterTemp; // Celsius
  final double phLevel; // pH scale (0-14)
  final double dissolvedOxygen; // mg/L

  const WaterQualityData({
    required this.id,
    required this.botId,
    required this.riverId,
    required this.timestamp,
    required this.turbidity,
    required this.waterTemp,
    required this.phLevel,
    required this.dissolvedOxygen,
  });

  // Get quality status based on thresholds
  String getTurbidityStatus() {
    if (turbidity < 5) return 'Excellent';
    if (turbidity < 25) return 'Good';
    if (turbidity < 50) return 'Fair';
    return 'Poor';
  }

  String getPhStatus() {
    if (phLevel >= 6.5 && phLevel <= 8.5) return 'Normal';
    if (phLevel >= 6.0 && phLevel <= 9.0) return 'Acceptable';
    return 'Poor';
  }

  String getWaterTempStatus() {
    if (waterTemp >= 15 && waterTemp <= 30) return 'Normal';
    if (waterTemp < 15) return 'Cold';
    return 'Warm';
  }

  String getDOStatus() {
    if (dissolvedOxygen >= 6) return 'Good';
    if (dissolvedOxygen >= 4) return 'Acceptable';
    return 'Poor';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'botId': botId,
      'riverId': riverId,
      'timestamp': timestamp.toIso8601String(),
      'turbidity': turbidity,
      'waterTemp': waterTemp,
      'phLevel': phLevel,
      'dissolvedOxygen': dissolvedOxygen,
    };
  }

  factory WaterQualityData.fromJson(Map<String, dynamic> json) {
    return WaterQualityData(
      id: json['id'] as String,
      botId: json['botId'] as String,
      riverId: json['riverId'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      turbidity: (json['turbidity'] as num).toDouble(),
      waterTemp: (json['waterTemp'] as num).toDouble(),
      phLevel: (json['phLevel'] as num).toDouble(),
      dissolvedOxygen: (json['dissolvedOxygen'] as num).toDouble(),
    );
  }
}