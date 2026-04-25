import 'dart:async';
import 'package:flutter/material.dart';
import '../map/map_screen.dart';

class AppStartupScreen extends StatefulWidget {
  const AppStartupScreen({super.key});

  @override
  State<AppStartupScreen> createState() => _AppStartupScreenState();
}

class _AppStartupScreenState extends State<AppStartupScreen> {
  bool _showFlash = true;
  bool _minDelayComplete = false;
  bool _mapReady = false;
  bool _modelReady = false;
  Timer? _flashTimer;

  @override
  void initState() {
    super.initState();
    _flashTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      _minDelayComplete = true;
      _hideFlashIfReady();
    });
  }

  void _onMapReady() {
    if (_mapReady) return;
    _mapReady = true;
    _hideFlashIfReady();
  }

  void _onModelReady() {
    if (_modelReady) return;
    _modelReady = true;
    _hideFlashIfReady();
  }

  void _hideFlashIfReady() {
    if (!_showFlash) return;
    if (!_minDelayComplete || !_mapReady || !_modelReady) return;
    if (!mounted) return;
    setState(() {
      _showFlash = false;
    });
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MapScreen(
          onMapReady: _onMapReady,
          onModelReady: _onModelReady,
        ),
        IgnorePointer(
          ignoring: !_showFlash,
          child: AnimatedOpacity(
            opacity: _showFlash ? 1 : 0,
            duration: const Duration(milliseconds: 350),
            child: const _FlashScreenOverlay(),
          ),
        ),
      ],
    );
  }
}

class _FlashScreenOverlay extends StatelessWidget {
  const _FlashScreenOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF7F3E8),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Text(
            'notdryjanuary',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: Color(0xFF1A3A2B),
            ),
          ),
          SizedBox(height: 12),
          CircularProgressIndicator(
            strokeWidth: 3,
            color: Color(0xFF1A3A2B),
          ),
        ],
      ),
    );
  }
}
