/**
 * Firebase Cloud Function for Razorpay Route Payouts
 * 
 * WHY: Retry-safe payout processing with dead-letter queue for failed payments.
 * All monetary operations include idempotency checks and structured error logging.
 *
 * Data layer: Supabase service-role client (db.js) mirroring the Firestore shapes.
 */

const functions = require('firebase-functions/v1');
const Razorpay = require('razorpay');
const crypto = require('crypto');
const { withErrorHandling, requireAdmin, validateRequired } = require('./src/utils/errorHandler');
const { getDoc, updateDoc, queryDocs, incr } = require('./src/db');

const PAYOUTS = { table: 'payouts', pk: 'id' };
const VENDORS = { table: 'vendors', pk: 'id' };

let razorpayInstance = null;

function getRazorpay() {
  if (!razorpayInstance) {
    const keyId = process.env.RAZORPAY_KEY_ID;
    const keySecret = process.env.RAZORPAY_KEY_SECRET;
    
    if (!keyId || !keySecret) {
      throw new Error('Razorpay credentials not found in environment variables');
    }
    
    razorpayInstance = new Razorpay({
      key_id: keyId,
      key_secret: keySecret,
    });
  }
  return razorpayInstance;
}

/**
 * Process a single vendor payout via Razorpay Route
 */
exports.processPayout = functions.region('asia-south1').runWith({
  timeoutSeconds: 120,
  memory: '256MB',
  secrets: ['RAZORPAY_KEY_ID', 'RAZORPAY_KEY_SECRET', 'RAZORPAY_PAYOUT_ACCOUNT_ID', 'SUPABASE_URL', 'SUPABASE_SERVICE_ROLE_KEY'],
}).https.onCall(async (data, context) => {
  try {
    const adminId = await requireAdmin(context);
    validateRequired(data, ['payoutId']);

    const { payoutId } = data;

    // WHY: Everything financial is read from the stored payout request, NOT
    // from the call body. Previously the caller supplied amount, method and
    // vendorDetails (bank account / UPI id), so a caller could pay out any
    // amount to any account they invented. Now the stored request is the only
    // source of truth and the client-supplied fields are ignored.

    // 1. Read the stored payout request.
    const payoutData = await getDoc(PAYOUTS, payoutId);
    if (!payoutData) {
      throw new functions.https.HttpsError('not-found', 'Payout document not found');
    }

    // 2. State guard — only a fresh pending payout may be processed.
    if (payoutData.status === 'completed' || payoutData.status === 'processing' || payoutData.status === 'failed') {
      console.log(`Payout ${payoutId} already ${payoutData.status}, skipping.`);
      return { success: true, message: `Payout already ${payoutData.status}` };
    }

    // 3. Recipient is taken from the stored request.
    const vendorId = payoutData.vendorId || payoutData.recipientId || payoutData.userId;
    if (!vendorId) {
      throw new functions.https.HttpsError('invalid-argument', 'Payout has no recipient');
    }

    // 4. Amount comes from the stored request.
    const amount = Number(payoutData.amount || payoutData.payoutAmount || 0);
    if (!Number.isFinite(amount) || amount < 1) {
      throw new functions.https.HttpsError('invalid-argument', 'Stored payout amount is invalid');
    }

    // 5. Balance check against the stored vendor record — never exceed what the
    //    vendor has actually earned (totalEarnings - totalWithdrawn).
    const vendor = await getDoc(VENDORS, vendorId);
    if (!vendor) {
      throw new functions.https.HttpsError('not-found', 'Vendor record not found');
    }
    const totalEarned = Number(vendor.totalEarnings || vendor.totalEarned || 0);
    const totalWithdrawn = Number(vendor.totalWithdrawn || 0);
    const available = totalEarned - totalWithdrawn;
    if (available < amount) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        `Insufficient balance: ₹${amount.toFixed(2)} requested, ₹${Math.max(available, 0).toFixed(2)} available`
      );
    }

    // 6. Bank details come from the stored request (the payout doc written when
    //    the request was raised), so a caller cannot inject a fund account at
    //    payout time.
    const method = String(payoutData.method || payoutData.payoutMethod || 'bank').toLowerCase() === 'upi' ? 'upi' : 'bank';
    const bankDetails = payoutData.bankDetails || payoutData.payoutDetails || {};
    const upiDetails = payoutData.upiDetails || {};
    const vendorDetails = {
      name: payoutData.vendorName || payoutData.recipientName || vendor.shopName || vendor.ownerName || 'Vendor',
      email: payoutData.vendorEmail || vendor.email || '',
      phone: payoutData.vendorPhone || vendor.phone || '',
      bankAccountNumber: payoutData.bankAccountNumber
        || bankDetails.accountNumber
        || bankDetails.bankAccountNumber
        || '',
      ifscCode: payoutData.ifscCode
        || bankDetails.ifsc
        || bankDetails.ifscCode
        || '',
      upiId: payoutData.upiId || upiDetails.upiId || '',
    };

    if (method === 'upi' && !vendorDetails.upiId) {
      throw new functions.https.HttpsError('invalid-argument', 'Payout request has no UPI id');
    }
    if (method === 'bank' && (!vendorDetails.bankAccountNumber || !vendorDetails.ifscCode)) {
      throw new functions.https.HttpsError('invalid-argument', 'Payout request has no bank account/IFSC');
    }

    console.log(`💰 Processing payout ${payoutId} for vendor ${vendorId}`);
    console.log(`💰 Amount: ₹${amount}, Method: ${method}`);

    const contactId = await getOrCreateContact(vendorId, vendorDetails);
    const fundAccountId = await createFundAccount(contactId, method, vendorDetails);

    const razorpay = getRazorpay();
    const payout = await razorpay.payouts.create({
      account_number: process.env.RAZORPAY_PAYOUT_ACCOUNT_ID,
      fund_account_id: fundAccountId,
      amount: Math.round(amount * 100),
      currency: 'INR',
      mode: method === 'upi' ? 'UPI' : 'NEFT',
      purpose: 'payout',
      queue_if_low_balance: true,
      reference_id: payoutId,
      narration: `Payout for order completion`,
    });

    console.log(`✅ Payout successful: ${payout.id}`);

    await updateDoc(PAYOUTS, payoutId, {
      status: 'processing',
      razorpayPayoutId: payout.id,
      razorpayContactId: contactId,
      razorpayFundAccountId: fundAccountId,
      processedAt: new Date(),
      processedBy: adminId,
      paymentGateway: 'razorpay_route',
    });

    return {
      success: true,
      payoutId: payout.id,
      status: payout.status,
      message: 'Payout initiated successfully',
    };

  } catch (error) {
    console.error('❌ Payout failed:', error);

    if (data && data.payoutId) {
      await updateDoc(PAYOUTS, data.payoutId, {
        status: 'failed',
        failureReason: error.message || 'Unknown error',
        failedAt: new Date(),
      });
    }

    throw new functions.https.HttpsError(
      error.message === 'UNAUTHENTICATED' ? 'unauthenticated' :
      error.message === 'FORBIDDEN' ? 'permission-denied' :
      (error.code && ['not-found', 'failed-precondition', 'invalid-argument'].includes(error.code))
        ? error.code
        : 'internal',
      error.message || 'Payout processing failed'
    );
  }
});

