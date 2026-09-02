# 💰 Razorpay Route Payout System - Complete Setup Guide

## 🎯 System Architecture

```
Customer Payment Flow:
Customer → Razorpay Payment Gateway → Your Razorpay Account (Platform)
                                              ↓
                                      You Keep Commission
                                              ↓
                                      Transfer to Vendor via Razorpay Route
```

## 📋 Prerequisites

### 1. Razorpay Account Setup

1. **Sign up for Razorpay**: https://dashboard.razorpay.com
2. **Activate Route** (Marketplace feature):
   - Go to Settings → Route
   - Apply for Route activation
   - Submit required documents (KYC)
   - Wait for approval (2-3 business days)

3. **Get Your Credentials**:
   - `RAZORPAY_KEY_ID` - From Dashboard → Settings → API Keys
   - `RAZORPAY_KEY_SECRET` - From Dashboard → Settings → API Keys
   - `RAZORPAY_PAYOUT_ACCOUNT_ID` - From Dashboard → Route → Account Settings
   - `RAZORPAY_WEBHOOK_SECRET` - From Dashboard → Webhooks → Create Webhook

### 2. Firebase Setup

1. **Enable Cloud Functions**:
   ```bash
   firebase init functions
   ```

2. **Set Environment Variables**:
   ```bash
   firebase functions:config:set \
     razorpay.key_id="YOUR_KEY_ID" \
     razorpay.key_secret="YOUR_KEY_SECRET" \
     razorpay.payout_account_id="YOUR_PAYOUT_ACCOUNT_ID" \
     razorpay.webhook_secret="YOUR_WEBHOOK_SECRET"
   ```

3. **Deploy Cloud Functions**:
   ```bash
   cd functions
   npm install razorpay
   firebase deploy --only functions:processPayout,functions:payoutWebhook,functions:processBulkPayouts
   ```

## 🔧 Step-by-Step Implementation

### Step 1: Install Razorpay Package

```bash
cd functions
npm install razorpay
```

### Step 2: Configure Firestore Collections

Your Firestore should have these collections:

```javascript
// vendors collection
{
  "vendorId": {
    "name": "Vendor Name",
    "email": "vendor@email.com",
    "phone": "9876543210",
    "bankAccountNumber": "1234567890",
    "ifscCode": "SBIN0001234",
    "upiId": "vendor@paytm",
    "availableBalance": 15000,
    "totalWithdrawn": 45000,
    "lastPayoutAt": Timestamp
  }
}

// payouts collection
{
  "payoutId": {
    "vendorId": "vendor_doc_id",
    "amount": 5000,
    "status": "pending", // pending, processing, completed, failed
    "method": "UPI", // or "Bank Transfer"
    "upiId": "vendor@paytm",
    "bankAccountNumber": "1234567890",
    "razorpayPayoutId": "pay_xxxxx",
    "createdAt": Timestamp,
    "processedAt": Timestamp,
    "completedAt": Timestamp
  }
}

// orders collection
{
  "orderId": {
    "vendorId": "vendor_doc_id",
    "total": 1000,
    "commissionAmount": 100,
    "status": "completed",
    "paymentStatus": "paid"
  }
}
```

### Step 3: Update Payout Request in Vendor Dashboard

The payout request button already creates a payout document in Firestore. Now we need to connect it to the Cloud Function.

Update `vendor_earnings_screen.dart`:

```dart
import 'package:cloud_functions/cloud_functions.dart';

Future<void> _requestPayout(String vendorId, BuildContext context) async {
  // ... existing code to calculate balance ...

  // Create payout request in Firestore
  final payoutRef = await FirebaseFirestore.instance
      .collection('payouts')
      .add(payoutData);

  // Call Cloud Function to process payout
  try {
    final functions = FirebaseFunctions.instance;
    final result = await functions.httpsCallable('processPayout').call({
      'payoutId': payoutRef.id,
      'vendorId': vendorId,
      'amount': availableBalance,
      'method': upiId.isNotEmpty ? 'upi' : 'bank_transfer',
      'vendorDetails': {
        'name': vendorData['name'],
        'email': vendorData['email'],
        'phone': vendorData['phone'],
        'bankAccountNumber': bankDetails,
        'ifscCode': vendorData['ifscCode'],
        'upiId': upiId,
      },
    });

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payout of ₹${availableBalance.toStringAsFixed(0)} processed!'),
        backgroundColor: Colors.green,
      ),
    );
  } catch (e) {
    // Show error message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payout failed: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
```

### Step 4: Setup Webhook in Razorpay Dashboard

1. Go to Razorpay Dashboard → Settings → Webhooks
2. Click "Create Webhook"
3. Configure:
   - **URL**: `https://us-central1-YOUR_PROJECT.cloudfunctions.net/payoutWebhook`
   - **Events to listen**:
     - ✅ `payout.processed`
     - ✅ `payout.failed`
     - ✅ `payout.reversed`
   - **Secret**: Generate a strong secret key
4. Save the webhook secret in Firebase:
   ```bash
   firebase functions:config:set razorpay.webhook_secret="YOUR_WEBHOOK_SECRET"
   ```

### Step 5: Admin Dashboard for Processing Payouts

Create an admin screen to view and process pending payouts:

