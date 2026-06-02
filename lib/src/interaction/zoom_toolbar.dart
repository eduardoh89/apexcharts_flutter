import 'package:flutter/material.dart';

/// The interactive mode selected in the toolbar, mirroring ApexCharts'
/// `zoomEnabled` / `panEnabled` globals (selection-zoom vs. pan-the-axis).
enum ZoomMode { selectionZoom, pan }

/// A reproduction of ApexCharts' chart toolbar (top-right), ported from
/// `src/modules/Toolbar.js`. Buttons (left→right): zoom-in (+), zoom-out (−),
/// selection-zoom (magnifier, a toggle), pan (hand, a toggle) and reset (home,
/// active only while zoomed). The active mode button is highlighted, exactly
/// like ApexCharts' `apexcharts-selected` class.
class ZoomToolbar extends StatelessWidget {
  const ZoomToolbar({
    super.key,
    required this.isZoomed,
    required this.mode,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onReset,
    required this.onSelectMode,
  });

  final bool isZoomed;

  /// The currently active interaction mode (selection-zoom or pan).
  final ZoomMode mode;

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onReset;

  /// Called when the user toggles between selection-zoom and pan.
  final ValueChanged<ZoomMode> onSelectMode;

  static const Color _icon = Color(0xFF6E8192);
  static const Color _iconActive = Color(0xFF008FFB);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xF7FFFFFF),
      borderRadius: BorderRadius.circular(6),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _btn(
              icon: Icons.add,
              tooltip: 'Zoom in',
              onTap: onZoomIn,
              color: _icon,
            ),
            _btn(
              icon: Icons.remove,
              tooltip: 'Zoom out',
              onTap: onZoomOut,
              color: _icon,
            ),
            _btn(
              // Magnifier (ico-zoom-in / "Selection Zoom").
              icon: Icons.search,
              tooltip: 'Selection zoom',
              onTap: () => onSelectMode(ZoomMode.selectionZoom),
              color: mode == ZoomMode.selectionZoom ? _iconActive : _icon,
            ),
            _btn(
              // Pan hand (ico-pan-hand / "Panning").
              icon: Icons.pan_tool_outlined,
              tooltip: 'Panning',
              onTap: () => onSelectMode(ZoomMode.pan),
              color: mode == ZoomMode.pan ? _iconActive : _icon,
            ),
            _btn(
              icon: Icons.home_outlined,
              tooltip: 'Reset zoom',
              onTap: isZoomed ? onReset : null,
              color: isZoomed ? _iconActive : _icon.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _btn({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
    required Color color,
  }) {
    // Plain Semantics (not a Material Tooltip) so the toolbar works without an
    // Overlay ancestor — keeps ApexChart embeddable anywhere.
    return Semantics(
      label: tooltip,
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}
