# 💰 Complete Payment & Payout System Architecture

## 📊 System Flow Diagram

```
┌─────────────┐
│  Customer   │
└──────┬──────┘
       │ Places Order
       ▼
┌─────────────────────────┐
│   Razorpay Payment      │
│   Gateway               │
│   (UPI/Cards/Wallet)    │
└──────┬──────────────────┘
       │ Payment Success
       ▼
┌─────────────────────────┐
│  YOUR Razorpay Account  │
│  (Platform Account)     │
│  💰 Total: ₹1000        │
└──────┬──────────────────┘
       │
       ├─────────────────────────────────┐
       │                                 │
       ▼                                 ▼
┌──────────────┐              ┌──────────────────┐
│ Commission   │              │ Vendor Earnings  │
│ 10% = ₹100   │              │ 90% = ₹900       │
│ (YOUR PROFIT)│              │ (Pending)        │
└──────────────┘              └────────┬─────────┘
                                       │
                                       │ Vendor Requests Payout
                                       ▼
                          ┌──────────────────────────┐
                          │ Firestore: payouts        │
                          │ status: "pending"         │
                          │ amount: ₹900              │
                          └────────┬─────────────────┘
                                   │
                                   │ Admin Processes
                                   ▼
                          ┌──────────────────────────┐
                          │ Firebase Cloud Function   │
                          │ processPayout()           │
                          └────────┬─────────────────┘
                                   │
                                   │ API Call
                                   ▼
                          ┌──────────────────────────┐
                          │ Razorpay Route API        │
                          │ (Fund Transfer)           │
                          └────────┬─────────────────┘
                                   │
                                   │ Transfer Money
                                   ▼
                          ┌──────────────────────────┐
                          │ Vendor Bank Account/UPI   │
                          │ 💰 Received: ₹900         │
                          └──────────────────────────┘
```

## 💵 Money Flow Example

### Order: ₹1000

```
Step 1: Customer Payment
┌────────────────────────────┐
│ Customer pays: ₹1000       │
│ via UPI/Cards/Wallet       │
└────────────┬───────────────┘
             │
             ▼
┌────────────────────────────┐
│ Your Razorpay Account      │
│ Balance: +₹1000            │
└────────────────────────────┘

Step 2: Commission Split
┌────────────────────────────────────────┐
│ Your Account Breakdown:                │
│                                        │
│ Total Received:    ₹1000               │
│ Commission (10%):  ₹100  ← YOUR PROFIT │
│ Vendor Earnings:   ₹900  ← PENDING     │
└────────────────────────────────────────┘

Step 3: Vendor Requests Payout
┌────────────────────────────────────────┐
│ Payout Created in Firestore:           │
│ {                                      │
│   vendorId: "vendor_123",             │
│   amount: 900,                         │
│   status: "pending",                   │
│   method: "UPI"                        │
│ }                                      │
└────────────────────────────────────────┘

Step 4: Admin Processes Payout
┌────────────────────────────────────────┐
│ Cloud Function Called:                 │
│ processPayout({                        │
│   amount: 900,                         │
│   vendorId: "vendor_123",             │
│   method: "upi"                        │
│ })                                     │
└────────────────────────────────────────┘

Step 5: Razorpay Route Transfer
┌────────────────────────────────────────┐
│ Razorpay Route API:                    │
│ - Creates vendor contact               │
│ - Creates fund account                 │
│ - Transfers ₹900 to vendor             │
│ - Charges ₹25-50 fee                   │
└────────────────────────────────────────┘

Step 6: Money Received
┌────────────────────────────────────────┐
│ Vendor Bank/UPI:                       │
│ 💰 Credited: ₹900                      │
│ Time: 1-3 business days                │
└────────────────────────────────────────┘

Step 7: Final Status
┌────────────────────────────────────────┐
│ YOUR PROFITS:                          │
│ Commission: ₹100                       │
│ (Minus Razorpay payout fees)           │
│                                        │
│ VENDOR RECEIVED:                       │
│ Earnings: ₹900                         │
│ In bank account                        │
└────────────────────────────────────────┘
```

## 🔧 Implementation Files

### Backend (Firebase Cloud Functions):
```
functions/
├── index.js                    ← Main file (exports functions)
└── processPayout.js            ← Payout processing logic
    ├── processPayout()         ← Single payout
    ├── processBulkPayouts()    ← Bulk payouts
    └── payoutWebhook()         ← Razorpay webhook handler
```

