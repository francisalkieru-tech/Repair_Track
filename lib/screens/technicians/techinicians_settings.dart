import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import '../auth/Welcome_screen.dart';
import '../../utils/colors.dart';
import '../../utils/ui_widgets.dart';

class TechnicianSettingsScreen extends StatefulWidget {
  final String technicianDocId;

  const TechnicianSettingsScreen({super.key, required this.technicianDocId});

  @override
  State<TechnicianSettingsScreen> createState() =>
      _TechnicianSettingsScreenState();
}

class _TechnicianSettingsScreenState extends State<TechnicianSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isEditing = false;
  String _email = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final doc = await FirebaseFirestore.instance
        .collection('technicians')
        .doc(widget.technicianDocId)
        .get();

    if (doc.exists && mounted) {
      final data = doc.data() as Map<String, dynamic>;
      setState(() {
        _nameController.text = data['name'] as String? ?? '';
        _phoneController.text = data['phoneNumber'] as String? ?? '';
        _email = data['email'] as String? ??
            FirebaseAuth.instance.currentUser?.email ??
            '';
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() {
        _email = FirebaseAuth.instance.currentUser?.email ?? '';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance
          .collection('technicians')
          .doc(widget.technicianDocId)
          .update({
        'name': _nameController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
      });

      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _isEditing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyErrorMessage(e)),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  void _cancelEdit() {
    setState(() => _isEditing = false);
    _loadProfile();
  }

  void _confirmLogout(BuildContext context) {
    showAppDialog(
      context: context,
      title: 'Logout',
      content: const Text('Are you sure you want to logout?',
          style: TextStyle(
              fontSize: AppColors.fontLabel, color: AppColors.textGray)),
      actions: [
        AppDialogAction(
          label: 'Cancel',
          onPressed: () => Navigator.pop(context),
        ),
        AppDialogAction(
          label: 'Logout',
          isPrimary: true,
          isDestructive: true,
          onPressed: () async {
            Navigator.pop(context);
            await AuthService().logout();
            if (context.mounted) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                (route) => false,
              );
            }
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF6F7F9),
        appBar: _buildAppBar(),
        body: const AppLoadingIndicator(message: 'Loading your settings...'),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: _buildAppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _profileHeader(),
                    const SizedBox(height: 16),
                    _sectionCard(
                      icon: Icons.person_outline,
                      title: 'Personal Information',
                      subtitle: 'Manage the details shown on your technician profile.',
                      child: _personalInfo(),
                    ),
                    const SizedBox(height: 14),
                    if (_isEditing)
                      _editActions()
                    else ...[
                      _securityCard(),
                      const SizedBox(height: 14),
                      _signOutCard(),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() => AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        titleSpacing: 20,
        title: const Text(
          'Settings',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        actions: [
          if (!_isEditing)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton.icon(
                onPressed: () => setState(() => _isEditing = true),
                icon: const Icon(Icons.edit_outlined, size: 17),
                label: const Text('Edit profile'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textDark,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
              ),
            ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE5E7EB)),
        ),
      );

  Widget _profileHeader() {
    final name = _nameController.text.trim().isEmpty
        ? 'Technician'
        : _nameController.text.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 18,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F1F3),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE1E4E8)),
            ),
            child: const Icon(
              Icons.build_circle_outlined,
              size: 34,
              color: Color(0xFF4B5563),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _email.isEmpty ? 'No email available' : _email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textGray,
                  ),
                ),
                const SizedBox(height: 9),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_outlined,
                          size: 13, color: Color(0xFF4B5563)),
                      SizedBox(width: 5),
                      Text(
                        'Technician Account',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4B5563),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon,
                        size: 19, color: const Color(0xFF374151)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 11.5,
                            height: 1.35,
                            color: AppColors.textGray,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            Padding(
              padding: const EdgeInsets.all(20),
              child: child,
            ),
          ],
        ),
      );

  Widget _personalInfo() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel('Full Name'),
          const SizedBox(height: 7),
          _field(
            controller: _nameController,
            icon: Icons.person_outline,
            enabled: _isEditing,
            validator: (v) => v == null || v.trim().isEmpty
                ? 'Please enter your name'
                : null,
          ),
          const SizedBox(height: 16),
          _fieldLabel('Email Address'),
          const SizedBox(height: 7),
          TextFormField(
            initialValue: _email,
            enabled: false,
            style: const TextStyle(
              fontSize: 13.5,
              color: Color(0xFF6B7280),
            ),
            decoration: _decoration(
              Icons.email_outlined,
              enabled: false,
            ).copyWith(
              suffixIcon: const Icon(
                Icons.lock_outline,
                size: 17,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Email is linked to your account and cannot be changed here.',
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF9CA3AF),
            ),
          ),
          const SizedBox(height: 16),
          _fieldLabel('Contact Number'),
          const SizedBox(height: 7),
          _field(
            controller: _phoneController,
            icon: Icons.phone_outlined,
            enabled: _isEditing,
            keyboard: TextInputType.phone,
            validator: (_) => null,
          ),
        ],
      );

  Widget _fieldLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF374151),
        ),
      );

  InputDecoration _decoration(
    IconData icon, {
    required bool enabled,
  }) =>
      InputDecoration(
        prefixIcon: Icon(
          icon,
          size: 19,
          color: enabled
              ? const Color(0xFF4B5563)
              : const Color(0xFF9CA3AF),
        ),
        filled: true,
        fillColor: enabled ? Colors.white : const Color(0xFFF7F8FA),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFDDE1E6)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFDDE1E6)),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: Color(0xFF111827), width: 1.3),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFDC2626)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: Color(0xFFDC2626), width: 1.3),
        ),
      );

  Widget _field({
    required TextEditingController controller,
    required IconData icon,
    required bool enabled,
    TextInputType keyboard = TextInputType.text,
    required String? Function(String?) validator,
  }) =>
      TextFormField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboard,
        style: const TextStyle(
          fontSize: 13.5,
          color: AppColors.textDark,
        ),
        decoration: _decoration(icon, enabled: enabled),
        validator: validator,
      );

  Widget _securityCard() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: const Row(
          children: [
            _SettingsIconBox(icon: Icons.security_outlined),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Account Security',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Your account information is protected by your login credentials.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textGray,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                size: 19, color: Color(0xFF9CA3AF)),
          ],
        ),
      );

  Widget _editActions() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isSaving ? null : _cancelEdit,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF4B5563),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  side: const BorderSide(color: Color(0xFFD1D5DB)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.dark,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check, size: 17),
                          SizedBox(width: 7),
                          Text('Save Changes'),
                        ],
                      ),
              ),
            ),
          ],
        ),
      );

  Widget _signOutCard() => Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF1D5D5)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _confirmLogout(context),
          child: const Padding(
            padding: EdgeInsets.all(17),
            child: Row(
              children: [
                _SettingsIconBox(
                  icon: Icons.logout_rounded,
                  danger: true,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sign Out',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF991B1B),
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Sign out of this technician account.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textGray,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 19,
                  color: Color(0xFFB91C1C),
                ),
              ],
            ),
          ),
        ),
      );
}

class _SettingsIconBox extends StatelessWidget {
  final IconData icon;
  final bool danger;

  const _SettingsIconBox({
    required this.icon,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: danger ? const Color(0xFFFFF1F2) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 19,
          color: danger
              ? const Color(0xFFB91C1C)
              : const Color(0xFF374151),
        ),
      );
}
