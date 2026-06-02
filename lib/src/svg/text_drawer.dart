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

  TextPainter _painter(String text) {
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
