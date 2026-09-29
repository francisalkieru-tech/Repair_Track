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
            builder: (_) => const LoginScreen(role: 'customer')),
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

                    // Animated Logo
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
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          repeat: false,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Create Account',
                      style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Register as a new customer',
                      style: TextStyle(
                          fontSize: AppColors.fontSubtitle,
                          color: AppColors.textGray),
                    ),
                    const SizedBox(height: 24),

                    // Register Card
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
                              const Text('Customer Registration',
                                  style: TextStyle(
                                      fontSize: AppColors.fontTitle,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              const Text(
                                'Fill in your details to get started',
                                style: TextStyle(
                                    fontSize: AppColors.fontSubtitle,
                                    color: AppColors.textGray),
                              ),
                              const SizedBox(height: 24),

                              // Error — user-friendly text, may icon para
                              // mas kapansin-pansin sa mata.
                              if (_errorMessage != null)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  margin:
                                      const EdgeInsets.only(bottom: 16),
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

                              // Full Name
                              _buildLabel('Full Name *'),
                              _buildField(
                                controller: _nameController,
                                hint: 'Juan dela Cruz',
                                icon: Icons.person_outline,
                                validator: (v) => v == null || v.isEmpty
                                    ? 'Please enter your name'
                                    : null,
                              ),
                              const SizedBox(height: 16),

                              // Email
                              _buildLabel('Email Address *'),
                              _buildField(
                                controller: _emailController,
                                hint: 'juan@example.com',
                                icon: Icons.email_outlined,
                                keyboard: TextInputType.emailAddress,
                                validator: (v) {
                                  if (v == null || v.isEmpty)
                                    return 'Please enter your email';
                                  if (!v.contains('@'))
                                    return 'Invalid email address';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Contact
                              _buildLabel('Contact Number *'),
                              _buildField(
                                controller: _contactController,
                                hint: '09XXXXXXXXX',
                                icon: Icons.phone_outlined,
                                keyboard: TextInputType.phone,
                                validator: (v) {
                                  if (v == null || v.isEmpty)
                                    return 'Please enter your contact number';
                                  if (v.length != 11)
                                    return 'Contact number must be 11 digits';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Address
                              _buildLabel('Address *'),
                              _buildField(
                                controller: _addressController,
                                hint: 'Barangay, City, Province',
                                icon: Icons.location_on_outlined,
                                validator: (v) => v == null || v.isEmpty
                                    ? 'Please enter your address'
                                    : null,
                              ),
                              const SizedBox(height: 16),

                              // Password
                              _buildLabel('Password *'),
                              _buildPasswordField(
                                controller: _passwordController,
                                hint: 'Minimum 6 characters',
                                isVisible: _isPasswordVisible,
                                onToggle: () => setState(() =>
                                    _isPasswordVisible =
                                        !_isPasswordVisible),
                                validator: (v) {
                                  if (v == null || v.isEmpty)
                                    return 'Please enter a password';
                                  if (v.length < 6)
                                    return 'Password must be at least 6 characters';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Confirm Password
                              _buildLabel('Confirm Password *'),
                              _buildPasswordField(
                                controller: _confirmPasswordController,
                                hint: 'Re-enter your password',
                                isVisible: _isConfirmPasswordVisible,
                                onToggle: () => setState(() =>
                                    _isConfirmPasswordVisible =
                                        !_isConfirmPasswordVisible),
                                validator: (v) =>
                                    v != _passwordController.text
                                        ? 'Passwords do not match'
                                        : null,
                              ),
                              const SizedBox(height: 24),

                              // Register Button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed:
                                      _isLoading ? null : _handleRegister,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.dark,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(8)),
                                  ),
                                  // "Creating account..." habang tumatakbo
                                  // yung registration — mas malinaw kaysa
                                  // bare spinner lang.
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
                                      : const Text('Register',
                                          style: TextStyle(
                                              fontSize: AppColors.fontBody,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white)),
                                ),
                              ),
                              const SizedBox(height: 24),
                              const Divider(),
                              const SizedBox(height: 16),

                              // Login link
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
                                                role: 'customer')),
                                      ),
                                      child: const Text('Sign in here',
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
          border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
            icon: Icon(
                isVisible ? Icons.visibility_off : Icons.visibility),
            onPressed: onToggle,
          ),
          border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        validator: validator,
      );
}