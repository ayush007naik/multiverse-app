import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class TicketPdfGenerator {
  static Future<Uint8List> generateTicket({
    required Map<String, dynamic> booking,
    String? moviePosterUrl,
  }) async {
    final pdf = pw.Document();
    pw.ImageProvider? netImage;
    if (moviePosterUrl != null && moviePosterUrl.isNotEmpty) {
      try {
        netImage = await networkImage(moviePosterUrl);
      } catch (_) {
        netImage = null;
      }
    }
    final seats = (booking['seats'] as List?)?.join(', ') ?? '-';
    final seatCount = (booking['seats'] as List?)?.length ?? 0;
    final showDate = booking['showTime']?.split(' • ')[0] ?? '-';
    final showTime = booking['showTime']?.split(' • ')[1] ?? '-';

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
                      bottom: pw.BorderSide(color: PdfColors.orange800, width: 2),
                    ),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('MULTIVERSE CITY',
                            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.orange800, letterSpacing: 2)),
                          pw.SizedBox(height: 2),
                          pw.Text('CINEMA TICKET',
                            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey400, letterSpacing: 3)),
                        ],
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: const pw.BoxDecoration(
                          color: PdfColors.grey900,
                          borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.Text('ID: ${booking['bookingId']}',
                          style: const pw.TextStyle(fontSize: 8, color: PdfColors.orange800, letterSpacing: 1)),
                      ),
                    ],
                  ),
                ),

                // Movie Section with Poster
                pw.Container(
                  padding: const pw.EdgeInsets.all(32),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (netImage != null)
                        pw.Container(
                          width: 110,
                          height: 160,
                          child: pw.Image(netImage, fit: pw.BoxFit.cover),
                        ),
                      if (netImage != null) pw.SizedBox(width: 24),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              (booking['movieTitle'] ?? 'MOVIE').toString().toUpperCase(),
                              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.white, letterSpacing: 1),
                            ),
                            pw.SizedBox(height: 12),
                            _infoRow('THEATRE', booking['theatreName'] ?? 'Multiverse Cinema'),
                            pw.SizedBox(height: 6),
                            _infoRow('SCREEN', booking['screen']?.toString() ?? 'Screen 1'),
                            pw.SizedBox(height: 16),
                            pw.Row(
                              children: [
                                pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Text('DATE', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500, letterSpacing: 1)),
                                    pw.SizedBox(height: 2),
                                    pw.Text(showDate, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                                  ],
                                ),
                                pw.SizedBox(width: 48),
                                pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Text('TIME', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500, letterSpacing: 1)),
                                    pw.SizedBox(height: 2),
                                    pw.Text(showTime, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Divider
                pw.Container(height: 1, color: PdfColors.grey800),

                // Seats & Count
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('SEATS', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500, letterSpacing: 1)),
                          pw.SizedBox(height: 4),
                          pw.Text(seats, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.orange800)),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('TICKETS', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500, letterSpacing: 1)),
                          pw.SizedBox(height: 4),
                          pw.Text('$seatCount', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                        ],
                      ),
                    ],
                  ),
                ),

                pw.Container(height: 1, color: PdfColors.grey800),

                // Customer & Payment
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('CUSTOMER', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500, letterSpacing: 1)),
                          pw.SizedBox(height: 4),
                          pw.Text(booking['customerName'] ?? 'Walk-in', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                          if (booking['customerPhone'] != null && booking['customerPhone'].toString().isNotEmpty)
                            pw.Text(booking['customerPhone'], style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey400)),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('AMOUNT PAID', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500, letterSpacing: 1)),
                          pw.SizedBox(height: 4),
                          pw.Text('Rs.${booking['totalAmount']}', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                          pw.Text(booking['paymentMethod']?.toString().toUpperCase() ?? 'CASH',
                            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey400)),
                        ],
                      ),
                    ],
                  ),
                ),

                pw.Container(height: 1, color: PdfColors.grey800),

                // Spacer pushes QR section toward bottom
                pw.Expanded(child: pw.SizedBox()),

                // Large QR Code
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                  child: pw.Column(
                    children: [
                      pw.Text('SCAN AT ENTRANCE',
                        style: const pw.TextStyle(fontSize: 11, color: PdfColors.orange800, letterSpacing: 3)),
                      pw.SizedBox(height: 16),
                      pw.Container(
                        width: 160,
                        height: 160,
                        decoration: const pw.BoxDecoration(
                          color: PdfColors.white,
                          borderRadius: pw.BorderRadius.all(pw.Radius.circular(12)),
                        ),
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.BarcodeWidget(
                          barcode: pw.Barcode.qrCode(),
                          data: booking['bookingId']?.toString() ?? 'MULTIVERSE',
                          width: 144,
                          height: 144,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(booking['ticketNumber'] ?? booking['bookingId'] ?? '',
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500, letterSpacing: 1)),
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
                      pw.Text('MULTIVERSE CITY • CINEMA TICKET',
                        style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600, letterSpacing: 1)),
                      pw.Text('Powered by Multiverse',
                        style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
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

  static pw.Widget _infoRow(String label, String value) {
    return pw.Row(
      children: [
        pw.Text('$label  ', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500, letterSpacing: 1)),
        pw.Text(value, style: const pw.TextStyle(fontSize: 12, color: PdfColors.white)),
      ],
    );
  }

  static Future<void> printTicket(Map<String, dynamic> booking, {String? moviePosterUrl, bool isThermal = false}) async {
    final pdfBytes = isThermal
      ? await generateThermalTicket(booking: booking)
      : await generateTicket(booking: booking, moviePosterUrl: moviePosterUrl);
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdfBytes);
  }

  static Future<Uint8List> generateThermalTicket({
    required Map<String, dynamic> booking,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginAll: 5 * PdfPageFormat.mm),
        build: (pw.Context context) {
          return pw.Container(
            decoration: const pw.BoxDecoration(color: PdfColors.black),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.SizedBox(height: 8),
                pw.Text('MULTIVERSE CITY',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.orange800, letterSpacing: 2)),
                pw.Text('CINEMA TICKET',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey400, letterSpacing: 2)),
                pw.SizedBox(height: 6),
                pw.Container(height: 0.5, color: PdfColors.grey700),
                pw.SizedBox(height: 6),
                pw.Text((booking['movieTitle'] ?? 'MOVIE').toString().toUpperCase(),
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                  textAlign: pw.TextAlign.center),
                pw.SizedBox(height: 6),
                _thermalRow('Show', '${booking['showTime'] ?? '-'}'),
                _thermalRow('Screen', '${booking['screen'] ?? '1'}'),
                pw.SizedBox(height: 8),
                pw.Container(height: 0.5, color: PdfColors.grey700),
                pw.SizedBox(height: 6),
                pw.Text('SEATS', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500, letterSpacing: 1)),
                pw.Text((booking['seats'] as List).join(', '),
                  style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.orange800)),
                pw.SizedBox(height: 8),
                pw.Container(height: 0.5, color: PdfColors.grey700),
                pw.SizedBox(height: 6),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Total Paid:', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey400)),
                    pw.Text('Rs.${booking['totalAmount']}',
                      style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                  ],
                ),
                if (booking['customerName'] != null && booking['customerName'].toString().isNotEmpty)
                  _thermalRow('Customer', '${booking['customerName']}'),
                pw.SizedBox(height: 10),
                pw.Container(
                  width: 120,
                  height: 120,
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: booking['bookingId']?.toString() ?? 'MULTIVERSE',
                    width: 108,
                    height: 108,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(booking['ticketNumber'] ?? '',
                  style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
                pw.SizedBox(height: 8),
                pw.Text('Enjoy your movie!',
                  style: pw.TextStyle(fontSize: 8, color: PdfColors.grey400, fontStyle: pw.FontStyle.italic)),
                pw.SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _thermalRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('$label: ', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey400)),
          pw.Text(value, style: const pw.TextStyle(fontSize: 8, color: PdfColors.white)),
        ],
      ),
    );
  }
}
