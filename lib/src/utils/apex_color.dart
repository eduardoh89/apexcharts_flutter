import 'dart:ui';

/// Color helpers ported from ApexCharts v4.7.0 `src/utils/Utils.js`.
///
/// ApexCharts works with CSS hex/rgba strings; in Flutter we operate on
/// [Color]. These helpers bridge the two and reproduce ApexCharts' shading
/// math so palettes look identical.
class ApexColor {
  const ApexColor._();

  /// Port of `Utils.isColorHex`: matches #RGB, #RRGGBB or #RRGGBBAA.
  static bool isColorHex(String color) {
    final re = RegExp(
      r'(^#[0-9A-F]{6}$)|(^#[0-9A-F]{3}$)|(^#[0-9A-F]{8}$)',
      caseSensitive: false,
    );
    return re.hasMatch(color);
  }

  /// Parse a CSS hex string (#RGB / #RRGGBB / #RRGGBBAA) into a [Color].
  /// Mirrors the lenient behaviour of `Utils.hexToRgba` which falls back to
  /// `#999999` for malformed input.
  static Color fromHex(String hex, {double opacity = 1.0}) {
    String h = hex;
    if (!h.startsWith('#')) h = '#999999';
    h = h.substring(1);

    if (h.length == 3) {
      h = h.split('').map((c) => '$c$c').join();
    }

    if (h.length == 6) {
      final int r = int.parse(h.substring(0, 2), radix: 16);
      final int g = int.parse(h.substring(2, 4), radix: 16);
      final int b = int.parse(h.substring(4, 6), radix: 16);
      return Color.fromRGBO(r, g, b, opacity);
    }

    if (h.length == 8) {
      final int r = int.parse(h.substring(0, 2), radix: 16);
      final int g = int.parse(h.substring(2, 4), radix: 16);
      final int b = int.parse(h.substring(4, 6), radix: 16);
      final int a = int.parse(h.substring(6, 8), radix: 16);
      return Color.fromRGBO(r, g, b, a / 255.0);
    }

    return const Color(0xFF999999).withValues(alpha: opacity);
  }

  /// Convert a [Color] to a `#RRGGBB` hex string (matches `Utils.rgb2hex`).
  static String toHex(Color color) {
    String two(int v) => v.toRadixString(16).padLeft(2, '0');
    final int r = (color.r * 255).round();
    final int g = (color.g * 255).round();
    final int b = (color.b * 255).round();
    return '#${two(r)}${two(g)}${two(b)}';
  }

  /// Port of `Utils.shadeHexColor` / `shadeRGBColor` combined.
  ///
  /// [percent] in [-1, 1]: positive lightens toward white, negative darkens
  /// toward black. This is ApexCharts' linear blend used for gradients and
  /// hover states.
  static Color shade(Color color, double percent) {
    final double t = percent < 0 ? 0 : 255;
    final double p = percent < 0 ? -percent : percent;
    final int r = (color.r * 255).round();
    final int g = (color.g * 255).round();
    final int b = (color.b * 255).round();
    final int nr = ((t - r) * p).round() + r;
    final int ng = ((t - g) * p).round() + g;
    final int nb = ((t - b) * p).round() + b;
    return Color.fromRGBO(
      nr.clamp(0, 255),
      ng.clamp(0, 255),
      nb.clamp(0, 255),
      color.a,
    );
  }
}
