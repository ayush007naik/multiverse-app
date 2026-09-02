import 'package:flutter/material.dart';
import 'package:db_compat/db_compat.dart';
import '../../core/theme/app_theme.dart';
import 'package:intl/intl.dart';

class AppointmentBookingsScreen extends StatefulWidget {
  const AppointmentBookingsScreen({super.key});

  @override
  State<AppointmentBookingsScreen> createState() => _AppointmentBookingsScreenState();
}

class _AppointmentBookingsScreenState extends State<AppointmentBookingsScreen> {
  String _searchQuery = '';
  String _statusFilter = 'all';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Appointment Bookings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _buildFilters(),
              ],
            ),
            const SizedBox(height: 24),
            _buildSearchField(),
            const SizedBox(height: 24),
            Expanded(
              child: _buildBookingsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: DropdownButton<String>(
        value: _statusFilter,
        dropdownColor: AppTheme.darkSurface,
        underline: const SizedBox(),
        style: const TextStyle(color: Colors.white),
        items: [
          'all',
          'searching_providers',
          'provider_assigned',
          'service_completed',
          'cancelled'
        ].map((String status) {
          return DropdownMenuItem<String>(
            value: status,
            child: Text(status.replaceAll('_', ' ').toUpperCase()),
          );
        }).toList(),
        onChanged: (value) {
          if (value != null) setState(() => _statusFilter = value);
        },
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: 'Search by Customer ID or Service Type...',
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
        prefixIcon: const Icon(Icons.search, color: AppTheme.accentOrange),
        filled: true,
        fillColor: AppTheme.darkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
    );
  }

  Widget _buildBookingsList() {
    Query query = FirebaseFirestore.instance.collection('bookings');

    if (_statusFilter != 'all') {
      query = query.where('status', isEqualTo: _statusFilter);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final customerId = (data['customerId'] ?? '').toString().toLowerCase();
          final serviceType = (data['serviceType'] ?? '').toString().toLowerCase();
          return customerId.contains(_searchQuery) || serviceType.contains(_searchQuery);
        }).toList();

        if (docs.isEmpty) {
          return const Center(
            child: Text('No bookings found', style: TextStyle(color: Colors.white54)),
          );
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            return _buildBookingCard(docs[index].id, data);
          },
        );
      },
    );
  }

  Widget _buildBookingCard(String id, Map<String, dynamic> data) {
    final status = data['status'] ?? 'unknown';
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            _buildStatusIndicator(status),
            const SizedBox(width: 20),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['serviceType'] ?? 'Unknown Service',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Customer: ${data['customerId']}',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 14, color: AppTheme.accentOrange),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          data['address']?['addressLine'] ?? 'No address',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const VerticalDivider(color: Colors.white10),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('MMM dd, yyyy').format(createdAt),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    DateFormat('hh:mm a').format(createdAt),
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '₹${data['acceptedPrice'] ?? data['budget'] ?? 0}',
                    style: const TextStyle(color: AppTheme.accentOrange, fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Fee: ₹${((data['platformFee'] ?? 0) is num ? (data['platformFee'] as num).toDouble() : 0.0).toStringAsFixed(0)}',
                    style: TextStyle(color: AppTheme.secondaryCyan, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'GST: ₹${((data['gst'] ?? 0) is num ? (data['gst'] as num).toDouble() : 0.0).toStringAsFixed(0)}',
                    style: TextStyle(color: Colors.teal, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    data['paymentStatus']?.toString().toUpperCase() ?? 'UNPAID',
                    style: TextStyle(
                      color: data['paymentStatus'] == 'paid' ? Colors.green : Colors.redAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(String status) {
    Color color;
    IconData icon;
    
    switch (status) {
      case 'searching_providers':
        color = Colors.blue;
        icon = Icons.search;
        break;
      case 'provider_assigned':
        color = Colors.orange;
        icon = Icons.person;
        break;
      case 'service_completed':
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'cancelled':
        color = Colors.red;
        icon = Icons.cancel;
        break;
      default:
        color = Colors.grey;
        icon = Icons.help;
    }

    return Container(
      width: 50,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(child: Icon(icon, color: color)),
    );
  }
}
