import 'package:flutter/material.dart';
import 'package:db_compat/db_compat.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';

class VendorHomeScreen extends StatefulWidget {
  const VendorHomeScreen({super.key});

  @override
  State<VendorHomeScreen> createState() => _VendorHomeScreenState();
}

class _VendorHomeScreenState extends State<VendorHomeScreen> {
  final _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text('Login required'));

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsGrid(user.uid),
          const SizedBox(height: 24),
          _buildRevenueChart(user.uid),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildTopProducts(user.uid)),
              const SizedBox(width: 24),
              Expanded(child: _buildLowStockAlerts(user.uid)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(String vendorId) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('orders')
          .where('vendorId', isEqualTo: vendorId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return _buildStatsLoading();
        }

        final orders = snapshot.data!.docs;
        int totalOrders = 0; // Only delivered/completed orders
        int pendingOrders = 0;
        int completedOrders = 0;
        double todayEarnings = 0;
        final today = DateTime.now();
        final todayStart = DateTime(today.year, today.month, today.day);

        for (final doc in orders) {
          final data = doc.data();
          final status = (data['status'] ?? '').toString().toLowerCase();
          final amount = (data['total'] ?? data['totalAmount'] ?? 0).toDouble();
          final orderDate =
              (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

          if (status == 'pending' || status == 'placed') {
            pendingOrders++;
          }

          // Only count delivered/completed orders for earnings and total
          if (status == 'completed' || status == 'delivered') {
            completedOrders++;
            totalOrders++; // Count only delivered as total
            if (orderDate.isAfter(todayStart)) {
              todayEarnings += amount;
            }
          }
        }

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.5,
          children: [
            _buildStatCard(
              '📦',
              totalOrders.toString(),
              'Total Orders',
              const Color(0xFFFF5722),
            ),
            _buildStatCard(
              '💰',
              '₹${todayEarnings.toStringAsFixed(0)}',
              'Today Earnings',
              const Color(0xFF4CAF50),
            ),
            _buildStatCard(
              '⏳',
              pendingOrders.toString(),
              'Pending Orders',
              const Color(0xFFFF9800),
            ),
            _buildStatCard(
              '✅',
              completedOrders.toString(),
              'Completed Orders',
              const Color(0xFF2196F3),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E1E1E), Color(0xFF2A2A2A)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 28)),
              const Spacer(),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.5),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
            ],
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsLoading() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: List.generate(
        4,
        (index) => Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Center(
            child: CircularProgressIndicator(color: Color(0xFFFF5722)),
          ),
        ),
      ),
    );
  }

  Widget _buildRevenueChart(String vendorId) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
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
            'Revenue Trend',
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
              stream: _firestore
                  .collection('orders')
                  .where('vendorId', isEqualTo: vendorId)
                  .where('status', whereIn: ['completed', 'delivered'])
                  .orderBy('createdAt', descending: true)
                  .limit(30)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No revenue data yet',
                      style: TextStyle(color: Color(0xFFAAAAAA)),
                    ),
                  );
                }

                final orders = snapshot.data!.docs;
                final dailyRevenue = <double>[];

                // Group by last 7 days
                for (int i = 6; i >= 0; i--) {
                  final date = DateTime.now().subtract(Duration(days: i));
                  final dayStart = DateTime(date.year, date.month, date.day);
                  final dayEnd = dayStart.add(const Duration(days: 1));

                  double dayTotal = 0;
                  for (final doc in orders) {
                    final data = doc.data();
                    final orderDate =
                        (data['createdAt'] as Timestamp?)?.toDate() ??
                        DateTime.now();
                    if (orderDate.isAfter(dayStart) &&
                        orderDate.isBefore(dayEnd)) {
                      dayTotal += (data['total'] ?? data['totalAmount'] ?? 0)
                          .toDouble();
                    }
                  }
                  dailyRevenue.add(dayTotal);
                }

                return LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 500,
                      getDrawingHorizontalLine: (value) {
                        return const FlLine(
                          color: Color(0xFF333333),
                          strokeWidth: 1,
                        );
                      },
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 50,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              '₹${value.toInt()}',
                              style: const TextStyle(
                                color: Color(0xFFAAAAAA),
                                fontSize: 10,
                              ),
                            );
                          },
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
                    lineBarsData: [
                      LineChartBarData(
                        spots: dailyRevenue.asMap().entries.map((e) {
                          return FlSpot(e.key.toDouble(), e.value);
                        }).toList(),
                        isCurved: true,
                        color: const Color(0xFFFF5722),
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(
                          show: true,
                          color: const Color(0xFFFF5722).withValues(alpha: 0.1),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopProducts(String vendorId) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E1E1E), Color(0xFF2A2A2A)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🏆 Top Products',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('products')
                .where('vendorId', isEqualTo: vendorId)
                .orderBy('totalSales', descending: true)
                .limit(5)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Text(
                  'No products yet',
                  style: TextStyle(color: Color(0xFFAAAAAA)),
                );
              }

              final products = snapshot.data!.docs;
              return Column(
                children: products.map((doc) {
                  final data = doc.data();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFFF5722,
                            ).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.shopping_bag,
                            color: Color(0xFFFF5722),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data['title'] ?? 'Product',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${data['totalSales'] ?? 0} sales',
                                style: const TextStyle(
                                  color: Color(0xFFAAAAAA),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '₹${data['price'] ?? 0}',
                          style: const TextStyle(
                            color: Color(0xFF4CAF50),
                            fontWeight: FontWeight.bold,
                          ),
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

  Widget _buildLowStockAlerts(String vendorId) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E1E1E), Color(0xFF2A2A2A)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFF9800).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '⚠️ Low Stock Alerts',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('products')
                .where('vendorId', isEqualTo: vendorId)
                .where('stock', isLessThanOrEqualTo: 10)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Text(
                  'All products well stocked ✓',
                  style: TextStyle(color: Color(0xFF4CAF50)),
                );
              }

              final products = snapshot.data!.docs;
              return Column(
                children: products.map((doc) {
                  final data = doc.data();
                  final stock = data['stock'] ?? 0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(
                          stock == 0 ? Icons.error : Icons.warning,
                          color: stock == 0
                              ? Colors.red
                              : const Color(0xFFFF9800),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            data['title'] ?? 'Product',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Text(
                          '$stock left',
                          style: TextStyle(
                            color: stock == 0
                                ? Colors.red
                                : const Color(0xFFFF9800),
                            fontWeight: FontWeight.bold,
                          ),
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
}
