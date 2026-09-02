# 🎯 Dynamic Banner System - FIRESTORE SETUP

## ✅ What's Changed

Home screen now loads banners dynamically from Firestore instead of static assets!

---

## 📊 Firestore Structure

### Collection: `banners`

Each banner document should have these fields:

```javascript
{
  "imageUrl": "https://example.com/banner.jpg",     // Required: Banner image URL
  "title": "Summer Sale!",                           // Optional: Banner title overlay
  "subtitle": "Up to 50% off",                       // Optional: Banner subtitle
  "actionUrl": "/page/sale",                         // Optional: Navigation action
  "isActive": true,                                  // Required: Show/hide banner
  "priority": 1,                                     // Required: Sort order (1=first)
  "createdAt": Timestamp                             // Auto: Creation date
}
```

---

## 🚀 How to Add Banners from Admin Dashboard

### Option 1: Firebase Console (Quick)

1. Go to: https://console.firebase.google.com/
2. Select project: **multiverses-8d207**
3. Go to **Firestore Database**
4. Create collection: **`banners`**
5. Add document with fields above

### Option 2: Admin Dashboard (Coming Soon)

You can build a banner management screen in admin dashboard to:
- Upload banner images
- Set title/subtitle
- Configure priority/order
- Toggle active/inactive
- Set action URLs

---

## 📝 Example Banner Documents

### Banner 1: Sale Promotion
```javascript
Collection: banners
Document ID: (auto-generate)

{
  "imageUrl": "https://firebasestorage.googleapis.com/...",
  "title": "MEGA SALE",
  "subtitle": "50% OFF Everything",
  "actionUrl": "",
  "isActive": true,
  "priority": 1,
  "createdAt": Timestamp.now()
}
```

### Banner 2: New Feature
```javascript
Collection: banners
Document ID: (auto-generate)

{
  "imageUrl": "https://firebasestorage.googleapis.com/...",
  "title": "NEW",
  "subtitle": "Movie Booking Available",
  "actionUrl": "/movies",
  "isActive": true,
  "priority": 2,
  "createdAt": Timestamp.now()
}
```

---

## 🎨 Banner Features

✅ **Auto-sliding carousel** - Banners auto-rotate every 4 seconds  
✅ **Real-time updates** - Changes reflect immediately in app  
✅ **Active/Inactive toggle** - Show/hide banners instantly  
✅ **Priority ordering** - Control banner display order  
✅ **Text overlay** - Optional title/subtitle on banners  
✅ **Click actions** - Navigate to specific screens/pages  
✅ **Loading states** - Beautiful loading placeholders  
✅ **Error handling** - Graceful fallback if image fails  
✅ **Empty state** - Shows "Add banners from Admin Dashboard" when empty  
✅ **Cyberpunk styling** - Orange glow borders, smooth animations  

---

## 📱 App Behavior

### When banners exist:
- Shows carousel with all active banners
- Auto-slides if multiple banners
- Shows glowing indicators (dots)
- Click to navigate (if actionUrl set)

### When no banners:
- Shows placeholder with message
- "No Banners Available"
- "Add banners from Admin Dashboard"

### When loading:
- Shows loading spinner
- Cyberpunk styled container
- Orange border glow

### On error:
- Shows error icon
- "Failed to load banners" message

---

## 🔒 Firestore Rules (Already Set)

```javascript
match /banners/{bannerId} {
  allow read: if true;              // Public read for customer app
  allow write: if isAdmin();        // Only admin can manage banners
}
```

✅ Customers can view banners  
✅ Only admins can create/edit/delete banners  

---

## 🎯 Image URLs

You can use:
1. **Firebase Storage URLs** (Recommended)
   - Upload images to Firebase Storage
   - Copy download URL
   - Use in `imageUrl` field

2. **External URLs**
   - Any direct image URL (https://...)
   - Must be publicly accessible

3. **Asset paths** (Not recommended for dynamic banners)
   - `assets/banners/banner.png`

---

## 📸 Recommended Banner Specs

- **Aspect Ratio**: 16:9 or 2:1
- **Resolution**: 1200x600px or higher
- **Format**: PNG or JPG
- **File Size**: < 500KB for fast loading
- **Safe Area**: Keep text in center (edges may be cropped on some devices)

---

## ✨ Testing

### Test 1: Add First Banner
1. Add banner in Firestore Console
2. Set `isActive: true`
3. Open app - banner should appear immediately

### Test 2: Multiple Banners
1. Add 2-3 banners with different priorities
2. Verify auto-sliding works
3. Check indicator dots

### Test 3: Toggle Active/Inactive
1. Set `isActive: false` on a banner
2. Banner should disappear from app instantly

### Test 4: Priority Order
1. Set different priority values (1, 2, 3)
2. Verify banners display in correct order

---

## 🎉 Benefits

✅ **No app updates needed** - Change banners anytime from Firebase  
✅ **Real-time control** - Instant updates across all devices  
✅ **Admin managed** - No developer needed to change banners  
✅ **Promotions ready** - Perfect for sales, events, announcements  
✅ **Marketing tool** - Drive user engagement with dynamic content  

---

## 🚨 Important Notes

- Only **active banners** (`isActive: true`) are shown
- Banners sorted by **priority** (lower number = first)
- If **priority is same**, sorted by creation date (newest first)
- Empty `imageUrl` shows placeholder
- Invalid URLs show error state gracefully

---

**Setup complete! Start adding banners from Firebase Console or Admin Dashboard!** 🎊
