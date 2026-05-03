import 'package:flutter/material.dart';

import '../services/settings_service.dart';

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key, this.selectionMode = false});

  final bool selectionMode;

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  final SettingsService _settingsService = SettingsService();

  Future<void> _openAddUpi() async {
    final controller = TextEditingController();
    String provider = 'Google Pay';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add UPI ID',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration(
                      'UPI ID',
                      Icons.alternate_email_rounded,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: provider,
                    dropdownColor: const Color(0xFF1E1E1E),
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration(
                      'Provider',
                      Icons.account_balance_wallet_rounded,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Google Pay',
                        child: Text('Google Pay'),
                      ),
                      DropdownMenuItem(
                        value: 'PhonePe',
                        child: Text('PhonePe'),
                      ),
                      DropdownMenuItem(value: 'Paytm', child: Text('Paytm')),
                      DropdownMenuItem(
                        value: 'BHIM UPI',
                        child: Text('BHIM UPI'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setModalState(() => provider = value);
                    },
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final navigator = Navigator.of(context);
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await _settingsService.addUpiMethod(
                            upiId: controller.text,
                            providerLabel: provider,
                          );
                          if (!mounted) return;
                          navigator.pop();
                        } catch (e) {
                          if (!mounted) return;
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                e.toString().replaceFirst(
                                  'Invalid argument(s): ',
                                  '',
                                ),
                              ),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF4D4F),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Save UPI ID'),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _openAddCard() async {
    final nameController = TextEditingController();
    final last4Controller = TextEditingController();
    String brand = 'Visa';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add Card',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration(
                      'Cardholder name',
                      Icons.person_outline_rounded,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: last4Controller,
                    maxLength: 4,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration(
                      'Last 4 digits only',
                      Icons.credit_card_rounded,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: brand,
                    dropdownColor: const Color(0xFF1E1E1E),
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration(
                      'Card brand',
                      Icons.style_rounded,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Visa', child: Text('Visa')),
                      DropdownMenuItem(
                        value: 'Mastercard',
                        child: Text('Mastercard'),
                      ),
                      DropdownMenuItem(value: 'RuPay', child: Text('RuPay')),
                      DropdownMenuItem(value: 'Amex', child: Text('Amex')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setModalState(() => brand = value);
                    },
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Only masked card metadata is stored. Full card details are not saved in Firestore.',
                    style: TextStyle(color: Color(0xFF888888), fontSize: 12),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final navigator = Navigator.of(context);
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await _settingsService.addCardMethod(
                            cardholderName: nameController.text,
                            last4Digits: last4Controller.text,
                            brand: brand,
                          );
                          if (!mounted) return;
                          navigator.pop();
                        } catch (e) {
                          if (!mounted) return;
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                e.toString().replaceFirst(
                                  'Invalid argument(s): ',
                                  '',
                                ),
                              ),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF4D4F),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Save Card'),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _selectMethod(Map<String, dynamic> method) async {
    final id = method['id'] as String?;
    if (id == null) return;
    await _settingsService.selectPaymentMethod(id);
    if (!mounted) return;
    if (widget.selectionMode) {
      Navigator.pop(context, {...method, 'isDefault': true});
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Default payment method updated'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _deleteMethod(Map<String, dynamic> method) async {
    final id = method['id'] as String?;
    if (id == null) return;
    await _settingsService.deletePaymentMethod(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Payment method removed'),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        title: Text(
          widget.selectionMode ? 'Select Payment Method' : 'Payment Methods',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _settingsService.streamPaymentMethods(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF4D4F)),
            );
          }

          final methods = snapshot.data ?? [];
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _openAddUpi,
                      icon: const Icon(Icons.alternate_email_rounded),
                      label: const Text('Add UPI'),
                      style: _topActionStyle(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _openAddCard,
                      icon: const Icon(Icons.credit_card_rounded),
                      label: const Text('Add Card'),
                      style: _topActionStyle(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'Saved payment methods',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              if (methods.isEmpty)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF272727)),
                  ),
                  child: const Text(
                    'No saved payment methods yet. Add a UPI ID or masked card.',
                    style: TextStyle(color: Color(0xFFAAAAAA)),
                  ),
                ),
              ...methods.map(_buildMethodCard),
              const SizedBox(height: 16),
              const Text(
                'Security: only UPI IDs and masked card details are stored. Full card numbers, CVV, and expiry are never written to Firestore.',
                style: TextStyle(color: Color(0xFF888888), fontSize: 12),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMethodCard(Map<String, dynamic> method) {
    final isDefault = method['isDefault'] == true;
    final type = method['type'] as String? ?? SettingsService.paymentTypeUpi;
    final icon = type == SettingsService.paymentTypeCard
        ? Icons.credit_card_rounded
        : Icons.account_balance_wallet_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDefault ? const Color(0xFFFF4D4F) : const Color(0xFF272727),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF4D4F).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFFFF4D4F)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      SettingsService.paymentMethodLabel(method),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      type == SettingsService.paymentTypeCard
                          ? 'Stored as masked card metadata'
                          : 'Saved for Razorpay UPI checkout',
                      style: const TextStyle(
                        color: Color(0xFF888888),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (isDefault)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF4D4F).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Default',
                    style: TextStyle(
                      color: Color(0xFFFF4D4F),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _selectMethod(method),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: isDefault
                          ? const Color(0xFFFF4D4F)
                          : const Color(0xFF444444),
                    ),
                  ),
                  child: Text(
                    widget.selectionMode
                        ? 'Use This'
                        : isDefault
                        ? 'Selected'
                        : 'Set Default',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                onPressed: () => _deleteMethod(method),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.redAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  ButtonStyle _topActionStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: Colors.white,
      side: const BorderSide(color: Color(0xFF333333)),
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF888888)),
      prefixIcon: Icon(icon, color: const Color(0xFFFF4D4F)),
      filled: true,
      fillColor: const Color(0xFF111111),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF272727)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFFF4D4F)),
      ),
    );
  }
}
