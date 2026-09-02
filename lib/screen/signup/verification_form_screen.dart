import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:db_compat/db_compat.dart';
import '../verification_pending_screen.dart';
import '../../core/logging_service.dart';

class VerificationFormScreen extends StatefulWidget {
  final String uid;
  final String role; // Renamed from roleId to role as per requirement
  final String name;
  final String email;
  final String phone;

  const VerificationFormScreen({
    super.key,
    required this.uid,
    required this.role,
    required this.name,
    required this.email,
    required this.phone,
  });

  @override
  State<VerificationFormScreen> createState() => _VerificationFormScreenState();
}

class _VerificationFormScreenState extends State<VerificationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  // Controllers for various possible fields
  final _nameController = TextEditingController();
  final _businessNameController =
      TextEditingController(); // For Shop/Theatre name
  final _addressController = TextEditingController();
  final _licenseController = TextEditingController();
  final _gstController = TextEditingController();
  final _businessRegController = TextEditingController();
  final _aadharController = TextEditingController();
  final _drivingLicenseController = TextEditingController();
  final _vehicleRcController = TextEditingController();

  // File management
  final Map<String, dynamic> _selectedFiles = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.name;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _businessNameController.dispose();
    _addressController.dispose();
    _licenseController.dispose();
    _gstController.dispose();
    _businessRegController.dispose();
    _aadharController.dispose();
    _drivingLicenseController.dispose();
    _vehicleRcController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(String fieldKey) async {
    if (_isLoading) return;
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (image != null) {
        setState(() {
          _selectedFiles[fieldKey] = File(image.path);
        });
      }
    } catch (e) {
      Log.e('VerificationFormScreen', 'Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
      }
    }
  }

  Future<void> _pickMultiImage(String fieldKey) async {
    if (_isLoading) return;
    try {
      final List<XFile> images = await _picker.pickMultiImage(imageQuality: 70);

      if (images.isNotEmpty) {
        setState(() {
          _selectedFiles[fieldKey] = images.map((x) => File(x.path)).toList();
        });
      }
    } catch (e) {
      Log.e('VerificationFormScreen', 'Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking images: $e')));
      }
    }
  }

  Future<Map<String, dynamic>> _uploadAllFiles() async {
    Map<String, dynamic> uploadedUrls = {};

    for (var entry in _selectedFiles.entries) {
      final String fieldKey = entry.key;
      final dynamic value = entry.value;

      if (value is File) {
        final String fileName =
            '${fieldKey}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final ref = FirebaseStorage.instance.ref().child(
          'verifications/${widget.role}/${widget.uid}/$fileName',
        );

        await ref.putFile(value);
        final url = await ref.getDownloadURL();
        uploadedUrls[fieldKey] = url;
      } else if (value is List<File>) {
        List<String> urls = [];
        for (int i = 0; i < value.length; i++) {
          final String fileName =
              '${fieldKey}_portfolio_${i}_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final ref = FirebaseStorage.instance.ref().child(
            'verifications/${widget.role}/${widget.uid}/$fileName',
          );

          await ref.putFile(value[i]);
          final url = await ref.getDownloadURL();
          urls.add(url);
        }
        uploadedUrls[fieldKey] = urls;
      }
    }

    return uploadedUrls;
  }

  Future<void> _submitVerification() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_validateRequiredFiles()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload all required documents')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Upload images to Firebase Storage
      final uploadedUrls = await _uploadAllFiles();

      final Map<String, dynamic> verificationData = {
        'uid': widget.uid,
        'name': _nameController.text.trim(),
        'email': widget.email,
        'phone': widget.phone,
        'role': widget.role,
        'status': 'pending',
        'requestedAt': FieldValue.serverTimestamp(),
        'details': _getRoleSpecificData(),
        'documents': uploadedUrls, // Using 'documents' to match AdminScreen
      };

      // 2. Update user document in Firestore
      // Standardize roles: ensure both 'roles' array and 'role' field are updated
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .get();
      final userData = userDoc.data() ?? {};
      List<String> roles = List<String>.from(userData['roles'] ?? ['customer']);
      if (!roles.contains(widget.role)) {
        roles.add(widget.role);
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .update({
            'roles': roles,
            'role': widget.role,
            'verificationStatus': 'pending',
            'isProvider': true,
            'isApproved':
                false, // Ensure isApproved is false until admin reviews
          });

      // 3. Create a verification request record
      await FirebaseFirestore.instance
          .collection('verification_requests')
          .doc(widget.uid)
          .set(verificationData);

      // 4. Sync with theatre_partner_requests for Admin Web Dashboard compatibility
      if (widget.role == 'theatre_owner') {
        final roleData = _getRoleSpecificData();
        await FirebaseFirestore.instance
            .collection('theatre_partner_requests')
            .doc(widget.uid)
            .set({
              'status': 'pending',
              'basicDetails': {
                'theatreName':
                    roleData['theatreName'] ??
                    _businessNameController.text.trim(),
                'ownerName': _nameController.text.trim(),
                'email': widget.email,
                'phone': widget.phone,
              },
              'theatreInfo': {
                'address': _addressController.text.trim(),
                'city': 'N/A',
                'state': 'N/A',
                'pincode': 'N/A',
                'screens': 1,
              },
              'documents': {
                'businessProof': uploadedUrls['business_proof'] ?? '',
                'theatrePhoto':
                    uploadedUrls['business_proof'] ?? '', // Fallback
              },
              'agreement': {
                'accepted': true,
                'acceptedAt': FieldValue.serverTimestamp(),
                'version': '1.0',
              },
              'verification': {'otpVerified': true},
              'createdAt': FieldValue.serverTimestamp(),
            });
      }

      Log.i('VerificationFormScreen', 'Submitted for ${widget.uid}');

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => VerificationPendingScreen(role: widget.role),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      Log.e('VerificationFormScreen', 'Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Submission failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _validateRequiredFiles() {
    switch (widget.role) {
      case 'doctor':
        return _selectedFiles.containsKey('degree_cert');
      case 'shop_vendor':
        return _selectedFiles.containsKey('shop_photo') &&
            _selectedFiles.containsKey('owner_id');
      case 'delivery_rider':
        return _selectedFiles.containsKey('aadhar_card') &&
            _selectedFiles.containsKey('dl_photo');
      case 'plumber':
      case 'electrician':
      case 'cleaner':
        return _selectedFiles.containsKey('aadhar_photo');
      case 'carpenter':
        return _selectedFiles.containsKey('id_proof');
      case 'theatre_owner':
        return _selectedFiles.containsKey('business_proof');
      default:
        return _selectedFiles.containsKey('id_proof');
    }
  }

  Map<String, dynamic> _getRoleSpecificData() {
    final Map<String, dynamic> data = {'fullName': _nameController.text.trim()};

    switch (widget.role) {
      case 'doctor':
        data['medicalLicense'] = _licenseController.text.trim();
        data['clinicAddress'] = _addressController.text.trim();
        break;
      case 'shop_vendor':
        data['shopName'] = _businessNameController.text.trim();
        data['shopAddress'] = _addressController.text.trim();
        data['gstNumber'] = _gstController.text.trim();
        break;
      case 'delivery_rider':
        data['address'] = _addressController.text.trim();
        data['aadharNumber'] = _aadharController.text.trim();
        data['drivingLicense'] = _drivingLicenseController.text.trim();
        data['vehicleRc'] = _vehicleRcController.text.trim();
        break;
      case 'plumber':
      case 'electrician':
      case 'cleaner':
        data['address'] = _addressController.text.trim();
        data['aadharNumber'] = _aadharController.text.trim();
        break;
      case 'carpenter':
        data['address'] = _addressController.text.trim();
        data['idProofNumber'] = _aadharController.text.trim();
        break;
      case 'theatre_owner':
        data['theatreName'] = _businessNameController.text.trim();
        data['theatreAddress'] = _addressController.text.trim();
        data['gstNumber'] = _gstController.text.trim();
        data['businessRegNumber'] = _businessRegController.text.trim();
        break;
      default:
        data['address'] = _addressController.text.trim();
    }
    return data;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.role.replaceAll('_', ' ').toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Verify Your Identity',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please provide details for ${widget.role.replaceAll('_', ' ')} verification',
                  style: const TextStyle(color: Colors.grey, fontSize: 16),
                ),
                const SizedBox(height: 32),

                ..._buildDynamicFields(),

                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitVerification,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF4D4F),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Submit for Verification',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildDynamicFields() {
    List<Widget> fields = [];

    switch (widget.role) {
      case 'doctor':
        fields.addAll([
          _buildField(
            label: 'Full Name',
            controller: _nameController,
            hint: 'Enter your full name',
          ),
          const SizedBox(height: 20),
          _buildField(
            label: 'Medical License Number',
            controller: _licenseController,
            hint: 'Enter license number',
            validator: (v) {
              if (v == null || v.isEmpty) return 'License number is required';
              if (v.length < 5) return 'Enter a valid license number';
              return null;
            },
          ),
          const SizedBox(height: 20),
          _buildField(
            label: 'Clinic Address',
            controller: _addressController,
            hint: 'Enter clinic address',
            maxLines: 3,
          ),
          const SizedBox(height: 24),
          _buildUploadPlaceholder(
            label: 'Degree Certificate',
            fieldKey: 'degree_cert',
          ),
        ]);
        break;

      case 'shop_vendor':
        fields.addAll([
          _buildField(
            label: 'Shop Name',
            controller: _businessNameController,
            hint: 'Enter shop name',
          ),
          const SizedBox(height: 20),
          _buildField(
            label: 'Owner Full Name',
            controller: _nameController,
            hint: 'Enter owner name',
          ),
          const SizedBox(height: 20),
          _buildField(
            label: 'Shop Address',
            controller: _addressController,
            hint: 'Enter shop address',
            maxLines: 3,
          ),
          const SizedBox(height: 20),
          _buildField(
            label: 'GST Number',
            controller: _gstController,
            hint: 'Enter 15-digit GST number',
            validator: (v) {
              if (v == null || v.isEmpty) return 'GST number is required';
              final regExp = RegExp(
                r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$',
              );
              if (!regExp.hasMatch(v.toUpperCase())) {
                return 'Enter a valid GST format';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          _buildUploadPlaceholder(label: 'Shop Photo', fieldKey: 'shop_photo'),
          const SizedBox(height: 16),
          _buildUploadPlaceholder(
            label: 'Owner ID Proof',
            fieldKey: 'owner_id',
          ),
        ]);
        break;

      case 'delivery_rider':
        fields.addAll([
          _buildField(
            label: 'Permanent Address',
            controller: _addressController,
            hint: 'Enter address',
            maxLines: 3,
          ),
          const SizedBox(height: 20),
          _buildField(
            label: 'Aadhar Number',
            controller: _aadharController,
            hint: 'Enter 12 digit Aadhar',
            validator: (v) {
              if (v == null || v.isEmpty) return 'Aadhar number is required';
              if (!RegExp(r'^[2-9]{1}[0-9]{11}$').hasMatch(v)) {
                return 'Enter a valid 12-digit Aadhar';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          _buildField(
            label: 'Driving License Number',
            controller: _drivingLicenseController,
            hint: 'Enter DL number',
            validator: (v) {
              if (v == null || v.isEmpty) return 'DL number is required';
              if (v.length < 10) return 'Enter a valid DL number';
              return null;
            },
          ),
          const SizedBox(height: 20),
          _buildField(
            label: 'Vehicle RC Number',
            controller: _vehicleRcController,
            hint: 'Enter vehicle RC',
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Vehicle RC is required' : null,
          ),
          const SizedBox(height: 24),
          _buildUploadPlaceholder(
            label: 'Aadhar Card Front \u0026 Back',
            fieldKey: 'aadhar_card',
          ),
          const SizedBox(height: 16),
          _buildUploadPlaceholder(
            label: 'Driving License',
            fieldKey: 'dl_photo',
          ),
        ]);
        break;

      case 'plumber':
      case 'electrician':
      case 'cleaner':
        fields.addAll([
          _buildField(
            label: 'Address',
            controller: _addressController,
            hint: 'Enter your address',
            maxLines: 3,
          ),
          const SizedBox(height: 20),
          _buildField(
            label: 'Aadhar Number',
            controller: _aadharController,
            hint: 'Enter Aadhar number',
            validator: (v) {
              if (v == null || v.isEmpty) return 'Aadhar number is required';
              if (!RegExp(r'^[2-9]{1}[0-9]{11}$').hasMatch(v)) {
                return 'Enter a valid 12-digit Aadhar';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          _buildUploadPlaceholder(
            label: 'Aadhar Card Photo',
            fieldKey: 'aadhar_photo',
          ),
          const SizedBox(height: 16),
          _buildUploadPlaceholder(
            label: 'Experience Proof (Optional)',
            fieldKey: 'exp_proof',
          ),
          const SizedBox(height: 16),
          _buildMultiUploadPlaceholder(
            label: 'Portfolio Images (Optional)',
            fieldKey: 'portfolio_images',
          ),
        ]);
        break;

      case 'carpenter':
        fields.addAll([
          _buildField(
            label: 'Address',
            controller: _addressController,
            hint: 'Enter your address',
            maxLines: 3,
          ),
          const SizedBox(height: 20),
          _buildField(
            label: 'ID Proof Number',
            controller: _aadharController,
            hint: 'Aadhar/PAN number',
            validator: (v) {
              if (v == null || v.isEmpty) return 'ID proof number is required';
              if (v.length < 10) return 'Enter a valid ID number';
              return null;
            },
          ),
          const SizedBox(height: 24),
          _buildUploadPlaceholder(
            label: 'ID Proof (Required)',
            fieldKey: 'id_proof',
          ),
          const SizedBox(height: 16),
          _buildUploadPlaceholder(
            label: 'Experience Proof (Optional)',
            fieldKey: 'exp_proof',
          ),
          const SizedBox(height: 16),
          _buildMultiUploadPlaceholder(
            label: 'Portfolio Images',
            fieldKey: 'portfolio_images',
          ),
        ]);
        break;

      case 'theatre_owner':
        fields.addAll([
          _buildField(
            label: 'Theatre Name',
            controller: _businessNameController,
            hint: 'Enter theatre name',
          ),
          const SizedBox(height: 20),
          _buildField(
            label: 'Owner Full Name',
            controller: _nameController,
            hint: 'Enter owner name',
          ),
          const SizedBox(height: 20),
          _buildField(
            label: 'Theatre Address',
            controller: _addressController,
            hint: 'Enter theatre address',
            maxLines: 3,
          ),
          const SizedBox(height: 20),
          _buildField(
            label: 'GST Number',
            controller: _gstController,
            hint: 'Enter 15-digit GST number',
            validator: (v) {
              if (v == null || v.isEmpty) return 'GST number is required';
              final regExp = RegExp(
                r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$',
              );
              if (!regExp.hasMatch(v.toUpperCase())) {
                return 'Enter a valid GST format';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          _buildField(
            label: 'Business Registration Number',
            controller: _businessRegController,
            hint: 'Enter reg number',
          ),
          const SizedBox(height: 24),
          _buildUploadPlaceholder(
            label: 'Business Proof Document',
            fieldKey: 'business_proof',
          ),
        ]);
        break;

      default:
        fields.addAll([
          _buildField(
            label: 'Address',
            controller: _addressController,
            hint: 'Enter your address',
            maxLines: 3,
          ),
          const SizedBox(height: 24),
          _buildUploadPlaceholder(
            label: 'Identity Proof',
            fieldKey: 'id_proof',
          ),
        ]);
    }

    return fields;
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        const SizedBox(height: 10),
        TextFormField(
          controller: controller,
          validator:
              validator ?? (v) => v!.isEmpty ? '$label is required' : null,
          style: const TextStyle(color: Colors.white),
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.withValues(alpha: 0.4)),
            filled: true,
            fillColor: const Color(0xFF1A1A1A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUploadPlaceholder({
    required String label,
    required String fieldKey,
  }) {
    final dynamic fileData = _selectedFiles[fieldKey];
    final File? file = fileData is File ? fileData : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => _pickImage(fieldKey),
          child: Container(
            width: double.infinity,
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: file != null
                    ? const Color(0xFFFF4D4F)
                    : const Color(0xFF2A2A2A),
                style: BorderStyle.solid,
              ),
              image: file != null
                  ? DecorationImage(image: FileImage(file), fit: BoxFit.cover)
                  : null,
            ),
            child: file == null
                ? const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_a_photo_outlined,
                        color: Color(0xFFFF4D4F),
                        size: 28,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Tap to upload photo',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.edit_outlined,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildMultiUploadPlaceholder({
    required String label,
    required String fieldKey,
  }) {
    final dynamic fileData = _selectedFiles[fieldKey];
    final List<File> files = fileData is List<File> ? fileData : [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => _pickMultiImage(fieldKey),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 120),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: files.isNotEmpty
                    ? const Color(0xFFFF4D4F)
                    : const Color(0xFF2A2A2A),
                style: BorderStyle.solid,
              ),
            ),
            child: files.isEmpty
                ? const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_outlined,
                        color: Color(0xFFFF4D4F),
                        size: 28,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Tap to upload multiple images',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...files.map(
                        (file) => Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(
                              image: FileImage(file),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFFFF4D4F),
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: const Icon(Icons.add, color: Colors.white),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
