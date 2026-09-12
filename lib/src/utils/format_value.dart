import '../options/apex_options.dart';

/// Number formatting helpers matching ApexCharts' default label formatters
/// (`Formatters.defaultYFormatter` / `defaultGeneralFormatter`).
class FormatValue {
  const FormatValue._();

  /// ApexCharts' default: whole numbers print without decimals; otherwise the
  /// value is shown with up to [maxDecimals] significant decimals, trailing
  /// zeros trimmed.
  ///
  /// **REVIA deviations from upstream:**
  /// - Real ApexCharts does not group thousands by default (axis
  ///   labels/tooltips print "8000000" verbatim) — confirmed reported as
  ///   hard to read on real dashboards. Every value through here gets
  ///   Chilean/Spanish-style grouping instead: `.` every 3 digits in the
  ///   integer part, `,` as the decimal separator (e.g. `740100` →
  ///   `740.100`, `1.2` stays `1,2`).
  /// - [maxDecimals] defaults to 1, not 3: an unrounded average (e.g.
  ///   `4988.822`) read as noisy false precision on a real dashboard. A
  ///   chart that explicitly configures `decimals` (via `ApexValueFormat`)
  ///   still gets exactly that instead of this default.
  static String number(num value, {int maxDecimals = 1}) {
    String s;
    if (value == value.truncate()) {
      s = value.toInt().toString();
    } else {
      s = value.toStringAsFixed(maxDecimals);
      // Trim trailing zeros and a dangling decimal point.
      if (s.contains('.')) {
        s = s.replaceAll(RegExp(r'0+$'), '');
        s = s.replaceAll(RegExp(r'\.$'), '');
      }
    }
    return _groupThousands(s);
  }

  /// Inserts `.` every 3 digits in the integer part of [s] (a plain
  /// `-?\d+(\.\d+)?` string, e.g. from `toString`/`toStringAsFixed`) and
  /// swaps its `.` decimal separator for `,` — Chilean/Spanish convention.
  static String _groupThousands(String s) {
    final bool negative = s.startsWith('-');
    final unsigned = negative ? s.substring(1) : s;
    final dotIndex = unsigned.indexOf('.');
    final String intPart =
        dotIndex == -1 ? unsigned : unsigned.substring(0, dotIndex);
    final String? decPart =
        dotIndex == -1 ? null : unsigned.substring(dotIndex + 1);

    final buffer = StringBuffer();
    final len = intPart.length;
    for (int i = 0; i < len; i++) {
      if (i > 0 && (len - i) % 3 == 0) buffer.write('.');
      buffer.write(intPart[i]);
    }
    final grouped = decPart == null ? buffer.toString() : '$buffer,$decPart';
    return negative ? '-$grouped' : grouped;
  }

  /// Apply an [ApexValueFormat] (prefix/suffix/decimals) to a value, matching
  /// the common `tooltip.y.formatter` use cases (currency, %, units).
  static String formatted(num value, ApexValueFormat fmt) {
    final String core = fmt.decimals != null
        ? _groupThousands(value.toStringAsFixed(fmt.decimals!))
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
