import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'home_page.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool isLoading = false;

  Future<void> sendTokenToServer(String token, String parentId) async {
    final String apiUrl =
        'https://8226-37-228-234-44.ngrok-free.app/register_token';

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"parent_id": parentId, "token": token}),
      );

      if (response.statusCode == 200) {
        print("✅ Token sent successfully to backend!");
      } else {
        print("❌ Failed to send token: ${response.body}");
      }
    } catch (e) {
      print("❌ Error sending token: $e");
    }
  }

  Future<void> login() async {
    final String apiUrl = 'https://8226-37-228-234-44.ngrok-free.app/login';
    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _emailController.text.trim(),
          'password': _passwordController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final userId = data['user_id'];
        var parentId = data['parent_id']; // Allow null

        // ✅ If parent_id is null, use user_id instead
        if (parentId == null) {
          print("⚠️ Warning: parent_id is missing. Using user_id instead.");
          parentId = userId.toString();
        }

        // ✅ Store Parent ID in SharedPreferences
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString("parent_id", parentId);

        if (rememberMe) {
          await prefs.setString("saved_email", _emailController.text.trim());
          await prefs.setString(
              "saved_password", _passwordController.text.trim());
        } else {
          await prefs.remove("saved_email");
          await prefs.remove("saved_password");
        }

        // ✅ Fetch Child Data
        final String childApiUrl =
            'https://8226-37-228-234-44.ngrok-free.app/view_child/$userId';
        final childResponse = await http.get(Uri.parse(childApiUrl));

        if (childResponse.statusCode == 200) {
          final childData = jsonDecode(childResponse.body);
          final childId = childData['id'];

          // ✅ Fetch & Send FCM Token to Backend
          FirebaseMessaging.instance.getToken().then((token) {
            if (token != null) {
              print("📲 Device FCM Token: $token");
              sendTokenToServer(token, parentId);
            } else {
              print("❌ Failed to retrieve FCM token!");
            }
          }).catchError((error) {
            print("❌ Error retrieving FCM token: $error");
          });

          // ✅ Navigate to Home Page
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => HomePage(
                userEmail: _emailController.text.trim(),
                userId: userId,
                childId: childId,
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to fetch child data.')),
          );
        }
      } else {
        final errorMessage = jsonDecode(response.body)['message'] ??
            'Login failed. Please check your credentials.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred. Please try again.')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  bool rememberMe = false;

  @override
  void initState() {
    super.initState();
    loadSavedCredentials();
  }

  Future<void> loadSavedCredentials() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString("saved_email");
    final savedPassword = prefs.getString("saved_password");

    if (savedEmail != null && savedPassword != null) {
      setState(() {
        _emailController.text = savedEmail;
        _passwordController.text = savedPassword;
        rememberMe = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade300, Colors.blue.shade900],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              child: Card(
                elevation: 8.0,
                margin: EdgeInsets.symmetric(horizontal: 20.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15.0),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Login',
                        style: TextStyle(
                          fontSize: 24.0,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                      SizedBox(height: 20),
                      TextField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      SizedBox(height: 10),
                      TextField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                        obscureText: true,
                      ),
                      CheckboxListTile(
                        title: Text("Remember Me"),
                        value: rememberMe,
                        onChanged: (value) {
                          setState(() {
                            rememberMe = value!;
                          });
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                      SizedBox(height: 20),
                      isLoading
                          ? CircularProgressIndicator()
                          : ElevatedButton(
                              onPressed: login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade900,
                                padding: EdgeInsets.symmetric(
                                    horizontal: 50.0, vertical: 12.0),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                              ),
                              child: Text(
                                'Login',
                                style: TextStyle(fontSize: 18),
                              ),
                            ),
                      SizedBox(height: 10),
                      TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/register');
                        },
                        child: Text('Register'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
