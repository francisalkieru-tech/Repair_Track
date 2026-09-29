import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../auth/Welcome_screen.dart';
import 'admin_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _storageService = StorageService();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kAdminBg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;

            final leftColumn = <Widget>[
              _SettingsCard(
                title: 'Shop / Business Info',
                subtitle: 'This is what your customers see on receipts '
                    'and SMS notifications.',
                icon: Icons.storefront_outlined,
                child: _ShopInfoSection(storageService: _storageService),
              ),
              const SizedBox(height: 14),
              _SettingsCard(
                title: 'Account / Profile',
                subtitle: 'Your personal admin login details.',
                icon: Icons.person_outline,
                child: const _AccountSettingsSection(),
              ),
              const SizedBox(height: 14),
              _SettingsCard(
                title: 'Data & Security',
                subtitle: 'Back up your repair records.',
                icon: Icons.shield_outlined,
                child: const _DataSecuritySection(),
              ),
              const SizedBox(height: 14),
              _SettingsCard(
                title: 'App Info',
                subtitle: null,
                icon: Icons.info_outline,
                padded: false,
                child: const _AppInfoSettingsSection(),
              ),
            ];

            final rightColumn = <Widget>[
              _SettingsCard(
                title: 'Notifications',
                subtitle: 'Control the SMS messages sent to customers '
                    'for each repair status.',
                icon: Icons.notifications_outlined,
                child: const _NotificationSettingsSection(),
              ),
            ];

            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: leftColumn,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: rightColumn,
                    ),
                  ),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...leftColumn,
                const SizedBox(height: 14),
                ...rightColumn,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget child;
  final bool padded;

  const _SettingsCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
    this.padded = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kAdminCardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: kAdminBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: kAdminTextDark),
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
                          color: kAdminTextDark,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: kAdminTextGray,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: kAdminCardBorder),
          Padding(
            padding: padded
                ? const EdgeInsets.fromLTRB(20, 16, 20, 18)
                : EdgeInsets.zero,
            child: child,
          ),
        ],
      ),
    );
  }
}

Future<String?> _showEditFieldDialog(
  BuildContext context, {
  required String title,
  required String initialValue,
  String? hint,
  int maxLines = 1,
  TextInputType? keyboardType,
}) {
  final controller = TextEditingController(text: initialValue);

  return showDialog<String>(
    context: context,
    builder: (context) => _EditFieldDialogContent(
      title: title,
      controller: controller,
      hint: hint,
      maxLines: maxLines,
      keyboardType: keyboardType,
    ),
  );
}

class _EditFieldDialogContent extends StatefulWidget {
  final String title;
  final TextEditingController controller;
  final String? hint;
  final int maxLines;
  final TextInputType? keyboardType;

  const _EditFieldDialogContent({
    required this.title,
    required this.controller,
    required this.hint,
    required this.maxLines,
    required this.keyboardType,
  });

  @override
  State<_EditFieldDialogContent> createState() =>
      _EditFieldDialogContentState();
}

class _EditFieldDialogContentState extends State<_EditFieldDialogContent> {
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    // Delay focus until the dialog entrance animation has finished.
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 12,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 24,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(
                      Icons.edit_outlined,
                      size: 20,
                      color: kAdminTextDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Edit ${widget.title}',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: kAdminTextDark,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Update the information below.',
                          style: TextStyle(
                            fontSize: 12,
                            color: kAdminTextGray,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close,
                      size: 20,
                      color: kAdminTextGray,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: kAdminTextDark,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: widget.controller,
                focusNode: _focusNode,
                maxLines: widget.maxLines,
                keyboardType: widget.keyboardType,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(
                  fontSize: 14,
                  color: kAdminTextDark,
                  height: 1.4,
                ),
                decoration: InputDecoration(
                  hintText: widget.hint ??
                      'Enter ${widget.title.toLowerCase()}',
                  hintStyle: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF9CA3AF),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(11),
                    borderSide: const BorderSide(
                      color: kAdminCardBorder,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(11),
                    borderSide: const BorderSide(
                      color: Colors.black,
                      width: 1.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: kAdminTextGray,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(
                      context,
                      widget.controller.text.trim(),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF111111),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Save Changes',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onEdit;
  final String editLabel;
  final IconData editIcon;

  const _DataRow({
    required this.label,
    required this.value,
    this.onEdit,
    this.editLabel = 'Edit',
    this.editIcon = Icons.edit_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: kAdminTextGray,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: kAdminTextDark,
                  ),
                ),
              ],
            ),
          ),
          if (onEdit != null)
            TextButton.icon(
              onPressed: onEdit,
              icon: Icon(editIcon, size: 15),
              label: Text(editLabel),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF2563EB),
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
    );
  }
}

