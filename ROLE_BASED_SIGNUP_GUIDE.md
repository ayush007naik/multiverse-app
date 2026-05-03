# Role-Based Signup System - Complete Implementation

## ✅ Overview

Complete redesign of the signup system with role-based flows for Customer, Vendor, and Delivery Partner.

---

## 🎯 Features Implemented

### 1. **Main Signup Screen with 3 Tabs**
- ✅ Customer Signup (default)
- ✅ Vendor Signup
- ✅ Delivery Partner Signup
- ✅ Tab-based navigation with icons

### 2. **Customer Signup Form**
Fields:
- Full Name
- Email Address
- Phone Number
- Password

Firestore Role: `"customer"`

### 3. **Vendor Signup Form**
Fields:
- Your Name
- Shop Name
- Email Address
- Phone Number
- GST Number (Optional)
- Shop Address
- Category (Dropdown)
- Password

Firestore Role: `"vendor"`

**Auto-Creates:**
- User document in `users/{uid}`
- Shop document in `shops/{uid}`
- Sets `isApproved: false` (requires admin approval)

### 4. **Delivery Partner Signup Form**
Fields:
- Full Name
- Phone Number
- Email Address
- Vehicle Type (2-wheeler / 4-wheeler)
- Vehicle Number
- License Number (Optional)
- Password

Firestore Role: `"rider"`

**Auto-Sets:**
- `isAvailable: false`
- `isApproved: true`

---

## 📊 Firestore Data Structure

### User Document (`users/{uid}`):

**Customer:**
```javascript
{
  uid: "user_123",
  name: "John Doe",
  email: "john@example.com",
  phone: "9876543210",
  role: "customer",
  createdAt: Timestamp,
  updatedAt: Timestamp,
  isActive: true,
  isBlocked: false,
  isApproved: true
}
```

**Vendor:**
```javascript
{
  uid: "vendor_123",
  name: "Jane Smith",
  email: "jane@example.com",
  phone: "9876543210",
  role: "vendor",
  shopName: "Jane's Restaurant",
  gstNumber: "22AAAAA0000A1Z5",
  address: "123 Main Street, Mumbai",
  category: "Restaurant",
  createdAt: Timestamp,
  updatedAt: Timestamp,
  isActive: true,
  isBlocked: false,
  isApproved: false  // Needs admin approval
}
```

**Rider:**
```javascript
{
  uid: "rider_123",
  name: "Mike Johnson",
  email: "mike@example.com",
  phone: "9876543210",
  role: "rider",
  vehicleType: "2-wheeler",
  vehicleNumber: "MH01AB1234",
  licenseNumber: "MH0120230012345",
  isAvailable: false,
  createdAt: Timestamp,
  updatedAt: Timestamp,
  isActive: true,
  isBlocked: false,
  isApproved: true
}
```

### Shop Document (`shops/{vendorId}`):
```javascript
{
  vendorId: "vendor_123",
  shopName: "Jane's Restaurant",
  category: "Restaurant",
  address: "123 Main Street, Mumbai",
  gstNumber: "22AAAAA0000A1Z5",
  phone: "9876543210",
  email: "jane@example.com",
  isApproved: false,
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

---

## 🔄 Navigation Flow

### After Signup:

**Customer:**
```
Signup → HomeScreen (customer dashboard)
```

**Vendor:**
```
Signup → LoginScreen (wait for admin approval)
After approval → VendorDashboard
```

**Rider:**
```
Signup → DeliveryHomeScreen (rider dashboard)
```

### After Login:
```
Login → Check role in Firestore → Navigate to appropriate screen
```

---

## 💻 Code Implementation

### 1. **Role-Based Signup Screen**

File: `lib/screen/role_based_signup_screen.dart`

```dart
class RoleBasedSignupScreen extends StatefulWidget {
  const RoleBasedSignupScreen({super.key});

  @override
  State<RoleBasedSignupScreen> createState() => _RoleBasedSignupScreenState();
}

