import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/location_provider.dart';
import '../services/settings_service.dart';
import 'add_address_screen.dart';

class LocationPickerScreen extends StatelessWidget {
  const LocationPickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final SettingsService settingsService = SettingsService();
    
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Location',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white54),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: settingsService.streamAddresses(),
                builder: (context, snapshot) {
                  final addresses = snapshot.data ?? [];
                  final locationProvider = context.watch<LocationProvider>();

                  return ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      // Detect Current Location Button
                      _buildLocationOption(
                        context,
                        'Use Current Location',
                        locationProvider.isLoading ? 'Detecting your location...' : 'Fastest way to get your current address',
                        icon: Icons.my_location_rounded,
                        isLoading: locationProvider.isLoading,
                        onTap: () async {
                          HapticFeedback.selectionClick();
                          await locationProvider.updateLocation();
                          if (context.mounted) {
                            if (locationProvider.errorMessage != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(locationProvider.errorMessage!)),
                              );
                            } else {
                              // Return both city/state and raw coordinates
                              final position = locationProvider.currentPosition;
                              if (position != null) {
                                final result = {
                                  'address': locationProvider.currentCityState,
                                  'latitude': position.latitude,
                                  'longitude': position.longitude,
                                  'accuracy': position.accuracy,
                                };
                                Navigator.pop(context, result);
                              } else {
                                Navigator.pop(context, locationProvider.currentCityState);
                              }
                            }
                          }
                        },
                      ),
                      
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Row(
                          children: [
                            Expanded(child: Divider(color: Colors.white10)),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'SAVED ADDRESSES',
                                style: TextStyle(
                                  color: Colors.white30,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            Expanded(child: Divider(color: Colors.white10)),
                          ],
                        ),
                      ),

                      // Saved Addresses List
                      if (addresses.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              children: [
                                Icon(Icons.location_off_rounded, size: 48, color: Colors.white.withValues(alpha: 0.05)),
                                const SizedBox(height: 16),
                                const Text(
                                  'No saved addresses yet',
                                  style: TextStyle(color: Colors.white30, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        )
                      else ...[
                        // Default Address first
                        ...addresses.where((a) => a['isDefault'] == true).map((address) {
                          final area = address['area'] ?? '';
                          final city = address['city'] ?? '';
                          final subtitle = area.isNotEmpty && city.isNotEmpty ? '$area, $city' : (area.isNotEmpty ? area : city);
                          return _buildLocationOption(
                            context,
                            address['name'] ?? 'Home',
                            subtitle.isEmpty ? 'No details provided' : subtitle,
                            icon: Icons.home_rounded,
                            isSelected: true,
                            onTap: () async {
                              HapticFeedback.selectionClick();
                              await settingsService.selectAddress(address['id']);
                              if (context.mounted) {
                                Navigator.pop(context, subtitle);
                              }
                            },
                          );
                        }),

                        // Others
                        ...addresses.where((a) => a['isDefault'] != true).map((address) {
                          final area = address['area'] ?? '';
                          final city = address['city'] ?? '';
                          final subtitle = area.isNotEmpty && city.isNotEmpty ? '$area, $city' : (area.isNotEmpty ? area : city);
                          final isWork = (address['name'] ?? '').toString().toLowerCase().contains('work');
                          return _buildLocationOption(
                            context,
                            address['name'] ?? 'Saved Address',
                            subtitle.isEmpty ? 'No details provided' : subtitle,
                            icon: isWork ? Icons.work_outline_rounded : Icons.place_outlined,
                            onTap: () async {
                              HapticFeedback.selectionClick();
                              await settingsService.selectAddress(address['id']);
                              if (context.mounted) {
                                Navigator.pop(context, subtitle);
                              }
                            },
                          );
                        }),
                      ],
                      
                      const SizedBox(height: 24),
                      
                      // Add New Address Button
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AddAddressScreen(),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF4D4F).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFFF4D4F).withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_location_alt_rounded, color: Color(0xFFFF4D4F), size: 20),
                              SizedBox(width: 10),
                              Text(
                                'Add New Address',
                                style: TextStyle(
                                  color: Color(0xFFFF4D4F),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationOption(
    BuildContext context,
    String title, 
    String subtitle, {
    VoidCallback? onTap, 
    IconData icon = Icons.location_on_outlined,
    bool isSelected = false,
    bool isLoading = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFFF4D4F).withValues(alpha: 0.05) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? const Color(0xFFFF4D4F).withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFF4D4F).withValues(alpha: 0.2) : const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: isLoading 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF4D4F)))
              : Icon(icon, color: isSelected ? const Color(0xFFFF4D4F) : Colors.white70, size: 22),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.9),
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: isSelected ? Colors.white70 : Colors.white38,
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: Color(0xFFFF4D4F), size: 20) : null,
        onTap: onTap,
      ),
    );
  }
}
