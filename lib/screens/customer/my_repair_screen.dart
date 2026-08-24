import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../tracking/tracking_screen.dart';

/// "My Repair" — full list of the customer's repair requests, each
/// row showing a status dot. Opened from the "Active Repair" card or
/// "In Process" stat on the Home Screen, and is also the content of
/// the "Repair" tab in the bottom nav.
class MyRepairScreen extends StatelessWidget {
  const MyRepairScreen({super.key});

  // Maps an appliance type string to its list icon.
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

  // Maps a repair status string to its indicator dot color.
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
      backgroundColor: const Color(0xFFF8FAFF),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header — solid black card with screen title + subtitle
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'My Repair',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Monitor your repair progress',
                    style: TextStyle(fontSize: 13, color: Colors.white70),
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
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  final docs = snapshot.data?.docs ?? [];

                  // Sort newest first by createdAt (done client-side to
                  // avoid needing a Firestore composite index).
                  final sortedDocs = [...docs];
                  sortedDocs.sort((a, b) {
                    final aTime = (a.data()
                        as Map<String, dynamic>)['createdAt'] as Timestamp?;
                    final bTime = (b.data()
                        as Map<String, dynamic>)['createdAt'] as Timestamp?;
                    if (aTime == null || bTime == null) return 0;
                    return bTime.compareTo(aTime);
                  });

                  if (sortedDocs.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.build_outlined,
                                size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            const Text(
                              'No repair requests yet.',
                              style: TextStyle(
                                  fontSize: 16, color: Color(0xFF6B7280)),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Submit a repair request from the Home tab to get started.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 13, color: Color(0xFF9CA3AF)),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    itemCount: sortedDocs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final doc = sortedDocs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final status = data['status'] as String? ?? 'Pending';
                      final applianceType =
                          data['applianceType'] as String? ?? 'Repair';

                      // Tap a request row to open its tracking detail.
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
                            border:
                                Border.all(color: const Color(0xFFE5E7EB)),
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
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF111827),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: _colorForStatus(status),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          status,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF6B7280),
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