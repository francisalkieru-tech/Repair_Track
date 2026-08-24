import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// "Repair Tracking Detail" — shows one repair request's full status
/// timeline, technician notes per step, and submitted photo. Reached
/// from a tap on any request row (My Repair list or Repair History).
class TrackingScreen extends StatelessWidget {
  final String trackingId;
  const TrackingScreen({super.key, required this.trackingId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        title: const Text('Track Repair'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('repairRequests')
            .where('trackingId', isEqualTo: trackingId)
            .limit(1)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildNotFound();
          }

          final data =
              snapshot.data!.docs.first.data() as Map<String, dynamic>;
          return _buildTrackingContent(data);
        },
      ),
    );
  }

  // Empty state shown when no request matches this tracking ID.
  Widget _buildNotFound() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              'Tracking ID not found',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black),
            ),
            const SizedBox(height: 8),
            Text(
              'No repair request found for tracking ID: $trackingId',
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackingContent(Map<String, dynamic> data) {
    final status = data['status'] ?? 'Pending';
    final allStatuses = [
      'Pending',
      'Accepted',
      'In Home',
      'In Shop',
      'In Process',
      'Waiting for Parts',
      'Complete',
    ];
    // Firestore stores the final status as 'Completed'; the timeline
    // label uses 'Complete' to match the mockup, so map it here.
    final normalizedStatus = status == 'Completed' ? 'Complete' : status;
    final currentIndex = allStatuses.indexOf(normalizedStatus);

    // Per-step notes/dates keyed by status label, pulled from statusHistory.
    final stepInfo = _buildStepInfo(data);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tracking ID header card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF9CA3AF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tracking ID:',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  trackingId,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2),
                ),
                const SizedBox(height: 12),
                _buildStatusBadge(normalizedStatus),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Repair details card (name, contact, address, appliance, problem, photo)
          _buildInfoCard(data),
          const SizedBox(height: 20),

          const Text(
            'Repair Status:',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.black),
          ),
          const SizedBox(height: 12),

          // Vertical timeline: one row per status, each with an optional note.
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB), width: 1.2),
            ),
            child: Column(
              children: List.generate(allStatuses.length, (index) {
                final isCompleted = index <= currentIndex;
                final isCurrent = index == currentIndex;
                final isLast = index == allStatuses.length - 1;
                final info = stepInfo[allStatuses[index]];

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Step indicator: check circle if reached, number if not.
                    Column(
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: isCompleted
                                ? const Color(0xFF2563EB)
                                : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isCompleted
                                  ? const Color(0xFF2563EB)
                                  : const Color(0xFFD1D5DB),
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: isCompleted
                                ? const Icon(Icons.check,
                                    color: Colors.white, size: 14)
                                : Text(
                                    '${index + 1}',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF9CA3AF),
                                        fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ),
                        if (!isLast)
                          Container(
                            width: 2,
                            height: 40,
                            color: index < currentIndex
                                ? const Color(0xFF2563EB)
                                : const Color(0xFFE5E7EB),
                          ),
                      ],
                    ),
                    const SizedBox(width: 16),

                    // Step label + date/note + "Current status" tag
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 32),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    allStatuses[index],
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isCurrent
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                      color: isCompleted
                                          ? Colors.black
                                          : const Color(0xFF9CA3AF),
                                    ),
                                  ),
                                  if (info?.date != null)
                                    Text(
                                      info!.date!,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF9CA3AF)),
                                    ),
                                  if (isCurrent)
                                    const Text(
                                      'Current status',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF2563EB)),
                                    ),
                                ],
                              ),
                            ),
                            // Right-aligned note label for this step
                            Text(
                              info?.note ?? 'Note:',
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFF9CA3AF)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // Builds a lookup of status -> {date, note} from the request's
  // statusHistory entries, so each timeline row can show its own note.
  Map<String, _StepInfo> _buildStepInfo(Map<String, dynamic> data) {
    final result = <String, _StepInfo>{};
    final history = data['statusHistory'] as List<dynamic>? ?? [];

    for (final entry in history) {
      final map = entry as Map<String, dynamic>;
      final status = map['status'] as String? ?? '';
      final label = status == 'Completed' ? 'Complete' : status;
      final timestamp = map['timestamp'] as Timestamp?;
      final note = map['note'] as String?;

      result[label] = _StepInfo(
        date: timestamp != null
            ? '${timestamp.toDate().month}/${timestamp.toDate().day}/${timestamp.toDate().year.toString().substring(2)}'
            : null,
        note: (note != null && note.isNotEmpty) ? note : null,
      );
    }

    return result;
  }

  Widget _buildInfoCard(Map<String, dynamic> data) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Repair Details:',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.black),
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.person_outline, 'Name', data['name'] ?? ''),
          _buildInfoRow(
              Icons.phone_outlined, 'Contact', data['contactNumber'] ?? ''),
          _buildInfoRow(
              Icons.location_on_outlined, 'Address', data['address'] ?? ''),
          _buildInfoRow(
              Icons.kitchen, 'Appliance', data['applianceType'] ?? ''),
          _buildInfoRow(Icons.description_outlined, 'Problem',
              data['problemDescription'] ?? ''),
          if (data['initialPhotoUrl'] != null &&
              (data['initialPhotoUrl'] as String).isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'Submitted Photo:',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                data['initialPhotoUrl'],
                width: double.infinity,
                height: 160,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    height: 160,
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  );
                },
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 100,
                  alignment: Alignment.center,
                  color: const Color(0xFFF3F4F6),
                  child: const Text(
                    'Failed to load photo',
                    style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF6B7280)),
          const SizedBox(width: 8),
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF6B7280)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;

    switch (status) {
      case 'Pending':
        bgColor = Colors.white24;
        textColor = Colors.white;
        break;
      case 'Accepted':
        bgColor = const Color(0xFF16A34A);
        textColor = Colors.white;
        break;
      case 'In Home':
      case 'In Shop':
        bgColor = const Color(0xFF5B21B6);
        textColor = Colors.white;
        break;
      case 'In Process':
        bgColor = const Color(0xFF9D174D);
        textColor = Colors.white;
        break;
      case 'Waiting for Parts':
        bgColor = const Color(0xFF991B1B);
        textColor = Colors.white;
        break;
      case 'Complete':
        bgColor = const Color(0xFF16A34A);
        textColor = Colors.white;
        break;
      default:
        bgColor = Colors.white24;
        textColor = Colors.white;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            status,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textColor),
          ),
        ],
      ),
    );
  }
}

/// Holds the date/note text shown for one step in the status timeline.
class _StepInfo {
  final String? date;
  final String? note;
  const _StepInfo({this.date, this.note});
}