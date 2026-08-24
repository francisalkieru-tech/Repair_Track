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

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _storageService = StorageService();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ShopInfoSection(storageService: _storageService),
          const Divider(),
          const _AccountSettingsSection(),
          const Divider(),
          const _NotificationSettingsSection(),
          const Divider(),
          const _DataSecuritySection(),
          const Divider(),
          const _AppInfoSettingsSection(),
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
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(hintText: hint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

class _DataRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onEdit;

  const _DataRow({
    required this.label,
    required this.value,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text('$label: $value'),
          ),
          if (onEdit != null)
            TextButton(
              onPressed: onEdit,
              child: const Text('Edit'),
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
    final result = await _showEditFieldDialog(
      context,
      title: 'Shop Name',
      initialValue: _shopName,
    );

    if (result != null && result != _shopName) {
      setState(() => _shopName = result);
      await _saveField('shopName', result);
    }
  }

  Future<void> _editAddress() async {
    final result = await _showEditFieldDialog(
      context,
      title: 'Address',
      initialValue: _address,
      maxLines: 2,
    );

    if (result != null && result != _address) {
      setState(() => _address = result);
      await _saveField('address', result);
    }
  }

  Future<void> _editContactNumber() async {
    final result = await _showEditFieldDialog(
      context,
      title: 'Contact Number',
      initialValue: _contactNumber,
      keyboardType: TextInputType.phone,
    );

    if (result != null && result != _contactNumber) {
      setState(() => _contactNumber = result);
      await _saveField('contactNumber', result);
    }
  }

  Future<void> _editBusinessHours() async {
    final result = await _showEditFieldDialog(
      context,
      title: 'Business Hours',
      initialValue: _businessHours,
    );

    if (result != null && result != _businessHours) {
      setState(() => _businessHours = result);
      await _saveField('businessHours', result);
    }
  }

  Future<void> _pickAndUploadLogo() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 85,
    );

    if (picked == null) return;

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
          Text(_loadError!),
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
          'Shop / Business Info',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _DataRow(
          label: 'Shop Name',
          value: _shopName.isEmpty ? 'Not yet set' : _shopName,
          onEdit: _editShopName,
        ),
        _DataRow(
          label: 'Address',
          value: _address.isEmpty ? 'Not yet set' : _address,
          onEdit: _editAddress,
        ),
        _DataRow(
          label: 'Contact Number',
          value: _contactNumber.isEmpty ? 'Not yet set' : _contactNumber,
          onEdit: _editContactNumber,
        ),
        _DataRow(
          label: 'Business Hours',
          value: _businessHours.isEmpty ? 'Not yet set' : _businessHours,
          onEdit: _editBusinessHours,
        ),
        _DataRow(
          label: 'Logo',
          value: _logoUrl == null || _logoUrl!.isEmpty
              ? 'Not uploaded'
              : _logoUrl!,
        ),
        TextButton(
          onPressed: _isUploadingLogo ? null : _pickAndUploadLogo,
          child: Text(_isUploadingLogo ? 'Uploading...' : 'Change Logo'),
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
          Text(_loadError!),
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
          'Account / Profile Settings',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _DataRow(
          label: 'Admin Name',
          value: _name.isEmpty ? 'Not yet set' : _name,
          onEdit: _editName,
        ),
        _DataRow(
          label: 'Email Address',
          value: _email.isEmpty ? 'Not available' : _email,
        ),
        _DataRow(
          label: 'Profile Photo',
          value: _photoUrl == null || _photoUrl!.isEmpty
              ? 'Not uploaded'
              : _photoUrl!,
        ),
        TextButton(
          onPressed: _isUploadingPhoto ? null : _pickAndUploadPhoto,
          child: Text(_isUploadingPhoto ? 'Uploading...' : 'Change Photo'),
        ),
        _DataRow(
          label: 'Password',
          value: 'Hidden',
          onEdit: _requestPasswordReset,
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
      builder: (context) => AlertDialog(
        title: Text('SMS Template - $status'),
        content: TextField(
          controller: controller,
          maxLines: 5,
        ),
        actions: [
          if (_customTemplates.containsKey(status))
            TextButton(
              onPressed: () => Navigator.pop(context, '__reset_to_default__'),
              child: const Text('Reset'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
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
          Text(_loadError!),
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
          'Notification Settings',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ..._kNotifiableStatuses.map((status) {
          final template =
              _customTemplates[status] ?? _kDefaultSmsTemplates[status] ?? '';

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(status)),
                  Switch(
                    value: _smsToggles[status] ?? true,
                    onChanged: (value) => _toggleSms(status, value),
                  ),
                  TextButton(
                    onPressed: () => _editTemplate(status),
                    child: const Text('Edit'),
                  ),
                ],
              ),
              Text(
                template,
                style: const TextStyle(fontSize: 12),
              ),
              const Divider(),
            ],
          );
        }),
        Row(
          children: [
            const Expanded(child: Text('Email Notifications')),
            Switch(
              value: _emailEnabled,
              onChanged: _toggleEmail,
            ),
          ],
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
      builder: (context) => AlertDialog(
        title: Text('Export - $count repair record(s)'),
        content: SizedBox(
          width: 500,
          height: 400,
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Clipboard.setData(
                ClipboardData(text: jsonStr),
              );

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Copied to clipboard.'),
                ),
              );
            },
            child: const Text('Copy'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Data & Security',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text('Export all repair requests as JSON.'),
        TextButton(
          onPressed: _isExporting ? null : _exportRepairRequests,
          child: Text(
            _isExporting ? 'Exporting...' : 'Export Repair Data',
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
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
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
    String body,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'App Info',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text('App Version: 1.0.0'),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => _showInfoDialog(
            context,
            'Terms of Service',
            'RepairTrack is a capstone/pilot app for tracking appliance repair requests. '
            'Use the system responsibly and only for lawful purposes.',
          ),
          child: const Text('Terms of Service'),
        ),
        TextButton(
          onPressed: () => _showInfoDialog(
            context,
            'Privacy Policy',
            'Customer details are used for processing repair requests and '
            'for notifications through the SMS provider.',
          ),
          child: const Text('Privacy Policy'),
        ),
        TextButton(
          onPressed: () => _showInfoDialog(
            context,
            'Contact / Support',
            'Contact the developer or administrator for support.',
          ),
          child: const Text('Contact / Support'),
        ),
        TextButton(
          onPressed: () => _confirmSignOut(context),
          child: const Text('Sign Out'),
        ),
      ],
    );
  }
}
