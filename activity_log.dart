import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class ActivityLogPage extends StatefulWidget {
  final int childId;

  ActivityLogPage({required this.childId});

  @override
  _ActivityLogPageState createState() => _ActivityLogPageState();
}

class _ActivityLogPageState extends State<ActivityLogPage> {
  Map<String, dynamic>? fitbitData;
  String errorMessage = '';
  Timer? timer;

  @override
  void initState() {
    super.initState();
    fetchFitbitData(); // Fetch data on page load
    timer = Timer.periodic(Duration(minutes: 5),
        (_) => fetchFitbitData()); // Refresh data every 5 minutes
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  // Fetch Fitbit Data
  Future<void> fetchFitbitData() async {
    final String apiUrl =
        'https://a20b-37-228-210-166.ngrok-free.app/fitbit_data/${widget.childId}';
    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        setState(() {
          fitbitData = jsonDecode(response.body)['data'];
          errorMessage = '';
        });
      } else {
        setState(() {
          errorMessage = 'Failed to load Fitbit data.';
        });
      }
    } catch (e) {
      print('Error fetching Fitbit data: $e');
      setState(() {
        errorMessage = 'An error occurred. Please try again later.';
      });
    }
  }

  // Traffic Light Color for Sleep Quality
  Color getSleepQualityTrafficLight(Map<String, dynamic>? sleepSummary) {
    if (sleepSummary == null) return Colors.grey; // No data

    int totalMinutesAsleep = sleepSummary['totalMinutesAsleep'] ?? 0;
    int efficiency = sleepSummary['efficiency'] ?? 0;

    double totalHoursAsleep = totalMinutesAsleep / 60.0;

    if ((totalHoursAsleep >= 7 && efficiency >= 85) || totalHoursAsleep >= 8) {
      return Colors.green; // Good sleep
    } else if ((totalHoursAsleep >= 6 && efficiency >= 70) ||
        (totalHoursAsleep >= 7 && efficiency < 70)) {
      return Colors.yellow; // Moderate sleep
    } else {
      return Colors.red; // Poor sleep
    }
  }

  // Widget for displaying sleep data
  Widget buildSleepData() {
    // Extract sleep data from the JSON response
    final sleepSummary = fitbitData?['sleep']?['summary'];
    final totalMinutesAsleep = sleepSummary?['totalMinutesAsleep'] ?? 0;
    final efficiency = fitbitData?['sleep']?['sleep']?[0]?['efficiency'] ?? 0;

    // Calculate sleep quality
    String sleepQuality = 'Unknown';
    Color trafficLightColor = Colors.grey;

    if (totalMinutesAsleep >= 420 && efficiency >= 85) {
      sleepQuality = 'Good';
      trafficLightColor = Colors.green;
    } else if (totalMinutesAsleep >= 300 && efficiency >= 70) {
      sleepQuality = 'Average';
      trafficLightColor = Colors.yellow;
    } else {
      sleepQuality = 'Poor';
      trafficLightColor = Colors.red;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Sleep Quality: $sleepQuality',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(width: 10),
            Icon(Icons.circle, color: trafficLightColor, size: 16),
          ],
        ),
        SizedBox(height: 10),
        Text(
          'Total Sleep: ${(totalMinutesAsleep / 60).toStringAsFixed(1)} hours',
          style: TextStyle(fontSize: 16),
        ),
        Text(
          'Efficiency: $efficiency%',
          style: TextStyle(fontSize: 16),
        ),
        Text(
          'Deep Sleep: ${sleepSummary?['stages']?['deep'] ?? 'N/A'} min',
          style: TextStyle(fontSize: 16),
        ),
        Text(
          'Light Sleep: ${sleepSummary?['stages']?['light'] ?? 'N/A'} min',
          style: TextStyle(fontSize: 16),
        ),
        Text(
          'REM Sleep: ${sleepSummary?['stages']?['rem'] ?? 'N/A'} min',
          style: TextStyle(fontSize: 16),
        ),
      ],
    );
  }

  // Widget for displaying heart rate data
  Widget buildHeartRateData() {
    final heartRateData =
        fitbitData?['heart_rate']?['activities-heart']?[0]?['value'];
    final restingHeartRate = heartRateData?['restingHeartRate'] ?? 'N/A';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Resting Heart Rate: $restingHeartRate bpm',
          style: TextStyle(fontSize: 16),
        ),
        SizedBox(height: 10),
        Text(
          'Heart Rate Zones:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        for (var zone in heartRateData?['heartRateZones'] ?? [])
          Text(
            '${zone['name']}: ${zone['minutes']} min (${zone['caloriesOut'].toStringAsFixed(1)} cal)',
            style: TextStyle(fontSize: 14),
          ),
      ],
    );
  }

  // Widget for displaying activity data
  Widget buildActivityData() {
    final activityData =
        fitbitData?['activity'] ?? {}; // Currently null in response
    final steps = activityData['steps'] ?? 'N/A';
    final caloriesOut = activityData['caloriesOut'] ?? 'N/A';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Steps: $steps', style: TextStyle(fontSize: 16)),
        Text('Calories Burned: $caloriesOut', style: TextStyle(fontSize: 16)),
      ],
    );
  }

  // Build method
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Activity Log'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: errorMessage.isNotEmpty
            ? Text(
                errorMessage,
                style: TextStyle(color: Colors.red, fontSize: 18),
              )
            : fitbitData != null
                ? SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        buildSleepData(),
                        SizedBox(height: 20),
                        buildActivityData(),
                        SizedBox(height: 20),
                        buildHeartRateData(),
                      ],
                    ),
                  )
                : Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
