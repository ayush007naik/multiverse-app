import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:db_compat/db_compat.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../utils/price_calculator.dart';
import '../core/logging_service.dart';

class HtmlInvoiceService {
  static final HtmlInvoiceService _instance = HtmlInvoiceService._internal();

  // Lazy initialization
  FirebaseFirestore? _firestore;
  FirebaseStorage? _storage;

  FirebaseFirestore get firestore {
    _firestore ??= FirebaseFirestore.instance;
    return _firestore!;
  }

  FirebaseStorage get storage {
    _storage ??= FirebaseStorage.instance;
    return _storage!;
  }

  // Private constructor
  HtmlInvoiceService._internal();

  factory HtmlInvoiceService() => _instance;

  /// Generate premium PDF e-bill
  Future<String> generateInvoicePdf({
    required String orderId,
    required Map<String, dynamic> orderData,
    required Map<String, dynamic>? userData,
    required Map<String, dynamic>? shopData,
  }) async {
    try {
      Log.i(
        'HtmlInvoiceService',
        '🎨 [E-Bill Service] Starting PDF generation for order: $orderId',
      );

      // Step 1: Generate e-bill details
      Log.i('HtmlInvoiceService', '📝 Step 1: Generating e-bill details...');
      final invoiceNo = 'EBILL-${orderId.substring(0, 8).toUpperCase()}';
      final date = _formatDate(orderData['createdAt']);
      final paymentMethod = orderData['paymentMethod'] ?? 'Online';
      Log.i(
        'HtmlInvoiceService',
        '✅ Step 1 complete: E-Bill No=$invoiceNo, Date=$date',
      );

      // Step 2: Extract customer details
      Log.i('HtmlInvoiceService', '📝 Step 2: Extracting customer details...');
      String customerName = 'Customer';
      if (userData != null) {
        customerName =
            userData['name']?.toString() ??
            userData['displayName']?.toString() ??
            'Customer';
      }
      Log.i('HtmlInvoiceService', '✅ Customer name: $customerName');

      final phone =
          orderData['phone']?.toString() ??
          orderData['customerPhone']?.toString() ??
          'N/A';
      final email =
          orderData['email']?.toString() ??
          orderData['customerEmail']?.toString() ??
          'N/A';
      final address = _buildAddress(orderData['address']);
      Log.i('HtmlInvoiceService', '✅ Customer contact: $phone, $email');

      // Step 3: Extract shop details from Firestore shopData
      Log.i('HtmlInvoiceService', '📝 Step 3: Extracting shop details...');
      final storeName =
          shopData?['name']?.toString() ??
          orderData['shopName']?.toString() ??
          orderData['vendorName']?.toString() ??
          'Multiverse Shop';

      // Get GSTIN from shop document or vendor document
      final gstin =
          shopData?['gstNumber']?.toString() ??
          shopData?['gstin']?.toString() ??
          orderData['gstNumber']?.toString() ??
          '000000000'; // Shows 000000000 if not registered

      // Build address from shop location fields
      String storeAddress;
      if (shopData?['locationLabel'] != null &&
          shopData!['locationLabel'].toString().isNotEmpty) {
        storeAddress = shopData['locationLabel'].toString();
      } else if (shopData?['location'] != null) {
        final location = shopData!['location'];
        if (location is Map && location['label'] != null) {
          storeAddress = location['label'].toString();
        } else {
          storeAddress = 'N/A';
        }
      } else {
        storeAddress = 'N/A'; // Changed from random address
      }

      // Get phone from shop or order
      final storePhone =
          shopData?['phone']?.toString() ??
          shopData?['contact']?.toString() ??
          orderData['vendorPhone']?.toString() ??
          '000000000'; // Shows 000000000 if not registered

      Log.i('HtmlInvoiceService', '✅ Shop: $storeName');
      Log.i('HtmlInvoiceService', '✅ GSTIN: $gstin');
      Log.i('HtmlInvoiceService', '✅ Address: $storeAddress');
      Log.i('HtmlInvoiceService', '✅ Phone: $storePhone');

      // Step 4: Build items and calculate totals
      Log.i(
        'HtmlInvoiceService',
        '📝 Step 4: Building items and calculating totals...',
      );
      final items = orderData['items'] as List? ?? [];
      Log.i('HtmlInvoiceService', '✅ Items count: ${items.length}');

      // Step 5: Calculate totals
      Log.i('HtmlInvoiceService', '📝 Step 5: Calculating totals...');
      final subtotal = (orderData['subtotal'] as num?)?.toDouble() ?? 0.0;
      final totalGst =
          (orderData['totalGst'] as num?)?.toDouble() ??
          (orderData['gst'] as num?)?.toDouble() ??
          0.0;

      // Split GST into CGST and SGST (half-half)
      final cgst = totalGst / 2;
      final sgst = totalGst / 2;

      // Calculate GST percentage
      final gstPercentage = subtotal > 0
          ? ((totalGst / subtotal) * 100).toStringAsFixed(1)
          : '0';

      final deliveryFee =
          (orderData['deliveryCharges'] as num?)?.toDouble() ??
          (orderData['deliveryFee'] as num?)?.toDouble() ??
          0.0;
      final platformFee = PriceCalculator.FIXED_PLATFORM_FEE;
      final discount = (orderData['discount'] as num?)?.toDouble() ?? 0.0;
      final total = (orderData['total'] as num?)?.toDouble() ?? 0.0;
      Log.i(
        'HtmlInvoiceService',
        '✅ Totals - Subtotal: ₹$subtotal, CGST: ₹${cgst.toStringAsFixed(2)}, SGST: ₹${sgst.toStringAsFixed(2)}, Total: ₹$total',
      );

      Log.i(
        'HtmlInvoiceService',
        '✅ [E-Bill Service] Data prepared, generating PDF...',
      );

      // Step 6: Create PDF document
      Log.i('HtmlInvoiceService', '📝 Step 6: Creating PDF document...');
      final pdf = pw.Document();
      Log.i('HtmlInvoiceService', '✅ PDF document created');

      // Step 7: Add page to PDF
      Log.i('HtmlInvoiceService', '📝 Step 7: Adding page to PDF...');
      try {
        // Load logo from assets
        pw.MemoryImage? logoImage;
        try {
          final logoBytes = await rootBundle.load('assets/logo.png');
          logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
          Log.i('HtmlInvoiceService', '✅ Logo loaded successfully');
        } catch (e) {
          Log.w(
            'HtmlInvoiceService',
            '⚠️ Logo not found, continuing without it: $e',
          );
        }

        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(40),
            build: (context) => [
              _buildHeader(invoiceNo, date, paymentMethod, logo: logoImage),
              pw.SizedBox(height: 20),
              _buildStatusBadge(),
              pw.SizedBox(height: 20),
              _buildInfoCards(orderId, date, paymentMethod),
              pw.SizedBox(height: 20),
              _buildCustomerStoreDetails(
                customerName,
                phone,
                email,
                address,
                storeName,
                gstin,
                storeAddress,
                storePhone,
              ),
              pw.SizedBox(height: 20),
              _buildItemsTable(items),
              pw.SizedBox(height: 20),
              _buildBillSummary(
                subtotal,
                cgst,
                sgst,
                gstPercentage,
                deliveryFee,
                platformFee,
                discount,
                total,
              ),
              pw.SizedBox(height: 30),
              _buildFooter(),
            ],
          ),
        );
        Log.i('HtmlInvoiceService', '✅ Page added to PDF');
      } catch (pageError, pageStack) {
        Log.e(
          'HtmlInvoiceService',
          '❌ ERROR ADDING PAGE: $pageError',
          ex: pageError,
          st: pageStack,
        );
        Log.e(
          'HtmlInvoiceService',
          '❌ PAGE STACK TRACE: $pageStack',
          ex: pageError,
          st: pageStack,
        );
        rethrow;
      }

