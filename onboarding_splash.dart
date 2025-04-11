import 'package:flutter/material.dart';

class OnboardingScreen extends StatefulWidget {
  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  final List<_OnboardingPage> pages = [
    _OnboardingPage(
      title: "Overview",
      description:
          "Your Home page gives a stress summary using heart rate, sleep and meal timing.",
      icon: Icons.home,
    ),
    _OnboardingPage(
      title: "Calendar",
      description:
          "Log school events, meals, PE, and more. These help interpret stress spikes.",
      icon: Icons.calendar_today,
    ),
    _OnboardingPage(
      title: "Stress Log",
      description:
          "This shows when your child was overstimulated and what helped.",
      icon: Icons.local_fire_department,
    ),
    _OnboardingPage(
      title: "Interventions",
      description:
          "View and discover what works best to calm your child based on past success.",
      icon: Icons.psychology_alt,
    ),
  ];

  void _nextPage() {
    if (_currentIndex < pages.length - 1) {
      _pageController.nextPage(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  void _skip() {
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: pages.length,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (context, index) {
              final page = pages[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(page.icon, size: 80, color: Colors.blue),
                    SizedBox(height: 30),
                    Text(
                      page.title,
                      style:
                          TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 20),
                    Text(
                      page.description,
                      style: TextStyle(fontSize: 18),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
          ),
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    pages.length,
                    (index) => Container(
                      margin: EdgeInsets.symmetric(horizontal: 6),
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _currentIndex == index
                            ? Colors.blue
                            : Colors.grey[300],
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _nextPage,
                  child: Text(
                      _currentIndex == pages.length - 1 ? "Finish" : "Next"),
                ),
                TextButton(
                  onPressed: _skip,
                  child: Text("Skip"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage {
  final String title;
  final String description;
  final IconData icon;

  _OnboardingPage({
    required this.title,
    required this.description,
    required this.icon,
  });
}
