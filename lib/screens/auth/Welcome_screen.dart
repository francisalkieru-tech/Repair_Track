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
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: AppColors.darkGradient,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
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
                    'Track and monitor your repairs',
                    style: TextStyle(
                      fontSize: AppColors.fontSubtitle,
                      color: AppColors.textGray,
                    ),
                  ),

                  const SizedBox(height: 32),

                  Card(
                    elevation: 8,
                    shadowColor: Colors.grey.withValues(alpha: 0.5),
                    surfaceTintColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const Text(
                            'Already have an account?',
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
                                  builder: (_) => const LoginScreen(),
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
                                'Sign In',
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
                            'Customers, technicians and admins can sign in here',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: AppColors.fontCaption,
                              color: AppColors.textGray,
                            ),
                          ),

                          const SizedBox(height: 20),

                          Row(
                            children: const [
                              Expanded(child: Divider()),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  'New to RepairTrack?',
                                  style: TextStyle(
                                    fontSize: AppColors.fontCaption,
                                    color: AppColors.textGray,
                                  ),
                                ),
                              ),
                              Expanded(child: Divider()),
                            ],
                          ),

                          const SizedBox(height: 16),

                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const CustomerRegisterScreen(),
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.dark,
                                side: const BorderSide(
                                  color: AppColors.dark,
                                  width: 1.5,
                                ),
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
                          color: Colors.black.withValues(alpha: 0.05),
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
