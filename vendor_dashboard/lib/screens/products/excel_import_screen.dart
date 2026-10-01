import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../services/excel_import_service.dart';
import '../../services/product_image_search_service.dart';
import '../../services/vendor_service.dart';
import '../../utils/file_downloader.dart';

class ExcelImportScreen extends StatefulWidget {
  final String vendorId;
  const ExcelImportScreen({super.key, required this.vendorId});

  @override
  State<ExcelImportScreen> createState() => _ExcelImportScreenState();
}

class _ExcelImportScreenState extends State<ExcelImportScreen> {
  final _service = ExcelImportService();

  ImportProgress? _progress;
  List<ImportResultRow>? _results;
  bool _importing = false;
  bool _cancelled = false;
  bool _isGstRegistered = true;
  bool _autoFindImages = true;
  String? _imageServiceWarning;

  @override
  void initState() {
    super.initState();
    _loadVendorGstStatus();
  }

  Future<void> _loadVendorGstStatus() async {
    try {
      final vendor = await VendorService().getVendorData(widget.vendorId);
      if (!mounted) return;
      setState(() => _isGstRegistered = vendor?.isGstRegistered ?? true);
    } catch (_) {}
  }

  Future<void> _downloadSample({required bool csv}) async {
    try {
      final Uint8List bytes = csv
          ? Uint8List.fromList(ExcelImportService.generateSampleCsv().codeUnits)
          : ExcelImportService.generateSampleExcel();
      final name = csv ? 'sample_products.csv' : 'sample_products.xlsx';
      await saveAndOpenBytes(bytes, name);
      _msg('Sample downloaded', isError: false);
    } catch (e) {
      _msg('Download failed: $e', isError: true);
    }
  }

