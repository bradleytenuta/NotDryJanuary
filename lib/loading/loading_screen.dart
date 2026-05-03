import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../map/map_screen.dart';
import '../map/providers/mapbox_maps_flutter_provider.dart';

class AppStartupScreen extends StatefulWidget {
  const AppStartupScreen({super.key});

  @override
  State<AppStartupScreen> createState() => _AppStartupScreenState();
}

class _AppStartupScreenState extends State<AppStartupScreen> {
  bool _showLoading = true;
  bool _minDelayComplete = false;
  bool _mapReady = false;
  bool _modelReady = false;
  Timer? _loadingTimer;

  @override
  void initState() {
    super.initState();
    _loadingTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      _minDelayComplete = true;
      _hideLoadingIfReady();
    });
  }

  void _onMapReady() {
    if (_mapReady) return;
    _mapReady = true;
    _hideLoadingIfReady();
  }

  void _onModelReady() {
    if (_modelReady) return;
    _modelReady = true;
    _hideLoadingIfReady();
  }

  void _hideLoadingIfReady() {
    if (!_showLoading) return;
    if (!_minDelayComplete || !_mapReady || !_modelReady) return;
    if (!mounted) return;
    setState(() {
      _showLoading = false;
    });
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MapScreen(
          mapProviderBuilder: buildMapboxMapsFlutterProvider,
          onMapReady: _onMapReady,
          onModelReady: _onModelReady,
        ),
        IgnorePointer(
          ignoring: !_showLoading,
          child: AnimatedOpacity(
            opacity: _showLoading ? 1 : 0,
            duration: const Duration(milliseconds: 350),
            child: const _LoadingScreenOverlay(),
          ),
        ),
      ],
    );
  }
}

class _LoadingScreenOverlay extends StatelessWidget {
  const _LoadingScreenOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      alignment: Alignment.center,
      child: Transform.scale(
        scale: 2,
        child: Lottie.asset(
          'assets/lottie/liquid-fill.json',
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
