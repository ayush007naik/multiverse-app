import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_flow_service.dart';
import 'login_screen.dart';

class RoleBasedSignupScreen extends StatefulWidget {
  const RoleBasedSignupScreen({super.key});

  @override
  State<RoleBasedSignupScreen> createState() => _RoleBasedSignupScreenState();
}

class _RoleBasedSignupScreenState extends State<RoleBasedSignupScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Controllers for Customer
  final _customerNameController = TextEditingController();
  final _customerEmailController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _customerPasswordController = TextEditingController();
  
  // Controllers for Vendor
  final _vendorNameController = TextEditingController();
  final _vendorShopNameController = TextEditingController();
  final _vendorEmailController = TextEditingController();
  final _vendorPhoneController = TextEditingController();
  final _vendorGSTController = TextEditingController();
  final _vendorAddressController = TextEditingController();
  final _vendorPasswordController = TextEditingController();
  String _vendorCategory = 'Restaurant';
  
  // Controllers for Rider
  final _riderNameController = TextEditingController();
  final _riderPhoneController = TextEditingController();
  final _riderEmailController = TextEditingController();
  final _riderVehicleNumberController = TextEditingController();
  final _riderLicenseNumberController = TextEditingController();
  final _riderPasswordController = TextEditingController();
  String _riderVehicleType = '2-wheeler';
  
  bool _isLoading = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthFlowService _authFlowService = AuthFlowService();

  final _spNameController = TextEditingController();
  final _spEmailController = TextEditingController();
  final _spPhoneController = TextEditingController();
  final _spPasswordController = TextEditingController();
  String _spServiceType = 'Plumber';

  final List<String> _serviceTypes = [
    'Plumber', 'Electrician', 'Doctor',
    'Carpenter', 'Cleaner', 'Painter',
    'AC Mechanic', 'Other'
  ];

  final List<String> _vendorCategories = [
    'Restaurant',
    'Grocery',
    'Fashion',
    'Electronics',
    'Pharmacy',
    'Salon',
    'Fitness',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _customerNameController.dispose();
    _customerEmailController.dispose();
    _customerPhoneController.dispose();
    _customerPasswordController.dispose();
    _vendorNameController.dispose();
    _vendorShopNameController.dispose();
    _vendorEmailController.dispose();
    _vendorPhoneController.dispose();
    _vendorGSTController.dispose();
    _vendorAddressController.dispose();
    _vendorPasswordController.dispose();
    _riderNameController.dispose();
    _riderPhoneController.dispose();
    _riderEmailController.dispose();
    _riderVehicleNumberController.dispose();
    _riderLicenseNumberController.dispose();
    _riderPasswordController.dispose();
    super.dispose();
    _spNameController.dispose();
    _spEmailController.dispose();
    _spPhoneController.dispose();
    _spPasswordController.dispose();
  }

   // ========================================
   // CUSTOMER SIGNUP
   // ========================================
   Future<void> _signupCustomer() async {
     final name = _customerNameController.text.trim();
     final email = _customerEmailController.text.trim();
     final phone = _customerPhoneController.text.trim();
     final password = _customerPasswordController.text.trim();

     if (name.isEmpty) { _showError('Please enter your name'); return; }
     if (email.isEmpty || !email.contains('@')) { _showError('Please enter valid email'); return; }
     if (phone.isEmpty || phone.length < 10) { _showError('Please enter valid phone'); return; }
     if (password.isEmpty || password.length < 6) { _showError('Password must be 6+ chars'); return; }

     setState(() => _isLoading = true);

     try {
       final userCredential = await _auth.createUserWithEmailAndPassword(
         email: email,
         password: password,
       );
       final uid = userCredential.user!.uid;

       await _firestore.collection('users').doc(uid).set({
         'uid': uid,
         'name': name,
         'email': email,
         'phone': phone,
         'role': 'customer',
         'createdAt': FieldValue.serverTimestamp(),
         'updatedAt': FieldValue.serverTimestamp(),
         'isActive': true,
         'isBlocked': false,
       });

       if (!mounted) return;
       _showSuccess('Customer account created!');

       Navigator.of(context).pushAndRemoveUntil(
         MaterialPageRoute(builder: (_) => const LoginScreen()),
         (route) => false,
       );
     } on FirebaseAuthException catch (e) {
       String message = 'Signup failed';
       if (e.code == 'email-already-in-use') {
         message = 'Email already registered';
       } else if (e.code == 'weak-password') {
         message = 'Password is too weak';
       }
       _showError(message);
     } catch (e) {
       _showError('Error: ${e.toString()}');
     } finally {
       if (mounted) setState(() => _isLoading = false);
     }
   }

   // ========================================
   // SERVICE PROVIDER SIGNUP
   // ========================================
   Future<void> _signupServiceProvider() async {
    final name = _spNameController.text.trim();
    final email = _spEmailController.text.trim();
    final phone = _spPhoneController.text.trim();
    final password = _spPasswordController.text.trim();

    if (name.isEmpty) { _showError('Please enter your name'); return; }
    if (email.isEmpty || !email.contains('@')) { _showError('Please enter valid email'); return; }
    if (phone.isEmpty || phone.length < 10) { _showError('Please enter valid phone'); return; }
    if (password.isEmpty || password.length < 6) { _showError('Password must be 6+ chars'); return; }

    setState(() => _isLoading = true);

    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email, password: password,
      );
      final uid = userCredential.user!.uid;

      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'name': name,
        'email': email,
        'phone': phone,
        'role': _spServiceType.toLowerCase(),
        'serviceType': _spServiceType,
        'isAvailable': true,
        'rating': 0.0,
        'totalJobs': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'isBlocked': false,
        'isApproved': false, // Admin approval needed
      });

      // Service providers collection mein bhi save karo
      await _firestore.collection('service_providers').doc(uid).set({
        'uid': uid,
        'name': name,
        'phone': phone,
        'serviceType': _spServiceType,
        'isAvailable': true,
        'rating': 0.0,
        'totalJobs': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _showSuccess('$_spServiceType account created! Waiting for approval.');

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      String msg = 'Signup failed';
      if (e.code == 'email-already-in-use') msg = 'Email already registered';
      if (e.code == 'weak-password') msg = 'Password too weak';
      _showError(msg);
    } catch (e) {
      _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ========================================
  // VENDOR SIGNUP
  // ========================================
  Future<void> _signupVendor() async {
    final name = _vendorNameController.text.trim();
    final shopName = _vendorShopNameController.text.trim();
    final email = _vendorEmailController.text.trim();
    final phone = _vendorPhoneController.text.trim();
    final gst = _vendorGSTController.text.trim();
    final address = _vendorAddressController.text.trim();
    final password = _vendorPasswordController.text.trim();

    if (name.isEmpty) {
      _showError('Please enter your name');
      return;
    }
    if (shopName.isEmpty) {
      _showError('Please enter shop name');
      return;
    }
    if (email.isEmpty || !email.contains('@')) {
      _showError('Please enter valid email');
      return;
    }
    if (phone.isEmpty || phone.length < 10) {
      _showError('Please enter valid phone number');
      return;
    }
    if (password.isEmpty || password.length < 6) {
      _showError('Password must be at least 6 characters');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Create Firebase Auth user
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = userCredential.user!.uid;

      // Save to Firestore with role = "vendor"
      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'name': name,
        'email': email,
        'phone': phone,
        'role': 'vendor',
        'shopName': shopName,
        'gstNumber': gst,
        'address': address,
        'category': _vendorCategory,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'isBlocked': false,
        'isApproved': false, // Vendor needs admin approval
      });

      // Create vendor shop document
      await _firestore.collection('shops').doc(uid).set({
        'vendorId': uid,
        'shopName': shopName,
        'category': _vendorCategory,
        'address': address,
        'gstNumber': gst,
        'phone': phone,
        'email': email,
        'isApproved': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _showSuccess('Vendor account created! Waiting for admin approval.');
      
      // Navigate to login screen
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      String message = 'Signup failed';
      if (e.code == 'email-already-in-use') {
        message = 'Email already registered';
      } else if (e.code == 'weak-password') {
        message = 'Password is too weak';
      }
      _showError(message);
    } catch (e) {
      _showError('Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ========================================
  // RIDER SIGNUP
  // ========================================
  Future<void> _signupRider() async {
    final name = _riderNameController.text.trim();
    final phone = _riderPhoneController.text.trim();
    final email = _riderEmailController.text.trim();
    final vehicleNumber = _riderVehicleNumberController.text.trim();
    final licenseNumber = _riderLicenseNumberController.text.trim();
    final password = _riderPasswordController.text.trim();

    if (name.isEmpty) {
      _showError('Please enter your name');
      return;
    }
    if (phone.isEmpty || phone.length < 10) {
      _showError('Please enter valid phone number');
      return;
    }
    if (email.isEmpty || !email.contains('@')) {
      _showError('Please enter valid email');
      return;
    }
    if (vehicleNumber.isEmpty) {
      _showError('Please enter vehicle number');
      return;
    }
    if (password.isEmpty || password.length < 6) {
      _showError('Password must be at least 6 characters');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Create Firebase Auth user
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = userCredential.user!.uid;

      // Save to Firestore with role = "rider"
      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'name': name,
        'email': email,
        'phone': phone,
        'role': 'rider',
        'vehicleType': _riderVehicleType,
        'vehicleNumber': vehicleNumber,
        'licenseNumber': licenseNumber,
        'isAvailable': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'isBlocked': false,
        'isApproved': true,
      });

      if (!mounted) return;
      _showSuccess('Delivery partner account created!');
      
      // Navigate to delivery home screen
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => _authFlowService.destinationForRole('rider'),
        ),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      String message = 'Signup failed';
      if (e.code == 'email-already-in-use') {
        message = 'Email already registered';
      } else if (e.code == 'weak-password') {
        message = 'Password is too weak';
      }
      _showError(message);
    } catch (e) {
      _showError('Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Image.asset(
                    'assets/logo.png',
                    width: 80,
                    height: 80,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.flash_on,
                      size: 60,
                      color: Color(0xFFFF4D4F),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Create Account',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),

            // Tab Bar
            TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFFFF4D4F),
              labelColor: const Color(0xFFFF4D4F),
              unselectedLabelColor: Colors.grey,
              tabs: const [
                Tab(text: 'Customer', icon: Icon(Icons.person)),
                Tab(text: 'Vendor', icon: Icon(Icons.store)),
                Tab(text: 'Delivery', icon: Icon(Icons.delivery_dining)),
                Tab(text: 'Services', icon: Icon(Icons.handyman)),
              ],
            ),

            const Divider(color: Color(0xFF333333), height: 1),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildCustomerForm(),
                  _buildVendorForm(),
                  _buildRiderForm(),
                  _buildServiceProviderForm(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========================================
  // CUSTOMER FORM
  // ========================================
  Widget _buildCustomerForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Customer Signup',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create account to order food & products',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 24),

          _buildTextField(
            _customerNameController,
            'Full Name',
            Icons.person_outline,
          ),
          const SizedBox(height: 16),

          _buildTextField(
            _customerEmailController,
            'Email Address',
            Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),

          _buildTextField(
            _customerPhoneController,
            'Phone Number',
            Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),

          _buildTextField(
            _customerPasswordController,
            'Password',
            Icons.lock_outline,
            obscureText: true,
          ),
          const SizedBox(height: 32),

          _buildButton('Create Account', _signupCustomer),
          const SizedBox(height: 16),

          Center(
            child: TextButton(
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
              child: RichText(
                text: TextSpan(
                  text: 'Already have account? ',
                  style: const TextStyle(color: Colors.grey),
                  children: [
                    TextSpan(
                      text: 'Login',
                      style: const TextStyle(
                        color: Color(0xFFFF4D4F),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========================================
  // VENDOR FORM
  // ========================================
  Widget _buildVendorForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vendor Signup',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Register your shop to start selling',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 24),

          _buildTextField(
            _vendorNameController,
            'Your Name',
            Icons.person_outline,
          ),
          const SizedBox(height: 16),

          _buildTextField(
            _vendorShopNameController,
            'Shop Name',
            Icons.store_outlined,
          ),
          const SizedBox(height: 16),

          _buildTextField(
            _vendorEmailController,
            'Email Address',
            Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),

          _buildTextField(
            _vendorPhoneController,
            'Phone Number',
            Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),

          _buildTextField(
            _vendorGSTController,
            'GST Number (Optional)',
            Icons.receipt_outlined,
          ),
          const SizedBox(height: 16),

          _buildTextField(
            _vendorAddressController,
            'Shop Address',
            Icons.location_on_outlined,
            maxLines: 2,
          ),
          const SizedBox(height: 16),

          const Text(
            'Category',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF333333)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _vendorCategory,
                isExpanded: true,
                dropdownColor: const Color(0xFF1E1E1E),
                items: _vendorCategories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(
                      category,
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _vendorCategory = value!);
                },
              ),
            ),
          ),
          const SizedBox(height: 16),

          _buildTextField(
            _vendorPasswordController,
            'Password',
            Icons.lock_outline,
            obscureText: true,
          ),
          const SizedBox(height: 32),

          _buildButton('Register Shop', _signupVendor),
          const SizedBox(height: 16),

          Center(
            child: TextButton(
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
              child: RichText(
                text: TextSpan(
                  text: 'Already have account? ',
                  style: const TextStyle(color: Colors.grey),
                  children: [
                    TextSpan(
                      text: 'Login',
                      style: const TextStyle(
                        color: Color(0xFFFF4D4F),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========================================
  // RIDER FORM
  // ========================================
  Widget _buildRiderForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Delivery Partner Signup',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Join as delivery partner and earn',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 24),

          _buildTextField(
            _riderNameController,
            'Full Name',
            Icons.person_outline,
          ),
          const SizedBox(height: 16),

          _buildTextField(
            _riderPhoneController,
            'Phone Number',
            Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),

          _buildTextField(
            _riderEmailController,
            'Email Address',
            Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),

          const Text(
            'Vehicle Type',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildVehicleTypeOption(
                  '2-wheeler',
                  Icons.motorcycle,
                  'Bike/Scooter',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildVehicleTypeOption(
                  '4-wheeler',
                  Icons.directions_car,
                  'Car/Van',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _buildTextField(
            _riderVehicleNumberController,
            'Vehicle Number (e.g., MH01AB1234)',
            Icons.directions_car_filled_outlined,
          ),
          const SizedBox(height: 16),

          _buildTextField(
            _riderLicenseNumberController,
            'License Number (Optional)',
            Icons.credit_card_outlined,
          ),
          const SizedBox(height: 16),

          _buildTextField(
            _riderPasswordController,
            'Password',
            Icons.lock_outline,
            obscureText: true,
          ),
          const SizedBox(height: 32),

          _buildButton('Join as Delivery Partner', _signupRider),
          const SizedBox(height: 16),

          Center(
            child: TextButton(
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
              child: RichText(
                text: TextSpan(
                  text: 'Already have account? ',
                  style: const TextStyle(color: Colors.grey),
                  children: [
                    TextSpan(
                      text: 'Login',
                      style: const TextStyle(
                        color: Color(0xFFFF4D4F),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildServiceProviderForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Service Provider Signup',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Register as plumber, electrician, doctor etc.',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 24),

          // Service Type Dropdown
          const Text('Service Type', style: TextStyle(color: Colors.white, fontSize: 14)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF333333)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _spServiceType,
                isExpanded: true,
                dropdownColor: const Color(0xFF1E1E1E),
                items: _serviceTypes.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type, style: const TextStyle(color: Colors.white)),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _spServiceType = value!),
              ),
            ),
          ),
          const SizedBox(height: 16),

          _buildTextField(_spNameController, 'Full Name', Icons.person_outline),
          const SizedBox(height: 16),
          _buildTextField(_spEmailController, 'Email Address', Icons.email_outlined,
              keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 16),
          _buildTextField(_spPhoneController, 'Phone Number', Icons.phone_outlined,
              keyboardType: TextInputType.phone),
          const SizedBox(height: 16),
          _buildTextField(_spPasswordController, 'Password', Icons.lock_outline,
              obscureText: true),
          const SizedBox(height: 16),

          // Info box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFF4D4F).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFF4D4F).withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFFFF4D4F), size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your account will be verified by admin before activation.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          _buildButton('Register as $_spServiceType', _signupServiceProvider),
          const SizedBox(height: 16),

          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
              ),
              child: RichText(
                text: const TextSpan(
                  text: 'Already have account? ',
                  style: TextStyle(color: Colors.grey),
                  children: [
                    TextSpan(
                      text: 'Login',
                      style: TextStyle(color: Color(0xFFFF4D4F), fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleTypeOption(String type, IconData icon, String label) {
    final isSelected = _riderVehicleType == type;
    return GestureDetector(
      onTap: () => setState(() => _riderVehicleType = type),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFF4D4F).withValues(alpha: 0.2)
              : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF4D4F) : const Color(0xFF333333),
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? const Color(0xFFFF4D4F) : Colors.grey, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Icon(icon, color: const Color(0xFFFF4D4F)),
        filled: true,
        fillColor: const Color(0xFF1E1E1E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF333333)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF333333)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFF4D4F), width: 2),
        ),
      ),
    );
  }

  Widget _buildButton(String text, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF4D4F),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                text,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
