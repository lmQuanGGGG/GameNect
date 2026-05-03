import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

// Widget biểu đồ cột hiển thị doanh thu từng ngày trong tháng.
// Nhận vào danh sách dữ liệu daily gồm ngày, doanh thu, số gói bán ra.

class DailyRevenueBarChart extends StatelessWidget {
  final List<dynamic> daily;
  const DailyRevenueBarChart({super.key, required this.daily});

  @override
  Widget build(BuildContext context) {
    if (daily.isEmpty) return const SizedBox();

    final maxRevenue = daily.map((d) => d['revenue'] as int).reduce((a, b) => a > b ? a : b);
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
                  if (idx < 0 || idx >= daily.length) return const SizedBox();
                  final day = daily[idx]['day'] as String;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      day.split('/')[0], // chỉ hiển thị ngày
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
          barGroups: List.generate(daily.length, (i) {
            final revenue = daily[i]['revenue'] as int;
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
