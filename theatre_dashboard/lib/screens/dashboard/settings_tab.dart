import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../theme/cyberpunk_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/theatre_service.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();
  
  double? _latitude;
  double? _longitude;
  bool _isDetecting = false;
  final bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final data = Provider.of<AuthProvider>(context, listen: false).theatreData;
    if (data != null) {
      _nameController.text = data['name'] ?? data['cinemaName'] ?? '';
      _addressController.text = data['address'] ?? '';
      _phoneController.text = data['phone'] ?? '';
      _emailController.text = data['email'] ?? '';
      _cityController.text = data['city'] ?? '';
      _stateController.text = data['state'] ?? '';
      _pincodeController.text = data['pincode'] ?? '';
      _latitude = (data['latitude'] as num?)?.toDouble();
      _longitude = (data['longitude'] as num?)?.toDouble();
    }
  }

  Future<void> _detectLocation() async {
    setState(() => _isDetecting = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });

      final response = await http.get(Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}&zoom=16&addressdetails=1'));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final addr = data['address'] as Map<String, dynamic>? ?? {};
        setState(() {
          _addressController.text = data['display_name'] ?? _addressController.text;
          _cityController.text = (addr['city'] ?? addr['town'] ?? addr['village'] ?? '').toString();
          _stateController.text = (addr['state'] ?? '').toString();
          _pincodeController.text = (addr['postcode'] ?? '').toString();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error detecting location: $e')));
      }
    } finally {
      setState(() => _isDetecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('THEATRE SETTINGS', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 32),
          
          Container(
            constraints: const BoxConstraints(maxWidth: 800),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: CyberpunkTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('GENERAL INFORMATION', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    TextButton.icon(
                      onPressed: _isDetecting ? null : _detectLocation,
                      icon: _isDetecting 
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.my_location, size: 18),
                      label: Text(_isDetecting ? 'DETECTING...' : 'UPDATE LOCATION'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildField('Theatre Name', _nameController),
                const SizedBox(height: 16),
                _buildField('Address', _addressController, maxLines: 2),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildField('City', _cityController)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildField('State', _stateController)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildField('Pincode', _pincodeController)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildField('Phone', _phoneController)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildField('Email', _emailController)),
                  ],
                ),
                if (_latitude != null) ...[
                  const SizedBox(height: 16),
                  Text('Coordinates: $_latitude, $_longitude', 
                    style: const TextStyle(color: Colors.greenAccent, fontSize: 12)),
                ],
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: _isSaving ? null : _saveSettings,
                  child: _isSaving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('UPDATE THEATRE PROFILE'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Logout Section
          Container(
            constraints: const BoxConstraints(maxWidth: 800),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: CyberpunkTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.logout, color: Colors.redAccent, size: 24),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Sign Out',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('Logout from the theatre dashboard',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _showLogoutDialog(),
                  icon: const Icon(Icons.power_settings_new, size: 16),
                  label: const Text('LOGOUT'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CyberpunkTheme.surface,
        title: const Text('Confirm Logout',
            style: TextStyle(color: Colors.redAccent)),
        content: const Text('Are you sure you want to logout from the dashboard?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Provider.of<AuthProvider>(context, listen: false).logout();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('LOGOUT'),
          ),
        ],
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
      ),
    );
  }

  void _saveSettings() async {
    final data = {
      'name': _nameController.text,
      'address': _addressController.text,
      'phone': _phoneController.text,
      'email': _emailController.text,
      'city': _cityController.text,
      'state': _stateController.text,
      'pincode': _pincodeController.text,
      'latitude': _latitude ?? 0.0,
      'longitude': _longitude ?? 0.0,
    };
    final theatreService = Provider.of<TheatreService>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    await theatreService.updateTheatreProfile(data);
    await authProvider.fetchTheatreData();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings updated successfully!')));
    }
  }
}
