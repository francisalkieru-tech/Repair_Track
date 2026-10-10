import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../tracking/tracking_screen.dart';
import '../../utils/colors.dart';
import '../../utils/constants.dart';
import '../../utils/ui_widgets.dart';

class MyRepairScreen extends StatelessWidget {
  const MyRepairScreen({super.key});

  IconData _iconForAppliance(String? applianceType) {
    switch (applianceType) {
      case 'Refrigerator':
        return Icons.kitchen_outlined;
      case 'Air Conditioner':
        return Icons.ac_unit_outlined;
      case 'Television':
        return Icons.tv_outlined;
      case 'Washing Machine':
        return Icons.local_laundry_service_outlined;
      case 'Microwave':
        return Icons.microwave_outlined;
      case 'Electric Fan':
        return Icons.mode_fan_off_outlined;
      case 'Water Dispenser':
        return Icons.water_drop_outlined;
      default:
        return Icons.build_outlined;
    }
  }

  Color _colorForStatus(String? status) {
    switch (status) {
      case 'Pending':
        return const Color(0xFFF59E0B);
      case 'Accepted':
        return const Color(0xFF3B82F6);
      case 'Tech Visit':
      case 'On-Site':
      case 'In Home': // old value, until migrated
      case 'In Shop': // old value, until migrated
        return const Color(0xFF6366F1);
      case 'In Process':
        return const Color(0xFFEC4899);
      case 'Queued':
      case 'Pending Review':
        return const Color(0xFFB45309);
      case 'Waiting for Parts':
        return const Color(0xFFEF4444);
      case 'Completed':
        return const Color(0xFF16A34A);
      case 'Declined':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF6B7280);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.darkGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'My Repair',
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
                        fontSize: AppColors.fontLabel, color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('repairRequests')
                    .where('customerId', isEqualTo: uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  // Loading  shared indicator na may label, hindi
                  // bare spinner lang.
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const AppLoadingIndicator(
                        message: 'Loading your repairs...');
                  }

                  // Error  user-friendly message imbes na raw
                  // Firestore exception text.
                  if (snapshot.hasError) {
                    return AppErrorState(
                      message: friendlyErrorMessage(snapshot.error),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];

                  // "My Repair"  active/ongoing lang. Once
                  // Completed o Declined na, dun na lang makikita
                  // sa Repair History — dito na wala na.
                  final activeDocs = docs.where((doc) {
                    final status = (doc.data()
                        as Map<String, dynamic>)['status'] as String?;
                    return status != 'Completed' && status != 'Declined';
                  }).toList();

                  // Newest first, batay sa createdAt (client-side sort
                  // para maiwasan ang composite index requirement).
                  final sortedDocs = [...activeDocs];
                  sortedDocs.sort((a, b) {
                    final aTime = (a.data()
                        as Map<String, dynamic>)['createdAt'] as Timestamp?;
                    final bTime = (b.data()
                        as Map<String, dynamic>)['createdAt'] as Timestamp?;
                    if (aTime == null || bTime == null) return 0;
                    return bTime.compareTo(aTime);
                  });

                  // Empty state malinaw na paalala kung ano next step
                  // ng customer, hindi lang blangkong screen.
                  if (sortedDocs.isEmpty) {
                    return RefreshIndicator(
                      color: AppColors.dark,
                      onRefresh: () async {
                        await Future.delayed(
                            const Duration(milliseconds: 600));
                      },
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 80),
                          AppEmptyState(
                            icon: Icons.build_outlined,
                            title: 'No active repairs right now.',
                            subtitle:
                                'Submit a repair request from the Home tab, or check Repair History for completed repairs.',
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
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: sortedDocs.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final doc = sortedDocs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final status =
                            data['status'] as String? ?? 'Pending';
                        final applianceType =
                            data['applianceType'] as String? ?? 'Repair';

                        final trackingId =
                            data['trackingId'] as String? ?? '';
                        final problem =
                            data['problemDescription'] as String? ?? '';
                        final needsAction = data['partsDecisionStatus'] ==
                            AppConstants.partsDecisionAwaitingCustomer;
                        final color = _colorForStatus(status);

                        return Material(
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
                                // Orange border when the customer must act
                                border: Border.all(
                                  color: needsAction
                                      ? const Color(0xFFFDBA74)
                                      : const Color(0xFFE5E7EB),
                                  width: needsAction ? 1.4 : 1,
                                ),
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
                                  // Info: appliance + tracking ID + status
                                  Row(
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF3F4F6),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          _iconForAppliance(applianceType),
                                          color: const Color(0xFF111827),
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              applianceType,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize:
                                                    AppColors.fontSubtitle + 2,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.textDark,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'ID: $trackingId',
                                              style: const TextStyle(
                                                fontSize:
                                                    AppColors.fontCaption,
                                                color: AppColors.textGray,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Status pill
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: 0.14),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 7,
                                              height: 7,
                                              decoration: BoxDecoration(
                                                color: color,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              AppConstants.displayLabel(
                                                  status),
                                              style: TextStyle(
                                                fontSize:
                                                    AppColors.fontCaption,
                                                fontWeight: FontWeight.w700,
                                                color: color,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (problem.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Text(
                                      problem,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: AppColors.fontLabel,
                                        height: 1.35,
                                        color: Color(0xFF4B5563),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  const Divider(
                                      height: 1, color: Color(0xFFE5E7EB)),
                                  const SizedBox(height: 12),

                                  // Action row: separate from the info above
                                  Row(
                                    children: [
                                      Icon(
                                        needsAction
                                            ? Icons.priority_high_rounded
                                            : Icons.timeline_outlined,
                                        size: 16,
                                        color: needsAction
                                            ? const Color(0xFF9A3412)
                                            : AppColors.textGray,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          needsAction
                                              ? 'Action needed: choose who supplies the part'
                                              : 'View repair progress',
                                          style: TextStyle(
                                            fontSize: AppColors.fontLabel,
                                            fontWeight: FontWeight.w600,
                                            color: needsAction
                                                ? const Color(0xFF9A3412)
                                                : AppColors.textDark,
                                          ),
                                        ),
                                      ),
                                      const Icon(Icons.chevron_right,
                                          size: 20,
                                          color: Color(0xFF9CA3AF)),
                                    ],
                                  ),
                                ],
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