import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class StressLogPage extends StatefulWidget {
  final int childId;

  const StressLogPage({Key? key, required this.childId}) : super(key: key);

  @override
  _StressLogPageState createState() => _StressLogPageState();
}

class _StressLogPageState extends State<StressLogPage> {
  DateTime selectedDate = DateTime.now();
  bool isLoading = true;
  List<dynamic> stressEvents = [];
  List<dynamic> topInterventions = [];

  @override
  void initState() {
    super.initState();
    fetchStressEvents();
    fetchTopInterventions();
  }

  Future<void> fetchStressEvents() async {
    setState(() => isLoading = true);
    String formattedDate = DateFormat('yyyy-MM-dd').format(selectedDate);
    final url = Uri.parse(
        'https://f099-37-228-234-175.ngrok-free.app/stress_events/${widget.childId}?date=$formattedDate');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          stressEvents = data['data'];
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      print("❌ Error: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> fetchTopInterventions() async {
    final url = Uri.parse(
        'https://f099-37-228-234-175.ngrok-free.app/top_interventions/${widget.childId}');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          topInterventions = data['top_interventions'];
        });
      }
    } catch (e) {
      print("❌ Error fetching top interventions: $e");
    }
  }

  void goToPreviousDay() {
    setState(() {
      selectedDate = selectedDate.subtract(Duration(days: 1));
    });
    fetchStressEvents();
  }

  void goToNextDay() {
    if (selectedDate.isBefore(DateTime.now())) {
      setState(() {
        selectedDate = selectedDate.add(Duration(days: 1));
      });
      fetchStressEvents();
    }
  }

  void showInterventionDialog(int eventId) {
    final causeController = TextEditingController();
    final interventionController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Log Stress Event Details"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: causeController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'What caused the stress?',
              ),
            ),
            SizedBox(height: 10),
            TextField(
              controller: interventionController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'What helped calm them down?',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              await logIntervention(
                eventId,
                interventionController.text.trim(),
                causeController.text.trim(),
              );
              Navigator.pop(context);
              fetchStressEvents();
              fetchTopInterventions();
            },
            child: Text("Save"),
          )
        ],
      ),
    );
  }

  Future<void> logManualStressEvent(String trigger, DateTime timestamp) async {
    final url = Uri.parse(
        "https://f099-37-228-234-175.ngrok-free.app/manual_log_stress");

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "child_id": widget.childId,
          "trigger": trigger,
          "timestamp": timestamp.toIso8601String()
        }),
      );

      if (response.statusCode == 200) {
        print("✅ Manual stress event logged!");
      } else {
        print("❌ Failed to log manual stress event: ${response.body}");
      }
    } catch (e) {
      print("❌ Error logging manual event: $e");
    }
  }

  Future<void> logIntervention(
      int eventId, String intervention, String cause) async {
    final url = Uri.parse(
        'https://f099-37-228-234-175.ngrok-free.app/log_intervention/$eventId');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "intervention_type": intervention,
        "description": cause,
      }),
    );

    if (response.statusCode == 200) {
      print("✅ Intervention logged");
    } else {
      print("❌ Failed to log intervention: ${response.body}");
    }
  }

  Future<void> checkEffectivenessNow(int interventionId) async {
    final url = Uri.parse(
        'https://f099-37-228-234-175.ngrok-free.app/update_intervention_effectiveness/$interventionId');

    final response = await http.post(url);

    if (response.statusCode == 200) {
      print("✅ Intervention effectiveness updated");
      fetchStressEvents(); // Refresh the UI with updated effectiveness
    } else {
      print("❌ Failed to update effectiveness: ${response.body}");
    }
  }

  Widget buildStressCard(Map<String, dynamic> event) {
    final hasIntervention =
        event['interventions'] != null && event['interventions'].isNotEmpty;
    final intervention = hasIntervention ? event['interventions'][0] : null;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Icon(
          hasIntervention ? Icons.check_circle : Icons.warning_amber_rounded,
          color: getStressIconColor(event, hasIntervention),
          size: 32,
        ),
        title: Text(
          "Stress Spike: ${event['timestamp'].substring(11, 16)}",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (event['stress_score'] != null)
              Text("📊 Stress Score at time: ${event['stress_score']}"),
            if (event['trigger'] != null && event['trigger'].isNotEmpty)
              Text("Trigger: ${event['trigger']}"),
            if (event['stress_score'] != null)
              Text("📊 Stress Score at time: ${event['stress_score']}"),
            if (!hasIntervention && event['during_activity'] == true)
              Text(
                  "⚠️ Occurred during activity (e.g., gym/PE) — may be expected."),
            if (hasIntervention) ...[
              Text("✅ Resolved with: ${intervention['intervention_type']}"),
              Text("📝 What happened: ${intervention['description']}"),
              Text(
                  "⏳ Resolved at: ${intervention['resolved_at'].substring(11, 16)}"),
              if (intervention['stress_score_after'] ==
                  null) // <-- This line checks unresolved
                TextButton.icon(
                  onPressed: () async {
                    await checkEffectivenessNow(intervention['id']);
                  },
                  icon: Icon(Icons.refresh),
                  label: Text("Check if this helped now"),
                )
            ]
          ],
        ),
        trailing: hasIntervention
            ? null
            : TextButton(
                child: Text("Add"),
                onPressed: () => showInterventionDialog(event['id']),
              ),
      ),
    );
  }

  Widget buildLeaderboardCard(Map<String, dynamic> intervention, int index) {
    IconData icon = Icons.emoji_events;
    Color iconColor;

    switch (index) {
      case 0:
        iconColor = Colors.amber; // Gold
        break;
      case 1:
        iconColor = Colors.grey; // Silver
        break;
      case 2:
        iconColor = Colors.brown; // Bronze
        break;
      default:
        iconColor = Colors.blueGrey; // Others
    }

    return ListTile(
      leading: Icon(Icons.emoji_events, color: Colors.amber),
      title: Text("${intervention['intervention_type']}"),
      subtitle: Text(
          "Avg Drop: ${intervention['average_stress_drop']}  |  Used: ${intervention['times_used']}x"),
    );
  }

  @override
  Widget build(BuildContext context) {
    String formattedDate = DateFormat('yyyy-MM-dd').format(selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: Text("Stress Event Log"),
        actions: [
          IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: goToPreviousDay,
          ),
          Text(
            formattedDate,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: Icon(Icons.arrow_forward),
            onPressed: goToNextDay,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (topInterventions.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        Icon(Icons.bar_chart, color: Colors.deepPurple),
                        SizedBox(width: 8),
                        Text(
                          "Top Interventions",
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  ...topInterventions.asMap().entries.map(
                        (entry) => buildLeaderboardCard(entry.value, entry.key),
                      ),
                  Divider(),
                ],
                Expanded(
                  child: stressEvents.isEmpty
                      ? Center(
                          child: Text(
                            "✅ No stress threshold exceeded today for this child.",
                            style: TextStyle(fontSize: 16),
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.all(16),
                          child: ListView(
                            children: stressEvents
                                .map((e) => buildStressCard(e))
                                .toList(),
                          ),
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: showManualLogDialog,
        backgroundColor: Colors.redAccent,
        child: Icon(Icons.add_alert),
        tooltip: "Manually Log Stress Event",
      ),
    );
  }

  void showManualLogDialog() {
    final TextEditingController triggerController = TextEditingController();
    TimeOfDay selectedTime = TimeOfDay.now();

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text("Manually Log Dysregulation"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: triggerController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: "What happened?",
                ),
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Text("Time: ${selectedTime.format(context)}"),
                  Spacer(),
                  TextButton(
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: selectedTime,
                      );
                      if (picked != null) {
                        setState(() {
                          selectedTime = picked;
                        });
                      }
                    },
                    child: Text("Pick Time"),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                final trigger = triggerController.text.trim();
                if (trigger.isNotEmpty) {
                  final now = DateTime.now();
                  final DateTime fullTimestamp = DateTime(
                    now.year,
                    now.month,
                    now.day,
                    selectedTime.hour,
                    selectedTime.minute,
                  );
                  await logManualStressEvent(trigger, fullTimestamp);
                  Navigator.pop(context);
                  fetchStressEvents();
                }
              },
              child: Text("Log Event"),
            ),
          ],
        ),
      ),
    );
  }

  Color getStressIconColor(Map<String, dynamic> event, bool hasIntervention) {
    if (hasIntervention) return Colors.green;
    if (event['during_activity'] == true) return Colors.orange; // 🟧 New
    return Colors.red;
  }
}
