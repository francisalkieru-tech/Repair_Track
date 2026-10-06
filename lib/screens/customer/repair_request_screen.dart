import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../../utils/constants.dart';
import '../../utils/colors.dart';
import '../../utils/ui_widgets.dart';
import '../../services/storage_service.dart';
import 'troubleshooting_screen.dart';

class RepairRequestScreen extends StatefulWidget {
  const RepairRequestScreen({super.key});

  @override
  State<RepairRequestScreen> createState() => _RepairRequestScreenState();
}

class _RepairRequestScreenState extends State<RepairRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  final _addressController = TextEditingController();
  final _problemController = TextEditingController();

  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final StorageService _storageService = StorageService();
  String? _selectedAppliance;
  Uint8List? _selectedImage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCustomerInfo();
  }

  Future<void> _loadCustomerInfo() async {
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
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _addressController.dispose();
    _problemController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    ImageSource source = ImageSource.gallery;

    if (!kIsWeb) {
      final chosen = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Take a Photo'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );
      if (chosen == null) return;
      source = chosen;
    }

    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 70,
    );
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() => _selectedImage = bytes);
    }
  }

  Future<void> _proceedToTroubleshooting() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAppliance == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an appliance type.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }
    setState(() => _isLoading = true);

    String? photoUrl;
    if (_selectedImage != null) {
      try {
        photoUrl = await _storageService.uploadPhoto(
          bytes: _selectedImage!,
          trackingId: 'request_${DateTime.now().millisecondsSinceEpoch}',
        );
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(friendlyErrorMessage(e)),
              backgroundColor: AppColors.danger,
            ),
          );
        }
        return;
      }
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    final applianceType = _selectedAppliance!;

    final confirmed = await _showReviewDialog(applianceType);
    if (confirmed != true) return;

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TroubleshootingScreen(
          repairData: {
            'name': _nameController.text.trim(),
            'contactNumber': _contactController.text.trim(),
            'address': _addressController.text.trim(),
            'applianceType': applianceType,
            'brand': _brandController.text.trim(),
            'applianceModel': _modelController.text.trim(),
            'problemDescription': _problemController.text.trim(),
            'photoUrl': photoUrl,
          },
        ),
      ),
    );
  }

  Future<bool?> _showReviewDialog(String applianceType) {
    return showAppDialog<bool>(
      context: context,
      title: 'Review Your Details',
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Please check if everything is correct before we continue.',
              style: TextStyle(
                  fontSize: AppColors.fontLabel, color: AppColors.textGray),
            ),
            const SizedBox(height: 16),
            _reviewRow('Name', _nameController.text.trim()),
            _reviewRow('Contact Number', _contactController.text.trim()),
            _reviewRow('Address', _addressController.text.trim()),
            _reviewRow('Appliance', applianceType),
            if (_brandController.text.trim().isNotEmpty)
              _reviewRow('Brand', _brandController.text.trim()),
            if (_modelController.text.trim().isNotEmpty)
              _reviewRow('Model', _modelController.text.trim()),
            _reviewRow('Problem', _problemController.text.trim()),
          ],
        ),
      ),
      actions: [
        AppDialogAction(
          label: 'Edit Details',
          onPressed: () => Navigator.pop(context, false),
        ),
        AppDialogAction(
          label: 'Continue',
          isPrimary: true,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );
  }

  Widget _reviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
                fontSize: AppColors.fontCaption,
                color: AppColors.textLightGray,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            value.isEmpty ? '—' : value,
            style: const TextStyle(
                fontSize: AppColors.fontLabel, color: AppColors.textDark),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: dark card with title + subtitle
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: AppColors.darkGradient,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Repair Request',
                            style: TextStyle(
                              fontSize: AppColors.fontTitle,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Tell us what needs fixing.',
                            style: TextStyle(
                                fontSize: AppColors.fontSubtitle,
                                color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Info banner: what happens after the form
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: Color(0xFF4B5563), size: 20),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'After this form, we\'ll guide you through a few basic troubleshooting steps.',
                              style: TextStyle(
                                  fontSize: AppColors.fontLabel,
                                  height: 1.35,
                                  color: Color(0xFF374151)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Section 1: contact details
                    _sectionCard(
                      icon: Icons.person_outline,
                      title: 'Your Details',
                      subtitle: 'Prefilled from your account. Edit if needed.',
                      children: [
                        _buildLabel('Full Name'),
                        _buildField(
                          controller: _nameController,
                          hint: 'e.g. Juan dela Cruz',
                          icon: Icons.person_outline,
                          validator: (v) => v == null || v.isEmpty
                              ? 'Please enter your name'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        _buildLabel('Contact Number'),
                        _buildField(
                          controller: _contactController,
                          hint: '09XX XXX XXXX',
                          icon: Icons.phone_outlined,
                          keyboard: TextInputType.phone,
                          maxLength: 11,
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Please enter contact number';
                            }
                            final digitsOnly = RegExp(r'^[0-9]+$').hasMatch(v);
                            if (!digitsOnly) {
                              return 'Numbers only, e.g. 09XX XXX XXXX';
                            }
                            if (v.length != 11 || !v.startsWith('09')) {
                              return 'Enter a valid number, e.g. 09XX XXX XXXX';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildLabel('Address'),
                        _buildField(
                          controller: _addressController,
                          hint: 'House/Bldg No., Street, Barangay, City, Province',
                          icon: Icons.location_on_outlined,
                          validator: (v) => v == null || v.isEmpty
                              ? 'Please enter address'
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Section 2: appliance
                    _sectionCard(
                      icon: Icons.kitchen_outlined,
                      title: 'Appliance',
                      subtitle: 'Which appliance needs repair?',
                      children: [
                        _buildLabel('Appliance Type'),
                        DropdownButtonFormField<String>(
                          value: _selectedAppliance,
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down,
                              color: AppColors.textGray),
                          style: const TextStyle(
                              fontSize: 15, color: AppColors.textDark),
                          decoration: _decoration(
                            hint: 'Select an appliance type',
                            prefix: const Icon(Icons.devices_other_outlined,
                                size: 20, color: Color(0xFF6B7280)),
                          ),
                          items: [
                            for (final appliance in AppConstants.applianceTypes)
                              DropdownMenuItem(
                                value: appliance,
                                child: Text(appliance),
                              ),
                          ],
                          onChanged: (value) =>
                              setState(() => _selectedAppliance = value),
                          validator: (v) => v == null
                              ? 'Please select an appliance type'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        // Brand and model are optional; they help the shop
                        // prepare parts
                        _buildLabel('Brand (Optional)'),
                        TextFormField(
                          controller: _brandController,
                          textCapitalization: TextCapitalization.words,
                          style: const TextStyle(
                              fontSize: 15, color: AppColors.textDark),
                          decoration: _decoration(
                            hint: 'e.g. Samsung, LG, Panasonic',
                            prefix: const Icon(Icons.sell_outlined,
                                size: 20, color: Color(0xFF6B7280)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildLabel('Model (Optional)'),
                        TextFormField(
                          controller: _modelController,
                          style: const TextStyle(
                              fontSize: 15, color: AppColors.textDark),
                          decoration: _decoration(
                            hint: 'e.g. RT20K, Twin Tub',
                            prefix: const Icon(Icons.label_outline,
                                size: 20, color: Color(0xFF6B7280)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Section 3: problem + photo
                    _sectionCard(
                      icon: Icons.build_outlined,
                      title: 'The Problem',
                      subtitle: 'The more detail, the faster we can help.',
                      children: [
                        _buildLabel('Problem Description'),
                        TextFormField(
                          controller: _problemController,
                          maxLines: 4,
                          style: const TextStyle(
                              fontSize: 15, color: AppColors.textDark),
                          decoration: _decoration(
                            hint:
                                'Describe the problem (e.g. not cooling, making noise, not turning on...)',
                          ),
                          validator: (v) => v == null || v.isEmpty
                              ? 'Please describe the problem'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        _buildLabel('Photo (Optional)'),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text(
                            'A photo helps us understand the problem better.',
                            style: TextStyle(
                                fontSize: AppColors.fontCaption,
                                color: AppColors.textGray),
                          ),
                        ),
                        _photoPicker(),
                      ],
                    ),
                    const SizedBox(height: 22),

                    // Next button: goes to troubleshooting guide
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed:
                            _isLoading ? null : _proceedToTroubleshooting,
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
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Text('Uploading...',
                                      style: TextStyle(
                                          fontSize: AppColors.fontBody,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white)),
                                ],
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('Next',
                                      style: TextStyle(
                                          fontSize: AppColors.fontBody,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white)),
                                  SizedBox(width: 8),
                                  Icon(Icons.arrow_forward, size: 18),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Center(
                      child: Text(
                        'Next: basic troubleshooting steps',
                        style: TextStyle(
                            fontSize: AppColors.fontCaption,
                            color: AppColors.textLightGray),
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

  // Photo picker: shows the selected preview, or a tap-to-add box
  Widget _photoPicker() {
    if (_selectedImage != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              _selectedImage!,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () => setState(() => _selectedImage = null),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      );
    }
    return InkWell(
      onTap: _pickPhoto,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 26),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFDDE1E6)),
        ),
        child: const Column(
          children: [
            Icon(Icons.add_photo_alternate_outlined,
                color: Color(0xFF6B7280), size: 30),
            SizedBox(height: 6),
            Text(
              'Tap to add a photo',
              style: TextStyle(
                  fontSize: AppColors.fontLabel, color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
    );
  }

  // Section card: icon header + divider + fields (same style as settings)
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

  // Shared input look across all fields in this screen
  InputDecoration _decoration({
    required String hint,
    Widget? prefix,
    String? counterText,
  }) =>
      InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(fontSize: 15, color: Color(0xFF9CA3AF)),
        prefixIcon: prefix,
        counterText: counterText,
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
    int? maxLength,
    required String? Function(String?) validator,
  }) =>
      TextFormField(
        controller: controller,
        keyboardType: keyboard,
        maxLength: maxLength,
        style: const TextStyle(fontSize: 15, color: AppColors.textDark),
        decoration: _decoration(
          hint: hint,
          prefix: Icon(icon, size: 20, color: const Color(0xFF6B7280)),
          counterText: maxLength != null ? '' : null,
        ),
        validator: validator,
      );
}
