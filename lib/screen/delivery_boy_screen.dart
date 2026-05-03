// 📁 lib/screens/delivery_boy_screen.dart
// ✅ Delivery Boy App for MULTIVERSE — Mandi, Himachal Pradesh

import 'package:flutter/material.dart';
import 'dart:async';

class DeliveryBoyScreen extends StatefulWidget {
  const DeliveryBoyScreen({super.key});

  @override
  State<DeliveryBoyScreen> createState() => _DeliveryBoyScreenState();
}

class _DeliveryBoyScreenState extends State<DeliveryBoyScreen> {
  int _selectedTab = 0;
  bool _isOnline = true;
  int _todayEarnings = 840;
  int _todayOrders = 6;

  // 📦 Incoming Orders
  final List<Map<String, dynamic>> _newOrders = [
    {
      'id': 'MV002345',
      'shop': 'Sharma Hardware Store',
      'shopAddr': 'Mandi Bazaar, Near Clock Tower',
      'customer': 'Amit Thakur',
      'customerAddr': 'Indira Colony, Mandi - 175001',
      'items': '3 items',
      'total': 687,
      'distance': '1.2 km',
      'eta': '12 min',
      'earning': 45,
      'icon': '🔨',
      'accepted': false,
    },
    {
      'id': 'MV002346',
      'shop': 'Shiv Medical Store',
      'shopAddr': 'Purani Mandi, HP',
      'customer': 'Priya Verma',
      'customerAddr': 'Seri Manch Area, Mandi',
      'items': '2 items',
      'total': 340,
      'distance': '0.8 km',
      'eta': '8 min',
      'earning': 35,
      'icon': '💊',
      'accepted': false,
    },
  ];

  // ✅ Active / Completed Orders
  final List<Map<String, dynamic>> _activeOrders = [
    {
      'id': 'MV002340',
      'customer': 'Rajesh Kumar',
      'customerAddr': 'Bus Stand Road, Mandi',
      'items': '5 items',
      'total': 520,
      'earning': 50,
      'icon': '🥫',
      'status': 'Picked Up',
      'statusColor': 0xFFFF9800,
    },
  ];

  final List<Map<String, dynamic>> _completedOrders = [
    {
      'id': 'MV002330',
      'customer': 'Sunita Devi',
      'earning': 40,
      'icon': '👔',
      'time': '1:30 PM',
    },
    {
      'id': 'MV002318',
      'customer': 'Mohan Lal',
      'earning': 55,
      'icon': '🔨',
      'time': '11:45 AM',
    },
    {
      'id': 'MV002305',
      'customer': 'Kavita Sharma',
      'earning': 35,
      'icon': '💊',
      'time': '10:20 AM',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      bottomNavigationBar: _buildBottomNav(),
      body: SafeArea(
        child: _selectedTab == 0
            ? _buildHomeTab()
            : _selectedTab == 1
            ? _buildOrdersTab()
            : _buildEarningsTab(),
      ),
    );
  }

