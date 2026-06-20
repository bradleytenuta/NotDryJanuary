---
name: Write Widget Regression Tests
description: Guidelines and patterns for writing fast, robust widget and regression tests in Flutter, including EventChannel streams, Pigeon channel mocking, native widget decoupling, and fake-async real I/O interleaving.
---

# Write Widget Regression Tests

This skill provides guidelines and patterns for writing robust widget and integration-level regression tests in Flutter. It covers how to handle native dependencies, platform channels, background tasks, and asynchronous I/O cleanly.

## 1. Decoupling Native or Heavy-weight Widgets
Heavy-weight or platform-native widgets (e.g., 3D model viewers, Google Maps, Mapbox, or native web views) often execute native platform calls or start background servers (like `model_viewer_plus` starting a local `HttpServer` to serve assets). These will fail or hang indefinitely in a headless `flutter test` environment.

### Best Practice: Dependency Injection via Builders
Decouple these widgets by exposing an optional builder callback parameter in the parent screen/widget.
- In **Production**: Default to the real widget.
- In **Tests**: Pass a custom builder that returns a mock/placeholder widget.

#### Example:
In the widget:
```dart
class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    required this.mapProviderBuilder,
    this.characterViewerBuilder,
  });

  final MapboxMapProviderBuilder mapProviderBuilder;
  final Widget Function(BuildContext context, String modelPath, String animationName)? characterViewerBuilder;
  
  // ...
}
```

In the test:
```dart
    await tester.pumpWidget(
      MaterialApp(
        home: MapScreen(
          mapProviderBuilder: // mock map...
          characterViewerBuilder: (context, modelPath, animationName) {
            return Container(
              key: const Key('mock_character_viewer'),
              child: Text('Mock Character: $modelPath ($animationName)'),
            );
          },
        ),
      ),
    );
```

---

## 2. Mocking Platform EventChannels (Streams)
Listening to native event channel streams (e.g., compass sensor events, location updates) in a widget test without a mock stream handler will throw `MissingPluginException` or block the test process.

### Best Practice: Mock Stream Handler
Register a mock stream handler using the default binary messenger in `setUp`, and clear it in `tearDown`.

#### Example:
```dart
  setUp(() async {
    // Mock the compass event channel stream
    const EventChannel compassChannel = EventChannel('hemanthraj/flutter_compass');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockStreamHandler(
      compassChannel,
      MockStreamHandler.inline(
        onListen: (arguments, sink) {
          // Emit events using sink.success(...) if needed, or leave empty
        },
        onCancel: (arguments) {},
      ),
    );
  });

  tearDown(() async {
    // Reset handler to clean up
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockStreamHandler(
      const EventChannel('hemanthraj/flutter_compass'),
      null,
    );
  });
```

---

## 3. Mocking Pigeon Generated Channels (Method/BasicMessageChannels)
Pigeon-generated interface methods (e.g. `wakelock_plus`) translate calls into `BasicMessageChannel`s. Unmocked calls throw a `PlatformException` (channel-error).

### Best Practice: Mock Message Handler
Register a mock message handler directly on the default binary messenger that decodes the request and returns a standard Pigeon success reply (`[null]`).

#### Example:
```dart
  setUp(() async {
    // Mock Pigeon channel for WakelockPlusApi.toggle
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
      'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
      (ByteData? message) async {
        // Pigeon success reply for void method is a list containing null encoded with StandardMessageCodec
        return const StandardMessageCodec().encodeMessage(<Object?>[null]);
      },
    );
  });

  tearDown(() async {
    // Clean up mock handler
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
      'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
      null,
    );
  });
```

---

## 4. Handling FakeAsync vs. Real File I/O Deadlocks
Flutter widget tests run in a `FakeAsync` zone where time is controlled. If a widget triggers real asynchronous operations (such as file reads/writes, SQLite database calls, or network calls):
1. The real I/O runs outside the control of the fake clock.
2. However, the microtask/callback that resumes your execution after the I/O completes is scheduled on the fake zone's queue.
3. If you poll using `tester.runAsync(() => Future.delayed(...))` directly, the fake queue is blocked, causing a deadlock (the I/O wait finishes, but the completion callback is frozen in the fake zone).

### Best Practice: Interleaved Pumping and Real-Time Waiting
Interleave `tester.pump()` (to run fake-async microtasks and progress the execution to the next yield) and `tester.runAsync(...)` (to run real-time delays and let background filesystem I/O progress).

#### Example:
```dart
    // Trigger location change which schedules async file write
    geolocatorPlatform.emitPosition(secondLat, secondLng);

    // Interleave pumping and real-time waiting until the condition is met in memory
    for (int i = 0; i < 30; i++) {
      await tester.pump(); // 1. Run fake zone microtasks to advance async steps
      if (UserSessionStore.instance.visitedPubsCountListenable.value > 0) {
        break; // 2. Check memory values to avoid concurrent file locks
      }
      // 3. Allow 100ms of real-time for background filesystem I/O to run
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
    }

    // Pump one final time to rebuild the widget tree after database writing is done
    await tester.pump();
```

> [!IMPORTANT]
> Always check **in-memory values** (like a `ValueNotifier` or cache state) during polling loops. Awaiting a file read (e.g. `loadOrCreate()`) inside the polling loop runs concurrently with the background write, causing file access lock exceptions (`OS Error: 32`) on Windows or JSON parsing format exceptions.