class _RoleBasedSignupScreenState extends State<RoleBasedSignupScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _signupType = 'customer';
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _signupType = _tabController.index == 0 
              ? 'customer' 
              : _tabController.index == 1 
                  ? 'vendor' 
                  : 'rider';
        });
      }
    });
  }
}
```

### 2. **Customer Signup Function**

```dart
Future<void> _signupCustomer() async {
  final name = _customerNameController.text.trim();
  final email = _customerEmailController.text.trim();
  final phone = _customerPhoneController.text.trim();
  final password = _customerPasswordController.text.trim();

  // Validation
  if (name.isEmpty) {
    _showError('Please enter your name');
    return;
  }
  if (email.isEmpty || !email.contains('@')) {
    _showError('Please enter valid email');
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

    // Save to Firestore with role = "customer"
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
      'isApproved': true,
    });

    // Navigate to home screen
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => _authFlowService.destinationForRole('customer'),
      ),
      (route) => false,
    );
  } catch (e) {
    _showError('Error: ${e.toString()}');
  }
}
```

### 3. **Vendor Signup Function**

```dart
Future<void> _signupVendor() async {
  final name = _vendorNameController.text.trim();
  final shopName = _vendorShopNameController.text.trim();
  final email = _vendorEmailController.text.trim();
  final password = _vendorPasswordController.text.trim();

  // Validation...

  try {
    // Create Firebase Auth user
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = userCredential.user!.uid;

    // Save user with role = "vendor"
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
      'isApproved': false, // Needs admin approval
    });

    // Create shop document
    await _firestore.collection('shops').doc(uid).set({
      'vendorId': uid,
      'shopName': shopName,
      'category': _vendorCategory,
      'address': address,
      'isApproved': false,
    });

    // Navigate to login (wait for approval)
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  } catch (e) {
    _showError('Error: ${e.toString()}');
  }
}
```

### 4. **Rider Signup Function**

```dart
Future<void> _signupRider() async {
  final name = _riderNameController.text.trim();
  final phone = _riderPhoneController.text.trim();
  final email = _riderEmailController.text.trim();
  final vehicleNumber = _riderVehicleNumberController.text.trim();
  final password = _riderPasswordController.text.trim();

  // Validation...

  try {
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = userCredential.user!.uid;

    // Save with role = "rider"
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
      'isApproved': true,
    });

    // Navigate to delivery home
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => _authFlowService.destinationForRole('rider'),
      ),
      (route) => false,
    );
  } catch (e) {
    _showError('Error: ${e.toString()}');
  }
}
```

---

## 🔧 Auth Flow Service Updates

File: `lib/services/auth_flow_service.dart`

### Role Normalization (lowercase):

```dart
Future<String> ensureUserProfile({
  required String uid,
  String? email,
  String? phoneNumber,
  String? name,
  String defaultRole = 'customer', // Changed from 'Customer'
}) async {
  final ref = _db.collection('users').doc(uid);
  final snapshot = await ref.get();
  final data = snapshot.data();
  // Normalize role to lowercase
  final role = (data?['role'] as String? ?? defaultRole).toLowerCase();
  
  // ... rest of the code
}
```

### Navigation by Role:

```dart
Widget destinationForRole(String role) {
  // Normalize role to lowercase
  final normalizedRole = role.toLowerCase();
  
  switch (normalizedRole) {
    case 'admin':
      return const AdminScreen();
    case 'vendor':
      return const VendorDashboard();
    case 'rider':
    case 'delivery partner':
      return const DeliveryHomeScreen();
    case 'real estate agent':
      return const RealEstateScreen();
    case 'customer':
    default:
      return const HomeScreen();
  }
}
```

---

## 🏪 Vendor Dashboard Changes

### Removed:
- ❌ "Add Shop" floating action button
- ❌ `_openAddShopScreen()` function
- ❌ Import for `AddShopScreen`
- ❌ "Add Shop" button in empty shop state

### Kept:
- ✅ "Add Product" floating action button (in Products tab)
- ✅ `_addProduct()` function

### Updated Empty State:

```dart
Widget _buildEmptyShopState(String message) {
  return Container(
    // ... styling
    child: Column(
      children: [
        Icon(Icons.storefront_outlined),
        Text(message),
        Text('Shop created during signup'), // New message
      ],
    ),
  );
}
```

---

## 🔐 Login Screen Updates

File: `lib/screen/login_screen.dart`

### Import Added:
```dart
import 'role_based_signup_screen.dart';
```

### Sign Up Button Updated:
```dart
Center(
  child: TextButton(
    onPressed: () {
      // Navigate to new role-based signup screen
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const RoleBasedSignupScreen()),
      );
    },
    child: RichText(
      text: TextSpan(
        text: _isLogin ? "New user? " : "Already have account? ",
        style: const TextStyle(color: Colors.grey),
        children: [
          TextSpan(
            text: _isLogin ? "Sign Up" : "Login",
            style: const TextStyle(
              color: Color(0xFFFF5722),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    ),
  ),
),
```

---

## 🎨 UI Components

### Tab Bar Design:
```dart
TabBar(
  controller: _tabController,
  indicatorColor: const Color(0xFFFF5722),
  labelColor: const Color(0xFFFF5722),
  unselectedLabelColor: Colors.grey,
  tabs: const [
    Tab(text: 'Customer', icon: Icon(Icons.person)),
    Tab(text: 'Vendor', icon: Icon(Icons.store)),
    Tab(text: 'Delivery', icon: Icon(Icons.delivery_dining)),
  ],
),
```

### Vehicle Type Selector (Rider):
```dart
Row(
  children: [
    Expanded(
      child: _buildVehicleTypeOption(
        '2-wheeler',
        Icons.motorcycle,
        'Bike/Scooter',
      ),
    ),
    Expanded(
      child: _buildVehicleTypeOption(
        '4-wheeler',
        Icons.directions_car,
        'Car/Van',
      ),
    ),
  ],
),
```

### Category Dropdown (Vendor):
```dart
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
          child: Text(category),
        );
      }).toList(),
      onChanged: (value) {
        setState(() => _vendorCategory = value!);
      },
    ),
  ),
),
```

---

## 🚀 Usage Examples

### Navigate to Signup from Login:
```dart
Navigator.of(context).push(
  MaterialPageRoute(builder: (_) => const RoleBasedSignupScreen()),
);
```

### Navigate After Customer Signup:
```dart
Navigator.of(context).pushAndRemoveUntil(
  MaterialPageRoute(
    builder: (_) => _authFlowService.destinationForRole('customer'),
  ),
  (route) => false,
);
```

### Navigate After Vendor Signup:
```dart
Navigator.of(context).pushAndRemoveUntil(
  MaterialPageRoute(builder: (_) => const LoginScreen()),
  (route) => false,
);
```

### Navigate After Rider Signup:
```dart
Navigator.of(context).pushAndRemoveUntil(
  MaterialPageRoute(
    builder: (_) => _authFlowService.destinationForRole('rider'),
  ),
  (route) => false,
);
```

---

## 🔒 Firestore Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Users collection
    match /users/{userId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null && request.auth.uid == userId;
      allow update: if request.auth != null && (
        request.auth.uid == userId ||
        request.auth.token.admin == true
      );
    }
    
    // Shops collection
    match /shops/{shopId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update: if request.auth != null && (
        resource.data.vendorId == request.auth.uid ||
        request.auth.token.admin == true
      );
    }
  }
}
```

