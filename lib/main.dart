import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'loading/loading_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  runApp(const NotDryJanuaryApp());
}

class NotDryJanuaryApp extends StatelessWidget {
  const NotDryJanuaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const AppStartupScreen(),
    );
  }
}
