import 'dart:ui';
import 'package:flutter/material.dart';

class MapButton extends StatelessWidget {
  const MapButton({
    super.key,
    required this.onPressed,
    required this.heroTag,
    this.icon,
    this.imagePath,
    this.customIcon,
    required this.tooltip,
    this.topOffset = 16,
  }) : assert(icon != null || imagePath != null || customIcon != null,
            'Either icon, imagePath, or customIcon must be provided');

  final VoidCallback onPressed;
  final String heroTag;
  final IconData? icon;
  final String? imagePath;
  final Widget? customIcon;
  final String tooltip;
  final double topOffset;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    Widget buttonContent;
    if (imagePath != null || customIcon != null) {
      buttonContent = SizedBox(
        width: 56,
        height: 56,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 6,
              top: 6,
              width: 44,
              height: 44,
              child: ClipOval(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withOpacity(0.68),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.colorScheme.primary.withOpacity(0.35),
                        width: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: -4,
              top: -4,
              width: 54,
              height: 54,
              child: IgnorePointer(
                child: customIcon ?? Image.asset(
                  imagePath!,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: Tooltip(
                  message: tooltip,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onPressed,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      buttonContent = ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withOpacity(0.68),
              shape: BoxShape.circle,
              border: Border.all(
                color: theme.colorScheme.primary.withOpacity(0.35),
                width: 1,
              ),
            ),
            child: IconButton(
              tooltip: tooltip,
              onPressed: onPressed,
              icon: Icon(
                icon,
                color: theme.colorScheme.primary,
                size: 20,
              ),
            ),
          ),
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(top: topOffset, right: 16),
        child: Align(
          alignment: Alignment.topRight,
          child: Hero(
            tag: heroTag,
            child: Material(
              color: Colors.transparent,
              child: buttonContent,
            ),
          ),
        ),
      ),
    );
  }
}