  // 🏠 Home Tab
  Widget _buildHomeTab() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopBar(),
          _buildOnlineToggle(),
          _buildTodayStats(),
          if (_isOnline) ...[
            _buildSectionHeader('🔔 New Orders', '${_newOrders.length} waiting'),
            ..._newOrders.map((o) => _buildNewOrderCard(o)),
            _buildSectionHeader('🚴 Active Order', ''),
            ..._activeOrders.map((o) => _buildActiveOrderCard(o)),
          ] else
            _buildOfflineCard(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // 🔝 Top Bar
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFFF4D4F),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Center(
              child: Text('R',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900)),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Ravi Kumar',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800)),
              Row(
                children: [
                  const Icon(Icons.star_rounded,
                      color: Color(0xFFFFB300), size: 13),
                  const SizedBox(width: 3),
                  const Text('4.8 · Delivery Partner',
                      style: TextStyle(
                          color: Color(0xFF888888), fontSize: 12)),
                ],
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _isOnline
                  ? const Color(0xFF4CAF50).withValues(alpha: 0.15)
                  : const Color(0xFF555555).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isOnline
                    ? const Color(0xFF4CAF50).withValues(alpha: 0.4)
                    : const Color(0xFF555555).withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: _isOnline
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFF666666),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _isOnline ? 'Online' : 'Offline',
                  style: TextStyle(
                    color: _isOnline
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFF888888),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🔛 Online Toggle
  Widget _buildOnlineToggle() {
    return GestureDetector(
      onTap: () => setState(() => _isOnline = !_isOnline),
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _isOnline
                ? [
              const Color(0xFF4CAF50).withValues(alpha: 0.2),
              const Color(0xFF4CAF50).withValues(alpha: 0.05),
            ]
                : [
              const Color(0xFF333333),
              const Color(0xFF222222),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isOnline
                ? const Color(0xFF4CAF50).withValues(alpha: 0.3)
                : const Color(0xFF272727),
          ),
        ),
        child: Row(
          children: [
            Text(
              _isOnline ? '🟢' : '🔴',
              style: const TextStyle(fontSize: 28),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isOnline ? 'You are Online' : 'You are Offline',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  _isOnline
                      ? 'Receiving new orders in Mandi'
                      : 'Tap to go online & earn',
                  style: const TextStyle(
                      color: Color(0xFF888888), fontSize: 12),
                ),
              ],
            ),
            const Spacer(),
            Switch(
              value: _isOnline,
              onChanged: (v) => setState(() => _isOnline = v),
              activeColor: const Color(0xFF4CAF50),
            ),
          ],
        ),
      ),
    );
  }

  // 📊 Today Stats
  Widget _buildTodayStats() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        children: [
          _miniStat('💰', '₹$_todayEarnings', "Today's Earning"),
          const SizedBox(width: 10),
          _miniStat('📦', '$_todayOrders', 'Deliveries'),
          const SizedBox(width: 10),
          _miniStat('⭐', '4.8', 'Rating'),
        ],
      ),
    );
  }

  Widget _miniStat(String icon, String val, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF272727)),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 5),
            Text(val,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    color: Color(0xFF888888), fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String sub) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800)),
          if (sub.isNotEmpty)
            Text(sub,
                style: const TextStyle(
                    color: Color(0xFFFF4D4F), fontSize: 12)),
        ],
      ),
    );
  }

  // 🔔 New Order Card
  Widget _buildNewOrderCard(Map<String, dynamic> o) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFFFF4D4F).withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFF4D4F).withValues(alpha: 0.08),
              borderRadius:
              const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(Icons.notifications_active_rounded,
                    color: Color(0xFFFF4D4F), size: 16),
                const SizedBox(width: 8),
                const Text('New Order!',
                    style: TextStyle(
                        color: Color(0xFFFF4D4F),
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
                const Spacer(),
                Text('#${o['id']}',
                    style: const TextStyle(
                        color: Color(0xFF888888), fontSize: 11)),
              ],
            ),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                // Shop → Customer
                Row(
                  children: [
                    Text(o['icon'] as String,
                        style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(o['shop'] as String,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700)),
                          Text(o['shopAddr'] as String,
                              style: const TextStyle(
                                  color: Color(0xFF888888),
                                  fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      const SizedBox(width: 34),
                      const Icon(Icons.arrow_downward_rounded,
                          color: Color(0xFF444444), size: 16),
                    ],
                  ),
                ),
                Row(
                  children: [
                    const Text('🏠',
                        style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(o['customer'] as String,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700)),
                          Text(o['customerAddr'] as String,
                              style: const TextStyle(
                                  color: Color(0xFF888888),
                                  fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Info chips
                Row(
                  children: [
                    _chip('📍 ${o['distance']}'),
                    const SizedBox(width: 8),
                    _chip('⏱ ${o['eta']}'),
                    const SizedBox(width: 8),
                    _chip('💰 ₹${o['earning']}'),
                  ],
                ),
                const SizedBox(height: 14),
                // Accept / Reject
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _rejectOrder(o),
                        child: Container(
                          padding:
                          const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.red.withValues(alpha: 0.3)),
                          ),
                          child: const Center(
                            child: Text('✕  Reject',
                                style: TextStyle(
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: GestureDetector(
                        onTap: () => _acceptOrder(o),
                        child: Container(
                          padding:
                          const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Text('✓  Accept Order',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🚴 Active Order Card
  Widget _buildActiveOrderCard(Map<String, dynamic> o) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFF9800).withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(o['icon'] as String,
                  style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(o['customer'] as String,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    Text(o['customerAddr'] as String,
                        style: const TextStyle(
                            color: Color(0xFF888888), fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Color(o['statusColor'] as int).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  o['status'] as String,
                  style: TextStyle(
                    color: Color(o['statusColor'] as int),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    // TODO: Open Google Maps navigation
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2196F3).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFF2196F3).withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.navigation_rounded,
                            color: Color(0xFF2196F3), size: 16),
                        SizedBox(width: 6),
                        Text('Navigate',
                            style: TextStyle(
                                color: Color(0xFF2196F3),
                                fontWeight: FontWeight.w700,
                                fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => _markDelivered(o),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_rounded,
                            color: Colors.white, size: 16),
                        SizedBox(width: 6),
                        Text('Delivered',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF272727)),
      ),
      child: Text(label,
          style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 11)),
    );
  }

  Widget _buildOfflineCard() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF272727)),
      ),
      child: const Column(
        children: [
          Text('😴', style: TextStyle(fontSize: 52)),
          SizedBox(height: 14),
          Text('You are Offline',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
          SizedBox(height: 8),
          Text('Go online to start receiving orders in Mandi',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF888888), fontSize: 13)),
        ],
      ),
    );
  }

  // 📋 Orders Tab
  Widget _buildOrdersTab() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Text('📋 All Orders',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900)),
          ),
          if (_activeOrders.isNotEmpty) ...[
            _buildSectionHeader('🚴 Active', ''),
            ..._activeOrders.map((o) => _buildActiveOrderCard(o)),
          ],
          _buildSectionHeader(
              '✅ Completed Today', '${_completedOrders.length} orders'),
          ..._completedOrders.map((o) => _buildCompletedCard(o)),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildCompletedCard(Map<String, dynamic> o) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF272727)),
      ),
      child: Row(
        children: [
          Text(o['icon'] as String,
              style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(o['customer'] as String,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
                Text('#${o['id']} · ${o['time']}',
                    style: const TextStyle(
                        color: Color(0xFF888888), fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('+₹${o['earning']}',
                  style: const TextStyle(
                      color: Color(0xFF4CAF50),
                      fontSize: 14,
                      fontWeight: FontWeight.w800)),
              const Text('Earned',
                  style: TextStyle(
                      color: Color(0xFF888888), fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  // 💰 Earnings Tab
  Widget _buildEarningsTab() {
    final weekData = [
      {'day': 'Mon', 'amt': 620},
      {'day': 'Tue', 'amt': 890},
      {'day': 'Wed', 'amt': 450},
      {'day': 'Thu', 'amt': 1100},
      {'day': 'Fri', 'amt': 780},
      {'day': 'Sat', 'amt': 1340},
      {'day': 'Sun', 'amt': 840},
    ];
    final maxAmt = weekData.map((d) => d['amt'] as int).reduce((a, b) => a > b ? a : b);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Text('💰 Earnings',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900)),
          ),
          // Summary cards
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                _earningCard('Today', '₹$_todayEarnings', '↑ 12%', true),
                const SizedBox(width: 12),
                _earningCard('This Week', '₹6,020', '↑ 8%', false),
              ],
            ),
          ),
          // Bar Chart
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF272727)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Weekly Overview',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 120,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: weekData.map((d) {
                        final h = ((d['amt'] as int) / maxAmt) * 100;
                        final isToday = d['day'] == 'Sun';
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text('₹${d['amt']}',
                                style: TextStyle(
                                    color: isToday
                                        ? const Color(0xFFFF4D4F)
                                        : const Color(0xFF888888),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Container(
                              width: 28,
                              height: h,
                              decoration: BoxDecoration(
                                color: isToday
                                    ? const Color(0xFFFF4D4F)
                                    : const Color(0xFF333333),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(d['day'] as String,
                                style: TextStyle(
                                    color: isToday
                                        ? Colors.white
                                        : const Color(0xFF888888),
                                    fontSize: 10,
                                    fontWeight: isToday
                                        ? FontWeight.w700
                                        : FontWeight.normal)),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Breakdown
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF272727)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Today's Breakdown",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 14),
                  _earningRow('🛵 Delivery Earnings', '₹750'),
                  _earningRow('⭐ Bonus (4.8 rating)', '₹50'),
                  _earningRow('⚡ Peak Hour Bonus', '₹40'),
                  const Divider(color: Color(0xFF272727), height: 20),
                  _earningRow('💰 Total', '₹$_todayEarnings', bold: true),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _earningCard(String label, String val, String change, bool highlight) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: highlight
              ? const Color(0xFFFF4D4F).withValues(alpha: 0.1)
              : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: highlight
                ? const Color(0xFFFF4D4F).withValues(alpha: 0.3)
                : const Color(0xFF272727),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: Color(0xFF888888), fontSize: 12)),
            const SizedBox(height: 6),
            Text(val,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(change,
                style: const TextStyle(
                    color: Color(0xFF4CAF50),
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _earningRow(String label, String val, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: bold ? Colors.white : const Color(0xFF888888),
                  fontSize: bold ? 14 : 13,
                  fontWeight:
                  bold ? FontWeight.w700 : FontWeight.normal)),
          Text(val,
              style: TextStyle(
                  color: bold ? const Color(0xFFFF4D4F) : Colors.white,
                  fontSize: bold ? 15 : 13,
                  fontWeight:
                  bold ? FontWeight.w900 : FontWeight.w600)),
        ],
      ),
    );
  }

  // ✅ Actions
  void _acceptOrder(Map<String, dynamic> o) {
    setState(() {
      _newOrders.remove(o);
      _activeOrders.add({...o, 'status': 'Picked Up', 'statusColor': 0xFFFF9800});
      _todayOrders++;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Order accepted! Head to the shop.'),
        backgroundColor: Color(0xFF4CAF50),
      ),
    );
  }

  void _rejectOrder(Map<String, dynamic> o) {
    setState(() => _newOrders.remove(o));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Order rejected.'),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  void _markDelivered(Map<String, dynamic> o) {
    setState(() {
      _activeOrders.remove(o);
      _completedOrders.insert(0, {
        'id': o['id'],
        'customer': o['customer'],
        'earning': o['earning'] ?? 45,
        'icon': o['icon'],
        'time': 'Just now',
      });
      _todayEarnings += (o['earning'] as int? ?? 45);
      _todayOrders++;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🎉 Order delivered! Earnings updated.'),
        backgroundColor: Color(0xFF4CAF50),
      ),
    );
  }

  // 🔘 Bottom Nav
  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: _selectedTab,
      onTap: (i) => setState(() => _selectedTab = i),
      backgroundColor: const Color(0xFF111111),
      selectedItemColor: const Color(0xFFFF4D4F),
      unselectedItemColor: const Color(0xFF555555),
      selectedFontSize: 11,
      unselectedFontSize: 11,
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded), label: 'Home'),
        BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_rounded), label: 'Orders'),
        BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_rounded),
            label: 'Earnings'),
      ],
    );
  }
}