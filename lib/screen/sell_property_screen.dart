import 'package:firebase_auth/firebase_auth.dart';
import '../core/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../core/logging_service.dart';
import '../models/payment_method.dart';
import '../services/property_service.dart';
import '../services/fee_config_service.dart';
import '../widgets/premium_ui_widgets.dart';
import 'premium_payment_screen.dart';

class SellPropertyScreen extends StatefulWidget {
  final String? initialCategory;
  const SellPropertyScreen({super.key, this.initialCategory});

  @override
  State<SellPropertyScreen> createState() => _SellPropertyScreenState();
}

class _SellPropertyScreenState extends State<SellPropertyScreen> {
  static const _bg = Color(0xFF000000);
  static const _orange = Color(0xFFFF7A1A);
  static const _purple = Color(0xFF7D4CFF);

  int _currentStep =
      0; // This screen starts from logical Step 2 (Basic Details)
  final PageController _pageController = PageController();
  final PropertyService _service = PropertyService();
  final ImagePicker _picker = ImagePicker();
  bool _isSubmitting = false;

  // Basic Details (Step 2)
  final _titleController = TextEditingController();
  String _propertyFor = 'Sale';
  String _ownershipType = 'Owner';
  String _propertyCondition = 'New';

  // Category Specific Details (Step 3)
  final Map<String, dynamic> _categoryFields = {};

  // Location Details (Step 4)
  String _selectedTown = 'Mandi City';
  final _localityController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _houseNoController = TextEditingController();
  double? _lat;
  double? _lng;
  String? _pincode;
  GoogleMapController? _mapController;
  final LatLng _initialPosition = const LatLng(31.7087, 76.9320); // Mandi
  Marker? _propertyMarker;

  // Price & Property Info (Step 5)
  final _priceController = TextEditingController();
  String _priceUnit = 'Total Price';
  String _propertyStatus = 'Ready To Move';
  String _possession = 'Immediate';
  final List<String> _selectedAmenities = [];
  final List<String> _allAmenities = [
    'Parking',
    'Security',
    'Lift',
    'CCTV',
    'Garden',
    'Club House',
    'Power Backup',
    'Gym',
    'Swimming Pool',
    'Gated Society',
    'Temple Nearby',
    'School Nearby',
    'Hospital Nearby',
    'Market Nearby',
  ];
  final _descController = TextEditingController();
  bool _isPriceNegotiable = false;

  // Photos & Videos (Step 6)
  final List<XFile?> _propertyImages = List.generate(6, (_) => null);
  final List<XFile> _additionalImages = [];
  final List<XFile> _propertyProofImages = [];
  int _coverImageIndex = -1; // -1 means none selected or use first
  final _videoLinkController = TextEditingController();
  final _droneVideoLinkController = TextEditingController();
  final _virtualTourController = TextEditingController();

  // Final Step (Step 7)
  final _ownerNameController = TextEditingController();
  final _ownerPhoneController = TextEditingController();
  final _ownerWhatsappController = TextEditingController();
  final _ownerEmailController = TextEditingController();
  String _preferredContactMethod = 'Both';

  // Plan Selection (Step 8)
  String _selectedPlanId = 'free';
  String _selectedPlanDuration = 'Monthly'; // Weekly or Monthly
  bool _showPaymentGateway = false;
  bool _isConfirmed = false;
  bool _isPaid = false;

