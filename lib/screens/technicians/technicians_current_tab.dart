import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firestore_service.dart';
import '../../utils/colors.dart';
import '../../utils/constants.dart';
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
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
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
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Nothing in progress right now — start a job from '
                'Pending to see it here.',
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

class _CurrentJobCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  const _CurrentJobCard({required this.data, required this.onTap});

  Color _statusColor(String status) {
    switch (status) {
      case 'Waiting for Parts':
        return AppColors.waitingParts;
      case 'Pending Review':
        return AppColors.completed;
      default:
        return AppColors.inProcess;
    }
  }

  String _actionHint(String status) {
    switch (status) {
      case 'Waiting for Parts':
        return 'Waiting on the part — tap to check the latest.';
      case 'Pending Review':
        return 'Marked done — waiting on Admin to confirm.';
      default:
        return 'Tap to update this repair.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = data['status'] as String? ?? 'In Process';
    final appliance = data['applianceType'] as String? ?? 'Appliance';
    final trackingId = data['trackingId'] as String? ?? '';
    final problem = data['problemDescription'] as String? ?? '';
    final color = _statusColor(status);

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
            border: Border.all(color: color, width: 1.4),
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
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      AppConstants.displayLabel(status),
                      style: TextStyle(
                        fontSize: AppColors.fontCaption,
                        fontWeight: FontWeight.w700,
                        color: color,
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
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.touch_app_outlined, size: 15, color: color),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      _actionHint(status),
                      style: TextStyle(fontSize: 12, color: color),
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
