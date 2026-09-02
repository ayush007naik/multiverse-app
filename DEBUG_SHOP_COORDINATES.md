# 🔍 Debug Shop Coordinates in Firebase

## Problem
Customer app me shop coordinates update nahi ho rahe even after Firebase Console update.

## ✅ Solution: Verify & Fix

### Step 1: Check Current Values in Firebase

Go to Firebase Console → Firestore → `shops` collection → your shop document

**Check these fields:**
```
lat: 31.6171822 (should be double type, NOT integer)
lng: 76.9000305 (should be double type, NOT integer)
location.latitude: 31.6171822 (double)
location.longitude: 76.9000305 (double)
```

### Step 2: If Values Are Wrong/Integer

**Option A: Delete & Re-add Fields (Recommended)**

1. In Firebase Console, click ❌ to delete these fields:
   - `lat`
   - `lng`
   - `location` (entire map)

2. Click **Save**

3. Now add them back as **NEW** fields:
   - Click "Add field"
   - Name: `lat`
   - Type: **double** (use dropdown!)
   - Value: `31.6171822`
   - Save

4. Repeat for `lng` with value `76.9000305`

5. For nested `location` object:
   - Add field: `location`
   - Type: **map**
   - Inside the map, add:
     - `latitude` (double): `31.6171822`
     - `longitude` (double): `76.9000305`

**Option B: Use Firestore REST API**

```bash
# Replace these values:
PROJECT_ID="your-firebase-project-id"
SHOP_ID="your-shop-document-id"
ACCESS_TOKEN="your-access-token"

# Update with proper double types
curl -X PATCH \
  "https://firestore.googleapis.com/v1/projects/$PROJECT_ID/databases/(default)/documents/shops/$SHOP_ID?updateMask.fieldPaths=lat&updateMask.fieldPaths=lng&updateMask.fieldPaths=location" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "lat": {"doubleValue": 31.6171822},
    "lng": {"doubleValue": 76.9000305},
    "location": {
      "mapValue": {
        "fields": {
          "latitude": {"doubleValue": 31.6171822},
          "longitude": {"doubleValue": 76.9000305}
        }
      }
    }
  }'
```

### Step 3: Clear App Cache & Rebuild

**For Customer App:**

```bash
cd /Users/ayushnaik/AndroidStudioProjects/multiversesss

# Clean build
flutter clean

# Get dependencies
flutter pub get

# Rebuild
flutter run
```

**For Web:**
- Hard refresh browser: `Ctrl+Shift+R` (Windows/Linux) or `Cmd+Shift+R` (Mac)
- Or clear browser cache

### Step 4: Test in App

1. Open customer app
2. Go to home screen
3. Find your shop
4. **Check:**
   - Distance should show realistic value (e.g., "2.5 km" not "6371 km")
   - Shop location on map should be correct
   - Checkout should calculate proper delivery fee

---

## 🐛 Common Issues & Solutions

### Issue 1: Fields Still Show as Integer
**Solution:** Delete fields completely and re-add them with "double" type selected

### Issue 2: App Still Shows Old Distance
**Solution:** 
- Clear app cache
- Hot restart app (not hot reload)
- Or reinstall app

### Issue 3: Coordinates Are 0.0
**Solution:** Firebase Console me type "double" select karna hai, not "integer"

### Issue 4: location Map Not Updating
**Solution:** 
- Delete entire `location` map field
- Re-create it as map type
- Add nested `latitude` and `longitude` as doubles

---

## 📊 What Customer App Reads

The app's `ShopService.readCoordinate()` method checks in this order:

1. `shop['lat']` (top-level field)
2. `shop['latitude']` (top-level alternative)
3. `shop['location']['lat']` (nested in location map)
4. `shop['location']['latitude']` (nested alternative)

**So make sure at least ONE of these exists:**
```
Option 1:
  lat: 31.6171822 (double)
  lng: 76.9000305 (double)

Option 2:
  location: {
    latitude: 31.6171822 (double)
    longitude: 76.9000305 (double)
  }

Option 3 (Best - Both):
  lat: 31.6171822
  lng: 76.9000305
  location: {
    latitude: 31.6171822
    longitude: 76.9000305
  }
```

---

## ✅ Verification Checklist

After updating, verify:

- [ ] `lat` field exists and is type **double**
- [ ] `lng` field exists and is type **double**
- [ ] Values have decimal points (31.6171822 not 31)
- [ ] App shows correct distance
- [ ] Map shows shop at correct location
- [ ] Checkout calculates delivery fee properly

---

## 🎯 Quick Fix Summary

**If Firebase Console is not accepting decimals:**

1. **Delete** the old integer fields
2. **Add new** fields with **double** type explicitly selected
3. **Enter** decimal values: 31.6171822, 76.9000305
4. **Clear** app cache
5. **Rebuild** app

This forces Firebase to use the correct data type!
