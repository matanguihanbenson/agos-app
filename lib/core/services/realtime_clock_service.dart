import 'dart:async';

class RealtimeClockService {
  static Timer? _timer;
  static final StreamController<DateTime> _clockController = 
      StreamController<DateTime>.broadcast();

  /// Stream of current time that updates every second
  static Stream<DateTime> get clockStream => _clockController.stream;

  /// Current time
  static DateTime get currentTime => DateTime.now();

  /// Start the real-time clock
  static void startClock() {
    if (_timer != null) {
      _timer!.cancel();
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _clockController.add(DateTime.now());
    });

    // Send initial time
    _clockController.add(DateTime.now());
  }

  /// Stop the real-time clock
  static void stopClock() {
    _timer?.cancel();
    _timer = null;
  }

  /// Dispose the clock service
  static void dispose() {
    stopClock();
    _clockController.close();
  }

  /// Format time for display (HH:mm)
  static String formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// Format date for display (MON DD-MM)
  static String formatDate(DateTime dateTime) {
    const months = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
    ];
    
    const weekdays = [
      'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'
    ];

    final weekday = weekdays[dateTime.weekday - 1];
    final month = months[dateTime.month - 1];
    final day = dateTime.day.toString().padLeft(2, '0');

    return '$weekday $day-$month';
  }

  /// Get weather condition based on time (mock data for now)
  static String getWeatherCondition(DateTime dateTime) {
    // This is mock data - in a real app, you'd fetch from a weather API
    final hour = dateTime.hour;
    
    if (hour >= 6 && hour < 12) {
      return 'Sunny';
    } else if (hour >= 12 && hour < 18) {
      return 'Cloudy';
    } else if (hour >= 18 && hour < 22) {
      return 'Partly Cloudy';
    } else {
      return 'Clear';
    }
  }

  /// Get weather icon based on condition
  static String getWeatherIcon(String condition) {
    switch (condition.toLowerCase()) {
      case 'sunny':
        return '☀️';
      case 'cloudy':
        return '☁️';
      case 'partly cloudy':
        return '⛅';
      case 'clear':
        return '🌙';
      case 'rainy':
        return '🌧️';
      case 'stormy':
        return '⛈️';
      default:
        return '☁️';
    }
  }

  /// Get temperature based on time (mock data for now)
  static int getTemperature(DateTime dateTime) {
    // This is mock data - in a real app, you'd fetch from a weather API
    final hour = dateTime.hour;
    final baseTemp = 25; // Base temperature
    
    // Simulate temperature variation throughout the day
    if (hour >= 6 && hour < 12) {
      return baseTemp + 5; // Morning: 30°C
    } else if (hour >= 12 && hour < 18) {
      return baseTemp + 8; // Afternoon: 33°C
    } else if (hour >= 18 && hour < 22) {
      return baseTemp + 2; // Evening: 27°C
    } else {
      return baseTemp - 3; // Night: 22°C
    }
  }

  /// Get high/low temperature for the day (mock data)
  static Map<String, int> getDailyTemperatureRange(DateTime dateTime) {
    // This is mock data - in a real app, you'd fetch from a weather API
    return {
      'high': 35,
      'low': 20,
    };
  }
}
