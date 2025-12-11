class TelemetryKeys {
  // Canonical keys we reference in app code
  static const String status = 'status';
  static const String battery = 'battery_level';
  static const String ph = 'ph_level';
  static const String temp = 'temp';
  static const String turbidity = 'turbidity';
  static const String trash = 'trash_collected';
  static const String lat = 'lat';
  static const String lng = 'lng';
  static const String currentScheduleId = 'current_schedule_id';
  static const String currentDeploymentId = 'current_deployment_id';

  // Helper to read value from a map with a list of alternative keys
  static T? read<T>(Map<String, dynamic> map, List<String> keys) {
    for (final k in keys) {
      if (map.containsKey(k) && map[k] != null) {
        return map[k] as T?;
      }
    }
    return null;
  }
}