// Shop / Business Info
class _ShopInfoSection extends StatefulWidget {
  final StorageService storageService;

  const _ShopInfoSection({required this.storageService});

  @override
  State<_ShopInfoSection> createState() => _ShopInfoSectionState();
}

class _ShopInfoSectionState extends State<_ShopInfoSection> {
  String _shopName = '';
  String _address = '';
  String _contactNumber = '';
  String _businessHours = '';
  String? _logoUrl;
  bool _logoLoadFailed = false;
  bool _isLoading = true;
  bool _isUploadingLogo = false;
  String? _loadError;

  DocumentReference get _docRef =>
      FirebaseFirestore.instance.collection('shopSettings').doc('config');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final doc = await _docRef.get();

      if (!mounted) return;

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;

        setState(() {
          _shopName = data['shopName'] ?? '';
          _address = data['address'] ?? '';
          _contactNumber = data['contactNumber'] ?? '';
          _businessHours = data['businessHours'] ?? '';
          _logoUrl = data['logoUrl'] as String?;
          _logoLoadFailed = false;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _loadError = 'Unable to load shop info: $e';
      });
    }
  }

  Future<void> _saveField(String field, String value) async {
    try {
      await _docRef.set({
        field: value,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _editShopName() async {
    try {
      final result = await _showEditFieldDialog(
        context,
        title: 'Shop Name',
        initialValue: _shopName,
      );

      if (result != null && result != _shopName && mounted) {
        setState(() => _shopName = result);
        await _saveField('shopName', result);
      }
    } catch (e) {
      debugPrint('Edit Shop Name failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open editor: $e')),
        );
      }
    }
  }

  Future<void> _editAddress() async {
    try {
      final result = await _showEditFieldDialog(
        context,
        title: 'Address',
        initialValue: _address,
        maxLines: 2,
      );

      if (result != null && result != _address && mounted) {
        setState(() => _address = result);
        await _saveField('address', result);
      }
    } catch (e) {
      debugPrint('Edit Address failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open editor: $e')),
        );
      }
    }
  }

  Future<void> _editContactNumber() async {
    try {
      final result = await _showEditFieldDialog(
        context,
        title: 'Contact Number',
        initialValue: _contactNumber,
        keyboardType: TextInputType.phone,
      );

      if (result != null && result != _contactNumber && mounted) {
        setState(() => _contactNumber = result);
        await _saveField('contactNumber', result);
      }
    } catch (e) {
      debugPrint('Edit Contact Number failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open editor: $e')),
        );
      }
    }
  }

  Future<void> _editBusinessHours() async {
    try {
      final result = await _showEditFieldDialog(
        context,
        title: 'Business Hours',
        initialValue: _businessHours,
      );

      if (result != null && result != _businessHours && mounted) {
        setState(() => _businessHours = result);
        await _saveField('businessHours', result);
      }
    } catch (e) {
      debugPrint('Edit Business Hours failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open editor: $e')),
        );
      }
    }
  }

  Future<void> _pickAndUploadLogo() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 85,
    );

    if (picked == null) return;
    if (!mounted) return;

    setState(() => _isUploadingLogo = true);

    try {
      final bytes = await picked.readAsBytes();

      final url = await widget.storageService.uploadPhoto(
        bytes: bytes,
        trackingId: 'shop-logo',
      );

      await _docRef.set(
        {'logoUrl': url},
        SetOptions(merge: true),
      );

      if (!mounted) return;

      setState(() {
        _logoUrl = url;
        _logoLoadFailed = false;
        _isUploadingLogo = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _isUploadingLogo = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_loadError!, style: const TextStyle(color: Colors.red)),
          TextButton(
            onPressed: _load,
            child: const Text('Retry'),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: kAdminBg,
                  backgroundImage: (_logoUrl != null &&
                          _logoUrl!.isNotEmpty &&
                          !_logoLoadFailed)
                      ? NetworkImage(_logoUrl!)
                      : null,
                  // A broken/unreachable image URL (e.g. deleted file,
                  // no internet) would otherwise leave CircleAvatar
                  // stuck trying to paint a failed image forever —
                  // this falls back to the plain icon instead so the
                  // rest of the screen stays usable.
                  onBackgroundImageError: (_logoUrl != null &&
                          _logoUrl!.isNotEmpty)
                      ? (error, stackTrace) {
                          if (mounted) setState(() => _logoLoadFailed = true);
                        }
                      : null,
                  child: (_logoUrl == null ||
                          _logoUrl!.isEmpty ||
                          _logoLoadFailed)
                      ? const Icon(Icons.storefront_outlined,
                          size: 28, color: kAdminTextGray)
                      : null,
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: InkWell(
                    onTap: _isUploadingLogo ? null : _pickAndUploadLogo,
                    customBorder: const CircleBorder(),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: _isUploadingLogo
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.camera_alt,
                              size: 13, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _shopName.isEmpty ? 'Your Shop Name' : _shopName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: kAdminTextDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Tap the camera icon to update your shop logo.',
                    style: TextStyle(fontSize: 11, color: kAdminTextGray),
                  ),
                ],
              ),
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 14),
          child: Divider(height: 1, color: kAdminCardBorder),
        ),
        _DataRow(
          label: 'Shop Name',
          value: _shopName.isEmpty ? 'Not yet set' : _shopName,
          onEdit: _editShopName,
        ),
        const Divider(height: 1, color: kAdminCardBorder),
        _DataRow(
          label: 'Address',
          value: _address.isEmpty ? 'Not yet set' : _address,
          onEdit: _editAddress,
        ),
        const Divider(height: 1, color: kAdminCardBorder),
        _DataRow(
          label: 'Contact Number',
          value: _contactNumber.isEmpty ? 'Not yet set' : _contactNumber,
          onEdit: _editContactNumber,
        ),
        const Divider(height: 1, color: kAdminCardBorder),
        _DataRow(
          label: 'Business Hours',
          value: _businessHours.isEmpty ? 'Not yet set' : _businessHours,
          onEdit: _editBusinessHours,
        ),
      ],
    );
  }
}

