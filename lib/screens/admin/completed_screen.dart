import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firestore_service.dart';
import 'admin_theme.dart';
import 'requests_screen.dart' show showQrDialog;

class CompletedScreen extends StatelessWidget {
  const CompletedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();

    return Container(
      color: kAdminBg,
      child: StreamBuilder<QuerySnapshot>(
        stream: firestoreService.streamRepairRequests(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final allDocs = snapshot.data?.docs ?? [];

          final completedDocs = allDocs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            return data['status'] == 'Completed';
          }).toList();

          if (completedDocs.isEmpty) {
            return const Center(
              child: Text(
                'No completed repairs yet.',
                style: TextStyle(color: kAdminTextGray),
              ),
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final crossAxisCount = width >= 1100
                  ? 4
                  : width >= 760
                      ? 3
                      : 2;

              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.7,
                ),
                itemCount: completedDocs.length,
                itemBuilder: (context, index) {
                  final doc = completedDocs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  return _CompletedCard(docId: doc.id, data: data);
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _CompletedCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;

  const _CompletedCard({required this.docId, required this.data});

  @override
  Widget build(BuildContext context) {
    final trackingId = data['trackingId'] ?? '';
    final name = data['name'] ?? '';
    final applianceType = data['applianceType'] ?? '';
    final contactNumber = data['contactNumber'] ?? '';

    return Material(
      color: const Color(0xFFD9D9D9),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showCompletedDetails(context, docId, data),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              //Left: tracking info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Tracking ID:',
                      style:
                          TextStyle(fontSize: 10, color: Color(0xFF555555)),
                    ),
                    Text(
                      trackingId,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        letterSpacing: 1,
                        color: Colors.black,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Name: $name',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF444444)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Appliances: $applianceType',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF444444)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Contact Number: $contactNumber',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF444444)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Status: ',
                          style: TextStyle(
                              fontSize: 10, color: Color(0xFF555555)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFBBF7D0),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Complete',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF166534),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Right: compact "View QR" button 
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => showQrDialog(context, trackingId, name),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.qr_code_2, size: 20, color: Colors.black),
                        SizedBox(height: 2),
                        Text(
                          'View QR',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                      ],
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
}

void _showCompletedDetails(
    BuildContext context, String docId, Map<String, dynamic> data) {
  showDialog(
    context: context,
    builder: (context) => Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 640),
        child: _CompletedDetailsDialog(docId: docId, data: data),
      ),
    ),
  );
}

class _CompletedDetailsDialog extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;

  const _CompletedDetailsDialog({required this.docId, required this.data});

  @override
  Widget build(BuildContext context) {
    final trackingId = data['trackingId'] ?? '';
    final name = data['name'] ?? '';
    final contactNumber = data['contactNumber'] ?? '';
    final address = data['address'] ?? '';
    final applianceType = data['applianceType'] ?? '';
    final problemDescription = data['problemDescription'] ?? '';
    final assignedTechnician = data['assignedTechnician'] as String?;
    final warrantyMonths = data['warrantyMonths'] as int?;
    final warrantyTerms = data['warrantyTerms'] as String?;
    final warrantyExpiresAt = data['warrantyExpiresAt'] as Timestamp?;

    final history = (data['statusHistory'] as List?) ?? [];
    Map<String, dynamic>? lastEntry;
    for (final entry in history) {
      if (entry is Map<String, dynamic> && entry['status'] == 'Completed') {
        lastEntry = entry;
      }
    }
    final completionNote = lastEntry?['note'] as String?;
    final completionPhotoUrl = lastEntry?['photoUrl'] as String?;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFBBF7D0),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Completed',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF166534),
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    customBorder: const CircleBorder(),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close,
                          size: 20, color: Color(0xFF6B7280)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Service Record — $trackingId',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 18),
              _DetailRow(icon: Icons.person_outline, label: 'Customer', value: name),
              _DetailRow(
                  icon: Icons.call_outlined,
                  label: 'Contact Number',
                  value: contactNumber),
              if (address.toString().isNotEmpty)
                _DetailRow(
                    icon: Icons.location_on_outlined,
                    label: 'Location',
                    value: address),
              _DetailRow(
                  icon: Icons.kitchen_outlined,
                  label: 'Appliance',
                  value: applianceType),
              if (problemDescription.toString().isNotEmpty)
                _DetailRow(
                    icon: Icons.description_outlined,
                    label: 'Appliance Problem',
                    value: problemDescription),
              if (assignedTechnician != null && assignedTechnician.isNotEmpty)
                _DetailRow(
                    icon: Icons.engineering_outlined,
                    label: 'Technician',
                    value: assignedTechnician),
              if (completionNote != null && completionNote.trim().isNotEmpty)
                _DetailRow(
                    icon: Icons.notes_outlined,
                    label: 'Completion Notes',
                    value: completionNote),
              if (warrantyMonths != null && warrantyMonths > 0) ...[
                _DetailRow(
                  icon: Icons.verified_outlined,
                  label: 'Warranty',
                  value: '$warrantyMonths Month'
                      '${warrantyMonths > 1 ? 's' : ''}'
                      '${warrantyExpiresAt != null ? ' — until ${_formatDate(warrantyExpiresAt.toDate())}' : ''}',
                ),
                if (warrantyTerms != null && warrantyTerms.trim().isNotEmpty)
                  _DetailRow(
                      icon: Icons.gavel_outlined,
                      label: 'Warranty Terms',
                      value: warrantyTerms),
              ],
              if (completionPhotoUrl != null &&
                  completionPhotoUrl.isNotEmpty) ...[
                const SizedBox(height: 6),
                const Text(
                  'Appliance Photo',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151)),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    completionPhotoUrl,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 160,
                      alignment: Alignment.center,
                      color: const Color(0xFFF3F4F6),
                      child: const Icon(Icons.broken_image_outlined,
                          color: Colors.grey),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF9CA3AF)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF111827),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}