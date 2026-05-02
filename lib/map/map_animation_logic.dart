import 'package:geolocator/geolocator.dart';

class MapAnimationLogic {
  MapAnimationLogic({
    this.idleAnimationName = 'CharacterArmature|Idle',
    this.walkAnimationName = 'CharacterArmature|Walk',
    this.runAnimationName = 'Run',
    this.walkActivationDelay = const Duration(milliseconds: 500),
    this.movementStopGrace = const Duration(milliseconds: 600),
    this.movementSpeedThresholdMps = 0.55,
    this.runningSpeedThresholdMps = 2.1,
    this.movementDistanceThresholdMeters = 1.8,
    this.derivedSpeedThresholdMps = 0.45,
    this.runningDerivedSpeedThresholdMps = 2.0,
    this.maxReliableAccuracyMeters = 25,
  });

  final String idleAnimationName;
  final String walkAnimationName;
  final String runAnimationName;
  final Duration walkActivationDelay;
  final Duration movementStopGrace;
  final double movementSpeedThresholdMps;
  final double runningSpeedThresholdMps;
  final double movementDistanceThresholdMeters;
  final double derivedSpeedThresholdMps;
  final double runningDerivedSpeedThresholdMps;
  final double maxReliableAccuracyMeters;

  Position? _lastAnimationPosition;
  DateTime? _lastAnimationSampleAt;
  DateTime? _movementStartedAt;
  DateTime? _lastMovingDetectedAt;
  String _lastMovementAnimationName = 'CharacterArmature|Walk';
  String _currentAnimationName = 'CharacterArmature|Idle';

  String get currentAnimationName => _currentAnimationName;

  String updateAnimation(Position position, DateTime now) {
    final bool movingBySpeed = position.speed >= movementSpeedThresholdMps;
    final bool runningBySpeed = position.speed >= runningSpeedThresholdMps;
    bool movingByDistance = false;
    bool runningByDistance = false;

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
        runningByDistance = movedMeters >= movementDistanceThresholdMeters &&
            derivedSpeed >= runningDerivedSpeedThresholdMps;
      }
    }

    _lastAnimationPosition = position;
    _lastAnimationSampleAt = now;

    final bool isMovingNow = movingBySpeed || movingByDistance;
    final bool isRunningNow = runningBySpeed || runningByDistance;

    if (isMovingNow) {
      _lastMovingDetectedAt = now;
      _lastMovementAnimationName =
          isRunningNow ? runAnimationName : walkAnimationName;
    }

    final bool inStopGrace = _lastMovingDetectedAt != null &&
        now.difference(_lastMovingDetectedAt!) < movementStopGrace;
    final bool isMoving = isMovingNow || inStopGrace;

    if (!isMoving) {
      _movementStartedAt = null;
      _currentAnimationName = idleAnimationName;
      return _currentAnimationName;
    }

    if (!isMovingNow && inStopGrace) {
      _currentAnimationName = _lastMovementAnimationName;
      return _currentAnimationName;
    }

    if (isRunningNow) {
      _movementStartedAt = now;
      _currentAnimationName = runAnimationName;
      return _currentAnimationName;
    }

    _movementStartedAt ??= now;
    final bool shouldWalk =
        now.difference(_movementStartedAt!) >= walkActivationDelay;
    _currentAnimationName = shouldWalk ? walkAnimationName : idleAnimationName;
    return _currentAnimationName;
  }
}
