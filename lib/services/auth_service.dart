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

      return {'success': true, 'role': 'customer'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // LOGOUT
  Future<void> logout() async {
    await _auth.signOut();
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