### Frontend (Flutter):
```
vendor_dashboard/
└── lib/
    ├── services/
    │   └── razorpay_payout_service.dart  ← Payout service
    └── screens/
        └── vendor_earnings_screen.dart   ← UI with payout button
```

## 📋 Setup Steps

### 1. Razorpay Account Setup
```bash
1. Sign up: https://dashboard.razorpay.com
2. Activate Route feature
3. Get credentials:
   - RAZORPAY_KEY_ID
   - RAZORPAY_KEY_SECRET
   - RAZORPAY_PAYOUT_ACCOUNT_ID
   - RAZORPAY_WEBHOOK_SECRET
```

### 2. Firebase Configuration
```bash
# Set environment variables
firebase functions:config:set \
  razorpay.key_id="YOUR_KEY_ID" \
  razorpay.key_secret="YOUR_KEY_SECRET" \
  razorpay.payout_account_id="YOUR_PAYOUT_ACCOUNT_ID" \
  razorpay.webhook_secret="YOUR_WEBHOOK_SECRET"

# Install dependencies
cd functions
npm install razorpay

# Deploy functions
firebase deploy --only functions:processPayout,functions:payoutWebhook,functions:processBulkPayouts
```

### 3. Webhook Setup
```
Razorpay Dashboard → Settings → Webhooks → Create Webhook

URL: https://us-central1-YOUR_PROJECT.cloudfunctions.net/payoutWebhook
Events:
  ✅ payout.processed
  ✅ payout.failed
  ✅ payout.reversed
Secret: Generate strong secret
```

## 🎯 API Flow

### Vendor Requests Payout (Flutter App):
```dart
1. User clicks "Request Payout"
2. Calculate available balance
3. Create payout document in Firestore
   {
     vendorId: "abc123",
     amount: 5000,
     status: "pending",
     method: "UPI",
     createdAt: Timestamp
   }
4. Show success message
```

### Admin Processes Payout (Cloud Function):
```javascript
1. Admin calls processPayout() function
2. Function authenticates admin user
3. Creates/gets vendor contact in Razorpay
4. Creates fund account (bank/UPI)
5. Initiates payout via Razorpay Route API
6. Updates Firestore:
   {
     status: "processing",
     razorpayPayoutId: "pay_xxxxx",
     processedAt: Timestamp
   }
7. Returns success/failure
```

### Webhook Updates Status (Cloud Function):
```javascript
1. Razorpay sends webhook when payout completes
2. payoutWebhook() receives event
3. Verifies webhook signature
4. Updates Firestore:
   {
     status: "completed",
     completedAt: Timestamp
   }
5. Updates vendor earnings:
   {
     totalWithdrawn: +amount,
     availableBalance: -amount
   }
```

## 💳 Razorpay Route Features

### Supported Payout Methods:
- ✅ **NEFT/RTGS** - Bank transfer (1-3 days)
- ✅ **IMPS** - Instant bank transfer
- ✅ **UPI** - UPI ID transfer (instant)

### Payout Limits:
- Minimum: ₹1
- Maximum: ₹1,000,000 per payout
- Daily limits based on your account tier

### Fees (Approximate):
- NEFT/RTGS: ₹25-35 per payout
- IMPS: ₹30-40 per payout
- UPI: ₹25-30 per payout

*Note: Fees may vary, check Razorpay pricing*

## 🔐 Security Architecture

```
┌─────────────────────────────────────┐
│  Security Layers                    │
│                                     │
│  1. Firebase Auth                   │
│     - Only authenticated users      │
│     - Role-based access (admin)     │
│                                     │
│  2. Cloud Functions                 │
│     - Secret keys in env vars       │
│     - Never exposed to client       │
│     - HTTPS only                    │
│                                     │
│  3. Webhook Verification            │
│     - Signature validation          │
│     - HMAC-SHA256                   │
│                                     │
│  4. Firestore Rules                 │
│     - Vendor can only create        │
│     - Admin can process             │
│     - Read own payouts only         │
└─────────────────────────────────────┘
```

## 📊 Firestore Collections

### vendors:
```javascript
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
    "lastPayoutAt": Timestamp,
    "lastPayoutAmount": 5000
  }
}
```

