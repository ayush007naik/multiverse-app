import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../core/logging_service.dart';

/// Completely offline PDF test - NO Firebase, shows result on screen
class OfflinePdfTestScreen extends StatefulWidget {
  const OfflinePdfTestScreen({super.key});

  @override
  State<OfflinePdfTestScreen> createState() => _OfflinePdfTestScreenState();
}

class _OfflinePdfTestScreenState extends State<OfflinePdfTestScreen> {
  String _status = 'Ready to test';
  bool _isTesting = false;
  String? _error;
  String? _pdfPath;

  Future<void> _runTest() async {
    setState(() {
      _isTesting = true;
      _status = 'Starting test...';
      _error = null;
      _pdfPath = null;
    });

    try {
      // Step 1
      setState(() => _status = 'Step 1/5: Creating PDF document...');
      await Future.delayed(const Duration(milliseconds: 100));
      final pdf = pw.Document();

      // Step 2
      setState(() => _status = 'Step 2/5: Adding page...');
      await Future.delayed(const Duration(milliseconds: 100));
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) => pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  'OFFLINE TEST',
                  style: pw.TextStyle(
                    fontSize: 32,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'This is a test PDF',
                  style: const pw.TextStyle(fontSize: 18),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  'No Firebase used!',
                  style: const pw.TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      );

      // Step 3
      setState(() => _status = 'Step 3/5: Converting to bytes...');
      await Future.delayed(const Duration(milliseconds: 100));
      final pdfBytes = await pdf.save();
      Log.i('OfflinePdfTestScreen', '✅ PDF bytes: ${pdfBytes.length}');

      // Step 4
      setState(() => _status = 'Step 4/5: Getting directory...');
      await Future.delayed(const Duration(milliseconds: 100));
      final dir = await getApplicationDocumentsDirectory();
      Log.i('OfflinePdfTestScreen', '✅ Directory: ${dir.path}');

      // Step 5
      setState(() => _status = 'Step 5/5: Writing file...');
      await Future.delayed(const Duration(milliseconds: 100));
      final pdfPath = '${dir.path}/offline_test.pdf';
      final pdfFile = File(pdfPath);
      await pdfFile.writeAsBytes(pdfBytes);

      // Success!
      setState(() {
        _isTesting = false;
        _status = '✅ SUCCESS! PDF created';
        _pdfPath = pdfPath;
      });

      Log.i('OfflinePdfTestScreen', '✅ SUCCESS: PDF saved at $pdfPath');
    } catch (e, stackTrace) {
      setState(() {
        _isTesting = false;
        _status = '❌ FAILED';
        _error = '$e\n\nStack trace:\n$stackTrace';
      });

      Log.e('OfflinePdfTestScreen', '❌ FAILED: $e', ex: e, st: stackTrace);
      Log.e(
        'OfflinePdfTestScreen',
        '❌ Stack trace: $stackTrace',
        ex: e,
        st: stackTrace,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text('Offline PDF Test'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.picture_as_pdf,
              size: 100,
              color: _pdfPath != null ? Colors.green : Colors.white38,
            ),
            const SizedBox(height: 24),
            Text(
              _status,
              style: TextStyle(
                color: _pdfPath != null ? Colors.green : Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red),
                ),
                child: SelectableText(
                  _error!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            if (_pdfPath != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green),
                ),
                child: Column(
                  children: [
                    const Text(
                      'PDF Path:',
                      style: TextStyle(color: Colors.green, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      _pdfPath!,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _isTesting ? null : _runTest,
              icon: _isTesting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(_isTesting ? 'Testing...' : 'Run Offline Test'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6A3D),
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                minimumSize: const Size(200, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
