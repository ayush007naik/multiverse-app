import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../providers/auth_provider.dart';
import 'package:intl/intl.dart';

class ServiceListModule extends StatefulWidget {
  const ServiceListModule({super.key});

  @override
  State<ServiceListModule> createState() => _ServiceListModuleState();
}

class _ServiceListModuleState extends State<ServiceListModule> {
  final _amountController = TextEditingController();

  void _showUpdateAmountDialog(double currentAmount, DateTime? lastUpdate) {
    if (lastUpdate != null) {
      final difference = DateTime.now().difference(lastUpdate).inDays;
      if (difference < 30) {
        final daysLeft = 30 - difference;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("You can only change the booking amount once every 30 days. Please try again in $daysLeft days."),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
    }

    _amountController.text = currentAmount.toStringAsFixed(0);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF14141C),
        title: const Text("SET BOOKING AMOUNT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("This amount will be displayed to customers in the app.", style: TextStyle(color: Colors.white38, fontSize: 12)),
            const SizedBox(height: 20),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                prefixText: "₹ ",
                prefixStyle: const TextStyle(color: Color(0xFFFF6A00), fontSize: 24),
                filled: true,
                fillColor: Colors.white.withAlpha(12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFFF6A00))),
              ),
            ),
            const SizedBox(height: 16),
            const Text("NOTE: You can only change this once every 30 days.", style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL", style: TextStyle(color: Colors.white38))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6A00),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              final auth = context.read<AuthProvider>();
              final dashboard = context.read<DashboardProvider>();
              final amount = double.tryParse(_amountController.text) ?? 0.0;
              dashboard.updateBookingAmount(auth.user!.uid, amount);
              Navigator.pop(context);
            },
            child: const Text("CONFIRM UPDATE"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final dashboardProvider = context.watch<DashboardProvider>();
    final bookingAmount = dashboardProvider.bookingAmount;
    final lastUpdate = dashboardProvider.lastBookingAmountUpdate;

    int daysSinceUpdate = 30;
    if (lastUpdate != null) {
      daysSinceUpdate = DateTime.now().difference(lastUpdate).inDays;
    }
    final bool canUpdate = daysSinceUpdate >= 30;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              "BOOKING AMOUNT",
              style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: isMobile ? 20 : null),
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              "Set the fixed amount you charge for each appointment booking. This can only be updated once every 30 days.",
              style: TextStyle(color: Colors.white.withAlpha(128), fontSize: isMobile ? 12 : 14),
            ),
          ),
          SizedBox(height: isMobile ? 20 : 32),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(isMobile ? 20 : 32),
            decoration: BoxDecoration(
              color: const Color(0xFF14141C),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: canUpdate ? const Color(0xFFFF6A00).withAlpha(51) : Colors.white.withAlpha(12)),
              gradient: canUpdate ? LinearGradient(
                colors: [const Color(0xFFFF6A00).withAlpha(12), Colors.transparent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ) : null,
            ),
            child: Column(
              children: [
                const Text("CURRENT BOOKING FEE", style: TextStyle(color: Colors.white38, fontSize: 12, letterSpacing: 1.2, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text(
                  "₹ ${bookingAmount.toStringAsFixed(0)}",
                  style: TextStyle(color: Colors.white, fontSize: isMobile ? 32 : 48, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: isMobile ? 20 : 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _showUpdateAmountDialog(bookingAmount, lastUpdate),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canUpdate ? const Color(0xFFFF6A00) : Colors.white.withAlpha(12),
                      foregroundColor: canUpdate ? Colors.white : Colors.white24,
                      padding: EdgeInsets.symmetric(vertical: isMobile ? 14 : 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(
                      canUpdate ? "SET BOOKING AMOUNT" : "LOCKED FOR ${30 - daysSinceUpdate} DAYS",
                      style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: isMobile ? 12 : 14),
                    ),
                  ),
                ),
                if (lastUpdate != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    "Last updated: ${DateFormat('MMM dd, yyyy').format(lastUpdate)}",
                    style: const TextStyle(color: Colors.white24, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }
}