```dart
class AdminPayoutsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('payouts')
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return CircularProgressIndicator();
        
        final payouts = snapshot.data!.docs;
        double totalPending = 0;
        
        for (final doc in payouts) {
          totalPending += (doc.data()['amount'] as num).toDouble();
        }
        
        return Column(
          children: [
            // Summary Card
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Pending Payouts: ${payouts.length}'),
                    Text('Total: ₹${totalPending.toStringAsFixed(0)}'),
                    ElevatedButton(
                      onPressed: () => _processAllPayouts(payouts),
                      child: Text('Process All'),
                    ),
                  ],
                ),
              ),
            ),
            
            // Payout List
            Expanded(
              child: ListView.builder(
                itemCount: payouts.length,
                itemBuilder: (context, index) {
                  final payout = payouts[index].data() as Map;
                  return ListTile(
                    title: Text('₹${payout['amount']}'),
                    subtitle: Text('Vendor: ${payout['vendorId']}'),
                    trailing: ElevatedButton(
                      onPressed: () => _processSinglePayout(payouts[index].id, payout),
                      child: Text('Process'),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
  
  Future<void> _processSinglePayout(String payoutId, Map payout) async {
    final functions = FirebaseFunctions.instance;
    await functions.httpsCallable('processPayout').call({
      'payoutId': payoutId,
      'vendorId': payout['vendorId'],
      'amount': payout['amount'],
      'method': payout['method']?.toLowerCase() == 'upi' ? 'upi' : 'bank_transfer',
      'vendorDetails': {
        'name': payout['vendorName'],
        'bankAccountNumber': payout['bankAccountNumber'],
        'ifscCode': payout['ifscCode'],
        'upiId': payout['upiId'],
      },
    });
  }
}
```

## 💸 Money Flow Example

### Scenario: Customer orders ₹1000 product

1. **Payment Received**:
   ```
   Customer pays: ₹1000
   ↓
   Razorpay Payment Gateway
   ↓
   Your Razorpay Account (Platform)
   Balance: +₹1000
   ```

2. **Commission Calculation**:
   ```
   Product price: ₹1000
   Commission rate: 10%
   Commission: ₹100
   Vendor earnings: ₹900
   ```

3. **Vendor Requests Payout**:
   ```
   Vendor clicks "Request Payout"
   ↓
   Payout created in Firestore (status: pending)
   ↓
   Admin processes payout via Cloud Function
   ↓
   Razorpay Route API called
   ↓
   Money transferred to vendor's bank/UPI
   ↓
   Payout status updated (completed)
   ```

4. **Final Balance**:
   ```
   Your Account:
   - Received: ₹1000
   - Commission kept: ₹100
   - Transferred to vendor: ₹900
   - Net profit: ₹100
   
   Vendor Account:
   - Earnings: ₹900
   - Received in bank: ₹900
   ```

## 🔐 Security Best Practices

### ✅ DO:
- Store Razorpay secrets in Firebase environment variables
- Use Cloud Functions for all Razorpay API calls
- Verify webhook signatures
- Authenticate users before processing payouts
- Log all payout transactions
- Implement rate limiting
- Set payout limits per vendor per day

### ❌ DON'T:
- Never expose Razorpay secret key in client code
- Never call Razorpay API directly from Flutter app
- Never process payouts without admin authorization
- Never skip webhook signature verification
- Never allow vendors to modify payout amounts

## 📊 Payout Status Flow

```
pending → processing → completed
   ↓
failed (retry allowed)
```

## 🎛️ Admin Controls

### Process Single Payout:
```dart
await processPayout({
  payoutId: "abc123",
  vendorId: "vendor_xyz",
  amount: 5000,
  method: "bank_transfer"
});
```

### Process Bulk Payouts:
```dart
await processBulkPayouts({
  payoutIds: ["id1", "id2", "id3"]
});
```

### View Pending Payouts:
```dart
final pendingPayouts = await getPendingPayouts();
final totalAmount = await getTotalPendingAmount();
```

## 🧪 Testing

### Test Mode Setup:
1. Use Razorpay Test Mode credentials
2. Create test vendor accounts
3. Use test bank accounts provided by Razorpay
4. Test both UPI and Bank Transfer methods
5. Verify webhook integration

### Test Scenarios:
- ✅ Successful payout
- ✅ Failed payout (insufficient balance)
- ✅ Invalid bank account
- ✅ Webhook processing
- ✅ Bulk payouts
- ✅ Duplicate payout prevention

## 🚀 Deployment Checklist

- [ ] Razorpay Route activated
- [ ] Firebase environment variables set
- [ ] Cloud Functions deployed
- [ ] Webhook configured in Razorpay
- [ ] Firestore security rules updated
- [ ] Admin dashboard implemented
- [ ] Testing completed in test mode
- [ ] Switched to production credentials

## 📞 Support

- Razorpay Support: support@razorpay.com
- Razorpay Route Docs: https://razorpay.com/docs/route/
- Firebase Functions: https://firebase.google.com/docs/functions

## 💡 Pro Tips

1. **Set Minimum Payout Amount**: Don't process payouts less than ₹100
2. **Daily Payout Limits**: Limit vendors to 1-2 payouts per day
3. **Batch Processing**: Process all payouts at once daily instead of individually
4. **Auto-Payout**: Automatically payout when vendor balance crosses threshold
5. **Payout Fees**: Razorpay charges ₹25-50 per payout - factor this into your commission
6. **Reconciliation**: Daily reconcile Razorpay settlements with Firestore records

## 📈 Scaling

For high-volume platforms:
- Use Firebase Cloud Tasks for async processing
- Implement payout queue system
- Add payout scheduling (daily/weekly)
- Enable auto-payout for trusted vendors
- Add payout analytics and reporting

---

**Note**: This system uses Razorpay Route, which requires special activation and has different pricing than standard Razorpay payments. Contact Razorpay support for Route pricing and activation.
