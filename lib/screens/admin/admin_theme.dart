import 'package:flutter/material.dart';


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
    case 'In Home':
    case 'In Shop':
      return (const Color(0xFFEDE9FE), const Color(0xFF5B21B6));
    case 'In Process':
      return (const Color(0xFFFCE7F3), const Color(0xFF9D174D));
    case 'Waiting for Parts':
      return (const Color(0xFFFEE2E2), const Color(0xFF991B1B));
    case 'Completed':
      return (const Color(0xFFDCFCE7), const Color(0xFF166534));
    case 'Declined':
      return (const Color(0xFFFEE2E2), const Color(0xFF7F1D1D));
    default:
      return (const Color(0xFFF3F4F6), const Color(0xFF374151));
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

/// Shared top bar used above every admin page (shows the page title and
/// today's date).
class AdminTopBar extends StatelessWidget {
  final String title;
  const AdminTopBar({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    const months = [
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
    final dateStr =
        '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day} ${now.year}';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: kAdminCardBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: kAdminTextDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Updated $dateStr',
                  style: const TextStyle(fontSize: 12, color: kAdminTextGray),
                ),
              ],
            ),
          ),
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFFF3F4F6),
            child: const Icon(Icons.person, color: kAdminBrand, size: 18),
          ),
        ],
      ),
    );
  }
}