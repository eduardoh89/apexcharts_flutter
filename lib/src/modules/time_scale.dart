/// Datetime x-axis tick generation, ported from ApexCharts v4.7.0
/// `src/modules/TimeScale.js` + `src/utils/DateTime.js`.
///
/// ApexCharts does *not* place datetime ticks at evenly spaced fractions of the
/// range; it snaps them to calendar boundaries (year/month/day/hour starts) and
/// picks both the tick interval and the label format from how wide the visible
/// window is. This module reproduces that: given the visible [minMs, maxMs]
/// window it returns calendar-aligned ticks, each carrying the formatted label
/// for its unit (e.g. a multi-year span labels years as `yyyy`, a sub-year span
/// labels months as `MMM 'yy`, and a few-day span labels days as `dd MMM`).
library;

/// One generated datetime tick: its timestamp and pre-formatted label.
class TimeTick {
  const TimeTick(this.ms, this.label);
  final double ms;
  final String label;
}

/// The tick interval bucket, mirroring `TimeScale.determineInterval`.
enum _TickUnit { years, months, days, hours, minutes, seconds }

/// Calendar-aligned datetime axis ticks and labels, ported from ApexCharts
/// `TimeScale.js`. Picks a sensible unit (years / months / days / hours / …)
/// for the visible span and formats each tick accordingly.
class TimeScale {
  const TimeScale._();

  static const List<String> _shortMonths = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// Generate calendar-aligned datetime ticks across [minMs, maxMs].
  ///
  /// [tickAmount] mirrors `xaxis.tickAmount` (target tick count); when null a
  /// density of ~1 tick / 120px is used, approximated here from [gridWidth].
  static List<TimeTick> ticks(
    double minMs,
    double maxMs, {
    int? tickAmount,
    double gridWidth = 600,
  }) {
    if (!(maxMs > minMs)) return const [];
    final double daysDiff = (maxMs - minMs) / 86400000.0;
    final _TickUnit unit = _determineInterval(daysDiff);

    final raw = switch (unit) {
      _TickUnit.years => _yearTicks(minMs, maxMs),
      _TickUnit.months => _monthTicks(minMs, maxMs),
      _TickUnit.days => _dayTicks(minMs, maxMs),
      _TickUnit.hours => _hourTicks(minMs, maxMs),
      _TickUnit.minutes => _minuteTicks(minMs, maxMs),
      _TickUnit.seconds => _secondTicks(minMs, maxMs),
    };

    // Thin to the target count (ApexCharts: tickAmount, else gridWidth/120).
    final int target =
        tickAmount ?? (gridWidth / 120).ceil().clamp(2, raw.length);
    if (raw.length <= target || target <= 0) return raw;
    final int modulo = (raw.length / target).floor().clamp(1, raw.length);
    final out = <TimeTick>[];
    for (int i = 0; i < raw.length; i++) {
      if (i % modulo == 0) out.add(raw[i]);
    }
    return out;
  }

  /// `TimeScale.determineInterval` — choose the unit from the span in days.
  static _TickUnit _determineInterval(double daysDiff) {
    final double yearsDiff = daysDiff / 365;
    final double hoursDiff = daysDiff * 24;
    final double minutesDiff = hoursDiff * 60;
    if (yearsDiff > 5) return _TickUnit.years;
    if (daysDiff > 180) return _TickUnit.months;
    // 30 < daysDiff <= 180 → ApexCharts uses month/day blends; we render days
    // for the shorter end and months for the longer, both as month-aligned.
    if (daysDiff > 60) return _TickUnit.months;
    if (daysDiff > 2) return _TickUnit.days;
    if (hoursDiff > 2.4) return _TickUnit.hours;
    if (minutesDiff > 5) return _TickUnit.minutes;
    return _TickUnit.seconds;
  }

