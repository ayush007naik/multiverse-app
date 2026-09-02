import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:db_compat/db_compat.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../theme/cyberpunk_theme.dart';
import '../../services/theatre_service.dart';

class AnalyticsTab extends StatelessWidget {
  const AnalyticsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final theatreService = Provider.of<TheatreService>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ADVANCED ANALYTICS', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 32),

          // Revenue summary cards
          Row(
            children: [
              Expanded(
                child: _RevenueSummaryCard(
                  label: 'ONLINE REVENUE',
                  bookingsStream: theatreService.getBookings(),
                  color: CyberpunkTheme.accentNeon,
                  icon: Icons.cloud_done,
                  filterOffline: false,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _RevenueSummaryCard(
                  label: 'OFFLINE REVENUE',
                  bookingsStream: theatreService.getBookings(),
                  color: CyberpunkTheme.primaryNeon,
                  icon: Icons.confirmation_number,
                  filterOffline: true,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _AvgTicketCard(bookingsStream: theatreService.getBookings()),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Monthly revenue chart
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: CyberpunkTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('MONTHLY REVENUE (ONLINE VS OFFLINE)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    Row(
                      children: [
                        _ChartLegend(color: CyberpunkTheme.accentNeon, label: 'Online'),
                        SizedBox(width: 16),
                        _ChartLegend(color: CyberpunkTheme.primaryNeon, label: 'Offline'),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 300,
                  child: _MonthlyRevenueChart(
                    bookingsStream: theatreService.getAllBookings(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          Row(
            children: [
              // Bookings by status
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: CyberpunkTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('BOOKINGS BY STATUS', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 250,
                        child: _StatusDistributionChart(
                          bookingsStream: theatreService.getAllBookings(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 32),
              // Revenue Source Split
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: CyberpunkTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('REVENUE SOURCE SPLIT', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 250,
                        child: _SourceSplitChart(
                          bookingsStream: theatreService.getAllBookings(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RevenueSummaryCard extends StatelessWidget {
  final String label;
  final Stream<QuerySnapshot> bookingsStream;
  final Color color;
  final IconData icon;
  final bool? filterOffline;

  const _RevenueSummaryCard({
    required this.label,
    required this.bookingsStream,
    required this.color,
    required this.icon,
    this.filterOffline,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CyberpunkTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.white54, letterSpacing: 1)),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot>(
            stream: Provider.of<TheatreService>(context).getAllBookings(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(height: 28, child: LinearProgressIndicator(minHeight: 2));
              }
              final docs = snapshot.data?.docs ?? [];

              List<QueryDocumentSnapshot> filteredDocs = docs;
              if (filterOffline != null) {
                filteredDocs = docs.where((doc) {
                  final data = doc.data();
                  return TheatreService.isOffline(data) == filterOffline;
                }).toList();
              }

              double total = 0;
              for (final doc in filteredDocs) {
                final data = doc.data();
                if (TheatreService.isConfirmed(data)) {
                  total += TheatreService.parseRevenue(data);
                }
              }
              return Text('₹${total.toStringAsFixed(0)}', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color));
            },
          ),
        ],
      ),
    );
  }
}

class _AvgTicketCard extends StatelessWidget {
  final Stream<QuerySnapshot> bookingsStream;
  const _AvgTicketCard({required this.bookingsStream});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CyberpunkTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CyberpunkTheme.accentNeon.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.trending_up, color: CyberpunkTheme.accentNeon, size: 28),
          const SizedBox(height: 12),
          const Text('AVG. TICKET', style: TextStyle(fontSize: 11, color: Colors.white54, letterSpacing: 1)),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot>(
            stream: Provider.of<TheatreService>(context).getAllBookings(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(height: 28, child: LinearProgressIndicator(minHeight: 2));
              }
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Text('\u20B9 0', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: CyberpunkTheme.accentNeon));
              }
              double total = 0;
              int totalSeats = 0;
              for (final doc in docs) {
                final data = doc.data();
                if (TheatreService.isConfirmed(data)) {
                  total += TheatreService.parseRevenue(data);
                  final seats = data['seats'] as List? ?? data['selectedSeats'] as List?;
                  totalSeats += seats?.length ?? 0;
                }
              }
              final avg = totalSeats > 0 ? (total / totalSeats) : 0;
              return Text('\u20B9 ${avg.toStringAsFixed(0)}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: CyberpunkTheme.accentNeon));
            },
          ),
        ],
      ),
    );
  }
}

class _MonthlyRevenueChart extends StatelessWidget {
  final Stream<QuerySnapshot> bookingsStream;
  const _MonthlyRevenueChart({required this.bookingsStream});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: bookingsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: CyberpunkTheme.primaryNeon));
        }
        final docs = snapshot.data?.docs ?? [];
        final now = DateTime.now();
        final onlineRevenue = <double>[];
        final offlineRevenue = <double>[];
        final dayLabels = <String>[];

        for (int i = 29; i >= 0; i--) {
          final day = now.subtract(Duration(days: i));
          final dateStr = DateFormat('yyyy-MM-dd').format(day);
          dayLabels.add('${day.day}/${day.month}');
          double onlineTotal = 0;
          double offlineTotal = 0;
          for (final doc in docs) {
            final data = doc.data();
            if (TheatreService.isConfirmed(data)) {
              final createdAt = data['createdAt'];
              if (createdAt is Timestamp) {
                final docDate = DateFormat('yyyy-MM-dd').format(createdAt.toDate());
                if (docDate == dateStr) {
                  final amount = TheatreService.parseRevenue(data);
                  if (TheatreService.isOffline(data)) {
                    offlineTotal += amount;
                  } else {
                    onlineTotal += amount;
                  }
                }
              }
            }
          }
          onlineRevenue.add(onlineTotal);
          offlineRevenue.add(offlineTotal);
        }

        final maxVal = <double>[...onlineRevenue, ...offlineRevenue].fold<double>(0, (a, b) => a > b ? a : b);
        final safeMax = maxVal == 0 ? 100.0 : maxVal;

        return BarChart(
          BarChartData(
            maxY: safeMax * 1.5, // Extra space for stacking if needed
            gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => const FlLine(color: Colors.white10, strokeWidth: 1)),
            titlesData: FlTitlesData(
              show: true,
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 5,
                  getTitlesWidget: (val, meta) {
                    final idx = val.toInt();
                    if (idx < 0 || idx >= dayLabels.length) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(dayLabels[idx], style: const TextStyle(color: Colors.white38, fontSize: 9)),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 45,
                  getTitlesWidget: (val, meta) => Text('\u20B9${val.toInt()}', style: const TextStyle(color: Colors.white38, fontSize: 9)),
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            barGroups: List.generate(onlineRevenue.length, (i) {
              return BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: onlineRevenue[i] + offlineRevenue[i],
                    color: Colors.transparent,
                    width: 8,
                    rodStackItems: [
                      BarChartRodStackItem(0, onlineRevenue[i], CyberpunkTheme.accentNeon),
                      BarChartRodStackItem(onlineRevenue[i], onlineRevenue[i] + offlineRevenue[i], CyberpunkTheme.primaryNeon),
                    ],
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                  ),
                ],
              );
            }),
          ),
        );
      },
    );
  }
}

