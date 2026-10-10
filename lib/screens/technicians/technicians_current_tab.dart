import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firestore_service.dart';
import '../../utils/colors.dart';
import '../../utils/ui_widgets.dart';
import '../../widget/tech_job_ui.dart';
import 'technicians_job_details.dart';

class TechnicianCurrentTab extends StatelessWidget {
  final String technicianDocId;

  const TechnicianCurrentTab({super.key, required this.technicianDocId});

  static const _currentStatuses = {
    'In Process',
    'Waiting for Parts',
    'Pending Review',
  };

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreService().streamMyJobs(technicianDocId),
      builder: (context, snapshot) {
        // Show a clear error instead of an endless spinner / blank screen.
        if (snapshot.hasError) {
          return AppErrorState(message: friendlyErrorMessage(snapshot.error));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppLoadingIndicator(message: 'Loading your jobs...');
        }

        final jobs = (snapshot.data?.docs ?? [])
            .where((d) => _currentStatuses.contains(d['status']))
            .toList()
          ..sort((a, b) {
            final aTime = a['updatedAt'] as Timestamp?;
            final bTime = b['updatedAt'] as Timestamp?;
            return (bTime ?? Timestamp(0, 0)).compareTo(aTime ?? Timestamp(0, 0));
          });

        if (jobs.isEmpty) {
          return const AppEmptyState(
            icon: Icons.handyman_outlined,
            title: 'Nothing in progress',
            subtitle: 'Start a job from Pending to see it here.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          itemCount: jobs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final doc = jobs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _CurrentJobCard(
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

/// Current-tab card: shared job card + a status hint at the bottom.
class _CurrentJobCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  const _CurrentJobCard({required this.data, required this.onTap});

  String _actionHint(String status) {
    switch (status) {
      case 'Waiting for Parts':
        return 'Waiting on the part. Tap to check the latest.';
      case 'Pending Review':
        return 'Marked done. Waiting on Admin to confirm.';
      default:
        return 'Tap to update this repair.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = data['status'] as String? ?? 'In Process';
    final color = techStatusTextColor(status);

    return TechJobCard(
      data: data,
      onTap: onTap,
      footer: Row(
        children: [
          Icon(Icons.touch_app_outlined, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _actionHint(status),
              style: TextStyle(
                  fontSize: AppColors.fontCaption,
                  fontWeight: FontWeight.w600,
                  color: color),
            ),
          ),
          Icon(Icons.chevron_right, size: 20, color: color),
        ],
      ),
    );
  }
}