### payouts:
```javascript
{
  "payoutId": {
    "vendorId": "vendor_doc_id",
    "amount": 5000,
    "status": "completed",  // pending → processing → completed/failed
    "method": "UPI",
    "razorpayPayoutId": "pay_xxxxx",
    "razorpayContactId": "cont_xxxxx",
    "razorpayFundAccountId": "fa_xxxxx",
    "orderCount": 15,
    "createdAt": Timestamp,
    "processedAt": Timestamp,
    "completedAt": Timestamp,
    "notes": "Payout for 15 completed orders"
  }
}
```

### orders:
```javascript
{
  "orderId": {
    "vendorId": "vendor_doc_id",
    "total": 1000,
    "commissionAmount": 100,
    "commissionRate": 10,
    "status": "completed",
    "paymentStatus": "paid",
    "earningsCredited": true,
    "createdAt": Timestamp
  }
}
```

## 🎛️ Admin Dashboard Features

### Pending Payouts View:
```dart
┌──────────────────────────────────────┐
│ PENDING PAYOUTS                      │
│                                      │
│ Total: 15 payouts | ₹45,000          │
│                                      │
│ [✅ Process All Payouts]             │
│                                      │
│ ┌────────────────────────────────┐  │
│ │ ₹5,000  | Vendor: ABC Store    │  │
│ │ UPI     | 15 orders            │  │
│ │ [Process]                      │  │
│ └────────────────────────────────┘  │
│                                      │
│ ┌────────────────────────────────┐  │
│ │ ₹3,500  | Vendor: XYZ Mart     │  │
│ │ Bank    | 10 orders            │  │
│ │ [Process]                      │  │
│ └────────────────────────────────┘  │
└──────────────────────────────────────┘
```

### Process All Button:
```dart
processBulkPayouts({
  payoutIds: ["id1", "id2", "id3"]
})
// Returns:
{
  success: true,
  totalProcessed: 15,
  successCount: 14,
  failedCount: 1,
  results: [...]
}
```

## 🧪 Testing Checklist

### Test Mode:
- [ ] Use Razorpay test credentials
- [ ] Create test vendor accounts
- [ ] Test UPI payout
- [ ] Test bank transfer payout
- [ ] Test failed payout scenarios
- [ ] Verify webhook processing
- [ ] Test bulk payouts
- [ ] Check Firestore updates

### Production:
- [ ] Switch to production credentials
- [ ] Test with small amounts (₹1-10)
- [ ] Verify bank account credits
- [ ] Monitor webhook logs
- [ ] Check payout fees
- [ ] Reconcile daily settlements

## 📈 Monitoring & Analytics

### Key Metrics to Track:
```javascript
// Daily
- Total payouts processed
- Total amount transferred
- Success rate
- Average processing time
- Failed payouts count

// Per Vendor
- Total earnings
- Total withdrawn
- Pending balance
- Payout frequency
- Average payout amount
```

### Cloud Function Logs:
```bash
# View payout logs
firebase functions:log --only processPayout

# View webhook logs
firebase functions:log --only payoutWebhook

# View last 100 entries
firebase functions:log --limit 100
```

## 🚀 Deployment Commands

```bash
# Install dependencies
cd functions
npm install

# Deploy all payout functions
firebase deploy --only functions:processPayout,functions:payoutWebhook,functions:processBulkPayouts

# Deploy with config
firebase functions:config:set \
  razorpay.key_id="rzp_test_xxx" \
  razorpay.key_secret="secret_xxx" \
  razorpay.payout_account_id="acc_xxx" \
  razorpay.webhook_secret="webhook_xxx"

# View logs
firebase functions:log
```

## 💡 Pro Tips

1. **Batch Processing**: Process payouts once daily instead of individually to save on fees
2. **Minimum Threshold**: Set minimum payout amount (e.g., ₹500) to avoid micro-transactions
3. **Auto-Payout**: Automatically payout when vendor balance crosses threshold
4. **Reconciliation**: Daily match Razorpay settlements with Firestore records
5. **Reserve Fund**: Keep 10% buffer in Razorpay account for failed payouts
6. **Notifications**: Send SMS/email to vendors when payout is processed
7. **Audit Trail**: Log all payout transactions for accounting

## 📞 Support Contacts

- **Razorpay Support**: support@razorpay.com
- **Razorpay Route Docs**: https://razorpay.com/docs/route/
- **Firebase Support**: https://firebase.google.com/support
- **Razorpay Pricing**: https://razorpay.com/route/pricing/

---

**Remember**: Razorpay Route requires separate activation and has different pricing than standard payments. Contact Razorpay sales for activation and pricing details.
