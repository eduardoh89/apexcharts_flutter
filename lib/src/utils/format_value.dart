import '../options/apex_options.dart';

/// Number formatting helpers matching ApexCharts' default label formatters
/// (`Formatters.defaultYFormatter` / `defaultGeneralFormatter`).
class FormatValue {
  const FormatValue._();

  /// ApexCharts' default: whole numbers print without decimals; otherwise the
  /// value is shown with up to [maxDecimals] significant decimals, trailing
  /// zeros trimmed. Thousands are not grouped by default.
  static String number(num value, {int maxDecimals = 3}) {
    if (value == value.truncate()) {
      return value.toInt().toString();
    }
    var s = value.toStringAsFixed(maxDecimals);
    // Trim trailing zeros and a dangling decimal point.
    if (s.contains('.')) {
      s = s.replaceAll(RegExp(r'0+$'), '');
      s = s.replaceAll(RegExp(r'\.$'), '');
    }
    return s;
  }

  /// Apply an [ApexValueFormat] (prefix/suffix/decimals) to a value, matching
  /// the common `tooltip.y.formatter` use cases (currency, %, units).
  static String formatted(num value, ApexValueFormat fmt) {
    final String core = fmt.decimals != null
        ? value.toStringAsFixed(fmt.decimals!)
        : number(value);
    return '${fmt.prefix}$core${fmt.suffix}';
  }

  /// Percentage with one decimal, matching the pie/donut data-label default.
  static String percent(num fraction) =>
      '${(fraction * 100).toStringAsFixed(1)}%';

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// Default datetime tooltip title: "d MMM" (e.g. "5 Jan").
  static String dateTitle(num msEpoch) {
    final d = DateTime.fromMillisecondsSinceEpoch(msEpoch.round());
    return '${d.day} ${_months[d.month - 1]}';
  }

  /// Format an epoch-ms value using an ApexCharts-style date format token
  /// string. Supports the common tokens used in demos: `dd`, `d`, `MMM`,
  /// `MM`, `yyyy`, `yy`, `HH`, `mm`. Falls back to [dateTitle] when [format]
  /// is null/empty.
  static String date(num msEpoch, String? format) {
    if (format == null || format.isEmpty) return dateTitle(msEpoch);
    final d = DateTime.fromMillisecondsSinceEpoch(msEpoch.round());
    String two(int v) => v.toString().padLeft(2, '0');
    // Replace longest tokens first to avoid partial collisions.
    return format
        .replaceAll('yyyy', d.year.toString())
        .replaceAll('yy', two(d.year % 100))
        .replaceAll('MMM', _months[d.month - 1])
        .replaceAll('MM', two(d.month))
        .replaceAll('dd', two(d.day))
        .replaceAll('HH', two(d.hour))
        .replaceAll('mm', two(d.minute))
        // Bare single-letter tokens last.
        .replaceAll('d', d.day.toString());
  }
}
