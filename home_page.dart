import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'profile_page.dart';
import 'calendar_page.dart';
import 'activity_log.dart'; // Import the Activity Log page

class HomePage extends StatefulWidget {
  final String userEmail;
  final int userId;

  HomePage({required this.userEmail, required this.userId});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  Map<String, dynamic> fitbitData = {}; // Store Fitbit data fetched
  String errorMessage = ''; // To store error messages

  @override
  void initState() {
    super.initState();
    print('HomePage received userId: ${widget.userId}'); // Debug log for userId
    fetchChild(); // Fetch child data when the home page loads
  }

  // Fetch Child Data
  Future<void> fetchChild() async {
    final String apiUrl =
        'https://a20b-37-228-210-166.ngrok-free.app/view_child/${widget.userId}';
    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final childData = jsonDecode(response.body);
        print('Child data fetched: $childData'); // Debug log for child data
        setState(() {
          fitbitData = childData; // Store child data for later use
          errorMessage = '';
        });
      } else {
        setState(() {
          fitbitData = {};
          errorMessage = 'No child data available.';
        });
        print(
            'Failed to fetch child data. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching child data: $e');
      setState(() {
        errorMessage = 'An error occurred fetching child data.';
      });
    }
  }

  // Navigate to Profile Page
  void _goToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfilePage(userEmail: widget.userEmail),
      ),
    );
  }

  // Handle Bottom Navigation Bar item selection
  void _onItemTapped(int index) {
    if (index == 2 && fitbitData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Child data not available. Cannot open Activity Log.'),
        ),
      );
      return;
    }
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Home'),
        actions: [
          IconButton(
            icon: Icon(Icons.person),
            onPressed: _goToProfile, // Navigate to profile page
          ),
        ],
      ),
      body: _selectedIndex == 0
          ? _buildHomePage() // Home page shows Fitbit data or error
          : _selectedIndex == 1
              ? CalendarPage(
                  childId:
                      fitbitData['id'], // Pass the child ID to CalendarPage
                )
              : ActivityLogPage(
                  childId:
                      fitbitData['id'], // Pass the child ID to Activity Log
                ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Calendar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: 'Activity Log',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        onTap: _onItemTapped,
      ),
    );
  }

  // Build Home Page (Fitbit Data or Message)
  Widget _buildHomePage() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          errorMessage.isNotEmpty
              ? Text(
                  errorMessage,
                  style: TextStyle(color: Colors.red, fontSize: 18),
                )
              : fitbitData.isNotEmpty
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (fitbitData['resting_heart_rate'] != null)
                          Text(
                            'Resting Heart Rate: ${fitbitData['resting_heart_rate']} bpm',
                            style: TextStyle(fontSize: 16),
                          ),
                        if (fitbitData['hrv'] != null)
                          Text(
                            'HRV: ${fitbitData['hrv']} ms',
                            style: TextStyle(fontSize: 16),
                          ),
                      ],
                    )
                  : Text(
                      'No Fitbit data available.',
                      style: TextStyle(fontSize: 18),
                    ),
        ],
      ),
    );
  }
}