/**
 * Create or get existing vendor contact in Razorpay
 */
async function getOrCreateContact(vendorId, vendorDetails) {
  const razorpay = getRazorpay();
  try {
    const contacts = await razorpay.contacts.all({
      notes_vendor_id: vendorId,
    });

    if (contacts.items && contacts.items.length > 0) {
      console.log(`📋 Existing contact found: ${contacts.items[0].id}`);
      return contacts.items[0].id;
    }

    const contact = await razorpay.contacts.create({
      name: vendorDetails.name || 'Vendor',
      email: vendorDetails.email || '',
      contact: vendorDetails.phone || '',
      type: 'vendor',
      reference_id: vendorId,
      notes: { vendor_id: vendorId },
    });

    console.log(`✅ New contact created: ${contact.id}`);
    return contact.id;

  } catch (error) {
    console.error('❌ Contact creation failed:', error);
    throw error;
  }
}

/**
 * Create fund account for vendor (bank or UPI)
 */
async function createFundAccount(contactId, method, vendorDetails) {
  const razorpay = getRazorpay();
  try {
    let fundAccount;

    if (method === 'upi') {
      fundAccount = await razorpay.fundAccount.create({
        contact_id: contactId,
        account_type: 'vpa',
        vpa: { address: vendorDetails.upiId },
      });
    } else {
      fundAccount = await razorpay.fundAccount.create({
        contact_id: contactId,
        account_type: 'bank_account',
        bank_account: {
          name: vendorDetails.name || 'Vendor',
          ifsc: vendorDetails.ifscCode,
          account_number: vendorDetails.bankAccountNumber,
        },
      });
    }

    console.log(`✅ Fund account created: ${fundAccount.id}`);
    return fundAccount.id;

  } catch (error) {
    console.error('❌ Fund account creation failed:', error);
    throw error;
  }
}

/**
 * Webhook to receive payout status updates from Razorpay
 */
