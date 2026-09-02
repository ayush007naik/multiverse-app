# 🚀 MULTIVERSE VENDOR DASHBOARD - SEPARATE WEB APP

## ✅ WHAT WAS CREATED

A **standalone vendor dashboard web app** in the `vendor_dashboard/` folder, completely separate from the main customer app.

---

## 📁 PROJECT STRUCTURE

```
multiversesss/
├── lib/                          # Main Customer App
├── admin_dashboard/              # Admin Dashboard (existing)
└── vendor_dashboard/             # ⭐ NEW - Vendor Dashboard
    ├── lib/
    │   ├── main.dart
    │   ├── screens/
    │   │   ├── vendor_login_screen.dart
    │   │   ├── vendor_signup_screen.dart
    │   │   ├── vendor_dashboard_main.dart
    │   │   ├── vendor_home_screen.dart
    │   │   ├── vendor_products_screen.dart
    │   │   ├── vendor_orders_screen.dart
    │   │   ├── vendor_inventory_screen.dart
    │   │   ├── vendor_offers_screen.dart
    │   │   ├── vendor_analytics_screen.dart
    │   │   ├── vendor_earnings_screen.dart
    │   │   ├── vendor_notifications_screen.dart
    │   │   └── vendor_settings_screen.dart
    │   ├── services/
    │   │   ├── vendor_service.dart
    │   │   └── vendor_product_service.dart
    │   └── models/
    │       └── vendor_model.dart
    ├── web/
    │   └── index.html
    ├── pubspec.yaml
    └── firebase_options.dart     (needs to be generated)
```

---

## 🔧 SETUP INSTRUCTIONS

### **Step 1: Copy Vendor Files**

Copy these files from main app to vendor_dashboard:

```bash
# Navigate to project root
cd /Users/ayushnaik/AndroidStudioProjects/multiversesss

# Copy vendor screens
cp lib/screen/vendor_*.dart vendor_dashboard/lib/screens/

# Copy vendor services
cp lib/services/vendor_service.dart vendor_dashboard/lib/services/
cp lib/services/vendor_product_service.dart vendor_dashboard/lib/services/

# Copy vendor model
cp lib/models/vendor_model.dart vendor_dashboard/lib/models/
```

### **Step 2: Install Dependencies**

```bash
cd vendor_dashboard
flutter pub get
```

### **Step 3: Configure Firebase**

```bash
# Install FlutterFire CLI (if not already installed)
dart pub global activate flutterfire_cli

# Configure Firebase for vendor dashboard
flutterfire configure --project=multiverses-8d207
```

This will generate `firebase_options.dart` with your Firebase config.

### **Step 4: Run Vendor Dashboard**

```bash
# Run on Chrome
flutter run -d chrome --web-port=9000

# Or run on web server
flutter run -d web-server --web-port=9000
```

**Vendor Dashboard will open at:** `http://localhost:9000`

---

## 🎯 COMMANDS

### **Run Customer App (Main App)**
```bash
cd /Users/ayushnaik/AndroidStudioProjects/multiversesss
flutter run -d chrome --web-port=8080
```
**URL:** `http://localhost:8080`

### **Run Vendor Dashboard (NEW)**
```bash
cd /Users/ayushnaik/AndroidStudioProjects/multiversesss/vendor_dashboard
flutter run -d chrome --web-port=9000
```
**URL:** `http://localhost:9000`

### **Run Admin Dashboard (Existing)**
```bash
cd /Users/ayushnaik/AndroidStudioProjects/multiversesss/admin_dashboard
flutter run -d chrome --web-port=3000
```
**URL:** `http://localhost:3000`

---

## 🌐 DEPLOY TO FIREBASE HOSTING

### **Deploy Customer App**
```bash
cd /Users/ayushnaik/AndroidStudioProjects/multiversesss
flutter build web --release
firebase deploy --only hosting
```

### **Deploy Vendor Dashboard**
```bash
cd /Users/ayushnaik/AndroidStudioProjects/multiversesss/vendor_dashboard

# Update firebase.json to add vendor hosting target
flutter build web --release

# Deploy to: https://YOUR_PROJECT.web.app/vendor
firebase deploy --only hosting:vendor
```

---

## 🔥 FIREBASE CONFIGURATION

### **Update firebase.json**

Add vendor dashboard hosting:

```json
{
  "hosting": [
    {
      "target": "customer",
      "public": "build/web",
      "ignore": ["firebase.json", "**/.*", "**/node_modules/**"],
      "rewrites": [{ "source": "**", "destination": "/index.html" }]
    },
    {
      "target": "vendor",
      "public": "vendor_dashboard/build/web",
      "ignore": ["firebase.json", "**/.*", "**/node_modules/**"],
      "rewrites": [{ "source": "**", "destination": "/index.html" }]
    }
  ]
}
```

### **Setup Hosting Targets**

```bash
firebase target:apply hosting customer multiverses-8d207
firebase target:apply hosting vendor multiverses-8d207
```

---

## 🎨 FEATURES (Same as Main App)

✅ **Vendor Authentication** - Login, Signup, Forgot Password  
✅ **Dashboard Home** - Stats, Charts, Alerts  
✅ **Products Management** - Add/Edit/Delete with images  
✅ **Orders Management** - Accept/Reject/Update status  
✅ **Inventory Tracking** - Stock levels & alerts  
✅ **Offers & Coupons** - Create discounts  
✅ **Analytics** - Charts & insights  
✅ **Earnings** - Revenue & payouts  
✅ **Notifications** - Realtime alerts  
✅ **Settings** - Shop management  

---

## 🔄 REALTIME SYNC

Both apps share the **same Firebase project**, so:

- **Vendor Dashboard** updates → **Customer App** sees changes instantly
- **Customer App** places order → **Vendor Dashboard** receives instantly
- **Both apps** use same Firestore collections
- **Same Firebase Auth** - vendors can login to both

---

## 📊 APP COMPARISON

| Feature | Customer App | Vendor Dashboard |
|---------|-------------|------------------|
| **Port** | 8080 | 9000 |
| **Purpose** | Browse & Order | Manage Shop |
| **Auth** | Customer login | Vendor login |
| **Role** | customer | vendor |
| **Firestore** | Same project | Same project |
| **Database** | Shared | Shared |

---

## 🚀 QUICK START

### **1. Setup Vendor Dashboard**

```bash
cd /Users/ayushnaik/AndroidStudioProjects/multiversesss

# Copy files
mkdir -p vendor_dashboard/lib/screens
mkdir -p vendor_dashboard/lib/services
mkdir -p vendor_dashboard/lib/models

cp lib/screen/vendor_*.dart vendor_dashboard/lib/screens/
cp lib/services/vendor_*.dart vendor_dashboard/lib/services/
cp lib/models/vendor_model.dart vendor_dashboard/lib/models/

# Install dependencies
cd vendor_dashboard
flutter pub get

# Configure Firebase
flutterfire configure --project=multiverses-8d207

# Run
flutter run -d chrome --web-port=9000
```

### **2. Test Both Apps**

**Terminal 1 - Customer App:**
```bash
cd /Users/ayushnaik/AndroidStudioProjects/multiversesss
flutter run -d chrome --web-port=8080
```

**Terminal 2 - Vendor Dashboard:**
```bash
cd /Users/ayushnaik/AndroidStudioProjects/multiversesss/vendor_dashboard
flutter run -d chrome --web-port=9000
```

### **3. Test Realtime Sync**

1. **Vendor Dashboard** (port 9000): Add a product
2. **Customer App** (port 8080): Product appears instantly!
3. **Customer App**: Place an order
4. **Vendor Dashboard**: Order appears in "Pending"!

---

## ✅ ADVANTAGES

✅ **Separate codebases** - No conflicts  
✅ **Independent deployment** - Update vendor app without touching customer app  
✅ **Same Firebase** - Realtime sync maintained  
✅ **Different URLs** - Easy to manage  
✅ **Optimized for vendors** - Only vendor features  
✅ **Faster builds** - Smaller codebase  
✅ **Better security** - Vendor-only access  

---

## 🎉 SUMMARY

You now have:

1. **Customer App** - `http://localhost:8080` (main app)
2. **Vendor Dashboard** - `http://localhost:9000` (NEW - separate)
3. **Admin Dashboard** - `http://localhost:3000` (existing)

**All three apps share the same Firebase project and sync in realtime!**

---

**Ready to run!** 🚀

```bash
cd vendor_dashboard
flutter pub get
flutterfire configure --project=multiverses-8d207
flutter run -d chrome --web-port=9000
```