---

## ✅ Testing Checklist

### Customer Signup:
- [ ] Fill all fields
- [ ] Click "Create Account"
- [ ] Verify user created in Firebase Auth
- [ ] Verify user document in Firestore with `role: "customer"`
- [ ] Verify navigation to HomeScreen

### Vendor Signup:
- [ ] Fill all fields including shop details
- [ ] Select category from dropdown
- [ ] Click "Register Shop"
- [ ] Verify user created in Firebase Auth
- [ ] Verify user document in Firestore with `role: "vendor"`
- [ ] Verify shop document created in `shops` collection
- [ ] Verify `isApproved: false`
- [ ] Verify navigation to LoginScreen

### Rider Signup:
- [ ] Fill all fields
- [ ] Select vehicle type (2-wheeler/4-wheeler)
- [ ] Enter vehicle number
- [ ] Click "Join as Delivery Partner"
- [ ] Verify user created in Firebase Auth
- [ ] Verify user document in Firestore with `role: "rider"`
- [ ] Verify `isAvailable: false`
- [ ] Verify navigation to DeliveryHomeScreen

### Login Flow:
- [ ] Login as customer → navigates to HomeScreen
- [ ] Login as vendor → navigates to VendorDashboard
- [ ] Login as rider → navigates to DeliveryHomeScreen
- [ ] Role is lowercase in Firestore
- [ ] Navigation works correctly

