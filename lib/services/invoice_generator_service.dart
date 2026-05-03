import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

class InvoiceGeneratorService {
  static const double commissionRate = 0.10; // 10%
  static const double gstRate = 0.18; // 18%

  static Future<Map<String, dynamic>> calculateInvoiceData(String orderId) async {
    try {
      final orderDoc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .get();

      if (!orderDoc.exists) {
        throw Exception('Order not found');
      }

      final orderData = orderDoc.data()!;
      final subtotal = (orderData['subtotal'] as num?)?.toDouble() ?? 
                       (orderData['total'] as num?)?.toDouble() ?? 0.0;
      final deliveryFee = (orderData['deliveryFee'] as num?)?.toDouble() ?? 0.0;
      final totalAmount = (orderData['total'] as num?)?.toDouble() ?? (subtotal + deliveryFee);

      // Calculate commission and GST on the SUB-TOTAL (or total depending on business logic)
      final commission = subtotal * commissionRate;
      final gstOnCommission = commission * gstRate;
      final netAmount = subtotal - commission - gstOnCommission;

      return {
        'orderId': orderId,
        'invoiceNumber': 'INV-${orderId.substring(0, 8).toUpperCase()}',
        'customerName': orderData['customerName'] ?? orderData['address']?['name'] ?? 'Customer',
        'customerEmail': orderData['customerEmail'] as String?,
        'vendorName': orderData['shopName'] ?? 'Vendor',
        'subtotal': subtotal,
        'deliveryFee': deliveryFee,
        'totalAmount': totalAmount,
        'commission': commission,
        'gstOnCommission': gstOnCommission,
        'netAmount': netAmount,
        'createdAt': (orderData['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
        'items': orderData['items'] ?? [],
      };
    } catch (e) {
      throw Exception('Failed to calculate invoice data: $e');
    }
  }

  static Future<Map<String, dynamic>> generateMonthlyReport({
    required int year,
    required int month,
  }) async {
    try {
      final startOfMonth = DateTime(year, month, 1);
      final endOfMonth = DateTime(year, month + 1, 0, 23, 59, 59);

      final querySnapshot = await FirebaseFirestore.instance
          .collection('invoices')
          .where('createdAt', isGreaterThanOrEqualTo: startOfMonth)
          .where('createdAt', isLessThanOrEqualTo: endOfMonth)
          .get();

      double totalRevenue = 0;
      double totalCommission = 0;
      double totalGST = 0;
      double netAmount = 0;
      List<Map<String, dynamic>> invoices = [];

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        totalRevenue += (data['totalAmount'] as num?)?.toDouble() ?? 0;
        totalCommission += (data['commission'] as num?)?.toDouble() ?? 0;
        totalGST += (data['gstOnCommission'] as num?)?.toDouble() ?? 0;
        netAmount += (data['netAmount'] as num?)?.toDouble() ?? 0;

        invoices.add({
          'invoiceNumber': data['invoiceNumber'] ?? 'INV-${doc.id.substring(0, 8)}',
          'date': (data['createdAt'] as Timestamp).toDate(),
          'customerName': data['customerName'] ?? 'Customer',
          'totalAmount': (data['totalAmount'] as num?)?.toDouble() ?? 0,
          'commission': (data['commission'] as num?)?.toDouble() ?? 0,
          'gst': (data['gstOnCommission'] as num?)?.toDouble() ?? 0,
        });
      }

      return {
        'totalRevenue': totalRevenue,
        'totalCommission': totalCommission,
        'totalGST': totalGST,
        'netAmount': netAmount,
        'totalInvoices': querySnapshot.size,
        'invoices': invoices,
        'month': DateFormat('MMMM yyyy').format(startOfMonth),
      };
    } catch (e) {
      throw Exception('Failed to generate monthly report: $e');
    }
  }

  static Future<pw.Document> generateMonthlyReportPDF(Map<String, dynamic> reportData) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Monthly Sales Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                  pw.Text(reportData['month'] ?? '', style: pw.TextStyle(fontSize: 16)),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _pdfSummaryItem('Total Revenue', 'Rs. ${reportData['totalRevenue'].toStringAsFixed(2)}'),
                _pdfSummaryItem('Total Commission', 'Rs. ${reportData['totalCommission'].toStringAsFixed(2)}'),
                _pdfSummaryItem('Total GST', 'Rs. ${reportData['totalGST'].toStringAsFixed(2)}'),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _pdfSummaryItem('Net Amount', 'Rs. ${reportData['netAmount'].toStringAsFixed(2)}'),
                _pdfSummaryItem('Total Invoices', reportData['totalInvoices'].toString()),
                pw.SizedBox(width: 100), // Spacer
              ],
            ),
            pw.SizedBox(height: 30),
            pw.Table(
              border: pw.TableBorder.all(),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    _pdfTableCell('Date', isHeader: true),
                    _pdfTableCell('Invoice #', isHeader: true),
                    _pdfTableCell('Customer', isHeader: true),
                    _pdfTableCell('Amount', isHeader: true),
                    _pdfTableCell('Commission', isHeader: true),
                  ],
                ),
                ...(reportData['invoices'] as List).map((inv) {
                  return pw.TableRow(
                    children: [
                      _pdfTableCell(DateFormat('dd/MM/yyyy').format(inv['date'])),
                      _pdfTableCell(inv['invoiceNumber']),
                      _pdfTableCell(inv['customerName']),
                      _pdfTableCell('Rs. ${inv['totalAmount'].toStringAsFixed(2)}'),
                      _pdfTableCell('Rs. ${inv['commission'].toStringAsFixed(2)}'),
                    ],
                  );
                }).toList(),
              ],
            ),
          ];
        },
      ),
    );

    return pdf;
  }

  static pw.Widget _pdfSummaryItem(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        pw.Text(value, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  static pw.Widget _pdfTableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static Future<void> sendInvoiceByEmail(String orderId, String email) async {
    // This typically opens the email app with the PDF attached
    // Since we don't have a direct "email with attachment" tool easily, 
    // we'll share it and the user can pick email
    await shareInvoice(orderId);
  }

  static Future<String> generateAndSaveInvoice(String orderId) async {
    try {
      final invoiceData = await calculateInvoiceData(orderId);

      // Save invoice data to Firestore
      await FirebaseFirestore.instance.collection('invoices').doc(orderId).set({
        ...invoiceData,
        'generatedAt': FieldValue.serverTimestamp(),
        'generatedBy': FirebaseAuth.instance.currentUser?.uid,
      });

      // Generate PDF
      final pdf = await _generatePDF(invoiceData);

      // Save PDF to device
      final file = await _savePDF(pdf, orderId);

      return file.path;
    } catch (e) {
      throw Exception('Failed to generate invoice: $e');
    }
  }

  static Future<pw.Document> _generatePDF(Map<String, dynamic> data) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue,
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'MULTIVERSES MANDI',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      'Invoice',
                      style: pw.TextStyle(
                        fontSize: 18,
                        color: PdfColors.white,
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // Invoice Details
              pw.Text(
                'Invoice #: ${data['orderId']}',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              pw.Text('Date: ${data['createdAt'].toString().split(' ')[0]}'),
              pw.SizedBox(height: 20),

              // Customer & Vendor Details
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Customer:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text(data['customerName']),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Vendor:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text(data['vendorName']),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 30),

              // Items Table
              pw.Text('Order Items:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Item', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Qty', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Price', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                    ],
                  ),
                  ...(data['items'] as List<dynamic>).map((item) {
                    final itemData = item as Map<String, dynamic>;
                    final name = itemData['name'] ?? 'Item';
                    final qty = itemData['qty'] ?? 1;
                    final price = (itemData['price'] as num?)?.toDouble() ?? 0.0;
                    final total = price * qty;

                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(name),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(qty.toString()),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('₹${price.toStringAsFixed(2)}'),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('₹${total.toStringAsFixed(2)}'),
                        ),
                      ],
                    );
                  }),
                ],
              ),

              pw.SizedBox(height: 30),

              // Amount Breakdown
              pw.Container(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Total Amount: ₹${data['totalAmount'].toStringAsFixed(2)}'),
                    pw.Text('Commission (10%): ₹${data['commission'].toStringAsFixed(2)}'),
                    pw.Text('GST on Commission (18%): ₹${data['gstOnCommission'].toStringAsFixed(2)}'),
                    pw.Divider(),
                    pw.Text(
                      'Net Amount to Vendor: ₹${data['netAmount'].toStringAsFixed(2)}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 50),

              // Footer
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(),
                ),
                child: pw.Text(
                  'Thank you for using Multiverses Mandi!\nThis is a computer-generated invoice.',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(fontSize: 10),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  static Future<File> _savePDF(pw.Document pdf, String orderId) async {
    final output = await getTemporaryDirectory();
    final file = File('${output.path}/invoice_$orderId.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static Future<void> shareInvoice(String orderId) async {
    try {
      final filePath = await generateAndSaveInvoice(orderId);
      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Invoice for Order #$orderId',
      );
    } catch (e) {
      throw Exception('Failed to share invoice: $e');
    }
  }

  static Future<void> viewInvoice(String orderId) async {
    try {
      final filePath = await generateAndSaveInvoice(orderId);
      // You can implement platform-specific viewing here
      // For now, we'll just share it
      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Invoice for Order #$orderId',
      );
    } catch (e) {
      throw Exception('Failed to view invoice: $e');
    }
  }

  static Future<void> generateInvoicePdf(String orderId) async {
    try {
      final filePath = await generateAndSaveInvoice(orderId);
      // Show success message
      // You can implement platform-specific file opening here
    } catch (e) {
      throw Exception('Failed to generate PDF invoice: $e');
    }
  }
}