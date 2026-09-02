import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../providers/auth_provider.dart';

class MedicalRecordsModule extends StatefulWidget {
  const MedicalRecordsModule({super.key});

  @override
  State<MedicalRecordsModule> createState() => _MedicalRecordsModuleState();
}

class _MedicalRecordsModuleState extends State<MedicalRecordsModule> {
  @override
  Widget build(BuildContext context) {
    final dashboardProvider = context.watch<DashboardProvider>();
    final authProvider = context.watch<AuthProvider>();
    final records = dashboardProvider.medicalRecords;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "PATIENT MEDICAL RECORDS",
              style: Theme.of(context).textTheme.displaySmall,
            ),
            ElevatedButton.icon(
              onPressed: () => _showUploadDialog(context, authProvider.user!.uid, dashboardProvider),
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text("UPLOAD RECORD"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6A00),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF14141C),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: records.isEmpty
                ? const Center(child: Text("No medical records found", style: TextStyle(color: Colors.white38)))
                : ListView.separated(
                    padding: const EdgeInsets.all(24),
                    itemCount: records.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final record = records[index];
                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.02),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.person_search_rounded, color: Color(0xFF8B5CF6)),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(record['patientName'] ?? 'Unknown Patient',
                                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                  Text("ID: ${record['id']}", style: const TextStyle(color: Colors.white38)),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(record['date'] ?? 'N/A',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                Text(record['status'] ?? 'N/A',
                                    style: TextStyle(color: _getStatusColor(record['status'] ?? ''), fontSize: 12)),
                              ],
                            ),
                            const SizedBox(width: 24),
                            IconButton(
                              onPressed: () {
                                // View record details
                              },
                              icon: const Icon(Icons.remove_red_eye_outlined, color: Colors.white24),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  void _showUploadDialog(BuildContext context, String partnerId, DashboardProvider provider) {
    final nameController = TextEditingController();
    final dateController = TextEditingController(text: DateTime.now().toString().split(' ')[0]);
    String status = 'Completed';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF14141C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: Colors.white10)),
          title: const Text("UPLOAD MEDICAL RECORD", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "PATIENT NAME",
                  labelStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: dateController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "DATE",
                  labelStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButton<String>(
                value: status,
                isExpanded: true,
                dropdownColor: const Color(0xFF14141C),
                style: const TextStyle(color: Colors.white),
                items: ['Completed', 'Follow-up', 'Pending'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (v) => setState(() => status = v!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL", style: TextStyle(color: Colors.white38))),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isNotEmpty) {
                  await provider.uploadMedicalRecord({
                    "partnerId": partnerId,
                    "patientName": nameController.text,
                    "date": dateController.text,
                    "status": status,
                  });
                  if (context.mounted) Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6A00)),
              child: const Text("UPLOAD"),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Completed': return Colors.greenAccent;
      case 'Follow-up': return Colors.blueAccent;
      case 'Pending': return Colors.amberAccent;
      default: return Colors.white38;
    }
  }
}
