import 'package:flutter/material.dart';
import 'package:db_compat/db_compat.dart';
import '../services/return_request_service.dart';
import 'dart:async';

class ReturnRequestScreen extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic> orderData;

  const ReturnRequestScreen({
    super.key,
    required this.orderId,
    required this.orderData,
  });

  @override
  State<ReturnRequestScreen> createState() => _ReturnRequestScreenState();
}

class _ReturnRequestScreenState extends State<ReturnRequestScreen> {
  final _reasonController = TextEditingController();
  bool _isSubmitting = false;
  String _requestType = 'return'; // return or replacement
  final List<String> _selectedIssues = [];
  Timer? _timer;
  int _timeRemainingMinutes = 0;
  bool _isAvailable = false;
  String? _existingRequestId;

  @override
  void initState() {
    super.initState();
    _checkAvailability();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _checkAvailability() async {
    final result = await ReturnRequestService.checkReturnAvailability(widget.orderId);
    
    if (mounted) {
      setState(() {
        _isAvailable = result['available'] ?? false;
        _timeRemainingMinutes = result['timeRemaining'] ?? 0;
      });

      if (_isAvailable) {
        _startTimer();
      }

      // Check existing request
      final existingRequest = await FirebaseFirestore.instance
          .collection('return_requests')
          .where('orderId', isEqualTo: widget.orderId)
          .limit(1)
          .get();

      if (existingRequest.docs.isNotEmpty) {
        setState(() {
          _existingRequestId = existingRequest.docs.first.id;
        });
      }
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      final result = await ReturnRequestService.checkReturnAvailability(widget.orderId);
      if (mounted) {
        setState(() {
          _timeRemainingMinutes = result['timeRemaining'] ?? 0;
          _isAvailable = result['available'] ?? false;
        });

        if (!_isAvailable) {
          _timer?.cancel();
        }
      }
    });
  }

