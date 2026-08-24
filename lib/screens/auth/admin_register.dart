import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'login_screen.dart';

// One-time admin setup screen — walang na SMS verification step, dahil
// naka-enforce na ang "isang beses lang" na registration sa Firestore
// rules mismo (adminSetup/lock). Kapag na-register na ang unang admin,
// awtomatikong mawawala/mababalak ang link papunta dito.
class AdminRegisterScreen extends StatefulWidget {
  const AdminRegisterScreen({super.key});

  @override
  State<AdminRegisterScreen> createState() => _AdminRegisterScreenState();
}

class _AdminRegisterScreenState extends State<AdminRegisterScreen> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
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
  void dispose() {
    _shopNameController.dispose();
    _shopAddressController.dispose();
    _emailController.dispose();
    _contactController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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
      // Kadalasang error dito kapag may nauna nang admin: yung Firestore
      // rule (adminSetup/lock) ang bumlock, hindi yung AuthService — kaya
      // manual nating hawakan yung message na ito para malinaw sa user.
      final message = error.contains('permission-denied')
          ? 'Admin registration is closed. An admin account already exists — please sign in instead.'
          : _authService.friendlyError(error);
      setState(() => _errorMessage = message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(15, 10, 15, 18),
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
                  const SizedBox(height: 7),
                  const _RepairLogo(size: 58),
                  const SizedBox(height: 7),
                  const Text(
                    'Admin Registration',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 1),
                  const Text(
                    'Setup your repair shop account (one-time only)',
                    style: TextStyle(fontSize: 7, color: Color(0xFF777777)),
                  ),
                  const SizedBox(height: 12),
                  _AdminCard(
                    formKey: _formKey,
                    errorMessage: _errorMessage,
                    isLoading: _isLoading,
                    passwordVisible: _isPasswordVisible,
                    confirmPasswordVisible: _isConfirmPasswordVisible,
                    onTogglePassword: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                    onToggleConfirmPassword: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
                    onRegister: _register,
                    onSignIn: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen(role: 'admin')),
                    ),
                    shopNameController: _shopNameController,
                    shopAddressController: _shopAddressController,
                    emailController: _emailController,
                    contactController: _contactController,
                    passwordController: _passwordController,
                    confirmPasswordController: _confirmPasswordController,
                  ),
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
      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(size * .18)),
      child: Icon(Icons.build_outlined, color: Colors.white, size: size * .62),
    );
  }
}

