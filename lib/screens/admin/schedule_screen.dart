import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firestore_service.dart';
import '../../utils/constants.dart';
import 'admin_theme.dart';
import 'requests_screen.dart' show showQrDialog;

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();

    return Container(
      color: kAdminBg,
      child: StreamBuilder<QuerySnapshot>(
        stream: firestoreService.streamRepairRequests(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final allDocs = snapshot.data?.docs ?? [];

          final scheduledDocs = allDocs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            return data['status'] == 'In Home' &&
                data['scheduledVisit'] != null;
          }).toList();

          scheduledDocs.sort((a, b) {
            final aTs = (a.data() as Map<String, dynamic>)['scheduledVisit']
                as Timestamp;
            final bTs = (b.data() as Map<String, dynamic>)['scheduledVisit']
                as Timestamp;
            return aTs.compareTo(bTs);
          });

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD9D9D9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'In Home Repair Schedule',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: scheduledDocs.isEmpty
                    ? const Center(
                        child: Text(
                          'No In Home visits scheduled right now.\n\n'
                          'Requests will show up here once their status is '
                          'set to "In Home" with a schedule.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: kAdminTextGray),
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final crossAxisCount =
                              (constraints.maxWidth / 300).floor().clamp(1, 4);
                          return GridView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 1.7,
                            ),
                            itemCount: scheduledDocs.length,
                            itemBuilder: (context, index) {
                              final doc = scheduledDocs[index];
                              final data = doc.data() as Map<String, dynamic>;
                              return _ScheduleCard(docId: doc.id, data: data);
                            },
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

String _formatScheduleLabel(DateTime date, {bool relative = true}) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  final hour12 = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final ampm = date.hour >= 12 ? 'PM' : 'AM';
  final timeStr = '$hour12:${date.minute.toString().padLeft(2, '0')} $ampm';

  if (relative) {
    final now = DateTime.now();
    final isToday = date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
    final tomorrow = now.add(const Duration(days: 1));
    final isTomorrow = date.year == tomorrow.year &&
        date.month == tomorrow.month &&
        date.day == tomorrow.day;

    if (isToday) return 'Today, $timeStr';
    if (isTomorrow) return 'Tomorrow, $timeStr';
  }
  return '${months[date.month - 1]} ${date.day}, $timeStr';
}

class _ScheduleCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;

  const _ScheduleCard({required this.docId, required this.data});

  @override
  Widget build(BuildContext context) {
    final trackingId = data['trackingId'] ?? '';
    final name = data['name'] ?? '';
    final applianceType = data['applianceType'] ?? '';
    final contactNumber = data['contactNumber'] ?? '';
    final status = data['status'] ?? '';
    final scheduledVisit = data['scheduledVisit'] as Timestamp?;
    final scheduleLabel = scheduledVisit != null
        ? _formatScheduleLabel(scheduledVisit.toDate())
        : '—';
    final colors = statusColors(status);

    return Material(
      color: const Color(0xFFD9D9D9),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showScheduleDetails(context, data),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tracking ID:',
                      style:
                          TextStyle(fontSize: 10, color: Color(0xFF555555)),
                    ),
                    Text(
                      trackingId,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        letterSpacing: 1,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Name: $name',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF444444)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Appliance: $applianceType',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF444444)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Contact Number: $contactNumber',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF444444)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Text(
                          'Status : ',
                          style: TextStyle(
                              fontSize: 11, color: Color(0xFF444444)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: colors.$1,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            AppConstants.displayLabel(status),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: colors.$2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Schedule',
                    style: TextStyle(fontSize: 10, color: Color(0xFF555555)),
                  ),
                  Text(
                    scheduleLabel,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const Spacer(),
                  Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => showQrDialog(context, trackingId, name),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.qr_code_2,
                                size: 16, color: Colors.black),
                            SizedBox(width: 4),
                            Text(
                              'View QR',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                              ),
                            ),
                          ],
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

void _showScheduleDetails(BuildContext context, Map<String, dynamic> data) {
  final trackingId = data['trackingId'] ?? '';
  final name = data['name'] ?? '';
  final contactNumber = data['contactNumber'] ?? '';
  final address = data['address'] ?? '';
  final applianceType = data['applianceType'] ?? '';
  final problemDescription = data['problemDescription'] ?? '';
  final assignedTechnician = data['assignedTechnician'] as String?;
  final status = data['status'] ?? '';
  final scheduledVisit = data['scheduledVisit'] as Timestamp?;
  final colors = statusColors(status);
  final scheduleLabel = scheduledVisit != null
      ? _formatScheduleLabel(scheduledVisit.toDate(), relative: false)
      : '—';

  showDialog(
    context: context,
    builder: (context) => Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 620),
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
                          color: colors.$1,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          AppConstants.displayLabel(status),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: colors.$2,
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
                    'Home Visit — $trackingId',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _DetailRow(
                      icon: Icons.event_outlined,
                      label: 'Scheduled Visit',
                      value: scheduleLabel),
                  _DetailRow(
                      icon: Icons.person_outline,
                      label: 'Customer',
                      value: name),
                  _DetailRow(
                      icon: Icons.call_outlined,
                      label: 'Contact Number',
                      value: contactNumber),
                  if (address.toString().isNotEmpty)
                    _DetailRow(
                        icon: Icons.location_on_outlined,
                        label: 'Location',
                        value: address),
                  _DetailRow(
                      icon: Icons.kitchen_outlined,
                      label: 'Appliance',
                      value: applianceType),
                  if (problemDescription.toString().isNotEmpty)
                    _DetailRow(
                        icon: Icons.description_outlined,
                        label: 'Appliance Problem',
                        value: problemDescription),
                  if (assignedTechnician != null &&
                      assignedTechnician.isNotEmpty)
                    _DetailRow(
                        icon: Icons.engineering_outlined,
                        label: 'Technician',
                        value: assignedTechnician),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        showQrDialog(context, trackingId, name);
                      },
                      icon: const Icon(Icons.qr_code_2, size: 18),
                      label: const Text('View QR'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black,
                        side: const BorderSide(color: Color(0xFFD1D5DB)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
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
                  style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}