import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/constants.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // In-app notifications — a simple bell-icon inbox for each of the
  // three roles, separate from the floating chat and from SMS (which
  // stays simulated elsewhere in the app). recipientType is 'admin',
  // 'technician', or 'customer'; recipientId is the technicianDocId
  // or customer auth uid (null/unused for 'admin', since this app has
  // a single-admin-per-shop design — see adminSetup/lock).
  Future<void> createNotification({
    required String recipientType,
    String? recipientId,
    required String title,
    required String body,
    String? trackingId,
  }) async {
    await _db.collection('notifications').add({
      'recipientType': recipientType,
      'recipientId': recipientId,
      'title': title,
      'body': body,
      'trackingId': trackingId,
      'read': false,
      'timestamp': Timestamp.now(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamNotifications({
    required String recipientType,
    String? recipientId,
  }) {
    Query<Map<String, dynamic>> q = _db
        .collection('notifications')
        .where('recipientType', isEqualTo: recipientType);
    if (recipientId != null) {
      q = q.where('recipientId', isEqualTo: recipientId);
    }
    return q.snapshots();
  }

  Future<void> markNotificationRead(String notificationId) async {
    await _db
        .collection('notifications')
        .doc(notificationId)
        .update({'read': true});
  }

  Stream<QuerySnapshot> streamRepairRequests() {
    return _db
        .collection('repairRequests')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> updateRepairStatus({
    required String docId,
    required String trackingId,
    required String newStatus,
    required String note,
    String? partsSource,
    String? assignedTechnician,
    String? assignedTechnicianUid,
    DateTime? scheduledDate,
    String? photoUrl,
    int? warrantyMonths,
    String? warrantyTerms,
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
    if (assignedTechnicianUid != null) {
      updateData['assignedTechnicianUid'] = assignedTechnicianUid;
    }
    if (scheduledDate != null) {
      updateData['scheduledVisit'] = Timestamp.fromDate(scheduledDate);
    }

    if (newStatus == 'Completed') {
      updateData['qrData'] = 'repairtrack://track/$trackingId';
      updateData['qrGeneratedAt'] = FieldValue.serverTimestamp();

      if (warrantyMonths != null && warrantyMonths > 0) {
        final now = DateTime.now();
        final expiresAt = DateTime(
          now.year,
          now.month + warrantyMonths,
          now.day,
        );
        updateData['warrantyMonths'] = warrantyMonths;
        updateData['warrantyTerms'] = (warrantyTerms ?? '').trim();
        updateData['warrantyStartAt'] = Timestamp.now();
        updateData['warrantyExpiresAt'] = Timestamp.fromDate(expiresAt);
      }
    }

    await _db.collection('repairRequests').doc(docId).update(updateData);
  }

  Stream<QuerySnapshot> streamTechnicians() {
    return _db.collection('technicians').orderBy('name').snapshots();
  }

  // Used by the technician's own home screen to list jobs assigned
  // to them. Sorted client-side (see technician_home_screen.dart)
  // to avoid requiring a composite index for uid + status ordering.
  Stream<QuerySnapshot> streamMyJobs(String technicianUid) {
    return _db
        .collection('repairRequests')
        .where('assignedTechnicianUid', isEqualTo: technicianUid)
        .snapshots();
  }

  // Admin <-> Technician chat — one thread per technician (not per
  // job), matching the floating-bubble "Messenger-style" widget design
  // instead of a notes field buried inside each job. Replaces the
  // earlier per-job `techNotes` approach entirely.
  Stream<DocumentSnapshot<Map<String, dynamic>>> streamChat(
      String technicianDocId) {
    return _db
        .collection('technicianChats')
        .doc(technicianDocId)
        .snapshots();
  }

  // ADMIN ONLY (see firestore.rules): every technician's chat thread
  // at once, so the floating chat bubble can show one aggregate
  // unread count without Admin having opened each thread.
  Stream<QuerySnapshot<Map<String, dynamic>>> streamAllChats() {
    return _db.collection('technicianChats').snapshots();
  }

  // Marks a chat thread as read by one side — stamps
  // adminLastRead/technicianLastRead with now, so unread counts (any
  // message from the OTHER side newer than this) go back to zero.
  // Called when that side actually opens the thread panel, not just
  // when the bubble is visible.
  Future<void> markChatRead({
    required String technicianDocId,
    required String reader, // 'admin' or 'technician'
  }) async {
    await _db.collection('technicianChats').doc(technicianDocId).set({
      reader == 'admin' ? 'adminLastRead' : 'technicianLastRead':
          Timestamp.now(),
    }, SetOptions(merge: true));
  }

  Future<void> sendChatMessage({
    required String technicianDocId,
    required String author, // 'admin' or 'technician'
    required String authorName,
    required String text,
  }) async {
    await _db.collection('technicianChats').doc(technicianDocId).set({
      'messages': FieldValue.arrayUnion([
        {
          'author': author,
          'authorName': authorName,
          'text': text,
          'timestamp': Timestamp.now(),
        }
      ]),
    }, SetOptions(merge: true));
  }

  // Lightweight "online" presence — no Realtime Database or Cloud
  // Functions in this app, so this is an approximation: the
  // technician's own screen calls this every ~30s while the app is
  // open (see technicians_pending_tab.dart / technicians_current_tab.dart),
  // and Admin's technician
  // picker (tech_chat_widget.dart) treats "lastSeen within the last 2
  // minutes" as online. It can lag by up to that window after the
  // technician actually closes the app — there's no way to detect an
  // app kill/crash instantly without a real presence system — but
  // needs no extra backend and is good enough to show at a glance.
  Future<void> updateTechnicianPresence(String technicianDocId) async {
    await _db.collection('technicians').doc(technicianDocId).set({
      'lastSeen': Timestamp.now(),
    }, SetOptions(merge: true));
  }

  // ADMIN: opens the 24-hour "who sources the part" window on a job
  // that's Waiting for Parts. Called after Admin has reviewed the
  // technician's note and filled in the part details/price for the
  // customer to see.
  Future<void> openPartsDecision({
    required String docId,
    required String partDetails,
  }) async {
    final deadline = DateTime.now().add(AppConstants.partsDecisionWindow);
    await _db.collection('repairRequests').doc(docId).update({
      'partsDecisionStatus': AppConstants.partsDecisionAwaitingCustomer,
      'partsDecisionDeadline': Timestamp.fromDate(deadline),
      'partsDecisionDetails': partDetails.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // CUSTOMER: answers the parts-sourcing prompt on their own request.
  // Security rules independently enforce the deadline and the
  // allowed field set — this is just the client-side call.
  Future<void> submitPartsDecision({
    required String docId,
    required String partsSource,
  }) async {
    await _db.collection('repairRequests').doc(docId).update({
      'partsSource': partsSource,
      'partsDecisionStatus': AppConstants.partsDecisionDecided,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ADMIN (client-side "cron"): there's no Cloud Functions/Blaze plan
  // here, so instead of a server-side scheduled job, Admin's own app
  // checks for expired decision windows every time the requests list
  // loads and applies the Shop-Supplied default itself. Safe to call
  // repeatedly — it only touches jobs still 'awaiting_customer' past
  // their deadline, so it's a no-op once a job's decision is settled.
  Future<void> applyExpiredPartsDecisionDefaults() async {
    final now = Timestamp.now();
    final expired = await _db
        .collection('repairRequests')
        .where('partsDecisionStatus',
            isEqualTo: AppConstants.partsDecisionAwaitingCustomer)
        .where('partsDecisionDeadline', isLessThan: now)
        .get();

    if (expired.docs.isEmpty) return;

    final batch = _db.batch();
    for (final doc in expired.docs) {
      batch.update(doc.reference, {
        'partsSource': AppConstants.partsSourceShop,
        'partsDecisionStatus': AppConstants.partsDecisionDecided,
        'partsDecisionDefaulted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }
}