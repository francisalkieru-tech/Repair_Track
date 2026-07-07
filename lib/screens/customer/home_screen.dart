import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import '../tracking/tracking_screen.dart';
import 'repair_request_screen.dart';
import 'repair_history_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showActiveRepairs = false;

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        title: const Text('RepairTrack'),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              ),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: const Icon(Icons.person,
                    color: Colors.white, size: 22),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Greeting
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFF2563EB),
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Welcome back!',
                          style: TextStyle(
                              fontSize: 13, color: Color(0xFF6B7280))),
                      Text(
                        user?.email ?? 'Customer',
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Active Repairs — Collapsible Section
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('repairRequests')
                  .where('customerId', isEqualTo: uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox.shrink();
                }

                final activeDocs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final status = data['status'];

                  // Pending pa (di pa na-review/na-accept ng admin) →
                  // hindi pa lumalabas sa Active Repairs. Lalabas lang
                  // 'to pagkatapos i-Accept (status na "Accepted" or
                  // anumang sumunod dito).
                  if (status == 'Pending') return false;

                  // Hindi pa Completed/Declined → kasama sa Active Repairs.
                  if (status != 'Completed' && status != 'Declined') {
                    return true;
                  }

                  // Completed o Declined na — pero panatilihin pa rin
                  // dito for 24 hours mula noong na-update (updatedAt),
                  // bago ito lumipat permanently palabas ng Active Repairs.
                  final updatedAt = data['updatedAt'] as Timestamp?;
                  if (updatedAt == null) return false;

                  final hoursSinceCompleted =
                      DateTime.now().difference(updatedAt.toDate()).inHours;
                  return hoursSinceCompleted < 24;
                }).toList();

                if (activeDocs.isEmpty) {
                  return const SizedBox.shrink();
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Toggle header — clickable
                    GestureDetector(
                      onTap: () => setState(
                          () => _showActiveRepairs = !_showActiveRepairs),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.build_circle_outlined,
                                  color: Color(0xFF2563EB), size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Active Repairs (${activeDocs.length})',
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF111827)),
                              ),
                            ),
                            Icon(
                              _showActiveRepairs
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              color: const Color(0xFF6B7280),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Expandable list
                    if (_showActiveRepairs) ...[
                      const SizedBox(height: 10),
                      ...activeDocs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
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
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: const Color(0xFFE5E7EB)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.build,
                                      color: Color(0xFF2563EB), size: 24),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        data['applianceType'] ?? '',
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF111827)),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          _buildStatusDot(data['status']),
                                          const SizedBox(width: 4),
                                          Text(
                                            data['status'] ?? 'Pending',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF6B7280)),
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
                      }),
                    ],
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),

            const Text(
              'What do you need?',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827)),
            ),
            const SizedBox(height: 16),

            // Submit Repair Request
            _MenuCard(
              gradient: const LinearGradient(
                colors: [Color(0xFF2563EB), Color(0xFF6366F1)],
              ),
              icon: Icons.build_circle_outlined,
              iconColor: Colors.white,
              title: 'Submit Repair Request',
              subtitle:
                  'Fill out a form and we\'ll guide you through basic troubleshooting.',
              titleColor: Colors.white,
              subtitleColor: Colors.white70,
              showShadow: true,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const RepairRequestScreen()),
              ),
            ),
            const SizedBox(height: 12),

            // Repair History
            _MenuCard(
              backgroundColor: Colors.white,
              icon: Icons.history,
              iconColor: const Color(0xFF6366F1),
              title: 'Repair History',
              subtitle: 'View your completed repairs and service records.',
              titleColor: const Color(0xFF111827),
              subtitleColor: const Color(0xFF6B7280),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const RepairHistoryScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusDot(String? status) {
    Color color;
    switch (status) {
      case 'Pending':
        color = const Color(0xFFF59E0B);
        break;
      case 'Accepted':
        color = const Color(0xFF3B82F6);
        break;
      case 'In Home':
      case 'In Shop':
        color = const Color(0xFF8B5CF6);
        break;
      case 'In Process':
        color = const Color(0xFFEC4899);
        break;
      case 'Waiting for Parts':
        color = const Color(0xFFEF4444);
        break;
      case 'Declined':
        color = const Color(0xFFDC2626);
        break;
      default:
        color = const Color(0xFF6B7280);
    }
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final Gradient? gradient;
  final Color? backgroundColor;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Color titleColor;
  final Color subtitleColor;
  final bool showShadow;
  final VoidCallback onTap;

  const _MenuCard({
    this.gradient,
    this.backgroundColor,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.titleColor,
    required this.subtitleColor,
    this.showShadow = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: gradient,
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: gradient == null
              ? Border.all(color: const Color(0xFFE5E7EB))
              : null,
          boxShadow: showShadow
              ? [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 40),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: titleColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style:
                          TextStyle(color: subtitleColor, fontSize: 13)),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: gradient != null
                    ? Colors.white
                    : const Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }
}