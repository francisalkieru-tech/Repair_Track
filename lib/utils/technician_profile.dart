import 'package:cloud_firestore/cloud_firestore.dart';
import 'constants.dart';
import 'report_data.dart';
import 'technician_availability.dart';

/// Common TESDA qualifications for appliance repair, offered as quick
/// suggestions. The technician can still type any other certificate.
const List<String> kCertificationSuggestions = [
  'Domestic Refrigeration and Air-conditioning Servicing NC II',
  'Consumer Electronics Servicing NC II',
  'Electrical Installation and Maintenance NC II',
];

/// One certificate on a technician's resume (TESDA NC II, brand training...).
class TechCertification {
  final String title;
  final String issuer;
  final String certNo;
  final DateTime? issued;
  final DateTime? expires;

  /// Set by Admin after checking the actual certificate.
  final bool verified;

  const TechCertification({
    required this.title,
    this.issuer = '',
    this.certNo = '',
    this.issued,
    this.expires,
    this.verified = false,
  });

  bool get isExpired =>
      expires != null && expires!.isBefore(DateTime.now());

  TechCertification copyWith({bool? verified}) => TechCertification(
        title: title,
        issuer: issuer,
        certNo: certNo,
        issued: issued,
        expires: expires,
        verified: verified ?? this.verified,
      );

  Map<String, dynamic> toMap() => {
        'title': title,
        'issuer': issuer,
        'certNo': certNo,
        'issued': issued == null ? '' : _iso(issued!),
        'expires': expires == null ? '' : _iso(expires!),
        'verified': verified,
      };

  factory TechCertification.fromMap(Map<dynamic, dynamic> m) =>
      TechCertification(
        title: (m['title'] ?? '').toString(),
        issuer: (m['issuer'] ?? '').toString(),
        certNo: (m['certNo'] ?? '').toString(),
        issued: DateTime.tryParse((m['issued'] ?? '').toString()),
        expires: DateTime.tryParse((m['expires'] ?? '').toString()),
        verified: m['verified'] == true,
      );

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

List<TechCertification> technicianCertifications(Map<String, dynamic> t) {
  final raw = t['certifications'];
  if (raw is! List) return [];
  return raw
      .whereType<Map>()
      .map(TechCertification.fromMap)
      .where((c) => c.title.trim().isNotEmpty)
      .toList();
}

/// Everything shown on a technician's resume.
class TechnicianResume {
  final String name;
  final String email;
  final String phone;
  final String bio;
  final int yearsExperience;
  final List<String> specializations;
  final List<TechCertification> certifications;
  final DateTime? memberSince;

  // Performance, computed from the repair requests.
  final int completed;
  final int active;
  final int declinedByMe;
  final Duration? averageRepairTime;
  final Map<String, int> completedByAppliance;

  const TechnicianResume({
    required this.name,
    required this.email,
    required this.phone,
    required this.bio,
    required this.yearsExperience,
    required this.specializations,
    required this.certifications,
    required this.memberSince,
    required this.completed,
    required this.active,
    required this.declinedByMe,
    required this.averageRepairTime,
    required this.completedByAppliance,
  });

  int get verifiedCertCount => certifications.where((c) => c.verified).length;
}

TechnicianResume buildTechnicianResume({
  required String docId,
  required Map<String, dynamic> technician,
  required List<Map<String, dynamic>> allRequests,
}) {
  final name = (technician['name'] ?? '') as String;
  final jobs = jobsFromDocs(allRequests);

  var completed = 0, active = 0, declined = 0;
  var total = Duration.zero;
  final byAppliance = <String, int>{};

  for (final j in jobs) {
    if (j.technician == name && name.isNotEmpty) {
      if (j.status == AppConstants.statusCompleted) {
        completed++;
        final key = j.appliance.isEmpty ? 'Other' : j.appliance;
        byAppliance[key] = (byAppliance[key] ?? 0) + 1;
        if (j.createdAt != null && j.completedAt != null) {
          total += j.completedAt!.difference(j.createdAt!);
        }
      } else if (!j.isClosed) {
        active++;
      }
    }
    declined += j.techDeclines.where((d) => d.technicianId == docId).length;
  }

  final years = technician['yearsExperience'];
  return TechnicianResume(
    name: name,
    email: (technician['email'] ?? '') as String,
    phone: (technician['phoneNumber'] ?? '') as String,
    bio: (technician['bio'] ?? '') as String,
    yearsExperience: years is num ? years.toInt() : 0,
    specializations: technicianSpecializations(technician),
    certifications: technicianCertifications(technician),
    memberSince: technician['createdAt'] is Timestamp
        ? (technician['createdAt'] as Timestamp).toDate()
        : null,
    completed: completed,
    active: active,
    declinedByMe: declined,
    averageRepairTime: completed == 0 ? null : total ~/ completed,
    completedByAppliance: byAppliance,
  );
}
