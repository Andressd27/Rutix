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
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF16C08A),
          primary: const Color(0xFF16C08A),
          onPrimary: Colors.white,
        ),
        useMaterial3: true,
      ),
      home: const LoginPage(),
    );
  }
}