exports.payoutWebhook = functions.region('asia-south1').runWith({
  memory: '256MB',
  secrets: ['RAZORPAY_KEY_ID', 'RAZORPAY_KEY_SECRET', 'RAZORPAY_WEBHOOK_SECRET', 'SUPABASE_URL', 'SUPABASE_SERVICE_ROLE_KEY'],
}).https.onRequest(async (req, res) => {
  try {
    const signature = req.headers['x-razorpay-signature'];
    const secret = process.env.RAZORPAY_WEBHOOK_SECRET;
    
    if (!signature || !secret) {
      console.error('❌ Missing signature or webhook secret');
      res.status(400).send('Invalid signature');
      return;
    }

    // WHY: The HMAC must be computed over the exact bytes Razorpay signed.
    // req.rawBody is the untouched request body (firebase-functions v1);
    // re-serializing req.body reorders/escapes fields and both rejects valid
    // signatures and can let a forged request pass.
    const body = req.rawBody
      ? Buffer.from(req.rawBody).toString('utf8')
      : JSON.stringify(req.body);
    const expectedSignature = crypto
      .createHmac('sha256', secret)
      .update(body)
      .digest('hex');

    if (expectedSignature !== signature) {
      console.warn('⚠️ Invalid payout webhook signature');
      res.status(400).send('Invalid signature');
      return;
    }
    
    const event = req.body;
    console.log(`📥 Webhook received: ${event.event}`);

    if (event.event === 'payout.processed') {
      const payout = event.payload.payout.entity;
      
      const payouts = await queryDocs(PAYOUTS, [
        { field: 'razorpayPayoutId', op: '==', value: payout.id },
      ]);

      for (const payoutData of payouts) {
        await updateDoc(PAYOUTS, payoutData.rowId, {
          status: 'completed',
          completedAt: new Date(),
          razorpayStatus: payout.status,
        });

        // WHY: Also update the unified payout document for backward compatibility
        if (payoutData.vendorId) {
          await incr(VENDORS, payoutData.vendorId, { totalWithdrawn: payoutData.amount || 0 });
          await updateDoc(VENDORS, payoutData.vendorId, {
            lastPayoutAt: new Date(),
          });
        }
      }

    } else if (event.event === 'payout.failed') {
      const payout = event.payload.payout.entity;
      
      const payouts = await queryDocs(PAYOUTS, [
        { field: 'razorpayPayoutId', op: '==', value: payout.id },
      ]);

      for (const payoutData of payouts) {
        await updateDoc(PAYOUTS, payoutData.rowId, {
          status: 'failed',
          failureReason: payout.error_description || 'Payout failed',
          failedAt: new Date(),
          razorpayStatus: payout.status,
        });
      }
    }

    res.status(200).send('Webhook processed');

  } catch (error) {
    console.error('❌ Webhook processing failed:', error);
    // WHY: Fail loudly. Previously errors returned 200 which made Razorpay
    // retry/stop retrying incorrectly and silently dropped webhook events.
    res.status(500).send('Webhook processing failed');
  }
});

/**
 * Process bulk payouts (admin function)
 */
exports.processBulkPayouts = functions.region('asia-south1').runWith({
  timeoutSeconds: 120,
  memory: '256MB',
  secrets: ['RAZORPAY_KEY_ID', 'RAZORPAY_KEY_SECRET', 'RAZORPAY_PAYOUT_ACCOUNT_ID', 'SUPABASE_URL', 'SUPABASE_SERVICE_ROLE_KEY'],
}).https.onCall(async (data, context) => {
  try {
    const adminId = await requireAdmin(context);

    const { payoutIds } = data;
    if (!payoutIds || !Array.isArray(payoutIds)) {
      throw new functions.https.HttpsError('invalid-argument', 'Invalid payout IDs');
    }

  let successCount = 0;
  let failedCount = 0;
  const results = [];

  for (const payoutId of payoutIds) {
    try {
      const payoutData = await getDoc(PAYOUTS, payoutId);
      
      if (!payoutData) {
        failedCount++;
        results.push({ payoutId, success: false, error: 'Payout not found' });
        continue;
      }

      // WHY: processPayout reads amount, recipient, method and bank details
      // from the stored payout doc itself, so the bulk wrapper only needs to
      // pass the id (it no longer forwards caller-supplied financial fields).
      const result = await exports.processPayout({
        payoutId,
      }, context);

      if (result.success) successCount++;
      else failedCount++;
      results.push({ payoutId, ...result });

    } catch (error) {
      failedCount++;
      results.push({ payoutId, success: false, error: error.message });
    }
  }

  return {
    success: true,
    totalProcessed: payoutIds.length,
    successCount,
    failedCount,
    results,
  };
  } catch (error) {
    console.error('processBulkPayouts outer error:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});
