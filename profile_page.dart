import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart'; // For Fitbit authentication URL
import 'dart:convert';
import 'add_child_dialog.dart'; // Import the dialog for adding children

class ProfilePage extends StatefulWidget {
  final String userEmail;

  ProfilePage({required this.userEmail});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? userInfo;
  Map<String, dynamic>? childData; // Store the child data
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchUserInfo(); // Fetch user info when profile page loads
  }

  // Fetch User Info
  Future<void> fetchUserInfo() async {
    final String apiUrl =
        'https://1a05-80-233-39-72.ngrok-free.app/user/email/${widget.userEmail}';
    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        setState(() {
          userInfo = jsonDecode(response.body);
          isLoading = false;
        });

        // Fetch the child data if user has a child
        if (userInfo != null) {
          fetchChild(userInfo!['id']);
        }
      } else {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load user info')),
        );
      }
    } catch (e) {
      print('Error fetching user info: $e');
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred. Please try again.')),
      );
    }
  }

  // Fetch Child Data
  Future<void> fetchChild(int userId) async {
    final String apiUrl =
        'https://1a05-80-233-39-72.ngrok-free.app/view_child/$userId';
    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        setState(() {
          childData = jsonDecode(response.body);
        });
      } else {
        setState(() {
          childData = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No child data available')),
        );
      }
    } catch (e) {
      print('Error fetching child data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred while fetching child data.')),
      );
    }
  }

  // First-time Fitbit Authentication
  Future<void> authenticateFitbit() async {
    if (childData == null) return;

    final String authApiUrl =
        'https://1a05-80-233-39-72.ngrok-free.app/authenticate_fitbit/${childData!['id']}';

    try {
      print("Calling authentication endpoint: $authApiUrl");

      final response = await http.post(Uri.parse(authApiUrl));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final String authUrl = responseData['auth_url'];
        print("Received auth URL: $authUrl");

        final Uri authUri = Uri.parse(authUrl);

        // Force opening in an external browser
        await launchUrl(
          authUri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        print(
            "Failed to initiate authentication. Status code: ${response.statusCode}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initiate Fitbit authentication')),
        );
      }
    } catch (e) {
      print("Error during authentication: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to launch Fitbit authentication')),
      );
    }
  }

  // Refresh Fitbit Token
  Future<void> refreshFitbitToken() async {
    if (childData == null) return;
    final String apiUrl =
        'https://1a05-80-233-39-72.ngrok-free.app/refresh_fitbit_token/${childData!['id']}';
    try {
      final response = await http.post(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Token refreshed successfully')),
        );
      } else if (response.statusCode == 403) {
        // Trigger re-authentication if refresh token is invalid
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Refresh token invalid. Re-authentication required.')),
        );
        reAuthenticateFitbit();
      } else {
        final error = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to refresh token: ${error['message']}')),
        );
      }
    } catch (e) {
      print('Error refreshing token: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error refreshing token')),
      );
    }
  }

  // Trigger Fitbit Re-authentication
  Future<void> reAuthenticateFitbit() async {
    if (childData == null) return;

    final String reAuthApiUrl =
        'https://1a05-80-233-39-72.ngrok-free.app/re_authorize_fitbit/${childData!['id']}';

    try {
      print("Calling re-authentication endpoint: $reAuthApiUrl");

      final response = await http.post(Uri.parse(reAuthApiUrl));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final String authUrl = responseData['auth_url'];
        print("Received auth URL: $authUrl");

        final Uri authUri = Uri.parse(authUrl);

        // Force opening in an external browser
        await launchUrl(
          authUri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        print(
            "Failed to initiate re-authentication. Status code: ${response.statusCode}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initiate re-authentication')),
        );
      }
    } catch (e) {
      print("Error during re-authentication: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to launch Fitbit re-authentication')),
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
                      childData == null
                          ? ElevatedButton(
                              onPressed: _addChild,
                              child: Text("Add Child"),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Child Name: ${childData!['name']}'),
                                Text('Child Age: ${childData!['age']}'),
                                SizedBox(height: 20),
                                if (childData!['fitbit_access_token'] == null)
                                  ElevatedButton(
                                    onPressed: authenticateFitbit,
                                    child: Text("Authenticate Fitbit"),
                                  ),
                                if (childData!['fitbit_access_token'] != null)
                                  ElevatedButton(
                                    onPressed: reAuthenticateFitbit,
                                    child: Text("Re-authenticate Fitbit"),
                                  ),
                                ElevatedButton(
                                  onPressed: refreshFitbitToken,
                                  child: Text("Refresh Token"),
                                ),
                              ],
                            ),
                    ],
                  ),
                )
              : Center(child: Text('No user info available')),
    );
  }

  // Add a child (optional)
  Future<void> _addChild() async {
    bool result = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AddChildDialog(userId: userInfo!['id']);
      },
    );

    if (result == true) {
      fetchChild(userInfo!['id']);
    }
  }
}
