import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/dashboard_provider.dart';

class AppointmentsModule extends StatelessWidget {
  const AppointmentsModule({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final dashboardProvider = context.watch<DashboardProvider>();
    final appointments = dashboardProvider.allAppointments;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            "MANAGE APPOINTMENTS",
            style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: isMobile ? 20 : null),
          ),
        ),
        SizedBox(height: isMobile ? 16 : 24),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF14141C),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: appointments.isEmpty
                ? const Center(child: Text("No appointments scheduled", style: TextStyle(color: Colors.white38)))
                : ListView.separated(
                    padding: EdgeInsets.all(isMobile ? 12 : 24),
                    itemCount: appointments.length,
                    separatorBuilder: (context, index) => SizedBox(height: isMobile ? 8 : 16),
                    itemBuilder: (context, index) {
                      final appt = appointments[index];
                      return Container(
                        padding: EdgeInsets.all(isMobile ? 12 : 16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.02),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(isMobile ? 8 : 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF6A00).withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.calendar_today_rounded, color: const Color(0xFFFF6A00), size: isMobile ? 16 : 20),
                            ),
                            SizedBox(width: isMobile ? 10 : 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(appt['customerName'] ?? appt['userName'] ?? "Client", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: isMobile ? 13 : 14)),
                                  if (appt['customerPhone'] != null && appt['customerPhone'].isNotEmpty) 
                                    Text(appt['customerPhone'], style: const TextStyle(color: Color(0xFFFF6A00), fontSize: 11)),
                                  Text(appt['serviceName'] ?? "Service", style: const TextStyle(color: Colors.white38, fontSize: 12)),
                                  if (appt['problem'] != null && appt['problem'].isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text("Reason: ${appt['problem']}", style: const TextStyle(color: Colors.white70, fontSize: 11, fontStyle: FontStyle.italic)),
                                  ]
                                ],
                              ),
                            ),
                            if (!isMobile) ...[
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(appt['time'] ?? "N/A", style: const TextStyle(color: Color(0xFFFF6A00), fontWeight: FontWeight.bold)),
                                  Text(appt['date'] ?? "N/A", style: const TextStyle(color: Colors.white38, fontSize: 10)),
                                ],
                              ),
                              const SizedBox(width: 16),
                              IconButton(
                                onPressed: () => _showStatusDialog(context, appt),
                                icon: const Icon(Icons.more_vert_rounded, color: Colors.white24),
                              ),
                            ],
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

  void _showStatusDialog(BuildContext context, Map<String, dynamic> appt) {
    final dashboardProvider = context.read<DashboardProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF14141C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Update Appointment Status", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            _statusOption(context, "Confirmed", Colors.green, () {
              dashboardProvider.updateAppointmentStatus(appt['id'], "Confirmed");
              Navigator.pop(context);
            }),
            _statusOption(context, "Completed", Colors.blue, () {
              dashboardProvider.updateAppointmentStatus(appt['id'], "Completed");
              Navigator.pop(context);
            }),
            _statusOption(context, "Cancelled", Colors.red, () {
              dashboardProvider.updateAppointmentStatus(appt['id'], "Cancelled");
              Navigator.pop(context);
            }),
          ],
        ),
      ),
    );
  }

  Widget _statusOption(BuildContext context, String label, Color color, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
        child: Icon(Icons.check_circle_outline, color: color, size: 20),
      ),
      title: Text(label, style: const TextStyle(color: Colors.white)),
    );
  }
}
