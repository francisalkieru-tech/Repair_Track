import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../utils/colors.dart';
import 'technicians_main_nav.dart';

class TechnicianAccountSetupScreen extends StatefulWidget {
  const TechnicianAccountSetupScreen({super.key});

  @override
  State<TechnicianAccountSetupScreen> createState() =>
      _TechnicianAccountSetupScreenState();
}

class _TechnicianAccountSetupScreenState
    extends State<TechnicianAccountSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _authService = AuthService();
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordController.text != _confirmController.text) {
      setState(() => _errorMessage = 'Passwords do not match.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final result = await _authService.verifyInviteAndCreateAccount(
      email: _emailController.text.trim(),
      inviteCode: _codeController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (result['success'] == true) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const TechnicianMainNav()),
      );
    } else {
      setState(() => _errorMessage = result['error']?.toString() ??
          'Something went wrong. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.dark,
        foregroundColor: Colors.white,
        title: const Text('Set Up Your Account'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 448),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Enter the email your admin registered you with '
                      'and the invite code they gave you, then choose '
                      'your own password.',
                      style: TextStyle(
                          fontSize: AppColors.fontLabel,
                          color: AppColors.textGray),
                    ),
                    const SizedBox(height: 20),
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 16),
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
                              child: Text(_errorMessage!,
                                  style: const TextStyle(
                                      color: AppColors.danger,
                                      fontSize: AppColors.fontCaption)),
                            ),
                          ],
                        ),
                      ),
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
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      validator: (v) => v == null || v.isEmpty
                          ? 'Please enter your email'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    const Text('Invite Code',
                        style: TextStyle(
                            fontSize: AppColors.fontLabel,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _codeController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: '6-digit code from your admin',
                        prefixIcon: const Icon(Icons.key_outlined),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      validator: (v) => v == null || v.isEmpty
                          ? 'Please enter your invite code'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    const Text('New Password',
                        style: TextStyle(
                            fontSize: AppColors.fontLabel,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: 'At least 6 characters',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      validator: (v) => v == null || v.length < 6
                          ? 'Password must be at least 6 characters'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    const Text('Confirm Password',
                        style: TextStyle(
                            fontSize: AppColors.fontLabel,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _confirmController,
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: 'Re-enter your password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Please confirm password' : null,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.dark,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Create Account',
                                style: TextStyle(
                                    fontSize: AppColors.fontBody,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white)),
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
