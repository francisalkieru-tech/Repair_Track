import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
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
import '../../utils/ui_widgets.dart';

class LoginScreen extends StatefulWidget {
  final String role;
  const LoginScreen({super.key, required this.role});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  String? _errorMessage;
  late AnimationController _lottieController;

  bool _adminExists = true;
  bool _checkedAdminExists = false;

  @override
  void initState() {
    super.initState();
    _lottieController = AnimationController(vsync: this);
    if (widget.role == 'admin') {
      _checkIfAdminExists();
    }
  }

  Future<void> _checkIfAdminExists() async {
    try {
      final lockDoc = await FirebaseFirestore.instance
          .collection('adminSetup')
          .doc('lock')
          .get();
      if (!mounted) return;
      setState(() {
        _adminExists = lockDoc.exists;
        _checkedAdminExists = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _checkedAdminExists = true;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _lottieController.dispose();
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

  String _roleMismatchMessage(String actualRole) {
    const labels = {
      'admin': 'admin',
      'technician': 'technician',
      'customer': 'customer',
    };
    final triedLabel = labels[widget.role] ?? widget.role;
    final actualLabel = labels[actualRole] ?? actualRole;
    return 'This is a $actualLabel account. Use $actualLabel login instead of $triedLabel login.';
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
      final actualRole = result['role'];
      if (actualRole != widget.role) {
        setState(() => _errorMessage = _roleMismatchMessage(actualRole));
        return;
      }

      if (widget.role == 'technician') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => TechnicianMainNav(
              technicianDocId: result['technicianDocId'] as String?,
            ),
          ),
        );
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => widget.role == 'admin'
              ? const AdminDashboardScreen()
              : const MainNavScreen(),
        ),
      );
    } else {
      final authError = _authService.friendlyError(result['error']);
      setState(() => _errorMessage = authError.isNotEmpty
          ? authError
          : friendlyErrorMessage(result['error']));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.role == 'admin';
    final isTechnician = widget.role == 'technician';

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
                    const SizedBox(height: 8),

                    // Animated Logo — play once only
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: AppColors.darkGradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Lottie.asset(
                          'assets/wired-outline-409-tool-in-reveal.json',
                          controller: _lottieController,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          onLoaded: (composition) {
                            _lottieController
                              ..duration = composition.duration
                              ..forward();
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text(
                      isAdmin ? 'Admin Login' : 'Customer Login',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isAdmin
                          ? 'Manage repair requests and customers'
                          : 'Sign in to track your repairs',
                      style: const TextStyle(
                          fontSize: AppColors.fontSubtitle,
                          color: AppColors.textGray),
                    ),
                    const SizedBox(height: 24),

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
                              const Text('Welcome Back',
                                  style: TextStyle(
                                      fontSize: AppColors.fontTitle,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              const Text(
                                'Enter your credentials to access your account',
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
                              Text(isAdmin ? 'Shop Email Address' : 'Email Address',
                                  style: const TextStyle(
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

                              if (isTechnician)
                                Center(
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      const Text(
                                        'First time logging in? ',
                                        style: TextStyle(
                                            fontSize: AppColors.fontLabel,
                                            color: AppColors.textGray),
                                      ),
                                      GestureDetector(
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const TechnicianAccountSetupScreen(),
                                          ),
                                        ),
                                        child: const Text(
                                          'Set up your account',
                                          style: TextStyle(
                                            fontSize: AppColors.fontLabel,
                                            color: AppColors.textDark,
                                            fontWeight: FontWeight.bold,
                                            decoration:
                                                TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else if (!isAdmin || (isAdmin && !_adminExists))
                                Center(
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        isAdmin
                                            ? 'New Shop? '
                                            : "Don't have an account? ",
                                        style: const TextStyle(
                                            fontSize: AppColors.fontLabel,
                                            color: AppColors.textGray),
                                      ),
                                      GestureDetector(
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => isAdmin
                                                ? const AdminRegisterScreen()
                                                : const CustomerRegisterScreen(),
                                          ),
                                        ),
                                        child: const Text(
                                          'Register here',
                                          style: TextStyle(
                                            fontSize: AppColors.fontLabel,
                                            color: AppColors.textDark,
                                            fontWeight: FontWeight.bold,
                                            decoration:
                                                TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
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