// Account / Profile Settings
class _AccountSettingsSection extends StatefulWidget {
  const _AccountSettingsSection();

  @override
  State<_AccountSettingsSection> createState() =>
      _AccountSettingsSectionState();
}

class _AccountSettingsSectionState extends State<_AccountSettingsSection> {
  String _name = '';
  String _email = '';
  String? _photoUrl;
  bool _photoLoadFailed = false;
  bool _isLoading = true;
  bool _isUploadingPhoto = false;
  String? _loadError;

  final _storageService = StorageService();

  DocumentReference? get _docRef {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) return null;

    return FirebaseFirestore.instance.collection('admins').doc(uid);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    final ref = _docRef;

    if (ref == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final doc = await ref.get();

      if (!mounted) return;

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;

        setState(() {
          _name = data['name'] ?? '';
          _email =
              data['email'] ?? FirebaseAuth.instance.currentUser?.email ?? '';
          _photoUrl = data['profilePhotoUrl'] as String?;
          _photoLoadFailed = false;
          _isLoading = false;
        });
      } else {
        setState(() {
          _email = FirebaseAuth.instance.currentUser?.email ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _loadError = 'Unable to load account info: $e';
      });
    }
  }

  Future<void> _editName() async {
    final result = await _showEditFieldDialog(
      context,
      title: 'Admin Name',
      initialValue: _name,
    );

    if (result == null || result == _name) return;

    final ref = _docRef;

    if (ref == null) return;

    try {
      await ref.set(
        {'name': result},
        SetOptions(merge: true),
      );

      if (!mounted) return;

      setState(() => _name = result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 600,
      imageQuality: 85,
    );

    if (picked == null) return;

    final ref = _docRef;

    if (ref == null) return;
    if (!mounted) return;

    setState(() => _isUploadingPhoto = true);

    try {
      final bytes = await picked.readAsBytes();

      final url = await _storageService.uploadPhoto(
        bytes: bytes,
        trackingId:
            'admin-profile-${FirebaseAuth.instance.currentUser?.uid}',
      );

      await ref.set(
        {'profilePhotoUrl': url},
        SetOptions(merge: true),
      );

      if (!mounted) return;

      setState(() {
        _photoUrl = url;
        _photoLoadFailed = false;
        _isUploadingPhoto = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _isUploadingPhoto = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    }
  }

  Future<void> _requestPasswordReset() async {
    if (_email.isEmpty) return;

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: _email);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reset link sent to $_email.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_loadError!, style: const TextStyle(color: Colors.red)),
          TextButton(
            onPressed: _load,
            child: const Text('Retry'),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: kAdminBg,
                  backgroundImage: (_photoUrl != null &&
                          _photoUrl!.isNotEmpty &&
                          !_photoLoadFailed)
                      ? NetworkImage(_photoUrl!)
                      : null,
                  onBackgroundImageError:
                      (_photoUrl != null && _photoUrl!.isNotEmpty)
                          ? (error, stackTrace) {
                              if (mounted) {
                                setState(() => _photoLoadFailed = true);
                              }
                            }
                          : null,
                  child: (_photoUrl == null ||
                          _photoUrl!.isEmpty ||
                          _photoLoadFailed)
                      ? const Icon(Icons.person_outline,
                          size: 28, color: kAdminTextGray)
                      : null,
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: InkWell(
                    onTap: _isUploadingPhoto ? null : _pickAndUploadPhoto,
                    customBorder: const CircleBorder(),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: _isUploadingPhoto
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.camera_alt,
                              size: 13, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _name.isEmpty ? 'Admin' : _name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: kAdminTextDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _email.isEmpty ? 'No email on file' : _email,
                    style: const TextStyle(fontSize: 11, color: kAdminTextGray),
                  ),
                ],
              ),
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 14),
          child: Divider(height: 1, color: kAdminCardBorder),
        ),
        _DataRow(
          label: 'Admin Name',
          value: _name.isEmpty ? 'Not yet set' : _name,
          onEdit: _editName,
        ),
        const Divider(height: 1, color: kAdminCardBorder),
        _DataRow(
          label: 'Email Address',
          value: _email.isEmpty ? 'Not available' : _email,
        ),
        const Divider(height: 1, color: kAdminCardBorder),
        _DataRow(
          label: 'Password',
          value: '••••••••',
          onEdit: _requestPasswordReset,
          editLabel: 'Reset',
          editIcon: Icons.lock_reset_outlined,
        ),
      ],
    );
  }
}

