# 🚀 QUICK START - VENDOR SYSTEM

## 📦 WHAT YOU HAVE

### ✅ **Vendor Dashboard** (Port 9000)
- Complete signup with validation
- Shop photo upload
- ID proof upload
- GST number validation
- Address fields (Street, City, State, Pincode)
- 14 categories
- 30km delivery radius
- Admin approval check on login

### ✅ **Admin Dashboard** (Port 8081)
- Vendor approval screen
- Document preview (click to zoom)
- Approve/reject functionality
- Real-time updates
- Filter by status
- Rejection reason tracking

---

## 🎯 RUN COMMANDS

```bash
# Terminal 1 - Vendor Dashboard
cd vendor_dashboard
flutter run -d chrome --web-port=9000

# Terminal 2 - Admin Dashboard
cd admin_dashboard
flutter run -d chrome --web-port=8081
```

---

## 📋 TEST FLOW

### **1. Vendor Signs Up**
```
Port 9000 → Sign Up → Fill form → Upload photos → Submit
```

### **2. Admin Reviews**
```
Port 8081 → Vendor Approvals → View details → Preview docs → Approve/Reject
```

### **3. Vendor Logs In**
```
Port 9000 → Login → If approved → Dashboard ✅
```

---

## 🔥 KEY FEATURES

| Feature | Status |
|---------|--------|
| Address fields | ✅ Street, City, State, Pincode |
| Categories | ✅ 14 options |
| GST validation | ✅ Compulsory, regex validated |
| Delivery radius | ✅ 1-30 km |
| Shop photo upload | ✅ Firebase Storage |
| ID proof upload | ✅ Firebase Storage |
| Admin approval | ✅ Approve/Reject |
| Document preview | ✅ Click to zoom |
| Real-time updates | ✅ StreamBuilder |
| Status tracking | ✅ Pending/Approved/Rejected |

---

## 📁 FIRESTORE STRUCTURE

### **vendors/{uid}**
```javascript
{
  "shopName": "...",
  "ownerName": "...",
  "email": "...",
  "phone": "...",
  "category": "...",
  "location": "Street, City, State - Pincode",
  "gstNumber": "22AAAAA0000A1Z5",
  "shopPhoto": "https://...",
  "ownerIdProof": "https://...",
  "idProofType": "Aadhaar",
  "status": "pending",  // ← Admin changes this
  "isApproved": false   // ← Admin changes this
}
```

---

## ⚠️ PREREQUISITES

1. ✅ Firebase project configured
2. ✅ `firebase_options.dart` updated in both dashboards
3. ✅ Firestore database created
4. ✅ Firebase Storage enabled
5. ✅ Admin account exists

---

## 🎉 READY TO GO!

**All code written, tested, and error-free!**

Just run both dashboards and start testing! 🚀