  static List<TimeTick> _yearTicks(double minMs, double maxMs) {
    final out = <TimeTick>[];
    final start = DateTime.fromMillisecondsSinceEpoch(minMs.round());
    int year = start.year + (start.month > 1 || start.day > 1 ? 1 : 0);
    while (true) {
      final dt = DateTime(year);
      final ms = dt.millisecondsSinceEpoch.toDouble();
      if (ms > maxMs) break;
      if (ms >= minMs) out.add(TimeTick(ms, '$year'));
      year++;
    }
    return out;
  }

  static List<TimeTick> _monthTicks(double minMs, double maxMs) {
    final out = <TimeTick>[];
    final start = DateTime.fromMillisecondsSinceEpoch(minMs.round());
    int year = start.year;
    int month = start.month + (start.day > 1 ? 1 : 0);
    if (month > 12) {
      month = 1;
      year++;
    }
    while (true) {
      final dt = DateTime(year, month);
      final ms = dt.millisecondsSinceEpoch.toDouble();
      if (ms > maxMs) break;
      if (ms >= minMs) out.add(TimeTick(ms, _monthLabel(dt)));
      month++;
      if (month > 12) {
        month = 1;
        year++;
      }
    }
    return out;
  }

  static List<TimeTick> _dayTicks(double minMs, double maxMs) {
    final out = <TimeTick>[];
    final start = DateTime.fromMillisecondsSinceEpoch(minMs.round());
    var day = DateTime(start.year, start.month, start.day);
    if (day.millisecondsSinceEpoch < minMs) {
      day = day.add(const Duration(days: 1));
    }
    while (day.millisecondsSinceEpoch <= maxMs) {
      out.add(TimeTick(day.millisecondsSinceEpoch.toDouble(), _dayLabel(day)));
      day = day.add(const Duration(days: 1));
    }
    return out;
  }

  static List<TimeTick> _hourTicks(double minMs, double maxMs) {
    final out = <TimeTick>[];
    final start = DateTime.fromMillisecondsSinceEpoch(minMs.round());
    var hour = DateTime(start.year, start.month, start.day, start.hour);
    if (hour.millisecondsSinceEpoch < minMs) {
      hour = hour.add(const Duration(hours: 1));
    }
    while (hour.millisecondsSinceEpoch <= maxMs) {
      out.add(
          TimeTick(hour.millisecondsSinceEpoch.toDouble(), _timeLabel(hour)));
      hour = hour.add(const Duration(hours: 1));
    }
    return out;
  }

  static List<TimeTick> _minuteTicks(double minMs, double maxMs) {
    final out = <TimeTick>[];
    final start = DateTime.fromMillisecondsSinceEpoch(minMs.round());
    var minute =
        DateTime(start.year, start.month, start.day, start.hour, start.minute);
    if (minute.millisecondsSinceEpoch < minMs) {
      minute = minute.add(const Duration(minutes: 1));
    }
    while (minute.millisecondsSinceEpoch <= maxMs) {
      out.add(TimeTick(
          minute.millisecondsSinceEpoch.toDouble(), _timeLabel(minute)));
      minute = minute.add(const Duration(minutes: 1));
    }
    return out;
  }

  static List<TimeTick> _secondTicks(double minMs, double maxMs) {
    final out = <TimeTick>[];
    final start = DateTime.fromMillisecondsSinceEpoch(minMs.round());
    var sec = DateTime(start.year, start.month, start.day, start.hour,
        start.minute, start.second);
    if (sec.millisecondsSinceEpoch < minMs) {
      sec = sec.add(const Duration(seconds: 1));
    }
    while (sec.millisecondsSinceEpoch <= maxMs) {
      out.add(
          TimeTick(sec.millisecondsSinceEpoch.toDouble(), _secondLabel(sec)));
      sec = sec.add(const Duration(seconds: 1));
    }
    return out;
  }

  // Default datetimeFormatter (settings/Options.js):
  //   year 'yyyy', month "MMM 'yy", day 'dd MMM', hour 'HH:mm'
  static String _monthLabel(DateTime d) =>
      "${_shortMonths[d.month - 1]} '${(d.year % 100).toString().padLeft(2, '0')}";

  static String _dayLabel(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} ${_shortMonths[d.month - 1]}';

  static String _timeLabel(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  static String _secondLabel(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';
}
