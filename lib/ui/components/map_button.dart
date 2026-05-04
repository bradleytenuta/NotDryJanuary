import 'package:flutter/material.dart';

class MapButton extends StatelessWidget {
  const MapButton({
    super.key,
    required this.onPressed,
    required this.heroTag,
    required this.icon,
    required this.tooltip,
    this.topOffset = 16,
  });

  final VoidCallback onPressed;
  final String heroTag;
  final IconData icon;
  final String tooltip;
  final double topOffset;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(top: topOffset, right: 16),
        child: Align(
          alignment: Alignment.topRight,
          child: FloatingActionButton.small(
            heroTag: heroTag,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            elevation: 6,
            tooltip: tooltip,
            onPressed: onPressed,
            child: Icon(icon),
          ),
        ),
      ),
    );
  }
}