      // Step 8: Save PDF to bytes
      Log.i('HtmlInvoiceService', '📝 Step 8: Saving PDF to bytes...');
      final pdfBytes = await pdf.save();
      Log.i(
        'HtmlInvoiceService',
        '✅ PDF bytes generated: ${pdfBytes.length} bytes',
      );

      // Step 9: Get documents directory
      Log.i('HtmlInvoiceService', '📝 Step 9: Getting documents directory...');
      final dir = await getApplicationDocumentsDirectory();
      Log.i('HtmlInvoiceService', '✅ Directory: ${dir.path}');

      // Step 10: Write PDF to file
      Log.i('HtmlInvoiceService', '📝 Step 10: Writing PDF to file...');
      final pdfPath = '${dir.path}/$invoiceNo.pdf';
      final pdfFile = File(pdfPath);
      await pdfFile.writeAsBytes(pdfBytes);
      Log.i('HtmlInvoiceService', '✅ PDF written to file: ${pdfFile.path}');

      Log.i(
        'HtmlInvoiceService',
        '✅ [E-Bill Service] PDF generated: ${pdfFile.path}',
      );

      // Step 11: Upload to Firebase Storage
      Log.i(
        'HtmlInvoiceService',
        '📝 Step 11: Uploading to Firebase Storage...',
      );
      final storageRef = storage.ref().child('invoices/$invoiceNo.pdf');
      final uploadTask = await storageRef.putFile(pdfFile);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      Log.i(
        'HtmlInvoiceService',
        '✅ [E-Bill Service] PDF uploaded: $downloadUrl',
      );

