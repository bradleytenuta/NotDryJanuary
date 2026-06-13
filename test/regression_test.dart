import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mbx;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'package:notdryjanuary/features/feature_service.dart';
import 'package:notdryjanuary/features/pub_cache.dart';
import 'package:notdryjanuary/map/mapbox.dart';
import 'package:notdryjanuary/ui/pages/map.dart';
import 'package:notdryjanuary/user_session_store.dart';

// Mock path provider
class MockPathProviderPlatform extends PathProviderPlatform {
  final Directory tempDir;
  MockPathProviderPlatform(this.tempDir);

  @override
  Future<String?> getApplicationDocumentsPath() async {
    return tempDir.path;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Mock geolocator with support for emitting stream positions and pure Dart distance calculation
class FakeGeolocatorPlatform extends GeolocatorPlatform {
  final StreamController<Position> positionStreamController =
      StreamController<Position>.broadcast();
  Position _currentPosition;

  FakeGeolocatorPlatform({required double latitude, required double longitude})
      : _currentPosition = Position(
          latitude: latitude,
          longitude: longitude,
          timestamp: DateTime.now(),
          accuracy: 1.0,
          altitude: 0.0,
          heading: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
          altitudeAccuracy: 0.0,
          headingAccuracy: 0.0,
        );

  void emitPosition(double latitude, double longitude) {
    _currentPosition = Position(
      latitude: latitude,
      longitude: longitude,
      timestamp: DateTime.now(),
      accuracy: 1.0,
      altitude: 0.0,
      heading: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
      altitudeAccuracy: 0.0,
      headingAccuracy: 0.0,
    );
    positionStreamController.add(_currentPosition);
  }

  @override
  double distanceBetween(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    const double p = 0.017453292519943295; // pi / 180
    final double a = 0.5 -
        math.cos((endLatitude - startLatitude) * p) / 2 +
        math.cos(startLatitude * p) *
            math.cos(endLatitude * p) *
            (1 - math.cos((endLongitude - startLongitude) * p)) /
            2;
    return 12742 * math.asin(math.sqrt(a)) * 1000;
  }

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async => LocationPermission.whileInUse;

  @override
  Future<LocationPermission> requestPermission() async => LocationPermission.whileInUse;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    return _currentPosition;
  }

  @override
  Stream<Position> getPositionStream({
    LocationSettings? locationSettings,
  }) {
    return positionStreamController.stream;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Fake MapboxMap for MapboxMapController constructor
class FakeMapboxMap implements mbx.MapboxMap {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// Mock MapboxMapController to prevent native calls, verify coordinates, and simulate pub visited checks
class MockMapboxMapController extends MapboxMapController {
  MockMapboxMapController() : super(FakeMapboxMap());

  double? lastLatitude;
  double? lastLongitude;
  bool moveCameraCalled = false;
  bool refreshPubsCalled = false;

  @override
  Future<void> moveCamera({
    required double latitude,
    required double longitude,
    required double tilt,
    required double zoom,
    required double bearing,
  }) async {
    lastLatitude = latitude;
    lastLongitude = longitude;
    moveCameraCalled = true;
  }

  @override
  Future<void> refreshNearbyPubsIfNeeded({
    required double latitude,
    required double longitude,
  }) async {
    refreshPubsCalled = true;

    // Simulate location visited check (usually done by private _recordVisitedPubsAtLocation)
    final List<PubFeature> candidateFeatures =
        await PubsGeoJsonCache.instance.loadNearbyFeatures(
      userLatitude: latitude,
      userLongitude: longitude,
      radiusMeters: PubsGeoJsonCache.visitedCheckRadiusMeters,
      refreshDistanceMeters: 5,
    );

    final List<String> visitedPubIds = FeatureService.findContainingFeatureIds(
      features: candidateFeatures,
      userLatitude: latitude,
      userLongitude: longitude,
    );

    if (visitedPubIds.isNotEmpty && visitedPubIds.length <= 5) {
      await UserSessionStore.instance.addVisitedPubs(visitedPubIds);
    }
  }
}

// Mock Map Widget that returns a placeholder and fires the controller callback
class MockMapWidget extends StatefulWidget {
  final ValueChanged<MapboxMapController> onControllerCreated;
  final MockMapboxMapController mockController;

  const MockMapWidget({
    super.key,
    required this.onControllerCreated,
    required this.mockController,
  });

  @override
  State<MockMapWidget> createState() => _MockMapWidgetState();
}

class _MockMapWidgetState extends State<MockMapWidget> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onControllerCreated(widget.mockController);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      key: Key('mock_map_widget'),
      width: 300,
      height: 300,
      child: Placeholder(),
    );
  }
}

// Fake WebView classes to avoid MissingPluginException with ModelViewer's WebView
class FakeWebViewPlatform extends WebViewPlatform {
  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    return FakeWebViewController(params);
  }

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) {
    return FakeWebViewWidget(params);
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) {
    return FakePlatformNavigationDelegate(params);
  }
}

