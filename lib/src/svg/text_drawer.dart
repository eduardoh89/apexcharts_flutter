import 'package:flutter/painting.dart';

/// Horizontal anchor for text, mirroring SVG `text-anchor`.
enum TextAnchor { start, middle, end }

/// Small helper around [TextPainter] for axis labels, data labels and legend
/// text. ApexCharts defaults to an 11px sans-serif for axis labels with a
/// muted grey (#373d3f at ~0.65 opacity); we reproduce those defaults so the
/// chrome matches without per-call boilerplate.
class TextDrawer {
  TextDrawer({
    this.fontSize = 11,
    this.color = const Color(0xFF6E8192),
    this.fontWeight = FontWeight.w400,
    this.fontFamily,
  });

  final double fontSize;
  final Color color;
  final FontWeight fontWeight;
  final String? fontFamily;

  /// Process-wide cache of laid-out [TextPainter]s, keyed by text + style.
  /// Axis/legend/data labels re-render the same strings every frame during the
  /// mount/pan/zoom animations; caching the `.layout()` (the dominant cost in
  /// Skia text) avoids paying for it on every repaint. A [TextPainter] is only
  /// read (sized / painted at an offset) after layout, so sharing one instance
  /// across draws within a single-threaded paint is safe.
  static final Map<_TextKey, TextPainter> _cache = {};
  static const int _maxCacheEntries = 512;

  TextPainter _painter(String text) {
    final key = _TextKey(text, fontSize, color, fontWeight, fontFamily);
    final cached = _cache[key];
    if (cached != null) return cached;

    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          color: color,
          fontWeight: fontWeight,
          fontFamily: fontFamily,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();

    // Bound the cache so long-lived charts with churning labels (datetime
    // ticks, live data) can't grow it without limit. A flat clear is fine —
    // misses just re-layout, which is the pre-cache cost.
    if (_cache.length >= _maxCacheEntries) _cache.clear();
    _cache[key] = tp;
    return tp;
  }

  /// Measure the rendered size of [text].
  Size measure(String text) {
    final tp = _painter(text);
    return tp.size;
  }

  /// Draw [text] at [anchor] position [at]. When [rotation] is non-zero the
  /// text is rotated about [at] (radians, positive = clockwise).
  void draw(
    Canvas canvas,
    String text,
    Offset at, {
    TextAnchor anchor = TextAnchor.start,
    double rotation = 0,
    bool verticalCenter = false,
  }) {
    final tp = _painter(text);
    double dx = at.dx;
    switch (anchor) {
      case TextAnchor.start:
        break;
      case TextAnchor.middle:
        dx -= tp.width / 2;
      case TextAnchor.end:
        dx -= tp.width;
    }
    double dy = at.dy;
    if (verticalCenter) dy -= tp.height / 2;

    if (rotation == 0) {
      tp.paint(canvas, Offset(dx, dy));
      return;
    }

    // Rotate about the anchor point [at]. Offsets relative to [at] reproduce
    // the anchoring (start/middle/end + optional vertical centering).
    final double ox = switch (anchor) {
      TextAnchor.start => 0.0,
      TextAnchor.middle => -tp.width / 2,
      TextAnchor.end => -tp.width,
    };
    final double oy = verticalCenter ? -tp.height / 2 : 0.0;

    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(rotation);
    tp.paint(canvas, Offset(ox, oy));
    canvas.restore();
  }
}

/// Cache key for [TextDrawer]'s laid-out [TextPainter]s: the text plus every
/// style input that affects its layout/paint.
class _TextKey {
  const _TextKey(
    this.text,
    this.fontSize,
    this.color,
    this.fontWeight,
    this.fontFamily,
  );

  final String text;
  final double fontSize;
  final Color color;
  final FontWeight fontWeight;
  final String? fontFamily;

  @override
  bool operator ==(Object other) =>
      other is _TextKey &&
      other.text == text &&
      other.fontSize == fontSize &&
      other.color == color &&
      other.fontWeight == fontWeight &&
      other.fontFamily == fontFamily;

  @override
  int get hashCode =>
      Object.hash(text, fontSize, color, fontWeight, fontFamily);
}
