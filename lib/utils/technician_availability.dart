import '../utils/constants.dart';

/// Single source of truth for "is this technician available for a new
/// assignment right now?" Computed live from the current repair
/// requests — not stored on the technician doc — so it can never
/// drift out of sync with the jobs actually assigned.
///
/// Two rules, in order:
/// 1. An active "In Home" job makes the technician unavailable for
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

  final hasInHomeJob =
      activeJobs.any((r) => r['status'] == AppConstants.statusInHome);
  if (hasInHomeJob) return false;

  return activeJobs.length < kMaxActiveJobsPerTechnician;
}
