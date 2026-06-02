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

  /// Default datetime tooltip title: "dd MMM" (e.g. "5 Jan").
  static String dateTitle(num msEpoch) {
    final d = DateTime.fromMillisecondsSinceEpoch(msEpoch.round());
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]}';
  }
}
