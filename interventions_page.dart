import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class InterventionsPage extends StatefulWidget {
  final int childId;

  const InterventionsPage({Key? key, required this.childId}) : super(key: key);

  @override
  _InterventionsPageState createState() => _InterventionsPageState();
}

class _InterventionsPageState extends State<InterventionsPage> {
  List<dynamic> topInterventions = [];
  bool isLoading = true;

  final TextEditingController _situationController = TextEditingController();
  String? aiSuggestion;
  bool isLoadingSuggestion = false;

  @override
  void initState() {
    super.initState();
    fetchTopInterventions();
  }

  Future<void> fetchTopInterventions() async {
    final url = Uri.parse(
        'https://8226-37-228-234-44.ngrok-free.app/top_interventions/${widget.childId}');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          topInterventions = data['top_interventions'];
          isLoading = false;
        });
      }
    } catch (e) {
      print("❌ Error fetching top interventions: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> fetchOpenAiSuggestion() async {
    final url = Uri.parse(
        'https://8226-37-228-234-44.ngrok-free.app/suggest_intervention');
    final situation = _situationController.text.trim();

    if (situation.isEmpty) return;

    setState(() {
      isLoadingSuggestion = true;
      aiSuggestion = null;
    });

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"situation": situation}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          aiSuggestion = data['suggestion'];
        });
      } else {
        print("❌ Error: ${response.body}");
      }
    } catch (e) {
      print("❌ Error fetching suggestion: $e");
    } finally {
      setState(() => isLoadingSuggestion = false);
    }
  }

  Widget buildLeaderboardCard(Map<String, dynamic> intervention, int index) {
    Color iconColor;
    switch (index) {
      case 0:
        iconColor = Colors.amber;
        break;
      case 1:
        iconColor = Colors.grey;
        break;
      case 2:
        iconColor = Colors.brown;
        break;
      default:
        iconColor = Colors.blueGrey;
    }

    return ListTile(
      leading: Icon(Icons.emoji_events, color: iconColor),
      title: Text("${intervention['intervention_type']}"),
      subtitle: Text(
          "Avg Drop: ${intervention['average_stress_drop']} | Used: ${intervention['times_used']}x"),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Interventions")),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("🏆 Top Interventions",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  ...topInterventions.asMap().entries.map(
                        (entry) => buildLeaderboardCard(entry.value, entry.key),
                      ),
                  Divider(height: 40),
                  Text("🤖 Get AI-Powered Suggestion",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 10),
                  TextField(
                    controller: _situationController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: "Describe the situation...",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 10),
                  ElevatedButton.icon(
                    icon: Icon(Icons.auto_fix_high),
                    label: Text("Get Suggestion"),
                    onPressed: fetchOpenAiSuggestion,
                  ),
                  if (isLoadingSuggestion) ...[
                    SizedBox(height: 16),
                    Center(child: CircularProgressIndicator())
                  ],
                  if (aiSuggestion != null) ...[
                    SizedBox(height: 16),
                    Text("🧘 Suggested Intervention:",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    SizedBox(height: 8),
                    Card(
                      color: Colors.lightBlue[50],
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          aiSuggestion!,
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ]
                ],
              ),
            ),
    );
  }
}
