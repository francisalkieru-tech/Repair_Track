import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firestore_service.dart';
import '../../utils/colors.dart';
import '../../utils/ui_widgets.dart';
import '../../widget/tech_job_ui.dart';
import 'technicians_job_details.dart';

class TechnicianPendingTab extends StatelessWidget {
  final String technicianDocId;

  const TechnicianPendingTab({super.key, required this.technicianDocId});

  static const _pendingStatuses = {
    'Accepted',
    'On-Site',
    'Tech Visit',
    'In Shop', // old value, until migrated
    'In Home', // old value, until migrated
    'Queued',
  };

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreService().streamMyJobs(technicianDocId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppLoadingIndicator(message: 'Loading your jobs...');
        }

        final jobs = (snapshot.data?.docs ?? [])
            .where((d) => _pendingStatuses.contains(d['status']))
            .toList()
          ..sort((a, b) {
            final aTime = a['updatedAt'] as Timestamp?;
            final bTime = b['updatedAt'] as Timestamp?;
            return (bTime ?? Timestamp(0, 0)).compareTo(aTime ?? Timestamp(0, 0));
          });

        if (jobs.isEmpty) {
          return const AppEmptyState(
            icon: Icons.assignment_outlined,
            title: 'No pending jobs',
            subtitle: 'Jobs assigned to you will show up here.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          itemCount: jobs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final doc = jobs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _PendingJobCard(
              data: data,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      TechnicianJobDetailScreen(docId: doc.id, data: data),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Pending-tab card: shared job card + a primary "Start to repair" button.
class _PendingJobCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  const _PendingJobCard({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TechJobCard(
      data: data,
      onTap: onTap,
      footer: SizedBox(
        width: double.infinity,
        height: 46,
        child: ElevatedButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.play_circle_outline, size: 18),
          label: const Text('Start to repair'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.dark,
            foregroundColor: Colors.white,
            elevation: 0,
            textStyle: const TextStyle(
                fontSize: AppColors.fontLabel, fontWeight: FontWeight.w600),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }
}
