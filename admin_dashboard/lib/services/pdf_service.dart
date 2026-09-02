import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:db_compat/db_compat.dart';

class PdfService {
  static Future<void> generatePartnerAgreement(Map<String, dynamic> partnerData) async {
    final pdf = pw.Document();
    final basic = (partnerData['basic_info'] ?? partnerData['basicInfo']) as Map? ?? {};
    final business = (partnerData['business_details'] ?? partnerData['businessDetails']) as Map? ?? {};
    final signatureUrl = partnerData['signature'] as String?;
    
    // Load Logo
    Uint8List? logoBytes;
    try {
      final ByteData data = await rootBundle.load('assets/images/logo.png');
      logoBytes = data.buffer.asUint8List();
    } catch (e) {
      print('Error loading logo: $e');
    }

    // Load Signature
    Uint8List? signatureImage;
    if (signatureUrl != null && signatureUrl.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(signatureUrl));
        if (response.statusCode == 200) {
          signatureImage = response.bodyBytes;
          print('Signature fetched successfully');
        } else {
          print('Failed to fetch signature. Status: ${response.statusCode}');
        }
      } catch (e) {
        print('Error fetching signature: $e');
      }
    }

    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final now = DateTime.now();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // HEADER WITH LOGO AND CITY NAME
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('MULTIVERSE CITY', 
                      style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: PdfColors.purple900)),
                    pw.Text('Official Service Partner Portal', 
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                  ],
                ),
                if (logoBytes != null)
                  pw.Image(pw.MemoryImage(logoBytes), width: 60, height: 60)
                else
                  pw.Container(width: 60, height: 60, color: PdfColors.grey100),
              ],
            ),
            pw.Divider(thickness: 2, color: PdfColors.purple900),
            pw.SizedBox(height: 20),
            
            pw.Center(
              child: pw.Text('SERVICE PARTNER AGREEMENT', 
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline)),
            ),
            pw.SizedBox(height: 20),
            
            pw.Text('This agreement is entered into on ${dateFormat.format(now)} between Multiverse City Platform and:',
              style: const pw.TextStyle(fontSize: 12)),
            pw.SizedBox(height: 10),

            _buildSectionTitle('PARTNER DETAILS'),
            _buildDetailRow('Full Name', basic['full_name'] ?? 'N/A'),
            _buildDetailRow('Business Name', business['name'] ?? 'N/A'),
            _buildDetailRow('Category', partnerData['category'] ?? 'N/A'),
            _buildDetailRow('Email', basic['email'] ?? 'N/A'),
            _buildDetailRow('Contact', basic['mobile'] ?? 'N/A'),
            _buildDetailRow('Partner ID', partnerData['id'] ?? 'N/A'),
            
            pw.SizedBox(height: 20),
            _buildSectionTitle('TERMS & CONDITIONS'),
            ..._getTerms().map((term) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 6),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('• ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Expanded(child: pw.Text(term, style: const pw.TextStyle(fontSize: 9))),
                ],
              ),
            )),

            pw.SizedBox(height: 30),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('OFFICIAL SEAL', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                    pw.SizedBox(height: 10),
                    _buildStamp(),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('DIGITAL SIGNATURE', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                    pw.SizedBox(height: 10),
                    if (signatureImage != null)
                      pw.Container(
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey200),
                        ),
                        child: pw.Image(pw.MemoryImage(signatureImage), width: 150, height: 70, fit: pw.BoxFit.contain),
                      )
                    else
                      pw.Container(
                        width: 150, 
                        height: 70, 
                        color: PdfColors.grey100,
                        child: pw.Center(child: pw.Text('No Signature Data', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey400))),
                      ),
                    pw.SizedBox(height: 5),
                    pw.Text(basic['full_name'] ?? '', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text('Signed on: ${partnerData['approved_at'] != null ? (partnerData['approved_at'] is Timestamp ? dateFormat.format((partnerData['approved_at'] as Timestamp).toDate()) : partnerData['approved_at'].toString()) : dateFormat.format(now)}', 
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Agreement_${partnerData['id'] ?? 'Partner'}.pdf',
    );
  }

  static pw.Widget _buildSectionTitle(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.purple700)),
          pw.Divider(color: PdfColors.purple100, thickness: 1),
        ],
      ),
    );
  }

  static pw.Widget _buildDetailRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        children: [
          pw.SizedBox(width: 100, child: pw.Text('$label:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
          pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  static pw.Widget _buildStamp() {
    final stampColor = PdfColor.fromHex('#1A237E'); // Deep Blue Ink
    return pw.Opacity(
      opacity: 0.8,
      child: pw.Container(
        width: 80,
        height: 80,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: stampColor, width: 1.5),
          shape: pw.BoxShape.circle,
        ),
        padding: const pw.EdgeInsets.all(2),
        child: pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: stampColor, width: 0.5),
            shape: pw.BoxShape.circle,
          ),
          child: pw.Center(
            child: pw.Transform.rotate(
              angle: -0.2,
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text('MULTIVERSE',
                      style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: stampColor)),
                  pw.Container(
                    margin: const pw.EdgeInsets.symmetric(vertical: 1),
                    height: 0.5,
                    width: 30,
                    color: stampColor,
                  ),
                  pw.Text('CITY',
                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: stampColor)),
                  pw.Container(
                    margin: const pw.EdgeInsets.symmetric(vertical: 1),
                    height: 0.5,
                    width: 30,
                    color: stampColor,
                  ),
                  pw.Text('VERIFIED',
                      style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold, color: stampColor)),
                  pw.Text('OFFICIAL',
                      style: pw.TextStyle(fontSize: 5, color: stampColor)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static List<String> _getTerms() {
    return [
      "I confirm that all information provided during registration is true, accurate, and up to date.",
      "I possess all required licenses, registrations, certifications, and permissions to provide my services.",
      "I am solely responsible for the quality, safety, and legality of the services I provide.",
      "I agree to keep my profile, pricing, availability, and contact details updated.",
      "I understand that customer reviews and ratings may be displayed publicly.",
      "I agree not to post false, misleading, or fraudulent information.",
      "I understand that the platform may suspend or terminate my account if I violate these terms or provide false information.",
      "I authorize the platform to verify my identity and submitted documents when necessary.",
      "I agree to comply with all applicable laws, regulations, and professional standards.",
      "I understand that the platform acts only as a marketplace connecting customers and service providers and is not responsible for disputes, damages, or losses arising from services provided.",
      "I agree to the platform’s Privacy Policy and Terms of Service.",
      "I consent to receive notifications via SMS, email, WhatsApp, or phone regarding my account, bookings, and platform updates."
    ];
  }
}

