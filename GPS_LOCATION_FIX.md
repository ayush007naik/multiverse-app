# GPS Location Fix for Shop Coordinates

## Problem
Shop GPS coordinates are hardcoded to `0.0, 0.0` during vendor signup, causing incorrect distance calculations when customers place orders.

## Root Cause
File: `vendor_dashboard/lib/services/vendor_service.dart` (Lines 131-138)
```dart
'lat': 0.0,
'lng': 0.0,
'location': {
  'label': location,
  'city': '',
  'area': '',
  'latitude': 0.0,
  'longitude': 0.0,
},
```

## Solution

### Step 1: Update Vendor Service to Accept GPS Coordinates

**File:** `vendor_dashboard/lib/services/vendor_service.dart`

**Line 38:** Add `latitude` and `longitude` parameters to `signupVendor` method:
```dart
Future<VendorModel> signupVendor({
  required String email,
  required String password,
  required String shopName,
  required String ownerName,
  required String phone,
  required String category,
  required String location,
  required double deliveryRadius,
  required double latitude,    // ADD THIS
  required double longitude,   // ADD THIS
  String? gstNumber,
  File? shopPhoto,
  File? ownerIdProof,
  String? idProofType,
  File? shopImage,
  // Web support
  Uint8List? shopPhotoBytes,
  Uint8List? ownerIdProofBytes,
}) async {
```

**Lines 131-138:** Replace hardcoded coordinates with actual values:
```dart
'lat': latitude,           // CHANGED from 0.0
'lng': longitude,          // CHANGED from 0.0
'location': {
  'label': location,
  'city': '',
  'area': '',
  'latitude': latitude,    // CHANGED from 0.0
  'longitude': longitude,  // CHANGED from 0.0
},
```

### Step 2: Add GPS Detection to Vendor Signup Screen

**File:** `vendor_dashboard/lib/screens/vendor_signup_screen.dart`

**Add import after line 4:**
```dart
import 'package:geolocator/geolocator.dart';
```

**Add state variables after line 56:**
```dart
// GPS Location
bool _isFetchingLocation = false;
double? _shopLatitude;
double? _shopLongitude;
String? _locationError;
```

**Add GPS fetching method after `_pickOwnerIdProof()` method (around line 217):**
```dart
Future<void> _fetchShopLocation() async {
  setState(() {
    _isFetchingLocation = true;
    _locationError = null;
  });

  try {
    // Check location permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _locationError = 'Location permission denied';
          _isFetchingLocation = false;
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _locationError = 'Location permission permanently denied.';
        _isFetchingLocation = false;
      });
      return;
    }

    // Get current position
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      _shopLatitude = position.latitude;
      _shopLongitude = position.longitude;
      _isFetchingLocation = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Location captured: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}'),
          backgroundColor: const Color(0xFF4CAF50),
        ),
      );
    }
  } catch (e) {
    setState(() {
      _locationError = 'Failed to get location: $e';
      _isFetchingLocation = false;
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ $_locationError'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
```

**Update `_signup()` method (around line 96-124) to pass coordinates:**
```dart
Future<void> _signup() async {
  if (!_formKey.currentState!.validate()) return;

  setState(() => _isLoading = true);

  try {
    // Combine address
    final fullAddress = '${_streetAddressController.text.trim()}, ${_cityController.text.trim()}, ${_stateController.text.trim()} - ${_pincodeController.text.trim()}';

    await _vendorService.signupVendor(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      shopName: _shopNameController.text.trim(),
      ownerName: _ownerNameController.text.trim(),
      phone: _phoneController.text.trim(),
      category: _selectedCategory,
      location: fullAddress,
      deliveryRadius: _deliveryRadius,
      latitude: _shopLatitude ?? 0.0,      // ADD THIS
      longitude: _shopLongitude ?? 0.0,    // ADD THIS
      gstNumber: _gstNumberController.text.trim().isNotEmpty 
          ? _gstNumberController.text.trim() 
          : null,
      // Mobile: File object
      shopPhoto: kIsWeb ? null : _shopPhoto,
      ownerIdProof: kIsWeb ? null : _ownerIdProof,
      // Web: Bytes
      shopPhotoBytes: kIsWeb ? _shopPhotoBytes : null,
      ownerIdProofBytes: kIsWeb ? _ownerIdProofBytes : null,
      idProofType: _selectedIdProofType,
    );
```

