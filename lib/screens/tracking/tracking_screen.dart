import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TrackingScreen extends StatelessWidget {
  final String trackingId;
  const TrackingScreen({super.key, required this.trackingId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        title: const Text('Track Repair'),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
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
                  color: Color(0xFF111827)),
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
      'Completed',
    ];
    final currentIndex = allStatuses.indexOf(status);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tracking ID header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2563EB), Color(0xFF6366F1)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tracking ID',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  trackingId,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildStatusBadge(status),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Repair Info Card
          _buildInfoCard(data),
          const SizedBox(height: 20),

          // Status Timeline
          const Text(
            'Repair Progress',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827)),
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: List.generate(allStatuses.length, (index) {
                final isCompleted = index <= currentIndex;
                final isCurrent = index == currentIndex;
                final isLast = index == allStatuses.length - 1;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Timeline indicator
                    Column(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: isCompleted
                                ? const Color(0xFF2563EB)
                                : const Color(0xFFE5E7EB),
                            shape: BoxShape.circle,
                            border: isCurrent
                                ? Border.all(
                                    color: const Color(0xFF2563EB), width: 3)
                                : null,
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
                            height: 36,
                            color: isCompleted && index < currentIndex
                                ? const Color(0xFF2563EB)
                                : const Color(0xFFE5E7EB),
                          ),
                      ],
                    ),
                    const SizedBox(width: 16),

                    // Status label
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 36),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              allStatuses[index],
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isCurrent
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: isCompleted
                                    ? const Color(0xFF111827)
                                    : const Color(0xFF9CA3AF),
                              ),
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
                    ),
                  ],
                );
              }),
            ),
          ),
          const SizedBox(height: 20),

          // Notes from admin (latest entry sa statusHistory, kung meron)
          if (data['statusHistory'] != null &&
              (data['statusHistory'] as List).isNotEmpty)
            _buildNotesCard(
              (data['statusHistory'] as List).last as Map<String, dynamic>,
            ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(Map<String, dynamic> data) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Repair Details',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827)),
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
              'Submitted Photo',
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
                  color: Color(0xFF111827)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesCard(Map<String, dynamic> latestEntry) {
    final note = latestEntry['note'] as String? ?? '';
    final partsSource = latestEntry['partsSource'] as String?;
    final photoUrl = latestEntry['photoUrl'] as String?;
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;

    if (note.isEmpty && !hasPhoto) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.note_outlined,
                  color: Color(0xFFD97706), size: 18),
              SizedBox(width: 8),
              Text(
                'Notes from Technician',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF92400E)),
              ),
            ],
          ),
          if (hasPhoto) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                photoUrl,
                width: double.infinity,
                height: 180,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    height: 180,
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  );
                },
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 100,
                  alignment: Alignment.center,
                  color: const Color(0xFFFEF3C7),
                  child: const Text(
                    'Failed to load photo',
                    style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                  ),
                ),
              ),
            ),
          ],
          if (note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              note,
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF78350F)),
            ),
          ],
          if (partsSource != null && partsSource.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Parts: $partsSource',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF92400E)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;

    switch (status) {
      case 'Pending':
        bgColor = const Color(0xFFFEF3C7);
        textColor = const Color(0xFF92400E);
        break;
      case 'Accepted':
        bgColor = const Color(0xFFDBEAFE);
        textColor = const Color(0xFF1E40AF);
        break;
      case 'In Home':
      case 'In Shop':
        bgColor = const Color(0xFFEDE9FE);
        textColor = const Color(0xFF5B21B6);
        break;
      case 'In Process':
        bgColor = const Color(0xFFFCE7F3);
        textColor = const Color(0xFF9D174D);
        break;
      case 'Waiting for Parts':
        bgColor = const Color(0xFFFEE2E2);
        textColor = const Color(0xFF991B1B);
        break;
      case 'Completed':
        bgColor = const Color(0xFFDCFCE7);
        textColor = const Color(0xFF166534);
        break;
      default:
        bgColor = const Color(0xFFF3F4F6);
        textColor = const Color(0xFF374151);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: textColor),
      ),
    );
  }
}