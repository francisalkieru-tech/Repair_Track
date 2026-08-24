import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../../utils/constants.dart';
import '../../services/storage_service.dart';
import 'troubleshooting_screen.dart';

/// "Repair Request" — form the customer fills out to start a repair
/// request. Submitting goes to TroubleshootingScreen first, not
/// straight to Firestore, so basic troubleshooting is offered before
/// the request is actually filed.
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
  final _otherApplianceController = TextEditingController();
  final StorageService _storageService = StorageService();
  String? _selectedAppliance;
  Uint8List? _selectedImage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCustomerInfo();
  }

  // Pre-fills the form with the customer's saved profile info.
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
    _otherApplianceController.dispose();
    super.dispose();
  }

  // Opens the photo picker; on mobile lets the user choose camera or gallery.
  Future<void> _pickPhoto() async {
    ImageSource source = ImageSource.gallery;

    // On web, skip straight to gallery — showing a chooser dialog first
    // breaks the user-gesture chain the browser needs to open the file
    // picker. On mobile it's fine to offer Camera/Gallery.
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

  // Validates the form, uploads the photo (if any), then moves to
  // the troubleshooting flow carrying the form data forward.
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
    if (_selectedAppliance == 'Others' &&
        _otherApplianceController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please specify your appliance.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Upload the photo first (if selected) so we have a URL ready for
    // the Firestore document once the request is actually filed.
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

    // Resolve the final appliance label: the custom text if "Others"
    // was picked, otherwise the selected type as-is.
    final applianceType = _selectedAppliance == 'Others'
        ? _otherApplianceController.text.trim()
        : _selectedAppliance!;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TroubleshootingScreen(
          repairData: {
            'name': _nameController.text.trim(),
            'contactNumber': _contactController.text.trim(),
            'address': _addressController.text.trim(),
            'applianceType': applianceType,
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
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Repair Request',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Submit your repair request',
                        style: TextStyle(fontSize: 13, color: Colors.white70),
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
                              TextStyle(fontSize: 12, color: Color(0xFF374151)),
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
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Please enter contact number';
                    }
                    if (v.length != 11) return 'Must be 11 digits';
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

                // Appliance type list — one bordered box holding all
                // options as tappable rows, matching the mockup's
                // expanded dropdown look.
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFD1D5DB)),
                  ),
                  child: Column(
                    children: [
                      for (final appliance in AppConstants.applianceTypes)
                        _ApplianceOptionTile(
                          label: appliance,
                          isSelected: _selectedAppliance == appliance,
                          isLast: appliance ==
                              AppConstants.applianceTypes.last,
                          onTap: () =>
                              setState(() => _selectedAppliance = appliance),
                        ),
                    ],
                  ),
                ),

                // Custom appliance name field — only shown when "Others" is picked
                if (_selectedAppliance == 'Others') ...[
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _otherApplianceController,
                    decoration: InputDecoration(
                      hintText: 'Input here your appliance',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
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
                    style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
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
                      backgroundColor: const Color(0xFF2563EB),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Next',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'click next to guide you to basic trouble shooting',
                    style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
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
                fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black)),
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
}

/// One selectable row inside the "Appliances Information" list box.
class _ApplianceOptionTile extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isLast;
  final VoidCallback onTap;

  const _ApplianceOptionTile({
    required this.label,
    required this.isSelected,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
          border: isLast
              ? null
              : const Border(
                  bottom: BorderSide(color: Color(0xFFE5E7EB)),
                ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? const Color(0xFF2563EB) : Colors.black87,
          ),
        ),
      ),
    );
  }
}