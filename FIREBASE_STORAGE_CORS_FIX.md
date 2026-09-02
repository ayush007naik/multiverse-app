# 🔥 Fix Firebase Storage CORS for Image Previews

## Problem
Image previews in Vendor Approvals screen show "Failed to load image" due to CORS (Cross-Origin Resource Sharing) policy blocking Firebase Storage URLs on Flutter Web.

---

## ✅ Solution: Configure CORS on Firebase Storage Bucket

### **Step 1: Install Google Cloud SDK (if not installed)**

```bash
# macOS
brew install --cask google-cloud-sdk

# Or download from: https://cloud.google.com/sdk/docs/install
```

### **Step 2: Initialize gcloud**

```bash
# Initialize and login
gcloud init

# This will:
# 1. Open browser for Google login
# 2. Ask you to select/confirm project
# 3. Set default configuration
```

### **Step 3: Create cors.json File**

Create a file named `cors.json` in your project root:

```bash
cd /Users/ayushnaik/AndroidStudioProjects/multiversesss
```

Create `cors.json`:

```json
[
  {
    "origin": ["*"],
    "method": ["GET", "HEAD", "OPTIONS"],
    "maxAgeSeconds": 3600,
    "responseHeader": [
      "Content-Type",
      "Authorization",
      "Content-Length",
      "User-Agent",
      "x-goog-resumable",
      "x-goog-acl"
    ]
  }
]
```

**Save this file at:** `/Users/ayushnaik/AndroidStudioProjects/multiversesss/cors.json`

### **Step 4: Find Your Firebase Storage Bucket Name**

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Click **Storage** in left sidebar
4. Look at the bucket name (usually): `your-project-id.appspot.com`

**Or find it via CLI:**

```bash
# List all buckets
gsutil ls
```

You'll see something like:
```
gs://multiverse-admin-12345.appspot.com/
```

### **Step 5: Apply CORS Configuration**

```bash
# Navigate to project root
cd /Users/ayushnaik/AndroidStudioProjects/multiversesss

# Apply CORS to your bucket (replace with your actual bucket name)
gsutil cors set cors.json gs://your-project-id.appspot.com
```

**Example:**
```bash
gsutil cors set cors.json gs://multiverse-admin-12345.appspot.com
```

### **Step 6: Verify CORS Settings**

```bash
# Check current CORS configuration
gsutil cors get gs://your-project-id.appspot.com
```

You should see:
```json
[{"origin":["*"],"method":["GET","HEAD","OPTIONS"],"maxAgeSeconds":3600,"responseHeader":["Content-Type","Authorization","Content-Length","User-Agent","x-goog-resumable","x-goog-acl"]}]
```

---

## 🎯 Alternative: Using Firebase Console UI

If gsutil is not working, you can set CORS via Google Cloud Console:

### **Step 1: Go to Google Cloud Console**
Visit: https://console.cloud.google.com/storage/browser

### **Step 2: Select Your Bucket**
- Find and click on your bucket (e.g., `your-project-id.appspot.com`)

### **Step 3: Edit CORS**
- Click **CONFIGURATION** tab
- Scroll to **CORS** section
- Click **ADD RULE**
- Fill in:
  - **Origin**: `*` (or specific domains)
  - **Methods**: Check `GET`, `HEAD`, `OPTIONS`
  - **Max age**: `3600`
  - **Access-Control-Allow-Headers**: Check all or add custom

### **Step 4: Save**
- Click **SAVE**

---

## 🧪 Test CORS Configuration

### **Test 1: Browser Console**

1. Open your admin dashboard in Chrome
2. Press `F12` to open DevTools
3. Go to **Console** tab
4. Try to preview a vendor document
5. Check if CORS errors are gone

### **Test 2: Direct URL Test**

Open browser and paste a Firebase Storage URL directly:
```
https://firebasestorage.googleapis.com/v0/b/your-project-id.appspot.com/o/vendor_verification%2F...?alt=media
```

If it loads, CORS is working! ✅

### **Test 3: cURL Test**

```bash
curl -I -H "Origin: http://localhost" \
  https://firebasestorage.googleapis.com/v0/b/your-project-id.appspot.com/o/test.jpg?alt=media
```

Look for these headers in response:
```
Access-Control-Allow-Origin: *
Access-Control-Allow-Methods: GET, HEAD, OPTIONS
```

---

## 🚀 Run Admin Panel After CORS Fix

```bash
cd /Users/ayushnaik/AndroidStudioProjects/multiversesss/admin_dashboard

# Run on Chrome
flutter run -d chrome
```

### **Test Image Previews:**

1. ✅ Login as admin
2. ✅ Go to **Vendor Approvals**
3. ✅ Click on any vendor card
4. ✅ Click **PREVIEW** button on documents
5. ✅ Images should load without errors!

---

## 📝 Complete CORS Configuration (Recommended)

For production, use this more restrictive CORS config:

**`cors-production.json`:**

```json
[
  {
    "origin": [
      "http://localhost:.*",
      "https://your-domain.web.app",
      "https://your-domain.firebaseapp.com"
    ],
    "method": ["GET", "HEAD"],
    "maxAgeSeconds": 3600,
    "responseHeader": [
      "Content-Type",
      "Authorization",
      "Content-Length",
      "User-Agent",
      "x-goog-resumable"
    ]
  }
]
```

Apply it:
```bash
gsutil cors set cors-production.json gs://your-project-id.appspot.com
```

---

## 🐛 Troubleshooting

### **Error: "gsutil: command not found"**

```bash
# Install Google Cloud SDK
brew install --cask google-cloud-sdk

# Or use npm (alternative)
npm install -g gsutil
```

### **Error: "Unauthorized" or "Permission denied"**

```bash
# Login to Google Cloud
gcloud auth login

# Set the correct project
gcloud config set project your-project-id
```

### **CORS Still Not Working**

1. **Wait 2-3 minutes** - CORS changes take time to propagate
2. **Clear browser cache** - Press `Ctrl+Shift+Delete` in Chrome
3. **Hard reload** - Press `Ctrl+Shift+R` (or `Cmd+Shift+R` on Mac)
4. **Check bucket name** - Make sure it's correct
5. **Verify CORS** - Run `gsutil cors get gs://your-bucket`

### **Images Still Failing**

Check browser console for specific errors:
- **CORS error**: CORS not configured correctly
- **404 error**: Image URL is invalid or deleted
- **403 error**: Authentication/permission issue
- **500 error**: Firebase Storage server error

---

## ✅ Success Indicators

You'll know CORS is fixed when:

- ✅ No CORS errors in browser console
- ✅ Vendor document images load on preview
- ✅ Direct Firebase Storage URLs work in browser
- ✅ cURL test shows CORS headers
- ✅ `gsutil cors get` returns your configuration

---

## 📚 Additional Resources

- [Firebase Storage CORS Documentation](https://firebase.google.com/docs/storage/web/download-files#cors_configuration)
- [Google Cloud Storage CORS](https://cloud.google.com/storage/docs/configuring-cors)
- [gsutil CORS Command Reference](https://cloud.google.com/storage/docs/gsutil/commands/cors)

---

## 🎯 Quick Command Summary

```bash
# 1. Navigate to project
cd /Users/ayushnaik/AndroidStudioProjects/multiversesss

# 2. Create cors.json (use the JSON above)

# 3. Apply CORS
gsutil cors set cors.json gs://your-project-id.appspot.com

# 4. Verify
gsutil cors get gs://your-project-id.appspot.com

# 5. Test
flutter run -d chrome
```

---

**Status:** 🎉 **ONCE CORS IS SET, ALL IMAGE PREVIEWS WILL WORK!**
