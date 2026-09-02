// 📁 lib/services/invoice_service.dart
// Complete Invoice Generation & Email System for Multiverse

import 'package:db_compat/db_compat.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:typed_data';

import '../models/invoice.dart';

class InvoiceService {
  static final InvoiceService _instance = InvoiceService._internal();
  factory InvoiceService() => _instance;
  InvoiceService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Resend API Configuration
  static const String _resendApiKey = 'YOUR_RESEND_API_KEY'; // Replace with actual key
  static const String _fromEmail = 'invoices@multiverseapp.in';

  /// Generate unique invoice number: MV/YYYY/MM/0001
  Future<String> _generateInvoiceNumber() async {
    final now = DateTime.now();
    final year = now.year;
    final month = now.month.toString().padLeft(2, '0');

    // Get count of invoices this month
    final snapshot = await _firestore
        .collection('invoices')
        .where('invoiceNumber', isGreaterThanOrEqualTo: 'MV/$year/$month/')
        .where('invoiceNumber', isLessThanOrEqualTo: 'MV/$year/$month/zzz')
        .get();

    final sequence = (snapshot.docs.length + 1).toString().padLeft(4, '0');
    return 'MV/$year/$month/$sequence';
  }

  /// Generate PDF Invoice
  Future<Uint8List> generateInvoicePdf(Invoice invoice) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          _buildHeader(invoice),
          pw.SizedBox(height: 20),
          _buildInvoiceInfo(invoice),
          pw.SizedBox(height: 20),
          _buildItemsTable(invoice),
          pw.SizedBox(height: 20),
          _buildPriceBreakdown(invoice),
          pw.SizedBox(height: 20),
          _buildPaymentInfo(invoice),
          pw.SizedBox(height: 30),
          _buildFooter(),
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildHeader(Invoice invoice) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'MULTIVERSE',
                  style: pw.TextStyle(
                    fontSize: 28,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#FF6A3D'),
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Your all-in-one marketplace',
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'INVOICE',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.black,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Invoice #: ${invoice.invoiceNumber}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ],
            ),
          ],
        ),
        pw.Divider(color: PdfColor.fromHex('#FF6A3D'), thickness: 2),
      ],
    );
  }

  pw.Widget _buildInvoiceInfo(Invoice invoice) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'FROM:',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                  color: PdfColor.fromHex('#FF6A3D'),
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(invoice.shopName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text('GSTIN: ${invoice.shopGstin}', style: const pw.TextStyle(fontSize: 9)),
              pw.Text(invoice.shopAddress, style: const pw.TextStyle(fontSize: 9)),
              pw.Text('Contact: ${invoice.shopContact}', style: const pw.TextStyle(fontSize: 9)),
            ],
          ),
        ),
        pw.SizedBox(width: 40),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'BILL TO:',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                  color: PdfColor.fromHex('#FF6A3D'),
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(invoice.customerName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text('Phone: ${invoice.customerPhone}', style: const pw.TextStyle(fontSize: 9)),
              pw.Text('Email: ${invoice.customerEmail}', style: const pw.TextStyle(fontSize: 9)),
              pw.Text(invoice.deliveryAddress, style: const pw.TextStyle(fontSize: 9)),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildItemsTable(Invoice invoice) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'ITEMS',
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 12,
            color: PdfColor.fromHex('#FF6A3D'),
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 1),
          columnWidths: {
            0: const pw.FlexColumnWidth(3),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(1.5),
            3: const pw.FlexColumnWidth(1),
            4: const pw.FlexColumnWidth(1.5),
          },
          children: [
            // Header
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColor.fromHex('#FF6A3D')),
              children: [
                _tableHeader('Item'),
                _tableHeader('Qty'),
                _tableHeader('Price'),
                _tableHeader('GST'),
                _tableHeader('Total'),
              ],
            ),
            // Items
            ...invoice.items.map((item) => pw.TableRow(
                  children: [
                    _tableCell(item.name),
                    _tableCell(item.quantity.toString()),
                    _tableCell('Rs.${item.price.toStringAsFixed(2)}'),
                    _tableCell('${item.gstPercent}%'),
                    _tableCell('Rs.${item.total.toStringAsFixed(2)}'),
                  ],
                )),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildPriceBreakdown(Invoice invoice) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          flex: 2,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'PRICE BREAKDOWN',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 12,
                  color: PdfColor.fromHex('#FF6A3D'),
                ),
              ),
              pw.SizedBox(height: 8),
              _priceRow('Subtotal', 'Rs.${invoice.subtotal.toStringAsFixed(2)}'),
              if (invoice.cgst > 0) _priceRow('CGST', 'Rs.${invoice.cgst.toStringAsFixed(2)}'),
              if (invoice.sgst > 0) _priceRow('SGST', 'Rs.${invoice.sgst.toStringAsFixed(2)}'),
              if (invoice.igst > 0) _priceRow('IGST', 'Rs.${invoice.igst.toStringAsFixed(2)}'),
              if (invoice.deliveryCharges > 0)
                _priceRow('Delivery Charges', 'Rs.${invoice.deliveryCharges.toStringAsFixed(2)}'),
              if (invoice.platformFee > 0)
                _priceRow('Platform Fee', 'Rs.${invoice.platformFee.toStringAsFixed(2)}'),
              if (invoice.discount > 0)
                _priceRow('Discount', '- Rs.${invoice.discount.toStringAsFixed(2)}'),
            ],
          ),
        ),
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.orange50,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: PdfColor.fromHex('#FF6A3D')),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'GRAND TOTAL',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 10,
                    color: PdfColor.fromHex('#FF6A3D'),
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Rs.${invoice.grandTotal.toStringAsFixed(2)}',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#FF6A3D'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildPaymentInfo(Invoice invoice) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.green50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.green),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'PAYMENT DETAILS',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
              color: PdfColors.green,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text('Payment ID: ${invoice.paymentId}', style: const pw.TextStyle(fontSize: 9)),
          pw.Text('Status: ${invoice.paymentStatus.toUpperCase()}', style: const pw.TextStyle(fontSize: 9)),
          pw.Text('Method: ${invoice.paymentMethod}', style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    );
  }

  pw.Widget _buildFooter() {
    return pw.Column(
      children: [
        pw.Divider(color: PdfColors.grey300),
        pw.SizedBox(height: 10),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Thank you for using Multiverse!',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 12,
                    color: PdfColor.fromHex('#FF6A3D'),
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text('Support: ayu007n@gmail.com', style: const pw.TextStyle(fontSize: 9)),
                pw.Text('Phone: +91 7018741456', style: const pw.TextStyle(fontSize: 9)),
              ],
            ),
            pw.Text(
              'www.multiverseapp.in',
              style: const pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _tableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          fontSize: 9,
          color: PdfColors.white,
        ),
      ),
    );
  }

  pw.Widget _tableCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 9)),
    );
  }

  pw.Widget _priceRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
          pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  /// Upload PDF to Firebase Storage
  Future<String> uploadInvoicePdf(String invoiceId, Uint8List pdfBytes) async {
    final ref = _storage.ref().child('invoices/$invoiceId.pdf');
    final uploadTask = await ref.putData(pdfBytes);
    return await uploadTask.ref.getDownloadURL();
  }

  /// Save invoice to Firestore
  Future<void> saveInvoice(Invoice invoice) async {
    await _firestore.collection('invoices').doc(invoice.id).set(invoice.toMap());
  }

  /// Send invoice via email using Resend API
  Future<bool> sendInvoiceEmail(Invoice invoice, String pdfUrl) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.resend.com/emails'),
        headers: {
          'Authorization': 'Bearer $_resendApiKey',
          'Content-Type': 'application/json',
        },
        body: {
          'from': 'Multiverse <$_fromEmail>',
          'to': [invoice.customerEmail],
          'subject': 'Your Multiverse Invoice - Order #${invoice.orderId.substring(0, 8)}',
          'html': '''
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
              <div style="background: #08080B; padding: 30px; border-radius: 10px;">
                <h1 style="color: #FF6A3D; margin: 0;">MULTIVERSE</h1>
                <p style="color: #ffffff; font-size: 12px;">Your all-in-one marketplace</p>
              </div>
              <div style="background: #ffffff; padding: 30px; margin-top: 20px; border-radius: 10px;">
                <h2 style="color: #08080B;">Thank you for your order!</h2>
                <p style="color: #666666;">Your payment has been successfully processed.</p>
                <div style="background: #f5f5f5; padding: 15px; border-radius: 8px; margin: 20px 0;">
                  <p style="margin: 5px 0;"><strong>Order ID:</strong> ${invoice.orderId.substring(0, 8)}</p>
                  <p style="margin: 5px 0;"><strong>Invoice #:</strong> ${invoice.invoiceNumber}</p>
                  <p style="margin: 5px 0;"><strong>Amount Paid:</strong> ₹${invoice.grandTotal.toStringAsFixed(2)}</p>
                </div>
                <p style="color: #666666;">Your invoice is attached to this email.</p>
                <div style="background: #f5f5f5; padding: 15px; border-radius: 8px; margin-top: 20px;">
                  <p style="margin: 5px 0; color: #666666;"><strong>Need Help?</strong></p>
                  <p style="margin: 5px 0;">Email: ayu007n@gmail.com</p>
                  <p style="margin: 5px 0;">Phone: +91 7018741456</p>
                </div>
              </div>
            </div>
          ''',
          'attachments': [
            {
              'filename': 'Invoice_${invoice.invoiceNumber.replaceAll('/', '-')}.pdf',
              'content': pdfUrl, // You'll need to download and base64 encode
            }
          ],
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Email send failed: $e');
      return false;
    }
  }

  /// Complete invoice generation flow
  Future<Invoice?> generateAndSendInvoice({
    required String orderId,
    required Map<String, dynamic> orderData,
    required String paymentId,
    required String paymentMethod,
  }) async {
    String? existingDocId;
    try {
      print('🎯 [InvoiceService] Starting HD invoice generation for order: $orderId');
      
      // Create/Update a placeholder in 'invoices' collection so UI knows we're working on it
      final docId = 'INV_$orderId';
      final invoiceDoc = await _firestore.collection('invoices').doc(docId).get();
          
      if (invoiceDoc.exists) {
        existingDocId = docId;
        await _firestore.collection('invoices').doc(docId).update({
          'pdfUrl': null, // Reset if we're regenerating
          'status': 'generating',
          'lastAttempt': FieldValue.serverTimestamp(),
        });
      } else {
        await _firestore.collection('invoices').doc(docId).set({
          'orderId': orderId,
          'pdfUrl': null,
          'status': 'generating',
          'userId': orderData['userId'] ?? orderData['customerId'],
          'vendorId': orderData['vendorId'] ?? orderData['shopOwnerId'],
          'shopId': orderData['shopId'],
          'createdAt': FieldValue.serverTimestamp(),
          'invoiceNumber': 'PENDING', 
        });
        existingDocId = docId;
      }

      // Ensure user is authenticated
      if (FirebaseAuth.instance.currentUser == null) {
        throw Exception('User must be logged in to generate invoices.');
      }

      // Call the Puppeteer Cloud Function
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
        'generateOrderInvoice',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 300)),
      );
      
      final result = await callable.call(<String, dynamic>{
        'orderId': orderId,
      });

      if (result.data != null && (result.data as Map)['success'] == true) {
        final String pdfUrl = result.data['url'];
        print('✅ [InvoiceService] Cloud Function generated PDF: $pdfUrl');
        
        // Ensure the invoice doc is updated with completion status
        await _firestore.collection('invoices').doc(existingDocId).update({
          'pdfUrl': pdfUrl,
          'status': 'completed',
          'updatedAt': FieldValue.serverTimestamp(),
        });
              
        // Fetch the latest data to return a full Invoice object
        final finalDoc = await _firestore.collection('invoices').doc(existingDocId).get();
        if (finalDoc.exists && finalDoc.data() != null) {
          return Invoice.fromMap(finalDoc.data()!);
        } else {
          // Fallback if doc was deleted or something went wrong with fetching
          return _generateLocalFallback(orderId, orderData, paymentId, paymentMethod, existingDocId);
        }
      }

      print('⚠️ [InvoiceService] Cloud Function failed. Falling back to local generation.');
      return _generateLocalFallback(orderId, orderData, paymentId, paymentMethod, existingDocId);
    } catch (e) {
      print('❌ [InvoiceService] Cloud Function call failed: $e');
      print('⚠️ [InvoiceService] Falling back to local generation...');
      final result = await _generateLocalFallback(orderId, orderData, paymentId, paymentMethod, existingDocId);
      
      if (result == null && existingDocId != null) {
        // If both failed, mark as failed in Firestore so UI stops polling
        await _firestore.collection('invoices').doc(existingDocId).update({
          'status': 'failed',
          'error': e.toString(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      return result;
    }
  }

  Future<Invoice?> _generateLocalFallback(
    String orderId,
    Map<String, dynamic> orderData,
    String paymentId,
    String paymentMethod,
    String? existingDocId,
  ) async {
    try {
      // Generate invoice number
      final invoiceNumber = await _generateInvoiceNumber();

      // Extract address safely
      String deliveryAddress = _extractAddress(orderData['address'] ?? orderData['deliveryAddress']);

      // Create invoice object
      final invoice = Invoice(
        id: existingDocId ?? 'INV_${DateTime.now().millisecondsSinceEpoch}',
        invoiceNumber: invoiceNumber,
        orderId: orderId,
        customerEmail: orderData['customerEmail'] ?? orderData['email'] ?? '',
        customerName: orderData['customerName'] ?? orderData['address']?['name'] ?? 'Customer',
        customerPhone: orderData['customerPhone'] ?? orderData['address']?['phone'] ?? '',
        deliveryAddress: deliveryAddress,
        shopName: orderData['shopName'] ?? orderData['vendorName'] ?? 'Multiverse Shop',
        shopGstin: orderData['shopGstin'] ?? orderData['storeGSTIN'] ?? '22AAAAA0000A1Z5',
        shopAddress: orderData['shopAddress'] ?? orderData['storeAddress'] ?? 'Mandi, Himachal Pradesh',
        shopContact: orderData['shopContact'] ?? '+91 7018741456',
        items: _parseItems(orderData['items']),
        subtotal: (orderData['subtotal'] as num?)?.toDouble() ?? 0.0,
        cgst: (orderData['cgst'] as num?)?.toDouble() ?? 0.0,
        sgst: (orderData['sgst'] as num?)?.toDouble() ?? 0.0,
        igst: (orderData['igst'] as num?)?.toDouble() ?? 0.0,
        deliveryCharges: (orderData['deliveryCharges'] as num?)?.toDouble() ?? (orderData['deliveryFee'] as num?)?.toDouble() ?? 0.0,
        platformFee: 5.0, // Consistent with UI and Cloud Function
        discount: (orderData['discount'] as num?)?.toDouble() ?? 0.0,
        grandTotal: (orderData['total'] as num?)?.toDouble() ?? 0.0,
        paymentId: paymentId,
        paymentStatus: 'paid',
        paymentMethod: paymentMethod,
        createdAt: DateTime.now(),
      );

      // Generate PDF
      final pdfBytes = await generateInvoicePdf(invoice);

      // Upload to Firebase Storage
      final pdfUrl = await uploadInvoicePdf(invoice.id, pdfBytes);

      // Update/Save to Firestore
      final updatedInvoice = Invoice(
        id: invoice.id,
        invoiceNumber: invoice.invoiceNumber,
        orderId: invoice.orderId,
        customerEmail: invoice.customerEmail,
        customerName: invoice.customerName,
        customerPhone: invoice.customerPhone,
        deliveryAddress: invoice.deliveryAddress,
        shopName: invoice.shopName,
        shopGstin: invoice.shopGstin,
        shopAddress: invoice.shopAddress,
        shopContact: invoice.shopContact,
        items: invoice.items,
        subtotal: invoice.subtotal,
        cgst: invoice.cgst,
        sgst: invoice.sgst,
        igst: invoice.igst,
        deliveryCharges: invoice.deliveryCharges,
        platformFee: invoice.platformFee,
        discount: invoice.discount,
        grandTotal: invoice.grandTotal,
        paymentId: invoice.paymentId,
        paymentStatus: invoice.paymentStatus,
        paymentMethod: invoice.paymentMethod,
        createdAt: invoice.createdAt,
        pdfUrl: pdfUrl,
        emailSent: true,
      );

      // Use set with merge if we have a doc ID
      if (existingDocId != null) {
        await _firestore.collection('invoices').doc(existingDocId).set(
          updatedInvoice.toMap()..['status'] = 'completed', 
          const SetOptions(merge: true)
        );
      } else {
        await saveInvoice(updatedInvoice);
      }
      
      // Update order doc as well
      await _firestore.collection('orders').doc(orderId).update({
        'invoiceUrl': pdfUrl,
      });

      return updatedInvoice;
    } catch (e) {
      print('❌ [InvoiceService] Local fallback failed: $e');
      return null;
    }
  }

  String _extractAddress(dynamic address) {
    if (address == null) return 'N/A';
    if (address is String) return address;
    if (address is Map) {
      if (address['fullAddress'] != null && address['fullAddress'].toString().isNotEmpty) {
        return address['fullAddress'].toString();
      }
      final parts = <String>[];
      if (address['houseNo'] != null && address['houseNo'].toString().isNotEmpty) parts.add(address['houseNo'].toString());
      if (address['street'] != null && address['street'].toString().isNotEmpty) parts.add(address['street'].toString());
      if (address['area'] != null && address['area'].toString().isNotEmpty && address['area'] != 'Location unavailable') parts.add(address['area'].toString());
      if (address['city'] != null && address['city'].toString().isNotEmpty) parts.add(address['city'].toString());
      if (address['pincode'] != null && address['pincode'].toString().isNotEmpty) parts.add(address['pincode'].toString());
      return parts.isEmpty ? 'N/A' : parts.join(', ');
    }
    return 'N/A';
  }

  List<InvoiceItem> _parseItems(dynamic items) {
    if (items == null) return [];
    if (items is List) {
      return items.map((item) {
        if (item is Map<String, dynamic>) {
          return InvoiceItem.fromMap(item);
        }
        return InvoiceItem(
          name: item['name']?.toString() ?? 'Item',
          quantity: (item['quantity'] as num?)?.toInt() ?? 1,
          price: (item['price'] as num?)?.toDouble() ?? 0.0,
          total: (item['total'] as num?)?.toDouble() ?? 0.0,
        );
      }).toList();
    }
    return [];
  }

  /// Resend invoice email
  Future<bool> resendInvoice(String invoiceId) async {
    try {
      final doc = await _firestore.collection('invoices').doc(invoiceId).get();
      if (!doc.exists) return false;

      final invoice = Invoice.fromMap(doc.data()!);
      if (invoice.pdfUrl == null) return false;

      return await sendInvoiceEmail(invoice, invoice.pdfUrl!);
    } catch (e) {
      print('Resend failed: $e');
      return false;
    }
  }
}
