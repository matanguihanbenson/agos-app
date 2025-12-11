enum TimePeriod {
  today,
  week,
  month,
  year,
  custom;

  String get displayName {
    switch (this) {
      case TimePeriod.today:
        return 'Today';
      case TimePeriod.week:
        return 'This Week';
      case TimePeriod.month:
        return 'This Month';
      case TimePeriod.year:
        return 'This Year';
      case TimePeriod.custom:
        return 'Custom';
    }
  }

  DateTimeRange getDateRange() {
    final now = DateTime.now();
    switch (this) {
      case TimePeriod.today:
        // Full day: 12:00 AM to 11:59 PM
        return DateTimeRange(
          start: DateTime(now.year, now.month, now.day, 0, 0),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
      case TimePeriod.week:
        // Current month's weeks
        final startOfMonth = DateTime(now.year, now.month, 1);
        final endOfMonth = DateTime(now.year, now.month + 1, 0);
        return DateTimeRange(
          start: startOfMonth,
          end: endOfMonth,
        );
      case TimePeriod.month:
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
        );
      case TimePeriod.year:
        // Full year: January to December
        return DateTimeRange(
          start: DateTime(now.year, 1, 1, 0, 0),
          end: DateTime(now.year, 12, 31, 23, 59, 59),
        );
      case TimePeriod.custom:
        // Return last 30 days as default for custom
        return DateTimeRange(
          start: now.subtract(const Duration(days: 30)),
          end: now,
        );
    }
  }

  // Get time labels for charts based on period
  List<String> getTimeLabels() {
    switch (this) {
      case TimePeriod.today:
        // All hours: 12am to 11pm
        return ['12am', '1am', '2am', '3am', '4am', '5am', '6am', '7am', '8am', '9am', '10am', '11am',
                '12pm', '1pm', '2pm', '3pm', '4pm', '5pm', '6pm', '7pm', '8pm', '9pm', '10pm', '11pm'];
      case TimePeriod.week:
        // All days: Monday to Sunday
        return ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      case TimePeriod.month:
        // All weeks: Week 1 to Week 4
        return ['Week 1', 'Week 2', 'Week 3', 'Week 4'];
      case TimePeriod.year:
        // All months: January to December
        return ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      case TimePeriod.custom:
        return [];
    }
  }

  // Get number of time slots for the period
  int getTimeSlotCount() {
    switch (this) {
      case TimePeriod.today:
        return 24; // 24 hours
      case TimePeriod.week:
        return 7; // 7 days
      case TimePeriod.month:
        return 4; // 4 weeks
      case TimePeriod.year:
        return 12; // 12 months
      case TimePeriod.custom:
        return 0;
    }
  }
}

class MonitoringFilters {
  final String? selectedRiverId;
  final String? selectedBotId;
  final TimePeriod timePeriod;
  final DateTimeRange? customDateRange;

  const MonitoringFilters({
    this.selectedRiverId,
    this.selectedBotId,
    this.timePeriod = TimePeriod.week,
    this.customDateRange,
  });

  MonitoringFilters copyWith({
    String? selectedRiverId,
    String? selectedBotId,
    TimePeriod? timePeriod,
    DateTimeRange? customDateRange,
  }) {
    return MonitoringFilters(
      selectedRiverId: selectedRiverId ?? this.selectedRiverId,
      selectedBotId: selectedBotId ?? this.selectedBotId,
      timePeriod: timePeriod ?? this.timePeriod,
      customDateRange: customDateRange ?? this.customDateRange,
    );
  }

  MonitoringFilters clearRiver() {
    return MonitoringFilters(
      selectedRiverId: null,
      selectedBotId: selectedBotId,
      timePeriod: timePeriod,
      customDateRange: customDateRange,
    );
  }

  MonitoringFilters clearBot() {
    return MonitoringFilters(
      selectedRiverId: selectedRiverId,
      selectedBotId: null,
      timePeriod: timePeriod,
      customDateRange: customDateRange,
    );
  }

  DateTimeRange getEffectiveDateRange() {
    if (timePeriod == TimePeriod.custom && customDateRange != null) {
      return customDateRange!;
    }
    return timePeriod.getDateRange();
  }
}

class DateTimeRange {
  final DateTime start;
  final DateTime end;

  const DateTimeRange({
    required this.start,
    required this.end,
  });
}