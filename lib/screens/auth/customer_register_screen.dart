import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'login_screen.dart';

class CustomerRegisterScreen extends StatefulWidget {
  const CustomerRegisterScreen({super.key});

  @override
  State<CustomerRegisterScreen> createState() => _CustomerRegisterScreenState();
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

    final String? error = await _authService.registerCustomer(
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
          builder: (_) => const LoginScreen(role: 'customer'),
        ),
      );
    } else {
      setState(() => _errorMessage = _authService.friendlyError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(15, 8, 15, 18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 390),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                      icon: const Icon(Icons.arrow_back, size: 17),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const _RepairLogo(),
                  const SizedBox(height: 7),
                  const Text(
                    'Create Account',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 1),
                  const Text(
                    'Register as a new customer',
                    style: TextStyle(
                      fontSize: 7,
                      color: Color(0xFF777777),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _RegistrationCard(
                    formKey: _formKey,
                    errorMessage: _errorMessage,
                    isLoading: _isLoading,
                    passwordVisible: _isPasswordVisible,
                    confirmPasswordVisible: _isConfirmPasswordVisible,
                    onTogglePassword: () => setState(
                      () => _isPasswordVisible = !_isPasswordVisible,
                    ),
                    onToggleConfirmPassword: () => setState(
                      () => _isConfirmPasswordVisible =
                          !_isConfirmPasswordVisible,
                    ),
                    onRegister: _handleRegister,
                    nameController: _nameController,
                    emailController: _emailController,
                    contactController: _contactController,
                    addressController: _addressController,
                    passwordController: _passwordController,
                    confirmPasswordController: _confirmPasswordController,
                    onSignIn: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LoginScreen(role: 'customer'),
                      ),
                    ),
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
  const _RepairLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(11),
      ),
      child: const Icon(
        Icons.build_outlined,
        color: Colors.white,
        size: 37,
      ),
    );
  }
}

class _RegistrationCard extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final String? errorMessage;
  final bool isLoading;
  final bool passwordVisible;
  final bool confirmPasswordVisible;
  final VoidCallback onTogglePassword;
  final VoidCallback onToggleConfirmPassword;
  final VoidCallback onRegister;
  final VoidCallback onSignIn;
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController contactController;
  final TextEditingController addressController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;

  const _RegistrationCard({
    required this.formKey,
    required this.errorMessage,
    required this.isLoading,
    required this.passwordVisible,
    required this.confirmPasswordVisible,
    required this.onTogglePassword,
    required this.onToggleConfirmPassword,
    required this.onRegister,
    required this.onSignIn,
    required this.nameController,
    required this.emailController,
    required this.contactController,
    required this.addressController,
    required this.passwordController,
    required this.confirmPasswordController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE8E8E8),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0xFFD0D0D0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x24000000),
            blurRadius: 3,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Customer Registration',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 1),
            const Text(
              'Fill in your details to get started',
              style: TextStyle(
                fontSize: 6.5,
                color: Color(0xFF777777),
              ),
            ),
            const SizedBox(height: 8),
            if (errorMessage != null) ...[
              _ErrorBox(message: errorMessage!),
              const SizedBox(height: 6),
            ],
            _field(
              'Full Name *',
              nameController,
              'Juan dela Cruz',
              Icons.person_outline,
              (v) => v == null || v.trim().isEmpty
                  ? 'Please enter your name'
                  : null,
            ),
            const SizedBox(height: 5),
            _field(
              'Email Address *',
              emailController,
              'juan@gmail.com',
              Icons.email_outlined,
              (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Please enter your email';
                }
                if (!v.contains('@')) return 'Invalid email format';
                return null;
              },
              keyboard: TextInputType.emailAddress,
            ),
            const SizedBox(height: 5),
            _field(
              'Contact Number *',
              contactController,
              '09XXXXXXXXX',
              Icons.phone_outlined,
              (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Please enter contact number';
                }
                if (v.trim().length != 11) {
                  return 'Please enter a valid 11-digit number';
                }
                return null;
              },
              keyboard: TextInputType.phone,
            ),
            const SizedBox(height: 5),
            _field(
              'Location *',
              addressController,
              'House/Blk No., Street, Barangay, City, Province',
              Icons.location_on_outlined,
              (v) => v == null || v.trim().isEmpty
                  ? 'Please enter your address'
                  : null,
            ),
            const SizedBox(height: 5),
            _passwordField(
              'Create Password *',
              passwordController,
              'Minimum 6 characters',
              passwordVisible,
              onTogglePassword,
              (v) {
                if (v == null || v.isEmpty) return 'Please enter password';
                if (v.length < 6) return 'Minimum 6 characters';
                return null;
              },
            ),
            const SizedBox(height: 5),
            _passwordField(
              'Confirm Password *',
              confirmPasswordController,
              'Re-enter your password',
              confirmPasswordVisible,
              onToggleConfirmPassword,
              (v) {
                if (v == null || v.isEmpty) {
                  return 'Please re-enter your password';
                }
                if (v != passwordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 31,
              child: ElevatedButton(
                onPressed: isLoading ? null : onRegister,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.black54,
                  elevation: 0,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Register',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 7),
            const Divider(
              height: 1,
              thickness: 1,
              color: Color(0xFFBBBBBB),
            ),
            const SizedBox(height: 6),
            Center(
              child: GestureDetector(
                onTap: onSignIn,
                child: const Text.rich(
                  TextSpan(
                    text: 'Already have an account? ',
                    style: TextStyle(
                      fontSize: 6.5,
                      color: Color(0xFF777777),
                    ),
                    children: [
                      TextSpan(
                        text: 'Sign in here',
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
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller,
    String hint,
    IconData icon,
    String? Function(String?) validator, {
    TextInputType? keyboard,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 7,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        _input(
          controller: controller,
          hint: hint,
          icon: icon,
          validator: validator,
          keyboardType: keyboard,
        ),
      ],
    );
  }

  Widget _passwordField(
    String label,
    TextEditingController controller,
    String hint,
    bool visible,
    VoidCallback toggle,
    String? Function(String?) validator,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 7,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        _input(
          controller: controller,
          hint: hint,
          icon: Icons.lock_outline,
          validator: validator,
          obscureText: !visible,
          suffix: IconButton(
            onPressed: toggle,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 28,
              minHeight: 28,
            ),
            icon: Icon(
              visible ? Icons.visibility_off : Icons.visibility,
              size: 14,
              color: const Color(0xFF555555),
            ),
          ),
        ),
      ],
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
        style: const TextStyle(
          fontSize: 7.5,
          color: Colors.black,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            fontSize: 6.5,
            color: Color(0xFF999999),
          ),
          prefixIcon: Icon(
            icon,
            size: 14,
            color: Colors.black,
          ),
          suffixIcon: suffix,
          prefixIconConstraints: const BoxConstraints(minWidth: 27),
          suffixIconConstraints: const BoxConstraints(minWidth: 28),
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 7,
            vertical: 7,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: Color(0xFFD0D0D0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: Color(0xFFD0D0D0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: Colors.black),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: Color(0xFFB00020)),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: Color(0xFFB00020)),
          ),
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;

  const _ErrorBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE8E8),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE57373)),
      ),
      child: Text(
        message,
        style: const TextStyle(
          fontSize: 7,
          color: Color(0xFFB71C1C),
        ),
      ),
    );
  }
}
