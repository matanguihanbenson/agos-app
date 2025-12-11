class ActiveDeploymentInfo {
  final String scheduleId;
  final String scheduleName;
  final String botId;
  final String botName;
  final String riverId;
  final String riverName;
  
  // Real-time data from RTDB
  final double? currentLat;
  final double? currentLng;
  final int? battery;
  final String? status;
  final bool? solarCharging;
  final double? trashCollected;
  final DateTime scheduledStartTime;
  final String? operationLocation;
  
  // Water quality sensor data
  final double? temperature;
  final double? phLevel;
  final double? turbidity;
  
  // Trash collection metrics
  final double? currentLoad; // Current trash load in kg
  final double? maxLoad; // Maximum capacity in kg
  final double? riverTotalToday; // Total trash collected on this river today (all bots)

  ActiveDeploymentInfo({
    required this.scheduleId,
    required this.scheduleName,
    required this.botId,
    required this.botName,
    required this.riverId,
    required this.riverName,
    this.currentLat,
    this.currentLng,
    this.battery,
    this.status,
    this.solarCharging,
    this.trashCollected,
    required this.scheduledStartTime,
    this.operationLocation,
    this.temperature,
    this.phLevel,
    this.turbidity,
    this.currentLoad,
    this.maxLoad,
    this.riverTotalToday,
  });

  bool get hasLocation => currentLat != null && currentLng != null;
  
  String get statusDisplay {
    switch (status?.toLowerCase()) {
      case 'active':
        return 'Active';
      case 'deployed':
        return 'Deployed';
      case 'scheduled':
        return 'Scheduled';
      case 'recalling':
        return 'Returning';
      default:
        return status ?? 'Unknown';
    }
  }

  ActiveDeploymentInfo copyWith({
    String? scheduleId,
    String? scheduleName,
    String? botId,
    String? botName,
    String? riverId,
    String? riverName,
    double? currentLat,
    double? currentLng,
    int? battery,
    String? status,
    double? trashCollected,
    DateTime? scheduledStartTime,
    String? operationLocation,
    double? temperature,
    double? phLevel,
    double? turbidity,
    double? currentLoad,
    double? maxLoad,
    double? riverTotalToday,
  }) {
    return ActiveDeploymentInfo(
      scheduleId: scheduleId ?? this.scheduleId,
      scheduleName: scheduleName ?? this.scheduleName,
      botId: botId ?? this.botId,
      botName: botName ?? this.botName,
      riverId: riverId ?? this.riverId,
      riverName: riverName ?? this.riverName,
      currentLat: currentLat ?? this.currentLat,
      currentLng: currentLng ?? this.currentLng,
      battery: battery ?? this.battery,
      status: status ?? this.status,
      solarCharging: solarCharging ?? this.solarCharging,
      trashCollected: trashCollected ?? this.trashCollected,
      scheduledStartTime: scheduledStartTime ?? this.scheduledStartTime,
      operationLocation: operationLocation ?? this.operationLocation,
      temperature: temperature ?? this.temperature,
      phLevel: phLevel ?? this.phLevel,
      turbidity: turbidity ?? this.turbidity,
      currentLoad: currentLoad ?? this.currentLoad,
      maxLoad: maxLoad ?? this.maxLoad,
      riverTotalToday: riverTotalToday ?? this.riverTotalToday,
    );
  }
}
