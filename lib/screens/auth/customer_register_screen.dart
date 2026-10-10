import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../services/auth_service.dart';
import 'login_screen.dart';
import '../../utils/colors.dart';
import '../../utils/ui_widgets.dart';

class CustomerRegisterScreen extends StatefulWidget {
  const CustomerRegisterScreen({super.key});

  @override
  State<CustomerRegisterScreen> createState() =>
      _CustomerRegisterScreenState();
}

class _CustomerRegisterScreenState extends State<CustomerRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _contactController = TextEditingController();
  final _addressController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _contactController.dispose();
    _addressController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    String? error = await _authService.registerCustomer(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      name: _nameController.text.trim(),
      contactNumber: _contactController.text.trim(),
      address: _addressController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) => const LoginScreen()),
      );
    } else {
      final authError = _authService.friendlyError(error);
      setState(() => _errorMessage =
          authError.isNotEmpty ? authError : friendlyErrorMessage(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Same soft gray background as the settings screens
      backgroundColor: const Color(0xFFF6F7F9),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back button
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back,
                            color: AppColors.textDark),
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Header: logo + title
                    Center(child: _logo()),
                    const SizedBox(height: 16),
                    const Center(
                      child: Text(
                        'Create Account',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Center(
                      child: Text(
                        'Register as a customer to request and track repairs.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: AppColors.fontLabel,
                          color: AppColors.textGray,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Error message (user-friendly text)
                    if (_errorMessage != null) ...[
                      _errorBox(_errorMessage!),
                      const SizedBox(height: 14),
                    ],

                    // Section 1: personal details
                    _sectionCard(
                      icon: Icons.person_outline,
                      title: 'Your Details',
                      subtitle: 'We use these so the shop can reach you.',
                      children: [
                        _buildLabel('Full Name'),
                        _buildField(
                          controller: _nameController,
                          hint: 'Juan dela Cruz',
                          icon: Icons.person_outline,
                          validator: (v) => v == null || v.isEmpty
                              ? 'Please enter your name'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        _buildLabel('Email Address'),
                        _buildField(
                          controller: _emailController,
                          hint: 'juan@example.com',
                          icon: Icons.email_outlined,
                          keyboard: TextInputType.emailAddress,
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Please enter your email';
                            }
                            // Basic shape check: name@domain.tld, no spaces.
                            if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$')
                                .hasMatch(v.trim())) {
                              return 'Invalid email address';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildLabel('Contact Number'),
                        _buildField(
                          controller: _contactController,
                          hint: '09XXXXXXXXX',
                          icon: Icons.phone_outlined,
                          keyboard: TextInputType.phone,
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Please enter your contact number';
                            }
                            // Same rule as the repair request form: digits
                            // only, 11 long, starting with 09 (PH mobile).
                            if (!RegExp(r'^[0-9]+$').hasMatch(v)) {
                              return 'Numbers only, e.g. 09XXXXXXXXX';
                            }
                            if (v.length != 11 || !v.startsWith('09')) {
                              return 'Enter a valid number, e.g. 09XXXXXXXXX';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildLabel('Address'),
                        _buildField(
                          controller: _addressController,
                          hint: 'Barangay, City, Province',
                          icon: Icons.location_on_outlined,
                          validator: (v) => v == null || v.isEmpty
                              ? 'Please enter your address'
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Section 2: password
                    _sectionCard(
                      icon: Icons.lock_outline,
                      title: 'Password',
                      subtitle: 'Use at least 6 characters.',
                      children: [
                        _buildLabel('Password'),
                        _buildPasswordField(
                          controller: _passwordController,
                          hint: 'Minimum 6 characters',
                          isVisible: _isPasswordVisible,
                          onToggle: () => setState(() =>
                              _isPasswordVisible = !_isPasswordVisible),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Please enter a password';
                            }
                            if (v.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildLabel('Confirm Password'),
                        _buildPasswordField(
                          controller: _confirmPasswordController,
                          hint: 'Re-enter your password',
                          isVisible: _isConfirmPasswordVisible,
                          onToggle: () => setState(() =>
                              _isConfirmPasswordVisible =
                                  !_isConfirmPasswordVisible),
                          validator: (v) => v != _passwordController.text
                              ? 'Passwords do not match'
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Register button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleRegister,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.dark,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isLoading
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  ),
                                  SizedBox(width: 10),
                                  Text('Creating account...',
                                      style: TextStyle(
                                          fontSize: AppColors.fontBody,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white)),
                                ],
                              )
                            : const Text('Create Account',
                                style: TextStyle(
                                    fontSize: AppColors.fontBody,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Login link
                    Center(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text('Already have an account? ',
                              style: TextStyle(
                                  fontSize: AppColors.fontLabel,
                                  color: AppColors.textGray)),
                          GestureDetector(
                            onTap: () => Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const LoginScreen()),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text('Sign in here',
                                  style: TextStyle(
                                      fontSize: AppColors.fontLabel,
                                      color: AppColors.textDark,
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline)),
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
        ),
      ),
    );
  }

  // App logo (same animated logo as before)
  Widget _logo() => Container(
        width: 76,
        height: 76,
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
            width: 76,
            height: 76,
            fit: BoxFit.cover,
            repeat: false,
          ),
        ),
      );

  // Error banner
  Widget _errorBox(String message) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.dangerBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.danger),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline,
                color: AppColors.danger, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message,
                  style: const TextStyle(
                      color: AppColors.danger,
                      fontSize: AppColors.fontLabel)),
            ),
          ],
        ),
      );

  // Section card: icon header + divider + fields (matches settings screens)
  Widget _sectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) =>
      Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x07000000),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon,
                        size: 20, color: const Color(0xFF374151)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(
                                fontSize: AppColors.fontBody,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark)),
                        const SizedBox(height: 2),
                        Text(subtitle,
                            style: const TextStyle(
                                fontSize: AppColors.fontCaption,
                                color: AppColors.textGray)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
          ],
        ),
      );

  Widget _buildLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                fontSize: AppColors.fontLabel,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151))),
      );

  // Shared input look: 12px radius, dark focus border
  InputDecoration _decoration({
    required String hint,
    required Widget prefix,
    Widget? suffix,
  }) =>
      InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(fontSize: 15, color: Color(0xFF9CA3AF)),
        prefixIcon: prefix,
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDDE1E6)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDDE1E6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.dark, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.4),
        ),
      );

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboard = TextInputType.text,
    required String? Function(String?) validator,
  }) =>
      TextFormField(
        controller: controller,
        keyboardType: keyboard,
        style: const TextStyle(fontSize: 15, color: AppColors.textDark),
        decoration: _decoration(
          hint: hint,
          prefix: Icon(icon, size: 20, color: const Color(0xFF6B7280)),
        ),
        validator: validator,
      );

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hint,
    required bool isVisible,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
  }) =>
      TextFormField(
        controller: controller,
        obscureText: !isVisible,
        style: const TextStyle(fontSize: 15, color: AppColors.textDark),
        decoration: _decoration(
          hint: hint,
          prefix: const Icon(Icons.lock_outline,
              size: 20, color: Color(0xFF6B7280)),
          suffix: IconButton(
            icon: Icon(
              isVisible
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size: 20,
              color: const Color(0xFF6B7280),
            ),
            onPressed: onToggle,
          ),
        ),
        validator: validator,
      );
}
