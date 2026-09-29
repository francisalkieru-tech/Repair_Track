import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'Welcome_screen.dart';
import '../admin/admin_dashboard.dart';
import '../technicians/technicians_main_nav.dart';
import '../customer/main_nav_screen.dart';
import '../../utils/colors.dart';

class AuthGateScreen extends StatefulWidget {
  const AuthGateScreen({super.key});

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen> {

  bool _roleCheckFailed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolveAndRoute());
  }

  Future<void> _resolveAndRoute() async {
    if (mounted && _roleCheckFailed) {
      setState(() => _roleCheckFailed = false);
    }

    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      try {
        user = await FirebaseAuth.instance
            .authStateChanges()
            .first
            .timeout(const Duration(seconds: 3));
      } catch (_) {
        user = FirebaseAuth.instance.currentUser;
      }
    }

    if (user == null) {
      _goTo(const WelcomeScreen());
      return;
    }

    try {
      final db = FirebaseFirestore.instance;

      final adminDoc = await db.collection('admins').doc(user.uid).get();
      if (adminDoc.exists) {
        _goTo(const AdminDashboardScreen());
        return;
      }

      final techAuthDoc =
          await db.collection('technicianAuth').doc(user.uid).get();
      if (techAuthDoc.exists) {
        final data = techAuthDoc.data() as Map<String, dynamic>;
        _goTo(TechnicianMainNav(
          technicianDocId: data['technicianDocId'] as String?,
        ));
        return;
      }

      _goTo(const MainNavScreen());
    } catch (_) {
      if (mounted) setState(() => _roleCheckFailed = true);
    }
  }

  void _goTo(Widget screen) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_roleCheckFailed) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off, size: 48),
                const SizedBox(height: 16),
                const Text(
                  "Can't connect right now. Check your internet and try again.",
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _resolveAndRoute,
                  child: const Text('Retry'),
                ),
                TextButton(
                  onPressed: () => _goTo(const WelcomeScreen()),
                  child: const Text('Go to login instead'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
