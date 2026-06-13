import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

// Widget biểu đồ cột hiển thị doanh thu từng ngày trong tháng.
// Thiết kế Neo-Brutalism: Nền trắng, viền đen dày, shadow cứng.
class DailyRevenueBarChart extends StatelessWidget {
  final List<dynamic> daily;
  final Color color;
  const DailyRevenueBarChart({super.key, required this.daily, this.color = Colors.black});

  @override
  Widget build(BuildContext context) {
    if (daily.isEmpty) return const SizedBox();

    final maxRevenue = daily.map((d) => d['revenue'] as int).reduce((a, b) => a > b ? a : b);
    final double maxYValue = (maxRevenue * 1.2) / 1000;

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
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxYValue > 0 ? maxYValue : 10,
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
                  if (idx < 0 || idx >= daily.length) return const SizedBox();
                  final day = daily[idx]['day'] as String;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      day.split('/')[0], // chỉ hiển thị ngày
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
          gridData: const FlGridData(show: false),
          barGroups: List.generate(daily.length, (i) {
            final revenue = daily[i]['revenue'] as int;
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: double.parse((revenue / 1000).toStringAsFixed(3)),
                  color: color,
                  width: 14,
                  borderRadius: BorderRadius.circular(4),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: maxYValue > 0 ? maxYValue : 10,
                    color: Colors.black.withValues(alpha: 0.05),
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
