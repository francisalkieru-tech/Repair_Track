import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Service History Screen — accessible via QR scan o deep link,
/// kahit walang login (public). Ipinapakita ang buong service record
/// ng isang COMPLETED repair: repair info, parts used, technician,
/// status history with dates, at lahat ng photos.
///
/// Para sa non-Completed records, ginagamit pa rin ang TrackingScreen
/// (para makita ng customer ang ongoing progress nila).
class ServiceHistoryScreen extends StatelessWidget {
  final String trackingId;

  const ServiceHistoryScreen({super.key, required this.trackingId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        title: const Text('Service History'),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
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
          return _buildContent(data);
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
              'Service Record Not Found',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827)),
            ),
            const SizedBox(height: 8),
            Text(
              'No service record found for tracking ID: $trackingId',
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(Map<String, dynamic> data) {
    final statusHistory =
        (data['statusHistory'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
    final completedEntry = statusHistory.lastWhere(
      (e) => e['status'] == 'Completed',
      orElse: () => <String, dynamic>{},
    );
    final completedAt = completedEntry['timestamp'] as Timestamp?;
    final createdAt = data['createdAt'] as Timestamp?;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF166534), Color(0xFF16A34A)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.verified, color: Colors.white70, size: 16),
                    SizedBox(width: 6),
                    Text('Service Completed',
                        style:
                            TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  trackingId,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  data['applianceType'] ?? '',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 15),
                ),
                if (completedAt != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Completed: ${_formatDate(completedAt.toDate())}',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Customer & Repair Info
          _buildSection(
            title: 'Customer & Repair Info',
            icon: Icons.person_outline,
            child: Column(
              children: [
                _buildRow('Customer', data['name'] ?? ''),
                _buildRow('Contact', data['contactNumber'] ?? ''),
                _buildRow('Address', data['address'] ?? ''),
                _buildRow('Appliance', data['applianceType'] ?? ''),
                _buildRow('Problem', data['problemDescription'] ?? ''),
                if (createdAt != null)
                  _buildRow(
                      'Date Filed', _formatDate(createdAt.toDate())),
                if (completedAt != null)
                  _buildRow('Date Completed',
                      _formatDate(completedAt.toDate())),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Customer submitted photo
          if (data['initialPhotoUrl'] != null &&
              (data['initialPhotoUrl'] as String).isNotEmpty) ...[
            _buildSection(
              title: 'Before Photo (Customer Submitted)',
              icon: Icons.photo_camera_outlined,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  data['initialPhotoUrl'],
                  width: double.infinity,
                  height: 180,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      height: 180,
                      alignment: Alignment.center,
                      child:
                          const CircularProgressIndicator(strokeWidth: 2),
                    );
                  },
                  errorBuilder: (_, __, ___) => Container(
                    height: 80,
                    alignment: Alignment.center,
                    color: const Color(0xFFF3F4F6),
                    child: const Text('Failed to load photo',
                        style: TextStyle(
                            fontSize: 12, color: Color(0xFF6B7280))),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Assigned Technician
          if (data['assignedTechnician'] != null &&
              (data['assignedTechnician'] as String).isNotEmpty) ...[
            _buildSection(
              title: 'Assigned Technician',
              icon: Icons.engineering_outlined,
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 18,
                    backgroundColor: Color(0xFFDBEAFE),
                    child: Icon(Icons.person,
                        color: Color(0xFF1E40AF), size: 18),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    data['assignedTechnician'],
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Parts used (from latest Waiting for Parts or In Process entry)
          () {
            final partsEntry = statusHistory.lastWhere(
              (e) =>
                  e['partsSource'] != null &&
                  (e['partsSource'] as String).isNotEmpty,
              orElse: () => <String, dynamic>{},
            );
            if (partsEntry.isEmpty) return const SizedBox.shrink();
            return Column(
              children: [
                _buildSection(
                  title: 'Parts Information',
                  icon: Icons.build_outlined,
                  child: _buildRow(
                      'Source', partsEntry['partsSource'] ?? ''),
                ),
                const SizedBox(height: 16),
              ],
            );
          }(),

          // Full Service History (all status entries with timestamps)
          _buildSection(
            title: 'Service History Log',
            icon: Icons.history,
            child: statusHistory.isEmpty
                ? const Text(
                    'No history entries yet.',
                    style:
                        TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                  )
                : Column(
                    children: statusHistory.asMap().entries.map((entry) {
                      final i = entry.key;
                      final item = entry.value;
                      final ts = item['timestamp'] as Timestamp?;
                      final note = item['note'] as String? ?? '';
                      final statusLabel = item['status'] as String? ?? '';
                      final tech = item['technician'] as String?;
                      final photoUrl = item['photoUrl'] as String?;
                      final hasPhoto =
                          photoUrl != null && photoUrl.isNotEmpty;
                      final isLast = i == statusHistory.length - 1;

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Timeline dot + line
                          Column(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: statusLabel == 'Completed'
                                      ? const Color(0xFF166534)
                                      : const Color(0xFF2563EB),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check,
                                    color: Colors.white, size: 14),
                              ),
                              if (!isLast)
                                Container(
                                  width: 2,
                                  height: 60 + (hasPhoto ? 180 : 0),
                                  color: const Color(0xFFE5E7EB),
                                ),
                            ],
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                  top: 4, bottom: isLast ? 0 : 16),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    statusLabel,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                  if (ts != null)
                                    Text(
                                      _formatDate(ts.toDate()),
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF9CA3AF)),
                                    ),
                                  if (tech != null &&
                                      tech.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Tech: $tech',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF6B7280)),
                                    ),
                                  ],
                                  if (note.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      note,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF374151)),
                                    ),
                                  ],
                                  if (hasPhoto) ...[
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(8),
                                      child: Image.network(
                                        photoUrl,
                                        width: double.infinity,
                                        height: 160,
                                        fit: BoxFit.cover,
                                        loadingBuilder:
                                            (context, child, progress) {
                                          if (progress == null)
                                            return child;
                                          return Container(
                                            height: 160,
                                            alignment: Alignment.center,
                                            child:
                                                const CircularProgressIndicator(
                                                    strokeWidth: 2),
                                          );
                                        },
                                        errorBuilder:
                                            (_, __, ___) => Container(
                                          height: 60,
                                          alignment: Alignment.center,
                                          color: const Color(0xFFF3F4F6),
                                          child: const Text(
                                              'Failed to load photo',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color:
                                                      Color(0xFF6B7280))),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 32),

          // Footer watermark
          Center(
            child: Column(
              children: [
                const Icon(Icons.verified_outlined,
                    color: Color(0xFF9CA3AF), size: 20),
                const SizedBox(height: 4),
                const Text(
                  'This is an official service record from RepairTrack.',
                  style:
                      TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                  textAlign: TextAlign.center,
                ),
                Text(
                  'Tracking ID: $trackingId',
                  style: const TextStyle(
                      fontSize: 10, color: Color(0xFFD1D5DB)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: const Color(0xFF2563EB)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
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

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} ${hour}:${minute} $period';
  }
}