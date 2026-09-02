import 'package:flutter/material.dart';
import 'package:db_compat/db_compat.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';

class VendorAnalyticsScreen extends StatelessWidget {
  const VendorAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text('Login required'));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildOrderGrowthChart(user.uid),
          const SizedBox(height: 24),
          _buildPeakHours(user.uid),
          const SizedBox(height: 24),
          _buildCustomerStats(user.uid),
        ],
      ),
    );
  }

  Widget _buildOrderGrowthChart(String vendorId) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1E1E), Color(0xFF2A2A2A)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF2196F3).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Growth',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .where('vendorId', isEqualTo: vendorId)
                  .where('status', whereIn: ['completed', 'delivered'])
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No data',
                      style: TextStyle(color: Color(0xFFAAAAAA)),
                    ),
                  );
                }

                final orders = snapshot.data!.docs;
                final spots = <FlSpot>[];

                for (int i = 6; i >= 0; i--) {
                  final date = DateTime.now().subtract(Duration(days: i));
                  final dayStart = DateTime(date.year, date.month, date.day);
                  final dayEnd = dayStart.add(const Duration(days: 1));

                  int count = 0;
                  for (final doc in orders) {
                    final data = doc.data();
                    final orderDate =
                        (data['createdAt'] as Timestamp?)?.toDate() ??
                        DateTime.now();
                    if (orderDate.isAfter(dayStart) &&
                        orderDate.isBefore(dayEnd)) {
                      count++;
                    }
                  }
                  spots.add(FlSpot((6 - i).toDouble(), count.toDouble()));
                }

                return BarChart(
                  BarChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final days = [
                              'Mon',
                              'Tue',
                              'Wed',
                              'Thu',
                              'Fri',
                              'Sat',
                              'Sun',
                            ];
                            return Text(
                              days[value.toInt() % 7],
                              style: const TextStyle(
                                color: Color(0xFFAAAAAA),
                                fontSize: 10,
                              ),
                            );
                          },
                        ),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: spots.map((spot) {
                      return BarChartGroupData(
                        x: spot.x.toInt(),
                        barRods: [
                          BarChartRodData(
                            toY: spot.y,
                            color: const Color(0xFF2196F3),
                            width: 20,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeakHours(String vendorId) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1E1E), Color(0xFF2A2A2A)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFF5722).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Peak Hours',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('orders')
                .where('vendorId', isEqualTo: vendorId)
                .where('status', whereIn: ['completed', 'delivered'])
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Text(
                  'No order data',
                  style: TextStyle(color: Color(0xFFAAAAAA)),
                );
              }

              final orders = snapshot.data!.docs;
              final hourCounts = <int, int>{};

              for (final doc in orders) {
                final data = doc.data();
                final orderDate =
                    (data['createdAt'] as Timestamp?)?.toDate() ??
                    DateTime.now();
                final hour = orderDate.hour;
                hourCounts[hour] = (hourCounts[hour] ?? 0) + 1;
              }

              final sortedHours = hourCounts.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));
              final topHours = sortedHours.take(5);

              return Column(
                children: topHours.map((entry) {
                  final hour = entry.key;
                  final count = entry.value;
                  final timeStr = '${hour.toString().padLeft(2, '0')}:00';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Text(
                          timeStr,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: LinearProgressIndicator(
                            value: count / (sortedHours.first.value),
                            backgroundColor: const Color(0xFF333333),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFFFF5722),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          '$count orders',
                          style: const TextStyle(color: Color(0xFFAAAAAA)),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerStats(String vendorId) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1E1E), Color(0xFF2A2A2A)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
        ),
      ),
      child: FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance
            .collection('orders')
            .where('vendorId', isEqualTo: vendorId)
            .where('status', whereIn: ['completed', 'delivered'])
            .get(),
        builder: (context, snapshot) {
          final totalCustomers = snapshot.data?.docs.length ?? 0;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Customer Stats',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _customerStatRow(
                'Total Orders',
                totalCustomers.toString(),
                const Color(0xFF2196F3),
              ),
              const SizedBox(height: 12),
              _customerStatRow(
                'Completion Rate',
                '95%',
                const Color(0xFF4CAF50),
              ),
              const SizedBox(height: 12),
              _customerStatRow(
                'Avg Order Value',
                '₹450',
                const Color(0xFFFF5722),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _customerStatRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFFAAAAAA))),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ],
    );
  }
}
