import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart'; // For date formatting

class HeartRateGraph extends StatefulWidget {
  final int childId;

  const HeartRateGraph({Key? key, required this.childId}) : super(key: key);

  @override
  _HeartRateGraphState createState() => _HeartRateGraphState();
}

class _HeartRateGraphState extends State<HeartRateGraph> {
  List<FlSpot> heartRateSpots = [];
  bool isLoading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    fetchHeartRateData();
  }

  Future<void> fetchHeartRateData() async {
    String todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final String apiUrl =
        'https://db45-37-228-234-175.ngrok-free.app/get_intraday_heart_rate/${widget.childId}/$todayDate';

    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final decodedData = jsonDecode(response.body);
        final List<dynamic> rawData =
            decodedData['data']['activities-heart-intraday']['dataset'] ?? [];

        List<FlSpot> spots = rawData.asMap().entries.map((entry) {
          int index = entry.key;
          double bpm = (entry.value['value'] as num).toDouble();
          return FlSpot(index.toDouble(), bpm);
        }).toList();

        setState(() {
          heartRateSpots = spots;
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Failed to load heart rate data.';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error fetching data: $e';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Heart Rate Graph")),
      body: isLoading
          ? Center(child: CircularProgressIndicator()) // ⏳ Loading state
          : errorMessage.isNotEmpty
              ? Center(
                  child: Text(errorMessage,
                      style: TextStyle(color: Colors.red, fontSize: 18)),
                ) // ❌ Error message
              : Padding(
                  padding: const EdgeInsets.only(
                      left: 16.0,
                      right: 16.0,
                      top: 20.0,
                      bottom: 16.0), // 👈 Increased top padding slightly
                  child: SizedBox(
                    width: double.infinity, // Make graph full-width
                    height: 420, // Slightly increased height to prevent overlap
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (value) {
                            return FlLine(
                              color: Colors.grey.shade300,
                              strokeWidth: 1,
                            );
                          },
                        ),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 32, // Reduce size to prevent squish
                              getTitlesWidget: (value, meta) {
                                return Padding(
                                  padding: EdgeInsets.only(right: 8.0),
                                  child: Text(
                                    "${value.toInt()} BPM",
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black),
                                  ),
                                );
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 24, // Prevent overlap
                              getTitlesWidget: (value, meta) {
                                int index = value.toInt();
                                if (index % 120 == 0) {
                                  return Padding(
                                    padding: EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      "${index ~/ 60}h",
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  );
                                }
                                return Container(); // Hide unnecessary labels
                              },
                            ),
                          ),
                          topTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          rightTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border: Border.all(
                            color: Colors.grey.shade400, // Subtle border
                          ),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: heartRateSpots,
                            isCurved: true,
                            color: Colors.red,
                            barWidth: 2.5, // Slightly thinner
                            belowBarData: BarAreaData(
                              show: true,
                              color: Colors.red.withOpacity(0.2),
                            ),
                            dotData: FlDotData(
                              show: false, // Hide dots for cleaner look
                            ),
                          ),

                          // ➕ **Baseline at 65 BPM**
                          LineChartBarData(
                            spots: [
                              FlSpot(0, 65), // Start of X-axis at 65 BPM
                              FlSpot(24 * 60, 65), // End of X-axis at 65 BPM
                            ],
                            isCurved: false,
                            color: Colors.grey.withOpacity(0.5),
                            barWidth: 2,
                            dashArray: [6, 4], // Dashed line effect
                            dotData: FlDotData(show: false),
                            belowBarData: BarAreaData(show: false),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }
}
