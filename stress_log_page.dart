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
  DateTime selectedDate = DateTime.now(); // Start with today
  bool isLoading = true;
  List<dynamic> stressEvents = [];

  @override
  void initState() {
    super.initState();
    fetchStressEvents();
  }

  Future<void> fetchStressEvents() async {
    setState(() => isLoading = true); // Start loading state

    String formattedDate = DateFormat('yyyy-MM-dd').format(selectedDate);
    final url = Uri.parse(
        'https://1a05-80-233-39-72.ngrok-free.app/stress_events/${widget.childId}?date=$formattedDate');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          stressEvents = data['data'];
          isLoading = false;
        });
      } else {
        print("❌ Failed to fetch events: ${response.body}");
        setState(() => isLoading = false);
      }
    } catch (e) {
      print("❌ Error fetching stress events: $e");
      setState(() => isLoading = false);
    }
  }

  /// Move to Previous Day
  void goToPreviousDay() {
    setState(() {
      selectedDate = selectedDate.subtract(Duration(days: 1));
    });
    fetchStressEvents();
  }

  /// Move to Next Day (Prevents Going to Future Dates)
  void goToNextDay() {
    if (selectedDate.isBefore(DateTime.now())) {
      setState(() {
        selectedDate = selectedDate.add(Duration(days: 1));
      });
      fetchStressEvents();
    }
  }

  /// Show Dialog to Log Intervention
  void showInterventionDialog(int eventId) {
    final controller = TextEditingController();
    String selectedType = 'Other';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Log Intervention"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButton<String>(
              value: selectedType,
              onChanged: (value) =>
                  setState(() => selectedType = value ?? 'Other'),
              items: [
                'Breathing Exercise',
                'Weighted Blanket',
                'Calming Music',
                'Quiet Break',
                'Other',
              ]
                  .map((type) =>
                      DropdownMenuItem(value: type, child: Text(type)))
                  .toList(),
            ),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: InputDecoration(hintText: 'Describe what helped...'),
            )
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              await logIntervention(eventId, selectedType, controller.text);
              Navigator.pop(context);
              fetchStressEvents();
            },
            child: Text("Save"),
          )
        ],
      ),
    );
  }

  Future<void> logIntervention(int eventId, String type, String desc) async {
    final url = Uri.parse(
        'https://1a05-80-233-39-72.ngrok-free.app/log_intervention/$eventId');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "intervention_type": type,
        "description": desc,
      }),
    );

    if (response.statusCode == 200) {
      print("✅ Intervention logged");
    } else {
      print("❌ Failed to log intervention: ${response.body}");
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
          color: hasIntervention ? Colors.green : Colors.red,
          size: 32,
        ),
        title: Text(
          "Stress Spike: ${event['timestamp'].substring(11, 16)}",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (event['trigger'] != null && event['trigger'].isNotEmpty)
              Text("Trigger: ${event['trigger']}"),
            if (hasIntervention) ...[
              Text("✅ Resolved: ${intervention['intervention_type']}"),
              Text("📝 ${intervention['description']}"),
              Text(
                  "⏳ Resolved at: ${intervention['resolved_at'].substring(11, 16)}"),
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
          : stressEvents.isEmpty
              ? Center(
                  child: Text(
                    "✅ No stress threshold exceeded today for this child.",
                    style: TextStyle(fontSize: 16),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: ListView(
                    children:
                        stressEvents.map((e) => buildStressCard(e)).toList(),
                  ),
                ),
    );
  }
}
