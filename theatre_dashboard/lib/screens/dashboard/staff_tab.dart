import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:db_compat/db_compat.dart';
import 'package:intl/intl.dart';
import '../../theme/cyberpunk_theme.dart';
import '../../services/theatre_service.dart';
import '../../widgets/common/neon_button.dart';

class StaffTab extends StatefulWidget {
  const StaffTab({super.key});

  @override
  State<StaffTab> createState() => _StaffTabState();
}

class _StaffTabState extends State<StaffTab> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _roleFilter = 'All';

  @override
  void dispose() {
    _searchCtrl.dispose();
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('STAFF MANAGEMENT', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text('Manage theatre staff accounts', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
                ],
              ),
              Row(
                children: [
                  Container(
                    width: 250,
                    height: 48,
                    decoration: BoxDecoration(
                      color: CyberpunkTheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Search staff by name, email...',
                        hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                        prefixIcon: Icon(Icons.search, color: Colors.white38, size: 20),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
                      ),
                      onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: CyberpunkTheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _roleFilter,
                        dropdownColor: CyberpunkTheme.surface,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        items: ['All', 'Scanner']
                            .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                            .toList(),
                        onChanged: (v) => setState(() => _roleFilter = v!),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  NeonButton(
                    text: 'ADD STAFF',
                    icon: Icons.person_add,
                    color: CyberpunkTheme.secondaryNeon,
                    onPressed: () => _showAddStaffDialog(context, theatreService),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: theatreService.getStaff(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: CyberpunkTheme.primaryNeon));
                }
                var staff = snapshot.data?.docs ?? [];

                if (_roleFilter != 'All') {
                  staff = staff.where((doc) {
                    final d = doc.data();
                    return (d['role'] ?? '').toString().toLowerCase() == _roleFilter.toLowerCase();
                  }).toList();
                }

                if (_searchQuery.isNotEmpty) {
                  staff = staff.where((doc) {
                    final d = doc.data();
                    final name = (d['name'] ?? '').toString().toLowerCase();
                    final email = (d['email'] ?? '').toString().toLowerCase();
                    final mobile = (d['mobile'] ?? '').toString().toLowerCase();
                    return name.contains(_searchQuery) || email.contains(_searchQuery) || mobile.contains(_searchQuery);
                  }).toList();
                }

                if (staff.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 80, color: Colors.white.withValues(alpha: 0.1)),
                        const SizedBox(height: 16),
                        const Text('NO STAFF MEMBERS', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        const Text('Add your first staff member to get started.', style: TextStyle(color: Colors.white54)),
                      ],
                    ),
                  );
                }

                return GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 3.5,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: staff.length,
                  itemBuilder: (context, index) {
                    final data = staff[index].data();
                    final docId = staff[index].id;
                    return _StaffCard(
                      id: docId,
                      data: data,
                      service: theatreService,
                      onUpdated: () => setState(() {}),
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

  void _showAddStaffDialog(BuildContext context, TheatreService service) {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final mobileCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final adminPasswordCtrl = TextEditingController();
    String selectedRole = 'Scanner';
    bool isActive = true;
    bool loading = false;
    bool showPass = false;
    bool showConfirm = false;
    bool showAdminPass = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => Dialog(
          backgroundColor: CyberpunkTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 480,
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ADD STAFF MEMBER', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: CyberpunkTheme.secondaryNeon)),
                const SizedBox(height: 24),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Full Name', hintText: 'Enter staff full name'),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email Address', hintText: 'staff@example.com'),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: mobileCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Mobile Number', hintText: '+91 9876543210'),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: passwordCtrl,
                        obscureText: !showPass,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          hintText: 'Min 6 characters',
                          suffixIcon: IconButton(
                            icon: Icon(showPass ? Icons.visibility_off : Icons.visibility, color: Colors.white54, size: 20),
                            onPressed: () => setDState(() => showPass = !showPass),
                          ),
                        ),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: confirmCtrl,
                        obscureText: !showConfirm,
                        decoration: InputDecoration(
                          labelText: 'Confirm Password',
                          suffixIcon: IconButton(
                            icon: Icon(showConfirm ? Icons.visibility_off : Icons.visibility, color: Colors.white54, size: 20),
                            onPressed: () => setDState(() => showConfirm = !showConfirm),
                          ),
                        ),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedRole,
                        decoration: const InputDecoration(labelText: 'Role'),
                        dropdownColor: CyberpunkTheme.surface,
                        style: const TextStyle(color: Colors.white),
                        items: ['Scanner'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                        onChanged: (v) => setDState(() => selectedRole = v ?? 'Scanner'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Row(
                        children: [
                          const Text('Active', style: TextStyle(color: Colors.white70)),
                          const SizedBox(width: 8),
                          Switch(
                            value: isActive,
                            onChanged: (v) => setDState(() => isActive = v),
                            activeThumbColor: Colors.greenAccent,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: adminPasswordCtrl,
                  obscureText: !showAdminPass,
                  decoration: InputDecoration(
                    labelText: 'Your Password',
                    hintText: 'Enter your password to confirm',
                    suffixIcon: IconButton(
                      icon: Icon(showAdminPass ? Icons.visibility_off : Icons.visibility, color: Colors.white54, size: 20),
                      onPressed: () => setDState(() => showAdminPass = !showAdminPass),
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: loading ? null : () async {
                        if (nameCtrl.text.isEmpty || emailCtrl.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Name and email are required'), backgroundColor: Colors.red),
                          );
                          return;
                        }
                        if (passwordCtrl.text.length < 6) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Password must be at least 6 characters'), backgroundColor: Colors.red),
                          );
                          return;
                        }
                        if (passwordCtrl.text != confirmCtrl.text) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Passwords do not match'), backgroundColor: Colors.red),
                          );
                          return;
                        }
                        if (adminPasswordCtrl.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter your password to create staff'), backgroundColor: Colors.red),
                          );
                          return;
                        }

                        final messenger = ScaffoldMessenger.of(context);
                        setDState(() => loading = true);
                        final err = await service.addStaffWithAuth({
                          'name': nameCtrl.text.trim(),
                          'email': emailCtrl.text.trim(),
                          'mobile': mobileCtrl.text.trim(),
                          'role': selectedRole,
                          'password': passwordCtrl.text,
                          'isActive': isActive,
                          'adminPassword': adminPasswordCtrl.text,
                        });

                        if (ctx.mounted) {
                          setDState(() => loading = false);
                          if (err != null) {
                            messenger.showSnackBar(
                              SnackBar(content: Text(err), backgroundColor: Colors.red),
                            );
                          } else {
                            Navigator.pop(ctx);
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Staff created successfully!'), backgroundColor: Colors.green),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CyberpunkTheme.secondaryNeon,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      ),
                      child: loading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('CREATE STAFF'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StaffCard extends StatelessWidget {
  final String id;
  final Map<String, dynamic> data;
  final TheatreService service;
  final VoidCallback onUpdated;

  const _StaffCard({
    required this.id,
    required this.data,
    required this.service,
    required this.onUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final name = data['name'] ?? 'Unknown';
    final role = data['role'] ?? 'Staff';
    final phone = data['mobile'] ?? data['phone'] ?? '-';
    final email = data['email'] ?? '-';
    final isActive = data['isActive'] ?? true;
    final lastLogin = data['lastLogin'] != null
        ? (data['lastLogin'] as Timestamp).toDate()
        : null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CyberpunkTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isActive ? CyberpunkTheme.secondaryNeon.withValues(alpha: 0.3) : Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isActive
                    ? [CyberpunkTheme.secondaryNeon, CyberpunkTheme.secondaryNeon.withValues(alpha: 0.5)]
                    : [Colors.grey, Colors.grey.withValues(alpha: 0.5)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              role.toString().toLowerCase().contains('manager') ? Icons.badge : Icons.person,
              color: Colors.white, size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: CyberpunkTheme.secondaryNeon.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: CyberpunkTheme.secondaryNeon.withValues(alpha: 0.3)),
                      ),
                      child: Text(role.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: CyberpunkTheme.secondaryNeon)),
                    ),
                    const SizedBox(width: 8),
                    Text(email, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(phone, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                    if (lastLogin != null) ...[
                      const SizedBox(width: 12),
                      Icon(Icons.login_rounded, size: 10, color: Colors.white.withValues(alpha: 0.3)),
                      const SizedBox(width: 4),
                      Text(
                        'Last: ${DateFormat('dd MMM, HH:mm').format(lastLogin)}',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 10),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      color: isActive ? Colors.greenAccent : Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(isActive ? 'Active' : 'Disabled',
                    style: TextStyle(color: isActive ? Colors.greenAccent : Colors.redAccent, fontSize: 11)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _IconBtn(Icons.edit_outlined, 'Edit', CyberpunkTheme.primaryNeon, () => _editStaff(context)),
                  const SizedBox(width: 4),
                  _IconBtn(
                    isActive ? Icons.block_outlined : Icons.check_circle_outlined,
                    isActive ? 'Disable' : 'Enable',
                    isActive ? Colors.orange : Colors.greenAccent,
                    () => _toggleActive(context),
                  ),
                  const SizedBox(width: 4),
                  _IconBtn(Icons.delete_outline, 'Delete', Colors.redAccent, () => _deleteStaff(context)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _IconBtn(IconData icon, String tooltip, Color color, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }

  void _editStaff(BuildContext context) {
    final nameCtrl = TextEditingController(text: data['name'] ?? '');
    final emailCtrl = TextEditingController(text: data['email'] ?? '');
    final mobileCtrl = TextEditingController(text: data['mobile'] ?? data['phone'] ?? '');
    String selectedRole = 'Scanner';
    bool isActive = data['isActive'] ?? true;
    bool loading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => Dialog(
          backgroundColor: CyberpunkTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 460,
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('EDIT STAFF', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: CyberpunkTheme.primaryNeon)),
                const SizedBox(height: 24),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full Name'), style: const TextStyle(color: Colors.white)),
                const SizedBox(height: 16),
                TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email'), style: const TextStyle(color: Colors.white)),
                const SizedBox(height: 16),
                TextField(controller: mobileCtrl, decoration: const InputDecoration(labelText: 'Mobile'), style: const TextStyle(color: Colors.white)),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  decoration: const InputDecoration(labelText: 'Role'),
                  dropdownColor: CyberpunkTheme.surface,
                  style: const TextStyle(color: Colors.white),
                  items: ['Scanner'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                  onChanged: (v) => setDState(() => selectedRole = v ?? 'Scanner'),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Active', style: TextStyle(color: Colors.white70)),
                    const SizedBox(width: 8),
                    Switch(
                      value: isActive,
                      onChanged: (v) => setDState(() => isActive = v),
                      activeThumbColor: Colors.greenAccent,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL', style: TextStyle(color: Colors.white54))),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: loading ? null : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        setDState(() => loading = true);
                        final err = await service.updateStaff(id, {
                          'name': nameCtrl.text.trim(),
                          'email': emailCtrl.text.trim(),
                          'mobile': mobileCtrl.text.trim(),
                          'role': selectedRole,
                          'isActive': isActive,
                        });

                        if (ctx.mounted) {
                          setDState(() => loading = false);
                          Navigator.pop(ctx);
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(err ?? 'Staff updated successfully!'),
                              backgroundColor: err != null ? Colors.red : Colors.green,
                            ),
                          );
                          onUpdated();
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: CyberpunkTheme.primaryNeon),
                      child: loading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('SAVE CHANGES'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _toggleActive(BuildContext context) async {
    final newState = !(data['isActive'] ?? true);
    final messenger = ScaffoldMessenger.of(context);
    final err = await service.toggleStaffActive(id, newState);
    if (context.mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(err ?? 'Staff ${newState ? 'enabled' : 'disabled'} successfully!'),
          backgroundColor: err != null ? Colors.red : Colors.green,
        ),
      );
      onUpdated();
    }
  }

  void _deleteStaff(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CyberpunkTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Staff', style: TextStyle(color: Colors.redAccent)),
        content: Text('Are you sure you want to delete ${data['name'] ?? 'this staff member'}? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              final err = await service.deleteStaff(id);
              if (context.mounted) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(err ?? 'Staff deleted successfully!'),
                    backgroundColor: err != null ? Colors.red : Colors.green,
                  ),
                );
                onUpdated();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }
}
