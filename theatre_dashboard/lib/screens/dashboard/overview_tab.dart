import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:db_compat/db_compat.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../theme/cyberpunk_theme.dart';
import '../../services/theatre_service.dart';

class OverviewTab extends StatelessWidget {
  const OverviewTab({super.key});

  @override
  Widget build(BuildContext context) {
    final theatreService = Provider.of<TheatreService>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('DASHBOARD OVERVIEW', style: Theme.of(context).textTheme.titleLarge),
              Row(
                children: [
                  Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'LIVE',
                    style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, letterSpacing: 2),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Real-time Stats Row
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = (constraints.maxWidth - 48) / 4; // 3 gaps of 16px
              final isCompact = cardWidth < 200;
              final gap = isCompact ? 12.0 : 16.0;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  // Total Earned (Online)
                  SizedBox(
                    width: isCompact ? (constraints.maxWidth - gap) / 2 : cardWidth,
                    child: _RealtimeStatCard(
                      title: "TOTAL EARNED",
                      icon: Icons.trending_up,
                      color: Colors.greenAccent,
                      stream: theatreService.getAllBookings(),
                      valueBuilder: (docs) {
                        double total = 0;
                        for (final doc in docs) {
                          final data = doc.data();
                          if (TheatreService.isConfirmed(data) && !TheatreService.isOffline(data)) {
                            total += TheatreService.parseRevenue(data);
                          }
                        }
                        return '₹ ${total.toStringAsFixed(0)}';
                      },
                    ),
                  ),
                  // Available Balance
                  SizedBox(
                    width: isCompact ? (constraints.maxWidth - gap) / 2 : cardWidth,
                    child: StreamBuilder<QuerySnapshot>(
                      stream: theatreService.getAllBookings(),
                      builder: (context, bSnap) {
                        return StreamBuilder<QuerySnapshot>(
                          stream: theatreService.getPayouts(),
                          builder: (context, pSnap) {
                            double earned = 0;
                            for (final doc in (bSnap.data?.docs ?? [])) {
                              final data = doc.data() as Map<String, dynamic>;
                              if (TheatreService.isConfirmed(data) && !TheatreService.isOffline(data)) {
                                earned += TheatreService.parseRevenue(data);
                              }
                            }
                            double paidOut = 0;
                            double pending = 0;
                            for (final doc in (pSnap.data?.docs ?? [])) {
                              final data = doc.data() as Map<String, dynamic>;
                              final amount = (data['amount'] as num?)?.toDouble() ?? 0;
                              final status = (data['status'] ?? 'pending').toString().toLowerCase();
                              if (status == 'paid' || status == 'completed') {
                                paidOut += amount;
                              } else if (status == 'pending') pending += amount;
                            }
                            final available = earned - paidOut - pending;
                            return _StatCardUI(
                              title: "AVAILABLE BALANCE",
                              icon: Icons.account_balance_wallet,
                              color: Colors.amber,
                              value: '₹ ${available.toStringAsFixed(0)}',
                            );
                          },
                        );
                      },
                    ),
                  ),
                  // Paid Out
                  SizedBox(
                    width: isCompact ? (constraints.maxWidth - gap) / 2 : cardWidth,
                    child: _RealtimeStatCard(
                      title: "PAID OUT",
                      icon: Icons.check_circle,
                      color: const Color(0xFF2196F3),
                      stream: theatreService.getPayouts(),
                      valueBuilder: (docs) {
                        double total = 0;
                        for (final doc in docs) {
                          final data = doc.data();
                          final status = (data['status'] ?? 'pending').toString().toLowerCase();
                          if (status == 'paid' || status == 'completed') {
                            total += (data['amount'] as num?)?.toDouble() ?? 0;
                          }
                        }
                        return '₹ ${total.toStringAsFixed(0)}';
                      },
                    ),
                  ),
                  // Today's Revenue (Total)
                  SizedBox(
                    width: isCompact ? (constraints.maxWidth - gap) / 2 : cardWidth,
                    child: _RealtimeStatCard(
                      title: "TODAY'S REVENUE",
                      icon: Icons.payments,
                      color: CyberpunkTheme.primaryNeon,
                      stream: theatreService.getAllBookings(),
                      valueBuilder: (docs) {
                        final now = DateTime.now();
                        final today = DateFormat('yyyy-MM-dd').format(now);
                        double total = 0;
                        for (final doc in docs) {
                          final data = doc.data();
                          if (TheatreService.isConfirmed(data)) {
                            final createdAt = data['createdAt'];
                            String? docDate;
                            if (createdAt is Timestamp) {
                              docDate = DateFormat('yyyy-MM-dd').format(createdAt.toDate());
                            } else if (data['date'] != null) {
                              docDate = data['date'].toString(); 
                            }
                            if (docDate == today) {
                              total += TheatreService.parseRevenue(data);
                            }
                          }
                        }
                        return '₹ ${total.toStringAsFixed(0)}';
                      },
                    ),
                  ),
                  // Tickets Sold
                  SizedBox(
                    width: isCompact ? (constraints.maxWidth - gap) / 2 : cardWidth,
                    child: _RealtimeStatCard(
                      title: 'TICKETS SOLD',
                      icon: Icons.confirmation_num,
                      color: CyberpunkTheme.secondaryNeon,
                      stream: theatreService.getAllBookings(),
                      valueBuilder: (docs) {
                        int totalSeats = 0;
                        for (final doc in docs) {
                          final data = doc.data();
                          if (TheatreService.isConfirmed(data)) {
                            final seats = data['seats'] as List? ?? data['selectedSeats'] as List?;
                            totalSeats += seats?.length ?? 0;
                          }
                        }
                        return '$totalSeats';
                      },
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 48),

          // Real-time Charts
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 800;
              return isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildChartContainer(
                          'BOOKING TREND (LAST 7 DAYS)',
                          _RealtimeBookingChart(
                            bookingsStream: theatreService.getAllBookings(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildChartContainer(
                          'MOVIE DISTRIBUTION',
                          _RealtimeMoviePie(
                            moviesStream: theatreService.getAllGlobalMovies(),
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      _buildChartContainer(
                        'BOOKING TREND (LAST 7 DAYS)',
                        _RealtimeBookingChart(
                          bookingsStream: theatreService.getAllBookings(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildChartContainer(
                        'MOVIE DISTRIBUTION',
                        _RealtimeMoviePie(
                          moviesStream: theatreService.getAllGlobalMovies(),
                        ),
                      ),
                    ],
                  );
            },
          ),

          const SizedBox(height: 32),

          // Recent bookings
          _buildChartContainer(
            'RECENT BOOKINGS',
            _RealtimeRecentBookings(
              bookingsStream: theatreService.getAllBookings(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartContainer(String title, Widget chart) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CyberpunkTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 20),
          SizedBox(height: 260, child: chart),
        ],
      ),
    );
  }
}

// ── Real-time stat card ──
class _RealtimeStatCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Stream<QuerySnapshot> stream;
  final String Function(List<QueryDocumentSnapshot>) valueBuilder;

  const _RealtimeStatCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.stream,
    required this.valueBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return _StatCardUI(
      title: title,
      icon: icon,
      color: color,
      stream: stream,
      valueBuilder: valueBuilder,
    );
  }
}

// ── Shared Stat Card UI ──
class _StatCardUI extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Stream<QuerySnapshot>? stream;
  final String Function(List<QueryDocumentSnapshot>)? valueBuilder;
  final String? value;

  const _StatCardUI({
    required this.title,
    required this.icon,
    required this.color,
    this.stream,
    this.valueBuilder,
    this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CyberpunkTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 10, color: Colors.white54, letterSpacing: 1.2)),
          const SizedBox(height: 6),
          if (value != null)
            Text(
              value!,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          else if (stream != null)
            StreamBuilder<QuerySnapshot>(
              stream: stream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 28,
                    child: LinearProgressIndicator(backgroundColor: Colors.white10, minHeight: 2),
                  );
                }
                final docs = snapshot.data?.docs ?? [];
                final val = valueBuilder!(docs);
                return Text(
                  val,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                );
              },
            ),
        ],
      ),
    );
  }
}

