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
              margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
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
                          'Monitor your repair progress',
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
                final date = createdAt != null
                    ? '${createdAt.toDate().day}/${createdAt.toDate().month}/${createdAt.toDate().year}'
                    : 'N/A';

                final status = data['status'] as String? ?? 'Completed';
                final isDeclined = status == 'Declined';

                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TrackingScreen(
                        trackingId: data['trackingId'],
                      ),
                    ),
                  ),
                  child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDeclined
                                  ? const Color(0xFFFEE2E2)
                                  : const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                  color: isDeclined
                                      ? AppColors.danger
                                      : AppColors.success,
                                  fontSize: AppColors.fontCaption,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            date,
                            style: const TextStyle(
                                fontSize: AppColors.fontCaption,
                                color: AppColors.textLightGray),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        data['applianceType'] ?? 'Unknown',
                        style: const TextStyle(
                            fontSize: AppColors.fontBody,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data['problemDescription'] ?? '',
                        style: const TextStyle(
                            fontSize: AppColors.fontLabel,
                            color: AppColors.textGray),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.tag,
                              size: 14, color: AppColors.textLightGray),
                          const SizedBox(width: 4),
                          Text(
                            'Tracking ID: ${data['trackingId'] ?? 'N/A'}',
                            style: const TextStyle(
                                fontSize: AppColors.fontCaption,
                                color: AppColors.textLightGray),
                          ),
                        ],
                      ),
                    ],
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