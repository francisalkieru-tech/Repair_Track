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
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header — solid black card with title + subtitle
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: AppColors.darkGradient,
                    borderRadius: BorderRadius.circular(16),
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
                        'Submit your repair request',
                        style: TextStyle(
                            fontSize: AppColors.fontSubtitle,
                            color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Info banner explaining what happens after submit
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.chat_bubble_outline,
                          color: Colors.black87, size: 18),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Fill out the form below. After submission, we\'ll guide you through basic troubleshooting steps.',
                          style:
                              TextStyle(fontSize: AppColors.fontLabel, color: Color(0xFF374151)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                _buildLabel('Full Name *'),
                _buildField(
                  controller: _nameController,
                  hint: 'e.g. Juan dela Cruz',
                  icon: Icons.person_outline,
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Please enter your name' : null,
                ),
                const SizedBox(height: 16),

                _buildLabel('Contact Number *'),
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
                    if (!digitsOnly) return 'Numbers only, e.g. 09XX XXX XXXX';
                    if (v.length != 11 || !v.startsWith('09')) {
                      return 'Enter a valid number, e.g. 09XX XXX XXXX';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                _buildLabel('Address *'),
                _buildField(
                  controller: _addressController,
                  hint: 'House/Bldg No., Street, Barangay, City, Province',
                  icon: Icons.location_on_outlined,
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Please enter address' : null,
                ),
                const SizedBox(height: 16),

                _buildLabel('Appliances Information'),
                const SizedBox(height: 8),

                DropdownButtonFormField<String>(
                  value: _selectedAppliance,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down,
                      color: AppColors.textGray),
                  style: const TextStyle(
                      fontSize: AppColors.fontLabel, color: AppColors.textDark),
                  decoration: InputDecoration(
                    hintText: 'Select an appliance type',
                    hintStyle:
                        const TextStyle(color: Color(0xFF9CA3AF)),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: Color(0xFFD1D5DB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: Color(0xFFD1D5DB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: AppColors.dark, width: 2),
                    ),
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
                  validator: (v) =>
                      v == null ? 'Please select an appliance type' : null,
                ),

                const SizedBox(height: 16),

                // Appliance Model optional, tumutulong sa shop na
                // malaman agad kung anong parts posibleng kailangan
                // bago pa dumating yung customer.
                _buildLabel('Appliance Model (Optional)'),
                TextFormField(
                  controller: _modelController,
                  decoration: InputDecoration(
                    hintText: 'e.g. Samsung RT20, LG Twin Tub',
                    prefixIcon: const Icon(Icons.label_outline),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 16),

                _buildLabel('Problem Description *'),
                TextFormField(
                  controller: _problemController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText:
                        'Describe the problem in detail of the appliances (e.g. not cooling, making noise, not turning on...)',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  validator: (v) => v == null || v.isEmpty
                      ? 'Please describe the problem'
                      : null,
                ),
                const SizedBox(height: 16),

                _buildLabel('Appliances Photo (Optional)'),
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'This help us better understand the problem.',
                    style: TextStyle(fontSize: AppColors.fontCaption, color: AppColors.textGray),
                  ),
                ),
                // Photo picker: shows the selected preview, or a tap-to-add box
                if (_selectedImage != null)
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          _selectedImage!,
                          height: 140,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedImage = null),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close,
                                color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  InkWell(
                    onTap: _pickPhoto,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.add_photo_alternate_outlined,
                              color: Colors.black54, size: 28),
                          SizedBox(height: 6),
                          Text(
                            'Tap to add a phot',
                            style: TextStyle(
                                fontSize: 12, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 28),

                // Next button — proceeds to the troubleshooting guide
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _proceedToTroubleshooting,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.dark,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const Row(
                            mainAxisSize: MainAxisSize.min,
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
                        : const Text(
                            'Next',
                            style: TextStyle(
                                fontSize: AppColors.fontBody,
                                fontWeight: FontWeight.w600,
                                color: Colors.white),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'click next to guide you to basic trouble shooting',
                    style: TextStyle(fontSize: AppColors.fontCaption, color: AppColors.textLightGray),
                  ),
                ),
                const SizedBox(height: 24),
              ],
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
                fontSize: AppColors.fontLabel, fontWeight: FontWeight.w600, color: AppColors.textDark)),
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
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          counterText: maxLength != null ? '' : null,
        ),
        validator: validator,
      );
}