// ── Real-time booking trend chart ──
class _RealtimeBookingChart extends StatelessWidget {
  final Stream<QuerySnapshot> bookingsStream;
  const _RealtimeBookingChart({required this.bookingsStream});

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

        // Build daily revenue for last 7 days
        final dailyRevenue = <double>[];
        final dayLabels = <String>[];
        for (int i = 6; i >= 0; i--) {
          final day = now.subtract(Duration(days: i));
          final dateStr = DateFormat('yyyy-MM-dd').format(day);
          dayLabels.add(DateFormat('EEE').format(day));
          double dayTotal = 0;
          for (final doc in docs) {
            final data = doc.data();
            if (TheatreService.isConfirmed(data)) {
              final createdAt = data['createdAt'];
              if (createdAt is Timestamp) {
                final docDate = DateFormat('yyyy-MM-dd').format(createdAt.toDate());
                if (docDate == dateStr) {
                  dayTotal += TheatreService.parseRevenue(data);
                }
              }
            }
          }
          dailyRevenue.add(dayTotal);
        }

        final maxVal = dailyRevenue.fold<double>(0, (a, b) => a > b ? a : b);
        final safeMax = maxVal == 0 ? 1.0 : maxVal;

        final spots = <FlSpot>[];
        for (int i = 0; i < dailyRevenue.length; i++) {
          spots.add(FlSpot(i.toDouble(), dailyRevenue[i]));
        }

