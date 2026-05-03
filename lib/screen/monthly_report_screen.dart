import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/invoice_generator_service.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class MonthlyReportScreen extends StatefulWidget {
  const MonthlyReportScreen({super.key});

  @override
  State<MonthlyReportScreen> createState() => _MonthlyReportScreenState();
}

class _MonthlyReportScreenState extends State<MonthlyReportScreen> {
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  Map<String, dynamic>? _reportData;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    try {
      final report = await InvoiceGeneratorService.generateMonthlyReport(
        year: _selectedDate.year,
        month: _selectedDate.month,
      );
      setState(() => _reportData = report);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectMonth() async {
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (context) => _MonthPickerDialog(initialDate: _selectedDate),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _loadReport();
    }
  }

  Future<void> _downloadReport() async {
    if (_reportData == null) return;

    try {
      final pdf = await InvoiceGeneratorService.generateMonthlyReportPDF(_reportData!);
      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading report: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        title: const Text(
          'Monthly Report',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_reportData != null)
            IconButton(
              icon: const Icon(Icons.download, color: Colors.white),
              onPressed: _downloadReport,
              tooltip: 'Download PDF',
            ),
        ],
      ),
      body: Column(
        children: [
          // Month Selector
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF272727)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, color: Color(0xFFFF4D4F)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    DateFormat('MMMM yyyy').format(_selectedDate),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _selectMonth,
                  icon: const Icon(Icons.edit_calendar, size: 18),
                  label: const Text('Change'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF4D4F),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Report Content
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFF4D4F)),
                  )
                : _reportData == null
                    ? const Center(
                        child: Text(
                          'No data available',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : _buildReport(),
          ),
        ],
      ),
    );
  }

  Widget _buildReport() {
    final currencyFormat = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Cards
          Row(
            children: [
              _summaryCard(
                'Total Revenue',
                currencyFormat.format(_reportData!['totalRevenue']),
                Icons.payments,
                Colors.blue,
              ),
              const SizedBox(width: 12),
              _summaryCard(
                'Commission',
                currencyFormat.format(_reportData!['totalCommission']),
                Icons.account_balance_wallet,
                const Color(0xFFFF4D4F),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _summaryCard(
                'GST Collected',
                currencyFormat.format(_reportData!['totalGST']),
                Icons.receipt_long,
                Colors.red,
              ),
              const SizedBox(width: 12),
              _summaryCard(
                'Net Amount',
                currencyFormat.format(_reportData!['netAmount']),
                Icons.savings,
                Colors.green,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _summaryCard(
            'Total Invoices',
            '${_reportData!['totalInvoices']}',
            Icons.description,
            Colors.purple,
          ),

          const SizedBox(height: 24),

          // Invoice List
          const Text(
            'Invoice Details',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          if ((_reportData!['invoices'] as List).isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No invoices for this month',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: (_reportData!['invoices'] as List).length,
              itemBuilder: (context, index) {
                final invoice = _reportData!['invoices'][index];
                return _invoiceListItem(invoice, currencyFormat);
              },
            ),
        ],
      ),
    );
  }

  Widget _summaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF272727)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _invoiceListItem(
    Map<String, dynamic> invoice,
    NumberFormat currencyFormat,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF272727)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  invoice['invoiceNumber'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              Text(
                DateFormat('dd MMM yyyy').format(invoice['date'] as DateTime),
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            invoice['customerName'],
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _detailItem('Amount', currencyFormat.format(invoice['totalAmount'])),
              _detailItem('Commission', currencyFormat.format(invoice['commission'])),
              _detailItem('GST', currencyFormat.format(invoice['gst'])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.grey, fontSize: 10),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _MonthPickerDialog extends StatefulWidget {
  final DateTime initialDate;

  const _MonthPickerDialog({required this.initialDate});

  @override
  State<_MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<_MonthPickerDialog> {
  late int _selectedYear;
  late int _selectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.initialDate.year;
    _selectedMonth = widget.initialDate.month;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: const Text(
        'Select Month',
        style: TextStyle(color: Colors.white),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Year Selector
            DropdownButtonFormField<int>(
              value: _selectedYear,
              dropdownColor: const Color(0xFF1E1E1E),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Year',
                labelStyle: TextStyle(color: Colors.grey),
              ),
              items: List.generate(5, (index) {
                final year = DateTime.now().year - 2 + index;
                return DropdownMenuItem(
                  value: year,
                  child: Text(year.toString()),
                );
              }),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedYear = value);
                }
              },
            ),
            const SizedBox(height: 16),
            // Month Selector
            DropdownButtonFormField<int>(
              value: _selectedMonth,
              dropdownColor: const Color(0xFF1E1E1E),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Month',
                labelStyle: TextStyle(color: Colors.grey),
              ),
              items: List.generate(12, (index) {
                final month = index + 1;
                final name = DateFormat('MMMM').format(DateTime(0, month));
                return DropdownMenuItem(
                  value: month,
                  child: Text(name),
                );
              }),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedMonth = value);
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(
              context,
              DateTime(_selectedYear, _selectedMonth),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF4D4F),
            foregroundColor: Colors.white,
          ),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