**Add "Use Current Location" button in the build method after `_buildPincodeField()` (around line 268):**
```dart
_buildPincodeField(),
const SizedBox(height: 16),
_buildLocationButton(),  // ADD THIS
const SizedBox(height: 24),
```

**Add the location button widget method (add anywhere in the class):**
```dart
Widget _buildLocationButton() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ElevatedButton.icon(
        onPressed: _isFetchingLocation ? null : _fetchShopLocation,
        icon: _isFetchingLocation
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.my_location, size: 20),
        label: Text(
          _isFetchingLocation 
              ? 'Fetching Location...' 
              : (_shopLatitude != null 
                  ? '✓ Location Captured' 
                  : 'Use Current Location'),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _shopLatitude != null 
              ? const Color(0xFF4CAF50)  // Green if captured
              : const Color(0xFF2196F3), // Blue if not
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          minimumSize: const Size(double.infinity, 0),
          elevation: 4,
        ),
      ),
      if (_shopLatitude != null) ...[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFF4CAF50).withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Lat: ${_shopLatitude!.toStringAsFixed(6)}\nLng: ${_shopLongitude!.toStringAsFixed(6)}',
                  style: const TextStyle(
                    color: Color(0xFFAAAAAA),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
      if (_locationError != null) ...[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.red.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.error, color: Colors.red, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _locationError!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ],
  );
}
```

### Step 3: Fix Existing Shops (One-Time Script)

**File:** Create new file `vendor_dashboard/lib/update_shop_location.dart`

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Utility to update GPS coordinates for existing shops
/// Run this once to fix shops that have 0.0, 0.0 coordinates
Future<void> updateShopLocation({
  required String vendorId,
  required double latitude,
  required double longitude,
}) async {
  try {
    await FirebaseFirestore.instance.collection('shops').doc(vendorId).update({
      'lat': latitude,
      'lng': longitude,
      'location': {
        'latitude': latitude,
        'longitude': longitude,
      },
      'updatedAt': FieldValue.serverTimestamp(),
    });

    print('✅ Shop location updated successfully!');
    print('Vendor ID: $vendorId');
    print('Latitude: $latitude');
    print('Longitude: $longitude');
  } catch (e) {
    print('❌ Failed to update shop location: $e');
  }
}

// Example usage:
// void main() async {
//   await updateShopLocation(
//     vendorId: 'YOUR_VENDOR_ID_HERE',
//     latitude: 19.0760,    // Replace with actual latitude
//     longitude: 72.8777,   // Replace with actual longitude
//   );
// }
```

## Step 4: Add Geolocator Dependency

**File:** `vendor_dashboard/pubspec.yaml`

Add under `dependencies:`:
```yaml
geolocator: ^10.1.0
```

Then run:
```bash
cd vendor_dashboard
flutter pub get
```

## Testing

1. **For New Vendors:**
   - Open vendor signup screen
   - Fill in all details
   - Click "Use Current Location" button
   - Verify coordinates are captured (green button + coordinates shown)
   - Complete signup
   - Check Firestore `shops` collection - `lat` and `lng` should have real values

2. **For Existing Vendors:**
   - Find your vendor UID from Firebase Console
   - Use the utility script to update coordinates manually
   - Or re-signup with GPS location enabled

3. **Customer App:**
   - Open shop detail screen
   - Distance should now show correct value based on actual GPS coordinates
   - Order placement will calculate proper delivery distance

## Important Notes

- GPS location is optional during signup (defaults to 0.0 if not captured)
- Recommend vendors to enable location for accurate delivery calculations
- Location permissions required on mobile devices
- On web browsers, location prompt will appear when button is clicked
- The fix affects distance-based features:
  - Shop search radius
  - Delivery fee calculation
  - ETA estimation
  - Shop sorting by distance