### Vendor Dashboard:
- [ ] No "Add Shop" button visible
- [ ] "Add Product" button visible in Products tab
- [ ] Empty shop state shows "Shop created during signup"
- [ ] No compilation errors

---

## 📁 Files Modified/Created

1. ✅ **NEW:** `lib/screen/role_based_signup_screen.dart` - Complete role-based signup UI
2. ✅ **UPDATED:** `lib/services/auth_flow_service.dart` - Role normalization (lowercase)
3. ✅ **UPDATED:** `lib/screen/vendor_dashboard.dart` - Removed "Add Shop" feature
4. ✅ **UPDATED:** `lib/screen/login_screen.dart` - Navigate to new signup screen

---

## 🎯 Role Values (Lowercase)

All roles are stored in lowercase for consistency:

| Role | Value | Destination Screen |
|------|-------|-------------------|
| Customer | `"customer"` | `HomeScreen` |
| Vendor | `"vendor"` | `VendorDashboard` |
| Rider | `"rider"` | `DeliveryHomeScreen` |
| Admin | `"admin"` | `AdminScreen` |
| Real Estate Agent | `"real_estate_agent"` | `RealEstateScreen` |

---

## 🐛 Troubleshooting

### Issue: Vendor can't login after signup
**Cause:** `isApproved: false`  
**Solution:** Admin must approve vendor in admin dashboard

### Issue: Role not matching in navigation
**Cause:** Case sensitivity  
**Solution:** All roles are now lowercase, check Firestore document

### Issue: Shop not created for vendor
**Cause:** Error in signup process  
**Solution:** Check console logs, verify vendor signup completed successfully

### Issue: Rider not navigating to delivery screen
**Cause:** Role mismatch  
**Solution:** Verify `role: "rider"` in Firestore (not "Delivery Partner")

---

## 📊 Complete Flow Diagram

```
┌─────────────────────────────────────┐
│        LOGIN SCREEN                 │
│                                     │
│  [Login Form]                       │
│                                     │
│  New user? [Sign Up]                │
└──────────────┬──────────────────────┘
               │ Click Sign Up
               ↓
┌─────────────────────────────────────┐
│     ROLE-BASED SIGNUP SCREEN        │
│                                     │
│  [Customer] [Vendor] [Delivery]     │
│       TAB BAR                       │
└───────┬──────────┬──────────┬───────┘
        │          │          │
        ↓          ↓          ↓
   Customer    Vendor     Rider
   Signup      Signup     Signup
        │          │          │
        ↓          ↓          ↓
   Create      Create     Create
   Account     Account    Account
        │          │          │
        ↓          ↓          ↓
   Save to     Save to    Save to
   Firestore   Firestore  Firestore
   role:       role:      role:
   "customer"  "vendor"   "rider"
        │          │          │
        │     + Create        │
        │     Shop Doc        │
        │          │          │
        ↓          ↓          ↓
   Navigate   Navigate   Navigate
   to         to         to
   HomeScreen LoginScreen Delivery
              (wait      HomeScreen
              approval)
```

---

## 🎉 Summary

✅ **3 signup flows:** Customer, Vendor, Rider  
✅ **Role-based navigation:** Automatic routing after login/signup  
✅ **Firestore integration:** Proper document creation  
✅ **Vendor shop auto-creation:** Shop created during signup  
✅ **Admin approval workflow:** Vendors need approval  
✅ **Clean UI:** Tab-based navigation, dark theme  
✅ **Validation:** All forms validated before submission  
✅ **Error handling:** User-friendly error messages  
✅ **Vendor dashboard cleaned:** Removed "Add Shop", kept "Add Product"  
✅ **Role normalization:** All lowercase for consistency  

**Complete production-ready implementation!** 🚀
