import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:db_compat/db_compat.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// Force immediate log output
void log(String message) {
  print(message);
  stdout.flush();
}

/// Ultra-minimal test - Tests Firebase operations step by step
class UltraMinimalInvoiceService {
  static final UltraMinimalInvoiceService _instance = UltraMinimalInvoiceService._internal();
  
  // Lazy initialization - don't initialize in constructor
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
  UltraMinimalInvoiceService._internal();
  
  factory UltraMinimalInvoiceService() {
    return _instance;
  }

  /// Generate PDF and test Firebase operations step by step
  Future<String> generateTestInvoicePdf({
    required String orderId,
    required Map<String, dynamic> orderData,
  }) async {
    try {
      print('🎨 [UltraMinimal] Starting PDF + Firebase test');
      print('📝 OrderId: $orderId');
      print('📝 OrderData keys: ${orderData.keys.toList()}');

      // Step 1: Extract data
      print('📝 Step 1: Extracting data...');
      final invoiceNo = 'INV-TEST-${DateTime.now().millisecondsSinceEpoch}';
      final total = (orderData['total'] as num?)?.toDouble() ?? 0.0;
      print('✅ Data: InvoiceNo=$invoiceNo, Total=$total');

      // Step 2: Create PDF
      print('📝 Step 2: Creating PDF...');
      final pdf = pw.Document();
      
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) => pw.Padding(
            padding: const pw.EdgeInsets.all(50),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'TEST INVOICE',
                  style: pw.TextStyle(
                    fontSize: 28,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 30),
                pw.Text('Order ID: $orderId', style: const pw.TextStyle(fontSize: 16)),
                pw.SizedBox(height: 10),
                pw.Text('Invoice: $invoiceNo', style: const pw.TextStyle(fontSize: 16)),
                pw.SizedBox(height: 10),
                pw.Text(
                  'Total: ₹${total.toStringAsFixed(0)}',
                  style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      );
      print('✅ PDF created');

      // Step 3: Save locally
      print('📝 Step 3: Saving PDF locally...');
      final dir = await getApplicationDocumentsDirectory();
      final pdfPath = '${dir.path}/$invoiceNo.pdf';
      final pdfFile = File(pdfPath);
      final pdfBytes = await pdf.save();
      await pdfFile.writeAsBytes(pdfBytes);
      print('✅ PDF saved locally: ${pdfFile.path}');

      // Step 4: Test Firebase Storage
      print('📝 Step 4: Testing Firebase Storage upload...');
      try {
        final storageRef = storage.ref().child('test_invoices/$invoiceNo.pdf');
        print('📍 Storage path: ${storageRef.fullPath}');
        
        final uploadTask = await storageRef.putFile(pdfFile);
        print('✅ Upload task completed');
        
        final downloadUrl = await uploadTask.ref.getDownloadURL();
        print('✅ Download URL: $downloadUrl');
        
        print('✅ [UltraMinimal] Firebase Storage WORKS!');
      } catch (storageError, storageStack) {
        print('❌ [UltraMinimal] Firebase Storage FAILED');
        print('❌ Error: $storageError');
        print('❌ Stack: $storageStack');
        
        // Don't throw, continue to test Firestore
        print('📝 Continuing to test Firestore...');
      }

      // Step 5: Test Firestore
      print('📝 Step 5: Testing Firestore write...');
      try {
        await firestore.collection('test_invoices').doc(invoiceNo).set({
          'orderId': orderId,
          'invoiceNumber': invoiceNo,
          'total': total,
          'testAt': FieldValue.serverTimestamp(),
        });
        print('✅ Firestore write SUCCESS!');
      } catch (firestoreError, firestoreStack) {
        print('❌ [UltraMinimal] Firestore FAILED');
        print('❌ Error: $firestoreError');
        print('❌ Stack: $firestoreStack');
      }

      print('✅ [UltraMinimal] Test completed - check results above');
      return pdfFile.path;
    } catch (e, stackTrace) {
      print('❌ [UltraMinimal] FAILED: $e');
      print('❌ [UltraMinimal] Stack trace:');
      print('$stackTrace');
      rethrow;
    }
  }
}
