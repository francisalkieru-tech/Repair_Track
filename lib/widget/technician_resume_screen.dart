import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../utils/report_data.dart';
import '../utils/report_pdf.dart';
import '../utils/technician_profile.dart';

/// Resume-style profile of a technician: who they are, what they
/// specialize in, their certificates (NC II etc.) and their work record.
/// Shown to Admin (who can verify certificates) and to the technician
/// themselves (read-only preview).
class TechnicianResumeScreen extends StatelessWidget {
  final String technicianDocId;
  final bool isAdmin;

  const TechnicianResumeScreen({
    super.key,
    required this.technicianDocId,
    this.isAdmin = false,
  });

  DocumentReference<Map<String, dynamic>> get _ref => FirebaseFirestore
      .instance
      .collection('technicians')
      .doc(technicianDocId);

  Future<void> _setVerified(
      Map<String, dynamic> tech, int index, bool verified) async {
    final certs = technicianCertifications(tech);
    certs[index] = certs[index].copyWith(verified: verified);
    await _ref.update({'certifications': certs.map((c) => c.toMap()).toList()});
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _ref.snapshots(),
      builder: (context, techSnap) {
        final tech = techSnap.data?.data();
        return StreamBuilder<QuerySnapshot>(
          stream: FirestoreService().streamRepairRequests(),
          builder: (context, reqSnap) {
            if (tech == null) {
              return Scaffold(
                appBar: AppBar(title: const Text('Technician Resume')),
                body: Center(
                  child: techSnap.connectionState == ConnectionState.waiting
                      ? const CircularProgressIndicator()
                      : const Text('Technician not found.'),
                ),
              );
            }
            final resume = buildTechnicianResume(
              docId: technicianDocId,
              technician: tech,
              allRequests: (reqSnap.data?.docs ?? [])
                  .map((d) => d.data() as Map<String, dynamic>)
                  .toList(),
            );
            return _build(context, tech, resume);
          },
        );
      },
    );
  }

  Widget _build(
      BuildContext context, Map<String, dynamic> tech, TechnicianResume r) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0,
        title: const Text('Technician Resume'),
        actions: [
          TextButton.icon(
            onPressed: () => downloadTechnicianResume(r),
            icon: const Icon(Icons.download_outlined, size: 18),
            label: const Text('Download PDF'),
          ),
          TextButton.icon(
            onPressed: () => printTechnicianResume(r),
            icon: const Icon(Icons.print_outlined, size: 18),
            label: const Text('Print'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _headerCard(r),
                if (r.bio.trim().isNotEmpty)
                  _card('About', Text(r.bio.trim(),
                      style: const TextStyle(fontSize: 13.5, height: 1.4))),
                _card(
                  'Specializations',
                  r.specializations.isEmpty
                      ? const Text('General repairs',
                          style: TextStyle(color: Color(0xFF6B7280)))
                      : Wrap(spacing: 8, runSpacing: 8, children: [
                          for (final s in r.specializations)
                            Chip(
                              label: Text(s),
                              backgroundColor: const Color(0xFFE0F2FE),
                              labelStyle: const TextStyle(
                                  fontSize: 12.5, color: Color(0xFF075985)),
                            ),
                        ]),
                ),
                _card(
                  'Certifications & Training',
                  r.certifications.isEmpty
                      ? const Text('No certifications listed yet.',
                          style: TextStyle(color: Color(0xFF6B7280)))
                      : Column(children: [
                          for (var i = 0; i < r.certifications.length; i++)
                            _certTile(tech, i, r.certifications[i]),
                        ]),
                ),
                _card(
                  'Work record',
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(spacing: 10, runSpacing: 10, children: [
                        _stat('Repairs completed', '${r.completed}'),
                        _stat('Active jobs', '${r.active}'),
                        _stat('Jobs declined', '${r.declinedByMe}'),
                        _stat(
                            'Avg. repair time',
                            r.averageRepairTime == null
                                ? '-'
                                : formatDuration(r.averageRepairTime!)),
                      ]),
                      if (r.completedByAppliance.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        const Text('Completed by appliance',
                            style: TextStyle(
                                fontSize: 12.5, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        for (final e in (r.completedByAppliance.entries.toList()
                          ..sort((a, b) => b.value.compareTo(a.value))))
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(e.key,
                                    style: const TextStyle(fontSize: 13)),
                                Text('${e.value}',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _headerCard(TechnicianResume r) {
    final initial = r.name.trim().isEmpty ? '?' : r.name.trim()[0].toUpperCase();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: const Color(0xFF111827),
            child: Text(initial,
                style: const TextStyle(
                    fontSize: 26,
                    color: Colors.white,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.name,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  r.specializations.isEmpty
                      ? 'General repairs'
                      : r.specializations.join(' • '),
                  style:
                      const TextStyle(fontSize: 13, color: Color(0xFF4B5563)),
                ),
                const SizedBox(height: 6),
                if (r.phone.isNotEmpty)
                  Text(r.phone,
                      style: const TextStyle(
                          fontSize: 12.5, color: Color(0xFF6B7280))),
                if (r.email.isNotEmpty)
                  Text(r.email,
                      style: const TextStyle(
                          fontSize: 12.5, color: Color(0xFF6B7280))),
                const SizedBox(height: 4),
                Text(
                  [
                    if (r.yearsExperience > 0)
                      '${r.yearsExperience} yr${r.yearsExperience == 1 ? '' : 's'} experience',
                    if (r.certifications.isNotEmpty)
                      '${r.verifiedCertCount}/${r.certifications.length} certificates verified',
                  ].join('  •  '),
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(String title, Widget child) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            child,
          ],
        ),
      );

  Widget _stat(String label, String value) => Container(
        width: 150,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label,
                style:
                    const TextStyle(fontSize: 11.5, color: Color(0xFF6B7280))),
          ],
        ),
      );

  Widget _certTile(Map<String, dynamic> tech, int index, TechCertification c) {
    final (label, bg, fg) = c.isExpired
        ? ('Expired', const Color(0xFFFEE2E2), const Color(0xFF991B1B))
        : c.verified
            ? ('Verified', const Color(0xFFDCFCE7), const Color(0xFF166534))
            : ('Not verified', const Color(0xFFFEF3C7), const Color(0xFF92400E));

    final details = [
      if (c.issuer.isNotEmpty) c.issuer,
      if (c.certNo.isNotEmpty) 'No. ${c.certNo}',
      if (c.issued != null) 'Issued ${formatDate(c.issued!)}',
      if (c.expires != null) 'Valid until ${formatDate(c.expires!)}',
    ].join('  •  ');

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.workspace_premium_outlined, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.title,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w700)),
                if (details.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(details,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF6B7280))),
                  ),
                if (isAdmin)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: OutlinedButton(
                      onPressed: () => _setVerified(tech, index, !c.verified),
                      child: Text(c.verified
                          ? 'Remove verification'
                          : 'Mark as verified'),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
                color: bg, borderRadius: BorderRadius.circular(20)),
            child: Text(label,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
          ),
        ],
      ),
    );
  }
}