// Notification Settings
const List<String> _kNotifiableStatuses = [
  'Accepted',
  'In Home',
  'In Shop',
  'In Process',
  'Waiting for Parts',
  'Completed',
  'Declined',
];

const Map<String, String> _kDefaultSmsTemplates = {
  'Accepted':
      'RepairTrack: Your repair request (ID: {trackingId}) for your '
          '{applianceType} has been ACCEPTED. Technician {technician} will '
          'be assisting you.',
  'In Home':
      'RepairTrack: Technician {technician} will visit your home to '
          'repair your {applianceType}. Please be available at that time.',
  'In Shop':
      'RepairTrack: Your {applianceType} (ID: {trackingId}) has been '
          'brought to our shop for repair. Assigned to technician '
          '{technician}. We will notify you once it is ready for pickup.',
  'In Process':
      'RepairTrack: Your {applianceType} repair (ID: {trackingId}) is '
          'now IN PROCESS.',
  'Waiting for Parts':
      'RepairTrack: Your {applianceType} repair (ID: {trackingId}) is '
          'currently waiting for parts.',
  'Completed':
      'RepairTrack: Great news! Your {applianceType} repair '
          '(ID: {trackingId}) is now COMPLETE and ready for pickup. Thank '
          'you for trusting RepairTrack!',
  'Declined':
      'RepairTrack: We\'re sorry, your repair request (ID: {trackingId}) '
          'for your {applianceType} has been DECLINED.',
};

