import 'package:flutter/material.dart';
import 'package:flutter_application_1/onboarding_splash.dart';
import 'dart:async';
import 'login_page.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(Duration(seconds: 3), () {
      Navigator.pushReplacementNamed(context, '/onboarding');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.lightBlue[50],
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder(
              tween: Tween<double>(begin: 0.8, end: 1.2),
              duration: Duration(seconds: 2),
              curve: Curves.easeInOut,
              builder: (context, double scale, child) {
                return Transform.scale(
                  scale: scale,
                  child: Text(
                    "CalmLink",
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[900],
                      shadows: [
                        Shadow(
                          blurRadius: 12,
                          color: Colors.blue.shade200,
                          offset: Offset(0, 0),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            SizedBox(height: 20),
            Text(
              "Helping manage your child's stress\nto support calmer days 💙",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                color: Colors.blueGrey[700],
              ),
            ),
            SizedBox(height: 40),
            CircularProgressIndicator(color: Colors.blue[700]),
          ],
        ),
      ),
    );
  }
}
