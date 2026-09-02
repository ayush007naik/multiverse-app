import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:db_compat/db_compat.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:async';
import 'appointment_success_screen.dart';
import '../utils/price_calculator.dart';
import '../services/fee_config_service.dart';
import '../core/logging_service.dart';

class ServiceBookingFormScreen extends StatefulWidget {
  final Map<String, dynamic> service;

  const ServiceBookingFormScreen({super.key, required this.service});

  @override
  State<ServiceBookingFormScreen> createState() =>
      _ServiceBookingFormScreenState();
}

class _ServiceBookingFormScreenState extends State<ServiceBookingFormScreen> {
  @override
  void initState() {
    super.initState();
    _loadPartnerSchedule();
    _feeSub = FeeConfigService.stream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  StreamSubscription<Map<String, double>>? _feeSub;

  void _loadPartnerSchedule() {
    final schedule =
        widget.service["full_partner_data"]?["schedule"] as Map? ?? {};
    if (_selectedDate != null) {
      final dateKey =
          "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}";
      setState(() {
        _timeSlots = List<String>.from(schedule[dateKey] ?? []);
      });
    }
  }

  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _budgetController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  DateTime? _selectedDate;
  String? _selectedTime;

  final List<File> _imageFiles = []; // Local image files
  bool _isUploading = false;
  String? _validationError;

  List<String> _timeSlots = [];

  // Validation Logic
  bool get _isFormValid {
    // Description must have at least 5 words
    final descriptionWords = _descriptionController.text.trim().split(
      RegExp(r'\s+'),
    );
    final isDescriptionValid =
        _descriptionController.text.trim().isNotEmpty &&
        descriptionWords.length >= 5;

    // Budget must be entered
    final isBudgetValid =
        _budgetController.text.isNotEmpty &&
        double.tryParse(_budgetController.text) != null &&
        double.parse(_budgetController.text) > 0;

    // Date must be selected
    final isDateValid = _selectedDate != null;

    // Time must be selected
    final isTimeValid = _selectedTime != null;

    return _nameController.text.isNotEmpty &&
        _phoneController.text.isNotEmpty &&
        isDescriptionValid &&
        isBudgetValid &&
        isDateValid &&
        isTimeValid;
  }

  String? _validateDescription() {
    if (_descriptionController.text.trim().isEmpty) {
      return 'Please describe your requirement.';
    }
    final words = _descriptionController.text.trim().split(RegExp(r'\s+'));
    if (words.length < 5) {
      return 'Please describe your requirement properly.';
    }
    return null;
  }

  /// Pick image from gallery
  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        final file = File(image.path);

        // Check file size (max 5MB)
        final fileSize = await file.length();
        if (fileSize > 5 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Image size must be less than 5MB'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        setState(() {
          _imageFiles.add(file);
        });

