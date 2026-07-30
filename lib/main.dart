import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MakkFinsolApp());
}

class MakkFinsolApp extends StatelessWidget {
  const MakkFinsolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Makk Finsol Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Inter',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF01696F),
        ),
        useMaterial3: true,
      ),
      // LoginScreen handles both session check and login form
      home: const LoginScreen(),
    );
  }
}