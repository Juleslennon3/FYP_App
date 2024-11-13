import 'package:flutter/material.dart';
import 'login_page.dart';
import 'register_page.dart';
// ignore: unused_import
import 'home_page.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      initialRoute: '/',
      routes: {
        '/': (context) => LoginPage(),
        '/register': (context) => RegisterPage(),
        // Remove the hardcoded email from here
      },
    );
  }
}
