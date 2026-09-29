import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firestore_service.dart';
import '../../utils/colors.dart';
import '../../utils/constants.dart';
import 'technicians_job_details.dart';

class TechnicianPendingTab extends StatelessWidget {
  final String technicianDocId;

  const TechnicianPendingTab({super.key, required this.technicianDocId});

  static const _pendingStatuses = {
    'Accepted',
    'In Shop',
    'In Home',
    'Queued',
  };

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreService().streamMyJobs(technicianDocId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
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
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No pending jobs right now.',
                style: TextStyle(
                    fontSize: AppColors.fontBody, color: AppColors.textGray),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
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

class _PendingJobCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  const _PendingJobCard({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = data['status'] as String? ?? 'Pending';
    final appliance = data['applianceType'] as String? ?? 'Appliance';
    final trackingId = data['trackingId'] as String? ?? '';
    final problem = data['problemDescription'] as String? ?? '';

    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(appliance,
                      style: const TextStyle(
                          fontSize: AppColors.fontBody,
                          fontWeight: FontWeight.bold)),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accepted.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      AppConstants.displayLabel(status),
                      style: const TextStyle(
                        fontSize: AppColors.fontCaption,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accepted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text('Tracking ID: $trackingId',
                  style: const TextStyle(
                      fontSize: AppColors.fontCaption,
                      color: AppColors.textGray)),
              if (problem.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  problem,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: AppColors.fontLabel),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.play_circle_outline, size: 18),
                  label: const Text('Start to repair'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.inProcess,
                    side: BorderSide(color: AppColors.inProcess),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
