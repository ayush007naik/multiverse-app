import 'package:flutter/material.dart';
import 'verification_form_screen.dart';

class RoleSelectionScreen extends StatefulWidget {
  final String uid;
  final String name;
  final String email;
  final String phone;

  const RoleSelectionScreen({
    super.key,
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
  });

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String? _selectedRole;

  final List<Map<String, dynamic>> _roles = [
    {'id': 'doctor', 'name': 'Doctor', 'icon': Icons.medical_services_outlined},
    {'id': 'plumber', 'name': 'Plumber', 'icon': Icons.plumbing_outlined},
    {
      'id': 'electrician',
      'name': 'Electrician',
      'icon': Icons.electrical_services_outlined,
    },
    {'id': 'carpenter', 'name': 'Carpenter', 'icon': Icons.handyman_outlined},
    {
      'id': 'cleaner',
      'name': 'Cleaner',
      'icon': Icons.cleaning_services_outlined,
    },
    {
      'id': 'theatre_owner',
      'name': 'Theatre Owner',
      'icon': Icons.movie_filter_outlined,
    },
    {
      'id': 'shop_vendor',
      'name': 'Shop Vendor',
      'icon': Icons.storefront_outlined,
    },
    {
      'id': 'delivery_rider',
      'name': 'Delivery Rider',
      'icon': Icons.delivery_dining_outlined,
    },
    {
      'id': 'real_estate',
      'name': 'Real Estate',
      'icon': Icons.real_estate_agent_outlined,
    },
  ];

  void _onRoleSelected(String roleId) {
    setState(() => _selectedRole = roleId);
  }

  void _onContinue() {
    if (_selectedRole != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VerificationFormScreen(
            uid: widget.uid,
            role: _selectedRole!,
            name: widget.name,
            email: widget.email,
            phone: widget.phone,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Select Your Role',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'What do you do?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Select the category that best describes your service',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: _roles.length,
                  itemBuilder: (context, index) {
                    final role = _roles[index];
                    final isSelected = _selectedRole == role['id'];
                    return GestureDetector(
                      onTap: () => _onRoleSelected(role['id']),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFFF4D4F)
                              : const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFFFF4D4F)
                                : const Color(0xFF2A2A2A),
                            width: 2,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              role['icon'],
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFFFF4D4F),
                              size: 32,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              role['name'],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.grey,
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _selectedRole != null ? _onContinue : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF4D4F),
                    disabledBackgroundColor: Colors.grey.withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
