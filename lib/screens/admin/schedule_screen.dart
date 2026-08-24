import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firestore_service.dart';
import 'admin_theme.dart';

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();

    return StreamBuilder<QuerySnapshot>(
      stream: firestoreService.streamRepairRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final allDocs = snapshot.data?.docs ?? [];

        final scheduledDocs = allDocs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          return data['status'] == 'In Home' && data['scheduledVisit'] != null;
        }).toList();

        scheduledDocs.sort((a, b) {
          final aTs = (a.data() as Map<String, dynamic>)['scheduledVisit']
              as Timestamp;
          final bTs = (b.data() as Map<String, dynamic>)['scheduledVisit']
              as Timestamp;
          return aTs.compareTo(bTs);
        });

        if (scheduledDocs.isEmpty) {
          return const Center(
            child: Text(
              'No In Home visits scheduled right now.\n\n'
              'Requests will show up here once their status is set '
              'to "In Home" with a schedule.',
              textAlign: TextAlign.center,
              style: TextStyle(color: kAdminTextGray),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: scheduledDocs.length,
          itemBuilder: (context, index) {
            final data =
                scheduledDocs[index].data() as Map<String, dynamic>;
            final scheduledVisit = data['scheduledVisit'] as Timestamp;
            final date = scheduledVisit.toDate();

            const months = [
              'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
              'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
            ];
            final hour12 = date.hour % 12 == 0 ? 12 : date.hour % 12;
            final ampm = date.hour >= 12 ? 'PM' : 'AM';
            final dateLabel = '${months[date.month - 1]} ${date.day}, '
                '${date.year} • $hour12:${date.minute.toString().padLeft(2, '0')} $ampm';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kAdminCardBorder),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5B21B6).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.home_repair_service_rounded,
                        color: Color(0xFF5B21B6), size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['trackingId'] ?? '',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: kAdminTextDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${data['applianceType'] ?? ''} • ${data['name'] ?? ''}',
                          style: const TextStyle(
                              fontSize: 12, color: kAdminTextGray),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.schedule_rounded,
                                size: 13, color: kAdminTextGray),
                            const SizedBox(width: 4),
                            Text(
                              dateLabel,
                              style: const TextStyle(
                                  fontSize: 12, color: kAdminTextGray),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (data['assignedTechnician'] != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: kAdminBrand.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        data['assignedTechnician'],
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: kAdminBrand,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