class _ChartLegend extends StatelessWidget {
  final Color color;
  final String label;
  const _ChartLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}

class _SourceSplitChart extends StatelessWidget {
  final Stream<QuerySnapshot> bookingsStream;
  const _SourceSplitChart({required this.bookingsStream});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: bookingsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: CyberpunkTheme.accentNeon));
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('No revenue data', style: TextStyle(color: Colors.white54)));
        }

        double onlineTotal = 0;
        double offlineTotal = 0;
        for (final doc in docs) {
          final data = doc.data();
          if (TheatreService.isConfirmed(data)) {
            final amount = TheatreService.parseRevenue(data);
            if (TheatreService.isOffline(data)) {
              offlineTotal += amount;
            } else {
              onlineTotal += amount;
            }
          }
        }

        final total = onlineTotal + offlineTotal;
        if (total == 0) return const Center(child: Text('No revenue data', style: TextStyle(color: Colors.white54)));

        final sections = [
          PieChartSectionData(
            color: CyberpunkTheme.accentNeon,
            value: onlineTotal,
            title: 'Online\n${(onlineTotal / total * 100).toStringAsFixed(1)}%',
            radius: 60,
            titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          PieChartSectionData(
            color: CyberpunkTheme.primaryNeon,
            value: offlineTotal,
            title: 'Offline\n${(offlineTotal / total * 100).toStringAsFixed(1)}%',
            radius: 60,
            titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ];

        return PieChart(PieChartData(sectionsSpace: 3, centerSpaceRadius: 30, sections: sections));
      },
    );
  }
}

class _StatusDistributionChart extends StatelessWidget {
  final Stream<QuerySnapshot> bookingsStream;
  const _StatusDistributionChart({required this.bookingsStream});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: bookingsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: CyberpunkTheme.secondaryNeon));
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('No bookings yet', style: TextStyle(color: Colors.white54)));
        }

        final statusCounts = <String, int>{};
        for (final doc in docs) {
          final data = doc.data();
          final bStatus = (data['bookingStatus'] ?? data['status'] ?? 'pending').toString().toLowerCase();
          
          String statusKey = bStatus;
          if (bStatus == 'success') statusKey = 'confirmed';
          
          statusCounts[statusKey] = (statusCounts[statusKey] ?? 0) + 1;
        }

        final colors = {
          'confirmed': Colors.greenAccent,
          'pending': Colors.amber,
          'cancelled': Colors.redAccent,
          'refunded': Colors.blueAccent,
        };

        final sections = <PieChartSectionData>[];
        for (final entry in statusCounts.entries) {
          sections.add(PieChartSectionData(
            color: colors[entry.key] ?? Colors.white24,
            value: entry.value.toDouble(),
            title: '${entry.key}\n${entry.value}',
            radius: 60,
            titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
          ));
        }

        return PieChart(PieChartData(sectionsSpace: 3, centerSpaceRadius: 30, sections: sections));
      },
    );
  }
}
