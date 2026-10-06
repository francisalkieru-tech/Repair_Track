import 'package:cloud_firestore/cloud_firestore.dart';
import 'constants.dart';

/// A reporting window. [start] is inclusive, [end] is exclusive.
class ReportPeriod {
  final DateTime start;
  final DateTime end;
  final String label;
  final bool isMonthly;

  const ReportPeriod({
    required this.start,
    required this.end,
    required this.label,
    required this.isMonthly,
  });

  bool contains(DateTime t) => !t.isBefore(start) && t.isBefore(end);

  /// Last day shown to the reader (end is exclusive).
  DateTime get lastDay => end.subtract(const Duration(days: 1));

  String get rangeText => '${formatDate(start)} - ${formatDate(lastDay)}';

  static ReportPeriod month(int year, int month) {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 1);
    return ReportPeriod(
      start: start,
      end: end,
      label: '${_monthNames[month - 1]} $year',
      isMonthly: true,
    );
  }

  /// Monday-to-Sunday week that contains [day].
  static ReportPeriod weekOf(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    final start = d.subtract(Duration(days: d.weekday - 1));
    final end = start.add(const Duration(days: 7));
    return ReportPeriod(
      start: start,
      end: end,
      label: 'Week of ${formatDate(start)}',
      isMonthly: false,
    );
  }

  /// Newest-first list used by the technician screen: the last
  /// [weeks] weeks followed by the last [months] months.
  static List<ReportPeriod> recentWeeks({int weeks = 5, DateTime? now}) {
    final today = now ?? DateTime.now();
    final thisWeek = weekOf(today);
    return [
      for (var i = 0; i < weeks; i++)
        weekOf(thisWeek.start.subtract(Duration(days: 7 * i))),
    ];
  }

  static List<ReportPeriod> recentMonths({int months = 6, DateTime? now}) {
    final today = now ?? DateTime.now();
    return [
      for (var i = 0; i < months; i++)
        month(
          DateTime(today.year, today.month - i, 1).year,
          DateTime(today.year, today.month - i, 1).month,
        ),
    ];
  }
}

const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];
const _monthShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String formatDate(DateTime t) =>
    '${_monthShort[t.month - 1]} ${t.day}, ${t.year}';

String formatDateTime(DateTime t) {
  final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final minute = t.minute.toString().padLeft(2, '0');
  return '${formatDate(t)} $hour:$minute ${t.hour >= 12 ? 'PM' : 'AM'}';
}

String formatDuration(Duration d) {
  final h = d.inMinutes / 60.0;
  return '${h.toStringAsFixed(1)} hrs';
}

/// A technician declined this ticket (see job_decline_service.dart).
class TechDecline {
  final String technicianName;
  final String technicianId;
  final String reason;
  final DateTime at;
  const TechDecline({
    required this.technicianName,
    required this.technicianId,
    required this.reason,
    required this.at,
  });
}

/// One repair ticket flattened for reporting.
class ReportJob {
  final String trackingId;
  final String customer;
  final String appliance;
  final String problem;
  final String technician;
  final String status;
  final String serviceMode;
  final DateTime? createdAt;
  final DateTime? completedAt;
  final DateTime? declinedAt;
  final int warrantyMonths;

  /// Every timestamp found in the ticket's statusHistory.
  final List<DateTime> events;

  /// Times a technician declined this ticket before it was reassigned.
  final List<TechDecline> techDeclines;

  const ReportJob({
    required this.trackingId,
    required this.customer,
    required this.appliance,
    required this.problem,
    required this.technician,
    required this.status,
    required this.serviceMode,
    required this.createdAt,
    required this.completedAt,
    required this.declinedAt,
    required this.warrantyMonths,
    required this.events,
    this.techDeclines = const [],
  });

