import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../tracking/tracking_screen.dart';
import '../../utils/colors.dart';
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
      case 'In Home':
      case 'In Shop':
        return const Color(0xFF6366F1);
      case 'In Process':
        return const Color(0xFFEC4899);
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
              margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
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
            const SizedBox(height: 8),

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
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: sortedDocs.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final doc = sortedDocs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final status =
                            data['status'] as String? ?? 'Pending';
                        final applianceType =
                            data['applianceType'] as String? ?? 'Repair';

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
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: const Color(0xFFE5E7EB)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: const Color(0xFF111827),
                                        width: 1.5),
                                  ),
                                  child: Icon(
                                    _iconForAppliance(applianceType),
                                    color: const Color(0xFF111827),
                                    size: 22,
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
                                        style: const TextStyle(
                                          fontSize: AppColors.fontBody,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textDark,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color:
                                                  _colorForStatus(status),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            status,
                                            style: const TextStyle(
                                              fontSize: AppColors.fontLabel,
                                              color: AppColors.textGray,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right,
                                    color: Color(0xFF9CA3AF)),
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