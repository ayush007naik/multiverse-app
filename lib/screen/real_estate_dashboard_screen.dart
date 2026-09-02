import 'package:url_launcher/url_launcher.dart';
import 'sell_property_category_screen.dart';
import 'property_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:db_compat/db_compat.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/property_model.dart';
import '../services/property_service.dart';

class RealEstateDashboardScreen extends StatefulWidget {
  final bool isAdmin;
  const RealEstateDashboardScreen({super.key, this.isAdmin = false});

  @override
  State<RealEstateDashboardScreen> createState() =>
      _RealEstateDashboardScreenState();
}

class _RealEstateDashboardScreenState extends State<RealEstateDashboardScreen>
    with SingleTickerProviderStateMixin {
  bool _isAdminLocal = false;
  late TabController _tabController;
  final PropertyService _service = PropertyService();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  static const _bg = Color(0xFF0A0A0B);
  static const _orange = Color(0xFFFF8C00);
  static const _purple = Color(0xFF8B5CFF);

  @override
  void initState() {
    super.initState();
    _isAdminLocal = widget.isAdmin;
    _checkAdminRole();
    _tabController = TabController(length: 4, vsync: this);
  }

  void _checkAdminRole() async {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    if (email == 'admin@multiverse.com' || email == 'ayu007n@gmail.com') {
      if (mounted) setState(() => _isAdminLocal = true);
      return;
    }
    try {
      final adminDoc = await FirebaseFirestore.instance
          .collection("dashboard_admins")
          .doc(email)
          .get();
      if (adminDoc.exists) {
        if (mounted) setState(() => _isAdminLocal = true);
        return;
      }
    } catch (_) {}
    final userDoc = await FirebaseFirestore.instance
        .collection("users")
        .doc(_currentUserId)
        .get();
    if (userDoc.exists && userDoc.data()?["role"] == "admin") {
      if (mounted) setState(() => _isAdminLocal = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isAdminLocal ? 'RE ADMIN CONSOLE' : 'PROPERTY DASHBOARD',
          style: GoogleFonts.orbitron(
            color: _orange,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _orange,
          labelColor: _orange,
          unselectedLabelColor: Colors.white38,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Properties'),
            Tab(text: 'Leads'),
            Tab(text: 'Visits'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          Column(children: [Expanded(child: _buildOverviewTab())]),
          Column(children: [Expanded(child: _buildPropertiesTab())]),
          Column(children: [Expanded(child: _buildLeadsTab())]),
          Column(children: [Expanded(child: _buildVisitsTab())]),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SellPropertyCategoryScreen()),
        ),
        backgroundColor: _orange,
        icon: const Icon(Icons.add_rounded, color: Colors.black),
        label: Text(
          'ADD PROPERTY',
          style: GoogleFonts.orbitron(
            color: Colors.black,
            fontWeight: FontWeight.w900,
            fontSize: 12,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsGrid(),
          const SizedBox(height: 35),
          Text(
            'QUICK ACTIONS',
            style: GoogleFonts.orbitron(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: _QuickActionCard(
                  title: 'ADD PROPERTY',
                  icon: Icons.add_box_rounded,
                  color: _orange,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SellPropertyCategoryScreen(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _QuickActionCard(
                  title: 'SCHEDULE VISIT',
                  icon: Icons.calendar_month_rounded,
                  color: Colors.cyanAccent,
                  onTap: () => _tabController.animateTo(3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 35),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'RECENT ENQUIRIES',
                style: GoogleFonts.orbitron(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              TextButton(
                onPressed: () => _tabController.animateTo(2),
                child: const Text(
                  'VIEW ALL',
                  style: TextStyle(
                    color: _orange,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          _buildRecentLeadsList(),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return StreamBuilder<List<Property>>(
      stream: _isAdminLocal
          ? _service.streamAllProperties()
          : _service.streamPropertiesByBroker(_currentUserId),
      builder: (context, propSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('property_leads')
              .snapshots(),
          builder: (context, leadSnap) {
            return StreamBuilder<QuerySnapshot>(
              stream: _isAdminLocal
                  ? FirebaseFirestore.instance
                        .collection('site_visits')
                        .snapshots()
                  : FirebaseFirestore.instance
                        .collection('site_visits')
                        .where('sellerId', isEqualTo: _currentUserId)
                        .snapshots(),
              builder: (context, visitSnap) {
                final props = propSnap.data ?? [];
                var leads = leadSnap.data?.docs ?? [];
                var visits = visitSnap.data?.docs ?? [];

                if (!_isAdminLocal) {
                  leads = leads.where((doc) {
                    final data = doc.data();
                    return data['sellerId'] == _currentUserId ||
                        data['brokerId'] == _currentUserId;
                  }).toList();
                }

                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                  childAspectRatio: 1.6,
                  children: [
                    _StatCard(
                      title: 'Active Props',
                      value: '${props.length}',
                      icon: Icons.home_work_rounded,
                      color: _orange,
                    ),
                    _StatCard(
                      title: 'Total Leads',
                      value: '${leads.length}',
                      icon: Icons.bolt_rounded,
                      color: _purple,
                    ),
                    _StatCard(
                      title: 'Site Visits',
                      value: '${visits.length}',
                      icon: Icons.calendar_today_rounded,
                      color: Colors.cyanAccent,
                    ),
                    _StatCard(
                      title: 'New Leads',
                      value:
                          '${leads.where((d) {
                            final data = d.data() as Map<String, dynamic>?;
                            return data != null && data['status'] == 'new';
                          }).length}',
                      icon: Icons.new_releases_rounded,
                      color: Colors.greenAccent,
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildRecentLeadsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('property_leads')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text(
            "Error loading leads",
            style: TextStyle(color: Colors.red[300], fontSize: 10),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: _orange));
        }
        var docs = (snapshot.data?.docs ?? []).toList();

        if (!_isAdminLocal) {
          docs = docs.where((doc) {
            final data = doc.data();
            return data['sellerId'] == _currentUserId ||
                data['brokerId'] == _currentUserId;
          }).toList();
        }

        docs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>?;
          final bData = b.data() as Map<String, dynamic>?;
          final aTime =
              (aData?["createdAt"] as Timestamp?)?.toDate() ??
              (aData?["timestamp"] as Timestamp?)?.toDate() ??
              DateTime(2020);
          final bTime =
              (bData?["createdAt"] as Timestamp?)?.toDate() ??
              (bData?["timestamp"] as Timestamp?)?.toDate() ??
              DateTime(2020);
          return bTime.compareTo(aTime);
        });
        if (docs.isEmpty) {
          return Container(
            height: 100,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Center(
              child: Text(
                'No enquiries yet',
                style: TextStyle(color: Colors.white24),
              ),
            ),
          );
        }

        // Limit to top 5
        final recentDocs = docs.take(5).toList();

        return Column(
          children: recentDocs.map((doc) {
            final lead = doc.data();
            return _LeadCard(lead: lead);
          }).toList(),
        );
      },
    );
  }

  Widget _buildPropertiesTab() {
    return StreamBuilder<List<Property>>(
      stream: _isAdminLocal
          ? _service.streamAllProperties()
          : _service.streamPropertiesByBroker(_currentUserId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                "Error: ${snapshot.error}",
                style: const TextStyle(color: Colors.red, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _orange));
        }
        final properties = snapshot.data ?? [];
        if (properties.isEmpty) {
          return _buildEmptyState(
            'No properties found',
            Icons.home_work_outlined,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(15),
          itemCount: properties.length,
          itemBuilder: (context, index) {
            final p = properties[index];
            return _DashboardPropertyCard(property: p, isAdmin: _isAdminLocal);
          },
        );
      },
    );
  }

  Widget _buildLeadsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('property_leads')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              "Error: ${snapshot.error}",
              style: const TextStyle(color: Colors.red),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: _orange));
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return _buildEmptyState(
            'No Leads Found (Collection: property_leads)',
            Icons.person_search_rounded,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(15),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final lead = docs[index].data();
            return _LeadCard(lead: lead);
          },
        );
      },
    );
  }

  Widget _buildVisitsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _isAdminLocal
          ? FirebaseFirestore.instance.collection('site_visits').snapshots()
          : FirebaseFirestore.instance
                .collection('site_visits')
                .where('sellerId', isEqualTo: _currentUserId)
                .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                "Error: ${snapshot.error}",
                style: const TextStyle(color: Colors.red, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _orange));
        }
        var docs = (snapshot.data?.docs ?? []).toList();

        docs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>?;
          final bData = b.data() as Map<String, dynamic>?;
          final aTime =
              (aData?["createdAt"] as Timestamp?)?.toDate() ??
              (aData?["timestamp"] as Timestamp?)?.toDate() ??
              DateTime(2020);
          final bTime =
              (bData?["createdAt"] as Timestamp?)?.toDate() ??
              (bData?["timestamp"] as Timestamp?)?.toDate() ??
              DateTime(2020);
          return bTime.compareTo(aTime);
        });
        if (docs.isEmpty) {
          return _buildEmptyState(
            'No site visits scheduled',
            Icons.calendar_month_rounded,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(15),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final visit = docs[index].data();
            return _VisitCard(visit: visit);
          },
        );
      },
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 60, color: Colors.white10),
          const SizedBox(height: 15),
          Text(
            message,
            style: GoogleFonts.poppins(color: Colors.white38, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _DashboardPropertyCard extends StatelessWidget {
  final Property property;
  final bool isAdmin;
  const _DashboardPropertyCard({required this.property, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: CachedNetworkImage(
              imageUrl: property.images.isNotEmpty ? property.images.first : '',
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              placeholder: (context, url) =>
                  Container(color: Colors.white10, width: 80, height: 80),
              errorWidget: (context, url, error) =>
                  Container(color: Colors.white10, width: 80, height: 80),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  property.title,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  property.price,
                  style: const TextStyle(
                    color: Color(0xFFFF8C00),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 5),
                _StatusBadge(status: property.status),
              ],
            ),
          ),
          if (isAdmin)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white70),
              color: const Color(0xFF1A1A1B),
              onSelected: (val) {
                if (val == 'approve') {
                  PropertyService().updateProperty(property.id, {
                    'status': 'approved',
                    'isActive': true,
                  });
                } else if (val == 'reject') {
                  PropertyService().updateProperty(property.id, {
                    'status': 'rejected',
                  });
                } else if (val == 'edit') {
                  _showEditPropertySheet(context, property);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Text('Edit', style: TextStyle(color: Colors.white)),
                ),
                const PopupMenuItem(
                  value: 'approve',
                  child: Text('Approve', style: TextStyle(color: Colors.green)),
                ),
                const PopupMenuItem(
                  value: 'reject',
                  child: Text('Reject', style: TextStyle(color: Colors.red)),
                ),
              ],
            )
          else
            IconButton(
              icon: const Icon(Icons.edit_note_rounded, color: Colors.white70),
              onPressed: () => _showEditPropertySheet(context, property),
            ),
        ],
      ),
    );
  }

  void _showEditPropertySheet(BuildContext context, Property property) {
    final title = TextEditingController(text: property.title);
    final price = TextEditingController(
      text: property.price.replaceAll(RegExp(r'[^0-9.]'), ''),
    );
    final desc = TextEditingController(text: property.description);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1C),
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'EDIT PROPERTY',
              style: GoogleFonts.orbitron(
                color: const Color(0xFFFF8C00),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: title,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Property Title'),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: price,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Price (Numbers only)'),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: desc,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Description'),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  PropertyService().updateProperty(property.id, {
                    'title': title.text,
                    'price': double.tryParse(price.text) ?? 0,
                    'description': desc.text,
                    'updatedAt': FieldValue.serverTimestamp(),
                  });
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF8C00),
                ),
                child: const Text(
                  'Update Property',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white38),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white10),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFFF8C00)),
      ),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
    );
  }
}

