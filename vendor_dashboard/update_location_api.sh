# Update Shop Location Using Firebase REST API
# This method guarantees proper double/float types in Firestore

# ============================================
# INSTRUCTIONS:
# 1. Replace YOUR_PROJECT_ID with your Firebase project ID
# 2. Replace YOUR_VENDOR_ID with your actual vendor UID
# 3. Replace YOUR_ACCESS_TOKEN with a valid Firebase auth token
# 4. Run this script in terminal
# ============================================

# Get these from Firebase Console → Project Settings → Service Accounts → Generate new private key
PROJECT_ID="YOUR_PROJECT_ID"
VENDOR_ID="YOUR_VENDOR_ID"
ACCESS_TOKEN="YOUR_ACCESS_TOKEN"

# Your shop coordinates
LATITUDE="31.6171822"
LONGITUDE="76.9000305"

echo "🔄 Updating shop location..."
echo "📍 Vendor ID: $VENDOR_ID"
echo "📍 Latitude: $LATITUDE"
echo "📍 Longitude: $LONGITUDE"
echo ""

# Update using REST API
curl -X PATCH \
  "https://firestore.googleapis.com/v1/projects/$PROJECT_ID/databases/(default)/documents/shops/$VENDOR_ID?updateMask.fieldPaths=lat&updateMask.fieldPaths=lng&updateMask.fieldPaths=location" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"lat\": {
      \"doubleValue\": $LATITUDE
    },
    \"lng\": {
      \"doubleValue\": $LONGITUDE
    },
    \"location\": {
      \"mapValue\": {
        \"fields\": {
          \"latitude\": {
            \"doubleValue\": $LATITUDE
          },
          \"longitude\": {
            \"doubleValue\": $LONGITUDE
          }
        }
      }
    }
  }"

echo ""
echo ""
echo "✅ Shop location updated!"
echo "🎉 Check Firebase Console to verify the values are now doubles with decimal points"
