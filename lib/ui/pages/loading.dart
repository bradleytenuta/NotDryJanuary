import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'map.dart';
import '../../map/mapbox.dart';

class Loading extends StatefulWidget {
  const Loading({super.key});

  @override
  State<Loading> createState() => _LoadingState();
}

class _LoadingState extends State<Loading> {
  bool _showLoading = true;

  /// After 7 seconds, we hide the loading screen and reveal
  /// the map that has been loading in the background.
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 7), () {
      setState(() {
        _showLoading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Stack(
      children: [
        MapScreen(mapProviderBuilder: mapboxMap),
        IgnorePointer(
          ignoring: !_showLoading,
          child: AnimatedOpacity(
            opacity: _showLoading ? 1 : 0,
            duration: const Duration(milliseconds: 500),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
              child: Container(
                color: theme.scaffoldBackgroundColor.withOpacity(0.5),
                alignment: Alignment.center,
                child: Transform.scale(
                  scale: 2,
                  child: Lottie.asset(
                    'assets/lottie/liquid-fill.json',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
