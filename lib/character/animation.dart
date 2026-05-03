import 'package:geolocator/geolocator.dart';

enum SpeedToTrigger {
  none,
  gpsSpeed,
  derivedSpeed,
}

enum AnimationRule {
  idle(
    animationName: 'CharacterArmature|Idle',
    speedThresholdMps: 0,
    speedToTrigger: SpeedToTrigger.none,
  ),
  walkGps(
    animationName: 'CharacterArmature|Walk',
    speedThresholdMps: 0.55,
    speedToTrigger: SpeedToTrigger.gpsSpeed,
  ),
  runGps(
    animationName: 'CharacterArmature|Run',
    speedThresholdMps: 2.1,
    speedToTrigger: SpeedToTrigger.gpsSpeed,
  ),
  walkDerived(
    animationName: 'CharacterArmature|Walk',
    speedThresholdMps: 0.45,
    speedToTrigger: SpeedToTrigger.derivedSpeed,
  ),
  runDerived(
    animationName: 'CharacterArmature|Run',
    speedThresholdMps: 2.0,
    speedToTrigger: SpeedToTrigger.derivedSpeed,
  );

  const AnimationRule({
    required this.animationName,
    required this.speedThresholdMps,
    required this.speedToTrigger,
  });

  final String animationName;
  final double speedThresholdMps;
  final SpeedToTrigger speedToTrigger;
}

class MapAnimationLogic {
  MapAnimationLogic({
    this.walkActivationDelay = const Duration(milliseconds: 500),
    this.movementStopGrace = const Duration(milliseconds: 600),
    this.movementDistanceThresholdMeters = 1.8,
    this.maxReliableAccuracyMeters = 25,
  });

  final Duration walkActivationDelay;
  final Duration movementStopGrace;
  final double movementDistanceThresholdMeters;
  final double maxReliableAccuracyMeters;

  Position? _lastAnimationPosition;
  DateTime? _lastAnimationSampleAt;
  DateTime? _movementStartedAt;
  DateTime? _lastMovingDetectedAt;
  String _lastMovementAnimationName = AnimationRule.walkGps.animationName;
  String _currentAnimationName = AnimationRule.idle.animationName;

  String get currentAnimationName => _currentAnimationName;

  /// Computes the next character animation name from current movement signals.
  String updateAnimation(Position position, DateTime now) {
    final ({bool isMovingNow, bool isRunningNow}) movementState =
        _computeInstantMovementState(position: position, now: now);

    _updateSamplingState(position: position, now: now);

    if (movementState.isMovingNow) {
      _updateLastDetectedMovement(
        now: now,
        isRunningNow: movementState.isRunningNow,
      );
    }

    final bool inStopGrace = _isWithinMovementStopGrace(now: now);
    final bool isMoving = movementState.isMovingNow || inStopGrace;

    if (!isMoving) {
      _movementStartedAt = null;
      _currentAnimationName = AnimationRule.idle.animationName;
      return _currentAnimationName;
    }

    if (!movementState.isMovingNow && inStopGrace) {
      _currentAnimationName = _lastMovementAnimationName;
      return _currentAnimationName;
    }

    if (movementState.isRunningNow) {
      _movementStartedAt = now;
      _currentAnimationName = AnimationRule.runGps.animationName;
      return _currentAnimationName;
    }

    _movementStartedAt ??= now;
    final bool shouldWalk =
        now.difference(_movementStartedAt!) >= walkActivationDelay;
    _currentAnimationName = shouldWalk
        ? AnimationRule.walkGps.animationName
        : AnimationRule.idle.animationName;
    return _currentAnimationName;
  }

  /// Combines GPS and derived-speed checks into current movement flags.
  ({bool isMovingNow, bool isRunningNow}) _computeInstantMovementState({
    required Position position,
    required DateTime now,
  }) {
    final bool movingBySpeed = _isMovingByGpsSpeed(position);
    final bool runningBySpeed = _isRunningByGpsSpeed(position);
    final ({bool movingByDistance, bool runningByDistance}) distanceState =
        _computeDerivedMovementState(position: position, now: now);

    return (
      isMovingNow: movingBySpeed || distanceState.movingByDistance,
      isRunningNow: runningBySpeed || distanceState.runningByDistance,
    );
  }

  /// Returns whether raw GPS speed is high enough for walking.
  bool _isMovingByGpsSpeed(Position position) {
    return position.speed >= AnimationRule.walkGps.speedThresholdMps;
  }

  /// Returns whether raw GPS speed is high enough for running.
  bool _isRunningByGpsSpeed(Position position) {
    return position.speed >= AnimationRule.runGps.speedThresholdMps;
  }

  /// Computes movement from distance traveled between consecutive samples.
  ({bool movingByDistance, bool runningByDistance}) _computeDerivedMovementState({
    required Position position,
    required DateTime now,
  }) {
    if (!_hasReliableDistanceSample(position)) {
      return (movingByDistance: false, runningByDistance: false);
    }

    final double elapsedSeconds =
        now.difference(_lastAnimationSampleAt!).inMilliseconds / 1000;
    if (elapsedSeconds <= 0) {
      return (movingByDistance: false, runningByDistance: false);
    }

    final double movedMeters = Geolocator.distanceBetween(
      _lastAnimationPosition!.latitude,
      _lastAnimationPosition!.longitude,
      position.latitude,
      position.longitude,
    );
    final double derivedSpeed = movedMeters / elapsedSeconds;

    final bool movingByDistance = movedMeters >= movementDistanceThresholdMeters &&
        derivedSpeed >= AnimationRule.walkDerived.speedThresholdMps;
    final bool runningByDistance = movedMeters >= movementDistanceThresholdMeters &&
        derivedSpeed >= AnimationRule.runDerived.speedThresholdMps;

    return (
      movingByDistance: movingByDistance,
      runningByDistance: runningByDistance,
    );
  }

  /// Checks if the previous sample is accurate enough for derived-speed math.
  bool _hasReliableDistanceSample(Position position) {
    return position.accuracy <= maxReliableAccuracyMeters &&
        _lastAnimationPosition != null &&
        _lastAnimationSampleAt != null;
  }

  /// Stores current sample for the next derived-speed calculation.
  void _updateSamplingState({
    required Position position,
    required DateTime now,
  }) {
    _lastAnimationPosition = position;
    _lastAnimationSampleAt = now;
  }

  /// Persists the last seen movement animation and timestamp.
  void _updateLastDetectedMovement({
    required DateTime now,
    required bool isRunningNow,
  }) {
    _lastMovingDetectedAt = now;
    _lastMovementAnimationName = isRunningNow
        ? AnimationRule.runGps.animationName
        : AnimationRule.walkGps.animationName;
  }

  /// Returns true while still inside the configured stop-grace window.
  bool _isWithinMovementStopGrace({required DateTime now}) {
    return _lastMovingDetectedAt != null &&
        now.difference(_lastMovingDetectedAt!) < movementStopGrace;
  }
}