  Future<void> _pickAndImport() async {
    if (_importing) return;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xlsm', 'csv', 'tsv', 'txt'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null) {
        _msg('Could not read file bytes', isError: true);
        return;
      }
      await _runImport(bytes, file.name);
    } catch (e) {
      _msg('File pick failed: $e', isError: true);
    }
  }

  /// Photo lookup never blocks an import, so a dead image service used to fail
  /// completely silently: every product landed without a photo and the vendor
  /// was never told why. Check the endpoint up front and say so instead.
  Future<void> _checkImageService() async {
    if (!_autoFindImages) {
      if (mounted) setState(() => _imageServiceWarning = null);
      return;
    }

    final service = ProductImageSearchService();
    try {
      if (!ProductImageSearchService.isConfigured) {
        if (mounted) {
          setState(() {
            _imageServiceWarning =
                'This build has no image service endpoint, so photos cannot be '
                'looked up. Products will still import, without photos. Tell a '
                'developer: the endpoint should be compiled into the app.';
          });
        }
        return;
      }
      if (!await service.isReachable()) {
        if (mounted) {
          setState(() {
            _imageServiceWarning =
                'Image service at ${ProductImageSearchService.baseUrl} is not '
                'responding. Products will still import, without photos.';
          });
        }
        return;
      }
      if (mounted) setState(() => _imageServiceWarning = null);
    } finally {
      service.dispose();
    }
  }

  Future<void> _runImport(Uint8List bytes, String fileName) async {
    await _checkImageService();

    setState(() {
      _importing = true;
      _cancelled = false;
      _progress = ImportProgress.initial(0);
      _results = null;
    });

    try {
      final results = await _service.import(
        bytes: bytes,
        fileName: fileName,
        vendorId: widget.vendorId,
        forceGstZero: !_isGstRegistered,
        autoFindImages: _autoFindImages,
        isCancelled: () => _cancelled,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );

      if (!mounted) return;
      setState(() {
        _importing = false;
        _results = results;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _importing = false);
      _msg('Import failed: $e', isError: true);
    }
  }

  Future<void> _retryFailed() async {
    final previous = _results;
    if (previous == null || _importing) return;
    setState(() {
      _importing = true;
      _cancelled = false;
      _progress = ImportProgress.initial(0);
    });

    List<ImportResultRow> results;
    try {
      results = await _service.retryFailed(
        previous: previous,
        vendorId: widget.vendorId,
        forceGstZero: !_isGstRegistered,
        autoFindImages: _autoFindImages,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _importing = false);
      _msg('Retry failed: $e', isError: true);
      return;
    }

    // Merge retried rows back into the full result list.
    final merged = previous
        .map(
          (r) => results.firstWhere(
            (x) => x.rowNumber == r.rowNumber,
            orElse: () => r,
          ),
        )
        .toList();

    if (!mounted) return;
    setState(() {
      _importing = false;
      _results = merged;
    });
  }

  void _msg(String msg, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError
            ? const Color(0xFFF44336)
            : const Color(0xFF4CAF50),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0518),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A0A2E),
        foregroundColor: Colors.white,
        title: const Text(
          'Import Excel / CSV',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSampleSection(),
            const SizedBox(height: 16),
            _buildUploadButton(),
            SwitchListTile.adaptive(
              value: _autoFindImages,
                  onChanged: _importing
                      ? null
                      : (value) {
                          setState(() => _autoFindImages = value);
                          _checkImageService();
                        },
              activeColor: const Color(0xFFFF5F00),
              title: const Text(
                'Auto-find product images',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: const Text(
                'Uses Image URL from the sheet first, then searches for a best match. Image lookup never blocks import.',
                style: TextStyle(color: Color(0xFF9A9A9A), fontSize: 12),
              ),
            ),
            if (_imageServiceWarning != null) ...[
              const SizedBox(height: 12),
              _buildImageWarning(),
            ],
            if (_importing || (_progress != null && !(_progress!.finished)))
              _buildProgressSection(),
            if (_results != null) _buildResultsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildImageWarning() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x33FF9800),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFF9800)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.image_not_supported_outlined,
            color: Color(0xFFFF9800),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _imageServiceWarning!,
              style: const TextStyle(color: Color(0xFFFF9800), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSampleSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.download_for_offline, color: Color(0xFF00E5FF)),
              SizedBox(width: 8),
              Text(
                'Step 1: Download the template',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Any column order is accepted. Common headers such as Item Name, '
            'Product, Rate, Price, Qty, MRP, GST and SKU are detected '
            'automatically. Extra columns are ignored.\n'
            'Only a product name and a price are required. Category defaults '
            'to Grocery; stock and GST default to 0. Prices may include Rs./₹ '
            'and commas; GST may be written as 5% or 0.05.',
            style: TextStyle(
              color: Color(0xFF9A9A9A),
              fontSize: 12,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _downloadSample(csv: false),
                  icon: const Icon(Icons.grid_on, size: 18),
                  label: const Text('Sample XLSX'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF00E5FF),
                    side: const BorderSide(color: Color(0xFF00E5FF)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _downloadSample(csv: true),
                  icon: const Icon(Icons.description_outlined, size: 18),
                  label: const Text('Sample CSV'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF00E5FF),
                    side: const BorderSide(color: Color(0xFF00E5FF)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUploadButton() {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFFF5F00).withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: _importing ? null : _pickAndImport,
        borderRadius: BorderRadius.circular(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _importing ? Icons.hourglass_top : Icons.upload_file,
              color: const Color(0xFFFF5F00),
              size: 40,
            ),
            const SizedBox(height: 8),
            Text(
              _importing
                  ? 'Importing...'
                  : 'Tap to upload XLSX, CSV, TSV or TXT file',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Flexible headers and column order supported. Products are added instantly.',
              style: TextStyle(color: Color(0xFF9A9A9A), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressSection() {
    final p = _progress!;
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Import Progress',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (!p.finished)
                TextButton(
                  onPressed: () => setState(() => _cancelled = true),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (p.phase != null) ...[
            Text(
              p.phase!,
              style: const TextStyle(color: Color(0xFFFFB74D), fontSize: 12),
            ),
            const SizedBox(height: 8),
          ],
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: p.fraction,
              minHeight: 8,
              backgroundColor: const Color(0xFF14141F),
              color: const Color(0xFFFF5F00),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _stat('Total', '${p.total}'),
              _stat('Imported', '${p.imported}', const Color(0xFF4CAF50)),
              _stat('Skipped', '${p.skipped}', const Color(0xFFFF9800)),
              _stat('Failed', '${p.failed}', const Color(0xFFF44336)),
              if (p.estimatedRemaining != null)
                _stat('ETA', _fmtDuration(p.estimatedRemaining!)),
            ],
          ),
        ],
      ),
    );
  }

  String _fmtDuration(Duration d) {
    final s = d.inSeconds;
    if (s < 60) return '${s}s left';
    return '${d.inMinutes}m ${s % 60}s left';
  }

  Widget _stat(String label, String value, [Color? color]) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF9A9A9A), fontSize: 11),
        ),
        Text(
          value,
          style: TextStyle(
            color: color ?? Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  Widget _buildResultsSection() {
    final results = _results!;
    final failed = results.where((r) => !r.success).length;
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Import Results',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            '${results.length} total • ${results.length - failed} imported • $failed skipped/failed',
            style: const TextStyle(color: Color(0xFF9A9A9A), fontSize: 12),
          ),
          const SizedBox(height: 12),
          if (failed > 0)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _importing ? null : _retryFailed,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Retry Failed Rows'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFF9800),
                      side: const BorderSide(color: Color(0xFFFF9800)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final bytes = ExcelImportService.generateErrorReport(
                        results,
                      );
                      await saveAndOpenBytes(bytes, 'import_errors.csv');
                    },
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('Error Report'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFF44336),
                      side: const BorderSide(color: Color(0xFFF44336)),
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: results.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: Color(0xFF2A2A3E)),
              itemBuilder: (context, index) {
                final r = results[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        r.success ? Icons.check_circle : Icons.cancel,
                        color: r.success
                            ? const Color(0xFF4CAF50)
                            : const Color(0xFFF44336),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Row ${r.rowNumber}: ${r.row?.productName ?? '(invalid row)'}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            if (r.error != null)
                              Text(
                                r.error!,
                                style: const TextStyle(
                                  color: Color(0xFF9A9A9A),
                                  fontSize: 11.5,
                                ),
                              ),
                            if (r.success && r.linked)
                              const Text(
                                'Linked to existing Global product',
                                style: TextStyle(
                                  color: Color(0xFF00E5FF),
                                  fontSize: 11.5,
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
          ),
        ],
      ),
    );
  }
}
