import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/constants.dart';
import '../../widget/notification_bell.dart';

const Color kAdminBrand = Colors.black;
const Color kAdminBg = Color(0xFFEFEFEF);
const Color kAdminCardBorder = Color(0xFFE5E5E5);
const Color kAdminTextDark = Color(0xFF111111);
const Color kAdminTextGray = Color(0xFF6B7280);

(Color, Color) statusColors(String status) {
  switch (status) {
    case 'Pending':
      return (const Color(0xFFFEF3C7), const Color(0xFF92400E));
    case 'Accepted':
      return (const Color(0xFFDBEAFE), const Color(0xFF1E40AF));
    case 'Tech Visit':
    case 'On-Site':
    case 'In Home': // old value, until migrated
    case 'In Shop': // old value, until migrated
      return (const Color(0xFFEDE9FE), const Color(0xFF5B21B6));
    case 'Queued':
      return (const Color(0xFFF3F4F6), const Color(0xFF4B5563));
    case 'In Process':
      return (const Color(0xFFFCE7F3), const Color(0xFF9D174D));
    case 'Waiting for Parts':
      return (const Color(0xFFFEE2E2), const Color(0xFF991B1B));
    case 'Pending Review':
      return (const Color(0xFFE0F2FE), const Color(0xFF075985));
    case 'Completed':
      return (const Color(0xFFDCFCE7), const Color(0xFF166534));
    case 'Declined':
      return (const Color(0xFFFEE2E2), const Color(0xFF7F1D1D));
    default:
      return (const Color(0xFFF3F4F6), const Color(0xFF374151));
  }
}

/// Monochrome ticket-stage badge used in the dashboard lists:
/// Open / In-Process / Waiting for Parts / Completed (+ Declined).
/// Pass the stored status; it is converted with AppConstants.ticketStage.
class TicketBadge extends StatelessWidget {
  final String status;

  const TicketBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final stage = AppConstants.ticketStage(status);

    Color bg;
    Color fg;
    Color border;
    switch (stage) {
      case AppConstants.stageOpen: // outlined
        bg = Colors.white;
        fg = Colors.black;
        border = Colors.black;
        break;
      case AppConstants.stageInProcess: // solid black
        bg = Colors.black;
        fg = Colors.white;
        border = Colors.black;
        break;
      case AppConstants.stageWaitingParts: // solid gray
        bg = const Color(0xFF6B6B6B);
        fg = Colors.white;
        border = const Color(0xFF6B6B6B);
        break;
      case AppConstants.stageCompleted: // light gray
        bg = const Color(0xFFE5E5E5);
        fg = const Color(0xFF333333);
        border = const Color(0xFFBDBDBD);
        break;
      default: // Declined
        bg = Colors.white;
        fg = const Color(0xFF777777);
        border = const Color(0xFFBDBDBD);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Text(
        stage,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

/// Reusable stat card — used on the Dashboard/Overview page and the
/// Schedule page.
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kAdminCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 13, color: kAdminTextGray),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: kAdminTextDark,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared top bar used above every admin page. 
class AdminTopBar extends StatefulWidget {
  final String title;
  final VoidCallback? onAvatarTap;
  // Opens the page for a request tapped in the notification list.
  final void Function(String status)? onOpenRequest;

  const AdminTopBar({
    super.key,
    required this.title,
    this.onAvatarTap,
    this.onOpenRequest,
  });

  @override
  State<AdminTopBar> createState() => _AdminTopBarState();
}

class _AdminTopBarState extends State<AdminTopBar> {
  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Tick every second so the clock next to the date stays live.
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  static const _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];

  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December'
  ];

  String _dateStr(bool compact) => compact
      ? '${_days[_now.weekday - 1].substring(0, 3)}, '
          '${_months[_now.month - 1].substring(0, 3)} ${_now.day}'
      : '${_days[_now.weekday - 1]}, ${_months[_now.month - 1]} ${_now.day}, ${_now.year}';

  String _timeStr(bool compact) {
    final hour = _now.hour % 12 == 0 ? 12 : _now.hour % 12;
    final minute = _now.minute.toString().padLeft(2, '0');
    final second = _now.second.toString().padLeft(2, '0');
    final ampm = _now.hour >= 12 ? 'PM' : 'AM';
    return compact ? '$hour:$minute $ampm' : '$hour:$minute:$second $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < 600;
    return Container(
      padding: compact
          ? const EdgeInsets.fromLTRB(14, 10, 10, 10)
          : const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: kAdminCardBorder)),
      ),
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('shopSettings')
            .doc('config')
            .snapshots(),
        builder: (context, snapshot) {
          String shopName = '';
          String? logoUrl;

          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>?;
            shopName = data?['shopName'] ?? '';
            logoUrl = data?['logoUrl'] as String?;
          }

          final greeting = shopName.isEmpty
              ? 'Welcome back!'
              : 'Welcome back, $shopName!';

          return Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 16 : 20,
                        fontWeight: FontWeight.bold,
                        color: kAdminTextDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          _dateStr(compact),
                          style: const TextStyle(
                            fontSize: 12,
                            color: kAdminTextGray,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            '•',
                            style: TextStyle(
                              fontSize: 12,
                              color: kAdminTextGray,
                            ),
                          ),
                        ),
                        Flexible(
                          child: Text(
                            _timeStr(compact),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: kAdminTextGray,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              NotificationBell(
                recipientType: 'admin',
                onOpenRequest: widget.onOpenRequest,
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: widget.onAvatarTap,
                customBorder: const CircleBorder(),
                child: CircleAvatar(
                  radius: compact ? 17 : 20,
                  backgroundColor: const Color(0xFFF3F4F6),
                  backgroundImage:
                      (logoUrl != null && logoUrl.isNotEmpty)
                          ? NetworkImage(logoUrl)
                          : null,
                  child: (logoUrl == null || logoUrl.isEmpty)
                      ? const Icon(Icons.store_rounded,
                          color: kAdminBrand, size: 18)
                      : null,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}