  Future<void> _submitRequest() async {
    if (_reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Please enter reason'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedIssues.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Please select at least one issue type'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await ReturnRequestService.createReturnRequest(
        orderId: widget.orderId,
        requestType: _requestType,
        reason: _reasonController.text.trim(),
        issueType: _selectedIssues,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Return request submitted! Admin will review shortly.'),
            backgroundColor: Color(0xFF4CAF50),
            duration: Duration(seconds: 3),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // If existing request, show tracking
    if (_existingRequestId != null) {
      return _buildTrackingScreen();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D0518),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0518),
        elevation: 0,
        title: const Text(
          'Return/Replacement Request',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timer Card
            if (!_isAvailable)
              _buildExpiredCard()
            else
              _buildTimerCard(),

            const SizedBox(height: 24),

            // Order Info
            _buildOrderInfoCard(),

            const SizedBox(height: 24),

            // Request Type Selection
            _buildRequestTypeSelection(),

            const SizedBox(height: 20),

            // Issue Type Selection
            _buildIssueTypeSelection(),

            const SizedBox(height: 20),

            // Reason Input
            _buildReasonInput(),

            const SizedBox(height: 24),

            // Submit Button
            _buildSubmitButton(),

            const SizedBox(height: 16),

            // Info
            _buildInfoCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6A00), Color(0xFFFF9800)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer, color: Colors.white, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Return Window Active',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Time remaining: ${_timeRemainingMinutes ~/ 60}h ${_timeRemainingMinutes % 60}m',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpiredCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red),
      ),
      child: const Row(
        children: [
          Icon(Icons.timer_off, color: Colors.red, size: 32),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              'Return Window Expired\nReturns only available within 1 hour of delivery',
              style: TextStyle(
                color: Colors.red,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Details',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Order #${widget.orderId.substring(0, 8).toUpperCase()}',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            'Shop: ${widget.orderData['shopName'] ?? 'N/A'}',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            'Amount: ₹${widget.orderData['totalAmount'] ?? widget.orderData['total'] ?? 0}',
            style: const TextStyle(
              color: Color(0xFF4CAF50),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestTypeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Request Type',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildRequestTypeOption('return', '💰', 'Return & Refund'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildRequestTypeOption('replacement', '🔄', 'Replacement'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRequestTypeOption(String type, String emoji, String label) {
    final isSelected = _requestType == type;
    return GestureDetector(
      onTap: () => setState(() => _requestType = type),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF6A00) : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF6A00) : const Color(0xFF333333),
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIssueTypeSelection() {
    final issues = [
      {'id': 'broken_item', 'label': 'Broken/Damaged', 'icon': Icons.dangerous},
      {'id': 'wrong_item', 'label': 'Wrong Item', 'icon': Icons.swap_horiz},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Issue Type (Select all that apply)',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...issues.map((issue) {
          final isSelected = _selectedIssues.contains(issue['id']);
          return GestureDetector(
            onTap: () {
              setState(() {
                if (isSelected) {
                  _selectedIssues.remove(issue['id']);
                } else {
                  _selectedIssues.add(issue['id'] as String);
                }
              });
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFFF6A00).withValues(alpha: 0.2) : const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? const Color(0xFFFF6A00) : const Color(0xFF333333),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isSelected ? Icons.check_circle : Icons.circle_outlined,
                    color: isSelected ? const Color(0xFFFF6A00) : Colors.white70,
                  ),
                  const SizedBox(width: 12),
                  Icon(issue['icon'] as IconData, color: Colors.white70),
                  const SizedBox(width: 8),
                  Text(
                    issue['label'] as String,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildReasonInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Reason for Return/Replacement',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _reasonController,
          maxLines: 4,
          enabled: _isAvailable,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Describe the issue in detail...',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            filled: true,
            fillColor: const Color(0xFF2A2A2A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: (_isAvailable && !_isSubmitting) ? _submitRequest : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isAvailable ? const Color(0xFFFF6A00) : Colors.grey,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Submit Request',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2196F3).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2196F3).withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: Color(0xFF2196F3), size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Admin will review your request. If approved, pickup will be scheduled with delivery boy.',
              style: TextStyle(
                color: Color(0xFF2196F3),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingScreen() {
    return StreamBuilder<DocumentSnapshot>(
      stream: ReturnRequestService.getReturnRequestStream(widget.orderId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Scaffold(
            backgroundColor: Color(0xFF0D0518),
            body: Center(child: Text('Error loading request', style: TextStyle(color: Colors.red))),
          );
        }

        if (!snapshot.hasData) {
          return const Scaffold(
            backgroundColor: Color(0xFF0D0518),
            body: Center(child: CircularProgressIndicator(color: Color(0xFFFF6A00))),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        return _buildTrackingUI(data);
      },
    );
  }

  Widget _buildTrackingUI(Map<String, dynamic> data) {
    final status = data['status'] ?? 'pending';
    final adminStatus = data['adminStatus'] ?? 'pending';
    final pickupStatus = data['pickupStatus'] ?? 'not_scheduled';
    final refundStatus = data['refundStatus'] ?? 'not_initiated';
    final requestType = data['requestType'] ?? 'return';

    return Scaffold(
      backgroundColor: const Color(0xFF0D0518),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0518),
        elevation: 0,
        title: Text(
          '${requestType == 'return' ? 'Return' : 'Replacement'} Status',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildStatusTimeline(status, adminStatus, pickupStatus, refundStatus),
            const SizedBox(height: 24),
            _buildRequestDetails(data),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTimeline(String status, String adminStatus, String pickupStatus, String refundStatus) {
    final steps = [
      {
        'title': 'Request Submitted',
        'icon': Icons.send,
        'completed': true,
        'color': const Color(0xFF4CAF50),
      },
      {
        'title': 'Admin Review',
        'icon': Icons.admin_panel_settings,
        'completed': adminStatus != 'pending',
        'active': adminStatus == 'pending',
        'color': adminStatus == 'approved' ? const Color(0xFF4CAF50) : (adminStatus == 'rejected' ? Colors.red : const Color(0xFFFF9800)),
      },
      {
        'title': 'Pickup Scheduled',
        'icon': Icons.local_shipping,
        'completed': pickupStatus == 'completed',
        'active': pickupStatus == 'scheduled' || pickupStatus == 'in_transit',
        'color': pickupStatus == 'completed' ? const Color(0xFF4CAF50) : (pickupStatus != 'not_scheduled' ? const Color(0xFFFF9800) : Colors.grey),
      },
      {
        'title': 'Refund Processed',
        'icon': Icons.account_balance_wallet,
        'completed': refundStatus == 'completed',
        'color': refundStatus == 'completed' ? const Color(0xFF4CAF50) : Colors.grey,
      },
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: steps.asMap().entries.map((entry) {
          final index = entry.key;
          final step = entry.value;
          return _buildTimelineStep(step, index < steps.length - 1);
        }).toList(),
      ),
    );
  }

  Widget _buildTimelineStep(Map<String, dynamic> step, bool showLine) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (step['completed'] == true ? step['color'] : Colors.grey).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                step['icon'] as IconData,
                color: step['completed'] == true ? step['color'] : Colors.grey,
                size: 24,
              ),
            ),
            if (showLine)
              Container(
                width: 2,
                height: 40,
                color: Colors.grey.withValues(alpha: 0.3),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step['title'] as String,
                  style: TextStyle(
                    color: step['completed'] == true ? Colors.white : Colors.white54,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (step['active'] == true)
                  const Text(
                    'In Progress...',
                    style: TextStyle(
                      color: Color(0xFFFF9800),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRequestDetails(Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Request Details',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildDetailRow('Type', data['requestType']?.toUpperCase() ?? 'N/A'),
          _buildDetailRow('Status', data['status']?.toUpperCase() ?? 'N/A'),
          _buildDetailRow('Reason', data['reason'] ?? 'N/A'),
          if (data['pickupBoyId'] != null && data['pickupBoyId'].toString().isNotEmpty)
            _buildDetailRow('Pickup Boy ID', data['pickupBoyId']),
          if (data['refundAmount'] != null && data['refundAmount'] > 0)
            _buildDetailRow('Refund Amount', '₹${data['refundAmount']}'),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
