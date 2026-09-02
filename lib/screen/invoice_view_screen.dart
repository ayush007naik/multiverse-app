import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:db_compat/db_compat.dart';
import '../core/app_constants.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:open_filex/open_filex.dart';
import '../widgets/premium_ui_widgets.dart';
import '../services/html_invoice_service.dart';
import '../utils/price_calculator.dart';
import '../core/logging_service.dart';

class InvoiceViewScreen extends StatefulWidget {
  final String orderId;

  const InvoiceViewScreen({super.key, required this.orderId});

  @override
  State<InvoiceViewScreen> createState() => _InvoiceViewScreenState();
}

class _InvoiceViewScreenState extends State<InvoiceViewScreen> {
  bool _isLoading = true;
  bool _isGenerating = false;
  Map<String, dynamic>? _invoiceData;
  Map<String, dynamic>? _orderData;
  Map<String, dynamic>? _shopData;
  Map<String, dynamic>? _userData;
  String? _error;

  // Real-time streams
  StreamSubscription? _invoiceSubscription;
  StreamSubscription? _orderSubscription;

  @override
  void initState() {
    super.initState();
    _loadInvoice();
    _setupRealtimeListeners();
  }

  @override
  void dispose() {
    _invoiceSubscription?.cancel();
    _orderSubscription?.cancel();
    super.dispose();
  }

  /// Setup real-time listeners for invoice and order
  void _setupRealtimeListeners() {
    // Listen to invoice changes
    _invoiceSubscription = FirebaseFirestore.instance
        .collection('invoices')
        .doc('INV_${widget.orderId}')
        .snapshots()
        .listen(
          (doc) {
            if (doc.exists && mounted) {
              setState(() {
                _invoiceData = doc.data();
                _isLoading = false;
              });
              Log.i('InvoiceViewScreen', '🔄 [E-Bill] Real-time update: ${_invoiceData?['invoiceNumber']}');

              // Also listen to order changes
              final orderId =
                  _invoiceData?['orderId'] as String? ?? widget.orderId;
              _listenToOrder(orderId);
            }
          },
          onError: (e) {
            Log.e('InvoiceViewScreen', '[E-Bill] Stream error: $e');
          },
        );
  }

  /// Listen to order changes in real-time
  void _listenToOrder(String orderId) {
    _orderSubscription?.cancel(); // Cancel previous subscription

    _orderSubscription = FirebaseFirestore.instance
        .collection('orders')
        .doc(orderId)
        .snapshots()
        .listen(
          (doc) {
            if (doc.exists && mounted) {
              setState(() {
                _orderData = doc.data();
              });
              Log.i('InvoiceViewScreen', '🔄 [Order] Real-time update received');

              // Load related data
              _loadUserData();
              _loadShopData();
            }
          },
          onError: (e) {
            Log.e('InvoiceViewScreen', '[Order] Stream error: $e');
          },
        );
  }

  Future<void> _loadInvoice() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      Log.i('InvoiceViewScreen', '🔍 [E-Bill] Looking for e-bill document: INV_${widget.orderId}');

      // Fetch invoice document
      final doc = await FirebaseFirestore.instance
          .collection('invoices')
          .doc('INV_${widget.orderId}')
          .get();

      if (!doc.exists) {
        Log.w('InvoiceViewScreen', '[E-Bill] E-Bill not found in Firestore - will generate on-demand');
        // Don't show error, just set invoiceData to null
        // Invoice will be generated when user taps download/share/print
        _invoiceData = null;

        // Still fetch order data
        await _loadOrderData();

        setState(() {
          _isLoading = false;
        });
        return;
      }

      _invoiceData = doc.data()!;
      Log.i('InvoiceViewScreen', '✅ [E-Bill] E-Bill found: ${_invoiceData!['invoiceNumber']}');

