import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/settings_service.dart';
import 'add_address_screen.dart';

class SavedAddressesScreen extends StatefulWidget {
  const SavedAddressesScreen({super.key, this.selectionMode = false});

  final bool selectionMode;

  @override
  State<SavedAddressesScreen> createState() => _SavedAddressesScreenState();
}

class _SavedAddressesScreenState extends State<SavedAddressesScreen> {
  final SettingsService _settingsService = SettingsService();

  Future<void> _openAddAddress() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddAddressScreen()),
    );
  }

  Future<void> _selectAddress(Map<String, dynamic> address) async {
    debugPrint('📍 Selecting address: ${address['id']}');
    final id = address['id'] as String?;
    if (id == null) return;
    
    HapticFeedback.selectionClick();
    await _settingsService.selectAddress(id);
    
    if (!mounted) return;
    
    if (widget.selectionMode) {
      debugPrint('✅ Returning address to caller');
      Navigator.pop(context, {...address, 'isDefault': true});
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Default address updated'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _deleteAddress(Map<String, dynamic> address) async {
    final id = address['id'] as String?;
    if (id == null) return;
    await _settingsService.deleteAddress(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Address deleted'),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        title: Text(
          widget.selectionMode ? 'Select Address' : 'Saved Addresses',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddAddress,
        backgroundColor: const Color(0xFFFF4D4F),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_location_alt_rounded),
        label: const Text('Add Address'),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _settingsService.streamAddresses(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF4D4F)),
            );
          }

          final addresses = snapshot.data ?? [];
          if (addresses.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.location_off_rounded,
                      color: Color(0xFF444444),
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No saved addresses yet',
                      style: TextStyle(color: Colors.white, fontSize: 15),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _openAddAddress,
                      child: const Text('Add your first address'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            itemCount: addresses.length,
            itemBuilder: (context, index) {
              final address = addresses[index];
              final isDefault = address['isDefault'] == true;
              final subtitle =
                  '${address['house'] ?? ''}, ${address['area'] ?? ''}, ${address['city'] ?? ''} - ${address['pincode'] ?? ''}';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDefault
                        ? const Color(0xFFFF4D4F)
                        : const Color(0xFF272727),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            address['name'] as String? ?? 'Address',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (isDefault)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFFFF4D4F,
                              ).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Default',
                              style: TextStyle(
                                color: Color(0xFFFF4D4F),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFFAAAAAA),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Phone: ${address['phone'] ?? ''}',
                      style: const TextStyle(
                        color: Color(0xFF888888),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _selectAddress(address),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: isDefault
                                    ? const Color(0xFFFF4D4F)
                                    : const Color(0xFF444444),
                              ),
                              foregroundColor: Colors.white,
                            ),
                            child: Text(
                              widget.selectionMode
                                  ? 'Deliver Here'
                                  : isDefault
                                  ? 'Selected'
                                  : 'Set Default',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton(
                          onPressed: () => _deleteAddress(address),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
