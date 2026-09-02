import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:db_compat/db_compat.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Minimal invoice service for testing - generates simple PDF
class MinimalInvoiceService {
  static final MinimalInvoiceService _instance = MinimalInvoiceService();
  factory MinimalInvoiceService() => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Generate minimal PDF invoice for testing
  Future<String> generateMinimalInvoicePdf({
    required String orderId,
    required Map<String, dynamic> orderData,
    required Map<String, dynamic>? userData,
    required Map<String, dynamic>? shopData,
  }) async {
    try {
      print('🎨 [MinimalInvoice] Starting MINIMAL PDF generation for order: $orderId');

      // Step 1: Basic data extraction
      print('📝 Step 1: Extracting basic data...');
      final invoiceNo = 'INV-${orderId.substring(0, 8).toUpperCase()}';
      final customerName = userData?['name']?.toString() ?? 'Customer';
      final total = (orderData['total'] as num?)?.toDouble() ?? 0.0;
      final storeName = shopData?['name']?.toString() ?? 'Multiverse Shop';
      print('✅ Data: InvoiceNo=$invoiceNo, Customer=$customerName, Total=$total');

      // Step 2: Create simple PDF
      print('📝 Step 2: Creating simple PDF...');
      final pdf = pw.Document();
      
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) => pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  'INVOICE',
                  style: pw.TextStyle(
                    fontSize: 32,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text('Invoice No: $invoiceNo', style: const pw.TextStyle(fontSize: 18)),
                pw.SizedBox(height: 10),
                pw.Text('Order ID: $orderId', style: const pw.TextStyle(fontSize: 16)),
                pw.SizedBox(height: 10),
                pw.Text('Customer: $customerName', style: const pw.TextStyle(fontSize: 16)),
                pw.SizedBox(height: 10),
                pw.Text('Shop: $storeName', style: const pw.TextStyle(fontSize: 16)),
                pw.SizedBox(height: 10),
                pw.Text(
                  'Total: ₹${total.toStringAsFixed(0)}',
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Thank you for shopping with Multiverse!',
                  style: const pw.TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      );
      print('✅ Simple PDF page created');

      // Step 3: Save PDF
      print('📝 Step 3: Saving PDF...');
      final pdfBytes = await pdf.save();
      print('✅ PDF bytes: ${pdfBytes.length} bytes');

      final dir = await getApplicationDocumentsDirectory();
      final pdfPath = '${dir.path}/$invoiceNo.pdf';
      final pdfFile = File(pdfPath);
      await pdfFile.writeAsBytes(pdfBytes);
      print('✅ PDF saved to: ${pdfFile.path}');

      // Step 4: Upload to Firebase
      print('📝 Step 4: Uploading to Firebase Storage...');
      final storageRef = _storage.ref().child('invoices/$invoiceNo.pdf');
      final uploadTask = await storageRef.putFile(pdfFile);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      print('✅ Uploaded to: $downloadUrl');

      // Step 5: Update Firestore
      print('📝 Step 5: Updating Firestore...');
      await _firestore.collection('invoices').doc('INV_$orderId').set({
        'orderId': orderId,
        'invoiceNumber': invoiceNo,
        'pdfUrl': downloadUrl,
        'status': 'completed',
        'createdAt': FieldValue.serverTimestamp(),
        'customerName': customerName,
        'shopName': storeName,
        'total': total,
      }, const SetOptions(merge: true));

      await _firestore.collection('orders').doc(orderId).update({
        'invoiceUrl': downloadUrl,
        'invoiceGeneratedAt': FieldValue.serverTimestamp(),
      });

      print('✅ [MinimalInvoice] Generation completed successfully');
      return downloadUrl;
    } catch (e, stackTrace) {
      print('❌ [MinimalInvoice] FAILED: $e');
      print('❌ [MinimalInvoice] Stack trace: $stackTrace');
      rethrow;
    }
  }
}
