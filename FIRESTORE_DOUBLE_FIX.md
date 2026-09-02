# 🔥 Fix Firebase Console Integer Issue for Coordinates

## Problem
Firebase Console is treating your coordinates as **int64 (integers)** instead of **double/float**, so it's rejecting decimal points like `31.6171822`.

## ✅ Solution: Use Firestore Web UI Correctly

### Method 1: Firebase Console - The RIGHT Way

When editing in Firebase Console, you need to **explicitly specify the type**:

1. Go to Firebase Console → Firestore Database
2. Find your shop document in `shops` collection
3. Click on the field you want to edit (e.g., `lat`)
4. **IMPORTANT:** When entering the value, you'll see a dropdown next to the input field
5. **Change the type from `integer` to `double`** using the dropdown
6. Now enter your decimal value: `31.6171822`
7. Click Save

**Do this for all 4 fields:**
- `lat` → change type to **double** → enter `31.6171822`
- `lng` → change type to **double** → enter `76.9000305`
- `location.latitude` → change type to **double** → enter `31.6171822`
- `location.longitude` → change type to **double** → enter `76.9000305`

### Method 2: Use the Web Tool (Easiest!)

I created a simple web page for you:

**File:** `vendor_dashboard/update_shop_location_web.html`

**Steps:**
1. Open the file `vendor_dashboard/update_shop_location_web.html` in a text editor
2. Replace the Firebase config with your project's config:
   ```javascript
   const firebaseConfig = {
       apiKey: "YOUR_API_KEY",
       authDomain: "YOUR_PROJECT.firebaseapp.com",
       projectId: "YOUR_PROJECT_ID",
       storageBucket: "YOUR_PROJECT.appspot.com",
       messagingSenderId: "YOUR_SENDER_ID",
       appId: "YOUR_APP_ID"
   };
   ```
   
   **Where to find this:**
   - Firebase Console → Project Settings ⚙️
   - Scroll down to "Your apps"
   - Click the Web app icon (`</>`)
   - Copy the config object

3. Save the file
4. Open it in your browser (double-click the HTML file)
5. Enter your Vendor ID
6. Coordinates are already pre-filled: `31.6171822`, `76.9000305`
7. Click "Update Shop Location"
8. Done! ✅

### Method 3: Use Firebase CLI (If you have it installed)

Create a file `update.js`:
```javascript
const admin = require('firebase-admin');

// Initialize with your service account
const serviceAccount = require('./path-to-service-account.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function updateLocation() {
  const vendorId = 'YOUR_VENDOR_ID_HERE'; // Replace this
  
  // JavaScript automatically treats these as doubles
  await db.collection('shops').doc(vendorId).update({
    lat: 31.6171822,
    lng: 76.9000305,
    location: {
      latitude: 31.6171822,
      longitude: 76.9000305
    },
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  });
  
  console.log('✅ Updated successfully!');
  process.exit();
}

updateLocation();
```

Run it:
```bash
npm install firebase-admin
node update.js
```

### Method 4: Use cURL REST API (Advanced)

I created a script: `vendor_dashboard/update_location_api.sh`

This uses Firebase REST API and explicitly specifies `doubleValue` type.

**Steps:**
1. Open `update_location_api.sh`
2. Replace:
   - `YOUR_PROJECT_ID`
   - `YOUR_VENDOR_ID`
   - `YOUR_ACCESS_TOKEN` (get from `gcloud auth print-access-token`)
3. Run: `bash update_location_api.sh`

---

## 🎯 Recommended: Method 1 or Method 2

**Method 1** is fastest if you just want to edit directly in Firebase Console - just make sure to **change the type dropdown to "double"** before entering the value.

**Method 2** is easiest if you want a simple UI that handles everything automatically.

---

## ✅ Verify the Update

After updating, check Firebase Console:
- The values should now show with decimal points
- The type should say `double` not `integer`
- Example: `31.6171822` (double) NOT `31` (integer)

---

## 📝 Your Coordinates (for reference)

- **Latitude:** 31.6171822
- **Longitude:** 76.9000305

---

## 🐛 Still Having Issues?

If Firebase Console still won't accept decimals:

1. **Delete the old fields first:**
   - Click the ❌ next to each field (`lat`, `lng`, etc.)
   - Save the document
   
2. **Add new fields:**
   - Click "Add field"
   - Name: `lat`
   - Type: **double** (use dropdown)
   - Value: `31.6171822`
   - Save

3. **Repeat for all 4 fields**

This forces Firebase to create new fields with the correct type.

---

## 🎉 After Update

Once the coordinates are properly saved as doubles:
- ✅ Customer app will calculate correct distances
- ✅ Delivery fees will be accurate
- ✅ Shop sorting by distance will work
- ✅ New vendors will auto-capture GPS during signup
