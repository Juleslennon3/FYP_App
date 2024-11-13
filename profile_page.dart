import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'add_child_dialog.dart'; // Import the dialog for adding children

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
    fetchUserInfo();
    fetchChildren(); // Fetch children when profile page loads
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
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load user info')),
        );
      }
    } catch (e) {
      print('Error fetching user info: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred. Please try again.')),
      );
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