  factory ReportJob.fromData(Map<String, dynamic> data) {
    final events = <DateTime>[];
    final techDeclines = <TechDecline>[];
    DateTime? completedAt;
    DateTime? declinedAt;

    final history = data['statusHistory'];
    if (history is List) {
      for (final h in history) {
        if (h is! Map || h['timestamp'] is! Timestamp) continue;
        final t = (h['timestamp'] as Timestamp).toDate();
        events.add(t);
        if (h['declinedBy'] != null) {
          techDeclines.add(TechDecline(
            technicianName: (h['declinedBy'] ?? '') as String,
            technicianId: (h['declinedByTechnicianId'] ?? '') as String,
            reason: (h['declineReason'] ?? '') as String,
            at: t,
          ));
        }
        final s = (h['status'] ?? '') as String;
        if (s == AppConstants.statusCompleted &&
            (completedAt == null || t.isAfter(completedAt))) {
          completedAt = t;
        }
        if (s == AppConstants.statusDeclined &&
            (declinedAt == null || t.isAfter(declinedAt))) {
          declinedAt = t;
        }
      }
    }

    final created = data['createdAt'] is Timestamp
        ? (data['createdAt'] as Timestamp).toDate()
        : null;
    if (created != null) events.add(created);

    final status = AppConstants.normalizeStatus(
        (data['status'] ?? 'Pending') as String);

    return ReportJob(
      trackingId: (data['trackingId'] ?? '') as String,
      customer: (data['name'] ?? '') as String,
      appliance: (data['applianceType'] ?? '') as String,
      problem: (data['problemDescription'] ?? '') as String,
      technician: (data['assignedTechnician'] ?? '') as String,
      status: status,
      serviceMode: (data['serviceMode'] ?? '') as String,
      createdAt: created,
      completedAt:
          status == AppConstants.statusCompleted ? completedAt : null,
      declinedAt: status == AppConstants.statusDeclined ? declinedAt : null,
      warrantyMonths: (data['warrantyMonths'] is num)
          ? (data['warrantyMonths'] as num).toInt()
          : 0,
      events: events,
      techDeclines: techDeclines,
    );
  }

  /// Anything happened to this ticket inside [p] (created, assigned,
  /// status changed, completed...).
  bool touches(ReportPeriod p) => events.any(p.contains);

  bool receivedIn(ReportPeriod p) => createdAt != null && p.contains(createdAt!);
  bool completedIn(ReportPeriod p) =>
      completedAt != null && p.contains(completedAt!);
  bool declinedIn(ReportPeriod p) =>
      declinedAt != null && p.contains(declinedAt!);

  bool get isClosed =>
      status == AppConstants.statusCompleted ||
      status == AppConstants.statusDeclined;

  /// Date used to sort a ticket inside a report (latest activity in [p]).
  DateTime activityIn(ReportPeriod p) {
    final inside = events.where(p.contains).toList()..sort();
    return inside.isEmpty ? (createdAt ?? p.start) : inside.last;
  }

  String get modeLabel {
    switch (serviceMode) {
      case 'home':
        return 'Tech Visit';
      case 'shop':
        return 'On-Site';
      default:
        return '-';
    }
  }
}

List<ReportJob> jobsFromDocs(Iterable<Map<String, dynamic>> docs) =>
    docs.map(ReportJob.fromData).toList();

// ADMIN (monthly)

class TechnicianTally {
  final String name;
  int completed = 0;
  int handled = 0;
  int stillActive = 0;
  int declinedByTech = 0;
  Duration totalRepairTime = Duration.zero;

  TechnicianTally(this.name);

  Duration? get averageRepairTime =>
      completed == 0 ? null : totalRepairTime ~/ completed;
}

class AdminReport {
  final ReportPeriod period;
  final List<ReportJob> jobs; // everything that touched the period
  final int received;
  final int completed;
  final int declined;
  final int stillOpen;
  final int warrantiesIssued;
  final int technicianDeclines;
  final Map<String, int> byAppliance; // tickets received in the period
  final Map<String, int> byMode;
  final List<TechnicianTally> technicians;

  const AdminReport({
    required this.period,
    required this.jobs,
    required this.received,
    required this.completed,
    required this.declined,
    required this.stillOpen,
    required this.warrantiesIssued,
    required this.technicianDeclines,
    required this.byAppliance,
    required this.byMode,
    required this.technicians,
  });

  /// Share of the tickets that had activity this period which are done.
  double get completionRate =>
      jobs.isEmpty ? 0 : (completed / jobs.length) * 100;
}

AdminReport buildAdminReport(List<ReportJob> all, ReportPeriod p) {
  final jobs = all.where((j) => j.touches(p)).toList()
    ..sort((a, b) => a.activityIn(p).compareTo(b.activityIn(p)));

  final byAppliance = <String, int>{};
  final byMode = <String, int>{};
  final techs = <String, TechnicianTally>{};
  var received = 0, completed = 0, declined = 0, open = 0, warranties = 0;
  var techDeclines = 0;

  for (final j in jobs) {
    if (j.receivedIn(p)) {
      received++;
      byAppliance[j.appliance.isEmpty ? 'Unspecified' : j.appliance] =
          (byAppliance[j.appliance.isEmpty ? 'Unspecified' : j.appliance] ??
                  0) +
              1;
      byMode[j.modeLabel] = (byMode[j.modeLabel] ?? 0) + 1;
    }
    if (j.completedIn(p)) {
      completed++;
      if (j.warrantyMonths > 0) warranties++;
    }
    if (j.declinedIn(p)) declined++;
    if (!j.isClosed) open++;

    for (final d in j.techDeclines) {
      if (!p.contains(d.at)) continue;
      techDeclines++;
      techs.putIfAbsent(d.technicianName, () => TechnicianTally(d.technicianName))
          .declinedByTech++;
    }

    if (j.technician.isNotEmpty) {
      final t = techs.putIfAbsent(j.technician, () => TechnicianTally(j.technician));
      t.handled++;
      if (j.completedIn(p)) {
        t.completed++;
        if (j.createdAt != null) {
          t.totalRepairTime += j.completedAt!.difference(j.createdAt!);
        }
      }
      if (!j.isClosed) t.stillActive++;
    }
  }

  final techList = techs.values.toList()
    ..sort((a, b) => b.completed.compareTo(a.completed));

  return AdminReport(
    period: p,
    jobs: jobs,
    received: received,
    completed: completed,
    declined: declined,
    stillOpen: open,
    warrantiesIssued: warranties,
    technicianDeclines: techDeclines,
    byAppliance: byAppliance,
    byMode: byMode,
    technicians: techList,
  );
}

