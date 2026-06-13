import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

// Widget biểu đồ đường hiển thị doanh thu từng tháng trong năm.
// Thiết kế Neo-Brutalism: Nền trắng, viền đen dày, shadow cứng.
class MonthlyRevenueLineChart extends StatelessWidget {
  final List<dynamic> yearly;
  final Color color;
  const MonthlyRevenueLineChart({super.key, required this.yearly, this.color = Colors.black});

  @override
  Widget build(BuildContext context) {
    if (yearly.isEmpty) return const SizedBox();

    return Container(
      height: 240,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2.5),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black,
            offset: Offset(4, 4),
          ),
        ],
      ),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) => Text(
                  '${value.toInt()}K',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                reservedSize: 38,
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= yearly.length) return const SizedBox();
                  final month = yearly[idx]['month'] as int;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '$month',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(
            show: true,
            border: const Border(
              bottom: BorderSide(color: Colors.black, width: 2),
              left: BorderSide(color: Colors.black, width: 2),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(yearly.length, (i) {
                final revenue = yearly[i]['revenue'] as int;
                return FlSpot(i.toDouble(), double.parse((revenue / 1000).toStringAsFixed(3)));
              }),
              isCurved: true,
              color: color,
              barWidth: 3.5,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(show: false),
            ),
          ],
        ),
      ),
    );
  }
}
