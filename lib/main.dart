import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'ui/pages/loading.dart';
import 'features/pub_cache.dart';
import 'user_session_store.dart';

const String _mapboxAccessToken = String.fromEnvironment('MAPS_API_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Add Mapbox access token from environment variable.
  if (_mapboxAccessToken.isEmpty) {
    throw StateError(
      'MAPS_API_KEY is missing. Start with --dart-define=MAPS_API_KEY=<your_token>.',
    );
  }
  MapboxOptions.setAccessToken(_mapboxAccessToken);

  // Load or create user data.
  await UserSessionStore.instance.loadOrCreate();
  // Load json pub data into memory.
  await PubsGeoJsonCache.instance.warmUp();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  runApp(const NotDryJanuaryApp());
}

class NotDryJanuaryApp extends StatelessWidget {
  const NotDryJanuaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const Loading(),
    );
  }
}
