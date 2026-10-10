import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../customer/main_nav_screen.dart';
import '../admin/admin_dashboard.dart';
import '../technicians/technicians_main_nav.dart';
import '../technicians/technicians_account_setup_screen.dart';
import 'customer_register_screen.dart';
import 'admin_register.dart';
import '../../utils/colors.dart';
import '../../utils/ui_widgets.dart';

/// One login screen for customers, technicians and admins.
///
/// The role cards on top only decide which sign-up / setup link is shown
/// below the form. The real role is always detected after sign-in by
/// [AuthService.login], so picking the "wrong" card never blocks a login.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  String? _errorMessage;
  String _selectedRole = 'customer';
  bool _adminExists = true;

  @override
  void initState() {
    super.initState();
    _checkIfAdminExists();
  }

  // Shop setup is only offered until the first admin exists.
  Future<void> _checkIfAdminExists() async {
    try {
      final lockDoc = await FirebaseFirestore.instance
          .collection('adminSetup')
          .doc('lock')
          .get();
      if (!mounted) return;
      setState(() => _adminExists = lockDoc.exists);
    } catch (_) {}
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showForgotPasswordDialog() {
    final resetEmailController =
        TextEditingController(text: _emailController.text.trim());
    bool isSending = false;
    String? dialogError;
    String? dialogSuccess;

    showAppDialog(
      context: context,
      title: 'Reset Password',
      content: StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter your email address. We\'ll send you a link to reset your password.',
                style: TextStyle(
                    fontSize: AppColors.fontLabel, color: AppColors.textGray),
              ),
              const SizedBox(height: 16),
              if (dialogSuccess != null)
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline,
                          color: AppColors.success, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(dialogSuccess!,
                            style: const TextStyle(
                                color: AppColors.success,
                                fontSize: AppColors.fontCaption)),
                      ),
                    ],
                  ),
                ),
              if (dialogError != null)
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.dangerBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.danger, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(dialogError!,
                            style: const TextStyle(
                                color: AppColors.danger,
                                fontSize: AppColors.fontCaption)),
                      ),
                    ],
                  ),
                ),
              TextField(
                controller: resetEmailController,
                keyboardType: TextInputType.emailAddress,
                enabled: !isSending && dialogSuccess == null,
                decoration: InputDecoration(
                  hintText: 'juan@example.com',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(dialogSuccess != null ? 'Close' : 'Cancel',
                        style: const TextStyle(color: AppColors.textGray)),
                  ),
                  const SizedBox(width: 4),
                  if (dialogSuccess == null)
                    ElevatedButton(
                      onPressed: isSending
                          ? null
                          : () async {
                              final email = resetEmailController.text.trim();
                              if (email.isEmpty || !email.contains('@')) {
                                setDialogState(() => dialogError =
                                    'Please enter a valid email address.');
                                return;
                              }
                              setDialogState(() {
                                isSending = true;
                                dialogError = null;
                              });
                              final error = await _authService
                                  .sendPasswordResetEmail(email);
                              setDialogState(() {
                                isSending = false;
                                if (error == null) {
                                  dialogSuccess =
                                      'Reset link sent! Please check your email.';
                                } else {
                                  dialogError = friendlyErrorMessage(error);
                                }
                              });
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.dark,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: isSending
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Send Reset Link',
                              style: TextStyle(color: Colors.white)),
                    ),
                ],
              ),
            ],
          );
        },
      ),
      actions: const [],
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _authService.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success']) {
      final actualRole = result['role'] as String?;
      final Widget destination;

      switch (actualRole) {
        case 'admin':
          destination = const AdminDashboardScreen();
          break;
        case 'technician':
          destination = TechnicianMainNav(
            technicianDocId: result['technicianDocId'] as String?,
          );
          break;
        default:
          destination = const MainNavScreen();
      }

      // Wipe the whole back stack (Welcome + Login) so pressing Back from the
      // home screen exits the app instead of returning to the login pages.
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => destination),
        (route) => false,
      );
    } else {
      final authError = _authService.friendlyError(result['error']);
      setState(() => _errorMessage = authError.isNotEmpty
          ? authError
          : friendlyErrorMessage(result['error']));
    }
  }

  String get _greeting {
    switch (_selectedRole) {
      case 'technician':
        return 'Hello, technician!';
      case 'admin':
        return 'Hello, admin!';
      default:
        return 'Hello, customer!';
    }
  }

  /// Sign-up / setup link that matches the selected role.
  Widget _roleFooter() {
    String? prompt;
    String? action;
    Widget Function()? screen;

    switch (_selectedRole) {
      case 'technician':
        prompt = 'Have an invite code? ';
        action = 'Set up technician account';
        screen = () => const TechnicianAccountSetupScreen();
        break;
      case 'admin':
        if (_adminExists) {
          return const Text(
            'Admin accounts are created during shop setup.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: AppColors.fontCaption, color: AppColors.textGray),
          );
        }
        prompt = 'New shop? ';
        action = 'Set up your shop';
        screen = () => const AdminRegisterScreen();
        break;
      default:
        prompt = "Don't have an account? ";
        action = 'Sign up';
        screen = () => const CustomerRegisterScreen();
    }

    // Wrap (not Row) so longer wording drops to a second line instead of
    // overflowing the card.
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(prompt,
            style: const TextStyle(
                fontSize: AppColors.fontLabel, color: AppColors.textGray)),
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => screen!()),
          ),
          child: Text(
            action,
            style: const TextStyle(
              fontSize: AppColors.fontLabel,
              color: AppColors.textDark,
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 448),
                child: Column(
                  children: [
                    // Back button
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back),
                      ),
                    ),
                    const Text(
                      'Choose Account Type',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 20),

                    Row(
                      children: [
                        Expanded(
                          child: _RoleCard(
                            icon: Icons.person_rounded,
                            label: 'Customer',
                            selected: _selectedRole == 'customer',
                            onTap: () => setState(() {
                              _selectedRole = 'customer';
                              _errorMessage = null;
                            }),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _RoleCard(
                            icon: Icons.build_rounded,
                            label: 'Technician',
                            selected: _selectedRole == 'technician',
                            onTap: () => setState(() {
                              _selectedRole = 'technician';
                              _errorMessage = null;
                            }),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _RoleCard(
                            icon: Icons.shield_rounded,
                            label: 'Admin',
                            selected: _selectedRole == 'admin',
                            onTap: () => setState(() {
                              _selectedRole = 'admin';
                              _errorMessage = null;
                            }),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Login Card
                    Card(
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_greeting,
                                  style: const TextStyle(
                                      fontSize: AppColors.fontTitle,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              const Text(
                                'Please fill out the form below to get started',
                                style: TextStyle(
                                    fontSize: AppColors.fontSubtitle,
                                    color: AppColors.textGray),
                              ),
                              const SizedBox(height: 24),

                              if (_errorMessage != null)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: AppColors.dangerBg,
                                    borderRadius: BorderRadius.circular(8),
                                    border:
                                        Border.all(color: AppColors.danger),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.error_outline,
                                          color: AppColors.danger, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(_errorMessage!,
                                            style: const TextStyle(
                                                color: AppColors.danger,
                                                fontSize:
                                                    AppColors.fontLabel)),
                                      ),
                                    ],
                                  ),
                                ),

                              // Email
                              const Text('Email Address',
                                  style: TextStyle(
                                      fontSize: AppColors.fontLabel,
                                      fontWeight: FontWeight.w500)),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  hintText: 'juan@example.com',
                                  prefixIcon:
                                      const Icon(Icons.email_outlined),
                                  border: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(8)),
                                ),
                                validator: (v) => v == null || v.isEmpty
                                    ? 'Please enter your email'
                                    : null,
                              ),
                              const SizedBox(height: 16),

                              // Password
                              const Text('Password',
                                  style: TextStyle(
                                      fontSize: AppColors.fontLabel,
                                      fontWeight: FontWeight.w500)),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: !_isPasswordVisible,
                                decoration: InputDecoration(
                                  hintText: 'Enter your password',
                                  prefixIcon:
                                      const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    icon: Icon(_isPasswordVisible
                                        ? Icons.visibility_off
                                        : Icons.visibility),
                                    onPressed: () => setState(() =>
                                        _isPasswordVisible =
                                            !_isPasswordVisible),
                                  ),
                                  border: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(8)),
                                ),
                                validator: (v) => v == null || v.isEmpty
                                    ? 'Please enter your password'
                                    : null,
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: GestureDetector(
                                  onTap: _showForgotPasswordDialog,
                                  child: const Text(
                                    'Forgot Password?',
                                    style: TextStyle(
                                      fontSize: AppColors.fontCaption,
                                      color: AppColors.dark,
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Login Button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed:
                                      _isLoading ? null : _handleLogin,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.dark,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(8)),
                                  ),
                                  child: _isLoading
                                      ? const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            SizedBox(
                                              height: 18,
                                              width: 18,
                                              child:
                                                  CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            ),
                                            SizedBox(width: 10),
                                            Text('Signing in...',
                                                style: TextStyle(
                                                    fontSize:
                                                        AppColors.fontBody,
                                                    fontWeight:
                                                        FontWeight.w600,
                                                    color: Colors.white)),
                                          ],
                                        )
                                      : const Text('Sign In',
                                          style: TextStyle(
                                              fontSize: AppColors.fontBody,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white)),
                                ),
                              ),
                              const SizedBox(height: 24),
                              const Divider(),
                              const SizedBox(height: 16),

                              Center(child: _roleFooter()),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              color: selected ? AppColors.dark : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? AppColors.dark : const Color(0xFFE1E4E8),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: selected ? 0.15 : 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(icon,
                    size: 30,
                    color: selected ? Colors.white : AppColors.textGray),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: AppColors.fontLabel,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
          if (selected)
            Positioned(
              top: -6,
              right: -6,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle,
                    size: 20, color: AppColors.success),
              ),
            ),
        ],
      ),
    );
  }
}
