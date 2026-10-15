import 'package:flutter/material.dart';
import 'login_page.dart';

void main() => runApp(const RutixApp());

class RutixApp extends StatelessWidget {
  const RutixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rutix',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF1F4E79),
        useMaterial3: true,
      ),
      home: const LoginPage(),
    );
  }
}
