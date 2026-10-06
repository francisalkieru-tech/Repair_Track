import 'package:flutter/material.dart';
import '../utils/colors.dart';
import '../utils/constants.dart';

/// One color per status so every technician screen looks the same.
Color techStatusColor(String status) {
  switch (status) {
    case 'Accepted':
    case 'Tech Visit':
    case 'On-Site':
    case 'In Home': // old value, until migrated
    case 'In Shop': // old value, until migrated
      return AppColors.accepted;
    case 'Queued':
      return AppColors.pending;
    case 'Waiting for Parts':
      return AppColors.waitingParts;
    case 'Pending Review':
    case 'Completed':
      return AppColors.completed;
    default:
      // In Process and anything else
      return AppColors.inProcess;
  }
}

/// Darker shade of the status color, readable on its light tinted badge.
Color techStatusTextColor(String status) {
  final hsl = HSLColor.fromColor(techStatusColor(status));
  return hsl.withLightness((hsl.lightness * 0.6).clamp(0.0, 1.0)).toColor();
}

/// Small pill badge: dot + status label.
/// [solid] = filled with the status color and white text (for dark headers).
class TechStatusBadge extends StatelessWidget {
  final String status;
  final bool solid;

  const TechStatusBadge({super.key, required this.status, this.solid = false});

  @override
  Widget build(BuildContext context) {
    final color = techStatusColor(status);
    final textColor = solid ? Colors.white : techStatusTextColor(status);

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: solid ? 14 : 10, vertical: solid ? 7 : 5),
      decoration: BoxDecoration(
        color: solid ? color : color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: solid ? Colors.white : color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            AppConstants.displayLabel(status),
            style: TextStyle(
              fontSize: solid ? AppColors.fontLabel : AppColors.fontCaption,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared job card for the technician Pending and Current tabs.
/// Pass a [footer] for the tab-specific action (button or hint).
class TechJobCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;
  final Widget? footer;

  const TechJobCard({
    super.key,
    required this.data,
    required this.onTap,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final status = data['status'] as String? ?? 'Pending';
    final appliance = data['applianceType'] as String? ?? 'Appliance';
    final trackingId = data['trackingId'] as String? ?? '';
    final problem = data['problemDescription'] as String? ?? '';
    final customer = data['name'] as String? ?? '';
    final address = data['address'] as String? ?? '';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
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
              // Row 1: appliance + status badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      appliance,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: AppColors.fontSubtitle + 2,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TechStatusBadge(status: status),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'ID: $trackingId',
                style: const TextStyle(
                    fontSize: AppColors.fontCaption,
                    color: AppColors.textGray),
              ),

              // Row 2: customer + location
              if (customer.isNotEmpty || address.isNotEmpty) ...[
                const SizedBox(height: 12),
                if (customer.isNotEmpty)
                  _metaRow(Icons.person_outline, customer),
                if (address.isNotEmpty) ...[
                  if (customer.isNotEmpty) const SizedBox(height: 6),
                  _metaRow(Icons.location_on_outlined, address),
                ],
              ],

              // Row 3: problem
              if (problem.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    problem,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: AppColors.fontLabel,
                        height: 1.35,
                        color: Color(0xFF374151)),
                  ),
                ),
              ],

              if (footer != null) ...[
                const SizedBox(height: 14),
                footer!,
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _metaRow(IconData icon, String text) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textGray),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: AppColors.fontLabel,
                  color: AppColors.textDark),
            ),
          ),
        ],
      );
}
