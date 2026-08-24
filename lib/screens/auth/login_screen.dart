import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../customer/main_nav_screen.dart';
import '../admin/admin_dashboard.dart';
import 'customer_register_screen.dart';
import 'admin_register.dart';

class LoginScreen extends StatefulWidget {
  final String role;
  const LoginScreen({super.key, required this.role});

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
  bool _adminExists = true;
  bool _checkedAdminExists = false;

  @override
  void initState() {
    super.initState();
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
    } catch (_) {
      if (!mounted) return;
      setState(() => _checkedAdminExists = true);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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
        setState(() => _errorMessage = widget.role == 'admin'
            ? 'This is not an admin account. Use Customer Login.'
            : 'This is an admin account. Use Admin Login.');
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
      setState(
        () => _errorMessage = _authService.friendlyError(result['error']),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.role == 'admin';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(15, 12, 15, 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 390),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                      icon: const Icon(Icons.arrow_back, size: 16),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const _RepairLogo(size: 58),
                  const SizedBox(height: 7),
                  Text(
                    isAdmin ? 'Admin Login' : 'Customer Login',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    isAdmin
                        ? 'Manage repair requests and customers'
                        : 'Sign in to track your repairs',
                    style: const TextStyle(
                      fontSize: 7,
                      color: Color(0xFF777777),
                    ),
                  ),
                  const SizedBox(height: 13),
                  _LoginCard(
                    formKey: _formKey,
                    isAdmin: isAdmin,
                    emailController: _emailController,
                    passwordController: _passwordController,
                    passwordVisible: _isPasswordVisible,
                    onTogglePassword: () => setState(
                      () => _isPasswordVisible = !_isPasswordVisible,
                    ),
                    isLoading: _isLoading,
                    errorMessage: _errorMessage,
                    showRegister: !isAdmin || !_adminExists,
                    onLogin: _handleLogin,
                    onRegister: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => isAdmin
                            ? const AdminRegisterScreen()
                            : const CustomerRegisterScreen(),
                      ),
                    ),
                  ),
                  if (isAdmin && !_checkedAdminExists)
                    const SizedBox(height: 1),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RepairLogo extends StatelessWidget {
  final double size;

  const _RepairLogo({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(size * .18),
      ),
      child: Icon(
        Icons.build_outlined,
        color: Colors.white,
        size: size * .62,
      ),
    );
  }
}

class _LoginCard extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final bool isAdmin;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool passwordVisible;
  final VoidCallback onTogglePassword;
  final bool isLoading;
  final String? errorMessage;
  final bool showRegister;
  final VoidCallback onLogin;
  final VoidCallback onRegister;

  const _LoginCard({
    required this.formKey,
    required this.isAdmin,
    required this.emailController,
    required this.passwordController,
    required this.passwordVisible,
    required this.onTogglePassword,
    required this.isLoading,
    required this.errorMessage,
    required this.showRegister,
    required this.onLogin,
    required this.onRegister,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 11, 10, 9),
      decoration: BoxDecoration(
        color: const Color(0xFFE7E7E7),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0xFFD0D0D0)),
        boxShadow: const [
          BoxShadow(color: Color(0x22000000), blurRadius: 3, offset: Offset(0, 2)),
        ],
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Welcome Back',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 1),
            const Text(
              'Enter your credentials to access your account',
              style: TextStyle(fontSize: 6.5, color: Color(0xFF777777)),
            ),
            const SizedBox(height: 10),
            if (errorMessage != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(7),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE8E8),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFE57373)),
                ),
                child: Text(
                  errorMessage!,
                  style: const TextStyle(fontSize: 7, color: Color(0xFFB71C1C)),
                ),
              ),
            ],
            _label(isAdmin ? 'Shop Email Address' : 'Email Address'),
            const SizedBox(height: 3),
            _input(
              controller: emailController,
              hint: 'juan@example.com',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (v) => v == null || v.isEmpty
                  ? 'Please enter your email'
                  : null,
            ),
            const SizedBox(height: 8),
            _label('Password'),
            const SizedBox(height: 3),
            _input(
              controller: passwordController,
              hint: 'Enter your password',
              icon: Icons.lock_outline,
              obscureText: !passwordVisible,
              suffix: IconButton(
                onPressed: onTogglePassword,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                icon: Icon(
                  passwordVisible ? Icons.visibility_off : Icons.visibility,
                  size: 15,
                  color: const Color(0xFF555555),
                ),
              ),
              validator: (v) => v == null || v.isEmpty
                  ? 'Please enter your password'
                  : null,
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 31,
              child: ElevatedButton(
                onPressed: isLoading ? null : onLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 14,
                        width: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Sign In',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
                      ),
              ),
            ),
            if (showRegister) ...[
              const SizedBox(height: 10),
              const Divider(height: 1, color: Color(0xFFBBBBBB)),
              const SizedBox(height: 7),
              Center(
                child: GestureDetector(
                  onTap: onRegister,
                  child: Text.rich(
                    TextSpan(
                      text: isAdmin ? 'New Shop? ' : "Don't have an account? ",
                      style: const TextStyle(fontSize: 6.5, color: Color(0xFF777777)),
                      children: const [
                        TextSpan(
                          text: 'Register here',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 7, fontWeight: FontWeight.w600),
    );
  }

  Widget _input({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffix,
  }) {
    return SizedBox(
      height: 30,
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        validator: validator,
        style: const TextStyle(fontSize: 7.5),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 7, color: Color(0xFF999999)),
          prefixIcon: Icon(icon, size: 14, color: Colors.black),
          suffixIcon: suffix,
          prefixIconConstraints: const BoxConstraints(minWidth: 27),
          suffixIconConstraints: const BoxConstraints(minWidth: 28),
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: Color(0xFFD2D2D2)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: Color(0xFFD2D2D2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: Colors.black, width: 1),
          ),
        ),
      ),
    );
  }
}
