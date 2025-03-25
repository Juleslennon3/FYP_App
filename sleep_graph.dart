import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class SleepGraph extends StatelessWidget {
  final List<double> sleepData; // Hours of sleep over the past week

  const SleepGraph({Key? key, required this.sleepData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Sleep Graph")),
      body: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9, // Make graph wider
          height: 300, // Increased height for clarity
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 5,
                spreadRadius: 2,
              ),
            ],
          ),
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: value == 8
                        ? Colors.green
                        : Colors.grey.shade300, // Baseline in green
                    strokeWidth: value == 8 ? 2 : 1, // Thicker for baseline
                  );
                },
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        "${value.toInt()} hrs",
                        style: TextStyle(
                          fontSize: 12,
                          color: value == 8
                              ? Colors.green
                              : Colors.black, // Green label for baseline
                          fontWeight:
                              value == 8 ? FontWeight.bold : FontWeight.normal,
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        "Day ${value.toInt() + 1}",
                        style: TextStyle(fontSize: 12, color: Colors.black),
                      );
                    },
                  ),
                ),
                topTitles:
                    AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: sleepData
                      .asMap()
                      .entries
                      .map((entry) => FlSpot(entry.key.toDouble(), entry.value))
                      .toList(),
                  isCurved: true,
                  color: Colors.blue,
                  barWidth: 3,
                  belowBarData: BarAreaData(
                    show: true,
                    color: Colors.blue.withOpacity(0.3),
                  ),
                  dotData: FlDotData(show: true),
                ),
              ],
              extraLinesData: ExtraLinesData(
                horizontalLines: [
                  HorizontalLine(
                    y: 8, // Baseline at 8 hours
                    color: Colors.green,
                    strokeWidth: 2,
                    dashArray: [5, 5], // Dashed line for baseline
                    label: HorizontalLineLabel(
                      show: true,
                      alignment: Alignment.topRight,
                      labelResolver: (line) => "Recommended: 8 hrs",
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
