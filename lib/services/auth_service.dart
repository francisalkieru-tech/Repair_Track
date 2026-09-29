import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  //REGISTER - Customer
  Future<String?> registerCustomer({
    required String email,
    required String password,
    required String name,
    required String contactNumber,
    required String address,
  }) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await _db.collection('customers').doc(result.user!.uid).set({
        'uid': result.user!.uid,
        'name': name,
        'email': email,
        'contactNumber': contactNumber,
        'address': address,
        'createdAt': DateTime.now().toString(),
        'role': 'customer',
      });

      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // REGISTER - Admin
  Future<String?> registerAdmin({
    required String email,
    required String password,
    required String name,
    required String shopName,
    required String shopAddress,
    required String contactNumber,
  }) async {
    try {
      // see if locked before make new Auth account
      final lockDoc = await _db.collection('adminSetup').doc('lock').get();
      if (lockDoc.exists) {
        return 'Admin registration is closed. Only one admin account is allowed for this shop.';
      }

      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final batch = _db.batch();
      final adminRef = _db.collection('admins').doc(result.user!.uid);
      final lockRef = _db.collection('adminSetup').doc('lock');

      batch.set(adminRef, {
        'uid': result.user!.uid,
        'name': name,
        'shopName': shopName,
        'shopAddress': shopAddress,
        'email': email,
        'contactNumber': contactNumber,
        'createdAt': DateTime.now().toString(),
        'role': 'admin',
      });

      batch.set(lockRef, {
        'createdAt': DateTime.now().toString(),
        'createdBy': result.user!.uid,
      });

      await batch.commit();

      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // ADMIN SIDE: adds a technician record (permanent doc ID, never
  // migrated later) + a small lookup pointer doc keyed by the invite
  // code itself. The pointer doc is the ONLY thing readable before
  // the technician has an account — it's a "get by exact ID" lookup,
  // never a listable/queryable collection, so a code can't be found
  // by browsing, only by already knowing it.
  Future<Map<String, dynamic>> addTechnicianWithInvite({
    required String email,
    required String name,
    String? phoneNumber,
    String? specialization,
    String? notes,
  }) async {
    try {
      // Generate then confirm the code isn't already taken (get-by-ID
      // lookup, allowed by rules even before signup) instead of trusting
      // randomness alone — cheap since collisions should be rare, but this
      // makes a collision impossible instead of just unlikely.
      final inviteCode = await _generateUniqueInviteCode();
      final techRef = _db.collection('technicians').doc();

      await techRef.set({
        'name': name.trim(),
        'email': email.trim(),
        'phoneNumber': (phoneNumber ?? '').trim(),
        'specialization': (specialization ?? '').trim(),
        'notes': (notes ?? '').trim(),
        'accountSetupComplete': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _db.collection('technicianInviteCodes').doc(inviteCode).set({
        'technicianDocId': techRef.id,
        'email': email.trim(),
      });

      return {'success': true, 'inviteCode': inviteCode, 'docId': techRef.id};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<String> _generateUniqueInviteCode() async {
    for (var attempt = 0; attempt < 5; attempt++) {
      final code = _generateInviteCode();
      final existing =
          await _db.collection('technicianInviteCodes').doc(code).get();
      if (!existing.exists) return code;
    }
    // Astronomically unlikely to ever reach here (5 straight collisions
    // out of 33^8 possibilities), but fall back to a longer code rather
    // than looping forever.
    return _generateInviteCode(length: 12);
  }

  String _generateInviteCode({int length = 8}) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no O/0/I/1 confusion
    final rand = Random.secure();
    return List.generate(length, (_) => chars[rand.nextInt(chars.length)])
        .join();
  }

  // TECHNICIAN SIDE: called from the technician's own device on first
  // login. Looks up the invite pointer (public get-by-ID only, see
  // rules), creates the Auth account under the technician's own
  // session, then links that account to the permanent technician doc
  // via a technicianAuth/{authUid} pointer — Admin's session is never
  // touched and the original technician doc's ID never changes.
  Future<Map<String, dynamic>> verifyInviteAndCreateAccount({
    required String email,
    required String inviteCode,
    required String password,
  }) async {
    try {
      final pointerRef =
          _db.collection('technicianInviteCodes').doc(inviteCode.trim());
      final pointerSnap = await pointerRef.get();

      if (!pointerSnap.exists) {
        return {'success': false, 'error': 'Invalid invite code.'};
      }

      final pointerData = pointerSnap.data()!;
      if ((pointerData['email'] as String?)?.toLowerCase() !=
          email.trim().toLowerCase()) {
        return {
          'success': false,
          'error': 'That code doesn\'t match this email.',
        };
      }

      final technicianDocId = pointerData['technicianDocId'] as String;

      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final newAuthUid = result.user!.uid;

      // Link this new account to the permanent technician doc.
      await _db.collection('technicianAuth').doc(newAuthUid).set({
        'technicianDocId': technicianDocId,
      });

      // Now permitted to read/update the technician doc (rules check
      // the technicianAuth link we just created).
      final techRef = _db.collection('technicians').doc(technicianDocId);
      final techSnap = await techRef.get();
      final techData = techSnap.data();

      if (techData == null) {
        return {
          'success': false,
          'error': 'Technician record not found. Ask your admin to check.',
        };
      }
      if (techData['accountSetupComplete'] == true) {
        return {
          'success': false,
          'error': 'This account is already set up. Please log in instead.',
        };
      }

      await techRef.update({'accountSetupComplete': true});
      await pointerRef.delete();

      // Backfill: any jobs Admin assigned to this technician (by
      // name) before setup won't have assignedTechnicianUid set yet
      // — fix those now so streamMyJobs() picks them up immediately.
      final techName = techData['name'] as String?;
      if (techName != null) {
        final priorJobs = await _db
            .collection('repairRequests')
            .where('assignedTechnician', isEqualTo: techName)
            .get();
        final backfillBatch = _db.batch();
        for (final job in priorJobs.docs) {
          if (job.data()['assignedTechnicianUid'] == null) {
            backfillBatch.update(
                job.reference, {'assignedTechnicianUid': technicianDocId});
          }
        }
        await backfillBatch.commit();
      }

      return {'success': true};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // LOGIN
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      DocumentSnapshot adminDoc = await _db
          .collection('admins')
          .doc(result.user!.uid)
          .get();

      if (adminDoc.exists) {
        return {'success': true, 'role': 'admin'};
      }

      DocumentSnapshot techAuthDoc = await _db
          .collection('technicianAuth')
          .doc(result.user!.uid)
          .get();

      if (techAuthDoc.exists) {
        final data = techAuthDoc.data() as Map<String, dynamic>;
        return {
          'success': true,
          'role': 'technician',
          'technicianDocId': data['technicianDocId'],
        };
      }

      return {'success': true, 'role': 'customer'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // LOGOUT
  Future<void> logout() async {
    await _auth.signOut();
  }

  // FORGOT PASSWORD
  Future<String?> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // FRIENDLY ERROR MESSAGES
  String friendlyError(String error) {
    if (error.contains('email-already-in-use')) {
      return 'This email already has an account.';
    } else if (error.contains('weak-password')) {
      return 'Password is too weak. Minimum 6 characters.';
    } else if (error.contains('invalid-email')) {
      return 'Invalid email format.';
    } else if (error.contains('user-not-found') ||
        error.contains('wrong-password') ||
        error.contains('invalid-credential')) {
      return 'Invalid email or password.';
    } else if (error.contains('too-many-requests')) {
      return 'Too many attempts. Try again later.';
    }
    return 'An error occurred. Try again.';
  }
} 