import 'package:flutter/material.dart';
import 'dart:ui';
import '../widgets/premium_ui_widgets.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Bookings & Services',
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 22),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFF4D4F),
          indicatorWeight: 3,
          labelColor: const Color(0xFFFF4D4F),
          unselectedLabelColor: Colors.grey,
          labelStyle:
          const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          tabs: const [
            Tab(text: 'Instant Services'),
            Tab(text: 'Appointments'),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D0D0D), Color(0xFF1A1A1A)],
          ),
        ),
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildInstantServices(),
            _buildScheduledAppointments(),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════
  // MY BOOKINGS (Service Requests)
  // ══════════════════════════════════════
  Widget _buildMyBookings() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('service_requests')
          .where('customerId', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final requests = snapshot.data?.docs ?? [];
        final activeRequests = requests.where((r) {
          final status =
              (r.data() as Map<String, dynamic>)['status'] ?? '';
          return status == 'open' || status == 'accepted';
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Text(
                'My Bookings',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
            ),
            activeRequests.isEmpty
                ? Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF2A2A2A)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.handyman_outlined,
                      color: Colors.grey, size: 20),
                  SizedBox(width: 12),
                  Text('No bookings yet',
                      style: TextStyle(
                          color: Colors.grey, fontSize: 14)),
                ],
              ),
            )
                : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: activeRequests.length,
              itemBuilder: (context, index) {
                final data = activeRequests[index].data()
                as Map<String, dynamic>;
                final status = data['status'] ?? 'open';
                Color statusColor = Colors.orange;
                if (status == 'accepted') statusColor = Colors.green;
                if (status == 'completed') statusColor = Colors.blue;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(16),
                    border:
                    Border.all(color: const Color(0xFF2A2A2A)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF4D4F)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.handyman,
                            color: Color(0xFFFF4D4F), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['serviceType'] ?? '',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15),
                            ),
                            Text(
                              data['description'] ?? '',
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(
                              color: statusColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const Divider(color: Color(0xFF2A2A2A), height: 32),
          ],
        );
      },
    );
  }

  // ══════════════════════════════════════
  // MY APPOINTMENTS (Doctor)
  // ══════════════════════════════════════
  Widget _buildMyAppointments() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('patientId', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final appointments = snapshot.data?.docs ?? [];
        final activeAppointments = appointments.where((a) {
          final status =
              (a.data() as Map<String, dynamic>)['status'] ?? '';
          return status == 'pending' || status == 'confirmed';
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Text(
                'My Appointments',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
            ),
            activeAppointments.isEmpty
                ? Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF2A2A2A)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.calendar_today_outlined,
                      color: Colors.grey, size: 20),
                  SizedBox(width: 12),
                  Text('No appointments yet',
                      style: TextStyle(
                          color: Colors.grey, fontSize: 14)),
                ],
              ),
            )
                : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: activeAppointments.length,
              itemBuilder: (context, index) {
                final data = activeAppointments[index].data()
                as Map<String, dynamic>;
                final status = data['status'] ?? 'pending';
                Color statusColor = Colors.orange;
                if (status == 'confirmed')
                  statusColor = Colors.green;
                if (status == 'cancelled') statusColor = Colors.red;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(16),
                    border:
                    Border.all(color: const Color(0xFF2A2A2A)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF4D4F)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                            Icons.medical_services_rounded,
                            color: Color(0xFFFF4D4F),
                            size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['doctorName'] ?? '',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15),
                            ),
                            Text(
                              '${data['date']} at ${data['time']}',
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(
                              color: statusColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const Divider(color: Color(0xFF2A2A2A), height: 32),
          ],
        );
      },
    );
  }

  // ══════════════════════════════════════
  // INSTANT SERVICES
  // ══════════════════════════════════════
  Widget _buildInstantServices() {
    final services = [
      {'name': 'Electrician', 'price': '₹199', 'icon': Icons.bolt_rounded, 'desc': 'Fan, Switch, Wiring fixes'},
      {'name': 'Plumber', 'price': '₹249', 'icon': Icons.water_drop_rounded, 'desc': 'Leakage, Tap, Pipe repair'},
      {'name': 'Furniture Maker', 'price': '₹399', 'icon': Icons.chair_rounded, 'desc': 'Assembly, Polishing, Repair'},
      {'name': 'Cleaning', 'price': '₹499', 'icon': Icons.cleaning_services_rounded, 'desc': 'Deep home cleaning'},
    ];

    return Column(
      children: [
        // ── My Bookings ──
        _buildMyBookings(),

        // ── Services List ──
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: services.length,
            itemBuilder: (context, index) {
              final service = services[index];
              return FadeSlideAnimation(
                delay: Duration(milliseconds: 100 * index),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF2A2A2A)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF4D4F)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(service['icon'] as IconData,
                            color: const Color(0xFFFF4D4F), size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              service['name'] as String,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              service['desc'] as String,
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            service['price'] as String,
                            style: const TextStyle(
                                color: Color(0xFFFF4D4F),
                                fontSize: 18,
                                fontWeight: FontWeight.w900),
                          ),
                          const Text('starting',
                              style: TextStyle(
                                  color: Colors.grey, fontSize: 10)),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () => _showServiceRequestDialog(
                                service['name'] as String),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF4D4F),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              minimumSize: Size.zero,
                              tapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Book',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════
  // SCHEDULED APPOINTMENTS
  // ══════════════════════════════════════
  Widget _buildScheduledAppointments() {
    return Column(
      children: [
        // ── My Appointments ──
        _buildMyAppointments(),

        // ── Doctors List ──
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('doctors')
                .where('isApproved', isEqualTo: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                      color: Color(0xFFFF4D4F)),
                );
              }
              final doctors = snapshot.data?.docs ?? [];
              if (doctors.isEmpty) {
                return const Center(
                  child: Text('No doctors available',
                      style: TextStyle(color: Colors.grey)),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: doctors.length,
                itemBuilder: (context, index) {
                  final data =
                  doctors[index].data() as Map<String, dynamic>;
                  final doctorId = doctors[index].id;
                  return _buildDoctorCard(data, doctorId);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDoctorCard(Map<String, dynamic> data, String doctorId) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor:
                const Color(0xFFFF4D4F).withValues(alpha: 0.1),
                child: const Icon(Icons.medical_services_rounded,
                    color: Color(0xFFFF4D4F), size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['name'] ?? '',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    Text(data['specialist'] ?? '',
                        style: const TextStyle(
                            color: Color(0xFFFF4D4F),
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('₹${data['consultationFee'] ?? 0}',
                    style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ),
            ],
          ),
          const Divider(color: Color(0xFF2A2A2A), height: 24),
          Row(children: [
            const Icon(Icons.school_outlined, color: Colors.grey, size: 16),
            const SizedBox(width: 6),
            Expanded(
                child: Text(data['qualification'] ?? '',
                    style:
                    const TextStyle(color: Colors.grey, fontSize: 13))),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.work_outline, color: Colors.grey, size: 16),
            const SizedBox(width: 6),
            Text('${data['experience'] ?? 0} years experience',
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.location_on_outlined,
                color: Colors.grey, size: 16),
            const SizedBox(width: 6),
            Expanded(
                child: Text(data['address'] ?? '',
                    style:
                    const TextStyle(color: Colors.grey, fontSize: 13))),
          ]),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _showSlotBookingSheet(data, doctorId),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF4D4F),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Book Appointment',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogField(
      TextEditingController controller,
      String label,
      IconData icon, {
        bool isNumber = false,
        int maxLines = 1,
      }) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Icon(icon, color: const Color(0xFFFF4D4F)),
        filled: true,
        fillColor: const Color(0xFF2A2A2A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildMyRequestTile(String requestId, Map<String, dynamic> data) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('service_requests')
          .doc(requestId)
          .collection('bids')
          .snapshots(),
      builder: (context, snapshot) {
        final bids = snapshot.data?.docs ?? [];
        if (bids.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Waiting for bids...',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(color: Color(0xFF2A2A2A)),
            Text('${bids.length} bid(s) received! 🎉',
                style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
            const SizedBox(height: 8),
            ...bids.map((bid) {
              final bidData = bid.data() as Map<String, dynamic>;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(bidData['providerName'] ?? '',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                          if ((bidData['note'] ?? '').isNotEmpty)
                            Text(bidData['note'],
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ),
                    Text('₹${bidData['amount']}',
                        style: const TextStyle(
                            color: Color(0xFFFF4D4F),
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        await FirebaseFirestore.instance
                            .collection('service_requests')
                            .doc(requestId)
                            .update({
                          'status': 'accepted',
                          'acceptedBidId': bid.id,
                          'acceptedProvider': bidData['providerName'],
                          'finalAmount': bidData['amount'],
                        });
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  '${bidData['providerName']} accepted! ✅'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        minimumSize: Size.zero,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Accept',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Future<void> _showServiceRequestDialog(String serviceType) async {
    final descController = TextEditingController();
    final budgetController = TextEditingController();
    final addressController = TextEditingController();
    final user = FirebaseAuth.instance.currentUser;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Request $serviceType',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                _buildDialogField(descController, 'Describe your problem',
                    Icons.description_outlined,
                    maxLines: 3),
                const SizedBox(height: 16),
                _buildDialogField(budgetController, 'Your Budget (₹)',
                    Icons.currency_rupee,
                    isNumber: true),
                const SizedBox(height: 16),
                _buildDialogField(addressController, 'Your Address',
                    Icons.location_on_outlined),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (descController.text.isEmpty ||
                          budgetController.text.isEmpty) return;
                      final userDoc = await FirebaseFirestore.instance
                          .collection('users')
                          .doc(user?.uid)
                          .get();
                      final customerName =
                          userDoc.data()?['name'] ?? 'Customer';
                      await FirebaseFirestore.instance
                          .collection('service_requests')
                          .add({
                        'customerId': user?.uid,
                        'customerName': customerName,
                        'serviceType': serviceType,
                        'description': descController.text.trim(),
                        'customerBudget': int.tryParse(
                            budgetController.text.trim()) ??
                            0,
                        'address': addressController.text.trim(),
                        'status': 'open',
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Request sent! Providers will bid soon.'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF4D4F),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Send Request',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 16),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('service_requests')
                      .where('customerId', isEqualTo: user?.uid)
                      .where('serviceType', isEqualTo: serviceType)
                      .where('status', isEqualTo: 'open')
                      .snapshots(),
                  builder: (context, snapshot) {
                    final requests = snapshot.data?.docs ?? [];
                    if (requests.isEmpty) return const SizedBox.shrink();
                    return Column(
                      children: requests.map((req) {
                        return _buildMyRequestTile(req.id,
                            req.data() as Map<String, dynamic>);
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showSlotBookingSheet(
      Map<String, dynamic> doctorData, String doctorId) async {
    final user = FirebaseAuth.instance.currentUser;
    String? selectedDay;
    String? selectedTime;
    final reasonController = TextEditingController();
    final slots = Map<String, dynamic>.from(doctorData['slots'] ?? {});
    final bookedSlots =
    List<String>.from(doctorData['bookedSlots'] ?? []);
    final days = [
      'monday', 'tuesday', 'wednesday',
      'thursday', 'friday', 'saturday', 'sunday'
    ];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24, right: 24, top: 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Book - ${doctorData['name']}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                const Text('Select Day',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: days.map((day) {
                    final daySlots =
                    List<String>.from(slots[day] ?? []);
                    final hasSlots = daySlots.isNotEmpty;
                    final isSelected = selectedDay == day;
                    return GestureDetector(
                      onTap: hasSlots
                          ? () => setModalState(() {
                        selectedDay = day;
                        selectedTime = null;
                      })
                          : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFFF4D4F)
                              .withValues(alpha: 0.2)
                              : hasSlots
                              ? const Color(0xFF2A2A2A)
                              : const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFFFF4D4F)
                                : hasSlots
                                ? const Color(0xFF333333)
                                : const Color(0xFF222222),
                          ),
                        ),
                        child: Text(
                          day[0].toUpperCase() + day.substring(1, 3),
                          style: TextStyle(
                            color: isSelected
                                ? const Color(0xFFFF4D4F)
                                : hasSlots
                                ? Colors.white
                                : Colors.grey[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                if (selectedDay != null) ...[
                  const Text('Select Time',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List<String>.from(
                        slots[selectedDay] ?? [])
                        .map((time) {
                      final slotKey = '${selectedDay}_$time';
                      final isBooked = bookedSlots.contains(slotKey);
                      final isSelected = selectedTime == time;
                      return GestureDetector(
                        onTap: isBooked
                            ? null
                            : () => setModalState(
                                () => selectedTime = time),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: isBooked
                                ? const Color(0xFF1A1A1A)
                                : isSelected
                                ? Colors.green.withValues(alpha: 0.2)
                                : const Color(0xFF2A2A2A),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isBooked
                                  ? const Color(0xFF222222)
                                  : isSelected
                                  ? Colors.green
                                  : const Color(0xFF333333),
                            ),
                          ),
                          child: Text(
                            isBooked ? '$time ✗' : time,
                            style: TextStyle(
                              color: isBooked
                                  ? Colors.grey[700]
                                  : isSelected
                                  ? Colors.green
                                  : Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                ],
                TextField(
                  controller: reasonController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Reason for visit (Optional)',
                    labelStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(Icons.note_outlined,
                        color: Color(0xFFFF4D4F)),
                    filled: true,
                    fillColor: const Color(0xFF2A2A2A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: selectedDay == null || selectedTime == null
                        ? null
                        : () async {
                      final userDoc = await FirebaseFirestore
                          .instance
                          .collection('users')
                          .doc(user?.uid)
                          .get();
                      final patientName =
                          userDoc.data()?['name'] ?? 'Patient';
                      await FirebaseFirestore.instance
                          .collection('appointments')
                          .add({
                        'doctorId': doctorId,
                        'doctorName': doctorData['name'],
                        'patientId': user?.uid,
                        'patientName': patientName,
                        'date': selectedDay,
                        'time': selectedTime,
                        'reason': reasonController.text.trim(),
                        'status': 'pending',
                        'consultationFee':
                        doctorData['consultationFee'],
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                      final slotKey =
                          '${selectedDay}_$selectedTime';
                      final updatedBookedSlots = [
                        ...bookedSlots,
                        slotKey
                      ];
                      await FirebaseFirestore.instance
                          .collection('doctors')
                          .doc(doctorId)
                          .update(
                          {'bookedSlots': updatedBookedSlots});
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                            Text('Appointment booked! ✅'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF4D4F),
                      disabledBackgroundColor: const Color(0xFF333333),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Confirm Appointment',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
