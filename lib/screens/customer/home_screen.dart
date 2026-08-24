import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/auth_service.dart';
import 'repair_request_screen.dart';
import 'repair_history_screen.dart';

// Placeholder shop contact details — replace with the real
// SMS number / Facebook page link when available.
const String _kShopSmsNumber = '+639171234567';
const String _kShopFacebookUrl = 'https://facebook.com/yourrepairshop';

/// Home tab content (first tab of MainNavScreen).
/// Kept separate from the bottom nav shell (see main_nav_screen.dart)
/// so this widget is just the screen body, not the Scaffold + nav bar.
class HomeScreen extends StatefulWidget {
  final VoidCallback? onGoToRepairTab;

  const HomeScreen({
    super.key,
    this.onGoToRepairTab,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting header card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hi, "${user?.email ?? 'Customer Name here'}"',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Welcome to the RepairTrack',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person_outline,
                          color: Colors.black, size: 26),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // "Your Repair Summary" stat row
              const Text(
                'Your Repair Summary:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 12),
              // Live counts from Firestore, scoped to the logged-in customer.
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('repairRequests')
                    .where('customerId', isEqualTo: uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  final docs = snapshot.data?.docs ?? [];

                  int inProcess = 0;
                  int complete = 0;

                  for (final doc in docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final status = data['status'];
                    if (status == 'Completed') {
                      complete++;
                    } else if (status != 'Declined') {
                      // Anything not yet Completed/Declined counts as "In Process".
                      inProcess++;
                    }
                  }

                  final total = docs.length;

                  return Row(
                    children: [
                      Expanded(
                        child: _SummaryStatCard(
                          value: inProcess,
                          label: 'In Process',
                          onTap: widget.onGoToRepairTab,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SummaryStatCard(
                          value: complete,
                          label: 'Complete',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const RepairHistoryScreen()),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SummaryStatCard(
                          value: total,
                          label: 'Total',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const RepairHistoryScreen()),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 28),

              const Text(
                'What do you need?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 16),

              // Submit Repair Request — solid black card (primary action)
              _MenuCard(
                backgroundColor: Colors.black,
                icon: Icons.build_outlined,
                iconColor: Colors.white,
                title: 'Submit Your Repair Request',
                subtitle:
                    'Fill out a form and we\'ll guide you through basic troubleshooting before submitting repair request .',
                titleColor: Colors.white,
                subtitleColor: Colors.white70,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const RepairRequestScreen()),
                ),
              ),
              const SizedBox(height: 12),

              // Active Repair — jumps to the Repair tab; count excludes
              // Completed and Declined requests.
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('repairRequests')
                    .where('customerId', isEqualTo: uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  final docs = snapshot.data?.docs ?? [];
                  final activeCount = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final status = data['status'];
                    return status != 'Completed' && status != 'Declined';
                  }).length;

                  return _MenuCard(
                    backgroundColor: const Color(0xFF4B5563),
                    icon: Icons.access_time,
                    iconColor: Colors.white,
                    title: 'Active Repair ($activeCount)',
                    subtitle: 'Click to view your repair progress',
                    titleColor: Colors.white,
                    subtitleColor: Colors.white70,
                    onTap: widget.onGoToRepairTab,
                  );
                },
              ),
              const SizedBox(height: 12),

              // Repair History — lighter gray card (least emphasized action)
              _MenuCard(
                backgroundColor: const Color(0xFF9CA3AF),
                icon: Icons.description_outlined,
                iconColor: Colors.white,
                title: 'Repair History',
                subtitle: 'View your completed repair and service record.',
                titleColor: Colors.white,
                subtitleColor: Colors.white70,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const RepairHistoryScreen()),
                ),
              ),
              const SizedBox(height: 20),

              // "Need Help?" footer link — opens the support bottom sheet
              Center(
                child: GestureDetector(
                  onTap: () => _showHelpSheet(context),
                  child: const Text(
                    'Need Help?',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2563EB),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Bottom sheet with the two support contact options (SMS / Facebook).
  void _showHelpSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Text(
                  'Need Help?',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Reach out to us through any of these option',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 20),

                // Option 1: message the shop via SMS
                _HelpOptionTile(
                  icon: Icons.sms_outlined,
                  label: 'Message us via SMS',
                  subtitle: _kShopSmsNumber,
                  onTap: () async {
                    Navigator.pop(context);
                    await _launchSms(context, _kShopSmsNumber);
                  },
                ),
                const SizedBox(height: 10),

                // Option 2: open the shop's Facebook page
                _HelpOptionTile(
                  icon: Icons.facebook_outlined,
                  label: 'Visit our Facebook Page',
                  subtitle: 'Message us on facebook',
                  onTap: () async {
                    Navigator.pop(context);
                    await _launchFacebook(context, _kShopFacebookUrl);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Opens the default SMS app pre-filled with the shop number.
  Future<void> _launchSms(BuildContext context, String number) async {
    final uri = Uri(scheme: 'sms', path: number);
    final launched = await launchUrl(uri);
    if (!launched && context.mounted) {
      _showLaunchError(context, 'Could not open the SMS app.');
    }
  }

  // Opens the shop's Facebook page in an external app/browser.
  Future<void> _launchFacebook(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      _showLaunchError(context, 'Could not open Facebook.');
    }
  }

  void _showLaunchError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

/// One stat card in the "Your Repair Summary" row (In Process / Complete / Total).
class _SummaryStatCard extends StatelessWidget {
  final int value;
  final String label;
  final VoidCallback? onTap;

  const _SummaryStatCard({
    required this.value,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black, width: 1.2),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reusable dark menu card used for the 3 "What do you need?" actions.
class _MenuCard extends StatelessWidget {
  final Color? backgroundColor;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Color titleColor;
  final Color subtitleColor;
  final VoidCallback? onTap;

  const _MenuCard({
    this.backgroundColor,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.titleColor,
    required this.subtitleColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 32),
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
                      style: TextStyle(color: subtitleColor, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: titleColor),
          ],
        ),
      ),
    );
  }
}

/// One row inside the "Need Help?" bottom sheet (SMS / Facebook option).
class _HelpOptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _HelpOptionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.black45),
          ],
        ),
      ),
    );
  }
}