import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class StressGraph extends StatefulWidget {
  final int childId;

  const StressGraph({Key? key, required this.childId}) : super(key: key);

  @override
  _StressGraphState createState() => _StressGraphState();
}

class _StressGraphState extends State<StressGraph> {
  Map<String, List<FlSpot>> groupedStressData = {};
  Map<String, List<DateTime>> timestampsByDate = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchStressScores();
  }

  Future<void> fetchStressScores() async {
    setState(() {
      isLoading = true;
    });

    final String apiUrl =
        'https://1a05-80-233-39-72.ngrok-free.app/get_stress_scores/${widget.childId}';

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);

        Map<String, List<FlSpot>> tempGroupedData = {};
        Map<String, List<DateTime>> tempTimestamps = {};

        for (var entry in jsonData['data']) {
          DateTime timestamp = DateTime.parse(entry['timestamp']);
          double stressScore = (entry['stress_score'] as num).toDouble();

          // Format date as YYYY-MM-DD
          String dateKey =
              "${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}";

          // Convert time into minutes since midnight
          double xValue = (timestamp.hour * 60 + timestamp.minute).toDouble();

          if (!tempGroupedData.containsKey(dateKey)) {
            tempGroupedData[dateKey] = [];
            tempTimestamps[dateKey] = [];
          }

          tempGroupedData[dateKey]!.add(FlSpot(xValue, stressScore));
          tempTimestamps[dateKey]!.add(timestamp);
        }

        setState(() {
          groupedStressData = tempGroupedData;
          timestampsByDate = tempTimestamps;
          isLoading = false;
        });
      } else {
        print("❌ Failed to fetch stress scores: ${response.body}");
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print("❌ Error fetching stress scores: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  /// **Formats timestamp to HH:MM**
  String formatTimestamp(double timestamp) {
    int totalMinutes = timestamp.toInt();
    int hours = totalMinutes ~/ 60;
    int minutes = totalMinutes % 60;
    return "$hours:${minutes.toString().padLeft(2, '0')}";
  }

  /// **Builds the line chart data with dynamic maxX**
  LineChartData _buildLineChartData(List<FlSpot> stressData, String date) {
    // Get latest data point for this day
    double latestTime = stressData.last.x; // Latest timestamp

    return LineChartData(
      minX: 0, // Start of day (00:00)
      maxX: latestTime, // Adjust dynamically to the latest time
      gridData: FlGridData(
        show: true,
        getDrawingHorizontalLine: (value) =>
            FlLine(color: Colors.grey.shade300, strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            getTitlesWidget: (value, meta) => Text(
              value.toStringAsFixed(1), // 1 decimal place
              style: TextStyle(fontSize: 12),
            ),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            interval: 120, // Show label every 2 hours
            getTitlesWidget: (value, meta) {
              return Text(
                formatTimestamp(value),
                style: TextStyle(fontSize: 10),
                textAlign: TextAlign.center,
              );
            },
          ),
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: stressData,
          isCurved: true,
          barWidth: 3,
          belowBarData:
              BarAreaData(show: true, color: Colors.blue.withOpacity(0.3)),
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) =>
                FlDotCirclePainter(
              radius: 4,
              color: Colors.blue,
              strokeWidth: 2,
              strokeColor: Colors.white,
            ),
          ),
          color: Colors.blue,
        ),
      ],
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          tooltipPadding: EdgeInsets.all(8),
          tooltipRoundedRadius: 8,
          tooltipMargin: 10,
          fitInsideHorizontally: true,
          fitInsideVertically: true,
          getTooltipItems: (List<LineBarSpot> touchedSpots) {
            return touchedSpots.map((spot) {
              return LineTooltipItem(
                "Time: ${formatTimestamp(spot.x)}\nScore: ${spot.y.toStringAsFixed(1)}",
                TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              );
            }).toList();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<String> sortedDates = groupedStressData.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(title: Text("Stress Score Graph")),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : groupedStressData.isEmpty
              ? Center(
                  child: Text(
                    "📉 No stress data available yet.",
                    style: TextStyle(fontSize: 16),
                  ),
                )
              : ListView.builder(
                  itemCount: sortedDates.length,
                  itemBuilder: (context, index) {
                    String date = sortedDates[index];
                    bool isToday = date ==
                        "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}";

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 16),
                          child: Text(
                            isToday ? "📅 Today" : "📆 $date",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          height: 300,
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: LineChart(_buildLineChartData(
                              groupedStressData[date]!, date)),
                        ),
                      ],
                    );
                  },
                ),
    );
  }
}
