import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../services/auth_service.dart';
import 'login_screen.dart';

class AdminRegisterScreen extends StatefulWidget {
  const AdminRegisterScreen({super.key});

  @override
  State<AdminRegisterScreen> createState() => _AdminRegisterScreenState();
}

class _AdminRegisterScreenState extends State<AdminRegisterScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  int _currentStep = 1;
  bool _isLoading = false;
  late AnimationController _lottieController;

  // Step 1
  final _contactForCodeController = TextEditingController();

  // Step 2
  final _formKey = GlobalKey<FormState>();
  final _shopNameController = TextEditingController();
  final _shopAddressController = TextEditingController();
  final _emailController = TextEditingController();
  final _contactController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _codeController = TextEditingController();
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
    _contactForCodeController.dispose();
    _shopNameController.dispose();
    _shopAddressController.dispose();
    _emailController.dispose();
    _contactController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _codeController.dispose();
    _lottieController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final contact = _contactForCodeController.text.trim();
    if (contact.isEmpty || contact.length != 11) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 11-digit contact number.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    String? error = await _authService.sendAdminCode(contact);
    setState(() => _isLoading = false);

    if (!mounted) return;

    if (error == null) {
      _contactController.text = contact;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification code sent! Check your SMS.'),
          backgroundColor: Colors.green,
        ),
      );
      setState(() => _currentStep = 2);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _verifyAndRegister() async {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    String? verifyError = await _authService.verifyAdminCode(
      _contactController.text.trim(),
      _codeController.text.trim(),
    );

    if (verifyError != null) {
      setState(() {
        _isLoading = false;
        _errorMessage = verifyError;
      });
      return;
    }

    String? error = await _authService.registerAdmin(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      name: _shopNameController.text.trim(), // shop name as display name
      shopName: _shopNameController.text.trim(),
      shopAddress: _shopAddressController.text.trim(),
      contactNumber: _contactController.text.trim(),
    );

    setState(() => _isLoading = false);
    if (!mounted) return;

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
      setState(() => _errorMessage = _authService.friendlyError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEFF6FF), Color(0xFFE0E7FF)],
          ),
        ),
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
                        color: const Color.fromARGB(255, 0, 4, 255),
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
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827)),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Setup your repair shop account',
                      style: TextStyle(fontSize: 14, color: Color(0xFF4B5563)),
                    ),
                    const SizedBox(height: 24),

                    // Step indicator
                    Row(
                      children: [
                        _StepIndicator(
                            number: 1,
                            label: 'Verify',
                            isActive: _currentStep == 1,
                            isDone: _currentStep > 1),
                        Expanded(
                          child: Container(
                            height: 2,
                            color: _currentStep > 1
                                ? const Color.fromARGB(255, 0, 4, 255)
                                : const Color(0xFFE5E7EB),
                          ),
                        ),
                        _StepIndicator(
                            number: 2,
                            label: 'Register',
                            isActive: _currentStep == 2,
                            isDone: false),
                      ],
                    ),
                    const SizedBox(height: 24),

                    _currentStep == 1 ? _buildStep1() : _buildStep2(),
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

  Widget _buildStep1() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Verify your number',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'We will send a verification code to your shop contact number.',
              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 20),

            // Info banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFCD34D)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFFD97706), size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This is only for authorized repair shop admins.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF92400E)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            const Text('Shop Contact Number',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _contactForCodeController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: '09XXXXXXXXX',
                prefixIcon: const Icon(Icons.phone_outlined),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _sendCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 0, 4, 255),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Send Verification Code',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Already have an account? ',
                      style:
                          TextStyle(fontSize: 14, color: Color(0xFF4B5563))),
                  GestureDetector(
                    onTap: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const LoginScreen(role: 'admin')),
                    ),
                    child: const Text('Sign in',
                        style: TextStyle(
                            fontSize: 14,
                            color: Color.fromARGB(255, 0, 4, 255),
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Setup Shop Account',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                'Code sent to ${_contactForCodeController.text}',
                style:
                    const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 24),

              // Error
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFEF4444)),
                  ),
                  child: Text(_errorMessage!,
                      style: const TextStyle(
                          color: Color(0xFFDC2626), fontSize: 14)),
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
                    if (v == null || v.isEmpty) return 'Please enter email';
                    if (!v.contains('@')) return 'Invalid email format';
                    return null;
                  }),
              const SizedBox(height: 16),

              // Contact number — pre-filled from Step 1, read only
              _buildLabel('Shop Contact Number'),
              TextFormField(
                controller: _contactController,
                readOnly: true,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.phone_outlined),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 16),

              _buildLabel('Password *'),
              _buildPasswordField(
                controller: _passwordController,
                hint: 'Minimum 6 characters',
                isVisible: _isPasswordVisible,
                onToggle: () =>
                    setState(() => _isPasswordVisible = !_isPasswordVisible),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Please enter password';
                  if (v.length < 6) return 'Minimum 6 characters';
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
                    _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
                validator: (v) => v != _passwordController.text
                    ? 'Passwords do not match'
                    : null,
              ),
              const SizedBox(height: 16),

              _buildLabel('Verification Code (from SMS) *'),
              TextFormField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: '6-digit code',
                  prefixIcon: const Icon(Icons.sms_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                validator: (v) => v == null || v.isEmpty
                    ? 'Please enter the code from SMS'
                    : null,
              ),
              const SizedBox(height: 8),

              GestureDetector(
                onTap: () => setState(() => _currentStep = 1),
                child: const Text(
                  "Didn't receive the code? Resend",
                  style: TextStyle(color: Color.fromARGB(255, 0, 4, 255), fontSize: 13),
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyAndRegister,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 0, 4, 255),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Create Admin Account',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Already have an account? ',
                        style: TextStyle(
                            fontSize: 14, color: Color(0xFF4B5563))),
                    GestureDetector(
                      onTap: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const LoginScreen(role: 'admin')),
                      ),
                      child: const Text('Sign in',
                          style: TextStyle(
                              fontSize: 14,
                              color: Color.fromARGB(255, 0, 4, 255),
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
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

class _StepIndicator extends StatelessWidget {
  final int number;
  final String label;
  final bool isActive;
  final bool isDone;

  const _StepIndicator({
    required this.number,
    required this.label,
    required this.isActive,
    required this.isDone,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor = isActive || isDone
        ? const Color.fromARGB(255, 0, 4, 255)
        : const Color(0xFFE5E7EB);
    Color textColor =
        isActive || isDone ? Colors.white : const Color(0xFF9CA3AF);

    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
          child: Center(
            child: isDone
                ? const Icon(Icons.check, color: Colors.white, size: 16)
                : Text('$number',
                    style: TextStyle(
                        color: textColor, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                color: isActive || isDone
                    ? const Color.fromARGB(255, 0, 4, 255)
                    : const Color(0xFF9CA3AF))),
      ],
    );
  }
}