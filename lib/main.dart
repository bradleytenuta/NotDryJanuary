import 'package:flutter/material.dart';
import 'flash/flash_screen.dart';

void main() {
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
