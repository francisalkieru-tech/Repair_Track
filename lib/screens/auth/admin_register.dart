import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../services/auth_service.dart';
import 'login_screen.dart';
import '../../utils/colors.dart';
import '../../utils/ui_widgets.dart';


class AdminRegisterScreen extends StatefulWidget {
  const AdminRegisterScreen({super.key});

  @override
  State<AdminRegisterScreen> createState() => _AdminRegisterScreenState();
}

class _AdminRegisterScreenState extends State<AdminRegisterScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  late AnimationController _lottieController;

  final _shopNameController = TextEditingController();
  final _shopAddressController = TextEditingController();
  final _emailController = TextEditingController();
  final _contactController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _lottieController = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _shopAddressController.dispose();
    _emailController.dispose();
    _contactController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _lottieController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    String? error = await _authService.registerAdmin(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      name: _shopNameController.text.trim(), // shop name as display name
      shopName: _shopNameController.text.trim(),
      shopAddress: _shopAddressController.text.trim(),
      contactNumber: _contactController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Admin account created! Please login.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen(role: 'admin')),
      );
    } else {
      final message = error.contains('permission-denied')
          ? 'Admin registration is closed. An admin account already exists — please sign in instead.'
          : (_authService.friendlyError(error).isNotEmpty
              ? _authService.friendlyError(error)
              : friendlyErrorMessage(error));
      setState(() => _errorMessage = message);
    }
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
                    const SizedBox(height: 8),

                    // Animated Logo — play once lang
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

                    const Text(
                      'Admin Registration',
                      style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Setup your repair shop account (one-time only)',
                      style: TextStyle(
                          fontSize: AppColors.fontSubtitle,
                          color: AppColors.textGray),
                    ),
                    const SizedBox(height: 24),

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
                              // Info banner
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFFBEB),
                                  borderRadius: BorderRadius.circular(8),
                                  border:
                                      Border.all(color: const Color(0xFFFCD34D)),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.info_outline,
                                        color: Color(0xFFD97706), size: 20),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'This is only for authorized repair shop admins.',
                                        style: TextStyle(
                                            fontSize: AppColors.fontLabel,
                                            color: Color(0xFF92400E)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Error — user-friendly message lang, may
                              // icon para agad mapansin.
                              if (_errorMessage != null)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: AppColors.dangerBg,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: AppColors.danger),
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

                              _buildLabel('Shop Name *'),
                              _buildField(
                                  controller: _shopNameController,
                                  hint: 'AllFix Repair Shop',
                                  icon: Icons.store_outlined,
                                  validator: (v) => v == null || v.isEmpty
                                      ? 'Please enter shop name'
                                      : null),
                              const SizedBox(height: 16),

                              _buildLabel('Shop Address *'),
                              _buildField(
                                  controller: _shopAddressController,
                                  hint: 'Barangay, City, Province',
                                  icon: Icons.location_on_outlined,
                                  validator: (v) => v == null || v.isEmpty
                                      ? 'Please enter shop address'
                                      : null),
                              const SizedBox(height: 16),

                              _buildLabel('Shop Email Address *'),
                              _buildField(
                                  controller: _emailController,
                                  hint: 'shop@example.com',
                                  icon: Icons.email_outlined,
                                  keyboard: TextInputType.emailAddress,
                                  validator: (v) {
                                    if (v == null || v.isEmpty) {
                                      return 'Please enter email';
                                    }
                                    if (!v.contains('@')) {
                                      return 'Invalid email format';
                                    }
                                    return null;
                                  }),
                              const SizedBox(height: 16),

                              _buildLabel('Shop Contact Number *'),
                              _buildField(
                                  controller: _contactController,
                                  hint: '09XXXXXXXXX',
                                  icon: Icons.phone_outlined,
                                  keyboard: TextInputType.phone,
                                  validator: (v) {
                                    if (v == null || v.isEmpty) {
                                      return 'Please enter contact number';
                                    }
                                    if (v.length != 11) {
                                      return 'Please enter a valid 11-digit number';
                                    }
                                    return null;
                                  }),
                              const SizedBox(height: 16),

                              _buildLabel('Password *'),
                              _buildPasswordField(
                                controller: _passwordController,
                                hint: 'Minimum 6 characters',
                                isVisible: _isPasswordVisible,
                                onToggle: () => setState(
                                    () => _isPasswordVisible =
                                        !_isPasswordVisible),
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Please enter password';
                                  }
                                  if (v.length < 6) {
                                    return 'Minimum 6 characters';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              _buildLabel('Confirm Password *'),
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
                              const SizedBox(height: 24),

                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _register,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.dark,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(8)),
                                  ),
                                  // "Creating account..." habang tumatakbo
                                  // yung registration, hindi lang spinner.
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
                                                      color: Colors.white),
                                            ),
                                            SizedBox(width: 10),
                                            Text('Creating account...',
                                                style: TextStyle(
                                                    fontSize:
                                                        AppColors.fontBody,
                                                    fontWeight:
                                                        FontWeight.w600,
                                                    color: Colors.white)),
                                          ],
                                        )
                                      : const Text('Create Admin Account',
                                          style: TextStyle(
                                              fontSize: AppColors.fontBody,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white)),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Divider(),
                              const SizedBox(height: 12),
                              Center(
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    const Text('Already have an account? ',
                                        style: TextStyle(
                                            fontSize: AppColors.fontLabel,
                                            color: AppColors.textGray)),
                                    GestureDetector(
                                      onTap: () => Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) => const LoginScreen(
                                                role: 'admin')),
                                      ),
                                      child: const Text('Sign in',
                                          style: TextStyle(
                                              fontSize: AppColors.fontLabel,
                                              color: AppColors.textDark,
                                              fontWeight: FontWeight.bold,
                                              decoration: TextDecoration
                                                  .underline)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                fontSize: AppColors.fontLabel, fontWeight: FontWeight.w500)),
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
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.lock_outline),
          suffixIcon: IconButton(
            icon: Icon(isVisible ? Icons.visibility_off : Icons.visibility),
            onPressed: onToggle,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        validator: validator,
      );
}