class _AdminCard extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final String? errorMessage;
  final bool isLoading;
  final bool passwordVisible;
  final bool confirmPasswordVisible;
  final VoidCallback onTogglePassword;
  final VoidCallback onToggleConfirmPassword;
  final VoidCallback onRegister;
  final VoidCallback onSignIn;
  final TextEditingController shopNameController;
  final TextEditingController shopAddressController;
  final TextEditingController emailController;
  final TextEditingController contactController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;

  const _AdminCard({
    required this.formKey,
    required this.errorMessage,
    required this.isLoading,
    required this.passwordVisible,
    required this.confirmPasswordVisible,
    required this.onTogglePassword,
    required this.onToggleConfirmPassword,
    required this.onRegister,
    required this.onSignIn,
    required this.shopNameController,
    required this.shopAddressController,
    required this.emailController,
    required this.contactController,
    required this.passwordController,
    required this.confirmPasswordController,
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
        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 3, offset: Offset(0, 2))],
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Admin Registration', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            const SizedBox(height: 1),
            const Text('Setup your repair shop account', style: TextStyle(fontSize: 6.5, color: Color(0xFF777777))),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4C7),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFE4C45A)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Color(0xFF8A6A00), size: 13),
                  SizedBox(width: 5),
                  Expanded(child: Text('This is only for authorized repair shop admins.', style: TextStyle(fontSize: 6.5, color: Color(0xFF735B00)))),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (errorMessage != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: const Color(0xFFFFE8E8), borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFFE57373))),
                child: Text(errorMessage!, style: const TextStyle(fontSize: 7, color: Color(0xFFB71C1C))),
              ),
              const SizedBox(height: 7),
            ],
            _field('Shop Name *', shopNameController, 'AllFix Repair Shop', Icons.store_outlined, (v) => v == null || v.isEmpty ? 'Please enter shop name' : null),
            const SizedBox(height: 6),
            _field('Shop Address *', shopAddressController, 'Barangay, City, Province', Icons.location_on_outlined, (v) => v == null || v.isEmpty ? 'Please enter shop address' : null),
            const SizedBox(height: 6),
            _field('Shop Email Address *', emailController, 'shop@example.com', Icons.email_outlined, (v) {
              if (v == null || v.isEmpty) return 'Please enter email';
              if (!v.contains('@')) return 'Invalid email format';
              return null;
            }, keyboard: TextInputType.emailAddress),
            const SizedBox(height: 6),
            _field('Shop Contact Number *', contactController, '09XXXXXXXXX', Icons.phone_outlined, (v) {
              if (v == null || v.isEmpty) return 'Please enter contact number';
              if (v.length != 11) return 'Please enter a valid 11-digit number';
              return null;
            }, keyboard: TextInputType.phone),
            const SizedBox(height: 6),
            _passwordField('Create Password *', passwordController, 'Minimum 6 characters', passwordVisible, onTogglePassword, (v) {
              if (v == null || v.isEmpty) return 'Please enter password';
              if (v.length < 6) return 'Minimum 6 characters';
              return null;
            }),
            const SizedBox(height: 6),
            _passwordField('Confirm Password *', confirmPasswordController, 'Re-enter your password', confirmPasswordVisible, onToggleConfirmPassword, (v) => v != passwordController.text ? 'Passwords do not match' : null),
            const SizedBox(height: 9),
            SizedBox(
              width: double.infinity,
              height: 31,
              child: ElevatedButton(
                onPressed: isLoading ? null : onRegister,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, elevation: 0, padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
                child: isLoading
                    ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Create Admin Account', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1, color: Color(0xFFBBBBBB)),
            const SizedBox(height: 6),
            Center(
              child: GestureDetector(
                onTap: onSignIn,
                child: const Text.rich(
                  TextSpan(
                    text: 'Already have an account? ',
                    style: TextStyle(fontSize: 6.5, color: Color(0xFF777777)),
                    children: [TextSpan(text: 'Sign in here', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700))],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController controller, String hint, IconData icon, String? Function(String?) validator, {TextInputType? keyboard}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 7, fontWeight: FontWeight.w600)),
        const SizedBox(height: 3),
        _input(controller: controller, hint: hint, icon: icon, validator: validator, keyboardType: keyboard),
      ],
    );
  }

  Widget _passwordField(String label, TextEditingController controller, String hint, bool visible, VoidCallback toggle, String? Function(String?) validator) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 7, fontWeight: FontWeight.w600)),
        const SizedBox(height: 3),
        _input(controller: controller, hint: hint, icon: Icons.lock_outline, validator: validator, obscureText: !visible, suffix: IconButton(
          onPressed: toggle,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          icon: Icon(visible ? Icons.visibility_off : Icons.visibility, size: 15, color: const Color(0xFF555555)),
        )),
      ],
    );
  }

  Widget _input({required TextEditingController controller, required String hint, required IconData icon, required String? Function(String?) validator, TextInputType? keyboardType, bool obscureText = false, Widget? suffix}) {
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
          hintStyle: const TextStyle(fontSize: 6.5, color: Color(0xFF999999)),
          prefixIcon: Icon(icon, size: 14, color: Colors.black),
          suffixIcon: suffix,
          prefixIconConstraints: const BoxConstraints(minWidth: 27),
          suffixIconConstraints: const BoxConstraints(minWidth: 28),
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Color(0xFFD2D2D2))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Color(0xFFD2D2D2))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Colors.black, width: 1)),
        ),
      ),
    );
  }
}
