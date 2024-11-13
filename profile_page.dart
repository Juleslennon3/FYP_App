import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart'; // Add this for launching URLs
import 'add_child_dialog.dart'; // Import the dialog for adding children
import 'package:flutter_web_auth/flutter_web_auth.dart';

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

  @override
  void initState() {
    super.initState();
    fetchUserInfo(); // Fetch user info when profile page loads
  }

  Future<void> fetchUserInfo() async {
    final String apiUrl =
        'https://2927-37-228-233-126.ngrok-free.app/user/email/${widget.userEmail}';
    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        setState(() {
          userInfo = jsonDecode(response.body);
          isLoading = false;
        });
        fetchChildren(); // Fetch children after userInfo is loaded
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

  Future<void> fetchChildren() async {
    if (userInfo == null) return; // Make sure userInfo is loaded first

    final String apiUrl =
        'https://2927-37-228-233-126.ngrok-free.app/view_children/${userInfo!['id']}';
    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        setState(() {
          children = jsonDecode(response.body);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load children')),
        );
      }
    } catch (e) {
      print('Error fetching children: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred. Please try again.')),
      );
    }
  }

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
                    ],
                  ),
                )
              : Center(child: Text('No user info available')),
    );
  }
}