class FakeWebViewController extends PlatformWebViewController {
  FakeWebViewController(super.params) : super.implementation();

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}

  @override
  Future<void> setBackgroundColor(Color color) async {}

  @override
  Future<void> loadRequest(LoadRequestParams params) async {}

  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async {}

  @override
  Future<void> addJavaScriptChannel(
    JavaScriptChannelParams javaScriptChannelParams,
  ) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeWebViewWidget extends PlatformWebViewWidget {
  FakeWebViewWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      key: Key('mock_webview_widget'),
      child: SizedBox.shrink(),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakePlatformNavigationDelegate extends PlatformNavigationDelegate {
  FakePlatformNavigationDelegate(super.params) : super.implementation();

  @override
  Future<void> setOnNavigationRequest(
    FutureOr<NavigationDecision> Function(NavigationRequest request) onNavigationRequest,
  ) async {}

  @override
  Future<void> setOnPageStarted(
    void Function(String url) onPageStarted,
  ) async {}

  @override
  Future<void> setOnPageFinished(
    void Function(String url) onPageFinished,
  ) async {}

  @override
  Future<void> setOnProgress(
    void Function(int progress) onProgress,
  ) async {}

  @override
  Future<void> setOnWebResourceError(
    void Function(WebResourceError error) onWebResourceError,
  ) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  // Initial coordinates: outside The Phoenix pub
  const double initialLat = 51.497851;
  const double initialLng = -0.142229;

  // Move-to coordinates: inside The Phoenix pub (way/263674306)
  const double secondLat = 51.498714;
  const double secondLng = -0.142047;

  late Directory tempDirectory;
  late FakeGeolocatorPlatform geolocatorPlatform;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('not_dry_january_test_');
    PathProviderPlatform.instance = MockPathProviderPlatform(tempDirectory);

    geolocatorPlatform = FakeGeolocatorPlatform(
      latitude: initialLat,
      longitude: initialLng,
    );
    GeolocatorPlatform.instance = geolocatorPlatform;

    WebViewPlatform.instance = FakeWebViewPlatform();

    // Mock compass channel to avoid hanging on native platform channel streams
    const EventChannel compassChannel = EventChannel('hemanthraj/flutter_compass');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockStreamHandler(
      compassChannel,
      MockStreamHandler.inline(
        onListen: (arguments, sink) {},
        onCancel: (arguments) {},
      ),
    );

    // Mock wakelock Pigeon channel to prevent PlatformExceptions on dispose
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
      'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
      (ByteData? message) async {
        return const StandardMessageCodec().encodeMessage(<Object?>[null]);
      },
    );

    await UserSessionStore.instance.loadOrCreate();
    await PubsGeoJsonCache.instance.warmUp();
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockStreamHandler(
      const EventChannel('hemanthraj/flutter_compass'),
      null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
      'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
      null,
    );
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  testWidgets('Regression Test: Simulates user walking, updates camera, and visits The Phoenix pub', (WidgetTester tester) async {
    final mockController = MockMapboxMapController();

    await tester.pumpWidget(
      MaterialApp(
        home: MapScreen(
          mapProviderBuilder: ({
            required ValueChanged<MapboxMapController> onControllerCreated,
            required OnPubFeatureTapped onPubFeatureTapped,
            required double initialLatitude,
            required double initialLongitude,
            required double initialZoom,
            required double initialTilt,
          }) {
            return MockMapWidget(
              onControllerCreated: onControllerCreated,
              mockController: mockController,
            );
          },
          characterViewerBuilder: (context, modelPath, animationName) {
            return Container(
              key: const Key('mock_character_viewer'),
              child: Text('Mock Character: $modelPath ($animationName)'),
            );
          },
        ),
      ),
    );

    // Wait a bit for initial async tasks (like loadOrCreate) to complete
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();

    expect(find.byKey(const Key('mock_map_widget')), findsOneWidget);
    expect(find.byKey(const Key('mock_character_viewer')), findsOneWidget);

    expect(mockController.moveCameraCalled, isTrue);
    expect(mockController.lastLatitude, closeTo(initialLat, 0.00001));
    expect(mockController.lastLongitude, closeTo(initialLng, 0.00001));

    expect(find.text('0 pubs visited'), findsOneWidget);
    late UserSessionData session;
    await tester.runAsync(() async {
      session = await UserSessionStore.instance.loadOrCreate();
    });
    expect(session.visitedPubs, isEmpty);

    mockController.moveCameraCalled = false;

    geolocatorPlatform.emitPosition(secondLat, secondLng);

    // Interleave pumping and real-time waiting until the Phoenix pub is visited
    for (int i = 0; i < 30; i++) {
      await tester.pump();
      if (UserSessionStore.instance.visitedPubsCountListenable.value > 0) {
        break;
      }
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
    }

    await tester.pump();

    expect(mockController.moveCameraCalled, isTrue);
    expect(mockController.lastLatitude, closeTo(secondLat, 0.00001));
    expect(mockController.lastLongitude, closeTo(secondLng, 0.00001));

    expect(find.text('1 pubs visited'), findsOneWidget);

    await tester.runAsync(() async {
      session = await UserSessionStore.instance.loadOrCreate();
    });
    expect(session.visitedPubs, contains('way/263674306'));

    // Close the broadcast stream controller to clean up the stream subscription
    await geolocatorPlatform.positionStreamController.close();

    // Pump a SizedBox to force disposal of the MapScreen widget tree
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
