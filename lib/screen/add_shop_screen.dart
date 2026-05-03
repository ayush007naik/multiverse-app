import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../services/shop_service.dart';

class AddShopScreen extends StatefulWidget {
  const AddShopScreen({super.key});

  @override
  State<AddShopScreen> createState() => _AddShopScreenState();
}

class _AddShopScreenState extends State<AddShopScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _imageController = TextEditingController();
  final _areaController = TextEditingController();
  final _cityController = TextEditingController(text: 'Mandi');
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final ShopService _shopService = ShopService();

  bool _isSaving = false;
  bool _isFetchingLocation = false;
  bool _isActive = true;
  String _selectedCategory = 'Grocery';

  static const List<String> _categories = [
    'Grocery',
    'Hardware',
    'Pharmacy',
    'Clothing',
    'Food',
    'Electronics',
    'Beauty',
    'Stationery',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _imageController.dispose();
    _areaController.dispose();
    _cityController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isFetchingLocation = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showMessage(
          'Location permission is required to save shop coordinates',
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;
      setState(() {
        _latitudeController.text = position.latitude.toStringAsFixed(6);
        _longitudeController.text = position.longitude.toStringAsFixed(6);
      });

      _showMessage('Shop coordinates updated from current location');
    } catch (e) {
      _showMessage('Failed to fetch location: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  Future<void> _saveShop() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showMessage('You must be logged in to create a shop', isError: true);
      return;
    }

    final latitude = double.tryParse(_latitudeController.text.trim());
    final longitude = double.tryParse(_longitudeController.text.trim());
    if (latitude == null || longitude == null) {
      _showMessage('Enter valid latitude and longitude', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final area = _areaController.text.trim();
      final city = _cityController.text.trim();
      final locationLabel = [
        area,
        city,
      ].where((value) => value.isNotEmpty).join(', ');

      await _shopService.createShop(
        ownerId: user.uid,
        name: _nameController.text.trim(),
        category: _selectedCategory,
        imageUrl: _imageController.text.trim(),
        locationLabel: locationLabel.isEmpty
            ? 'Location unavailable'
            : locationLabel,
        latitude: latitude,
        longitude: longitude,
        city: city,
        area: area,
        isActive: _isActive,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _showMessage('Failed to save shop: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        title: const Text(
          'Add Shop',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('Shop Details'),
              _buildField(
                controller: _nameController,
                label: 'Shop name',
                icon: Icons.storefront_outlined,
              ),
              const SizedBox(height: 14),
              _buildCategoryField(),
              const SizedBox(height: 14),
              _buildField(
                controller: _imageController,
                label: 'Image URL',
                icon: Icons.image_outlined,
                keyboardType: TextInputType.url,
                required: false,
              ),
              const SizedBox(height: 22),
              _sectionTitle('Location'),
              OutlinedButton.icon(
                onPressed: _isFetchingLocation ? null : _useCurrentLocation,
                icon: _isFetchingLocation
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFFF4D4F),
                        ),
                      )
                    : const Icon(
                        Icons.my_location_rounded,
                        color: Color(0xFFFF4D4F),
                      ),
                label: const Text(
                  'Use current location',
                  style: TextStyle(color: Colors.white),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF333333)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _buildField(
                controller: _areaController,
                label: 'Area / locality',
                icon: Icons.location_on_outlined,
              ),
              const SizedBox(height: 14),
              _buildField(
                controller: _cityController,
                label: 'City',
                icon: Icons.location_city_outlined,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _buildField(
                      controller: _latitudeController,
                      label: 'Latitude',
                      icon: Icons.explore_outlined,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildField(
                      controller: _longitudeController,
                      label: 'Longitude',
                      icon: Icons.explore,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SwitchListTile(
                value: _isActive,
                onChanged: (value) => setState(() => _isActive = value),
                activeColor: const Color(0xFF4CAF50),
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Shop active',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  'Active shops are visible in the customer app.',
                  style: TextStyle(color: Color(0xFF888888), fontSize: 12),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveShop,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF4D4F),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Save Shop',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
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

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildCategoryField() {
    return DropdownButtonFormField<String>(
      value: _selectedCategory,
      dropdownColor: const Color(0xFF1E1E1E),
      decoration: _inputDecoration('Category', Icons.category_outlined),
      style: const TextStyle(color: Colors.white),
      items: _categories
          .map(
            (category) => DropdownMenuItem<String>(
              value: category,
              child: Text(category),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value == null) return;
        setState(() => _selectedCategory = value);
      },
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool required = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      validator: required
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Required';
              }
              return null;
            }
          : null,
      decoration: _inputDecoration(label, icon),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF888888)),
      prefixIcon: Icon(icon, color: const Color(0xFFFF4D4F)),
      filled: true,
      fillColor: const Color(0xFF1E1E1E),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFFF4D4F)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF272727)),
      ),
    );
  }
}
