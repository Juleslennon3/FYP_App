import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class MealGraph extends StatefulWidget {
  final int childId;

  const MealGraph({Key? key, required this.childId}) : super(key: key);

  @override
  _MealGraphState createState() => _MealGraphState();
}

class _MealGraphState extends State<MealGraph> {
  List<double> mealGaps = List.filled(7, 0.0);
  List<double> mealCounts = List.filled(7, 0.0);
  List<String> dateLabels = List.filled(7, "");

  @override
  void initState() {
    super.initState();
    fetchMealData();
  }

  /// Fetch meal data from the backend API
  Future<void> fetchMealData() async {
    try {
      final String apiUrl =
          "https://1a05-80-233-39-72.ngrok-free.app/getMealData/${widget.childId}";
      print("🚀 Fetching meal data from: $apiUrl");

      final response = await http.get(Uri.parse(apiUrl));

      print("🔵 Response Code: ${response.statusCode}");
      print("🟡 Raw Response Body: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data == null ||
            !data.containsKey("meal_gaps") ||
            !data.containsKey("meal_counts") ||
            !data.containsKey("dates")) {
          print("❌ API response missing required fields!");
          throw Exception("Invalid API response format");
        }

        setState(() {
          mealGaps = List<double>.from(
              (data["meal_gaps"] as List).map((e) => (e as num).toDouble()));
          mealCounts = List<double>.from(
              (data["meal_counts"] as List).map((e) => (e as num).toDouble()));
          dateLabels = List<String>.from(data["dates"]);

          print("✅ Meal Gaps: $mealGaps");
          print("✅ Meal Counts: $mealCounts");
          print("✅ Date Labels: $dateLabels");
        });
      } else {
        print("❌ Failed to load meal data (Status: ${response.statusCode})");
        throw Exception("API returned status ${response.statusCode}");
      }
    } catch (e) {
      print("❌ Error fetching meal data: $e");
      setState(() {
        mealGaps = List.filled(7, 0.0);
        mealCounts = List.filled(7, 0.0);
        dateLabels = ["", "", "", "", "", "", ""];
      });
    }
  }

  /// Build a line chart with optional baseline
  Widget buildLineChart(List<double> data, String title, Color lineColor,
      {double? baseline, String? baselineLabel}) {
    if (data.isEmpty || data.every((element) => element == 0.0)) {
      return Center(child: Text("No Data Available for $title"));
    }

    return Column(
      children: [
        Text(title,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        SizedBox(
          height: 200, // Adjust as needed
          child: LineChart(
            LineChartData(
              gridData: FlGridData(show: true),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      return Text("${value.toInt()}",
                          style: TextStyle(fontSize: 12));
                    },
                    interval: 1,
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      int index = value.toInt();
                      return index >= 0 && index < dateLabels.length
                          ? Text(dateLabels[index],
                              style: TextStyle(fontSize: 10))
                          : Container();
                    },
                    interval: 1,
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: data
                      .asMap()
                      .entries
                      .map((entry) => FlSpot(entry.key.toDouble(), entry.value))
                      .toList(),
                  isCurved: true,
                  color: lineColor,
                  barWidth: 3,
                  dotData: FlDotData(show: true),
                  belowBarData: BarAreaData(
                      show: true, color: lineColor.withOpacity(0.3)),
                ),
                // ➕ **Baseline at 4 hours between meals**
                if (baseline != null)
                  LineChartBarData(
                    spots: [
                      FlSpot(0, baseline),
                      FlSpot(data.length.toDouble() - 1, baseline),
                    ],
                    isCurved: false,
                    color: Colors.grey,
                    barWidth: 2,
                    dashArray: [6, 4], // Dashed line effect
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(show: false),
                  ),
              ],
            ),
          ),
        ),
        if (baselineLabel != null) // Show label below the graph
          Text(
            baselineLabel,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        SizedBox(height: 20),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Meal Graphs")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            buildLineChart(mealCounts, "Meals Eaten Per Day",
                Colors.green), // No baseline needed
            buildLineChart(mealGaps, "Meal Gaps (Hours)", Colors.orange,
                baseline: 4.0, // 🍽 **Baseline at 4 hours**
                baselineLabel: "Recommended meal gap: 4 hours"),
          ],
        ),
      ),
    );
  }
}
