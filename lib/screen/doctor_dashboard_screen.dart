import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'login_screen.dart';

class DoctorDashboardScreen extends StatefulWidget {
  const DoctorDashboardScreen({super.key});

  @override
  State<DoctorDashboardScreen> createState() => _DoctorDashboardScreenState();
}

class _DoctorDashboardScreenState extends State<DoctorDashboardScreen>
    with SingleTickerProviderStateMixin {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  late TabController _tabController;
  Map<String, dynamic>? _doctorData;

  final List<String> _days = [
    'monday', 'tuesday', 'wednesday',
    'thursday', 'friday', 'saturday', 'sunday'
  ];

  final List<String> _allTimeSlots = [
    '09:00', '10:00', '11:00', '12:00',
    '13:00', '14:00', '15:00', '16:00',
    '17:00', '18:00', '19:00',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadDoctorData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDoctorData() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final doc = await _firestore.collection('doctors').doc(uid).get();
    if (mounted) {
      setState(() => _doctorData = doc.data());
    }
  }

  Future<void> _toggleSlot(String day, String time) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final slots = Map<String, dynamic>.from(_doctorData?['slots'] ?? {});
    final daySlots = List<String>.from(slots[day] ?? []);

    if (daySlots.contains(time)) {
      daySlots.remove(time);
    } else {
      daySlots.add(time);
      daySlots.sort();
    }

    slots[day] = daySlots;

    await _firestore.collection('doctors').doc(uid).update({'slots': slots});
    setState(() => _doctorData?['slots'] = slots);

    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _doctorData?['name'] ?? 'Doctor',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              _doctorData?['specialist'] ?? '',
              style: const TextStyle(color: Color(0xFFFF4D4F), fontSize: 13),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFF4D4F),
          labelColor: const Color(0xFFFF4D4F),
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Appointments'),
            Tab(text: 'Manage Slots'),
            Tab(text: 'Profile'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAppointments(),
          _buildManageSlots(),
          _buildProfile(),
        ],
      ),
    );
  }

  // ── APPOINTMENTS ──
  Widget _buildAppointments() {
    final uid = _auth.currentUser?.uid;
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('appointments')
          .where('doctorId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFFF4D4F)));
        }

        final appointments = snapshot.data?.docs ?? [];

        if (appointments.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_today_outlined, color: Colors.grey[700], size: 64),
                const SizedBox(height: 16),
                const Text('No appointments yet', style: TextStyle(color: Colors.grey, fontSize: 18)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: appointments.length,
          itemBuilder: (context, index) {
            final data = appointments[index].data() as Map<String, dynamic>;
            final appointmentId = appointments[index].id;
            return _buildAppointmentCard(data, appointmentId);
          },
        );
      },
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> data, String appointmentId) {
    final status = data['status'] ?? 'pending';
    Color statusColor = Colors.orange;
    if (status == 'confirmed') statusColor = Colors.green;
    if (status == 'cancelled') statusColor = Colors.red;
    if (status == 'completed') statusColor = Colors.blue;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFFF4D4F).withValues(alpha: 0.1),
                child: const Icon(Icons.person, color: Color(0xFFFF4D4F)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['patientName'] ?? 'Patient',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      '${data['date']} at ${data['time']}',
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),

          if (data['reason']?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            const Divider(color: Color(0xFF2A2A2A)),
            const SizedBox(height: 8),
            Text(
              'Reason: ${data['reason']}',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],

          if (status == 'pending') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _updateAppointmentStatus(appointmentId, 'confirmed'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Confirm', style: TextStyle(color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _updateAppointmentStatus(appointmentId, 'cancelled'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Cancel', style: TextStyle(color: Colors.red)),
                  ),
                ),
              ],
            ),
          ],

          if (status == 'confirmed') ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _updateAppointmentStatus(appointmentId, 'completed'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Mark Completed', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _updateAppointmentStatus(String appointmentId, String status) async {
    await _firestore.collection('appointments').doc(appointmentId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // If cancelled - unlock the slot
    if (status == 'cancelled') {
      final doc = await _firestore.collection('appointments').doc(appointmentId).get();
      final data = doc.data();
      if (data != null) {
        final uid = _auth.currentUser?.uid;
        final bookedSlots = List<String>.from(_doctorData?['bookedSlots'] ?? []);
        final slotKey = '${data['date']}_${data['time']}';
        bookedSlots.remove(slotKey);
        await _firestore.collection('doctors').doc(uid).update({'bookedSlots': bookedSlots});
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Appointment $status!'),
          backgroundColor: status == 'confirmed' ? Colors.green : status == 'cancelled' ? Colors.red : Colors.blue,
        ),
      );
    }
  }

  // ── MANAGE SLOTS ──
  Widget _buildManageSlots() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _days.length,
      itemBuilder: (context, index) {
        final day = _days[index];
        final slots = Map<String, dynamic>.from(_doctorData?['slots'] ?? {});
        final availableSlots = List<String>.from(slots[day] ?? []);

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                day[0].toUpperCase() + day.substring(1),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _allTimeSlots.map((time) {
                  final isAvailable = availableSlots.contains(time);
                  return GestureDetector(
                    onTap: () => _toggleSlot(day, time),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isAvailable
                            ? Colors.green.withValues(alpha: 0.2)
                            : const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isAvailable ? Colors.green : const Color(0xFF333333),
                        ),
                      ),
                      child: Text(
                        time,
                        style: TextStyle(
                          color: isAvailable ? Colors.green : Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── PROFILE ──
  Widget _buildProfile() {
    if (_doctorData == null) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFFF4D4F)));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Avatar
          CircleAvatar(
            radius: 50,
            backgroundColor: const Color(0xFFFF4D4F).withValues(alpha: 0.1),
            child: const Icon(Icons.medical_services, color: Color(0xFFFF4D4F), size: 50),
          ),
          const SizedBox(height: 16),
          Text(
            _doctorData?['name'] ?? '',
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          Text(
            _doctorData?['specialist'] ?? '',
            style: const TextStyle(color: Color(0xFFFF4D4F), fontSize: 15),
          ),
          const SizedBox(height: 24),

          _buildProfileTile(Icons.school_outlined, 'Qualification', _doctorData?['qualification'] ?? ''),
          _buildProfileTile(Icons.work_outline, 'Experience', '${_doctorData?['experience'] ?? 0} years'),
          _buildProfileTile(Icons.location_on_outlined, 'Address', _doctorData?['address'] ?? ''),
          _buildProfileTile(Icons.phone_outlined, 'Phone', _doctorData?['phone'] ?? ''),
          _buildProfileTile(Icons.currency_rupee, 'Consultation Fee', '₹${_doctorData?['consultationFee'] ?? 0}'),

          const SizedBox(height: 24),

          // Logout
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                  );
                }
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFFF4D4F)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.logout, color: Color(0xFFFF4D4F)),
              label: const Text('Logout', style: TextStyle(color: Color(0xFFFF4D4F), fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTile(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFFF4D4F), size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}
