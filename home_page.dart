import 'dart:convert';
import 'package:flutter/material.dart';
import 'profile_page.dart';
import 'calendar_page.dart';
import 'activity_log.dart';
import 'heart_rate_graph_page.dart'; // Import the Heart Rate Graph Page
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatefulWidget {
  final String userEmail;
  final int userId;
  final int childId;

  HomePage({
    required this.userEmail,
    required this.userId,
    required this.childId,
  });

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  Map<String, dynamic>? fitbitData;
  String errorMessage = '';
  bool isLoading = true;
  String currentHeartRate = 'N/A'; // To store the most recent heart rate

  @override
  void initState() {
    super.initState();
    fetchFitbitData();
    _sendFcmToken();
  }

  // Fetch Fitbit Data
  Future<void> fetchFitbitData() async {
    final String apiUrl =
        'https://3efd-80-233-12-225.ngrok-free.app/fitbit_data/${widget.childId}';

    setState(() {
      isLoading = true; // Show loading spinner
      errorMessage = ''; // Clear previous errors
    });

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        setState(() {
          final decodedData = jsonDecode(response.body);
          if (decodedData.containsKey('data')) {
            setState(() {
              fitbitData = decodedData['data'] ?? {};
              extractCurrentHeartRate();
              isLoading = false;
            });
          } else {
            setState(() {
              errorMessage = 'No valid data received.';
              isLoading = false;
            });
          }

          extractCurrentHeartRate(); // Extract the latest heart rate
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Failed to load Fitbit data.';
          isLoading = false;
        });
        print('Error: ${response.statusCode}, ${response.body}');
      }
    } catch (e) {
      setState(() {
        errorMessage = 'An error occurred while fetching Fitbit data.';
        isLoading = false;
      });
      print('Exception while fetching data: $e');
    }
  }

  // Extract the latest heart rate from intraday data
  void extractCurrentHeartRate() {
    try {
      if (fitbitData == null ||
          fitbitData?['heart_rate_intraday'] == null ||
          fitbitData?['heart_rate_intraday']?['activities-heart-intraday'] ==
              null ||
          fitbitData?['heart_rate_intraday']?['activities-heart-intraday']
                  ?['dataset'] ==
              null) {
        print("❌ No heart rate intraday data available.");
        setState(() {
          currentHeartRate = 'No data available';
        });
        return;
      }

      final intradayData = fitbitData!['heart_rate_intraday']
              ?['activities-heart-intraday']?['dataset'] ??
          [];

      if (intradayData.isNotEmpty) {
        final latestEntry = intradayData.last;
        setState(() {
          currentHeartRate = latestEntry['value']?.toString() ?? 'N/A';
        });
        print('🔥 Latest Heart Rate: $currentHeartRate BPM');
      } else {
        setState(() {
          currentHeartRate = 'No recent heart rate data';
        });
      }
    } catch (e) {
      setState(() {
        currentHeartRate = 'Error retrieving heart rate';
      });
      print('❌ Error extracting heart rate: $e');
    }
  }

  Future<void> _sendFcmToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? parentId = prefs.getString("parent_id");

    if (parentId == null) {
      print("❌ No parent_id found, skipping FCM token registration.");
      return;
    }

    FirebaseMessaging.instance.getToken().then((token) async {
      if (token != null) {
        print("📲 New FCM Token: $token");

        // 🔍 Retrieve the old stored token (if any)
        String? oldToken = prefs.getString("fcm_token");

        // ✅ Only send if the token has changed
        if (oldToken == token) {
          print("🔄 Token is already up to date, no need to send.");
          return;
        }

        // 🗑️ Store the new token and send it to the backend
        await prefs.setString("fcm_token", token);

        _registerTokenToBackend(token, parentId);
      } else {
        print("❌ Failed to retrieve FCM token!");
      }
    }).catchError((error) {
      print("❌ Error retrieving FCM token: $error");
    });
  }

  Future<void> _registerTokenToBackend(String token, String parentId) async {
    final String apiUrl =
        'https://3efd-80-233-12-225.ngrok-free.app/register_token';

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"parent_id": parentId, "token": token}),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        print(
            "✅ Token sent successfully to backend: ${responseData['message']}");
      } else {
        print(
            "❌ Failed to send token: ${responseData['error'] ?? response.body}");
      }
    } catch (e) {
      print("❌ Error sending token: $e");
    }
  }

  Future<Map<String, dynamic>> fetchGraphData() async {
    final String apiUrl =
        'https://3efd-80-233-12-225.ngrok-free.app/generate_graph_data/${widget.childId}';

    try {
      final response = await http.get(Uri.parse(apiUrl));

      // ✅ If successful, return real API data
      if (response.statusCode == 200) {
        print("📡 API Response: ${response.body}"); // 🔍 Debugging
        return jsonDecode(response.body);
      }

      // 🚨 If rate-limited (429), use the hardcoded backup
      if (response.statusCode == 429) {
        print("⚠️ TOO MANY REQUESTS (429) - Using backup data instead.");
        return {
          "intradayData": [
            {"time": "10:00:00", "value": 70},
            {"time": "10:01:00", "value": 72},
            {"time": "10:02:00", "value": 75},
            {"time": "10:03:00", "value": 78},
          ],
          "calendarEvents": [],
        };
      }

      // ❌ If another error occurs, throw an exception
      throw Exception('Failed to fetch graph data: ${response.statusCode}');
    } catch (e) {
      print("❌ Error fetching graph data: $e");

      // ✅ Ensure it still returns a backup if the request completely fails
      return {
        "intradayData": [],
        "calendarEvents": [],
      };
    }
  }

  // Handle Bottom Navigation Bar item selection
  Future<void> _onItemTapped(int index) async {
    setState(() {
      _selectedIndex = index;
    });

    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CalendarPage(childId: widget.childId),
        ),
      );
    } else if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ActivityLogPage(childId: widget.childId),
        ),
      );
    } else if (index == 3) {
      try {
        print("📡 Fetching graph data...");
        final graphData = await fetchGraphData();

        // Debugging step: Print the received graph data
        print("✅ Graph Data Received: $graphData");

        // If graphData is empty, display an error message
        if (graphData['intradayData'] == null ||
            graphData['intradayData'].isEmpty) {
          print("⚠️ No intraday heart rate data available.");
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text("No heart rate data available for graph.")));
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => HeartRateGraphPage(
              intradayData: graphData['intradayData'] ?? [],
              calendarEvents: graphData['calendarEvents'] ?? [],
            ),
          ),
        );
      } catch (e) {
        print('❌ Error fetching graph data: $e');
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to load graph data.")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Home'),
        actions: [
          IconButton(
            icon: Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ProfilePage(userEmail: widget.userEmail),
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: fetchFitbitData, // Calls API again on pull-down
        child: isLoading
            ? Center(child: CircularProgressIndicator())
            : errorMessage.isNotEmpty
                ? Center(
                    child: Text(errorMessage,
                        style: TextStyle(color: Colors.red, fontSize: 18)))
                : _buildHomePage(),
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
          BottomNavigationBarItem(
            icon: Icon(Icons.show_chart),
            label: 'Graph',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
    );
  }

  // Build Home Page
  Widget _buildHomePage() {
    print("📡 UI is building with fitbitData: $fitbitData");

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fitbit Data Summary',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),

            // ✅ Activity Summary (Always show, even if data is missing)
            _buildDataCard(
              title: 'Activity Summary',
              icon: Icons.directions_walk,
              data: [
                'Steps: ${fitbitData?['activity']?['summary']?['steps'] ?? 'N/A'}',
                'Calories Burned: ${fitbitData?['activity']?['summary']?['caloriesOut'] ?? 'N/A'}',
              ],
            ),

            // ✅ Heart Rate Summary (Always show, even if data is missing)
            _buildDataCard(
              title: 'Heart Rate Summary',
              icon: Icons.favorite,
              data: [
                'Resting Heart Rate: ${fitbitData?['heart_rate']?['activities-heart']?[0]['value']['restingHeartRate'] ?? 'N/A'} bpm',
                'Current Heart Rate: $currentHeartRate bpm',
              ],
            ),

            // ✅ Sleep Summary (Always show, even if data is missing)
            _buildDataCard(
              title: 'Sleep Summary',
              icon: Icons.bed,
              data: [
                'Total Sleep: ${fitbitData?['sleep']?['summary']?['totalMinutesAsleep'] ?? 'N/A'} mins',
                'Sleep Efficiency: ${fitbitData?['sleep']?['sleep']?[0]?['efficiency'] ?? 'N/A'}%',
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataCard({
    required String title,
    required IconData icon,
    required List<String> data,
  }) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 10),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, size: 40, color: Colors.blue),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 10),
                  for (var item in data)
                    Text(
                      item,
                      style: TextStyle(fontSize: 16),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