class _LeadCard extends StatelessWidget {
  final Map<String, dynamic> lead;
  const _LeadCard({required this.lead});

  void _showLeadDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 25),
              Text(
                'LEAD ENQUIRY DETAILS',
                style: GoogleFonts.orbitron(
                  color: const Color(0xFFFF8C00),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 25),

              _detailSection('BUYER DETAILS', [
                _detailRow(Icons.person, 'Name', lead['buyerName'] ?? 'N/A'),
                _detailRow(Icons.phone, 'Phone', lead['buyerPhone'] ?? 'N/A'),
                _detailRow(Icons.email, 'Email', lead['buyerEmail'] ?? 'N/A'),
                _detailRow(
                  Icons.bolt,
                  'Lead Type',
                  (lead['leadType'] ?? 'general').toString().toUpperCase(),
                ),
              ]),

              const Divider(color: Colors.white10, height: 40),

              _detailSection('PROPERTY DETAILS', [
                _detailRow(
                  Icons.home_work,
                  'Title',
                  lead['propertyTitle'] ?? 'N/A',
                ),
                _detailRow(
                  Icons.payments,
                  'Price',
                  lead['propertyPrice']?.toString() ?? 'N/A',
                ),
                _detailRow(
                  Icons.fingerprint,
                  'Property ID',
                  lead['propertyId'] ?? 'N/A',
                ),
              ]),

              const Divider(color: Colors.white10, height: 40),

              _detailSection('SELLER & ASSIGNMENT', [
                FutureBuilder<Property?>(
                  future: PropertyService().getPropertyById(
                    lead['propertyId'] ?? '',
                  ),
                  builder: (context, snapshot) {
                    final prop = snapshot.data;
                    final sName =
                        lead['sellerName'] ??
                        prop?.ownerName ??
                        prop?.brokerName ??
                        'N/A';
                    final sPhone =
                        lead['sellerPhone'] ??
                        prop?.ownerPhone ??
                        prop?.brokerPhone ??
                        'N/A';

                    return Column(
                      children: [
                        _detailRow(Icons.person_pin, 'Seller Name', sName),
                        _detailRow(
                          Icons.phone_android,
                          'Seller Contact',
                          sPhone,
                        ),
                      ],
                    );
                  },
                ),
                _detailRow(
                  Icons.admin_panel_settings,
                  'Seller ID',
                  lead['sellerId'] ?? 'N/A',
                ),
                _detailRow(
                  Icons.handshake,
                  'Broker ID',
                  lead['brokerId'] ?? 'N/A',
                ),
              ]),

              const SizedBox(height: 30),
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.call,
                      label: 'Call',
                      color: Colors.green,
                      onTap: () => _launch('tel:${lead['buyerPhone']}'),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.message,
                      label: 'WhatsApp',
                      color: const Color(0xFF25D366),
                      onTap: () =>
                          _launch('https://wa.me/91${lead['buyerPhone']}'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.orbitron(
            color: Colors.white38,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 15),
        ...children,
      ],
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFFFF8C00)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showLeadDetails(context),
      borderRadius: BorderRadius.circular(15),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  lead['buyerName'] ?? 'Unknown Buyer',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CFF).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    (lead['leadType'] ?? 'general').toString().toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFF8B5CFF),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Interested in: ${lead['propertyTitle']}',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _ActionButton(
                  icon: Icons.call,
                  label: 'Call',
                  color: Colors.green,
                  onTap: () => _launch('tel:${lead['buyerPhone']}'),
                ),
                const SizedBox(width: 10),
                _ActionButton(
                  icon: Icons.message,
                  label: 'WhatsApp',
                  color: const Color(0xFF25D366),
                  onTap: () => _launch('https://wa.me/91${lead['buyerPhone']}'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VisitCard extends StatelessWidget {
  final Map<String, dynamic> visit;
  const _VisitCard({required this.visit});

  @override
  Widget build(BuildContext context) {
    final DateTime? date = (visit['date'] as Timestamp?)?.toDate();
    return GestureDetector(
      onTap: () {
        if (visit['propertyId'] != null) {
          PropertyService().getPropertyById(visit['propertyId']).then((prop) {
            if (prop != null && context.mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PropertyDetailScreen(property: prop),
                ),
              );
            }
          });
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white10),
        ),
        child: FutureBuilder<Property?>(
          future: PropertyService().getPropertyById(visit['propertyId'] ?? ''),
          builder: (context, snapshot) {
            final prop = snapshot.data;
            final imageUrl = prop?.images.isNotEmpty == true
                ? prop!.images.first
                : '';
            final buyerPhone = visit['buyerPhone']?.toString() ?? '';

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      if (imageUrl.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: CachedNetworkImage(
                            imageUrl: imageUrl,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFFF8C00,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Text(
                                date != null ? '${date.day}' : '??',
                                style: const TextStyle(
                                  color: Color(0xFFFF8C00),
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                date != null ? _getMonth(date.month) : 'MMM',
                                style: const TextStyle(
                                  color: Color(0xFFFF8C00),
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              visit['buyerName'] ?? 'Visitor',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Row(
                              children: [
                                const Icon(
                                  Icons.access_time,
                                  size: 12,
                                  color: Colors.white38,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${visit['time'] ?? 'N/A'} - ${date != null ? "${date.day}/${date.month}" : ""}',
                                  style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              visit['propertyTitle'] ?? 'Property',
                              style: const TextStyle(
                                color: Color(0xFFFF8C00),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (prop != null) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  if (prop.beds != '0')
                                    _miniSpec(Icons.bed, prop.beds),
                                  if (prop.baths != '0')
                                    _miniSpec(Icons.bathtub, prop.baths),
                                  _miniSpec(Icons.square_foot, prop.area),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      _StatusBadge(status: visit['status'] ?? 'pending'),
                    ],
                  ),
                ),
                if (buyerPhone.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(15),
                      ),
                    ),
                    child: Row(
                      children: [
                        _ActionButton(
                          icon: Icons.call,
                          label: 'Call',
                          color: Colors.green,
                          onTap: () => _launch('tel:$buyerPhone'),
                        ),
                        const SizedBox(width: 10),
                        _ActionButton(
                          icon: Icons.message,
                          label: 'WhatsApp',
                          color: const Color(0xFF25D366),
                          onTap: () => _launch('https://wa.me/91$buyerPhone'),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _miniSpec(IconData icon, String value) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(
        children: [
          Icon(icon, size: 10, color: Colors.white24),
          const SizedBox(width: 2),
          Text(
            value,
            style: const TextStyle(color: Colors.white24, fontSize: 9),
          ),
        ],
      ),
    );
  }

  String _getMonth(int m) {
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return months[m - 1];
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status.toLowerCase()) {
      case 'approved':
      case 'available':
      case 'completed':
        color = Colors.green;
        break;
      case 'pending':
      case 'pending_approval':
        color = Colors.orange;
        break;
      case 'rejected':
      case 'cancelled':
        color = Colors.red;
        break;
      default:
        color = Colors.blue;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 10),
            Text(
              title,
              style: GoogleFonts.orbitron(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _launch(String value) async {
  final uri = Uri.parse(value);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
