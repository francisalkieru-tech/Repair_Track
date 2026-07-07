import 'package:cloud_firestore/cloud_firestore.dart';

/// Centralized Firestore access para sa repairRequests collection
/// (at ngayon, technicians collection din).
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Stream ng LAHAT ng repair requests, naka-order by newest first.
  /// Client-side na lang ang status filtering (sa admin_dashboard.dart)
  /// para iwas composite index issues.
  Stream<QuerySnapshot> streamRepairRequests() {
    return _db
        .collection('repairRequests')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// I-update ang status ng isang repair request + i-log sa statusHistory.
  ///
  /// Day 16 update: optional na ang partsSource (relevant lang sa
  /// In Process / Waiting for Parts), pati assignedTechnician at
  /// scheduledDate (relevant lang sa In Home) — kaya nullable lahat,
  /// at lalagay lang sa Firestore kung may value.
  ///
  /// Mahalaga: ginagamit dito ang Timestamp.now() (hindi serverTimestamp())
  /// dahil hindi pwede gumamit ng FieldValue.serverTimestamp() sa loob ng
  /// isang array na ipinasa via arrayUnion.
  Future<void> updateRepairStatus({
    required String docId,
    required String trackingId,
    required String newStatus,
    required String note,
    String? partsSource,
    String? assignedTechnician,
    DateTime? scheduledDate,
    String? photoUrl,
  }) async {
    final historyEntry = <String, dynamic>{
      'status': newStatus,
      'note': note.trim(),
      'timestamp': Timestamp.now(),
    };
    if (partsSource != null) {
      historyEntry['partsSource'] = partsSource;
    }
    if (assignedTechnician != null) {
      historyEntry['technician'] = assignedTechnician;
    }
    if (scheduledDate != null) {
      historyEntry['scheduledDate'] = Timestamp.fromDate(scheduledDate);
    }
    if (photoUrl != null) {
      historyEntry['photoUrl'] = photoUrl;
    }

    final updateData = <String, dynamic>{
      'status': newStatus,
      'statusHistory': FieldValue.arrayUnion([historyEntry]),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (assignedTechnician != null) {
      updateData['assignedTechnician'] = assignedTechnician;
    }
    if (scheduledDate != null) {
      updateData['scheduledVisit'] = Timestamp.fromDate(scheduledDate);
    }

    // Day 17-18: kapag naging "Completed" ang status, i-link/i-record
    // natin ang QR code data sa mismong document — para may permanenteng
    // record kung kailan na-generate ang QR para sa service record na
    // ito (ang actual QR image ay client-side na lang ginagawa mula sa
    // trackingId, pero ang link/reference ay nakatala na rin sa Firestore).
    if (newStatus == 'Completed') {
      updateData['qrData'] = 'repairtrack://track/$trackingId';
      updateData['qrGeneratedAt'] = FieldValue.serverTimestamp();
    }

    await _db.collection('repairRequests').doc(docId).update(updateData);
  }

  // ── Technicians ──────────────────────────────────────────────
  // Simpleng collection lang ng technician names na nadadagdagan ng
  // admin habang gumagamit (via "Add New Technician" sa dropdown).

  Stream<QuerySnapshot> streamTechnicians() {
    return _db.collection('technicians').orderBy('name').snapshots();
  }

  Future<void> addTechnician(String name) async {
    await _db.collection('technicians').add({
      'name': name.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}