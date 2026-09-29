import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firestore_service.dart';
import '../../services/auth_service.dart';
import '../../utils/technician_availability.dart';
import 'admin_theme.dart';

class TechniciansScreen extends StatefulWidget {
  const TechniciansScreen({super.key});

  @override
  State<TechniciansScreen> createState() => _TechniciansScreenState();
}

class _TechniciansScreenState extends State<TechniciansScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kAdminBg,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showAddTechnicianDialog(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Technicians'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kAdminTextDark,
                  side: const BorderSide(color: kAdminCardBorder),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestoreService.streamRepairRequests(),
              builder: (context, requestsSnap) {
                final allData = (requestsSnap.data?.docs ?? [])
                    .map((d) => d.data() as Map<String, dynamic>)
                    .toList();

                return StreamBuilder<QuerySnapshot>(
                  stream: _firestoreService.streamTechnicians(),
                  builder: (context, techSnap) {
                    if (techSnap.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator());
                    }
                    final techs = techSnap.data?.docs ?? [];
                    if (techs.isEmpty) {
                      return const Center(
                        child: Text(
                          'No technicians yet. Tap "Add Technicians" '
                          'to add one.',
                          style: TextStyle(color: kAdminTextGray),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final crossAxisCount =
                            (constraints.maxWidth / 340).floor().clamp(1, 3);
                        return GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 2.3,
                          ),
                          itemCount: techs.length,
                          itemBuilder: (context, index) {
                            final doc = techs[index];
                            final data = doc.data() as Map<String, dynamic>;

                            final assignedJobs = activeJobsForTechnician(
                              allData,
                              data['name'] ?? '',
                            );

                            return _TechnicianCard(
                              docId: doc.id,
                              data: data,
                              activeJobCount: assignedJobs.length,
                              isAvailable: isTechnicianAvailable(
                                allData,
                                data['name'] ?? '',
                              ),
                            );
                          },
                        );
                      },
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
}

class _TechnicianCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final int activeJobCount;
  final bool isAvailable;

  const _TechnicianCard({
    required this.docId,
    required this.data,
    required this.activeJobCount,
    required this.isAvailable,
  });

  @override
  Widget build(BuildContext context) {
    final name = data['name'] ?? '';
    final phone = data['phoneNumber'] ?? '';
    final specialization = data['specialization'] ?? '';

    return Material(
      color: const Color(0xFFD9D9D9),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showTechnicianDetails(context, data, activeJobCount, isAvailable),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Technicians ID: ${docId.substring(0, docId.length >= 6 ? 6 : docId.length).toUpperCase()}',
                style: const TextStyle(fontSize: 10, color: Color(0xFF555555)),
              ),
              const SizedBox(height: 2),
              Text(
                'Name: $name',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.black,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'Phone Number: ${phone.isEmpty ? '—' : phone}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF444444)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'Specialization/Type: '
                '${specialization.isEmpty ? 'General repairs' : specialization}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF444444)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              Row(
                children: [
                  Row(
                    children: [
                      const Text(
                        'Status: ',
                        style: TextStyle(
                            fontSize: 11, color: Color(0xFF444444)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: isAvailable
                              ? const Color(0xFFBBF7D0)
                              : const Color(0xFFFECACA),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isAvailable ? 'Available' : 'Unavailable',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isAvailable
                                ? const Color(0xFF166534)
                                : const Color(0xFF991B1B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Material(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () =>
                          _showTechnicianDetails(context, data, activeJobCount, isAvailable),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        child: Text(
                          'View Details',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _showTechnicianDetails(BuildContext context, Map<String, dynamic> data,
    int activeJobCount, bool isAvailable) {
  final name = data['name'] ?? '';
  final phone = data['phoneNumber'] ?? '';
  final email = data['email'] ?? '';
  final specialization = data['specialization'] ?? '';
  final notes = data['notes'] ?? '';

  showDialog(
    context: context,
    builder: (context) => Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isAvailable
                              ? const Color(0xFFBBF7D0)
                              : const Color(0xFFFECACA),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isAvailable ? 'Available' : 'Unavailable',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isAvailable
                                ? const Color(0xFF166534)
                                : const Color(0xFF991B1B),
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        customBorder: const CircleBorder(),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.close,
                              size: 20, color: Color(0xFF6B7280)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _DetailRow(
                      icon: Icons.call_outlined,
                      label: 'Phone Number',
                      value: phone.isEmpty ? '—' : phone),
                  if (email.toString().isNotEmpty)
                    _DetailRow(
                        icon: Icons.email_outlined,
                        label: 'Email',
                        value: email),
                  _DetailRow(
                      icon: Icons.build_outlined,
                      label: 'Specialization',
                      value: specialization.isEmpty
                          ? 'General repairs'
                          : specialization),
                  _DetailRow(
                    icon: Icons.assignment_outlined,
                    label: 'Current Job Load',
                    value:
                        '$activeJobCount active job${activeJobCount == 1 ? '' : 's'} '
                        '(unavailable while on an In Home job, or at '
                        '$kMaxActiveJobsPerTechnician other active jobs)',
                  ),
                  if (notes.toString().isNotEmpty)
                    _DetailRow(
                        icon: Icons.notes_outlined,
                        label: 'Notes / Remarks',
                        value: notes),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF9CA3AF)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF111827),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void _showInviteCodeDialog(
    BuildContext context, String name, String inviteCode) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('"$name" added!'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Share this invite code with them directly (chat, SMS, or '
            'verbally) so they can set up their own login:',
          ),
          const SizedBox(height: 16),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                inviteCode,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'They\'ll use this code together with their email on the '
            '"First time logging in?" screen under Technician Login.',
            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    ),
  );
}

void _showAddTechnicianDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 640),
        child: _AddTechnicianDialog(),
      ),
    ),
  );
}

class _AddTechnicianDialog extends StatefulWidget {
  @override
  State<_AddTechnicianDialog> createState() => _AddTechnicianDialogState();
}

class _AddTechnicianDialogState extends State<_AddTechnicianDialog> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _specializationController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _specializationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Full name and phone number are required.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Email is required — the technician logs in and sets up their own account with it.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final result = await AuthService().addTechnicianWithInvite(
        email: email,
        name: name,
        phoneNumber: phone,
        specialization: _specializationController.text.trim(),
        notes: _notesController.text.trim(),
      );

      if (result['success'] != true) {
        throw result['error'] ?? 'Unknown error';
      }

      final inviteCode = result['inviteCode'] as String;

      if (mounted) {
        Navigator.pop(context);
        _showInviteCodeDialog(context, name, inviteCode);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add technician: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Add New Technician',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    customBorder: const CircleBorder(),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close,
                          size: 20, color: Color(0xFF6B7280)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _formField('Full Name', _nameController, 'Required'),
              const SizedBox(height: 12),
              _formField('Phone Number', _phoneController, 'Required'),
              const SizedBox(height: 12),
              _formField(
                  'Email', _emailController, 'Required'),
              const SizedBox(height: 12),
              _formField(
                  'Specialization', _specializationController, '(Optional)'),
              const SizedBox(height: 12),
              const Text('Notes / Remarks',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151))),
              const SizedBox(height: 6),
              TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: '(Optional)',
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Add Technician'),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'An invite code will be generated so the technician can '
                'set up their own login.',
                style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _formField(
      String label, TextEditingController controller, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151))),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
          ),
        ),
      ],
    );
  }
} 