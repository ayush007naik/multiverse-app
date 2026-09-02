import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:db_compat/db_compat.dart';
import '../core/logging_service.dart';

class MoviePdfService {
  static Future<Uint8List> generateTicketPdfBytes(
    Map<String, dynamic> bookingData,
  ) async {
    final pdf = pw.Document();

    pw.MemoryImage? logoImage;
    try {
      final ByteData bytes = await rootBundle.load('assets/logo.png');
      final Uint8List list = bytes.buffer.asUint8List();
      logoImage = pw.MemoryImage(list);
    } catch (e) {
      Log.e('MoviePdfService', 'Error loading logo: $e', ex: e);
    }

    final seats = _getSeats(bookingData);
    final seatCount = seats.length;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(0),
        build: (pw.Context context) {
          return pw.Container(
            decoration: const pw.BoxDecoration(color: PdfColors.black),
            child: pw.Column(
              children: [
                // Header
                pw.Container(
                  padding: const pw.EdgeInsets.fromLTRB(32, 32, 32, 16),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(
                        color: PdfColors.orange800,
                        width: 2,
                      ),
                    ),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Row(
                        children: [
                          if (logoImage != null)
                            pw.Container(
                              width: 48,
                              height: 48,
                              child: pw.Image(
                                logoImage,
                                fit: pw.BoxFit.contain,
                              ),
                            ),
                          if (logoImage != null) pw.SizedBox(width: 12),
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'MULTIVERSE CITY',
                                style: pw.TextStyle(
                                  fontSize: 20,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.orange800,
                                  letterSpacing: 2,
                                ),
                              ),
                              pw.Text(
                                'CINEMA E-TICKET',
                                style: const pw.TextStyle(
                                  fontSize: 10,
                                  color: PdfColors.grey400,
                                  letterSpacing: 3,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: const pw.BoxDecoration(
                          color: PdfColors.grey900,
                          borderRadius: pw.BorderRadius.all(
                            pw.Radius.circular(4),
                          ),
                        ),
                        child: pw.Text(
                          bookingData['ticketNumber'] ?? '',
                          style: const pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.orange800,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Movie Details Section
                pw.Container(
                  padding: const pw.EdgeInsets.all(32),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'MOVIE',
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.grey500,
                          letterSpacing: 2,
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        (bookingData['movieName'] ??
                                bookingData['movieTitle'] ??
                                '')
                            .toString()
                            .toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 26,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                          letterSpacing: 1,
                        ),
                      ),
                      pw.SizedBox(height: 12),
                      pw.Row(
                        children: [
                          pw.Container(
                            width: 10,
                            height: 10,
                            decoration: const pw.BoxDecoration(
                              color: PdfColors.orange800,
                              shape: pw.BoxShape.circle,
                            ),
                          ),
                          pw.SizedBox(width: 8),
                          pw.Text(
                            '${bookingData['theatreName'] ?? ''}  ${bookingData['screenName'] ?? ''}',
                            style: const pw.TextStyle(
                              fontSize: 12,
                              color: PdfColors.grey300,
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 16),
                      pw.Row(
                        children: [
                          _detailBox('DATE', bookingData['date'] ?? '-'),
                          pw.SizedBox(width: 16),
                          _detailBox('TIME', bookingData['time'] ?? '-'),
                        ],
                      ),
                    ],
                  ),
                ),

                pw.Container(height: 1, color: PdfColors.grey800),

                // Booking Details
                pw.Container(
                  padding: const pw.EdgeInsets.all(32),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'BOOKING',
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.grey500,
                          letterSpacing: 2,
                        ),
                      ),
                      pw.SizedBox(height: 12),
                      _dataRow('Customer', bookingData['customerName'] ?? '-'),
                      pw.SizedBox(height: 8),
                      _dataRow('Phone', bookingData['customerPhone'] ?? '-'),
                      pw.SizedBox(height: 8),
                      _dataRow('Booking ID', bookingData['bookingId'] ?? ''),
                      pw.SizedBox(height: 8),
                      _dataRow(
                        'Seats',
                        '${seats.join(', ')}  ($seatCount Tickets)',
                      ),
                    ],
                  ),
                ),

                pw.Container(height: 1, color: PdfColors.grey800),

                // Payment Details
                pw.Container(
                  padding: const pw.EdgeInsets.all(32),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'PAYMENT',
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.grey500,
                          letterSpacing: 2,
                        ),
                      ),
                      pw.SizedBox(height: 12),
                      _dataRow(
                        'Ticket Price',
                        'Rs.${bookingData['ticketPrice'] ?? bookingData['totalAmount'] ?? bookingData['finalAmount'] ?? 0}',
                      ),
                      pw.SizedBox(height: 8),
                      _dataRow(
                        'Convenience Fee',
                        'Rs.${bookingData['convenienceFee'] ?? 0}',
                      ),
                      pw.SizedBox(height: 8),
                      _dataRow(
                        'Platform Fee',
                        'Rs.${bookingData['platformFee'] ?? 0}',
                      ),
                      pw.SizedBox(height: 8),
                      _dataRow('GST & Other', 'Rs.${bookingData['gst'] ?? 0}'),
                      pw.SizedBox(height: 8),
                      pw.Container(height: 1, color: PdfColors.grey700),
                      pw.SizedBox(height: 8),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Total Paid',
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                            ),
                          ),
                          pw.Text(
                            'Rs.${bookingData['totalPaid'] ?? bookingData['finalAmount'] ?? 0}',
                            style: pw.TextStyle(
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.orange800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                pw.Expanded(child: pw.SizedBox()),

                // Large QR Code
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 24,
                  ),
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'SCAN AT ENTRANCE',
                        style: const pw.TextStyle(
                          fontSize: 12,
                          color: PdfColors.orange800,
                          letterSpacing: 3,
                        ),
                      ),
                      pw.SizedBox(height: 16),
                      pw.Container(
                        width: 180,
                        height: 180,
                        decoration: const pw.BoxDecoration(
                          color: PdfColors.white,
                          borderRadius: pw.BorderRadius.all(
                            pw.Radius.circular(12),
                          ),
                        ),
                        padding: const pw.EdgeInsets.all(10),
                        child: pw.BarcodeWidget(
                          barcode: pw.Barcode.qrCode(),
                          data: _buildQrData(bookingData),
                          width: 160,
                          height: 160,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        bookingData['ticketNumber']?.toString() ??
                            bookingData['bookingId']?.toString() ??
                            '',
                        style: const pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.grey500,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),

                pw.Container(height: 1, color: PdfColors.grey800),

                // Footer
                pw.Container(
                  padding: const pw.EdgeInsets.fromLTRB(32, 16, 32, 24),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'MULTIVERSE CITY • CINEMA E-TICKET',
                        style: const pw.TextStyle(
                          fontSize: 7,
                          color: PdfColors.grey600,
                          letterSpacing: 1,
                        ),
                      ),
                      pw.Text(
                        'Powered by Multiverse',
                        style: const pw.TextStyle(
                          fontSize: 7,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    return pdf.save();
  }

  static pw.Widget _detailBox(String label, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const pw.BoxDecoration(
        color: PdfColors.grey900,
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(
              fontSize: 8,
              color: PdfColors.grey500,
              letterSpacing: 1,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _dataRow(String label, String value) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey400),
        ),
        pw.Text(
          value,
          style: const pw.TextStyle(fontSize: 11, color: PdfColors.white),
        ),
      ],
    );
  }

  static List<dynamic> _getSeats(Map<String, dynamic> data) {
    final seatNumbers = data['seatNumbers'];
    if (seatNumbers is List && seatNumbers.isNotEmpty) return seatNumbers;
    final seats = data['seats'];
    if (seats is List && seats.isNotEmpty) return seats;
    return [];
  }

  static String _buildQrData(Map<String, dynamic> bookingData) {
    final qrData = bookingData['qrData'];
    if (qrData != null) {
      if (qrData is String) return qrData;
      try {
        return jsonEncode(qrData);
      } catch (_) {}
    }
    return jsonEncode({
      'bookingId': bookingData['bookingId'] ?? '',
      'ticketId': bookingData['ticketNumber'] ?? '',
    });
  }

  static Future<String?> generateAndUploadTicket(
    Map<String, dynamic> bookingData,
  ) async {
    try {
      final pdfBytes = await generateTicketPdfBytes(bookingData);

      final output = await getTemporaryDirectory();
      final file = File('${output.path}/${bookingData['ticketNumber']}.pdf');
      await file.writeAsBytes(pdfBytes);

      final ref = FirebaseStorage.instance.ref().child(
        'tickets/${bookingData['ticketNumber']}.pdf',
      );
      await ref.putFile(file);
      final downloadUrl = await ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('movie_bookings')
          .doc(bookingData['bookingId'])
          .update({'ticketPdfUrl': downloadUrl});

      return downloadUrl;
    } catch (e) {
      Log.e('MoviePdfService', 'Error generating/uploading PDF: $e', ex: e);
      return null;
    }
  }
}