        if (spots.isEmpty) {
          return const Center(child: Text('No booking data yet', style: TextStyle(color: Colors.white54)));
        }

        return LineChart(
          LineChartData(
            minY: 0,
            maxY: safeMax * 1.2,
            gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => const FlLine(color: Colors.white10, strokeWidth: 1)),
            titlesData: FlTitlesData(
              show: true,
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (val, meta) {
                    final idx = val.toInt();
                    if (idx < 0 || idx >= dayLabels.length) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(dayLabels[idx], style: const TextStyle(color: Colors.white38, fontSize: 10)),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (val, meta) {
                    return Text('\u20B9${val.toInt()}', style: const TextStyle(color: Colors.white38, fontSize: 10));
                  },
                  reservedSize: 50,
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: CyberpunkTheme.primaryNeon,
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: FlDotData(show: true, getDotPainter: (s, p, b, i) => FlDotCirclePainter(color: CyberpunkTheme.primaryNeon, radius: 4, strokeWidth: 2, strokeColor: Colors.white)),
                belowBarData: BarAreaData(show: true, color: CyberpunkTheme.primaryNeon.withValues(alpha: 0.08)),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Real-time movie distribution pie ──
class _RealtimeMoviePie extends StatelessWidget {
  final Stream<QuerySnapshot> moviesStream;
  const _RealtimeMoviePie({required this.moviesStream});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: moviesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: CyberpunkTheme.secondaryNeon));
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('No movies yet', style: TextStyle(color: Colors.white54)));
        }

        // Group by status
        int nowShowing = 0, upcoming = 0, ended = 0;
        for (final doc in docs) {
          final data = doc.data();
          final status = data['status'] ?? 'approved';
          if (status == 'approved' || status == 'now_showing') {
            nowShowing++;
          } else if (status == 'upcoming' || status == 'coming_soon') {
            upcoming++;
          } else {
            ended++;
          }
        }

        final total = nowShowing + upcoming + ended;
        final sections = <PieChartSectionData>[];
        if (nowShowing > 0) {
          sections.add(PieChartSectionData(
            color: CyberpunkTheme.primaryNeon, value: nowShowing.toDouble(),
            title: '${(nowShowing / total * 100).toInt()}%',
            radius: 50, titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
          ));
        }
        if (upcoming > 0) {
          sections.add(PieChartSectionData(
            color: CyberpunkTheme.secondaryNeon, value: upcoming.toDouble(),
            title: '${(upcoming / total * 100).toInt()}%',
            radius: 50, titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
          ));
        }
        if (ended > 0) {
          sections.add(PieChartSectionData(
            color: Colors.white24, value: ended.toDouble(),
            title: '${(ended / total * 100).toInt()}%',
            radius: 50, titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
          ));
        }

