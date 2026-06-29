import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<QuerySnapshot> streamRepairRequests() {
    return _db
        .collection('repairRequests')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> updateRepairStatus({
    required String docId,
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

    await _db.collection('repairRequests').doc(docId).update(updateData);
  }

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