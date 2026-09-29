import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import 'login_screen.dart';
import 'customer_register_screen.dart';
import '../tracking/tracking_input_screen.dart';
import '../../utils/colors.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 448),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ---------------------------------------------------------
                  // APP LOGO / ANIMATION
                  // ---------------------------------------------------------
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: AppColors.darkGradient,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Lottie.asset(
                        'assets/wired-outline-409-tool-in-reveal.json',
                        controller: _controller,
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                        onLoaded: (composition) {
                          _controller
                            ..duration = composition.duration
                            ..forward();
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    'RepairTrack',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'Track, and Monitor Repairs',
                    style: TextStyle(
                      fontSize: AppColors.fontSubtitle,
                      color: AppColors.textGray,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ---------------------------------------------------------
                  // LOGIN OPTIONS CARD
                  // ---------------------------------------------------------
                  Card(
                    elevation: 8,
                    shadowColor: Colors.grey.withOpacity(0.5),
                    surfaceTintColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const Text(
                            'Welcome!',
                            style: TextStyle(
                              fontSize: AppColors.fontTitle,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 8),

                          const Text(
                            'Choose an option to get started',
                            style: TextStyle(
                              fontSize: AppColors.fontSubtitle,
                              color: AppColors.textGray,
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Customer
                          _OptionButton(
                            icon: Icons.person,
                            title: 'Login as Customer',
                            subtitle: 'Already have an account',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const LoginScreen(role: 'customer'),
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Admin
                          _OptionButton(
                            icon: Icons.shield,
                            title: 'Admin',
                            subtitle: 'Admin access only',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const LoginScreen(role: 'admin'),
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Technician
                          _OptionButton(
                            icon: Icons.build,
                            title: 'Technician',
                            subtitle: 'Technician access only',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const LoginScreen(role: 'technician'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ---------------------------------------------------------
                  // CREATE ACCOUNT CARD
                  // ---------------------------------------------------------
                  Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(
                        color: Color.fromARGB(255, 94, 94, 94),
                        width: 2,
                      ),
                    ),
                    color: AppColors.background,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const Text(
                            'New to RepairTrack?',
                            style: TextStyle(
                              fontSize: AppColors.fontLabel,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF374151),
                            ),
                          ),

                          const SizedBox(height: 12),

                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const CustomerRegisterScreen(),
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.dark,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Create New Account',
                                style: TextStyle(
                                  fontSize: AppColors.fontBody,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          const Text(
                            'Register to submit and track your appliance repairs',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: AppColors.fontCaption,
                              color: AppColors.textGray,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ---------------------------------------------------------
                  // GUEST TRACKING
                  // ---------------------------------------------------------
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFE1E4E8),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.track_changes,
                          size: 28,
                          color: AppColors.dark,
                        ),

                        const SizedBox(height: 8),

                        const Text(
                          'Already have a tracking ID?',
                          style: TextStyle(
                            fontSize: AppColors.fontLabel,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),

                        const SizedBox(height: 4),

                        const Text(
                          'Check the status of your repair without logging in.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: AppColors.fontCaption,
                            color: AppColors.textGray,
                          ),
                        ),

                        const SizedBox(height: 14),

                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const TrackingInputScreen(),
                              ),
                            ),
                            icon: const Icon(
                              Icons.track_changes,
                              size: 19,
                            ),
                            label: const Text(
                              'Track a Repair',
                              style: TextStyle(
                                fontSize: AppColors.fontBody,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.dark,
                              backgroundColor: Colors.white,
                              side: const BorderSide(
                                color: AppColors.dark,
                                width: 1.5,
                              ),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// LOGIN OPTION BUTTON
// ===========================================================================

class _OptionButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _OptionButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.dark,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 26,
              color: Colors.white,
            ),

            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: AppColors.fontBody,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: AppColors.fontCaption,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),

            const Icon(
              Icons.chevron_right,
              color: Colors.white70,
            ),
          ],
        ),
      ),
    );
  }
}