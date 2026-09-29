import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/auth_service.dart';
import 'repair_request_screen.dart';
import 'repair_history_screen.dart';
import '../../utils/colors.dart';
import '../../utils/ui_widgets.dart';
import '../../widget/notification_bell.dart';

const String _kShopSmsNumber = '+639273919370';
const String _kShopFacebookUrl = 'https://www.facebook.com/share/19L7Qf7xzh/';

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
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.dark,
          onRefresh: () async {
            await Future.delayed(const Duration(milliseconds: 600));
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting header — dark card gaya ng mockup
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppColors.darkGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hi, "${user?.email ?? 'Customer'}"',
                            style: const TextStyle(
                              fontSize: AppColors.fontTitle,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Welcome to the RepairTrack',
                            style: TextStyle(
                              fontSize: AppColors.fontLabel,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    NotificationBell(
                      recipientType: 'customer',
                      recipientId: uid,
                      iconColor: Colors.white,
                    ),
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white54, width: 1.5),
                      ),
                      child: const Icon(Icons.person,
                          color: Colors.white, size: 26),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'Your Repair Summary:',
                style: TextStyle(
                  fontSize: AppColors.fontBody,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 12),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('repairRequests')
                    .where('customerId', isEqualTo: uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Row(
                      children: [
                        Expanded(child: _SummaryStatCardLoading()),
                        SizedBox(width: 10),
                        Expanded(child: _SummaryStatCardLoading()),
                        SizedBox(width: 10),
                        Expanded(child: _SummaryStatCardLoading()),
                      ],
                    );
                  }

                  // Error state — user-friendly message, hindi raw
                  // Firestore exception.
                  if (snapshot.hasError) {
                    return AppErrorState(
                      message: friendlyErrorMessage(snapshot.error),
                    );
                  }
                  final docs = snapshot.data?.docs ?? [];

                  int inProcess = 0;
                  int complete = 0;

                  for (final doc in docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final status = data['status'];
                    if (status == 'Completed') {
                      complete++;
                    } else if (status != 'Declined') {
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
                  fontSize: AppColors.fontTitle,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 16),

              // Submit Repair Request
              _MenuCard(
                backgroundColor: Colors.black,
                icon: Icons.build_circle_outlined,
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
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('repairRequests')
                    .where('customerId', isEqualTo: uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const _MenuCard(
                      backgroundColor: Color(0xFF6B7280),
                      icon: Icons.access_time,
                      iconColor: Colors.white,
                      title: 'Active Repair (...)',
                      subtitle: 'Loading your repair progress...',
                      titleColor: Colors.white,
                      subtitleColor: Colors.white70,
                      onTap: null,
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];
                  final activeCount = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final status = data['status'];
                    return status != 'Completed' && status != 'Declined';
                  }).length;

                  return _MenuCard(
                    backgroundColor: const Color(0xFF6B7280),
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

              // Repair History
              _MenuCard(
                backgroundColor: const Color(0xFF9CA3AF),
                icon: Icons.assignment_turned_in_outlined,
                iconColor: Colors.white,
                title: 'Repair History',
                subtitle: 'View your completed repairs and service record.',
                titleColor: Colors.white,
                subtitleColor: Colors.white70,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const RepairHistoryScreen()),
                ),
              ),
              const SizedBox(height: 20),

              // Need help? — support link/footer
              Center(
                child: GestureDetector(
                  onTap: () => _showHelpSheet(context),
                  child: const Text(
                    'Need Help?',
                    style: TextStyle(
                      fontSize: AppColors.fontLabel,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }

  void _showHelpSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
          child: SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                    'Need help?',
                    style: TextStyle(
                      fontSize: AppColors.fontTitle,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Reach out to us through any of these options.',
                    style: TextStyle(
                      fontSize: AppColors.fontLabel,
                      color: AppColors.textGray,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Option 1: Message via SMS
                  _HelpOptionTile(
                    icon: Icons.sms_outlined,
                    label: 'Message via SMS',
                    subtitle: _kShopSmsNumber,
                    onTap: () async {
                      Navigator.pop(context);
                      await _launchSms(context, _kShopSmsNumber);
                    },
                  ),
                  const SizedBox(height: 10),

                  // Option 2: Visit Facebook Page
                  _HelpOptionTile(
                    icon: Icons.facebook_outlined,
                    label: 'Visit our Facebook Page',
                    subtitle: 'Message us on Facebook',
                    onTap: () async {
                      Navigator.pop(context);
                      await _launchFacebook(context, _kShopFacebookUrl);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _launchSms(BuildContext context, String number) async {
    final uri = Uri(scheme: 'sms', path: number);
    final launched = await launchUrl(uri);
    if (!launched && context.mounted) {
      _showLaunchError(context, 'Hindi mabuksan ang SMS app.');
    }
  }

  Future<void> _launchFacebook(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      _showLaunchError(context, 'Hindi mabuksan ang Facebook.');
    }
  }

  void _showLaunchError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

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
          border: Border.all(color: const Color(0xFF111827), width: 1.2),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: AppColors.fontCaption,
                fontWeight: FontWeight.w600,
                color: AppColors.textGray,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryStatCardLoading extends StatelessWidget {
  const _SummaryStatCardLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1.2),
      ),
      child: const SizedBox(
        height: 44,
        child: Center(
          child: SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
    );
  }
}

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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 36),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: titleColor,
                          fontSize: AppColors.fontBody,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: TextStyle(
                          color: subtitleColor,
                          fontSize: AppColors.fontCaption)),
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
                      fontSize: AppColors.fontLabel,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: AppColors.fontCaption,
                      color: AppColors.textGray,
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