// TECHNICIAN (weekly / monthly)

class TechnicianReport {
  final String technicianName;
  final ReportPeriod period;
  final List<ReportJob> jobs;
  final int completed;
  final int stillOpen;
  final int declined;
  final Duration? averageRepairTime;
  final Duration dutyTime;
  final int daysOnDuty;

  /// Jobs this technician declined (and that were reassigned) in the period.
  final List<TechnicianDeclineRow> declinedJobs;

  const TechnicianReport({
    required this.technicianName,
    required this.period,
    required this.jobs,
    required this.completed,
    required this.stillOpen,
    required this.declined,
    required this.averageRepairTime,
    required this.dutyTime,
    required this.daysOnDuty,
    required this.declinedJobs,
  });
}

class TechnicianDeclineRow {
  final String trackingId;
  final String appliance;
  final String reason;
  final DateTime at;
  const TechnicianDeclineRow({
    required this.trackingId,
    required this.appliance,
    required this.reason,
    required this.at,
  });
}

/// [jobs] must already be limited to this technician's tickets.
/// [dutyLogs] are the raw `{type, timestamp}` rows of the clock in/out log.
TechnicianReport buildTechnicianReport({
  required String technicianName,
  required List<ReportJob> jobs,
  required List<Map<String, dynamic>> dutyLogs,
  required ReportPeriod period,
  String? technicianDocId,
  List<ReportJob> declinedJobs = const [],
}) {
  final mine = jobs.where((j) => j.touches(period)).toList()
    ..sort((a, b) => a.activityIn(period).compareTo(b.activityIn(period)));

  var completed = 0, open = 0, declined = 0;
  var repairTotal = Duration.zero;
  for (final j in mine) {
    if (j.completedIn(period)) {
      completed++;
      if (j.createdAt != null) {
        repairTotal += j.completedAt!.difference(j.createdAt!);
      }
    }
    if (j.declinedIn(period)) declined++;
    if (!j.isClosed) open++;
  }

  // Pair clock_in -> next clock_out to get hours on duty.
  final logs = dutyLogs
      .where((l) => l['timestamp'] is Timestamp)
      .map((l) => _DutyEvent(
            (l['type'] ?? '') as String,
            (l['timestamp'] as Timestamp).toDate(),
          ))
      .toList()
    ..sort((a, b) => a.at.compareTo(b.at));

  var duty = Duration.zero;
  final days = <String>{};
  DateTime? clockedInAt;
  for (final e in logs) {
    if (e.type == 'clock_in') {
      clockedInAt = e.at;
    } else if (e.type == 'clock_out' && clockedInAt != null) {
      if (period.contains(clockedInAt)) {
        duty += e.at.difference(clockedInAt);
        days.add('${clockedInAt.year}-${clockedInAt.month}-${clockedInAt.day}');
      }
      clockedInAt = null;
    }
  }

  final declineRows = <TechnicianDeclineRow>[];
  for (final j in declinedJobs) {
    for (final d in j.techDeclines) {
      final mine = technicianDocId != null && technicianDocId.isNotEmpty
          ? d.technicianId == technicianDocId
          : d.technicianName == technicianName;
      if (mine && period.contains(d.at)) {
        declineRows.add(TechnicianDeclineRow(
          trackingId: j.trackingId,
          appliance: j.appliance,
          reason: d.reason,
          at: d.at,
        ));
      }
    }
  }
  declineRows.sort((a, b) => a.at.compareTo(b.at));

  return TechnicianReport(
    technicianName: technicianName,
    period: period,
    jobs: mine,
    completed: completed,
    stillOpen: open,
    declined: declined,
    averageRepairTime: completed == 0 ? null : repairTotal ~/ completed,
    dutyTime: duty,
    daysOnDuty: days.length,
    declinedJobs: declineRows,
  );
}

class _DutyEvent {
  final String type;
  final DateTime at;
  const _DutyEvent(this.type, this.at);
}
