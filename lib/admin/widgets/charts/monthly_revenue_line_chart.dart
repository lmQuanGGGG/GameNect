import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

// Widget biểu đồ đường hiển thị doanh thu từng tháng trong năm.
// Nhận vào danh sách dữ liệu yearly gồm tháng, doanh thu, số gói bán ra.

class MonthlyRevenueLineChart extends StatelessWidget {
  final List<dynamic> yearly;
  const MonthlyRevenueLineChart({super.key, required this.yearly});

  @override
  Widget build(BuildContext context) {
    if (yearly.isEmpty) return const SizedBox();

    yearly.map((m) => m['revenue'] as int).reduce((a, b) => a > b ? a : b);
    return Container(
      height: 220,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) => Text(
                  '${value.toInt()}K',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
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
                      month.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  );
                },
              ),
            ),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1),
              right: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1),
              bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(yearly.length, (i) {
                final revenue = yearly[i]['revenue'] as int;
                return FlSpot(i.toDouble(), double.parse((revenue / 1000).toStringAsFixed(3)));
              }),
              isCurved: true,
              color: Colors.deepOrangeAccent,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
            ),
          ],
        ),
      ),
    );
  }
}