class _NotificationSettingsSection extends StatefulWidget {
  const _NotificationSettingsSection();

  @override
  State<_NotificationSettingsSection> createState() =>
      _NotificationSettingsSectionState();
}

class _NotificationSettingsSectionState
    extends State<_NotificationSettingsSection> {
  final Map<String, bool> _smsToggles = {
    for (final s in _kNotifiableStatuses) s: true,
  };

  final Map<String, String> _customTemplates = {};

  bool _emailEnabled = false;
  bool _isLoading = true;
  String? _loadError;

  DocumentReference get _settingsDocRef => FirebaseFirestore.instance
      .collection('notificationSettings')
      .doc('config');

  DocumentReference get _templatesDocRef =>
      FirebaseFirestore.instance.collection('smsTemplates').doc('config');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final settingsDoc = await _settingsDocRef.get();
      final templatesDoc = await _templatesDocRef.get();

      if (!mounted) return;

      if (settingsDoc.exists) {
        final data = settingsDoc.data() as Map<String, dynamic>;

        final smsMap =
            data['smsEnabledByStatus'] as Map<String, dynamic>?;

        if (smsMap != null) {
          for (final s in _kNotifiableStatuses) {
            _smsToggles[s] = smsMap[s] as bool? ?? true;
          }
        }

        _emailEnabled = data['emailEnabled'] as bool? ?? false;
      }

      if (templatesDoc.exists) {
        final data = templatesDoc.data() as Map<String, dynamic>;

        for (final s in _kNotifiableStatuses) {
          final custom = data[s] as String?;

          if (custom != null && custom.trim().isNotEmpty) {
            _customTemplates[s] = custom;
          }
        }
      }

      setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _loadError = 'Unable to load notification settings: $e';
      });
    }
  }

  Future<void> _toggleSms(String status, bool value) async {
    setState(() => _smsToggles[status] = value);

    try {
      await _settingsDocRef.set({
        'smsEnabledByStatus': _smsToggles,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _toggleEmail(bool value) async {
    setState(() => _emailEnabled = value);

    try {
      await _settingsDocRef.set({
        'emailEnabled': value,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _editTemplate(String status) async {
    final currentValue =
        _customTemplates[status] ?? _kDefaultSmsTemplates[status] ?? '';

    final controller = TextEditingController(text: currentValue);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SMS Message — $status',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: kAdminTextDark,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                maxLines: 5,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: kAdminCardBorder),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_customTemplates.containsKey(status))
                    TextButton(
                      onPressed: () =>
                          Navigator.pop(context, '__reset_to_default__'),
                      style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF991B1B)),
                      child: const Text('Reset to default'),
                    )
                  else
                    const SizedBox(),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                            foregroundColor: kAdminTextGray),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () =>
                            Navigator.pop(context, controller.text.trim()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (result == null) return;

    try {
      if (result == '__reset_to_default__') {
        await _templatesDocRef.set(
          {status: FieldValue.delete()},
          SetOptions(merge: true),
        );

        if (mounted) {
          setState(() => _customTemplates.remove(status));
        }
      } else {
        await _templatesDocRef.set(
          {status: result},
          SetOptions(merge: true),
        );

        if (mounted) {
          setState(() => _customTemplates[status] = result);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_loadError!, style: const TextStyle(color: Colors.red)),
          TextButton(
            onPressed: _load,
            child: const Text('Retry'),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SMS Notifications',
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: kAdminTextGray),
        ),
        const SizedBox(height: 4),
        ..._kNotifiableStatuses.map((status) {
          final template =
              _customTemplates[status] ?? _kDefaultSmsTemplates[status] ?? '';
          final isCustom = _customTemplates.containsKey(status);

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        status,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: kAdminTextDark,
                        ),
                      ),
                    ),
                    Switch(
                      value: _smsToggles[status] ?? true,
                      onChanged: (value) => _toggleSms(status, value),
                      activeThumbColor: Colors.white,
                      activeTrackColor: Colors.black,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  template,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: kAdminTextGray),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => _editTemplate(status),
                      icon: const Icon(Icons.edit_outlined, size: 14),
                      label: const Text('Edit message'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                    if (isCustom) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Customized',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2563EB)),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          );
        }).map((row) => Column(
              children: [
                row,
                const Divider(height: 1, color: kAdminCardBorder),
              ],
            )),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Email Notifications',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: kAdminTextDark,
                  ),
                ),
              ),
              Switch(
                value: _emailEnabled,
                onChanged: _toggleEmail,
                activeThumbColor: Colors.white,
                activeTrackColor: Colors.black,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Data & Security
class _DataSecuritySection extends StatefulWidget {
  const _DataSecuritySection();

  @override
  State<_DataSecuritySection> createState() => _DataSecuritySectionState();
}

class _DataSecuritySectionState extends State<_DataSecuritySection> {
  bool _isExporting = false;

  Future<void> _exportRepairRequests() async {
    setState(() => _isExporting = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('repairRequests')
          .orderBy('createdAt', descending: true)
          .get();

      final records = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['docId'] = doc.id;

        data.updateAll((key, value) {
          if (value is Timestamp) {
            return value.toDate().toIso8601String();
          }

          if (value is List) {
            return value.map((e) {
              if (e is Map) {
                final copy = Map<String, dynamic>.from(e);

                copy.updateAll(
                  (k, v) => v is Timestamp
                      ? v.toDate().toIso8601String()
                      : v,
                );

                return copy;
              }

              return e;
            }).toList();
          }

          return value;
        });

        return data;
      }).toList();

      final jsonStr =
          const JsonEncoder.withIndent('  ').convert(records);

      if (mounted) {
        setState(() => _isExporting = false);
        _showExportDialog(jsonStr, records.length);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  void _showExportDialog(String jsonStr, int count) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Export — $count repair record${count == 1 ? '' : 's'}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: kAdminTextDark,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: 560,
                height: 380,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kAdminCardBorder),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    jsonStr,
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style:
                        TextButton.styleFrom(foregroundColor: kAdminTextGray),
                    child: const Text('Close'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: jsonStr));

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Copied to clipboard.'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Download a complete copy of your repair records as a JSON '
          'file — useful for backups or migrating to another system.',
          style: TextStyle(fontSize: 13, color: kAdminTextGray),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isExporting ? null : _exportRepairRequests,
            icon: _isExporting
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_outlined, size: 18),
            label: Text(
              _isExporting ? 'Exporting...' : 'Export Repair Data (JSON)',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: kAdminTextDark,
              side: const BorderSide(color: kAdminCardBorder),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// App Info
class _AppInfoSettingsSection extends StatelessWidget {
  const _AppInfoSettingsSection();

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 12,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.logout_rounded,
                      size: 27,
                      color: Color(0xFFB91C1C),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Sign out of admin account?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: kAdminTextDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'You will be returned to the welcome screen and will need to sign in again to access the admin dashboard.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: kAdminTextGray,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(dialogContext, false);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: kAdminTextDark,
                            side: const BorderSide(
                              color: kAdminCardBorder,
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: 13,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(dialogContext, true);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFB91C1C),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              vertical: 13,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Sign Out',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (confirmed != true) return;

    await AuthService().logout();

    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const WelcomeScreen(),
        ),
        (route) => false,
      );
    }
  }

  void _showInfoDialog(
    BuildContext context,
    String title,
    String body, {
    IconData icon = Icons.info_outline,
  }) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 12,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 520,
              maxHeight: 600,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 20, 14, 18),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(
                          icon,
                          size: 21,
                          color: kAdminTextDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: kAdminTextDark,
                              ),
                            ),
                            const SizedBox(height: 3),
                            const Text(
                              'RepairTrack information',
                              style: TextStyle(
                                fontSize: 12,
                                color: kAdminTextGray,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(
                          Icons.close,
                          size: 20,
                          color: kAdminTextGray,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(
                  height: 1,
                  color: kAdminCardBorder,
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      22,
                      20,
                      22,
                      10,
                    ),
                    child: Text(
                      body,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.65,
                        color: Color(0xFF374151),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF111111),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          vertical: 13,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Close',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _infoTile({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
    bool showDivider = true,
  }) {
    final color = isDestructive ? const Color(0xFF991B1B) : kAdminTextDark;

    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Icon(icon, size: 19, color: color),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
                if (!isDestructive)
                  const Icon(Icons.chevron_right,
                      size: 18, color: kAdminTextGray),
              ],
            ),
          ),
        ),
        if (showDivider)
          const Divider(height: 1, color: kAdminCardBorder, indent: 20),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Color(0xFF16A34A),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'App Version 1.0.0',
                style: TextStyle(fontSize: 12, color: kAdminTextGray),
              ),
            ],
          ),
        ),
        _infoTile(
          context: context,
          icon: Icons.description_outlined,
          label: 'Terms of Service',
          onTap: () => _showInfoDialog(
            context,
            'Terms of Service',
            'RepairTrack is a capstone/pilot system for tracking appliance '
                'repair requests from intake to completion. By using this '
                'system, you agree to use it responsibly, only for lawful '
                'purposes, and to keep customer information confidential.',
            icon: Icons.description_outlined,
          ),
        ),
        _infoTile(
          context: context,
          icon: Icons.privacy_tip_outlined,
          label: 'Privacy Policy',
          onTap: () => _showInfoDialog(
            context,
            'Privacy Policy',
            'Customer details such as name, contact number, and address '
                'are collected solely to process repair requests and to '
                'send status notifications through SMS. Information is not '
                'shared with third parties beyond what is required to '
                'deliver these notifications.',
            icon: Icons.privacy_tip_outlined,
          ),
        ),
        _infoTile(
          context: context,
          icon: Icons.support_agent_outlined,
          label: 'Contact / Support',
          onTap: () => _showInfoDialog(
            context,
            'Contact / Support',
            'For technical issues, feature requests, or questions about '
                'this system, please reach out to the system administrator '
                'or development team.',
            icon: Icons.support_agent_outlined,
          ),
        ),
        _infoTile(
          context: context,
          icon: Icons.logout_rounded,
          label: 'Sign Out',
          isDestructive: true,
          showDivider: false,
          onTap: () => _confirmSignOut(context),
        ),
      ],
    );
  }
}