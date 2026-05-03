import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

// Widget biểu đồ cột hiển thị doanh thu từng tháng trong năm.
// Nhận vào danh sách dữ liệu yearly gồm tháng, doanh thu, số gói bán ra.

class YearlyRevenueBarChart extends StatelessWidget {
  final List<Map<String, dynamic>> yearly;
  const YearlyRevenueBarChart({super.key, required this.yearly});

  @override
  Widget build(BuildContext context) {
    if (yearly.isEmpty) return const SizedBox();

    final maxRevenue = yearly.map((m) => m['revenue'] as int).reduce((a, b) => a > b ? a : b);
    return Container(
      height: 220,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: (maxRevenue * 1.2) ~/ 1000 + 1,
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
                      '$month',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  );
                },
              ),
            ),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(show: false),
          barGroups: List.generate(yearly.length, (i) {
            final revenue = yearly[i]['revenue'] as int;
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: double.parse((revenue / 1000).toStringAsFixed(3)),
                  color: Colors.deepOrangeAccent,
                  width: 18,
                  borderRadius: BorderRadius.circular(8),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: double.parse(((maxRevenue * 1.2) / 1000).toStringAsFixed(3)),
                    color: Colors.white.withValues(alpha: 0.07),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}
