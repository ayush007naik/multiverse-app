import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:db_compat/db_compat.dart';
import 'package:intl/intl.dart';
import '../../theme/cyberpunk_theme.dart';
import '../../services/theatre_service.dart';
import '../../widgets/common/neon_button.dart';

class NotificationsTab extends StatefulWidget {
  const NotificationsTab({super.key});

  @override
  State<NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends State<NotificationsTab> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theatreService = Provider.of<TheatreService>(context);

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('NOTIFICATIONS', style: Theme.of(context).textTheme.titleLarge),
              NeonButton(
                text: 'SEND ALERT',
                icon: Icons.send,
                color: CyberpunkTheme.accentNeon,
                onPressed: () => _showSendNotificationDialog(context, theatreService),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: theatreService.getNotifications(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: CyberpunkTheme.primaryNeon));
                }
                final notifications = snapshot.data?.docs ?? [];
                if (notifications.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_off_outlined, size: 80, color: Colors.white.withValues(alpha: 0.1)),
                        const SizedBox(height: 16),
                        const Text('NO NOTIFICATIONS', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        const Text('Alerts and notifications will appear here.', style: TextStyle(color: Colors.white54)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final data = notifications[index].data();
                    final title = data['title'] ?? 'Notification';
                    final body = data['body'] ?? '';
                    final createdAt = data['createdAt'];
                    final sent = data['sent'] ?? false;
                    String timeStr = 'Just now';
                    if (createdAt is Timestamp) {
                      timeStr = DateFormat('dd MMM, hh:mm a').format(createdAt.toDate());
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: CyberpunkTheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: sent ? CyberpunkTheme.accentNeon.withValues(alpha: 0.3) : Colors.white10,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: CyberpunkTheme.accentNeon.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              sent ? Icons.check_circle : Icons.notifications_active,
                              color: sent ? Colors.greenAccent : CyberpunkTheme.accentNeon,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                const SizedBox(height: 4),
                                Text(body, style: const TextStyle(color: Colors.white54, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(timeStr, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: sent ? Colors.greenAccent.withValues(alpha: 0.1) : Colors.amber.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  sent ? 'SENT' : 'PENDING',
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: sent ? Colors.greenAccent : Colors.amber),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showSendNotificationDialog(BuildContext context, TheatreService service) {
    _titleCtrl.clear();
    _bodyCtrl.clear();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CyberpunkTheme.surface,
        title: const Text('SEND NOTIFICATION', style: TextStyle(color: CyberpunkTheme.accentNeon)),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'Title')),
              const SizedBox(height: 16),
              TextField(
                controller: _bodyCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Message'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: CyberpunkTheme.accentNeon, foregroundColor: Colors.black),
            onPressed: () async {
              if (_titleCtrl.text.isNotEmpty) {
                await service.sendNotification(_titleCtrl.text, _bodyCtrl.text);
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('SEND'),
          ),
        ],
      ),
    );
  }
}
