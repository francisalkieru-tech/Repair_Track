import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import '../auth/Welcome_screen.dart';
import '../../utils/colors.dart';
import '../../utils/ui_widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  final _addressController = TextEditingController();

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
    _contactController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('customers')
        .doc(uid)
        .get();

    if (doc.exists && mounted) {
      setState(() {
        _nameController.text = doc['name'] ?? '';
        _contactController.text = doc['contactNumber'] ?? '';
        _addressController.text = doc['address'] ?? '';
        _email = doc['email'] ?? FirebaseAuth.instance.currentUser?.email ?? '';
        _isLoading = false;
      });
    } else {
      setState(() {
        _email = FirebaseAuth.instance.currentUser?.email ?? '';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance.collection('customers').doc(uid).update({
        'name': _nameController.text.trim(),
        'contactNumber': _contactController.text.trim(),
        'address': _addressController.text.trim(),
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
      if (!mounted) return;
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
    _loadProfile(); // reset to original values
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _isLoading
            ? const AppLoadingIndicator(message: 'Loading your settings...')
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Settings',
                            style: TextStyle(
                              fontSize: AppColors.fontTitle,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          if (!_isEditing)
                            IconButton(
                              icon: const Icon(Icons.edit,
                                  color: AppColors.textDark),
                              tooltip: 'Edit Profile',
                              onPressed: () =>
                                  setState(() => _isEditing = true),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Avatar + email header
                      Center(
                        child: Column(
                          children: [
                            Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE4E6EB),
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: const Color(0xFFD1D5DB),
                                    width: 2),
                              ),
                              child: const Icon(Icons.person,
                                  color: Color(0xFF9CA3AF), size: 56),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _nameController.text.isNotEmpty
                                  ? _nameController.text
                                  : 'Customer',
                              style: const TextStyle(
                                  fontSize: AppColors.fontTitle,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textDark),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _email,
                              style: const TextStyle(
                                  fontSize: AppColors.fontLabel,
                                  color: AppColors.textGray),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      _buildSectionLabel('Personal Information'),
                      const SizedBox(height: 12),

                      _buildLabel('Full Name'),
                      _buildField(
                        controller: _nameController,
                        icon: Icons.person_outline,
                        enabled: _isEditing,
                        validator: (v) => v == null || v.isEmpty
                            ? 'Please enter your name'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      _buildLabel('Email Address'),
                      TextFormField(
                        initialValue: _email,
                        enabled: false,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.email_outlined),
                          filled: true,
                          fillColor: const Color(0xFFF3F4F6),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Email cannot be changed.',
                        style: TextStyle(
                            fontSize: AppColors.fontCaption, color: AppColors.textGray),
                      ),
                      const SizedBox(height: 16),

                      _buildLabel('Contact Number'),
                      _buildField(
                        controller: _contactController,
                        icon: Icons.phone_outlined,
                        enabled: _isEditing,
                        keyboard: TextInputType.phone,
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Please enter contact number';
                          }
                          if (v.length != 11) return 'Must be 11 digits';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      _buildLabel('Address'),
                      _buildField(
                        controller: _addressController,
                        icon: Icons.location_on_outlined,
                        enabled: _isEditing,
                        validator: (v) => v == null || v.isEmpty
                            ? 'Please enter address'
                            : null,
                      ),
                      const SizedBox(height: 32),

                      if (_isEditing)
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _isSaving ? null : _cancelEdit,
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14),
                                  side: const BorderSide(
                                      color: Color(0xFFE5E7EB)),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(10)),
                                ),
                                child: const Text('Cancel',
                                    style: TextStyle(
                                        color: Color(0xFF6B7280))),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _isSaving ? null : _saveProfile,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.dark,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(10)),
                                ),
                                child: _isSaving
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
                                          SizedBox(width: 8),
                                          Text('Saving...',
                                              style: TextStyle(
                                                  color: Colors.white)),
                                        ],
                                      )
                                    : const Text('Save Changes',
                                        style: TextStyle(
                                            color: Colors.white)),
                              ),
                            ),
                          ],
                        ),

                      if (!_isEditing) ...[
                        const SizedBox(height: 8),
                        const Divider(),
                        const SizedBox(height: 20),

                        _buildSectionLabel('About'),
                        const SizedBox(height: 12),
                        _AboutTile(
                          icon: Icons.info_outline,
                          label: 'App Version',
                          value: '1.0.0',
                        ),
                        const SizedBox(height: 10),
                        _AboutTile(
                          icon: Icons.build_outlined,
                          label: 'RepairTrack',
                          value: 'Appliance Repair Tracking',
                        ),
                        const SizedBox(height: 24),

                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _confirmLogout(context),
                            icon: const Icon(Icons.logout,
                                color: Color(0xFFDC2626), size: 18),
                            label: const Text(
                              'Logout',
                              style: TextStyle(
                                  color: Color(0xFFDC2626),
                                  fontWeight: FontWeight.w600),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(
                                  color: Color(0xFFFECACA)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showAppDialog(
      context: context,
      title: 'Logout',
      content: const Text('Are you sure you want to logout?',
          style: TextStyle(fontSize: AppColors.fontLabel, color: AppColors.textGray)),
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

  Widget _buildSectionLabel(String text) => Text(
        text,
        style: const TextStyle(
            fontSize: AppColors.fontBody,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark),
      );

  Widget _buildLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                fontSize: AppColors.fontLabel,
                fontWeight: FontWeight.w500,
                color: AppColors.textGray)),
      );

  Widget _buildField({
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
        decoration: InputDecoration(
          prefixIcon: Icon(icon),
          filled: true,
          fillColor: enabled ? Colors.white : const Color(0xFFF9FAFB),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        validator: validator,
      );
}

class _AboutTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _AboutTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textGray),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
                fontSize: AppColors.fontLabel,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
                fontSize: AppColors.fontCaption, color: AppColors.textGray),
          ),
        ],
      ),
    );
  }
}