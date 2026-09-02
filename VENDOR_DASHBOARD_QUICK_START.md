# 🚀 VENDOR DASHBOARD - QUICK START

## Setup in 5 Minutes

### Step 1: Deploy Firestore Rules
```bash
# Copy the rules from firestore_vendor_rules.txt to your firestore.rules file
firebase deploy --only firestore:rules
```

### Step 2: Create Firestore Indexes

Go to Firebase Console → Firestore → Indexes → Create these composite indexes:

1. **Products Index**
   - Collection: `products`
   - Fields: `vendorId` (Ascending), `createdAt` (Descending)

2. **Orders by Vendor Index**
   - Collection: `orders`
   - Fields: `vendorId` (Ascending), `createdAt` (Descending)

3. **Orders by Status Index**
   - Collection: `orders`
   - Fields: `vendorId` (Ascending), `status` (Ascending), `createdAt` (Descending)

4. **Notifications Index**
   - Collection: `notifications`
   - Fields: `vendorId` (Ascending), `createdAt` (Descending)

5. **Payouts Index**
   - Collection: `payouts`
   - Fields: `vendorId` (Ascending), `createdAt` (Descending)

### Step 3: Test Vendor Signup

Run your Flutter app:
```bash
flutter run -d chrome
```

1. Navigate to Vendor Signup
2. Fill in details:
   - Shop Name: "Test Shop"
   - Owner Name: "John Doe"
   - Email: "vendor@test.com"
   - Phone: "1234567890"
   - Category: "Restaurant"
   - Location: "Mumbai, India"
   - Delivery Radius: 5 km
   - Password: "test123"

3. Submit → Status set to `pending`

### Step 4: Approve Vendor (Admin)

In Firebase Console → Firestore:

1. Find vendor in `vendors/{uid}` collection
2. Update document:
```javascript
{
  "status": "approved",
  "isApproved": true
}
```

3. Update user in `users/{uid}` collection:
```javascript
{
  "isApproved": true,
  "verificationStatus": "approved"
}
```

### Step 5: Login as Vendor

1. Go to Vendor Login
2. Email: "vendor@test.com"
3. Password: "test123"
4. Login → Access Dashboard!

---

## Dashboard Features Overview

### 📊 Dashboard Home
- Realtime stats cards
- Revenue trend chart
- Top products
- Low stock alerts

### 🛍️ Products
- Click "Add Product" button
- Fill product details
- Upload images (Firebase Storage)
- Set price and discount
- Manage stock

### 📦 Orders
- View incoming orders
- Accept/Reject pending orders
- Update status: Accepted → Preparing → Ready

### 📊 Inventory
- See stock levels
- Update quantities
- Low stock warnings

### 🎁 Offers
- Create discount offers
- Toggle active/inactive

### 📈 Analytics
- View order growth
- Peak hours analysis
- Customer stats

### 💰 Earnings
- Total earnings
- Commission deducted
- Payout history

### 🔔 Notifications
- New order alerts
- Payment notifications
- System alerts

### ⚙️ Settings
- Toggle shop open/close
- Update shop details
- Edit contact info

---

## Realtime Testing

### Test 1: Product Sync
1. Vendor adds product
2. Open customer app
3. Product should appear immediately

### Test 2: Order Flow
1. Customer places order
2. Vendor sees it in "Pending"
3. Vendor accepts → Customer sees "Accepted"
4. Vendor marks "Preparing" → Customer updates
5. Vendor marks "Ready" → Customer updates

### Test 3: Inventory
1. Vendor changes stock to 5
2. Customer app shows "Low Stock"
3. Vendor changes stock to 0
4. Customer app shows "Out of Stock"

### Test 4: Shop Status
1. Vendor closes shop
2. Customer app shows shop as closed
3. Vendor opens shop
4. Customer app shows shop as open

---

## Common Issues

### Issue: Vendor can't login
**Solution:** Check if vendor is approved by admin

### Issue: Products not showing
**Solution:** Verify Firestore indexes are created

### Issue: Images not uploading
**Solution:** Check Firebase Storage rules allow writes

### Issue: Orders not appearing
**Solution:** Verify `vendorId` field exists in order document

### Issue: Permission denied errors
**Solution:** Deploy the Firestore rules from `firestore_vendor_rules.txt`

---

## Production Checklist

- [ ] Firestore rules deployed
- [ ] All indexes created
- [ ] Firebase Storage rules configured
- [ ] Vendor approval workflow tested
- [ ] Product CRUD operations working
- [ ] Order flow end-to-end tested
- [ ] Realtime sync verified
- [ ] Image upload working
- [ ] Notifications appearing
- [ ] Analytics showing correct data
- [ ] Responsive design tested on all devices

---

## Next Steps

1. **Customize Branding**
   - Update colors in theme
   - Add your logo
   - Customize dashboard name

2. **Add Payment Integration**
   - Connect Razorpay for vendor payouts
   - Automate commission calculation

3. **Push Notifications**
   - Setup Firebase Cloud Messaging
   - Send push notifications for new orders

4. **Advanced Analytics**
   - Add more chart types
   - Export reports to CSV
   - Date range filters

5. **Multi-language Support**
   - Add localization
   - Support regional languages

---

## Support

For help:
1. Check `VENDOR_DASHBOARD_COMPLETE_GUIDE.md` for detailed documentation
2. Review Firebase Console logs
3. Verify all indexes are created
4. Test with a new vendor account

**Happy Selling!** 🎉
