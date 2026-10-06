import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/constants.dart';
import '../utils/technician_availability.dart';
import 'firestore_service.dart';

/// How many jobs one technician may decline per week (Mon-Sun). Past this
/// the button is blocked and the technician is told to talk to Admin, so
/// declining can't be abused to dodge work.
const int kMaxDeclinesPerWeek = 3;

/// Reasons shown in the decline dialog.
const List<String> kDeclineReasons = [
  'Not my specialty',
  'Too many jobs right now',
  'Cannot make the schedule',
  'Other',
];

/// Statuses where a technician may still decline: assigned to them but the
/// repair has not been started yet.
const Set<String> kDeclinableStatuses = {
  AppConstants.statusAccepted,
  AppConstants.statusTechVisit,
  AppConstants.statusOnSite,
  AppConstants.statusQueued,
};

bool isJobDeclinable(String status) =>
    kDeclinableStatuses.contains(AppConstants.normalizeStatus(status));

class DeclineResult {
  /// Name of the technician the job was handed to (null = nobody was
  /// free, the job went back to Admin as Pending).
  final String? reassignedTo;
  const DeclineResult({this.reassignedTo});
  bool get needsAdmin => reassignedTo == null;
}

class DeclineException implements Exception {
  final String message;
  const DeclineException(this.message);
  @override
  String toString() => message;
}

class JobDeclineService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirestoreService _fs = FirestoreService();

  DateTime _weekStart() {
    final n = DateTime.now();
    final d = DateTime(n.year, n.month, n.day);
    return d.subtract(Duration(days: d.weekday - 1));
  }

  /// Declines this technician already made since Monday.
  Future<int> declinesThisWeek(String technicianDocId) async {
    final snap = await _db
        .collection('repairRequests')
        .where('declinedByTechnicianIds', arrayContains: technicianDocId)
        .get();
    final start = _weekStart();
    var count = 0;
    for (final doc in snap.docs) {
      final history = doc.data()['statusHistory'];
      if (history is! List) continue;
      for (final h in history) {
        if (h is! Map || h['declinedByTechnicianId'] != technicianDocId) {
          continue;
        }
        final ts = h['timestamp'];
        if (ts is Timestamp && !ts.toDate().isBefore(start)) count++;
      }
    }
    return count;
  }

  Future<int> declinesLeftThisWeek(String technicianDocId) async =>
      (kMaxDeclinesPerWeek - await declinesThisWeek(technicianDocId))
          .clamp(0, kMaxDeclinesPerWeek);

  /// Technician gives the job back. The job is handed to the next suitable
  /// technician (specialists first, fair queue order, never someone who
  /// already declined it). If nobody is free it goes back to Admin as
  /// Pending. The decliner moves to the back of the queue and Admin is
  /// notified either way.
  Future<DeclineResult> decline({
    required String docId,
    required String technicianDocId,
    required String technicianName,
    required String reason,
    String note = '',
  }) async {
    final ref = _db.collection('repairRequests').doc(docId);
    final snap = await ref.get();
    final job = snap.data();
    if (job == null) throw const DeclineException('This job no longer exists.');

    if (job['assignedTechnicianUid'] != technicianDocId) {
      throw const DeclineException('This job is no longer assigned to you.');
    }
    final status = (job['status'] ?? '') as String;
    if (!isJobDeclinable(status)) {
      throw const DeclineException(
          'You can only decline a job before you start the repair.');
    }
    if (await declinesLeftThisWeek(technicianDocId) <= 0) {
      throw const DeclineException(
          'You reached the limit of $kMaxDeclinesPerWeek declines this week. '
          'Please contact Admin.');
    }

    final trackingId = (job['trackingId'] ?? '') as String;
    final appliance = (job['applianceType'] ?? '') as String;

    // Everyone who already turned this job down is skipped.
    final skip = <String>{technicianName};
    final history = job['statusHistory'];
    if (history is List) {
      for (final h in history) {
        if (h is Map && h['declinedBy'] != null) {
          skip.add(h['declinedBy'].toString());
        }
      }
    }

    // Best-effort pick of the next technician. If reading the other
    // technicians/jobs fails, the job simply goes back to Admin.
    Map<String, dynamic>? next;
    List<Map<String, dynamic>> techs = [];
    try {
      final techSnap = await _fs.streamTechnicians().first;
      final reqSnap = await _fs.streamRepairRequests().first;
      techs = techSnap.docs.map((d) {
        final m = Map<String, dynamic>.from(d.data() as Map);
        m['id'] = d.id;
        return m;
      }).toList();
      final requests = reqSnap.docs
          .map((d) => d.data() as Map<String, dynamic>)
          .toList();
      next = nextTechnicianInQueue(
        requests,
        techs,
        excludeNames: skip,
        applianceType: appliance,
      );
    } catch (_) {
      next = null;
    }

    final nextName = next?['name'] as String?;
    final nextId = next?['id'] as String?;
    final cleanReason = reason.trim();
    final cleanNote = note.trim();

    // A reassigned job starts again at "Accepted" for the new technician;
    // with nobody free it returns to Admin as Pending.
    final newStatus = next != null
        ? (AppConstants.normalizeStatus(status) == AppConstants.statusQueued
            ? AppConstants.statusAccepted
            : AppConstants.normalizeStatus(status))
        : AppConstants.statusPending;

    final entry = <String, dynamic>{
      'status': newStatus,
      // Customer-facing text stays neutral; the real reason is kept in
      // the declineReason / declineNote fields for Admin and reports.
      'note': next != null
          ? 'Technician reassigned'
          : 'Waiting for a technician to be assigned',
      'timestamp': Timestamp.now(),
      'declinedBy': technicianName,
      'declinedByTechnicianId': technicianDocId,
      'declineReason': cleanReason,
      if (cleanNote.isNotEmpty) 'declineNote': cleanNote,
      if (next != null) 'technician': nextName,
      if (next != null) 'reassignedFrom': technicianName,
    };

    await ref.update({
      'status': newStatus,
      'statusHistory': FieldValue.arrayUnion([entry]),
      'declinedByTechnicianIds': FieldValue.arrayUnion([technicianDocId]),
      'updatedAt': FieldValue.serverTimestamp(),
      'assignedTechnician': next != null ? nextName : FieldValue.delete(),
      'assignedTechnicianUid': next != null ? nextId : FieldValue.delete(),
    });

    // Queue: decliner (and the new assignee) go to the back.
    try {
      if (techs.isNotEmpty) {
        final ordered = orderTechnicianQueue(techs);
        await _fs.moveTechniciansToQueueEnd(
          currentOrderIds: ordered.map((t) => t['id'] as String).toList(),
          moveToEnd: [technicianDocId, if (nextId != null) nextId],
        );
      }
    } catch (_) {}

    // Notifications (never block the decline itself).
    try {
      final why = cleanNote.isEmpty ? cleanReason : '$cleanReason - $cleanNote';
      await _fs.createNotification(
        recipientType: 'admin',
        title: 'Job declined by $technicianName',
        body: '$appliance (ID: $trackingId). Reason: $why. '
            '${next != null ? 'Reassigned to $nextName.' : 'No technician is free - please reassign.'}',
        trackingId: trackingId,
      );
      if (nextId != null) {
        await _fs.createNotification(
          recipientType: 'technician',
          recipientId: nextId,
          title: 'New job assigned',
          body: '$appliance (ID: $trackingId)',
          trackingId: trackingId,
        );
      }
    } catch (_) {}

    return DeclineResult(reassignedTo: nextName);
  }
}
