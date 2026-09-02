# 🎟️ MOVIE BOOKING CHECKOUT SYSTEM - IMPLEMENTATION GUIDE

## ✨ Features Implemented

### 1. **Checkout Screen** ✅
- Beautiful checkout page with complete booking summary
- Real-time coupon fetching from Firebase
- Price breakdown with discount calculation
- Razorpay payment integration
- Booking confirmation with QR code

### 2. **Coupon Management** ✅
- Theatre admins can create coupons in the theatre dashboard
- Coupons stored in Firebase under each theatre
- Supports fixed amount and percentage-based discounts
- Max discount limit support
- Expiry date validation

### 3. **User Flow** ✅
- Customer selects seats → "PROCEED TO CHECKOUT" button
- Opens checkout page with:
  - ✅ Booking summary (movie, theatre, seats, date, time)
  - ✅ Available coupons from that theatre
  - ✅ Price breakdown with discount
  - ✅ Payment details
- Customer applies coupon → discount calculated
- Click "PAY NOW" → Razorpay payment
- Payment success → Booking saved with coupon details

---

## 📊 FIREBASE STRUCTURE FOR COUPONS

### Theatre Coupons Collection:
```
theatres/
  └── {theatreId}/
      └── active_coupons/
          ├── {couponId}/
          │   ├── code: "SUMMER50"
          │   ├── discountType: "percentage" | "fixed"
          │   ├── discountValue: 50 (for percentage) or 500 (for ₹500 off)
          │   ├── maxDiscount: 1000 (optional limit)
          │   ├── isActive: true
          │   ├── expiryDate: Timestamp
          │   ├── description: "Summer special offer"
          │   ├── minOrderValue: 0 (optional)
          │   └── usageLimit: 100 (optional)
          └── {coupon2Id}/...
```

---

## 🛠️ HOW TO ADD COUPONS FROM THEATRE DASHBOARD

### Option 1: Via Theatre Admin Panel (If exists)
1. Go to Theatre Dashboard → Settings → Coupons
2. Click "Add New Coupon"
3. Fill in the details:
   - **Code**: `SUMMER50`
   - **Discount Type**: Choose "Fixed Amount" or "Percentage"
   - **Discount Value**: 
     - For Fixed: `500` (₹500 off)
     - For Percentage: `50` (50% off)
   - **Max Discount**: `1000` (Optional, for percentage discounts)
   - **Expiry Date**: Select date
   - **Active**: Toggle ON
4. Click "Create Coupon"

### Option 2: Manual Firebase Firestore Entry
1. Go to Firebase Console → Firestore
2. Navigate to: `theatres` → Your Theatre ID → `active_coupons`
3. Add a new document with ID (e.g., `coupon_001`)
4. Add fields:
```json
{
  "code": "SUMMER50",
  "discountType": "percentage",
  "discountValue": 50,
  "maxDiscount": 1000,
  "isActive": true,
  "expiryDate": timestamp_of_expiry_date,
  "description": "Summer Special - 50% off",
  "minOrderValue": 0,
  "usageLimit": 100
}
```

---

## 📱 CUSTOMER CHECKOUT FLOW

### Step 1: Seat Selection
- Customer selects seats
- Clicks **"PROCEED TO CHECKOUT"** button

### Step 2: Checkout Page Opens
Shows:
- Movie poster + details
- Theatre name & location
- Selected date, time, seats
- All available coupons from that theatre

### Step 3: Apply Coupon (Optional)
- Swipe through available coupons
- Tap on coupon to apply
- ✅ Coupon applied with discount
- ❌ Click ✕ icon to remove

### Step 4: Review & Pay
- See price breakdown:
  ```
  Subtotal:        ₹1000
  SUMMER50 Discount: -₹500
  ─────────────────────
  Total:           ₹500
  ```
- Click **"PAY NOW"** to open Razorpay

### Step 5: Payment & Confirmation
- Razorpay payment page opens
- After payment success:
  - Booking saved with coupon code
  - Navigate to Movie Ticket screen
  - Ticket shows booking details

---

## 💾 BOOKING DATA STORED

When booking is saved, it includes:
```json
{
  "bookingId": "MB_16234567890_user123",
  "userId": "user_id",
  "movieId": "movie_123",
  "theatreId": "theatre_456",
  "showId": "show_789",
  "seats": ["A1", "A2", "A3"],
  "totalAmount": 1000,
  "discountAmount": 500,        ✅ COUPON DISCOUNT
  "appliedCoupon": "SUMMER50",  ✅ COUPON CODE
  "finalAmount": 500,           ✅ FINAL PAID AMOUNT
  "paymentId": "pay_123456789",
  "status": "confirmed",
  "createdAt": timestamp,
  "expiresAt": timestamp
}
```

---

## 🔧 CODE CHANGES SUMMARY

### Modified Files:
1. **movie_booking_screen.dart**
   - Changed button text: "PAY NOW" → "PROCEED TO CHECKOUT"
   - Navigation: Direct payment → Checkout screen
   - Added import for checkout_screen

2. **Created: checkout_screen.dart**
   - Beautiful checkout UI
   - Coupon fetching logic
   - Coupon application & discount calculation
   - Razorpay payment processing
   - Booking confirmation

---

## 🎯 EXAMPLE COUPON SETUPS

### Example 1: Fixed Amount Discount
```
Code: WELCOME100
Discount Type: Fixed
Discount Value: 100
Max Discount: 100
Description: Welcome offer - ₹100 off
```

### Example 2: Percentage Discount
```
Code: SUMMER50
Discount Type: Percentage
Discount Value: 50
Max Discount: 500
Description: Summer special - 50% off (max ₹500)
```

### Example 3: Student Discount
```
Code: STUDENT20
Discount Type: Percentage
Discount Value: 20
Max Discount: 200
Min Order Value: 400
Description: Student discount - 20% off
```

---

## ✅ TESTING THE FEATURE

### Local Testing:
1. Add test coupon via Firebase Console
2. Open app → Movies → Select movie
3. Select cinema, date, time, seats
4. Click "PROCEED TO CHECKOUT"
5. Verify coupon appears in checkout page
6. Apply coupon → verify discount calculates
7. Remove coupon → verify discount removed
8. Complete payment flow

---

## 🚀 DEPLOYMENT NOTES

- Checkout screen is fully integrated
- Coupons auto-fetch from each theatre's collection
- Expired coupons automatically hidden
- Payment processing works with existing Razorpay setup
- All booking data saved in Firebase with coupon details

---

## 📞 SUPPORT

For issues or questions, check:
- `checkout_screen.dart` - Main checkout logic
- `movie_booking_screen.dart` - Navigation to checkout
- Firebase: `theatres/{id}/active_coupons` - Coupon storage