      // Fetch order data for customer details
      await _loadOrderData();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      Log.e('InvoiceViewScreen', '[E-Bill] Error loading e-bill: $e');
      setState(() {
        _error = 'Error loading e-bill: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadOrderData() async {
    try {
      // Get order ID from invoice data or use widget.orderId
      final orderId = _invoiceData?['orderId'] as String? ?? widget.orderId;

      Log.i('InvoiceViewScreen', '🔍 [E-Bill] Fetching order data: $orderId');

      // Fetch order data (one-time for initial load)
      final orderDoc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .get();

      if (orderDoc.exists) {
        _orderData = orderDoc.data();
        Log.i('InvoiceViewScreen', '✅ [E-Bill] Order data fetched');

        // Load related data
        await _loadUserData();
        await _loadShopData();
      } else {
        Log.w('InvoiceViewScreen', '[E-Bill] Order not found: $orderId');
      }
    } catch (e) {
      Log.e('InvoiceViewScreen', '[E-Bill] Error loading order data: $e');
    }
  }

  /// Load user data in real-time
  Future<void> _loadUserData() async {
    try {
      final userId = _orderData?['userId'] as String?;
      if (userId != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
        if (userDoc.exists && mounted) {
          setState(() {
            _userData = userDoc.data();
          });
          Log.i('InvoiceViewScreen', '✅ [E-Bill] User data fetched: ${_userData?['name']}');
        }
      }
    } catch (e) {
      Log.e('InvoiceViewScreen', '[E-Bill] Error loading user data: $e');
    }
  }

  /// Load shop data in real-time
  Future<void> _loadShopData() async {
    try {
      final shopId =
          _invoiceData?['shopId'] as String? ??
          _orderData?['shopId'] as String?;
      if (shopId != null) {
        final shopDoc = await FirebaseFirestore.instance
            .collection('shops')
            .doc(shopId)
            .get();
        if (shopDoc.exists && mounted) {
          setState(() {
            _shopData = shopDoc.data();
          });
          Log.i('InvoiceViewScreen', '✅ [E-Bill] Shop data fetched: ${_shopData?['name']}');

          // If shop doesn't have phone/gstNumber, fetch from vendor document
          if (_shopData?['phone'] == null || _shopData?['gstNumber'] == null) {
            await _loadVendorData(shopId);
          }
        }
      }
    } catch (e) {
      Log.e('InvoiceViewScreen', '[E-Bill] Error loading shop data: $e');
    }
  }

  /// Load vendor data as fallback for missing shop fields
  Future<void> _loadVendorData(String vendorId) async {
    try {
      final vendorDoc = await FirebaseFirestore.instance
          .collection('vendors')
          .doc(vendorId)
          .get();

      if (vendorDoc.exists && mounted) {
        final vendorData = vendorDoc.data();
        setState(() {
          // Merge vendor data into shopData for missing fields
          _shopData = {
            ...?_shopData,
            'phone': _shopData?['phone'] ?? vendorData?['phone'],
            'gstNumber': _shopData?['gstNumber'] ?? vendorData?['gstNumber'],
            'name': _shopData?['name'] ?? vendorData?['shopName'],
          };
        });
        Log.i('InvoiceViewScreen', '✅ [E-Bill] Vendor data merged for missing fields');
      }
    } catch (e) {
      Log.e('InvoiceViewScreen', '[E-Bill] Error loading vendor data: $e');
    }
  }

  Future<void> _shareInvoice() async {
    if (_invoiceData == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ E-Bill data not loaded'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      String? pdfUrl = _invoiceData!['pdfUrl'] as String?;

      if (pdfUrl == null || pdfUrl.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ PDF not available'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      Log.i('InvoiceViewScreen', '📤 [E-Bill] Sharing e-bill from: $pdfUrl');

      String filePath;

      // Check if local file or remote URL
      if (pdfUrl.startsWith('/')) {
        // LOCAL FILE - Use directly
        filePath = pdfUrl;
        Log.i('InvoiceViewScreen', '📝 [E-Bill] Local file, using directly');
      } else {
        // REMOTE URL - Download first
        Log.i('InvoiceViewScreen', '📝 [E-Bill] Remote URL, downloading...');
        final response = await http.get(Uri.parse(pdfUrl));

        if (response.statusCode != 200) {
          throw Exception(
            'Failed to download PDF (Status: ${response.statusCode})',
          );
        }

        final dir = await getApplicationDocumentsDirectory();
        final invoiceNum = _invoiceData!['invoiceNumber'] ?? 'E-Bill';
        final file = File('${dir.path}/$invoiceNum.pdf');
        await file.writeAsBytes(response.bodyBytes);
        filePath = file.path;
        Log.i('InvoiceViewScreen', '✅ [E-Bill] Downloaded to: $filePath');
      }

      // Share the file
      await Share.shareXFiles([
        XFile(filePath),
      ], text: 'E-Bill ${_invoiceData!['invoiceNumber']} - Multiverse');
    } catch (e) {
      Log.e('InvoiceViewScreen', '[E-Bill] Share error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to share: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _printInvoice() async {
    if (_invoiceData == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ E-Bill data not loaded'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      String? pdfUrl = _invoiceData!['pdfUrl'] as String?;

      if (pdfUrl == null || pdfUrl.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ PDF not available'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      Log.i('InvoiceViewScreen', '🖨️ [E-Bill] Printing e-bill from: $pdfUrl');

      Uint8List pdfBytes;

      // Check if local file or remote URL
      if (pdfUrl.startsWith('/')) {
        // LOCAL FILE - Read directly
        Log.i('InvoiceViewScreen', '📝 [E-Bill] Local file, reading...');
        final file = File(pdfUrl);
        if (!await file.exists()) {
          throw Exception('File not found: $pdfUrl');
        }
        pdfBytes = await file.readAsBytes();
        Log.i('InvoiceViewScreen', '✅ [E-Bill] Read ${pdfBytes.length} bytes');
      } else {
        // REMOTE URL - Download
        Log.i('InvoiceViewScreen', '📝 [E-Bill] Remote URL, downloading...');
        final response = await http.get(Uri.parse(pdfUrl));

        if (response.statusCode != 200) {
          throw Exception(
            'Failed to download PDF (Status: ${response.statusCode})',
          );
        }
        pdfBytes = response.bodyBytes;
        Log.i('InvoiceViewScreen', '✅ [E-Bill] Downloaded ${pdfBytes.length} bytes');
      }

      Log.i('InvoiceViewScreen', '✅ [E-Bill] Opening print dialog');

      // Open print dialog
      await Printing.layoutPdf(onLayout: (format) async => pdfBytes);

      Log.i('InvoiceViewScreen', '✅ [E-Bill] Print dialog closed');
    } catch (e) {
      Log.e('InvoiceViewScreen', '[E-Bill] Print error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to print: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _downloadAndOpenInvoice() async {
    if (_invoiceData == null) return;

    try {
      String? pdfUrl = _invoiceData!['pdfUrl'] as String?;

      if (pdfUrl == null || pdfUrl.isEmpty) {
        Log.e('InvoiceViewScreen', '[E-Bill] No PDF URL found');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ PDF not available'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      Log.i('InvoiceViewScreen', '📥 [E-Bill] Opening PDF from: $pdfUrl');

      // Check if it's a local file or remote URL
      if (pdfUrl.startsWith('/')) {
        // LOCAL FILE - Open directly
        Log.i('InvoiceViewScreen', '📝 [E-Bill] Local file detected, opening directly...');

        final file = File(pdfUrl);
        if (!await file.exists()) {
          throw Exception('File not found: $pdfUrl');
        }

        Log.i('InvoiceViewScreen', '✅ [E-Bill] File exists, opening...');
        final result = await OpenFilex.open(pdfUrl);

        if (mounted) {
          if (result.type == ResultType.done) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ E-Bill opened successfully'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('❌ Failed to open: ${result.message}'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      } else {
        // REMOTE URL - Download first
        Log.i('InvoiceViewScreen', '📝 [E-Bill] Remote URL detected, downloading...');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⏳ Downloading E-Bill...'),
              duration: Duration(seconds: 2),
            ),
          );
        }

        final response = await http.get(Uri.parse(pdfUrl));

        if (response.statusCode != 200) {
          throw Exception(
            'Failed to download PDF (Status: ${response.statusCode})',
          );
        }

        final dir = await getApplicationDocumentsDirectory();
        final invoiceNum = _invoiceData!['invoiceNumber'] ?? 'E-Bill';
        final file = File('${dir.path}/$invoiceNum.pdf');
        await file.writeAsBytes(response.bodyBytes);

        Log.i('InvoiceViewScreen', '✅ [E-Bill] PDF saved to: ${file.path}');

        final result = await OpenFilex.open(file.path);

        if (mounted) {
          if (result.type == ResultType.done) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ E-Bill opened successfully'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('❌ Failed to open: ${result.message}'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      }
    } catch (e) {
      Log.e('InvoiceViewScreen', '[E-Bill] Download error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text(
          'E-Bill',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_invoiceData != null) ...[
            IconButton(
              icon: const Icon(Icons.share_rounded, color: Colors.white),
              onPressed: _shareInvoice,
              tooltip: 'Share E-Bill',
            ),
            IconButton(
              icon: const Icon(Icons.print_rounded, color: Colors.white),
              onPressed: _printInvoice,
              tooltip: 'Print E-Bill',
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF6A3D)),
            )
          : _error != null
          ? _buildErrorState()
          : _invoiceData == null
          ? _buildGenerateInvoicePrompt()
          : _buildInvoiceContent(),
    );
  }

  Widget _buildGenerateInvoicePrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 100,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 24),
            const Text(
              'E-Bill Not Generated Yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Generate your premium e-bill now to download, share, or print it.',
              style: TextStyle(color: Colors.white54, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _isGenerating ? null : _generateInvoiceNow,
              icon: _isGenerating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.download_rounded),
              label: Text(_isGenerating ? 'Generating...' : 'Generate E-Bill'),
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

  Future<void> _generateInvoiceNow() async {
    Log.i('InvoiceViewScreen', '🚀 [E-Bill] ===== GENERATE E-BILL STARTED =====');

    if (_orderData == null) {
      Log.e('InvoiceViewScreen', '[E-Bill] Order data is NULL');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Order data not available'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    Log.i('InvoiceViewScreen', '✅ [E-Bill] Order data available: ${_orderData!.keys.length} fields');

    // Prevent double-tap
    if (_isGenerating) {
      Log.w('InvoiceViewScreen', '[E-Bill] Already generating, preventing double-tap');
      return;
    }

    Log.i('InvoiceViewScreen', '📝 [E-Bill] Setting _isGenerating = true');
    setState(() {
      _isGenerating = true;
    });

    try {
      Log.i('InvoiceViewScreen', '🚀 [E-Bill] About to call HtmlInvoiceService...');

      // USE FULL HTML INVOICE SERVICE - Premium PDF
      final htmlInvoiceService = HtmlInvoiceService();
      Log.i('InvoiceViewScreen', '✅ [E-Bill] HtmlInvoiceService instance created');

      Log.i('InvoiceViewScreen', '📝 [E-Bill] Calling generateInvoicePdf()...');
      Log.i('InvoiceViewScreen', '🔍 [E-Bill] ShopData: $_shopData');
      Log.i('InvoiceViewScreen', '🔍 [E-Bill] OrderData keys: ${_orderData?.keys.toList()}');

      final pdfUrl = await htmlInvoiceService.generateInvoicePdf(
        orderId: widget.orderId,
        orderData: _orderData!,
        userData: _userData,
        shopData: _shopData,
      );

      Log.i('InvoiceViewScreen', '✅ [E-Bill] PDF generated: $pdfUrl');

      // Create invoice data with remote URL
      Log.i('InvoiceViewScreen', '📝 [E-Bill] Updating UI state...');
      setState(() {
        _invoiceData = {
          'orderId': widget.orderId,
          'invoiceNumber':
              'INV-${widget.orderId.substring(0, 8).toUpperCase()}',
          'pdfUrl': pdfUrl, // Firebase Storage URL
          'status': 'completed',
          'createdAt': Timestamp.now(),
        };
        _isGenerating = false;
      });

      Log.i('InvoiceViewScreen', '✅ [E-Bill] UI state updated');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ PDF generated locally! Check console for path.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }

      Log.i('InvoiceViewScreen', '✅ [E-Bill] ===== GENERATE E-BILL COMPLETED =====');
    } catch (e, stackTrace) {
      Log.e('InvoiceViewScreen', '[E-Bill] ===== GENERATION FAILED =====');
      Log.e('InvoiceViewScreen', '[E-Bill] Error type: ${e.runtimeType}');
      Log.e('InvoiceViewScreen', '[E-Bill] Error: $e');
      Log.e('InvoiceViewScreen', '[E-Bill] Stack trace:');
      Log.e('InvoiceViewScreen', '$stackTrace');
      Log.e('InvoiceViewScreen', '[E-Bill] ====================================');

      setState(() {
        _isGenerating = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 80,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 24),
          Text(
            _error ?? 'Error loading e-bill',
            style: const TextStyle(color: Colors.white54, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadInvoice,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6A3D),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceContent() {
    Log.i('InvoiceViewScreen', '🔍 [E-Bill] E-Bill data keys: ${_invoiceData?.keys.toList()}');
    Log.i('InvoiceViewScreen', '🔍 [E-Bill] Order data keys: ${_orderData?.keys.toList()}');

    // Extract data with fallbacks - Invoice data first, then Order data
    final invoiceNumber =
        _invoiceData!['invoiceNumber']?.toString() ??
        'INV-${widget.orderId.substring(0, 8).toUpperCase()}';
    final orderId = _invoiceData!['orderId']?.toString() ?? widget.orderId;
    final createdAt = _invoiceData!['createdAt'] ?? _orderData?['createdAt'];
    final paymentMethod =
        _invoiceData!['paymentMethod']?.toString() ??
        _orderData?['paymentMethod']?.toString() ??
        'Online';

    // Customer details - Priority: User Profile > Order Data > Invoice Data
    String customerName = 'Customer';
    String customerPhone = 'N/A';
    String customerEmail = 'N/A';
    String fullAddress = 'N/A';

    // Get name from user profile first
    if (_userData != null) {
      customerName =
          _userData!['name']?.toString() ??
          _userData!['displayName']?.toString() ??
          'Customer';
      Log.i('InvoiceViewScreen', '✅ [E-Bill] Customer name from profile: $customerName');
    }

    // Get details from order data
    if (_orderData != null) {
      customerPhone =
          _orderData!['customerPhone']?.toString() ??
          _orderData!['phone']?.toString() ??
          _orderData!['address']?['phone']?.toString() ??
          'N/A';

      customerEmail =
          _orderData!['customerEmail']?.toString() ??
          _orderData!['email']?.toString() ??
          'N/A';

      // Build full address from order
      final address = _orderData!['address'];
      if (address != null) {
        Log.i('InvoiceViewScreen', '🔍 [E-Bill] Address data: $address');
        final addressLines = <String>[];

        // Try fullAddress first
        if (address['fullAddress'] != null &&
            address['fullAddress'].toString().isNotEmpty) {
          fullAddress = address['fullAddress'].toString();
        } else {
          // Build from parts - Check multiple field names

          // House/Flat number
          final houseNo =
              address['houseNo'] ??
              address['house_no'] ??
              address['flatNo'] ??
              address['flat_no'] ??
              '';
          if (houseNo.toString().isNotEmpty && houseNo.toString() != 'null') {
            addressLines.add(houseNo.toString());
          }

          // Building/Apartment
          final building =
              address['building'] ??
              address['buildingName'] ??
              address['apartment'] ??
              '';
          if (building.toString().isNotEmpty && building.toString() != 'null') {
            addressLines.add(building.toString());
          }

          // Street/Road/Area
          final street =
              address['street'] ??
              address['road'] ??
              address['area'] ??
              address['locality'] ??
              '';
          if (street.toString().isNotEmpty &&
              street.toString() != 'null' &&
              street.toString() != 'Location unavailable') {
            addressLines.add(street.toString());
          }

          // Landmark
          if (address['landmark'] != null &&
              address['landmark'].toString().isNotEmpty &&
              address['landmark'].toString() != 'null') {
            addressLines.add('Near ${address['landmark']}');
          }

          // City
          if (address['city'] != null &&
              address['city'].toString().isNotEmpty &&
              address['city'].toString() != 'null') {
            addressLines.add(address['city'].toString());
          }

          // State
          if (address['state'] != null &&
              address['state'].toString().isNotEmpty &&
              address['state'].toString() != 'null') {
            addressLines.add(address['state'].toString());
          }

          // Pincode - Check multiple field names and filter invalid values
          final pincode =
              address['pincode'] ?? address['pin_code'] ?? address['pin'] ?? '';
          final pincodeStr = pincode.toString().trim();
          if (pincodeStr.isNotEmpty &&
              pincodeStr != 'null' &&
              pincodeStr != '000000' &&
              pincodeStr != 'null' &&
              pincodeStr.length >= 5) {
            addressLines.add(pincodeStr);
          }

          fullAddress = addressLines.isNotEmpty
              ? addressLines.join(', ')
              : 'Address not available';
        }
        Log.i('InvoiceViewScreen', '✅ [E-Bill] Full address: $fullAddress');
      }
    }

    // Shop details - Priority: Shop Data > Invoice Data > Order Data
    final shopName =
        _shopData?['name']?.toString() ??
        _invoiceData!['shopName']?.toString() ??
        _orderData?['shopName']?.toString() ??
        _orderData?['vendorName']?.toString() ??
        'Multiverse Shop';

    // GSTIN - Show actual if available, otherwise show 000000
    final shopGstinRaw =
        _shopData?['gstin']?.toString() ??
        _invoiceData!['shopGstin']?.toString() ??
        _orderData?['shopGstin']?.toString() ??
        _orderData?['storeGSTIN']?.toString() ??
        '';
    final shopGstin = shopGstinRaw.isNotEmpty && shopGstinRaw != 'null'
        ? shopGstinRaw
        : '000000';

    // Address - Use shop address if available, otherwise show 000000
    final shopAddressRaw =
        _shopData?['address']?.toString() ??
        _invoiceData!['shopAddress']?.toString() ??
        _orderData?['shopAddress']?.toString() ??
        _orderData?['storeAddress']?.toString() ??
        '';
    final shopAddress = shopAddressRaw.isNotEmpty && shopAddressRaw != 'null'
        ? shopAddressRaw
        : '000000';

    // Contact - Use shop contact if available, otherwise show 000000
    final shopContactRaw =
        _shopData?['contact']?.toString() ??
        _invoiceData!['shopContact']?.toString() ??
        _orderData?['shopContact']?.toString() ??
        _orderData?['shopPhone']?.toString() ??
        '';
    final shopContact = shopContactRaw.isNotEmpty && shopContactRaw != 'null'
        ? shopContactRaw
        : '000000';

    // Items list - Priority: Invoice Data > Order Data
    List<dynamic> items = [];
    if (_invoiceData!['items'] != null && _invoiceData!['items'] is List) {
      items = _invoiceData!['items'] as List;
      Log.i('InvoiceViewScreen', '✅ [E-Bill] Items from e-bill data: ${items.length} items');
    } else if (_orderData?['items'] != null && _orderData!['items'] is List) {
      items = _orderData!['items'] as List;
      Log.i('InvoiceViewScreen', '✅ [E-Bill] Items from order data: ${items.length} items');
    }
    Log.i('InvoiceViewScreen', '🔍 [E-Bill] First item structure: ${items.isNotEmpty ? items[0] : 'No items'}');

    // Calculate totals - Priority: Invoice Data > Order Data
    final subtotal =
        (_invoiceData!['subtotal'] as num?)?.toDouble() ??
        (_orderData?['subtotal'] as num?)?.toDouble() ??
        0.0;

    // Get total GST from order and split into CGST and SGST (half-half)
    final totalGst =
        (_invoiceData!['totalGst'] as num?)?.toDouble() ??
        (_invoiceData!['gst'] as num?)?.toDouble() ??
        (_orderData?['gst'] as num?)?.toDouble() ??
        (_orderData?['tax'] as num?)?.toDouble() ??
        0.0;

    // Split GST into CGST and SGST equally
    final cgst = totalGst / 2;
    final sgst = totalGst / 2;

    final deliveryCharges =
        (_invoiceData!['deliveryCharges'] as num?)?.toDouble() ??
        (_orderData?['deliveryCharges'] as num?)?.toDouble() ??
        (_orderData?['deliveryFee'] as num?)?.toDouble() ??
        0.0;
    final platformFee =
        (_invoiceData!['platformFee'] as num?)?.toDouble() ??
        PriceCalculator.FIXED_PLATFORM_FEE;
    final discount =
        (_invoiceData!['discount'] as num?)?.toDouble() ??
        (_orderData?['discount'] as num?)?.toDouble() ??
        0.0;
    final grandTotal =
        (_invoiceData!['grandTotal'] as num?)?.toDouble() ??
        (_invoiceData!['total'] as num?)?.toDouble() ??
        (_orderData?['total'] as num?)?.toDouble() ??
        0.0;

    Log.i('InvoiceViewScreen', '💰 [E-Bill] Totals - Subtotal: ₹$subtotal, Total GST: ₹$totalGst, CGST: ₹${cgst.toStringAsFixed(2)}, SGST: ₹${sgst.toStringAsFixed(2)}, Delivery: ₹$deliveryCharges, Platform: ₹$platformFee, Discount: ₹$discount, Grand Total: ₹$grandTotal');

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Header with gradient
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFF7A1A), Color(0xFFFF4D4F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TAX E-BILL',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  invoiceNumber,
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ],
            ),
          ),
        ),

        // Info cards
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildInfoCard([
                  _buildInfoRow('E-Bill Number', invoiceNumber),
                  _buildInfoRow('Order ID', orderId),
                  _buildInfoRow('Date', _formatDate(createdAt)),
                  _buildInfoRow('Payment', paymentMethod),
                ]),
                const SizedBox(height: 16),

                // Customer and Shop details
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildDetailCard('BILL TO', [
                        customerName,
                        customerPhone,
                        customerEmail,
                        fullAddress,
                      ]),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDetailCard('FROM', [
                        shopName,
                        'GSTIN: $shopGstin',
                        shopAddress,
                        shopContact,
                      ]),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Items section
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Order Items',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _buildItemsTable(items),
              ],
            ),
          ),
        ),

        // Bill summary
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _buildBillSummary({
              'Subtotal': subtotal,
              'CGST': cgst,
              'SGST': sgst,
              'Delivery Charges': deliveryCharges,
              'Platform Fee': platformFee,
              'Discount': -discount,
              'Grand Total': grandTotal,
            }),
          ),
        ),

        // Action buttons
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ElevatedButton.icon(
                  onPressed: _downloadAndOpenInvoice,
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Download & Open E-Bill'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6A3D),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),

        // Footer
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  'Thank you for your purchase!',
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                ),
                SizedBox(height: 8),
                Text(
                  'For support: ${AppContactInfo.supportEmail}',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return GlassCard(
      margin: EdgeInsets.zero,
      borderRadius: 16,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard(String title, List<String> lines) {
    return GlassCard(
      margin: EdgeInsets.zero,
      borderRadius: 16,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFFFF6A3D),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...lines.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  line,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsTable(List<dynamic> items) {
    return GlassCard(
      margin: EdgeInsets.zero,
      borderRadius: 16,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Item',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Qty',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: Text(
                    'Price',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Items
            ...items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;

              // Handle different field names (name, productName, title)
              final name =
                  item['name']?.toString() ??
                  item['productName']?.toString() ??
                  item['title']?.toString() ??
                  'Item $index';

              // Handle different field names (quantity, qty)
              final qty =
                  (item['quantity'] as num?)?.toInt() ??
                  (item['qty'] as num?)?.toInt() ??
                  1;

              // Handle different field names (price, unitPrice)
              final price =
                  (item['price'] as num?)?.toDouble() ??
                  (item['unitPrice'] as num?)?.toDouble() ??
                  0.0;

              // Handle different field names (total, lineTotal)
              final total =
                  (item['total'] as num?)?.toDouble() ??
                  (item['lineTotal'] as num?)?.toDouble() ??
                  (price * qty);

              Log.i('InvoiceViewScreen', '📦 [E-Bill] Item $index: $name, Qty: $qty, Price: ₹$price, Total: ₹$total');

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '$qty',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '₹${total.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildBillSummary(Map<String, double> items) {
    return GlassCard(
      margin: EdgeInsets.zero,
      borderRadius: 16,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: items.entries.map((entry) {
            final isTotal = entry.key == 'Grand Total';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    entry.key,
                    style: TextStyle(
                      color: isTotal ? const Color(0xFFFF6A3D) : Colors.white70,
                      fontSize: isTotal ? 16 : 14,
                      fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                  Text(
                    entry.value < 0
                        ? '-₹${(-entry.value).toStringAsFixed(0)}'
                        : '₹${entry.value.toStringAsFixed(0)}',
                    style: TextStyle(
                      color: isTotal ? const Color(0xFFFF6A3D) : Colors.white,
                      fontSize: isTotal ? 18 : 14,
                      fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

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
}
