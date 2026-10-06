import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/constants.dart';

/// Single source of truth for "is this technician available for a new
/// assignment right now?" Computed live from the current repair
/// requests — not stored on the technician doc — so it can never
/// drift out of sync with the jobs actually assigned.
///
/// Two rules, in order:
/// 1. An active "Tech Visit" job makes the technician unavailable for
///    anything else, regardless of their job count — they're
///    physically at a customer's location.
/// 2. Otherwise, available as long as their active job count is
///    below [kMaxActiveJobsPerTechnician] (bench/in-shop jobs can
///    queue up to that cap).
const int kMaxActiveJobsPerTechnician = 5;

List<Map<String, dynamic>> activeJobsForTechnician(
  List<Map<String, dynamic>> allRepairRequests,
  String technicianName,
) {
  return allRepairRequests.where((r) {
    final status = r['status'];
    return r['assignedTechnician'] == technicianName &&
        status != AppConstants.statusCompleted &&
        status != AppConstants.statusDeclined;
  }).toList();
}

bool isTechnicianAvailable(
  List<Map<String, dynamic>> allRepairRequests,
  String technicianName,
) {
  final activeJobs = activeJobsForTechnician(allRepairRequests, technicianName);

  final hasTechVisitJob =
      activeJobs.any((r) => AppConstants.isTechVisit(r['status'] as String?));
  if (hasTechVisitJob) return false;

  return activeJobs.length < kMaxActiveJobsPerTechnician;
}

// DUTY STATUS + ASSIGNMENT QUEUE

/// Clock-in state, set by the technician's own Clock In / Clock Out button.
/// A technician only counts as "active today" if they clocked in TODAY, so
/// someone who forgot to clock out yesterday is not shown as on duty.
bool isTechnicianClockedIn(Map<String, dynamic> technician) {
  if (technician['dutyStatus'] != AppConstants.dutyOnDuty) return false;
  final since = technician['dutySince'];
  if (since is! Timestamp) return false;
  final d = since.toDate();
  final now = DateTime.now();
  return d.year == now.year && d.month == now.month && d.day == now.day;
}

/// When the technician clocked in today (null if not clocked in).
DateTime? technicianClockedInSince(Map<String, dynamic> technician) =>
    isTechnicianClockedIn(technician)
        ? (technician['dutySince'] as Timestamp).toDate()
        : null;

/// Can this technician take a new job right now? Clocked in today AND not
/// blocked by the job rules above.
bool isTechnicianAssignable(
  List<Map<String, dynamic>> allRepairRequests,
  Map<String, dynamic> technician,
) {
  if (!isTechnicianClockedIn(technician)) return false;
  return isTechnicianAvailable(
    allRepairRequests,
    (technician['name'] ?? '') as String,
  );
}

/// Appliance types this technician is certified / specialized in.
/// Reads the structured `specializations` list; falls back to the old
/// free-text `specialization` field (comma separated) so existing
/// technician records keep working.
List<String> technicianSpecializations(Map<String, dynamic> technician) {
  final list = technician['specializations'];
  if (list is List && list.isNotEmpty) {
    return list.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
  }
  final text = (technician['specialization'] ?? '').toString();
  return text
      .split(RegExp(r'[,/;]'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
}

/// True when the technician specializes in [applianceType].
bool technicianCoversAppliance(
  Map<String, dynamic> technician,
  String? applianceType,
) {
  final want = (applianceType ?? '').trim().toLowerCase();
  if (want.isEmpty) return false;
  return technicianSpecializations(technician).any((s) {
    final have = s.toLowerCase();
    return have == want || have.contains(want) || want.contains(have);
  });
}

/// The system's pick for the next job: the first technician in the queue
/// who can take it. When [applianceType] is given, technicians who
/// specialize in it are preferred (still in fair queue order); if none of
/// them is free, falls back to the first free technician so the job is
/// never stuck. [excludeName] / [excludeNames] skip people (e.g. the
/// technician the job is being reassigned away from, or who declined it).
Map<String, dynamic>? nextTechnicianInQueue(
  List<Map<String, dynamic>> allRepairRequests,
  List<Map<String, dynamic>> technicians, {
  String? excludeName,
  Iterable<String>? excludeNames,
  String? applianceType,
}) {
  final skip = <String>{
    if (excludeName != null) excludeName,
    if (excludeNames != null) ...excludeNames,
  };
  final free = orderTechnicianQueue(technicians)
      .where((t) =>
          !skip.contains(t['name']) &&
          isTechnicianAssignable(allRepairRequests, t))
      .toList();
  if (free.isEmpty) return null;
  if (applianceType != null && applianceType.trim().isNotEmpty) {
    for (final t in free) {
      if (technicianCoversAppliance(t, applianceType)) return t;
    }
  }
  return free.first;
}

/// Technician queue: ordered by `queuePosition` (lowest = next in line).
/// Technicians without a position yet go after the ones that have one,
/// alphabetically, so the order is always stable.
List<Map<String, dynamic>> orderTechnicianQueue(
  List<Map<String, dynamic>> technicians,
) {
  final sorted = List<Map<String, dynamic>>.from(technicians);
  sorted.sort((a, b) {
    final pa = a['queuePosition'];
    final pb = b['queuePosition'];
    if (pa is num && pb is num) {
      final c = pa.compareTo(pb);
      if (c != 0) return c;
    } else if (pa is num) {
      return -1;
    } else if (pb is num) {
      return 1;
    }
    return ((a['name'] ?? '') as String)
        .toLowerCase()
        .compareTo(((b['name'] ?? '') as String).toLowerCase());
  });
  return sorted;
}