        return Column(
          children: [
            Expanded(
              child: PieChart(PieChartData(sectionsSpace: 4, centerSpaceRadius: 35, sections: sections)),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _legendDot(CyberpunkTheme.primaryNeon, 'Showing'),
                const SizedBox(width: 12),
                _legendDot(CyberpunkTheme.secondaryNeon, 'Upcoming'),
                const SizedBox(width: 12),
                _legendDot(Colors.white24, 'Ended'),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.white54)),
      ],
    );
  }
}

// ── Recent bookings table ──
class _RealtimeRecentBookings extends StatelessWidget {
  final Stream<QuerySnapshot> bookingsStream;
  const _RealtimeRecentBookings({required this.bookingsStream});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: bookingsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: CyberpunkTheme.primaryNeon));
        }
        final docs = (snapshot.data?.docs ?? []).take(5).toList();
        if (docs.isEmpty) {
          return const Center(
            heightFactor: 3,
            child: Text('No bookings yet', style: TextStyle(color: Colors.white54)),
          );
        }

        return SingleChildScrollView(
          child: DataTable(
            headingTextStyle: const TextStyle(color: CyberpunkTheme.primaryNeon, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
            dataTextStyle: const TextStyle(color: Colors.white70, fontSize: 12),
            columnSpacing: 20,
            columns: const [
              DataColumn(label: Text('ID')),
              DataColumn(label: Text('CUSTOMER')),
              DataColumn(label: Text('MOVIE')),
              DataColumn(label: Text('SEATS')),
              DataColumn(label: Text('AMOUNT')),
              DataColumn(label: Text('STATUS')),
            ],
            rows: docs.map((doc) {
              final d = doc.data();
              final seats = (d['seats'] as List? ?? d['selectedSeats'] as List? ?? []);
              
              // Standardize status logic to match BookingsTab
              final bStatus = (d['bookingStatus'] ?? d['status'] ?? 'pending').toString().toLowerCase();
              final isUsed = d['isUsed'] == true;
              
              String displayStatus = 'BOOKED';
              Color statusColor = Colors.greenAccent;

              if (bStatus == 'cancelled') {
                displayStatus = 'CANCELLED';
                statusColor = Colors.redAccent;
              } else if (isUsed) {
                displayStatus = 'USED';
                statusColor = Colors.blueAccent;
              } else if (bStatus == 'pending') {
                displayStatus = 'PENDING';
                statusColor = Colors.amber;
              } else if (bStatus == 'confirmed' || bStatus == 'success') {
                displayStatus = 'BOOKED';
                statusColor = Colors.greenAccent;
              } else {
                displayStatus = bStatus.toUpperCase();
                statusColor = Colors.amber;
              }

              return DataRow(cells: [
                DataCell(Text(doc.id.substring(0, 8), style: const TextStyle(fontFamily: 'monospace', fontSize: 11))),
                DataCell(Text(d['customerName'] ?? d['userName'] ?? d['userId'] ?? 'Guest', maxLines: 1, overflow: TextOverflow.ellipsis)),
                DataCell(Text(d['movieName'] ?? d['movieTitle'] ?? d['title'] ?? '-', maxLines: 1, overflow: TextOverflow.ellipsis)),
                DataCell(Text(seats.join(', '), maxLines: 1, overflow: TextOverflow.ellipsis)),
                DataCell(Text('\u20B9${TheatreService.parseRevenue(d).toStringAsFixed(0)}')),
                DataCell(Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(displayStatus, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: statusColor)),
                )),
              ]);
            }).toList(),
          ),
        );
      },
    );
  }
}