        Log.i('ServiceBookingFormScreen', '📸 Image picked: ${image.path}');
      }
    } catch (e) {
      Log.e('ServiceBookingFormScreen', 'Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to pick image'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Upload all images to Firebase Storage
  Future<List<String>> _uploadImages(String bookingId) async {
    if (_imageFiles.isEmpty) {
      return [];
    }

    setState(() => _isUploading = true);
    final List<String> imageUrls = [];

    try {
      for (int i = 0; i < _imageFiles.length; i++) {
        final file = _imageFiles[i];
        final fileName =
            'booking_$bookingId/image_${i}_${DateTime.now().millisecondsSinceEpoch}.jpg';

        Log.i(
          'ServiceBookingFormScreen',
          '📤 Uploading image ${i + 1}/${_imageFiles.length}: $fileName',
        );

        // Create storage reference
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('service_bookings')
            .child(fileName);

        // Upload file
        final uploadTask = await storageRef.putFile(
          file,
          SettableMetadata(
            contentType: 'image/jpeg',
            customMetadata: {
              'bookingId': bookingId,
              'uploadedAt': DateTime.now().toIso8601String(),
            },
          ),
        );

        // Get download URL
        final downloadUrl = await uploadTask.ref.getDownloadURL();
        imageUrls.add(downloadUrl);

        Log.i('ServiceBookingFormScreen', '✅ Image ${i + 1} uploaded: $downloadUrl');
      }

      setState(() => _isUploading = false);
      return imageUrls;
    } catch (e) {
      Log.e('ServiceBookingFormScreen', 'Error uploading images: $e');
      setState(() => _isUploading = false);
      throw Exception('Failed to upload images: $e');
    }
  }

  /// Remove image from list
  void _removeImage(int index) {
    setState(() {
      _imageFiles.removeAt(index);
    });
    Log.i('ServiceBookingFormScreen', '🗑️ Image removed at index $index');
  }

  Future<void> _handleSendRequest() async {
    setState(() {
      _validationError = null;
    });

    if (!_isFormValid) {
      setState(() {
        _validationError = 'Please complete all required details first.';
      });

      // Show validation popup
      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1F),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.red,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'Incomplete Details',
                  style: GoogleFonts.orbitron(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Please complete all required details first.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF7A1A),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'OK',
                    style: GoogleFonts.orbitron(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }

    // Show loading dialog
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          color: Color(0xFF1A1A1F),
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFFFF7A1A)),
                SizedBox(height: 16),
                Text(
                  'Creating Booking Request...',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // Validate user is logged in
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please login to book a service'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Create booking in Firestore
      final bookingRef = FirebaseFirestore.instance
          .collection('service_bookings')
          .doc();
      final bookingId = bookingRef.id;

      // Upload images to Firebase Storage first
      List<String> imageUrls = [];
      if (_imageFiles.isNotEmpty) {
        Log.i('ServiceBookingFormScreen', '📸 Uploading ${_imageFiles.length} images...');
        imageUrls = await _uploadImages(bookingId);
        Log.i('ServiceBookingFormScreen', '✅ ${imageUrls.length} images uploaded successfully');
      }

      // Save booking with image URLs
      final fullPartner = widget.service['full_partner_data'] ?? {};
      final double budget = double.tryParse(_budgetController.text) ?? 0;
      final breakdown = PriceCalculator.calculateBookingPrice(budget);

      await bookingRef.set({
        'bookingId': bookingId,
        'customerId': user.uid,
        'customerPhone': user.phoneNumber ?? '',
        'customerEmail': user.email ?? '',
        'serviceCategory': widget.service['name'] ?? '',
        'serviceId': widget.service['id'] ?? '',
        'partnerId': fullPartner['userId'] ?? fullPartner['id'] ?? '',
        'serviceDescription': _descriptionController.text.trim(),
        'budget': budget,
        'basePrice': breakdown['basePrice'],
        'markup': breakdown['markup'],
        'platformFee': breakdown['platformFee'],
        'gst': breakdown['gst'],
        'totalPrice': breakdown['totalPayable'],
        'profit': breakdown['profit'],
        'scheduledDate': Timestamp.fromDate(_selectedDate ?? DateTime.now()),
        'scheduledTime': _selectedTime ?? '',
        'status': 'confirmed', // auto-confirmed
        'images': imageUrls, // Firebase Storage URLs
        'imageCount': imageUrls.length,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'providerName':
            widget.service['name'] ?? fullPartner['name'] ?? 'Service Provider',
        'providerDetails': {
          'name': fullPartner['name'] ?? widget.service['name'] ?? '',
          'qualification': fullPartner['qualification'] ?? '',
          'specialization':
              fullPartner['specialization'] ??
              (fullPartner['selectedSubCategories'] as List?)?.join(', ') ??
              '',
          'category': fullPartner['category'] ?? '',
          'experience':
              fullPartner['experience'] ??
              fullPartner['yearsOfExperience'] ??
              '',
          'rating': fullPartner['rating'] ?? '',
          'shopAddress':
              fullPartner['shopAddress'] ?? fullPartner['address'] ?? '',
          'phone': fullPartner['phone'] ?? '',
          'bio': fullPartner['bio'] ?? '',
          'profileImage':
              fullPartner['profileImage'] ?? fullPartner['image'] ?? '',
        },
        'customerName': _nameController.text.trim(),
        'userName': _nameController.text.trim(), // for dashboard compatibility
        'date':
            "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}",
        'time': _selectedTime ?? '',
      });

      Log.i('ServiceBookingFormScreen', '✅ Booking created successfully: $bookingId');
      // PDF is now handled in Success Screen
      Log.i('ServiceBookingFormScreen', '📸 Images: ${imageUrls.length}');

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Navigate to RequestSentScreen
      if (mounted) {
        final double budget = double.tryParse(_budgetController.text) ?? 0;
        final breakdown = PriceCalculator.calculateBookingPrice(budget);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AppointmentSuccessScreen(
              bookingData: {
                'customerName': _nameController.text.trim(),
                'customerPhone': _phoneController.text.trim(),
                'serviceDescription': _descriptionController.text.trim(),
                'budget': breakdown['totalPayable'].toStringAsFixed(2),
                'scheduledDateStr':
                    "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}",
                'scheduledTime': _selectedTime ?? '',
                'price': breakdown['totalPayable'],
              },
              service: widget.service,
            ),
          ),
        );
      }
    } catch (e) {
      Log.e('ServiceBookingFormScreen', 'Error creating booking: $e');

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Show specific error message
      String errorMessage = 'Failed to create booking. Please try again.';
      if (e.toString().contains('permission')) {
        errorMessage = 'Database permission error. Please contact support.';
      } else if (e.toString().contains('network')) {
        errorMessage = 'No internet connection. Please check your network.';
      } else if (e.toString().contains('upload')) {
        errorMessage = 'Failed to upload images. Please try again.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color neonColor =
        widget.service['neonColor'] ??
        widget.service['color'] ??
        const Color(0xFFFF7A1A);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Book Service',
          style: GoogleFonts.orbitron(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              physics: const BouncingScrollPhysics(),
              children: [
                // Name & Phone Fields
                _buildSectionHeader('YOUR NAME *'),
                const SizedBox(height: 12),
                _buildInputContainer(
                  _nameController,
                  'Enter your name...',
                  Icons.person_outline,
                ),
                const SizedBox(height: 24),

                _buildSectionHeader('PHONE NUMBER *'),
                const SizedBox(height: 12),
                _buildInputContainer(
                  _phoneController,
                  'Enter phone number...',
                  Icons.phone_android_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 24),

                // 1. Describe Your Requirement
                _buildSectionHeader('DESCRIBE YOUR REQUIREMENT *'),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _validateDescription() != null
                          ? Colors.red.withValues(alpha: 0.5)
                          : Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: TextField(
                    controller: _descriptionController,
                    maxLines: 4,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Explain what work you need...',
                      hintStyle: GoogleFonts.poppins(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    onChanged: (value) => setState(() {}),
                  ),
                ),
                // Validation Error Message
                if (_validateDescription() != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: Colors.red,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _validateDescription()!,
                          style: GoogleFonts.poppins(
                            color: Colors.red,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 28),

                // 2. Upload Images
                _buildSectionHeader('UPLOAD IMAGES (OPTIONAL)'),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _isUploading ? null : _pickImage,
                  child: Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _imageFiles.isEmpty
                            ? Colors.white.withValues(alpha: 0.1)
                            : widget.service['neonColor']?.withOpacity(0.3) ??
                                  Colors.white.withValues(alpha: 0.1),
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: _imageFiles.isEmpty
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate_rounded,
                                color:
                                    widget.service['neonColor'] ??
                                    const Color(0xFFFF7A1A),
                                size: 40,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap to add photos',
                                style: GoogleFonts.poppins(
                                  color:
                                      widget.service['neonColor'] ??
                                      const Color(0xFFFF7A1A),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Max 5MB per image',
                                style: GoogleFonts.poppins(
                                  color: Colors.white.withValues(alpha: 0.4),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              // Show uploaded images
                              Expanded(
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.all(12),
                                  itemCount: _imageFiles.length,
                                  itemBuilder: (context, index) {
                                    return Stack(
                                      children: [
                                        Container(
                                          width: 90,
                                          height: 90,
                                          margin: const EdgeInsets.only(
                                            right: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            image: DecorationImage(
                                              image: FileImage(
                                                _imageFiles[index],
                                              ),
                                              fit: BoxFit.cover,
                                            ),
                                            border: Border.all(
                                              color:
                                                  (widget.service['neonColor'] ??
                                                          const Color(
                                                            0xFFFF7A1A,
                                                          ))
                                                      .withOpacity(0.3),
                                            ),
                                          ),
                                        ),
                                        // Delete button
                                        Positioned(
                                          top: 4,
                                          right: 12,
                                          child: GestureDetector(
                                            onTap: () => _removeImage(index),
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: Colors.red.withValues(
                                                  alpha: 0.9,
                                                ),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.close_rounded,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                              // Add more button
                              if (_imageFiles.length < 5)
                                Container(
                                  width: 50,
                                  height: 90,
                                  margin: const EdgeInsets.only(right: 12),
                                  decoration: BoxDecoration(
                                    color:
                                        (widget.service['neonColor'] ??
                                                const Color(0xFFFF7A1A))
                                            .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color:
                                          (widget.service['neonColor'] ??
                                                  const Color(0xFFFF7A1A))
                                              .withOpacity(0.3),
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.add_rounded,
                                    color:
                                        widget.service['neonColor'] ??
                                        const Color(0xFFFF7A1A),
                                    size: 28,
                                  ),
                                ),
                            ],
                          ),
                  ),
                ),
                // Image count info
                if (_imageFiles.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.photo_library_rounded,
                        size: 16,
                        color:
                            widget.service['neonColor'] ??
                            const Color(0xFFFF7A1A),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${_imageFiles.length} image${_imageFiles.length > 1 ? 's' : ''} selected',
                        style: GoogleFonts.poppins(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 28),

                // 3. Enter Your Budget
                _buildSectionHeader('YOUR BUDGET'),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: TextField(
                    controller: _budgetController,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Enter your expected price',
                      hintStyle: GoogleFonts.poppins(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 14,
                      ),
                      prefixText: '₹ ',
                      prefixStyle: GoogleFonts.poppins(
                        color: neonColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    onChanged: (value) => setState(() {}),
                  ),
                ),

                const SizedBox(height: 28),

                // 4. Preferred Date *
                _buildSectionHeader('PREFERRED DATE *'),
                const SizedBox(height: 12),
                _buildDatePicker(neonColor),
                if (_selectedDate == null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: Colors.red,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Please select a date.',
                        style: GoogleFonts.poppins(
                          color: Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 28),

                // 5. Preferred Time Slot *
                _buildSectionHeader('PREFERRED TIME *'),
                const SizedBox(height: 12),

                // Use _buildPriceRow to resolve unused warning
                if (_budgetController.text.isNotEmpty) ...[
                  Builder(
                    builder: (context) {
                      final double budget =
                          double.tryParse(_budgetController.text) ?? 0;
                      final breakdown = PriceCalculator.calculateBookingPrice(
                        budget,
                      );
                      return Column(
                        children: [
                          _buildPriceRow(
                            'Booking Price',
                            '₹ ${(breakdown['basePrice'] + breakdown['markup']).toStringAsFixed(0)}',
                            neonColor: neonColor,
                          ),
                          _buildPriceRow(
                            'Platform Fee',
                            '₹ ${breakdown['platformFee'].toStringAsFixed(0)}',
                            neonColor: neonColor,
                          ),
                          _buildPriceRow(
                            'GST (18%)',
                            '₹ ${breakdown['gst'].toStringAsFixed(2)}',
                            neonColor: neonColor,
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Divider(color: Colors.white10),
                          ),
                          _buildPriceRow(
                            'Total Payable',
                            '₹ ${breakdown['totalPayable'].toStringAsFixed(2)}',
                            isTotal: true,
                            neonColor: neonColor,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                ],

                _timeSlots.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          "NO BOOKING SLOT AVAILABLE",
                          style: GoogleFonts.poppins(
                            color: Colors.redAccent,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    : Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _timeSlots.map((time) {
                          final isSelected = _selectedTime == time;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedTime = time),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? neonColor
                                    : Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.transparent
                                      : Colors.white.withValues(alpha: 0.1),
                                ),
                              ),
                              child: Text(
                                time,
                                style: GoogleFonts.poppins(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.6),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                if (_selectedTime == null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: Colors.red,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Please select a time slot.',
                        style: GoogleFonts.poppins(
                          color: Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 30),

                // "Why Book With Us?" Info Card
                _buildWhyBookWithUsCard(neonColor),

                const SizedBox(height: 30),
              ],
            ),
          ),

          // Send Booking Request Button
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  const Color(0xFF0A0A0D).withValues(alpha: 0.95),
                  const Color(0xFF0A0A0D),
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_validationError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _validationError!,
                      style: GoogleFonts.poppins(
                        color: Colors.redAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: _isFormValid
                        ? [
                            BoxShadow(
                              color: const Color(
                                0xFFFF7A1A,
                              ).withValues(alpha: 0.5),
                              blurRadius: 20,
                              spreadRadius: 0,
                            ),
                          ]
                        : [],
                  ),
                  child: ElevatedButton(
                    onPressed: _handleSendRequest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isFormValid
                          ? const Color(0xFFFF7A1A)
                          : Colors.grey.withValues(alpha: 0.3),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                      disabledBackgroundColor: Colors.grey.withValues(
                        alpha: 0.3,
                      ),
                    ),
                    child: Text(
                      'SEND BOOKING REQUEST',
                      style: GoogleFonts.orbitron(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputContainer(
    TextEditingController controller,
    String hint,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.white38, size: 20),
          hintText: hint,
          hintStyle: GoogleFonts.poppins(
            color: Colors.white.withValues(alpha: 0.3),
            fontSize: 14,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
        onChanged: (value) => setState(() {}),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.orbitron(
        color: Colors.white.withValues(alpha: 0.6),
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildPriceRow(
    String label,
    String value, {
    bool isTotal = false,
    Color? neonColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            color: isTotal ? Colors.white : Colors.white.withValues(alpha: 0.6),
            fontSize: isTotal ? 15 : 13,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: isTotal
              ? GoogleFonts.orbitron(
                  color: neonColor ?? const Color(0xFFFF7A1A),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                )
              : GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
        ),
      ],
    );
  }

  Widget _buildWhyBookWithUsCard(Color neonColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.08),
            Colors.white.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: neonColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: neonColor.withValues(alpha: 0.1),
            blurRadius: 20,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Row(
            children: [
              Icon(Icons.workspace_premium_rounded, color: neonColor, size: 24),
              const SizedBox(width: 10),
              Text(
                'Why Book With Us?',
                style: GoogleFonts.orbitron(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Without Platform
          Text(
            'If you go yourself:',
            style: GoogleFonts.poppins(
              color: Colors.red.withValues(alpha: 0.9),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          _buildBenefitItem(
            Icons.directions_car_rounded,
            'Car charges ₹300+',
            neonColor,
            isNegative: true,
          ),
          const SizedBox(height: 8),
          _buildBenefitItem(
            Icons.schedule_rounded,
            'Your valuable time wasted',
            neonColor,
            isNegative: true,
          ),
          const SizedBox(height: 8),
          _buildBenefitItem(
            Icons.money_off_rounded,
            'You may spend more money',
            neonColor,
            isNegative: true,
          ),
          const SizedBox(height: 8),
          _buildBenefitItem(
            Icons.verified_user_rounded,
            'No trusted professional guarantee',
            neonColor,
            isNegative: true,
          ),

          const SizedBox(height: 20),
          const Divider(color: Colors.white24),
          const SizedBox(height: 20),

          // With Platform
          Text(
            'With our platform:',
            style: GoogleFonts.poppins(
              color: Colors.green.withValues(alpha: 0.9),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          _buildBenefitItem(
            Icons.timer_rounded,
            'Save time',
            neonColor,
            isNegative: false,
          ),
          const SizedBox(height: 8),
          _buildBenefitItem(
            Icons.savings_rounded,
            'Save money',
            neonColor,
            isNegative: false,
          ),
          const SizedBox(height: 8),
          _buildBenefitItem(
            Icons.verified_rounded,
            'Get verified professionals',
            neonColor,
            isNegative: false,
          ),
          const SizedBox(height: 8),
          _buildBenefitItem(
            Icons.compare_arrows_rounded,
            'Compare multiple offers',
            neonColor,
            isNegative: false,
          ),
          const SizedBox(height: 8),
          _buildBenefitItem(
            Icons.handshake_rounded,
            'Easy counter offer system',
            neonColor,
            isNegative: false,
          ),
          const SizedBox(height: 8),
          _buildBenefitItem(
            Icons.home_rounded,
            'Doorstep service',
            neonColor,
            isNegative: false,
          ),

          const SizedBox(height: 20),

          // Bottom Highlight
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  neonColor.withValues(alpha: 0.2),
                  neonColor.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: neonColor.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.trending_down_rounded, color: neonColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  'You can save ₹300+ easily.',
                  style: GoogleFonts.orbitron(
                    color: neonColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(
    IconData icon,
    String text,
    Color neonColor, {
    required bool isNegative,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: (isNegative ? Colors.red : neonColor).withValues(
              alpha: 0.15,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: isNegative ? Colors.red : neonColor,
            size: 16,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePicker(Color neonColor) {
    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 14,
        itemBuilder: (context, index) {
          DateTime date = DateTime.now().add(Duration(days: index));
          bool isSelected =
              _selectedDate != null &&
              _selectedDate!.day == date.day &&
              _selectedDate!.month == date.month;

          return GestureDetector(
            onTap: () {
              setState(() => _selectedDate = date);
              _loadPartnerSchedule();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 65,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? neonColor
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? Colors.transparent
                      : Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _getMonthName(date.month),
                    style: GoogleFonts.poppins(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.8)
                          : Colors.white.withValues(alpha: 0.4),
                      fontSize: 9,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date.day.toString(),
                    style: GoogleFonts.orbitron(
                      color: isSelected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.7),
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _getDayName(date.weekday),
                    style: GoogleFonts.poppins(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.9)
                          : Colors.white.withValues(alpha: 0.4),
                      fontSize: 8,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _getMonthName(int month) {
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
    return months[month - 1];
  }

  String _getDayName(int day) {
    const days = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
    return days[day - 1];
  }

  @override
  void dispose() {
    _feeSub?.cancel();
    _descriptionController.dispose();
    _budgetController.dispose();
    super.dispose();
  }
}
