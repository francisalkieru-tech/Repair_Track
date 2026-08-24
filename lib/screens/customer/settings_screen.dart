import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import '../auth/Welcome_screen.dart';

/// "Setting" tab — profile info (view/edit), logout, at app info.
/// Ginagamit ang parehong Firestore fields/logic ng dating
/// ProfileScreen, pero ito na ang laman ng Settings tab mismo
/// (walang sariling AppBar dahil naka-loob na sa MainNavScreen).
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

    setState(() => _isSaving = true);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      await FirebaseFirestore.instance.collection('customers').doc(uid).update({
        'name': _nameController.text.trim(),
        'contactNumber': _contactController.text.trim(),
        'address': _addressController.text.trim(),
      });

      setState(() {
        _isSaving = false;
        _isEditing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
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
      backgroundColor: const Color(0xFFF8FAFF),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
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
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF111827),
                            ),
                          ),
                          if (!_isEditing)
                            IconButton(
                              icon: const Icon(Icons.edit,
                                  color: Color(0xFF111827)),
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
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF111827)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _email,
                              style: const TextStyle(
                                  fontSize: 13, color: Color(0xFF6B7280)),
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
                            fontSize: 11, color: Color(0xFF9CA3AF)),
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
                                  backgroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(10)),
                                ),
                                child: _isSaving
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white))
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await AuthService().logout();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Logout',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) => Text(
        text,
        style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF111827)),
      );

  Widget _buildLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF6B7280))),
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
          Icon(icon, size: 20, color: const Color(0xFF6B7280)),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827)),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}