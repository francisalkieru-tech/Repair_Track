import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firestore_service.dart';
import '../../utils/colors.dart';
import '../../widget/tech_chat.dart';
import '../../widget/notification_bell.dart';
import 'technicians_pending.dart';
import 'technicians_current_tab.dart';
import 'technicians_schedule_screen.dart';
import 'techinicians_settings.dart';

class TechnicianMainNav extends StatefulWidget {
  final String? technicianDocId;

  const TechnicianMainNav({super.key, this.technicianDocId});

  @override
  State<TechnicianMainNav> createState() => _TechnicianMainNavState();
}

class _TechnicianMainNavState extends State<TechnicianMainNav> {
  int _currentIndex = 0;

  Timer? _presenceTimer;
  String? _presenceStartedFor;

  Future<String?> _resolveTechnicianDocId(String uid) async {
    if (widget.technicianDocId != null) return widget.technicianDocId;
    final doc = await FirebaseFirestore.instance
        .collection('technicianAuth')
        .doc(uid)
        .get();
    return (doc.data() as Map<String, dynamic>?)?['technicianDocId'];
  }

  void _ensurePresenceHeartbeat(String technicianDocId) {
    if (_presenceStartedFor == technicianDocId) return;
    _presenceTimer?.cancel();
    _presenceStartedFor = technicianDocId;
    FirestoreService().updateTechnicianPresence(technicianDocId);
    _presenceTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => FirestoreService().updateTechnicianPresence(technicianDocId),
    );
  }

  @override
  void dispose() {
    _presenceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Not signed in.')));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FutureBuilder<String?>(
          future: _resolveTechnicianDocId(uid),
          builder: (context, idSnapshot) {
            if (idSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final resolvedId = idSnapshot.data;
            if (resolvedId == null) {
              return const Center(
                  child: Text('Could not find your technician record.'));
            }

            _ensurePresenceHeartbeat(resolvedId);

            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('technicians')
                  .doc(resolvedId)
                  .snapshots(),
              builder: (context, techSnapshot) {
                final techName =
                    techSnapshot.data?.data()?['name'] as String? ??
                        'Technician';

                final tabs = [
                  TechnicianPendingTab(technicianDocId: resolvedId),
                  TechnicianCurrentTab(technicianDocId: resolvedId),
                  TechnicianScheduleTabContent(technicianDocId: resolvedId),
                ];

                return Stack(
                  children: [
                    Column(
                      children: [
                        _GreetingHeader(
                          name: techName,
                          technicianDocId: resolvedId,
                          onSettingsTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TechnicianSettingsScreen(
                                  technicianDocId: resolvedId),
                            ),
                          ),
                        ),
                        Expanded(
                          child:
                              IndexedStack(index: _currentIndex, children: tabs),
                        ),
                      ],
                    ),
                    TechnicianChatBubble(
                      technicianDocId: resolvedId,
                      technicianName: techName,
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.dark,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.pending_actions,
                  label: 'Pending',
                  isSelected: _currentIndex == 0,
                  onTap: () => setState(() => _currentIndex = 0),
                ),
                _NavItem(
                  icon: Icons.build,
                  label: 'Current',
                  isSelected: _currentIndex == 1,
                  onTap: () => setState(() => _currentIndex = 1),
                ),
                _NavItem(
                  icon: Icons.calendar_month,
                  label: 'Schedule',
                  isSelected: _currentIndex == 2,
                  onTap: () => setState(() => _currentIndex = 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GreetingHeader extends StatelessWidget {
  final String name;
  final String technicianDocId;
  final VoidCallback onSettingsTap;

  const _GreetingHeader({
    required this.name,
    required this.technicianDocId,
    required this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 8),
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
                  'Hello Tech. $name',
                  style: const TextStyle(
                    fontSize: AppColors.fontTitle,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Welcome back to RepairTrack, let\'s work together!',
                  style: TextStyle(
                    fontSize: AppColors.fontLabel,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          NotificationBell(
            recipientType: 'technician',
            recipientId: technicianDocId,
            iconColor: Colors.white,
          ),
          IconButton(
            onPressed: onSettingsTap,
            icon: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white54, width: 1.5),
              ),
              child: const Icon(Icons.settings, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? Colors.white : Colors.white54;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: AppColors.fontCaption,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
