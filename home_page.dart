import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'profile_page.dart';
import 'calendar_page.dart';
import 'activity_log.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'sleep_graph.dart';
import 'heart_rate_graph.dart';
import 'meal_graph.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'overall_score_graph.dart';
import 'stress_log_page.dart';

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
  double sleep = 0.0;
  int heartRate = 70; // Default heart rate
  int timeSinceLastMeal = 0;
  int riskLevel = 0;
  double sleepScore = 0.0; // Store sleep score
  double mealScore = 0.0; // Store meal score
  double heartStressScore = 0.0; // Store heart stress score
  double overallScore = 0.0; // Store overall score
  int sleepEfficiency = 0;
  double totalSleep = 0.0;
  double deepSleep = 0.0;
  int restingHeartRate = 0;
  List<double> weeklySleepData = List.filled(7, 0.0);

  @override
  void initState() {
    super.initState();
    fetchFitbitData();
    _sendFcmToken();
    fetchTimeSinceLastMeal();
  }

  // Fetch Fitbit Data
  Future<void> fetchFitbitData() async {
    final String fitbitApiUrl =
        'https://1a05-80-233-39-72.ngrok-free.app/fitbit_data/${widget.childId}';
    final String mealApiUrl =
        'https://1a05-80-233-39-72.ngrok-free.app/get_last_meal/${widget.childId}';

    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      // 🌙 Fetch Fitbit Data
      final fitbitResponse = await http.get(Uri.parse(fitbitApiUrl));
      final mealResponse = await http.get(Uri.parse(mealApiUrl));

      if (fitbitResponse.statusCode == 200) {
        final decodedData = jsonDecode(fitbitResponse.body);
        if (decodedData.containsKey('data')) {
          fitbitData = decodedData['data'] ?? {};

          // Extract main sleep data
          final sleepList = fitbitData?['sleep']?['sleep'] ?? [];
          final sleepData = sleepList.firstWhere(
                (sleep) => sleep['isMainSleep'] == true,
                orElse: () => null,
              ) ??
              {};

          totalSleep =
              (sleepData['minutesAsleep'] ?? 0) / 60.0; // Convert to hours
          deepSleep =
              (sleepData['levels']?['summary']?['deep']?['minutes'] ?? 0) /
                  60.0;
          sleepEfficiency = sleepData['efficiency'] ?? 0;

          sleepScore =
              calculateSleepScore(totalSleep, deepSleep, sleepEfficiency);

          // ❤️ Extract Heart Rate
          // Get Resting Heart Rate
          restingHeartRate = (fitbitData?['heart_rate']?['activities-heart']?[0]
                      ?['value']?['restingHeartRate'] ??
                  0)
              .toInt();

          // Get Most Recent Intraday Heart Rate
          final intradayData = fitbitData?['heart_rate_intraday']
              ?['activities-heart-intraday']?['dataset'];
          if (intradayData != null && intradayData.isNotEmpty) {
            final latestEntry = intradayData.last; // Get the most recent entry
            heartRate = latestEntry['value'] ?? 0;
            print('🔥 Latest Heart Rate: $heartRate BPM');
          } else {
            heartRate = 0; // Default if no data
          }

          // Fetch meal data
          if (mealResponse.statusCode == 200) {
            final decodedMealData = jsonDecode(mealResponse.body);
            timeSinceLastMeal = decodedMealData['time_since_last_meal'] ?? 0;
          } else {
            timeSinceLastMeal = 24;
          }

          mealScore = calculateMealScore(timeSinceLastMeal);
          heartStressScore = calculateHeartStress(heartRate);

          overallScore =
              calculateOverallScore(sleepScore, heartStressScore, mealScore);

          setState(() {
            isLoading = false;
          });

          await saveStressScore();
        }
      } else {
        setState(() {
          errorMessage = 'Failed to load Fitbit data.';
        });
      }
    } catch (e) {
      print('❌ Error fetching data: $e');
      setState(() {
        errorMessage = 'An error occurred while fetching data.';
        isLoading = false;
      });
    }
  }

  Future<void> saveStressScore() async {
    final String apiUrl =
        'https://1a05-80-233-39-72.ngrok-free.app/save_stress_score';

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "child_id": widget.childId,
          "stress_score": overallScore, // ✅ Use the calculated stress score
          "timestamp": DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        print("✅ Stress score saved successfully.");
      } else {
        print("❌ Failed to save stress score: ${response.body}");
      }
    } catch (e) {
      print("❌ Error saving stress score: $e");
    }
  }

  Future<List<double>> fetchWeeklySleepData() async {
    final String sleepHistoryApiUrl =
        'https://1a05-80-233-39-72.ngrok-free.app/get_weekly_sleep/${widget.childId}';

    try {
      final response = await http.get(Uri.parse(sleepHistoryApiUrl));

      if (response.statusCode == 200) {
        final decodedData = jsonDecode(response.body);

        if (decodedData.containsKey('data')) {
          List<double> weeklySleepData = List.filled(7, 0.0);

          for (var entry in decodedData['data']) {
            String date = entry['dateOfSleep'];
            int minutesAsleep = entry['minutesAsleep'] ?? 0;

            // Convert minutes to hours (round to 1 decimal place)
            double hoursAsleep = (minutesAsleep / 60.0);

            // Map dates to indexes (Day 0 = latest)
            int dayIndex =
                6 - DateTime.now().difference(DateTime.parse(date)).inDays;
            if (dayIndex >= 0 && dayIndex < 7) {
              weeklySleepData[dayIndex] = hoursAsleep;
            }
          }

          return weeklySleepData;
        }
      }
      return List.filled(7, 0.0); // Return empty if API fails
    } catch (e) {
      print("❌ Error fetching weekly sleep data: $e");
      return List.filled(7, 0.0); // Return empty if an error occurs
    }
  }

  int calculateRiskScore(double sleep, int heartRate, int timeSinceLastMeal) {
    int score = 0;

    // Check Sleep
    if (sleep < 4) {
      score += 2; // High risk
    } else if (sleep < 6) {
      score += 1; // Medium risk
    }

    // Check Heart Rate
    if (heartRate > 130) {
      score += 2;
    } else if (heartRate > 100) {
      score += 1;
    }

    // Check Eating
    if (timeSinceLastMeal > 6) {
      score += 2;
    } else if (timeSinceLastMeal > 4) {
      score += 1;
    }

    return score;
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

  Future<void> fetchTimeSinceLastMeal() async {
    final String apiUrl =
        'https://1a05-80-233-39-72.ngrok-free.app/get_last_meal/${widget.childId}';

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final decodedData = jsonDecode(response.body);
        setState(() {
          timeSinceLastMeal =
              decodedData['time_since_last_meal'] ?? -1; // -1 means no data
        });
      } else {
        setState(() {
          timeSinceLastMeal = -1; // No data or error
        });
      }
    } catch (e) {
      print('❌ Error fetching time since last meal: $e');
      setState(() {
        timeSinceLastMeal = -1;
      });
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
        'https://1a05-80-233-39-72.ngrok-free.app/register_token';

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
        'https://1a05-80-233-39-72.ngrok-free.app/generate_graph_data/${widget.childId}';

    try {
      final response = await http.get(Uri.parse(apiUrl));

      // ✅ If successful, return real API data
      if (response.statusCode == 200) {
        print("📡 API Response: ${response.body}"); // 🔍 Debugging
        final Map<String, dynamic> jsonData = jsonDecode(response.body);

        // Explicitly parse 'intradayData' into a List<Map<String, dynamic>>
        List<Map<String, dynamic>> intradayData =
            (jsonData['intradayData'] as List)
                .map((item) => Map<String, dynamic>.from(item))
                .toList();

        return {
          "intradayData": intradayData,
          "calendarEvents": jsonData['calendarEvents'] ?? [],
        };
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
          ]
              .map((item) => Map<String, dynamic>.from(item))
              .toList(), // ✅ Added conversion here
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
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => StressLogPage(childId: widget.childId),
        ),
      );
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
              icon: Icon(Icons.local_fire_department), label: 'Stress Log'),
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
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: 40),
          // 🔵 Main Score Circle
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => StressGraph(childId: widget.childId),
                ),
              );
            },
            child: Column(
              children: [
                SizedBox(
                  width: 200,
                  height: 100,
                  child: CustomPaint(
                    painter:
                        OverallStressDialPainter(stressScore: overallScore),
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  "${overallScore.toStringAsFixed(1)}",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: overallScore < 50
                        ? Colors.green
                        : (overallScore < 75 ? Colors.orange : Colors.red),
                  ),
                ),
                Text(
                  overallScore < 50
                      ? "Low"
                      : (overallScore < 75 ? "Medium" : "High"),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
                Text(
                  "Stress Level",
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ),

          SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              GestureDetector(
                onTap: () async {
                  showDialog(
                    context: context,
                    builder: (context) =>
                        Center(child: CircularProgressIndicator()),
                  );

                  try {
                    List<double> weeklySleepData = await fetchWeeklySleepData();
                    Navigator.pop(context); // Close loading indicator

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            SleepGraph(sleepData: weeklySleepData),
                      ),
                    );
                  } catch (e) {
                    Navigator.pop(context); // Close loading indicator
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Error fetching sleep data: $e")),
                    );
                  }
                },
                child: _buildCircularIndicator(
                  title: "Sleep",
                  value: sleepScore / 100,
                  color: getTrafficColor(sleepScore),
                  size: 100,
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          HeartRateGraph(childId: widget.childId),
                    ),
                  );
                },
                child: _buildCircularIndicator(
                  title: "Heart",
                  value: heartStressScore / 25,
                  color: getTrafficColor((heartStressScore / 25) * 100),
                  size: 100,
                ),
              ),
              GestureDetector(
                onTap: () async {
                  print("📡 Fetching meal data before opening graph...");

                  try {
                    final String mealApiUrl =
                        "https://1a05-80-233-39-72.ngrok-free.app/getMealData/${widget.childId}";
                    final response = await http.get(Uri.parse(mealApiUrl));

                    print("🔵 Response Code: ${response.statusCode}");
                    print("🟡 Raw Response Body: ${response.body}");

                    if (response.statusCode == 200) {
                      final data = jsonDecode(response.body);
                      print("✅ Meal Data Received: $data");

                      // 🚀 Navigate to Meal Graph Page

                      // ✅ Close loading indicator
                      Navigator.pop(context);

                      // ✅ Navigate to MealGraph with the correct childId
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              MealGraph(childId: widget.childId),
                        ),
                      );
                    } else {
                      throw Exception("Failed to fetch meal data");
                    }
                  } catch (e) {
                    // ❌ Close loading indicator and show error message
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Error fetching meal data: $e")),
                    );
                  }
                },
                child: _buildCircularIndicator(
                  title: "Meal",
                  value: mealScore / 100,
                  color: getTrafficColor(mealScore),
                  size: 100,
                ),
              ),
            ],
          ),

          SizedBox(height: 20),

          // 🔽 Information Cards (Scrollable)
          _buildInfoCards()
        ],
      ),
    );
  }

  Widget _buildInfoCards() {
    return Column(
      children: [
        _buildDataCard(
            title: "Sleep Analysis",
            icon: Icons.nightlight_round,
            data: [
              "Total Sleep: ${_formatHoursAndMinutes(totalSleep)}",
              "Deep Sleep: ${_formatHoursAndMinutes(deepSleep)}",
              "Efficiency: ${sleepEfficiency}%",
            ]),
        _buildDataCard(title: "Heart Rate Stress", icon: Icons.favorite, data: [
          "Current HR: ${heartRate} BPM",
          "Resting HR: ${restingHeartRate} BPM"
        ]),
        _buildDataCard(title: "Meal Timing", icon: Icons.fastfood, data: [
          "Last Meal: $timeSinceLastMeal hours ago",
          "Fullness Score: ${mealScore.toInt()}%",
        ]),
      ],
    );
  }

  String _formatHoursAndMinutes(double valueInHours) {
    int hours = valueInHours.floor();
    int minutes = ((valueInHours - hours) * 60).round();
    return "${hours}h ${minutes}m";
  }

  Widget _buildDialWithDetails({
    required String title,
    required double value,
    required double maxValue,
    required String unit,
    required Color dialColor,
    required String details,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            SizedBox(
              height: 150,
              width: 150,
              child: CustomPaint(
                painter: DialPainter(
                  value: value,
                  maxValue: maxValue,
                  dialColor: dialColor,
                ),
              ),
            ),
            SizedBox(height: 10),
            Text(
              "$value $unit",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        SizedBox(width: 20),
        Expanded(
          child: Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              details,
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeartRateDialWithDetails({
    required int restingHeartRate,
    required int intradayHeartRate,
    required String details,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Text(
              "Heart Rate",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            SizedBox(
              height: 150,
              width: 150,
              child: CustomPaint(
                painter: HeartRateDialPainter(
                  restingHeartRate: restingHeartRate,
                  intradayHeartRate: intradayHeartRate,
                  maxValue: 150,
                ),
              ),
            ),
            SizedBox(height: 10),
            Text(
              "Resting: $restingHeartRate BPM\nIntraday: $intradayHeartRate BPM",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        SizedBox(width: 20),
        Expanded(
          child: Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              details,
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }

  String _getSleepDetails(double sleep) {
    if (sleep < 4) {
      return "⛔ Insufficient sleep (less than 4 hours). This may impact mood and energy levels. Consider ensuring earlier bedtimes.";
    } else if (sleep < 6) {
      return "⚠️ Limited sleep (4-6 hours). This may cause mild fatigue. Consider improving sleep routine.";
    } else if (sleep < 8) {
      return "✅ Adequate sleep (6-8 hours). This is within a healthy range.";
    } else {
      return "🌙 Excellent sleep (8+ hours). Well-rested and recharged!";
    }
  }

  String _getHeartRateDetails(int heartRate) {
    if (heartRate == 0) {
      return "⚠️ No heart rate data available. Ensure the Fitbit is worn and connected.";
    } else if (heartRate > 130) {
      return "⛔ High heart rate detected (>130 BPM). This may indicate physical exertion or stress. Monitor closely.";
    } else if (heartRate > 100) {
      return "⚠️ Elevated heart rate (100-130 BPM). This may be due to activity or stress. Ensure sufficient rest.";
    } else if (heartRate >= 60) {
      return "✅ Normal resting heart rate (60-100 BPM). This is within a healthy range.";
    } else {
      return "⚠️ Low heart rate detected (<60 BPM). This may be normal during sleep but monitor if persistent.";
    }
  }

  Widget _buildMealDialWithDetails(int timeSinceLastMeal) {
    if (timeSinceLastMeal <= 0) {
      return Column(
        children: [
          Text(
            "Time Since Last Meal",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),
          Text(
            "No recent meal data available",
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          SizedBox(height: 20),
        ],
      );
    }

    Color dialColor = getMealDialColor(timeSinceLastMeal);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Text(
              "Time Since Last Meal",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            SizedBox(
              height: 150,
              width: 150,
              child: CustomPaint(
                painter: MealDialPainter(timeSinceLastMeal, dialColor),
              ),
            ),
            SizedBox(height: 10),
            Text(
              "$timeSinceLastMeal hours ago",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
          ],
        ),
        SizedBox(width: 20),
        Expanded(
          child: Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _getMealDetails(timeSinceLastMeal),
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }

  String _getMealDetails(int timeSinceLastMeal) {
    if (timeSinceLastMeal <= 3) {
      return "✅ Recently ate (within 3 hours). Energy levels should be stable.";
    } else if (timeSinceLastMeal <= 5) {
      return "⚠️ It's been a while since the last meal (3-5 hours). Consider a snack to maintain energy.";
    } else if (timeSinceLastMeal <= 7) {
      return "⚠️ Long time since last meal (5-7 hours). Hunger or fatigue may occur.";
    } else {
      return "⛔ Very long time since last meal (>7 hours). This may impact focus, mood, and energy. Please eat soon.";
    }
  }

  Color getMealDialColor(int timeSinceLastMeal) {
    if (timeSinceLastMeal >= 7) return Colors.red;
    if (timeSinceLastMeal >= 5) return Colors.orange;
    if (timeSinceLastMeal >= 3) return Colors.yellow;
    return Colors.green;
  }

  Widget _buildRiskLevel() {
    String message = "";
    Color riskColor = Colors.green;

    if (riskLevel >= 4) {
      message = "⚠️ High Risk - Check Sleep, Heart Rate, or Eating!";
      riskColor = Colors.red;
    } else if (riskLevel >= 2) {
      message = "⚠️ Moderate Risk - Monitor child's status.";
      riskColor = Colors.orange;
    } else {
      message = "✅ Child is doing well!";
    }

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: riskColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        message,
        style: TextStyle(
            fontSize: 18, fontWeight: FontWeight.bold, color: riskColor),
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

// ✅ Correct Circular Indicator (Place near the bottom, before closing })
  Widget _buildCircularIndicator({
    required String title,
    required double value,
    required Color color,
    required double size,
  }) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 5),
        SizedBox(
          height: size,
          width: size,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: value,
                strokeWidth: 10,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation(color),
              ),
              Center(
                child: Text(
                  "${(value * 100).toInt()}",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class MealDialPainter extends CustomPainter {
  final int timeSinceLastMeal;
  final Color dialColor;

  MealDialPainter(this.timeSinceLastMeal, this.dialColor);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = dialColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12;

    final double radius = size.width / 2;
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double startAngle = pi;
    final double sweepAngle = pi * (timeSinceLastMeal.clamp(0, 7) / 7);

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle,
        sweepAngle, false, paint);

    final Paint needlePaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    double needleAngle = pi + (pi * (timeSinceLastMeal.clamp(0, 7) / 7));
    final Offset needleStart = center;
    final Offset needleEnd = Offset(
      center.dx + radius * cos(needleAngle),
      center.dy + radius * sin(needleAngle),
    );

    canvas.drawLine(needleStart, needleEnd, needlePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// 🕰️ DialPainter for Sleep and Meals
class DialPainter extends CustomPainter {
  final double value;
  final double maxValue;
  final Color dialColor;

  DialPainter(
      {required this.value, required this.maxValue, required this.dialColor});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = dialColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12;

    final double radius = size.width / 2;
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double startAngle = pi;
    final double sweepAngle = pi * (value.clamp(0, maxValue) / maxValue);

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle,
        sweepAngle, false, paint);

    final Paint needlePaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    double needleAngle = pi + (pi * (value.clamp(0, maxValue) / maxValue));
    final Offset needleStart = center;
    final Offset needleEnd = Offset(
      center.dx + radius * cos(needleAngle),
      center.dy + radius * sin(needleAngle),
    );

    canvas.drawLine(needleStart, needleEnd, needlePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class OverallStressDialPainter extends CustomPainter {
  final double stressScore;

  OverallStressDialPainter({required this.stressScore});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint bgPaint = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 15
      ..style = PaintingStyle.stroke;

    final Paint dialPaint = Paint()
      ..shader = LinearGradient(
        colors: [Colors.blue, Colors.yellow, Colors.orange, Colors.red],
      ).createShader(Rect.fromCircle(
          center: size.center(Offset.zero), radius: size.width / 2))
      ..strokeWidth = 15
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    double startAngle = pi;
    double sweepAngle = pi * (stressScore / 100);

    // Draw Background Arc
    canvas.drawArc(
        Rect.fromLTWH(0, 0, size.width, size.height), pi, pi, false, bgPaint);

    // Draw Foreground Arc (Stress Level)
    canvas.drawArc(Rect.fromLTWH(0, 0, size.width, size.height), startAngle,
        sweepAngle, false, dialPaint);

    // Draw Needle
    final needlePaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    double needleAngle = pi + sweepAngle;
    final Offset center = Offset(size.width / 2, size.height / 2);
    final Offset needleEnd = Offset(
      center.dx + (size.width / 2) * cos(needleAngle),
      center.dy + (size.height / 2) * sin(needleAngle),
    );

    canvas.drawLine(center, needleEnd, needlePaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

// ❤️ HeartRateDialPainter for Two Arrows (Resting + Intraday Heart Rate)
class HeartRateDialPainter extends CustomPainter {
  final int restingHeartRate;
  final int intradayHeartRate;
  final int maxValue;

  HeartRateDialPainter({
    required this.restingHeartRate,
    required this.intradayHeartRate,
    required this.maxValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint backgroundPaint = Paint()
      ..color = Colors.grey[300]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12;

    final double radius = size.width / 2;
    final Offset center = Offset(size.width / 2, size.height / 2);

    // Background arc
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), pi, pi,
        false, backgroundPaint);

    // Resting Heart Rate Arrow (Green)
    _drawArrow(canvas, center, radius, restingHeartRate, Colors.green);

    // Intraday Heart Rate Arrow (Red)
    _drawArrow(canvas, center, radius, intradayHeartRate, Colors.red);
  }

  void _drawArrow(
      Canvas canvas, Offset center, double radius, int heartRate, Color color) {
    final Paint arrowPaint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    double needleAngle = pi + (pi * (heartRate.clamp(0, maxValue) / maxValue));
    final Offset needleStart = center;
    final Offset needleEnd = Offset(
      center.dx + radius * cos(needleAngle),
      center.dy + radius * sin(needleAngle),
    );

    canvas.drawLine(needleStart, needleEnd, arrowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

double calculateSleepScore(
    double totalSleep, double deepSleep, int efficiency) {
  double score = (totalSleep / 8) * 50; // Max 50 points
  score += (deepSleep / 2) * 25; // Deep sleep contributes up to 25 points
  score += (efficiency / 100) * 25; // Efficiency contributes up to 25 points
  return score.clamp(0, 100);
}

double calculateMealScore(int hoursSinceMeal) {
  return (25 - (hoursSinceMeal / 24) * 25).clamp(0, 25);
}

double calculateHeartStress(int heartRate) {
  if (heartRate < 60) return 25;
  if (heartRate < 100) return 12.5;
  return 0; // High heart rate means high stress (bad score)
}

Color getTrafficColor(double percentage) {
  if (percentage >= 75) return Colors.green;
  if (percentage >= 50) return Colors.orange;
  return Colors.red;
}

double calculateOverallScore(double sleep, double heart, double meal) {
  double originalScore = (sleep * 0.5) + (heart * 0.25) + (meal * 0.25);
  return 100 - originalScore;
}
