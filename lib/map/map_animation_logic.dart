import 'package:geolocator/geolocator.dart';

class MapAnimationLogic {
  MapAnimationLogic({
    this.idleAnimationName = 'CharacterArmature|Idle',
    this.walkAnimationName = 'CharacterArmature|Walk',
    this.walkActivationDelay = const Duration(milliseconds: 500),
    this.movementStopGrace = const Duration(milliseconds: 600),
    this.movementSpeedThresholdMps = 0.55,
    this.movementDistanceThresholdMeters = 1.8,
    this.derivedSpeedThresholdMps = 0.45,
    this.maxReliableAccuracyMeters = 25,
  });

  final String idleAnimationName;
  final String walkAnimationName;
  final Duration walkActivationDelay;
  final Duration movementStopGrace;
  final double movementSpeedThresholdMps;
  final double movementDistanceThresholdMeters;
  final double derivedSpeedThresholdMps;
  final double maxReliableAccuracyMeters;

  Position? _lastAnimationPosition;
  DateTime? _lastAnimationSampleAt;
  DateTime? _movementStartedAt;
  DateTime? _lastMovingDetectedAt;
  String _currentAnimationName = 'CharacterArmature|Idle';

  String get currentAnimationName => _currentAnimationName;

  String updateAnimation(Position position, DateTime now) {
    final bool movingBySpeed = position.speed >= movementSpeedThresholdMps;
    bool movingByDistance = false;

    if (position.accuracy <= maxReliableAccuracyMeters &&
        _lastAnimationPosition != null &&
        _lastAnimationSampleAt != null) {
      final double elapsedSeconds =
          now.difference(_lastAnimationSampleAt!).inMilliseconds / 1000;
      if (elapsedSeconds > 0) {
        final double movedMeters = Geolocator.distanceBetween(
          _lastAnimationPosition!.latitude,
          _lastAnimationPosition!.longitude,
          position.latitude,
          position.longitude,
        );
        final double derivedSpeed = movedMeters / elapsedSeconds;
        movingByDistance = movedMeters >= movementDistanceThresholdMeters &&
            derivedSpeed >= derivedSpeedThresholdMps;
      }
    }

    _lastAnimationPosition = position;
    _lastAnimationSampleAt = now;

    final bool isMovingNow = movingBySpeed || movingByDistance;

    if (isMovingNow) {
      _lastMovingDetectedAt = now;
    }

    final bool inStopGrace = _lastMovingDetectedAt != null &&
        now.difference(_lastMovingDetectedAt!) < movementStopGrace;
    final bool isMoving = isMovingNow || inStopGrace;

    if (!isMoving) {
      _movementStartedAt = null;
      _currentAnimationName = idleAnimationName;
      return _currentAnimationName;
    }

    _movementStartedAt ??= now;
    final bool shouldWalk =
        now.difference(_movementStartedAt!) >= walkActivationDelay;
    _currentAnimationName = shouldWalk ? walkAnimationName : idleAnimationName;
    return _currentAnimationName;
  }
}
