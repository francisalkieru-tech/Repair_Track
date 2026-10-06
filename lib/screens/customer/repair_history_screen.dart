import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../tracking/tracking_screen.dart';
import '../../utils/colors.dart';
import '../../utils/ui_widgets.dart';

class RepairHistoryScreen extends StatelessWidget {
  const RepairHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.darkGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Repair History',
                          style: TextStyle(
                            fontSize: AppColors.fontTitle,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Your completed and declined repairs',
                          style: TextStyle(
                              fontSize: AppColors.fontLabel,
                              color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('repairRequests')
            .where('customerId', isEqualTo: uid)
            .snapshots(),
        builder: (context, snapshot) {
          // Loading — shared indicator na may label.
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingIndicator(
                message: 'Loading your repair history...');
          }

          // Error — user-friendly message
          if (snapshot.hasError) {
            return AppErrorState(
              message: friendlyErrorMessage(snapshot.error),
            );
          }

          final allDocs = snapshot.data?.docs ?? [];

          // Client-side filter: 'Completed' or 'Declined' 
          final docs = allDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status'];
            return status == 'Completed' || status == 'Declined';
          }).toList();

          // Client-side sort: newest first based on createdAt
          docs.sort((a, b) {
            final aTime = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
            final bTime = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
            if (aTime == null || bTime == null) return 0;
            return bTime.compareTo(aTime);
          });

          if (docs.isEmpty) {
            return RefreshIndicator(
              color: AppColors.dark,
              onRefresh: () async {
                await Future.delayed(const Duration(milliseconds: 600));
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 80),
                  AppEmptyState(
                    icon: Icons.history,
                    title: 'No repair history yet.',
                    subtitle:
                        'Your completed and declined repair records will appear here.',
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: AppColors.dark,
            onRefresh: () async {
              await Future.delayed(const Duration(milliseconds: 600));
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                final createdAt = data['createdAt'] as Timestamp?;
                // Readable date, e.g. "Oct 4, 2026"
                const months = [
                  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
                ];
                String date = 'N/A';
                if (createdAt != null) {
                  final d = createdAt.toDate();
                  date = '${months[d.month - 1]} ${d.day}, ${d.year}';
                }

                final status = data['status'] as String? ?? 'Completed';
                final isDeclined = status == 'Declined';
                final problem = data['problemDescription'] as String? ?? '';
                final trackingId = data['trackingId'] as String? ?? '';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              TrackingScreen(trackingId: trackingId),
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border:
                              Border.all(color: const Color(0xFFE5E7EB)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x07000000),
                              blurRadius: 12,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Row 1: appliance + status pill
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    data['applianceType'] ?? 'Unknown',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: AppColors.fontSubtitle + 2,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textDark),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: isDeclined
                                        ? AppColors.dangerBg
                                        : const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isDeclined
                                            ? Icons.cancel_outlined
                                            : Icons.check_circle_outline,
                                        size: 14,
                                        color: isDeclined
                                            ? AppColors.danger
                                            : AppColors.success,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        status,
                                        style: TextStyle(
                                            color: isDeclined
                                                ? AppColors.danger
                                                : AppColors.success,
                                            fontSize: AppColors.fontCaption,
                                            fontWeight: FontWeight.w700),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (problem.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                problem,
                                style: const TextStyle(
                                    fontSize: AppColors.fontLabel,
                                    height: 1.35,
                                    color: AppColors.textGray),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 12),
                            const Divider(
                                height: 1, color: Color(0xFFE5E7EB)),
                            const SizedBox(height: 10),
                            // Row 2: tracking ID + date
                            Row(
                              children: [
                                const Icon(Icons.tag,
                                    size: 14, color: AppColors.textGray),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    trackingId.isEmpty ? 'N/A' : trackingId,
                                    style: const TextStyle(
                                        fontSize: AppColors.fontCaption,
                                        color: AppColors.textGray),
                                  ),
                                ),
                                const Icon(Icons.event_outlined,
                                    size: 14, color: AppColors.textGray),
                                const SizedBox(width: 4),
                                Text(
                                  date,
                                  style: const TextStyle(
                                      fontSize: AppColors.fontCaption,
                                      color: AppColors.textGray),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
              ),
            ),
          ],
        ),
      ),
    );
  }
}