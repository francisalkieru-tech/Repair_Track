import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../../utils/constants.dart';
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
  final StorageService _storageService = StorageService();
  String? _selectedAppliance;
  Uint8List? _selectedImage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCustomerInfo();
  }

  // Auto-fill customer info from Firestore
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
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    ImageSource source = ImageSource.gallery;

    // On web, go directly to gallery — if we go through a dialog/await
    // first before calling pickImage, it breaks the user-gesture chain
    // required by the browser to open the file dialog. On mobile, it's
    // fine to offer a choice between Camera/Gallery.
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
      setState(() => _selectedImage = bytes);
    }
  }

  Future<void> _proceedToTroubleshooting() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAppliance == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an appliance type.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    // If a photo is selected, upload it to Supabase Storage first before
    // proceeding — to ensure we have a URL to include in the Firestore
    // document later.
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
              content: Text('Failed to upload photo: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    // Go to troubleshooting with the form data
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TroubleshootingScreen(
          repairData: {
            'name': _nameController.text.trim(),
            'contactNumber': _contactController.text.trim(),
            'address': _addressController.text.trim(),
            'applianceType': _selectedAppliance!,
            'problemDescription': _problemController.text.trim(),
            'photoUrl': photoUrl,
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        title: const Text('Repair Request'),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFF2563EB)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Fill out the form below. After submission, we\'ll guide you through basic troubleshooting steps.',
                        style:
                            TextStyle(fontSize: 13, color: Color(0xFF374151)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Section: Your Information
              _buildSectionLabel('Your Information'),
              const SizedBox(height: 12),

              _buildLabel('Full Name *'),
              _buildField(
                controller: _nameController,
                hint: 'Juan dela Cruz',
                icon: Icons.person_outline,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Please enter your name' : null,
              ),
              const SizedBox(height: 16),

              _buildLabel('Contact Number *'),
              _buildField(
                controller: _contactController,
                hint: '09XXXXXXXXX',
                icon: Icons.phone_outlined,
                keyboard: TextInputType.phone,
                validator: (v) {
                  if (v == null || v.isEmpty)
                    return 'Please enter contact number';
                  if (v.length != 11) return 'Must be 11 digits';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              _buildLabel('Pickup / Service Address *'),
              _buildField(
                controller: _addressController,
                hint: 'Barangay, City, Province',
                icon: Icons.location_on_outlined,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Please enter address' : null,
              ),
              const SizedBox(height: 24),

              // Section: Appliance Info
              _buildSectionLabel('Appliance Information'),
              const SizedBox(height: 12),

              _buildLabel('Appliance Type *'),
              const SizedBox(height: 8),

              // Appliance Grid
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.1,
                children: AppConstants.applianceTypes.map((appliance) {
                  final isSelected = _selectedAppliance == appliance;
                  return GestureDetector(
                    onTap: () =>
                        setState(() => _selectedAppliance = appliance),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF2563EB)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF2563EB)
                              : const Color(0xFFE5E7EB),
                          width: 2,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _applianceIcon(appliance),
                            size: 26,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF2563EB),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            appliance,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF374151),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              _buildLabel('Problem Description *'),
              TextFormField(
                controller: _problemController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText:
                      'Describe the problem in detail (e.g. not cooling, making noise, not turning on...)',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                validator: (v) => v == null || v.isEmpty
                    ? 'Please describe the problem'
                    : null,
              ),
              const SizedBox(height: 16),

              _buildLabel('Appliance Photo (Optional)'),
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'This will help us better understand the problem.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
              ),
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
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.add_a_photo_outlined,
                            color: Color(0xFF9CA3AF), size: 24),
                        SizedBox(height: 6),
                        Text(
                          'Tap to add a photo',
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFF9CA3AF)),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 32),

              // Next Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _proceedToTroubleshooting,
                  icon: _isLoading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.arrow_forward, color: Colors.white),
                  label: Text(
                    _isLoading ? 'Uploading...' : 'Next — Troubleshooting Guide',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
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
                fontSize: 14, fontWeight: FontWeight.w500)),
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

  IconData _applianceIcon(String appliance) {
    switch (appliance) {
      case 'Refrigerator':
        return Icons.kitchen;
      case 'Air Conditioner':
        return Icons.ac_unit;
      case 'Television':
        return Icons.tv;
      case 'Washing Machine':
        return Icons.local_laundry_service;
      case 'Microwave':
        return Icons.microwave;
      case 'Electric Fan':
        return Icons.wind_power;
      case 'Water Dispenser':
        return Icons.water_drop;
      default:
        return Icons.devices_other;
    }
  }
}