      // Update Firestore
      await firestore.collection('invoices').doc('INV_$orderId').set({
        'orderId': orderId,
        'invoiceNumber': invoiceNo,
        'pdfUrl': downloadUrl,
        'status': 'completed',
        'createdAt': FieldValue.serverTimestamp(),
        'customerName': customerName,
        'customerPhone': phone,
        'shopName': storeName,
        'total': total,
      }, const SetOptions(merge: true));

      // Update order document
      await firestore.collection('orders').doc(orderId).update({
        'invoiceUrl': downloadUrl,
        'invoiceGeneratedAt': FieldValue.serverTimestamp(),
      });

      Log.i(
        'HtmlInvoiceService',
        '✅ [E-Bill Service] E-Bill generation completed successfully',
      );
      return downloadUrl;
    } catch (e, stackTrace) {
      Log.e(
        'HtmlInvoiceService',
        '❌ [E-Bill Service] E-Bill generation failed: $e',
        ex: e,
        st: stackTrace,
      );
      Log.e(
        'HtmlInvoiceService',
        '❌ [E-Bill Service] Stack trace: $stackTrace',
        ex: e,
        st: stackTrace,
      );
      rethrow;
    }
  }

  /// Build full address from parts
  String _buildAddress(dynamic address) {
    if (address == null) return 'N/A';

    if (address is Map) {
      // Try fullAddress first
      if (address['fullAddress'] != null &&
          address['fullAddress'].toString().isNotEmpty) {
        return address['fullAddress'].toString();
      }

      // Build from parts
      final lines = <String>[];

      if (address['houseNo'] != null &&
          address['houseNo'].toString().isNotEmpty) {
        lines.add(address['houseNo'].toString());
      }
      if (address['building'] != null &&
          address['building'].toString().isNotEmpty) {
        lines.add(address['building'].toString());
      }
      if (address['street'] != null &&
          address['street'].toString().isNotEmpty) {
        lines.add(address['street'].toString());
      }
      if (address['area'] != null && address['area'].toString().isNotEmpty) {
        lines.add(address['area'].toString());
      }
      if (address['city'] != null && address['city'].toString().isNotEmpty) {
        lines.add(address['city'].toString());
      }
      if (address['state'] != null && address['state'].toString().isNotEmpty) {
        lines.add(address['state'].toString());
      }
      if (address['pincode'] != null &&
          address['pincode'].toString() != '000000') {
        lines.add(address['pincode'].toString());
      }

      return lines.isNotEmpty ? lines.join(', ') : 'N/A';
    }

    return address.toString();
  }

  /// Format date
  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';

    DateTime date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is String) {
      try {
        date = DateTime.parse(timestamp);
      } catch (e) {
        return 'N/A';
      }
    } else {
      return 'N/A';
    }

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  // ========== PDF BUILDING METHODS ==========

  pw.Widget _buildHeader(
    String invoiceNo,
    String date,
    String paymentMethod, {
    pw.MemoryImage? logo,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(30),
      decoration: pw.BoxDecoration(
        gradient: pw.LinearGradient(
          colors: [PdfColor.fromHex('#1a1a1a'), PdfColor.fromHex('#000000')],
          begin: pw.Alignment.topLeft,
          end: pw.Alignment.bottomRight,
        ),
        borderRadius: pw.BorderRadius.circular(16),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Row(
            children: [
              if (logo != null)
                pw.Container(
                  width: 50,
                  height: 50,
                  child: pw.Image(logo, fit: pw.BoxFit.contain),
                ),
              if (logo != null) pw.SizedBox(width: 15),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'MULTIVERSE',
                    style: pw.TextStyle(
                      fontSize: 32,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.Text(
                    'Premium Marketplace',
                    style: const pw.TextStyle(
                      fontSize: 14,
                      color: PdfColor.fromInt(0xE6FFFFFF), // white70 equivalent
                    ),
                  ),
                ],
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: pw.BoxDecoration(
                  color: const PdfColor.fromInt(
                    0x3DFFFFFF,
                  ), // white24 equivalent
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Text(
                  'TAX E-BILL',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                invoiceNo,
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildStatusBadge() {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#10b981'),
        borderRadius: pw.BorderRadius.circular(12),
      ),
      child: pw.Text(
        'PAYMENT CONFIRMED',
        style: pw.TextStyle(
          fontSize: 14,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
      ),
    );
  }

  pw.Widget _buildInfoCards(String orderId, String date, String paymentMethod) {
    return pw.Column(
      children: [
        _buildInfoCard('Order ID', orderId),
        pw.SizedBox(height: 8),
        _buildInfoCard('Date & Time', date),
        pw.SizedBox(height: 8),
        _buildInfoCard('Payment Method', paymentMethod),
      ],
    );
  }

  pw.Widget _buildInfoCard(String label, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFF8F9FA),
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: const PdfColor.fromInt(0xFFE5E7EB)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 12,
              color: const PdfColor.fromInt(0xFF6B7280),
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildCustomerStoreDetails(
    String customerName,
    String phone,
    String email,
    String address,
    String storeName,
    String gstin,
    String storeAddress,
    String storePhone,
  ) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: _buildDetailCard('BILL TO', [
            pw.Text(
              customerName,
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Text('Phone: $phone', style: const pw.TextStyle(fontSize: 14)),
            pw.SizedBox(height: 4),
            pw.Text('Email: $email', style: const pw.TextStyle(fontSize: 14)),
            pw.SizedBox(height: 4),
            pw.Text(address, style: const pw.TextStyle(fontSize: 14)),
          ]),
        ),
        pw.SizedBox(width: 16),
        pw.Expanded(
          child: _buildDetailCard('FROM', [
            pw.Text(
              storeName,
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Text('GSTIN: $gstin', style: const pw.TextStyle(fontSize: 14)),
            pw.SizedBox(height: 4),
            pw.Text(storeAddress, style: const pw.TextStyle(fontSize: 14)),
            pw.SizedBox(height: 4),
            pw.Text(
              'Contact: $storePhone',
              style: const pw.TextStyle(fontSize: 14),
            ),
          ]),
        ),
      ],
    );
  }

  pw.Widget _buildDetailCard(String title, List<pw.Widget> children) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        gradient: const pw.LinearGradient(
          colors: [PdfColor.fromInt(0xFFF8F9FA), PdfColors.white],
          begin: pw.Alignment.topLeft,
          end: pw.Alignment.bottomRight,
        ),
        borderRadius: pw.BorderRadius.circular(16),
        border: pw.Border.all(
          color: const PdfColor.fromInt(0xFFE5E7EB),
          width: 2,
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 13,
              color: PdfColor.fromHex('#FF7A1A'),
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  pw.Widget _buildItemsTable(List<dynamic> items) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Order Items',
          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 12),
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: const PdfColor.fromInt(0xFFE5E7EB)),
            borderRadius: pw.BorderRadius.circular(12),
          ),
          child: pw.Column(
            children: [
              // Header
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  gradient: pw.LinearGradient(
                    colors: [
                      PdfColor.fromHex('#FF7A1A'),
                      PdfColor.fromHex('#FF4D4F'),
                    ],
                  ),
                  borderRadius: const pw.BorderRadius.only(
                    topLeft: pw.Radius.circular(12),
                    topRight: pw.Radius.circular(12),
                  ),
                ),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 3,
                      child: pw.Text(
                        'Item',
                        style: pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Text(
                        'Qty',
                        style: pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Text(
                        'Price',
                        style: pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Text(
                        'Total',
                        style: pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),
              // Items
              ...items.asMap().entries.map((entry) {
                final item = entry.value;
                final name =
                    item['name']?.toString() ??
                    item['productName']?.toString() ??
                    'Item';
                final qty =
                    (item['quantity'] as num?)?.toInt() ??
                    (item['qty'] as num?)?.toInt() ??
                    1;
                final price = (item['price'] as num?)?.toDouble() ?? 0.0;
                final total =
                    (item['total'] as num?)?.toDouble() ?? (price * qty);

                return pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: entry.key % 2 == 0
                        ? PdfColors.white
                        : const PdfColor.fromInt(0xFFF9FAFB),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        flex: 3,
                        child: pw.Text(
                          name,
                          style: const pw.TextStyle(fontSize: 14),
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Text(
                          '$qty',
                          style: const pw.TextStyle(fontSize: 14),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Text(
                          'Rs.${price.toStringAsFixed(0)}',
                          style: const pw.TextStyle(fontSize: 14),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Text(
                          'Rs.${total.toStringAsFixed(0)}',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                          ),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildBillSummary(
    double subtotal,
    double cgst,
    double sgst,
    String gstPercentage,
    double deliveryFee,
    double platformFee,
    double discount,
    double total,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        gradient: const pw.LinearGradient(
          colors: [PdfColor.fromInt(0xFFF8F9FA), PdfColors.white],
        ),
        borderRadius: pw.BorderRadius.circular(16),
        border: pw.Border.all(
          color: const PdfColor.fromInt(0xFFE5E7EB),
          width: 2,
        ),
      ),
      child: pw.Column(
        children: [
          _buildSummaryRow('Subtotal', 'Rs.${subtotal.toStringAsFixed(0)}'),
          pw.SizedBox(height: 8),
          _buildSummaryRow('CGST', 'Rs.${cgst.toStringAsFixed(0)}'),
          pw.SizedBox(height: 8),
          _buildSummaryRow('SGST', 'Rs.${sgst.toStringAsFixed(0)}'),
          pw.SizedBox(height: 8),
          _buildSummaryRow(
            'Delivery Charges',
            'Rs.${deliveryFee.toStringAsFixed(0)}',
          ),
          pw.SizedBox(height: 8),
          _buildSummaryRow(
            'Platform Fee',
            'Rs.${platformFee.toStringAsFixed(0)}',
          ),
          if (discount > 0) ...[
            pw.SizedBox(height: 8),
            _buildSummaryRow(
              'Discount',
              '-Rs.${discount.toStringAsFixed(0)}',
              color: PdfColor.fromHex('#10b981'),
            ),
          ],
          pw.SizedBox(height: 12),
          pw.Container(
            height: 2,
            decoration: pw.BoxDecoration(
              gradient: pw.LinearGradient(
                colors: [
                  PdfColor.fromHex('#FF7A1A'),
                  PdfColor.fromHex('#FF4D4F'),
                ],
              ),
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Grand Total',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'Rs.${total.toStringAsFixed(0)}',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#FF7A1A'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSummaryRow(String label, String value, {PdfColor? color}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 15,
            color: color ?? const PdfColor.fromInt(0xFF6B7280),
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 15,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildFooter() {
    return pw.Column(
      children: [
        pw.Container(height: 2, color: const PdfColor.fromInt(0xFFE5E7EB)),
        pw.SizedBox(height: 20),
        pw.Text(
          'Thanks for choosing Multiverse City!',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 12),
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: const pw.BoxDecoration(
            gradient: pw.LinearGradient(
              colors: [
                PdfColor.fromInt(0xFFFF6A00),
                PdfColor.fromInt(0xFFFF8C00),
              ],
            ),
            borderRadius: pw.BorderRadius.all(pw.Radius.circular(12)),
          ),
          child: pw.Column(
            children: [
              pw.Text(
                'Download Multiverse City App',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: const PdfColor.fromInt(0xFFFFFFFF),
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'For shopping, online booking, appointment & real estate',
                style: const pw.TextStyle(
                  fontSize: 12,
                  color: PdfColor.fromInt(0xFFFFFFFF),
                ),
                textAlign: pw.TextAlign.center,
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Text(
          'Need help? Contact us at support@multiverse.com | +91 7018741456',
          style: const pw.TextStyle(
            fontSize: 14,
            color: PdfColor.fromInt(0xFF6B7280),
          ),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          '© 2026 Multiverse. All rights reserved.',
          style: const pw.TextStyle(
            fontSize: 12,
            color: PdfColor.fromInt(0xFF9CA3AF),
          ),
          textAlign: pw.TextAlign.center,
        ),
      ],
    );
  }
}