  late String _selectedType;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialCategory ?? 'Flat / Apartment';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _localityController.dispose();
    _landmarkController.dispose();
    _houseNoController.dispose();
    _descController.dispose();
    _ownerNameController.dispose();
    _ownerPhoneController.dispose();
    _ownerWhatsappController.dispose();
    _ownerEmailController.dispose();
    _videoLinkController.dispose();
    _droneVideoLinkController.dispose();
    _virtualTourController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _pickCategorizedImage(int index) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _propertyImages[index] = image;
      });
    }
  }

  Future<void> _pickAdditionalImages() async {
    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() {
        _additionalImages.addAll(images);
      });
    }
  }

  Future<void> _pickPropertyProof() async {
    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() {
        _propertyProofImages.addAll(images);
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error('Location permissions are permanently denied.');
    }

    final Position position = await Geolocator.getCurrentPosition();
    _updateLocation(LatLng(position.latitude, position.longitude));

    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(position.latitude, position.longitude),
        15,
      ),
    );
  }

  Future<void> _updateLocation(LatLng position) async {
    setState(() {
      _lat = position.latitude;
      _lng = position.longitude;
      _propertyMarker = Marker(
        markerId: const MarkerId('property_loc'),
        position: position,
        draggable: true,
        onDragEnd: (newPos) => _updateLocation(newPos),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      );
    });

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        setState(() {
          _pincode = placemarks.first.postalCode;
        });
      }
    } catch (e) {
      Log.e('SellPropertyScreen', 'Error fetching pincode: $e');
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final String tempId =
          '${user?.uid ?? "anon"}_${DateTime.now().millisecondsSinceEpoch}';
      List<String> imageUrls = [];

      List<XFile> allImages = [];
      for (var img in _propertyImages) {
        if (img != null) allImages.add(img);
      }
      allImages.addAll(_additionalImages);

      if (allImages.isNotEmpty) {
        imageUrls = await _service.uploadPropertyImages(tempId, allImages);
      }

      List<String> proofUrls = [];
      if (_propertyProofImages.isNotEmpty) {
        proofUrls = await _service.uploadPropertyImages(
          "${tempId}_proof",
          _propertyProofImages,
        );
      }

      // Auto-approve logic: Free or Featured plans are approved immediately.
      // Other plans (Verified, Banner, Premium, Elite) require admin approval.

      // Automatic Feature Activation Logic
      bool showFeaturedBadge = false;
      bool featuredSection = false;
      bool priorityListing = false;
      int searchBoost = 0;
      String propertyCardBorder = 'none';
      bool showVerifiedBadge = false;
      int trustScore = 0;
      bool verifiedSectionVisible = false;
      bool topSearchPlacement = false;
      bool priorityReview = false;
      bool premiumBadge = false;
      bool eliteBadge = false;
      bool dedicatedBroker = false;
      int visibilityScore = 0;

      if (_selectedPlanId == 'featured') {
        showFeaturedBadge = true;
        featuredSection = true;
        priorityListing = true;
        searchBoost = 20;
        visibilityScore = 20;
        propertyCardBorder = 'featured';
      } else if (_selectedPlanId == 'verified') {
        // showVerifiedBadge is true ONLY after admin approval
        trustScore = 15;
        visibilityScore = 15;
        propertyCardBorder = 'verified';
      } else if (_selectedPlanId == 'premium') {
        showFeaturedBadge = true;
        featuredSection = true;
        priorityListing = true;
        showVerifiedBadge = true;
        topSearchPlacement = true;
        priorityReview = true;
        premiumBadge = true;
        searchBoost = 50;
        visibilityScore = 50;
        propertyCardBorder = 'premium';
      } else if (_selectedPlanId == 'elite' ||
          _selectedPlanId == 'banner_request') {
        showFeaturedBadge = true;
        featuredSection = true;
        priorityListing = true;
        showVerifiedBadge = true;
        topSearchPlacement = true;
        priorityReview = true;
        dedicatedBroker = true;
        eliteBadge = true;
        searchBoost = 100;
        visibilityScore = 100;
        propertyCardBorder = 'elite';
      }

      // Add Recent Listing bonus
      visibilityScore += 10;

      // Add High Quality Photos bonus (if more than 5 images)
      if (imageUrls.length >= 5) {
        visibilityScore += 10;
      }

      final bool autoApprove =
          (_selectedPlanId == 'free' || _selectedPlanId == 'featured');

      final now = DateTime.now();
      final listingExpiry = now.add(const Duration(days: 30));
      DateTime? planExpiry;

      if (_selectedPlanId != 'free') {
        final durationDays = _selectedPlanDuration.toLowerCase() == 'weekly'
            ? 7
            : 30;
        planExpiry = now.add(Duration(days: durationDays));
      }

      final data = {
        'title': _titleController.text,
        'type': _selectedType,
        'category': _selectedType,
        'propertyFor': _propertyFor,
        'ownershipType': _ownershipType,
        'condition': _propertyCondition,
        'price':
            double.tryParse(_priceController.text.replaceAll(',', '')) ?? 0,
        'priceUnit': _priceUnit,
        'isNegotiable': _isPriceNegotiable,
        'propertyStatus': _propertyStatus,
        'possession': _possession,
        'amenities': _selectedAmenities,
        'videoLink': _videoLinkController.text,
        'droneVideoLink': _droneVideoLinkController.text,
        'virtualTourLink': _virtualTourController.text,
        'state': 'Himachal Pradesh',
        'district': 'Mandi',
        'town': _selectedTown,
        'locality': _localityController.text,
        'landmark': _landmarkController.text,
        'houseNo': _houseNoController.text,
        'latitude': _lat,
        'longitude': _lng,
        'pincode': _pincode,
        'location': '${_localityController.text}, $_selectedTown, Mandi, HP',
        'mapLocation': _lat != null ? '$_lat,$_lng' : '',
        'description': _descController.text,
        'ownerName': _ownerNameController.text,
        'ownerPhone': _ownerPhoneController.text,
        'ownerWhatsapp': _ownerWhatsappController.text,
        'ownerEmail': _ownerEmailController.text,
        'preferredContactMethod': _preferredContactMethod,
        'plan': _selectedPlanId,
        'planDuration': _selectedPlanDuration,
        'isPremium': _selectedPlanId != 'free',
        'showFeaturedBadge': showFeaturedBadge,
        'featuredSection': featuredSection,
        'priorityListing': priorityListing,
        'searchBoost': searchBoost,
        'propertyCardBorder': propertyCardBorder,
        'showVerifiedBadge': showVerifiedBadge,
        'isVerified': showVerifiedBadge,
        'trustScore': trustScore,
        'verifiedSectionVisible': verifiedSectionVisible,
        'topSearchPlacement': topSearchPlacement,
        'priorityReview': priorityReview,
        'premiumBadge': premiumBadge,
        'eliteBadge': eliteBadge,
        'dedicatedBroker': dedicatedBroker,
        'visibilityScore': visibilityScore,
        'images': imageUrls,
        'propertyProof': proofUrls,
        ..._categoryFields,
        'status': autoApprove ? 'available' : 'pending_approval',
        'isActive': autoApprove,
        'isFeatured':
            _selectedPlanId == 'featured' ||
            _selectedPlanId == 'premium' ||
            _selectedPlanId == 'banner_request',
        'createdAt': now.toIso8601String(),
        'listingExpiry': listingExpiry.toIso8601String(),
        'planExpiry': planExpiry?.toIso8601String(),
        'planStartTime': now.toIso8601String(),

        'area':
            _categoryFields['plotArea'] ??
            _categoryFields['builtUpArea'] ??
            _categoryFields['superArea'] ??
            _categoryFields['area'] ??
            '0',
      };

      await _service.submitSellerProperty(data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              autoApprove
                  ? 'Property listed successfully!'
                  : 'Property submitted for approval!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () {
            if (_currentStep > 0) {
              _pageController.previousPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          'SELL PROPERTY',
          style: GoogleFonts.orbitron(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Positioned(
            top: -50,
            right: -50,
            child: _GlowCircle(
              color: _purple.withValues(alpha: 0.1),
              size: 250,
            ),
          ),
          Positioned(
            bottom: 100,
            left: -50,
            child: _GlowCircle(
              color: _orange.withValues(alpha: 0.08),
              size: 200,
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (i) => setState(() => _currentStep = i),
                    children: [
                      _buildBasicDetails(),
                      _buildCategorySpecificDetails(),
                      _buildLocationDetails(),
                      _buildPriceAndPropertyInfo(),
                      _buildPhotosAndVideos(),
                      _buildFinalContact(),
                      _buildPlanSelection(),
                      _buildReviewAndSubmit(),
                    ],
                  ),
                ),
                if (!_showPaymentGateway) _buildBottomNav(),
              ],
            ),
          ),
          if (_showPaymentGateway) _buildPaymentGatewayOverlay(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    String title = "";
    String subtitle = "";
    int stepNum = _currentStep + 2;

    switch (_currentStep) {
      case 0:
        title = "BASIC PROPERTY DETAILS";
        subtitle = "Provide the primary details of your listing";
        break;
      case 1:
        title = "${_selectedType.toUpperCase()} DETAILS";
        subtitle = "Specific specifications for your property type";
        break;
      case 2:
        title = "LOCATION DETAILS";
        subtitle = "Mandatory details for Mandi District";
        break;
      case 3:
        title = "PRICE & PROPERTY INFO";
        subtitle = "Detailed valuation and property features";
        break;
      case 4:
        title = "PHOTOS & VIDEOS";
        subtitle = "Professional media for your listing";
        break;
      case 5:
        title = "FINAL CONTACT";
        subtitle = "Finalize your listing and contact info";
        break;
      case 6:
        title = "PLAN SELECTION";
        subtitle = "Choose a plan to boost your visibility";
        break;
      case 7:
        title = "REVIEW & SUBMIT";
        subtitle = "Verify your property details";
        break;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_orange, _purple]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'STEP $stepNum',
                  style: GoogleFonts.orbitron(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.orbitron(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 4,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: (stepNum) / 9,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_orange, _purple]),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildBasicDetails() {
    return _StepBody(
      children: [
        _buildTextField(
          'Property Title',
          Icons.title_rounded,
          controller: _titleController,
        ),
        const SizedBox(height: 25),
        _buildSegmentedControl(
          'Property For',
          ['Sale', 'Rent'],
          _propertyFor,
          (val) => setState(() => _propertyFor = val),
        ),
        const SizedBox(height: 25),
        _buildSegmentedControl(
          'Ownership Type',
          ['Owner', 'Builder', 'Broker'],
          _ownershipType,
          (val) => setState(() => _ownershipType = val),
        ),
        const SizedBox(height: 25),
        _buildSegmentedControl(
          'Property Condition',
          ['New', 'Resale', 'Under Construction'],
          _propertyCondition,
          (val) => setState(() => _propertyCondition = val),
        ),
      ],
    );
  }

  Widget _buildCategorySpecificDetails() {
    return _StepBody(children: _getCategorySpecificWidgets());
  }

  List<Widget> _getCategorySpecificWidgets() {
    switch (_selectedType) {
      case 'House':
        return [
          _buildRowFields([
            _buildSmallField('Plot Area', 'plotArea', Icons.landscape),
            _buildSmallField('Built Area', 'builtArea', Icons.home_work),
          ]),
          _buildRowFields([
            _buildSmallField('Bedrooms', 'bedrooms', Icons.bed, isNumber: true),
            _buildSmallField(
              'Bathrooms',
              'bathrooms',
              Icons.bathtub,
              isNumber: true,
            ),
          ]),
          _buildRowFields([
            _buildSmallField('Floors', 'floors', Icons.layers, isNumber: true),
          ]),
          _buildSwitch('Private Garden', 'garden'),
          _buildSwitch('Private Parking', 'parking'),
          _buildSwitch('Swimming Pool', 'pool'),
          const SizedBox(height: 15),
          _buildSegmentedControl(
            'Furnishing',
            ['Unfurnished', 'Semi Furnished', 'Fully Furnished'],
            _categoryFields['furnished'] ?? 'Unfurnished',
            (v) => setState(() => _categoryFields['furnished'] = v),
          ),
          const SizedBox(height: 15),
          _buildTextField(
            'Property Age',
            Icons.history,
            onChanged: (v) => _categoryFields['age'] = v,
          ),
        ];
      case 'Flat / Apartment':
        return [
          _buildRowFields([
            _buildSmallField('Plot Area', 'plotArea', Icons.landscape),
            _buildSmallField('Built Area', 'builtArea', Icons.home_work),
          ]),
          _buildRowFields([
            _buildSmallField('Bedrooms', 'bedrooms', Icons.bed, isNumber: true),
            _buildSmallField(
              'Bathrooms',
              'bathrooms',
              Icons.bathtub,
              isNumber: true,
            ),
          ]),
          _buildRowFields([
            _buildSmallField('Floors', 'floors', Icons.layers, isNumber: true),
          ]),
          _buildSwitch('Private Garden', 'garden'),
          _buildSwitch('Private Parking', 'parking'),
          _buildSwitch('Swimming Pool', 'pool'),
          const SizedBox(height: 15),
          _buildSegmentedControl(
            'Furnishing',
            ['Unfurnished', 'Semi Furnished', 'Fully Furnished'],
            _categoryFields['furnished'] ?? 'Unfurnished',
            (v) => setState(() => _categoryFields['furnished'] = v),
          ),
          const SizedBox(height: 15),
          _buildTextField(
            'Property Age',
            Icons.history,
            onChanged: (v) => _categoryFields['age'] = v,
          ),
        ];
      case 'Villa':
        return [
          _buildRowFields([
            _buildSmallField('Plot Area', 'plotArea', Icons.landscape),
            _buildSmallField('Built Area', 'builtArea', Icons.home_work),
          ]),
          _buildRowFields([
            _buildSmallField('Bedrooms', 'bedrooms', Icons.bed, isNumber: true),
            _buildSmallField(
              'Bathrooms',
              'bathrooms',
              Icons.bathtub,
              isNumber: true,
            ),
          ]),
          _buildRowFields([
            _buildSmallField('Floors', 'floors', Icons.layers, isNumber: true),
          ]),
          _buildSwitch('Private Garden', 'garden'),
          _buildSwitch('Private Parking', 'parking'),
          _buildSwitch('Swimming Pool', 'pool'),
          const SizedBox(height: 15),
          _buildSegmentedControl(
            'Furnishing',
            ['Unfurnished', 'Semi Furnished', 'Fully Furnished'],
            _categoryFields['furnished'] ?? 'Unfurnished',
            (v) => setState(() => _categoryFields['furnished'] = v),
          ),
          const SizedBox(height: 15),
          _buildTextField(
            'Property Age',
            Icons.history,
            onChanged: (v) => _categoryFields['age'] = v,
          ),
        ];
      case 'Plot / Land':
        return [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildTextField(
                  'Plot Area',
                  Icons.landscape,
                  onChanged: (v) => _categoryFields['plotArea'] = v,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDropdown(
                  'Unit',
                  ['Sq Ft', 'Sq Yard', 'Kanal', 'Marla', 'Bigha'],
                  _categoryFields['unit'] ?? 'Sq Ft',
                  (v) => setState(() => _categoryFields['unit'] = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          _buildTextField(
            'Road Width',
            Icons.add_road,
            onChanged: (v) => _categoryFields['roadWidth'] = v,
          ),
          const SizedBox(height: 15),
          _buildSwitch('Corner Plot', 'cornerPlot'),
          _buildTextField(
            'Facing Direction',
            Icons.explore,
            onChanged: (v) => _categoryFields['facing'] = v,
          ),
          const SizedBox(height: 15),
          _buildSwitch('Boundary Wall', 'boundaryWall'),
          _buildSwitch('Water Available', 'water'),
          _buildSwitch('Electricity Available', 'electricity'),
          const SizedBox(height: 15),
          _buildSegmentedControl(
            'Land Type',
            ['Residential', 'Commercial', 'Agricultural'],
            _categoryFields['landType'] ?? 'Residential',
            (v) => setState(() => _categoryFields['landType'] = v),
          ),
        ];
      case 'Shop / Showroom':
        return [
          _buildTextField(
            'Shop Area',
            Icons.square_foot,
            onChanged: (v) => _categoryFields['area'] = v,
          ),
          const SizedBox(height: 15),
          _buildTextField(
            'Front Width',
            Icons.straighten,
            onChanged: (v) => _categoryFields['width'] = v,
          ),
          const SizedBox(height: 15),
          _buildTextField(
            'Floor',
            Icons.layers,
            isNumber: true,
            onChanged: (v) => _categoryFields['floor'] = v,
          ),
          const SizedBox(height: 15),
          _buildTextField(
            'Washroom',
            Icons.wc,
            isNumber: true,
            onChanged: (v) => _categoryFields['washroom'] = v,
          ),
          const SizedBox(height: 15),
          _buildSwitch('Main Road Facing', 'mainRoad'),
          _buildSwitch('Corner Shop', 'corner'),
          _buildTextField(
            'Parking',
            Icons.local_parking,
            onChanged: (v) => _categoryFields['parking'] = v,
          ),
          const SizedBox(height: 15),
          _buildTextField(
            'Storage Space',
            Icons.inventory_2,
            onChanged: (v) => _categoryFields['storage'] = v,
          ),
        ];
      case 'Commercial Building':
        return [
          _buildTextField(
            'Total Floors',
            Icons.layers,
            isNumber: true,
            onChanged: (v) => _categoryFields['floors'] = v,
          ),
          const SizedBox(height: 15),
          _buildTextField(
            'Total Area',
            Icons.square_foot,
            onChanged: (v) => _categoryFields['area'] = v,
          ),
          const SizedBox(height: 15),
          _buildSwitch('Lift', 'lift'),
          _buildTextField(
            'Parking',
            Icons.local_parking,
            onChanged: (v) => _categoryFields['parking'] = v,
          ),
          const SizedBox(height: 15),
          _buildTextField(
            'Number Of Offices',
            Icons.work,
            isNumber: true,
            onChanged: (v) => _categoryFields['offices'] = v,
          ),
          const SizedBox(height: 15),
          _buildTextField(
            'Number Of Shops',
            Icons.store,
            isNumber: true,
            onChanged: (v) => _categoryFields['shops'] = v,
          ),
          const SizedBox(height: 15),
          _buildTextField(
            'Occupancy Status',
            Icons.info,
            onChanged: (v) => _categoryFields['occupancy'] = v,
          ),
        ];
      case 'Office Space':
        return [
          _buildTextField(
            'Office Area',
            Icons.square_foot,
            onChanged: (v) => _categoryFields['area'] = v,
          ),
          const SizedBox(height: 15),
          _buildTextField(
            'Floor',
            Icons.layers,
            isNumber: true,
            onChanged: (v) => _categoryFields['floor'] = v,
          ),
          const SizedBox(height: 15),
          _buildTextField(
            'Cabins',
            Icons.room,
            isNumber: true,
            onChanged: (v) => _categoryFields['cabins'] = v,
          ),
          const SizedBox(height: 15),
          _buildTextField(
            'Workstations',
            Icons.computer,
            isNumber: true,
            onChanged: (v) => _categoryFields['workstations'] = v,
          ),
          const SizedBox(height: 15),
          _buildSwitch('Conference Room', 'conference'),
          _buildSwitch('Reception', 'reception'),
          _buildTextField(
            'Parking',
            Icons.local_parking,
            onChanged: (v) => _categoryFields['parking'] = v,
          ),
          const SizedBox(height: 15),
          _buildSegmentedControl(
            'Furnished Status',
            ['Unfurnished', 'Semi Furnished', 'Fully Furnished'],
            _categoryFields['furnished'] ?? 'Unfurnished',
            (v) => setState(() => _categoryFields['furnished'] = v),
          ),
        ];
      case 'Warehouse':
        return [
          _buildTextField(
            'Warehouse Area',
            Icons.square_foot,
            onChanged: (v) => _categoryFields['area'] = v,
          ),
          const SizedBox(height: 15),
          _buildTextField(
            'Ceiling Height',
            Icons.height,
            onChanged: (v) => _categoryFields['height'] = v,
          ),
          const SizedBox(height: 15),
          _buildSwitch('Loading Dock', 'loadingDock'),
          _buildSwitch('Truck Access', 'truckAccess'),
          _buildTextField(
            'Parking',
            Icons.local_parking,
            onChanged: (v) => _categoryFields['parking'] = v,
          ),
          const SizedBox(height: 15),
          _buildSwitch('Electricity Connection', 'electricity'),
          _buildSwitch('Water Connection', 'water'),
        ];
      case 'PG / Hostel':
        return [
          _buildTextField(
            'Total Rooms',
            Icons.door_front_door,
            isNumber: true,
            onChanged: (v) => _categoryFields['rooms'] = v,
          ),
          const SizedBox(height: 15),
          _buildTextField(
            'Beds Per Room',
            Icons.bed,
            isNumber: true,
            onChanged: (v) => _categoryFields['beds'] = v,
          ),
          const SizedBox(height: 15),
          _buildSwitch('Attached Bathroom', 'attachedBath'),
          _buildSwitch('Mess Available', 'mess'),
          _buildSwitch('Wifi Available', 'wifi'),
          _buildTextField(
            'Parking',
            Icons.local_parking,
            onChanged: (v) => _categoryFields['parking'] = v,
          ),
          const SizedBox(height: 15),
          _buildTextField(
            'Security',
            Icons.security,
            onChanged: (v) => _categoryFields['security'] = v,
          ),
        ];
      case 'Rental Property':
        return [
          _buildTextField(
            'Property Type',
            Icons.home,
            onChanged: (v) => _categoryFields['rentType'] = v,
          ),
          const SizedBox(height: 15),
          _buildTextField(
            'Monthly Rent',
            Icons.currency_rupee,
            isNumber: true,
            onChanged: (v) => _categoryFields['rent'] = v,
          ),
          const SizedBox(height: 15),
          _buildTextField(
            'Security Deposit',
            Icons.savings,
            isNumber: true,
            onChanged: (v) => _categoryFields['deposit'] = v,
          ),
          const SizedBox(height: 15),
          _buildTextField(
            'Available From',
            Icons.calendar_today,
            onChanged: (v) => _categoryFields['availableFrom'] = v,
          ),
          const SizedBox(height: 20),
          _buildSegmentedControl(
            'Preferred Tenant',
            ['Family', 'Students', 'Working Professional'],
            _categoryFields['tenant'] ?? 'Family',
            (v) => setState(() => _categoryFields['tenant'] = v),
          ),
        ];
      default:
        return [
          const Text(
            'Details coming soon...',
            style: TextStyle(color: Colors.white54),
          ),
        ];
    }
  }

  Widget _buildLocationDetails() {
    return _StepBody(
      children: [
        // Platform Restriction Note
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _orange.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _orange.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: _orange, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Platform operates only in Mandi District, HP.',
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 25),

        Row(
          children: [
            Expanded(
              child: _buildReadOnlyField(
                'State',
                'Himachal Pradesh',
                Icons.map_rounded,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _buildReadOnlyField(
                'District',
                'Mandi',
                Icons.location_city_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 25),

        _buildTownDropdown(),
        const SizedBox(height: 20),

        _buildTextField(
          'Search or enter village',
          Icons.holiday_village_rounded,
          controller: _localityController,
          hintLabel: 'Locality / Village',
        ),
        const SizedBox(height: 20),

        _buildTextField(
          'Nearby landmark',
          Icons.assistant_photo_rounded,
          controller: _landmarkController,
          hintLabel: 'Landmark',
        ),
        const SizedBox(height: 20),

        _buildTextField(
          'House No / Building Name',
          Icons.home_rounded,
          controller: _houseNoController,
          hintLabel: 'House Number / Building Name',
        ),
        const SizedBox(height: 30),

        _buildMapPicker(),
      ],
    );
  }

  Widget _buildReadOnlyField(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white38,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Row(
            children: [
              Icon(icon, color: _orange.withValues(alpha: 0.5), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  value,
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTownDropdown() {
    final towns = [
      'Mandi City',
      'Ner Chowk',
      'Sundernagar',
      'Jogindernagar',
      'Sarkaghat',
      'Karsog',
      'Padhar',
      'Rewalsar',
      'Gohar',
      'Kotli',
      'Balh',
      'Dharampur',
      'Thunag',
      'Aut',
      'Other',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Town / Area',
          style: GoogleFonts.poppins(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        _buildDropdown(
          'Select Town',
          towns,
          _selectedTown,
          (v) => setState(() => _selectedTown = v!),
        ),
      ],
    );
  }

  Widget _buildMapPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Property Location on Map',
          style: GoogleFonts.poppins(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          height: 280,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.black38,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _purple.withValues(alpha: 0.3)),
          ),
          child: Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _initialPosition,
                  zoom: 12,
                ),
                onMapCreated: (controller) => _mapController = controller,
                onTap: _updateLocation,
                markers: _propertyMarker != null ? {_propertyMarker!} : {},
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapType: MapType.normal,
                style: _darkMapStyle,
                gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                  Factory<OneSequenceGestureRecognizer>(
                    () => EagerGestureRecognizer(),
                  ),
                },
              ),

              // Map UI Badges
              Positioned(
                top: 15,
                left: 15,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: _getCurrentLocation,
                      child: _buildMapBadge(
                        Icons.my_location,
                        'Use Current Location',
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildMapBadge(Icons.touch_app, 'Tap Map to Place Pin'),
                  ],
                ),
              ),

              if (_lat != null)
                Positioned(
                  top: 15,
                  right: 15,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.greenAccent.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Colors.greenAccent,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'PIN DROPPED',
                              style: GoogleFonts.orbitron(
                                color: Colors.greenAccent,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _lat = null;
                            _lng = null;
                            _pincode = null;
                            _propertyMarker = null;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.redAccent.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.location_off_rounded,
                                color: Colors.redAccent,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'REMOVE PIN',
                                style: GoogleFonts.orbitron(
                                  color: Colors.redAccent,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (_lat != null) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Lat: ${_lat!.toStringAsFixed(4)}, Lng: ${_lng!.toStringAsFixed(4)}',
                      style: GoogleFonts.poppins(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                    if (_pincode != null)
                      Text(
                        'Pincode: $_pincode',
                        style: GoogleFonts.poppins(
                          color: _purple.withValues(alpha: 0.8),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  final String _darkMapStyle = '''
[
  {
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#212121"
      }
    ]
  },
  {
    "elementType": "labels.icon",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  },
  {
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#757575"
      }
    ]
  },
  {
    "elementType": "labels.text.stroke",
    "stylers": [
      {
        "color": "#212121"
      }
    ]
  },
  {
    "featureType": "administrative",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#757575"
      }
    ]
  },
  {
    "featureType": "landscape",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#121212"
      }
    ]
  },
  {
    "featureType": "poi",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#121212"
      }
    ]
  },
  {
    "featureType": "poi",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#757575"
      }
    ]
  },
  {
    "featureType": "road",
    "elementType": "geometry.fill",
    "stylers": [
      {
        "color": "#2c2c2c"
      }
    ]
  },
  {
    "featureType": "road",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#8a8a8a"
      }
    ]
  },
  {
    "featureType": "water",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#000000"
      }
    ]
  },
  {
    "featureType": "water",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#3d3d3d"
      }
    ]
  }
]
''';

  Widget _buildMapBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _purple, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceAndPropertyInfo() {
    return _StepBody(
      children: [
        Text(
          'Price Details',
          style: GoogleFonts.orbitron(
            color: _orange,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 15),
        _buildTextField(
          'Expected Price',
          Icons.currency_rupee_rounded,
          keyboardType: TextInputType.number,
          controller: _priceController,
        ),
        const SizedBox(height: 15),
        _buildDropdown(
          'Price Unit',
          ['Total Price', 'Per Sq Ft', 'Per Sq Yard', 'Per Bigha'],
          _priceUnit,
          (v) => setState(() => _priceUnit = v!),
        ),
        const SizedBox(height: 10),
        _buildSwitch('Is Price Negotiable?', '_isPriceNegotiable_local'),

        const SizedBox(height: 25),
        Text(
          'Property Status',
          style: GoogleFonts.orbitron(
            color: _orange,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 15),
        _buildSegmentedControl(
          '',
          ['Ready To Move', 'Under Construction', 'Newly Built', 'Resale'],
          _propertyStatus,
          (val) => setState(() => _propertyStatus = val),
        ),

        const SizedBox(height: 25),
        Text(
          'Possession',
          style: GoogleFonts.orbitron(
            color: _orange,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 15),
        _buildSegmentedControl(
          '',
          ['Immediate', 'Within 3 Months', 'Within 6 Months'],
          _possession,
          (val) => setState(() => _possession = val),
        ),

        const SizedBox(height: 25),
        Text(
          'Amenities',
          style: GoogleFonts.orbitron(
            color: _orange,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 15),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _allAmenities.map((amenity) {
            final isSelected = _selectedAmenities.contains(amenity);
            return FilterChip(
              label: Text(
                amenity,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: isSelected ? Colors.white : Colors.white60,
                ),
              ),
              selected: isSelected,
              onSelected: (bool selected) {
                setState(() {
                  if (selected) {
                    _selectedAmenities.add(amenity);
                  } else {
                    _selectedAmenities.remove(amenity);
                  }
                });
              },
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              selectedColor: _purple.withValues(alpha: 0.5),
              checkmarkColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: isSelected ? _purple : Colors.white12),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: _showAddAmenityDialog,
          icon: const Icon(Icons.add, size: 18, color: _purple),
          label: Text(
            'Add More Amenities',
            style: GoogleFonts.poppins(
              color: _purple,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        const SizedBox(height: 25),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Property Description',
              style: GoogleFonts.orbitron(
                color: _orange,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            GestureDetector(
              onTap: _suggestAIDescription,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_purple, Color(0xFF9D7CFF)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'AI SUGGEST',
                      style: GoogleFonts.orbitron(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        _buildTextField(
          'Detailed property description...',
          Icons.notes_rounded,
          maxLines: 5,
          controller: _descController,
        ),
      ],
    );
  }

  void _showAddAmenityDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1C),
        title: Text(
          'Add Amenity',
          style: GoogleFonts.orbitron(color: Colors.white, fontSize: 16),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter amenity name',
            hintStyle: const TextStyle(color: Colors.white38),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: _orange.withValues(alpha: 0.5)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'CANCEL',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(() {
                  _allAmenities.add(controller.text);
                  _selectedAmenities.add(controller.text);
                });
                Navigator.pop(context);
              }
            },
            child: const Text('ADD', style: TextStyle(color: _orange)),
          ),
        ],
      ),
    );
  }

  void _suggestAIDescription() {
    // Mock AI Suggestion based on available data
    String suggestion =
        "This beautiful $_selectedType is located in $_selectedTown, Mandi. ";
    suggestion +=
        "It features $_propertyStatus status and is ready for $_possession possession. ";
    if (_selectedAmenities.isNotEmpty) {
      suggestion +=
          "Key amenities include ${_selectedAmenities.take(3).join(', ')} and more. ";
    }
    suggestion +=
        "Perfect for those looking for a premium property in Himachal Pradesh.";

    setState(() {
      _descController.text = suggestion;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('AI description generated!'),
        backgroundColor: Colors.purple,
      ),
    );
  }

  Widget _buildPhotosAndVideos() {
    int totalUploaded =
        _propertyImages.where((v) => v != null).length +
        _additionalImages.length;
    double progress = (totalUploaded / 3).clamp(0.0, 1.0);

    return _StepBody(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Upload Section',
              style: GoogleFonts.orbitron(
                color: _orange,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: totalUploaded >= 3
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$totalUploaded / 3 MIN',
                style: GoogleFonts.orbitron(
                  color: totalUploaded >= 3
                      ? Colors.greenAccent
                      : Colors.redAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white.withValues(alpha: 0.05),
            valueColor: AlwaysStoppedAnimation<Color>(
              totalUploaded >= 3 ? Colors.greenAccent : _orange,
            ),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 15),
        Text(
          'Long press to set as Cover Photo',
          style: GoogleFonts.poppins(color: Colors.white38, fontSize: 10),
        ),
        const SizedBox(height: 15),

        // Image Slots
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 6,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 15,
            crossAxisSpacing: 15,
            childAspectRatio: 1.2,
          ),
          itemBuilder: (context, index) => _buildPhotoSlot(index),
        ),

        const SizedBox(height: 25),
        Text(
          'Additional Photos',
          style: GoogleFonts.orbitron(
            color: _orange,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 15),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _additionalImages.length + 1,
            itemBuilder: (context, index) {
              if (index == _additionalImages.length) {
                return _buildAddMoreThumbSlot();
              }
              return _buildAdditionalImageThumb(index);
            },
          ),
        ),

        const SizedBox(height: 35),
        Text(
          'Video & Virtual Tours',
          style: GoogleFonts.orbitron(
            color: _orange,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 20),
        _buildTextField(
          'YouTube / Video Link',
          Icons.play_circle_fill_rounded,
          controller: _videoLinkController,
        ),
        const SizedBox(height: 15),
        _buildTextField(
          'Drone Video Link',
          Icons.screenshot_monitor_rounded,
          controller: _droneVideoLinkController,
        ),
        const SizedBox(height: 15),
        _buildTextField(
          'Virtual Tour URL',
          Icons.view_in_ar_rounded,
          controller: _virtualTourController,
        ),

        const SizedBox(height: 30),
        _buildPhotoQualityCard(),
      ],
    );
  }

  Widget _buildPhotoSlot(int index) {
    final file = _propertyImages[index];
    final bool isCover = _coverImageIndex == index;
    final String label = "Image ${index + 1}";

    return GestureDetector(
      onTap: () => _pickCategorizedImage(index),
      onLongPress: file != null
          ? () => setState(() => _coverImageIndex = index)
          : null,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isCover
                ? _orange
                : (file != null
                      ? _purple.withValues(alpha: 0.5)
                      : Colors.white12),
            width: isCover ? 2 : 1.5,
          ),
        ),
        child: file != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.file(File(file.path), fit: BoxFit.cover),
                  ),
                  if (isCover)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _orange,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'COVER',
                          style: GoogleFonts.orbitron(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _propertyImages[index] = null;
                        if (_coverImageIndex == index) _coverImageIndex = -1;
                      }),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(18),
                          bottomRight: Radius.circular(18),
                        ),
                      ),
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_a_photo_outlined,
                    color: _orange.withValues(alpha: 0.5),
                    size: 28,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      color: Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildAdditionalImageThumb(int index) {
    final bool isCover =
        _coverImageIndex == index + 6; // Property Images are 0-5
    return GestureDetector(
      onTap: () => setState(() => _coverImageIndex = index + 6),
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCover ? _orange : Colors.white24,
            width: isCover ? 2 : 1,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.file(
                File(_additionalImages[index].path),
                fit: BoxFit.cover,
              ),
            ),
            if (isCover)
              Positioned(
                top: 5,
                left: 5,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _orange,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'COVER',
                    style: GoogleFonts.orbitron(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            Positioned(
              top: 5,
              right: 5,
              child: GestureDetector(
                onTap: () => setState(() {
                  _additionalImages.removeAt(index);
                  if (_coverImageIndex == index + 6) {
                    _coverImageIndex = -1;
                  } else if (_coverImageIndex > index + 6)
                    _coverImageIndex--;
                }),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.black87,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddMoreThumbSlot() {
    return GestureDetector(
      onTap: _pickAdditionalImages,
      child: Container(
        width: 100,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12, style: BorderStyle.solid),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_rounded, color: Colors.white38, size: 30),
            Text(
              'Add More',
              style: GoogleFonts.poppins(color: Colors.white38, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoQualityCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _purple.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _purple.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.high_quality_rounded,
            color: Colors.greenAccent,
            size: 24,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Photo Quality Checker',
                  style: GoogleFonts.orbitron(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'AI ensures your photos meet premium listing standards.',
                  style: GoogleFonts.poppins(
                    color: Colors.white54,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinalContact() {
    return _StepBody(
      children: [
        Text(
          'Owner Details',
          style: GoogleFonts.orbitron(
            color: _orange,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 25),
        _buildTextField(
          'Full Name',
          Icons.person_rounded,
          controller: _ownerNameController,
        ),
        const SizedBox(height: 15),
        _buildTextField(
          'Mobile Number',
          Icons.phone_rounded,
          keyboardType: TextInputType.phone,
          controller: _ownerPhoneController,
        ),
        const SizedBox(height: 15),
        _buildTextField(
          'WhatsApp Number',
          Icons.chat_rounded,
          keyboardType: TextInputType.phone,
          controller: _ownerWhatsappController,
        ),
        const SizedBox(height: 15),
        _buildTextField(
          'Email Address',
          Icons.email_rounded,
          keyboardType: TextInputType.emailAddress,
          controller: _ownerEmailController,
        ),

        const SizedBox(height: 30),
        _buildSegmentedControl(
          'Preferred Contact Method',
          ['Call', 'WhatsApp', 'Both'],
          _preferredContactMethod,
          (val) => setState(() => _preferredContactMethod = val),
        ),

        const SizedBox(height: 30),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            children: [
              Text(
                'Almost Done!',
                style: GoogleFonts.orbitron(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Review your property details before submitting for approval. Our team typically reviews listings within 24 hours.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNav() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: NeonButton(
                text: 'BACK',
                isSecondary: true,
                onPressed: () => _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                ),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 15),
          Expanded(
            flex: 2,
            child: NeonButton(
              text: _isSubmitting
                  ? 'UPLOADING...'
                  : (_currentStep < 7
                        ? (_currentStep == 6
                              ? (_selectedPlanId == 'free'
                                    ? 'CONTINUE'
                                    : (_isPaid ? 'CONTINUE' : 'PAY & CONTINUE'))
                              : 'CONTINUE')
                        : 'SUBMIT PROPERTY'),
              onPressed: (_isSubmitting || (_currentStep == 7 && !_isConfirmed))
                  ? null
                  : () {
                      if (_currentStep < 7) {
                        // Step 0: Basic Details
                        if (_currentStep == 0) {
                          if (_titleController.text.trim().isEmpty) {
                            _showError('Please enter a property title');
                            return;
                          }
                        }

                        // Step 3 (index 1): Category Specific Details
                        if (_currentStep == 1) {
                          final missing = <String>[];
                          if (_categoryFields['plotArea'] == null ||
                              (_categoryFields['plotArea'] as String)
                                  .trim()
                                  .isEmpty) {
                            missing.add('Plot Area');
                          }
                          if (_selectedType != 'Plot / Land' &&
                              (_categoryFields['builtArea'] == null ||
                                  (_categoryFields['builtArea'] as String)
                                      .trim()
                                      .isEmpty)) {
                            missing.add('Built Area');
                          }
                          if (_selectedType != 'Plot / Land' &&
                              _selectedType != 'Shop / Showroom' &&
                              _selectedType != 'Commercial Building' &&
                              _selectedType != 'Office Space' &&
                              _selectedType != 'Warehouse' &&
                              _selectedType != 'PG / Hostel' &&
                              _selectedType != 'Rental Property') {
                            if (_categoryFields['bedrooms'] == null ||
                                (_categoryFields['bedrooms'] as String)
                                    .trim()
                                    .isEmpty) {
                              missing.add('Bedrooms');
                            }
                          }
                          if (_selectedType == 'Plot / Land' &&
                              (_categoryFields['plotArea'] == null ||
                                  (_categoryFields['plotArea'] as String)
                                      .trim()
                                      .isEmpty)) {
                            missing.add('Plot Area');
                          }
                          if (_selectedType == 'Shop / Showroom' &&
                              (_categoryFields['area'] == null ||
                                  (_categoryFields['area'] as String)
                                      .trim()
                                      .isEmpty)) {
                            missing.add('Shop Area');
                          }
                          if (_selectedType == 'Commercial Building' &&
                              (_categoryFields['area'] == null ||
                                  (_categoryFields['area'] as String)
                                      .trim()
                                      .isEmpty)) {
                            missing.add('Total Area');
                          }
                          if (_selectedType == 'Office Space' &&
                              (_categoryFields['area'] == null ||
                                  (_categoryFields['area'] as String)
                                      .trim()
                                      .isEmpty)) {
                            missing.add('Office Area');
                          }
                          if (_selectedType == 'Warehouse' &&
                              (_categoryFields['area'] == null ||
                                  (_categoryFields['area'] as String)
                                      .trim()
                                      .isEmpty)) {
                            missing.add('Warehouse Area');
                          }
                          if (_selectedType == 'PG / Hostel' &&
                              (_categoryFields['rooms'] == null ||
                                  (_categoryFields['rooms'] as String)
                                      .trim()
                                      .isEmpty)) {
                            missing.add('Total Rooms');
                          }
                          if (_selectedType == 'Rental Property' &&
                              (_categoryFields['rent'] == null ||
                                  (_categoryFields['rent'] as String)
                                      .trim()
                                      .isEmpty)) {
                            missing.add('Monthly Rent');
                          }
                          if (missing.isNotEmpty) {
                            _showError('Please fill: ${missing.join(', ')}');
                            return;
                          }
                        }

                        // Step 4 (index 2): Location Details
                        if (_currentStep == 2) {
                          if (_localityController.text.trim().isEmpty) {
                            _showError('Please enter locality / village');
                            return;
                          }
                          if (_landmarkController.text.trim().isEmpty) {
                            _showError('Please enter a nearby landmark');
                            return;
                          }
                          if (_houseNoController.text.trim().isEmpty) {
                            _showError('Please enter house no / building name');
                            return;
                          }
                          if (_lat == null) {
                            _showError(
                              'Please drop a pin on the map to mark property location',
                            );
                            return;
                          }
                        }

                        // Step 5 (index 3): Price & Property Info
                        if (_currentStep == 3) {
                          if (_priceController.text.trim().isEmpty) {
                            _showError('Please enter the expected price');
                            return;
                          }
                        }

                        // Step 6 (index 4): Photos & Videos
                        if (_currentStep == 4) {
                          int total =
                              _propertyImages.where((v) => v != null).length +
                              _additionalImages.length;
                          if (total < 3) {
                            _showError('Please upload at least 3 photos');
                            return;
                          }
                        }

                        // Step 5 (index 5): Final Contact
                        if (_currentStep == 5) {
                          if (_ownerNameController.text.trim().isEmpty) {
                            _showError('Please enter your full name');
                            return;
                          }
                          if (_ownerPhoneController.text.trim().isEmpty) {
                            _showError('Please enter your mobile number');
                            return;
                          }
                          if (_ownerPhoneController.text.trim().length < 10) {
                            _showError(
                              'Please enter a valid 10-digit mobile number',
                            );
                            return;
                          }
                        }

                        // Plan Selection Logic (Step 8/index 6)
                        if (_currentStep == 6) {
                          if (_selectedPlanId == 'free' || _isPaid) {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          } else {
                            setState(() => _showPaymentGateway = true);
                          }
                          return;
                        }

                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      } else {
                        _submit();
                      }
                    },
            ),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.withValues(alpha: 0.9),
      ),
    );
  }

  Widget _buildReviewAndSubmit() {
    return _StepBody(
      children: [
        _buildReviewSection('Property Type & Basic', [
          _buildReviewItem('Title', _titleController.text),
          _buildReviewItem('Type', _selectedType),
          _buildReviewItem('Purpose', _propertyFor),
          _buildReviewItem('Ownership', _ownershipType),
          _buildReviewItem('Condition', _propertyCondition),
        ], 0),

        _buildReviewSection('Location', [
          _buildReviewItem('Town', _selectedTown),
          _buildReviewItem('Locality', _localityController.text),
          _buildReviewItem(
            'Address',
            '${_houseNoController.text}, ${_landmarkController.text}',
          ),
          _buildReviewItem('District', 'Mandi, HP'),
          if (_lat != null)
            _buildReviewItem('GPS', 'Coordinates Set', isStatus: true),
        ], 2),

        _buildReviewSection('Pricing & Area', [
          _buildReviewItem('Price', '₹${_priceController.text} $_priceUnit'),
          _buildReviewItem('Negotiable', _isPriceNegotiable ? 'Yes' : 'No'),
          ..._categoryFields.entries
              .where((e) => e.key.toLowerCase().contains('area'))
              .map(
                (e) => _buildReviewItem(_formatKey(e.key), e.value.toString()),
              ),
        ], 3),

        _buildReviewSection('Property Details', [
          _buildReviewItem('Status', _propertyStatus),
          _buildReviewItem('Possession', _possession),
          ..._categoryFields.entries
              .where(
                (e) =>
                    !e.key.toLowerCase().contains('area') && e.value is! bool,
              )
              .map(
                (e) => _buildReviewItem(_formatKey(e.key), e.value.toString()),
              ),
        ], 1),

        _buildReviewSection('Features & Amenities', [
          if (_selectedAmenities.isNotEmpty) ...[
            Text(
              'AMENITIES',
              style: GoogleFonts.poppins(
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedAmenities
                  .map((a) => _buildBadge(a, _purple))
                  .toList(),
            ),
            const SizedBox(height: 12),
          ],
          if (_categoryFields.entries.any((e) => e.value == true)) ...[
            Text(
              'SPECIFICATIONS',
              style: GoogleFonts.poppins(
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categoryFields.entries
                  .where((e) => e.value == true)
                  .map((e) => _buildBadge(_formatKey(e.key), _orange))
                  .toList(),
            ),
          ],
          if (_selectedAmenities.isEmpty &&
              !_categoryFields.entries.any((e) => e.value == true))
            _buildReviewItem('Features', 'None Specified'),
        ], 3),

        _buildReviewSection('Media', [
          _buildReviewItem(
            'Photos',
            '${_propertyImages.where((v) => v != null).length + _additionalImages.length} Uploaded',
          ),
          if (_videoLinkController.text.isNotEmpty)
            _buildReviewItem('Video', 'Link Provided', isStatus: true),
          if (_droneVideoLinkController.text.isNotEmpty)
            _buildReviewItem('Drone', 'Link Provided', isStatus: true),
          if (_virtualTourController.text.isNotEmpty)
            _buildReviewItem('360 Tour', 'Link Provided', isStatus: true),
        ], 4),

        _buildReviewSection('Contact Details', [
          _buildReviewItem('Owner', _ownerNameController.text),
          _buildReviewItem('Phone', _ownerPhoneController.text),
          _buildReviewItem('WhatsApp', _ownerWhatsappController.text),
          _buildReviewItem('Email', _ownerEmailController.text),
          _buildReviewItem('Preferred', _preferredContactMethod),
        ], 5),

        _buildReviewSection('Selected Promotion', [
          _buildReviewItem('Plan', _selectedPlanId.toUpperCase()),
          _buildReviewItem('Duration', _selectedPlanDuration),
          _buildReviewItem('Amount', '₹${_getPlanPrice().toInt()}'),
          if (_isPaid) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.greenAccent.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.greenAccent,
                    size: 12,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'PAID',
                    style: GoogleFonts.orbitron(
                      color: Colors.greenAccent,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ], 6),

        const SizedBox(height: 20),
        if (['verified', 'premium', 'elite'].contains(_selectedPlanId) &&
            _isPaid) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.blueAccent.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.verified_user_rounded,
                      color: Colors.blueAccent,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'PROPERTY PROOF REQUIRED',
                      style: GoogleFonts.orbitron(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Please upload property documents, registry, or utility bills for verification.',
                  style: GoogleFonts.poppins(
                    color: Colors.white60,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 15),
                if (_propertyProofImages.isNotEmpty) ...[
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _propertyProofImages.length,
                      itemBuilder: (context, index) {
                        return Stack(
                          children: [
                            Container(
                              margin: const EdgeInsets.only(right: 10),
                              width: 80,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                image: DecorationImage(
                                  image: FileImage(
                                    File(_propertyProofImages[index].path),
                                  ),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 2,
                              right: 12,
                              child: GestureDetector(
                                onTap: () => setState(
                                  () => _propertyProofImages.removeAt(index),
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 15),
                ],
                NeonButton(
                  text: _propertyProofImages.isEmpty
                      ? 'UPLOAD PROOF'
                      : 'ADD MORE PROOF',
                  isSecondary: true,
                  onPressed: _pickPropertyProof,
                ),
              ],
            ),
          ),
        ],
        _buildConfirmationCheckbox(),
      ],
    );
  }

  String _formatKey(String key) {
    return key.replaceAll(RegExp(r'(?=[A-Z])'), ' ').trim().toUpperCase();
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  double _getPlanPrice() {
    double price = 0;
    if (_selectedPlanId == 'featured') {
      price = _selectedPlanDuration == 'Weekly'
          ? FeeConfigService.listingFeaturedWeekly
          : FeeConfigService.listingFeaturedMonthly;
    } else if (_selectedPlanId == 'verified')
      price = _selectedPlanDuration == 'Weekly'
          ? FeeConfigService.listingVerifiedWeekly
          : FeeConfigService.listingVerifiedMonthly;
    else if (_selectedPlanId == 'banner_request')
      price = _selectedPlanDuration == 'Weekly'
          ? FeeConfigService.listingBannerWeekly
          : FeeConfigService.listingBannerMonthly;
    else if (_selectedPlanId == 'premium')
      price = _selectedPlanDuration == 'Weekly'
          ? FeeConfigService.listingPremiumWeekly
          : FeeConfigService.listingPremiumMonthly;
    else if (_selectedPlanId == 'elite')
      price = _selectedPlanDuration == 'Weekly'
          ? FeeConfigService.listingEliteWeekly
          : FeeConfigService.listingEliteMonthly;
    return price;
  }

  Future<void> _payWithRazorpay() async {
    final price = _getPlanPrice();
    final user = FirebaseAuth.instance.currentUser;

    final PaymentResult? result = await Navigator.push<PaymentResult>(
      context,
      MaterialPageRoute(
        builder: (_) => PremiumPaymentScreen(
          total: price.toDouble(),
          shopName: 'Multiverse City',
          description: 'Property Listing - $_selectedPlanId Plan',
          customerPhone: _ownerPhoneController.text.trim().isEmpty
              ? user?.phoneNumber
              : _ownerPhoneController.text.trim(),
          customerEmail: _ownerEmailController.text.trim().isEmpty
              ? user?.email
              : _ownerEmailController.text.trim(),
          showCod: false,
        ),
      ),
    );

    if (result == null || !mounted) return;
    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Payment failed: ${result.message ?? 'Please try again'}',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isPaid = true;
      _showPaymentGateway = false;
    });
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Widget _buildConfirmationCheckbox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _orange.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _orange.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: _isConfirmed,
              onChanged: (v) => setState(() => _isConfirmed = v ?? false),
              activeColor: _orange,
              checkColor: Colors.white,
              side: const BorderSide(color: _orange, width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              'I confirm all information is correct and comply with platform policies.',
              style: GoogleFonts.poppins(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewSection(
    String title,
    List<Widget> children,
    int stepIndex,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title.toUpperCase(),
                style: GoogleFonts.orbitron(
                  color: _orange,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.edit_note_rounded,
                  color: _purple,
                  size: 20,
                ),
                onPressed: () => _pageController.animateToPage(
                  stepIndex,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _buildReviewItem(String label, String value, {bool isStatus = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(color: Colors.white38, fontSize: 12),
          ),
          if (isStatus)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                value,
                style: GoogleFonts.orbitron(
                  color: Colors.greenAccent,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlanSelection() {
    return _StepBody(
      children: [
        _buildPlanCard(
          id: 'free',
          title: 'FREE PLAN',
          features: ['Basic Listing', 'Normal Visibility', 'Direct Activation'],
          weeklyPrice: 0,
          monthlyPrice: 0,
        ),
        const SizedBox(height: 20),
        _buildPlanCard(
          id: 'featured',
          title: 'Featured Property',
          features: [
            'Featured Badge',
            'Higher Visibility',
            'Featured Section',
            'Auto-Approval after Pay',
          ],
          weeklyPrice: FeeConfigService.listingFeaturedWeekly,
          monthlyPrice: FeeConfigService.listingFeaturedMonthly,
        ),
        const SizedBox(height: 20),
        _buildPlanCard(
          id: 'verified',
          title: 'Verified By MULTIVERSE',
          features: [
            'Document Verification',
            'Verified Badge',
            'Manual Approval Required',
          ],
          weeklyPrice: FeeConfigService.listingVerifiedWeekly,
          monthlyPrice: FeeConfigService.listingVerifiedMonthly,
          isVerified: true,
        ),
        const SizedBox(height: 20),

        _buildPlanCard(
          id: 'premium',
          title: 'Premium Package',
          features: ['Featured', 'Verified', 'Priority Admin Approval'],
          weeklyPrice: FeeConfigService.listingPremiumWeekly,
          monthlyPrice: FeeConfigService.listingPremiumMonthly,
          badge: 'Most Popular',
          icon: Icons.king_bed_rounded,
        ),
        const SizedBox(height: 20),
        _buildPlanCard(
          id: 'banner_request',
          title: 'Request Homepage Banner',
          features: [
            'Homepage Placement',
            'Maximum Visibility',
            'Approved within 24 Hours',
            'Manual Review Required',
          ],
          weeklyPrice: FeeConfigService.listingBannerWeekly,
          monthlyPrice: FeeConfigService.listingBannerMonthly,
          icon: Icons.campaign_rounded,
          badge: 'High Impact',
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildPlanCard({
    required String id,
    required String title,
    required List<String> features,
    required double weeklyPrice,
    required double monthlyPrice,
    String? badge,
    bool isVerified = false,
    IconData? icon,
  }) {
    final bool isSelected = _selectedPlanId == id;
    final double currentPrice = _selectedPlanDuration == 'Weekly'
        ? weeklyPrice
        : monthlyPrice;

    return GestureDetector(
      onTap: () => setState(() => _selectedPlanId = id),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? _purple.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? _purple : Colors.white.withValues(alpha: 0.05),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Stack(
          children: [
            if (badge != null)
              Positioned(
                top: 0,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: const BoxDecoration(
                    color: _orange,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: Text(
                    badge,
                    style: GoogleFonts.orbitron(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: _orange, size: 20),
                        const SizedBox(width: 8),
                      ],
                      if (isVerified) ...[
                        const Icon(
                          Icons.verified_rounded,
                          color: Colors.blueAccent,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        title,
                        style: GoogleFonts.orbitron(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  ...features.map(
                    (f) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_outline_rounded,
                            color: Colors.greenAccent,
                            size: 14,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            f,
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (id != 'free') ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedPlanDuration == 'Weekly'
                                  ? 'Weekly'
                                  : 'Monthly',
                              style: GoogleFonts.poppins(
                                color: Colors.white38,
                                fontSize: 10,
                              ),
                            ),
                            Text(
                              '₹${currentPrice.toInt()}',
                              style: GoogleFonts.orbitron(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              _buildDurationBtn('Weekly', id),
                              _buildDurationBtn('Monthly', id),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                  ],
                  NeonButton(
                    text: isSelected ? 'SELECTED' : 'SELECT PLAN',
                    isSecondary: !isSelected,
                    onPressed: () => setState(() => _selectedPlanId = id),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationBtn(String duration, String planId) {
    final bool isSel =
        _selectedPlanDuration == duration && _selectedPlanId == planId;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPlanId = planId;
          _selectedPlanDuration = duration;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSel ? _purple : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          duration,
          style: GoogleFonts.poppins(
            color: isSel ? Colors.white : Colors.white38,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentGatewayOverlay() {
    double price = _getPlanPrice();

    return Container(
      color: Colors.black.withValues(alpha: 0.9),
      width: double.infinity,
      height: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 30),
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1C),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: _purple.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: _orange,
                  size: 50,
                ),
                const SizedBox(height: 20),
                Text(
                  'PAYMENT SUMMARY',
                  style: GoogleFonts.orbitron(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 30),
                _buildSummaryRow(
                  'Selected Plan',
                  _selectedPlanId.toUpperCase(),
                ),
                _buildSummaryRow('Duration', _selectedPlanDuration),
                const Divider(color: Colors.white12, height: 40),
                _buildSummaryRow(
                  'Total Amount',
                  '₹${price.toInt()}',
                  isTotal: true,
                ),
                const SizedBox(height: 40),
                if (_selectedPlanId == 'banner_request') ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.timer_rounded,
                              color: Colors.orange,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'IMPORTANT: Banner will be live within 24 hours after payment approval.',
                                style: GoogleFonts.poppins(
                                  color: Colors.orange,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'For support: ${AppContactInfo.supportEmail}',
                          style: GoogleFonts.poppins(
                            color: Colors.white54,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                NeonButton(text: 'PAY & CONTINUE', onPressed: _payWithRazorpay),
                const SizedBox(height: 15),
                TextButton(
                  onPressed: () => setState(() => _showPaymentGateway = false),
                  child: Text(
                    'CANCEL',
                    style: GoogleFonts.poppins(
                      color: Colors.redAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
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

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              color: isTotal ? Colors.white : Colors.white60,
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.orbitron(
                color: isTotal ? _orange : Colors.white,
                fontSize: isTotal ? 20 : 14,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String hint,
    IconData icon, {
    TextInputType? keyboardType,
    int maxLines = 1,
    TextEditingController? controller,
    Function(String)? onChanged,
    bool isNumber = false,
    String? hintLabel,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hintLabel != null) ...[
          Text(
            hintLabel,
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
        ],
        TextField(
          controller: controller,
          onChanged: onChanged,
          maxLines: maxLines,
          keyboardType: isNumber ? TextInputType.number : keyboardType,
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.poppins(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 14,
            ),
            prefixIcon: Icon(icon, color: _orange, size: 20),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSmallField(
    String hint,
    String key,
    IconData icon, {
    bool isNumber = false,
  }) {
    return Expanded(
      child: _buildTextField(
        hint,
        icon,
        isNumber: isNumber,
        onChanged: (v) => _categoryFields[key] = v,
      ),
    );
  }

  Widget _buildRowFields(List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(children: children),
    );
  }

  Widget _buildSwitch(String label, String key) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
          ),
          Switch(
            value: key == '_isPriceNegotiable_local'
                ? _isPriceNegotiable
                : (_categoryFields[key] ?? false),
            activeThumbColor: _orange,
            onChanged: (v) => setState(() {
              if (key == '_isPriceNegotiable_local') {
                _isPriceNegotiable = v;
              } else {
                _categoryFields[key] = v;
              }
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    List<String> items,
    String currentVal,
    Function(String?) onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentVal,
          dropdownColor: const Color(0xFF1A1A1C),
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
          isExpanded: true,
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildSegmentedControl(
    String label,
    List<String> options,
    String selected,
    Function(String) onSelect,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 48,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: options.map((opt) {
              final isSel = opt == selected;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onSelect(opt),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSel ? _orange : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: isSel
                          ? [
                              BoxShadow(
                                color: _orange.withValues(alpha: 0.3),
                                blurRadius: 8,
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      opt,
                      style: GoogleFonts.poppins(
                        color: isSel ? Colors.white : Colors.white38,
                        fontSize: 12,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _StepBody extends StatelessWidget {
  final List<Widget> children;
  const _StepBody({required this.children});
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          ...children,
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  final Color color;
  final double size;
  const _GlowCircle({required this.color, required this.size});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: color, blurRadius: size / 2, spreadRadius: size / 4),
        ],
      ),
    );
  }
}
