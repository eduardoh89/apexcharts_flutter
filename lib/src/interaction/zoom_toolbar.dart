import 'package:flutter/material.dart';

/// A minimal reproduction of ApexCharts' chart toolbar (the reset/home icon
/// shown top-right). We expose just the **reset zoom** action, which is the
/// one users need most; zoom-in/out is available via wheel + drag-select.
class ZoomToolbar extends StatelessWidget {
  const ZoomToolbar({
    super.key,
    required this.isZoomed,
    required this.onReset,
    this.fontFamily,
  });

  final bool isZoomed;
  final VoidCallback onReset;
  final String? fontFamily;

  @override
  Widget build(BuildContext context) {
    if (!isZoomed) return const SizedBox.shrink();
    return Material(
      color: const Color(0xF5FFFFFF),
      borderRadius: BorderRadius.circular(4),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onReset,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.home_outlined, size: 16, color: Color(0xFF6E8192)),
              const SizedBox(width: 4),
              Text(
                'Reset zoom',
                style: TextStyle(
                  fontFamily: fontFamily,
                  fontSize: 12,
                  color: const Color(0xFF6E8192),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
