import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'add_child_dialog.dart'; // Import the dialog for adding children
import 'package:flutter_web_auth/flutter_web_auth.dart'; // Import for web authentication

class ProfilePage extends StatefulWidget {
  final String userEmail; // Pass the email if needed for fetching user info

  ProfilePage({required this.userEmail});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? userInfo;
  List<dynamic> children = []; // List to store children data
  bool isLoading = true;
  Map<String, dynamic> fitbitData = {}; // Store fetched Fitbit data

  @override
  void initState() {
    super.initState();
    fetchUserInfo(); // Fetch user info when profile page loads
  }

  // Fetch User Info
  Future<void> fetchUserInfo() async {
    final String apiUrl =
        'https://2927-37-228-233-126.ngrok-free.app/user/email/${widget.userEmail}';
    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        setState(() {
          userInfo = jsonDecode(response.body);
          print("User Info fetched successfully: $userInfo"); // Debugging log
          isLoading = false;
        });
        fetchChildren(); // Fetch children after userInfo is loaded
        fetchFitbitData(); // Fetch Fitbit data after user info is fetched
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load user info')),
        );
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching user info: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred. Please try again.')),
      );
      setState(() {
        isLoading = false;
      });
    }
  }

  // Fetch Children
  Future<void> fetchChildren() async {
    if (userInfo == null) return; // Make sure userInfo is loaded first

    final String apiUrl =
        'https://2927-37-228-233-126.ngrok-free.app/view_children/${userInfo!['id']}';
    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        setState(() {
          children = jsonDecode(response.body);
          print("Children Data: $children"); // Debugging log
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load children')),
        );
      }
    } catch (e) {
      print('Error fetching children data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('An error occurred while fetching children data.')),
      );
    }
  }

  // Fetch Fitbit Data
  Future<void> fetchFitbitData() async {
    if (userInfo == null) return;

    final String apiUrl =
        'https://2927-37-228-233-126.ngrok-free.app/fitbit_data/${userInfo!['id']}';
    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        setState(() {
          fitbitData = jsonDecode(response.body);
          print("Fitbit Data: $fitbitData"); // Debugging log
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load Fitbit data')),
        );
      }
    } catch (e) {
      print('Error fetching Fitbit data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('An error occurred while fetching Fitbit data.')),
      );
    }
  }

  // Function to refresh Fitbit token
  Future<void> refreshFitbitToken(int childId) async {
    final String apiUrl =
        'https://2927-37-228-233-126.ngrok-free.app/refresh_fitbit_token/$childId';

    try {
      final response = await http.post(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        print('Fitbit token refreshed successfully!');
        fetchFitbitData(); // Now, try to fetch Fitbit data again
      } else {
        print('Failed to refresh Fitbit token: ${response.body}');
      }
    } catch (e) {
      print('Error refreshing Fitbit token: $e');
    }
  }

  // Add a child
  Future<void> _addChild() async {
    bool result = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AddChildDialog(
            userId: userInfo!['id']); // Pass user ID to dialog
      },
    );

    if (result == true) {
      // If child was added successfully, reload the children list
      fetchChildren();
    }
  }

  // Function to initiate Fitbit authorization for a child
  Future<void> _linkFitbit(int childId) async {
    final authUrl = 'https://www.fitbit.com/oauth2/authorize?response_type=code'
        '&client_id=23PVVG'
        '&redirect_uri=https://2927-37-228-233-126.ngrok-free.app/fitbit_callback'
        '&scope=activity%20profile%20heartrate%20sleep'
        '&state=$childId';

    try {
      final result = await FlutterWebAuth.authenticate(
        url: authUrl,
        callbackUrlScheme: "https",
      );
      // The result will contain the callback URL with the authorization code
      // Extract the code and complete the OAuth flow as needed
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not complete Fitbit authorization')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Profile'),
        backgroundColor: Colors.blue,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : userInfo != null
              ? Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Name: ${userInfo!['name']}',
                          style: TextStyle(fontSize: 20)),
                      SizedBox(height: 10),
                      Text('Email: ${userInfo!['email']}',
                          style: TextStyle(fontSize: 20)),
                      SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _addChild,
                        child: Text("Add Child"),
                      ),
                      SizedBox(height: 20),
                      Text('Children:',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      children.isEmpty
                          ? Text('No children added.')
                          : Expanded(
                              child: ListView.builder(
                                itemCount: children.length,
                                itemBuilder: (context, index) {
                                  final child = children[index];
                                  return ListTile(
                                    title: Text(child['name']),
                                    subtitle: Text('Age: ${child['age']}'),
                                    trailing: ElevatedButton(
                                      onPressed: () => _linkFitbit(child['id']),
                                      child: Text('Link Fitbit'),
                                    ),
                                  );
                                },
                              ),
                            ),
                      SizedBox(height: 20),
                      Text('Fitbit Activity Data:',
                          style: TextStyle(fontSize: 18)),
                      fitbitData.isNotEmpty
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    'Heart Rate: ${fitbitData['activities-heart'] != null && fitbitData['activities-heart'].isNotEmpty ? fitbitData['activities-heart'][0]['value']['restingHeartRate'] : 'N/A'} bpm'),
                                Text(
                                    'Steps: ${fitbitData['activities'] != null && fitbitData['activities'].isNotEmpty ? fitbitData['activities'][0]['steps'] : 'N/A'} steps'),
                                Text(
                                    'Calories: ${fitbitData['activities'] != null && fitbitData['activities'].isNotEmpty ? fitbitData['activities'][0]['calories'] : 'N/A'} kcal'),
                                Text(
                                    'Distance: ${fitbitData['activities'] != null && fitbitData['activities'].isNotEmpty ? fitbitData['activities'][0]['distance'] : 'N/A'} km'),
                              ],
                            )
                          : Text('No Fitbit data available.'),
                    ],
                  ),
                )
              : Center(child: Text('No user info available')),
    );
  }
}
