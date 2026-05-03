import 'package:flutter/material.dart';

class MapActionButton extends StatelessWidget {
  const MapActionButton({
    super.key,
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: 16, right: 16),
        child: Align(
          alignment: Alignment.topRight,
          child: FloatingActionButton.small(
            heroTag: 'map-action-button',
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            elevation: 6,
            tooltip: 'Recenter map',
            onPressed: onPressed,
            child: const Icon(Icons.manage_accounts),
          ),
        ),
      ),
    );
  }
}