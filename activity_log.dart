import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ActivityLogPage extends StatefulWidget {
  final int childId;

  ActivityLogPage({required this.childId});

  @override
  _ActivityLogPageState createState() => _ActivityLogPageState();
}

class _ActivityLogPageState extends State<ActivityLogPage> {
  Map<String, dynamic>? fitbitData;
  String errorMessage = '';
  List<Map<String, dynamic>> activityMatches = [];
  String sleepQuality = 'Unknown';
  Color sleepQualityColor = Colors.grey;
  String sleepSuggestion = '';
  String currentDate = DateTime.now().toLocal().toString().split(' ')[0];
  bool isLoading = true;
  List<Map<String, dynamic>> calendarEvents = []; // Store all calendar events
  String? foodWarning;
  String? lastMealTime;

  @override
  void initState() {
    super.initState();
    fetchFitbitData();
    checkLastFoodEvent();
  }

  // Fetch Fitbit Data
  Future<void> fetchFitbitData() async {
    final String apiUrl =
        'https://3efd-80-233-12-225.ngrok-free.app/fitbit_data/${widget.childId}';
    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        calendarEvents = await fetchCalendarEntries(widget.childId);

        setState(() {
          fitbitData = jsonDecode(response.body)['data'];
          errorMessage = '';

          // ✅ Debugging: Print fetched Fitbit data
          print("🔥 Full Fitbit Data: ${jsonEncode(fitbitData)}");

          processHeartRateData();
          processSleepData();

          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Failed to load Fitbit data.';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'An error occurred. Please try again later.';
        isLoading = false;
      });
    }
  }

  // Fetch Calendar Entries
  Future<List<Map<String, dynamic>>> fetchCalendarEntries(int childId) async {
    final String apiUrl =
        'https://3efd-80-233-12-225.ngrok-free.app/calendar_entries/$childId';

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<Map<String, dynamic>> fullCalendar =
            List<Map<String, dynamic>>.from(data['activities']);

        print("✅ Full Calendar Data: ${jsonEncode(fullCalendar)}");
        return fullCalendar;
      } else {
        print(
            "❌ Failed to fetch calendar entries. Status: ${response.statusCode}");
        return [];
      }
    } catch (e) {
      print("❌ Error fetching calendar entries: $e");
      return [];
    }
  }

  Future<void> checkLastFoodEvent() async {
    final String apiUrl =
        'https://3efd-80-233-12-225.ngrok-free.app/calendar_entries/${widget.childId}';

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<Map<String, dynamic>> allEvents =
            List<Map<String, dynamic>>.from(data['activities']);

        // ✅ Filter only 'Food' category events
        List<Map<String, dynamic>> mealEvents = allEvents
            .where((event) => event['category'].toLowerCase() == 'food')
            .toList();

        if (mealEvents.isNotEmpty) {
          // ✅ Sort by most recent first
          mealEvents.sort((a, b) => DateTime.parse(b['start_time'])
              .compareTo(DateTime.parse(a['start_time'])));

          DateTime latestMealTime =
              DateTime.parse(mealEvents.first['start_time']);

          // ✅ Check if within last 5 hours
          bool withinFiveHours =
              DateTime.now().difference(latestMealTime).inHours <= 5;

          setState(() {
            lastMealTime = latestMealTime.toLocal().toString();
            foodWarning =
                withinFiveHours ? null : "⚠️ No meals in the last 5 hours!";
          });

          print(
              "🍽️ Last Meal Time: $lastMealTime | Within 5 Hours: $withinFiveHours");
        } else {
          // ✅ No meal events found
          setState(() {
            lastMealTime = null;
            foodWarning = "⚠️ No meals logged!";
          });

          print("❌ No meals found.");
        }
      } else {
        print("❌ Failed to fetch food event data: ${response.statusCode}");
      }
    } catch (e) {
      print("❌ Error fetching last food event: $e");
    }
  }

  // Evaluate Sleep Quality
  void evaluateSleepQuality() {
    final sleepSummary = fitbitData?['sleep']?['summary'] ?? {};
    final totalMinutesAsleep = sleepSummary['totalMinutesAsleep'] ?? 0;
    final efficiency = fitbitData?['sleep']?['sleep']?[0]?['efficiency'] ?? 0;

    if (totalMinutesAsleep >= 420 && efficiency >= 85) {
      sleepQuality = 'Good';
      sleepQualityColor = Colors.green;
      sleepSuggestion =
          'Great job! Keep maintaining a consistent sleep schedule.';
    } else if (totalMinutesAsleep >= 300 && efficiency >= 70) {
      sleepQuality = 'Average';
      sleepQualityColor = Colors.yellow;
      sleepSuggestion =
          'You had a decent sleep, but aim for at least 7-8 hours to feel more rested.';
    } else {
      sleepQuality = 'Poor';
      sleepQualityColor = Colors.red;
      sleepSuggestion =
          'Try to get more sleep (at least 7-8 hours) and establish a calming bedtime routine.';
    }
  }

  void processSleepData() {
    final sleepSummary = fitbitData?['sleep']?['summary'] ?? {};
    final totalMinutesAsleep = sleepSummary['totalMinutesAsleep'] ?? 0;
    final efficiency = fitbitData?['sleep']?['sleep']?[0]?['efficiency'] ?? 0;

    if (totalMinutesAsleep >= 420 && efficiency >= 85) {
      sleepQuality = 'Good';
      sleepQualityColor = Colors.green;
      sleepSuggestion =
          'Great job! Keep maintaining a consistent sleep schedule.';
    } else if (totalMinutesAsleep >= 300 && efficiency >= 70) {
      sleepQuality = 'Average';
      sleepQualityColor = Colors.yellow;
      sleepSuggestion =
          'You had a decent sleep, but aim for at least 7-8 hours to feel more rested.';
    } else {
      sleepQuality = 'Poor';
      sleepQualityColor = Colors.red;
      sleepSuggestion =
          'Try to get more sleep (at least 7-8 hours) and establish a calming bedtime routine.';
    }

    setState(() {});
  }

  // Process Heart Rate Data and Check for Exercise During Spikes
  void processHeartRateData() {
    activityMatches.clear();
    final intradayData = fitbitData?['heart_rate_intraday']
            ?['activities-heart-intraday']?['dataset'] ??
        [];
    final restingHeartRate = fitbitData?['heart_rate']?['activities-heart']?[0]
            ?['value']?['restingHeartRate'] ??
        50;

    // Calculate threshold for a spike: 200% above resting heart rate
    final spikeThreshold = (restingHeartRate * 2).toInt();

    for (var dataPoint in intradayData) {
      final time = dataPoint['time'];
      final value = dataPoint['value'];
      final dataTime = DateTime.parse('$currentDate $time');

      bool wasActivityOngoing = false;
      String activityName = "Unknown";

      // ✅ Check if a calendar event was happening at this time
      for (var event in calendarEvents) {
        final eventStart = DateTime.parse(event['start_time']);
        final eventEnd = DateTime.parse(event['end_time']);

        if (dataTime.isAfter(eventStart) && dataTime.isBefore(eventEnd)) {
          wasActivityOngoing = true;
          activityName = event['activity_name'];
          break; // Stop checking once we find an activity match
        }
      }

      // ✅ Add data point with whether it was explained or not
      activityMatches.add({
        'time': time,
        'value': value,
        'wasActivityOngoing': wasActivityOngoing,
        'activityName': activityName
      });
    }

    setState(() {});
  }

  // Check if the child has eaten in the last 5 hours
  String? getLastMealTime() {
    final now = DateTime.now();
    DateTime? latestMealTime;

    for (var entry in calendarEvents) {
      if (entry['category'] == 'meal') {
        final mealTime = DateTime.parse(entry['start_time']);

        // ✅ Ensure we get the most recent meal within 5 hours
        if (now.difference(mealTime).inHours <= 5) {
          if (latestMealTime == null || mealTime.isAfter(latestMealTime)) {
            latestMealTime = mealTime;
          }
        }
      }
    }

    return latestMealTime?.toLocal().toString().split(' ')[1] ??
        'No meals in the last 5 hours!';
  }

  // Build Sleep Quality Card
  Widget buildSleepQualityCard() {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 10),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(
              Icons.bed,
              size: 40,
              color: sleepQualityColor,
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sleep Quality: $sleepQuality',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    sleepSuggestion,
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

  // Build Last Eaten Card
  Widget buildLastEatenCard() {
    final hasEatenRecently = lastMealTime != null &&
        DateTime.now().difference(DateTime.parse(lastMealTime!)).inHours <= 5;

    return Card(
      margin: EdgeInsets.symmetric(vertical: 10),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(
              Icons.fastfood,
              size: 40,
              color: hasEatenRecently
                  ? Colors.green
                  : Colors.red, // ✅ Correct color logic
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Eating Status',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    hasEatenRecently
                        ? 'Last meal: ${lastMealTime?.split(" ")[1] ?? "Unknown"}'
                        : '⚠️ No meals in the last 5 hours!',
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

  // Build Activity List
  Widget buildActivityList() {
    if (activityMatches.isEmpty) {
      return Center(
        child: Text(
          'No significant heart rate activity detected.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return Expanded(
      child: ListView.builder(
        itemCount: activityMatches.length,
        itemBuilder: (context, index) {
          final match = activityMatches[index];
          final time = match['time'];
          final value = match['value'];
          final wasActivityOngoing = match['wasActivityOngoing'];
          final activityName = match['activityName'];

          return Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
            elevation: 4,
            margin: EdgeInsets.symmetric(vertical: 8.0, horizontal: 0.0),
            child: ListTile(
              leading: Icon(
                wasActivityOngoing ? Icons.check_circle : Icons.warning,
                color: wasActivityOngoing ? Colors.green : Colors.red,
                size: 40,
              ),
              title: Text(
                'Time: $time',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: wasActivityOngoing ? Colors.green : Colors.red,
                ),
              ),
              subtitle: Text(
                'Heart Rate: $value bpm\n'
                '${wasActivityOngoing ? "✅ Explained by: $activityName" : "❌ No matching activity"}',
                style: TextStyle(fontSize: 14),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Activity Log'),
        backgroundColor: Colors.blue,
        centerTitle: true,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Date: $currentDate',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),
                  buildSleepQualityCard(),
                  SizedBox(height: 10),
                  buildLastEatenCard(),
                  SizedBox(height: 20),
                  Text(
                    'Heart Rate Activity',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),
                  buildActivityList(),
                ],
              ),
            ),
    );
  }
}
