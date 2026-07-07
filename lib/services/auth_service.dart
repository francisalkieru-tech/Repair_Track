import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

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
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await _db.collection('admins').doc(result.user!.uid).set({
        'uid': result.user!.uid,
        'name': name,
        'shopName': shopName,
        'shopAddress': shopAddress,
        'email': email,
        'contactNumber': contactNumber,
        'createdAt': DateTime.now().toString(),
        'role': 'admin',
      });

      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // GENERATE random 6-digit code
  String _generateCode() {
    Random random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  // SEND verification code via SMS
  Future<String?> sendAdminCode(String contactNumber) async {
    String code = _generateCode();

    try {
      await _db.collection('adminCodes').add({
        'code': code,
        'contactNumber': contactNumber,
        'used': false,
        'createdAt': DateTime.now(),
        'expiresAt': DateTime.now().add(const Duration(minutes: 10)),
      });

      // TEMPORARY for testing — will be seen in VS Code terminal
      // ignore: avoid_print
      print('=============================');
      // ignore: avoid_print
      print('TEST CODE: $code');
      // ignore: avoid_print
      print('=============================');

      // Uncomment this when you have an actual Semaphore API key
      // final response = await http.post(
      //   Uri.parse('https://api.semaphore.co/api/v4/messages'),
      //   body: {
      //     'apikey': 'YOUR_SEMAPHORE_API_KEY',
      //     'number': contactNumber,
      //     'message': 'Your Repair Tracker admin code is: $code. Valid for 10 minutes.',
      //     'sendername': 'REPAIRAPP',
      //   },
      // );
      // if (response.statusCode != 200) {
      //   return 'Failed to send SMS. Try again.';
      // }

      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // VERIFY the SMS code
  Future<String?> verifyAdminCode(String contactNumber, String code) async {
    final now = DateTime.now();

    final query = await _db
        .collection('adminCodes')
        .where('code', isEqualTo: code)
        .where('contactNumber', isEqualTo: contactNumber)
        .where('used', isEqualTo: false)
        .get();

    if (query.docs.isEmpty) {
      return 'Invalid code. Try again.';
    }

    final expiresAt =
        (query.docs.first['expiresAt'] as Timestamp).toDate();
    if (now.isAfter(expiresAt)) {
      return 'Code has expired. Request a new code.';
    }

    await _db
        .collection('adminCodes')
        .doc(query.docs.first.id)
        .update({'used': true});

    return null;
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
}  // ← closing bracket ng AuthService class