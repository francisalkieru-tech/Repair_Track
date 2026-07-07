import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../utils/qr_downloader.dart';
import '../../services/firestore_service.dart';
import '../../services/sms_service.dart';
import '../../services/storage_service.dart';
import '../../utils/constants.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  String _selectedFilter = 'All';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestoreService.streamRepairRequests(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final allDocs = snapshot.data?.docs ?? [];

                // Client-side filtering (consistent sa existing pattern ng app)
                final docs = _selectedFilter == 'All'
                    ? allDocs
                    : allDocs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return data['status'] == _selectedFilter;
                      }).toList();

                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      'Walang repair requests${_selectedFilter == 'All' ? '' : ' sa "$_selectedFilter"'}.',
                      style: const TextStyle(color: Color(0xFF6B7280)),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return _buildRequestCard(doc.id, data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    // 'Declined' idinagdag lang dito sa filter (hindi sa
    // AppConstants.allStatuses) dahil hindi 'to dapat lumabas bilang
    // option sa status dropdown ng generic update sheet — makukuha lang
    // ito via ang Decline button sa Review sheet.
    final filters = ['All', ...AppConstants.allStatuses, 'Declined'];

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = filter == _selectedFilter;

          return ChoiceChip(
            label: Text(filter),
            selected: isSelected,
            onSelected: (_) => setState(() => _selectedFilter = filter),
            selectedColor: const Color(0xFF2563EB),
            backgroundColor: Colors.white,
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF374151),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            side: BorderSide(
              color: isSelected
                  ? const Color(0xFF2563EB)
                  : const Color(0xFFE5E7EB),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRequestCard(String docId, Map<String, dynamic> data) {
    final status = data['status'] ?? 'Pending';
    final trackingId = data['trackingId'] ?? '';
    final name = data['name'] ?? '';
    final applianceType = data['applianceType'] ?? '';
    final contactNumber = data['contactNumber'] ?? '';
    final assignedTechnician = data['assignedTechnician'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _handleCardTap(docId, data),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    trackingId,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      letterSpacing: 1,
                      color: Color(0xFF111827),
                    ),
                  ),
                  _buildStatusBadge(status),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$applianceType • $contactNumber',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B7280),
                ),
              ),
              if (assignedTechnician != null &&
                  assignedTechnician.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.engineering_outlined,
                        size: 13, color: Color(0xFF9CA3AF)),
                    const SizedBox(width: 4),
                    Text(
                      assignedTechnician,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: status == 'Completed'
                    ? MainAxisAlignment.spaceBetween
                    : MainAxisAlignment.end,
                children: [
                  if (status == 'Completed')
                    TextButton.icon(
                      onPressed: () => _showQrDialog(trackingId, name),
                      icon: const Icon(Icons.qr_code_2, size: 16),
                      label: const Text('View QR'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF166534),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                    ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'I-update',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.chevron_right,
                          size: 18, color: Color(0xFF2563EB)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Pending pa ang request → kailangan munang i-REVIEW (Accept/Decline)
  /// bago payagan ang admin na tumalon diretso sa status update flow.
  /// Anuman pang status → tuloy na sa normal update sheet.
  void _handleCardTap(String docId, Map<String, dynamic> data) {
    final status = data['status'] ?? 'Pending';
    if (status == 'Pending') {
      _openReviewSheet(docId, data);
    } else {
      _openUpdateSheet(docId, data);
    }
  }

  void _showQrDialog(String trackingId, String customerName) {
    showDialog(
      context: context,
      builder: (context) => _QrCodeDialog(
        trackingId: trackingId,
        customerName: customerName,
      ),
    );
  }

  void _openReviewSheet(String docId, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ReviewRequestSheet(
        docId: docId,
        trackingId: data['trackingId'] ?? '',
        name: data['name'] ?? '',
        contactNumber: data['contactNumber'] ?? '',
        address: data['address'] ?? '',
        applianceType: data['applianceType'] ?? '',
        problemDescription: data['problemDescription'] ?? '',
        initialPhotoUrl: data['initialPhotoUrl'] as String?,
      ),
    );
  }

  void _openUpdateSheet(String docId, Map<String, dynamic> data) {
    final scheduledVisit = data['scheduledVisit'] as Timestamp?;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _UpdateStatusSheet(
        docId: docId,
        currentStatus: data['status'] ?? 'Pending',
        trackingId: data['trackingId'] ?? '',
        contactNumber: data['contactNumber'] ?? '',
        applianceType: data['applianceType'] ?? '',
        currentTechnician: data['assignedTechnician'] as String?,
        initialScheduledDate: scheduledVisit?.toDate(),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final colors = _statusColors(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: colors.$2,
        ),
      ),
    );
  }
}

/// Bawat status may katumbas na (background, text) color pair —
/// pareho ito ng ginamit sa tracking_screen.dart at home_screen.dart
/// para consistent ang tingin sa buong app.
(Color, Color) _statusColors(String status) {
  switch (status) {
    case 'Pending':
      return (const Color(0xFFFEF3C7), const Color(0xFF92400E));
    case 'Accepted':
      return (const Color(0xFFDBEAFE), const Color(0xFF1E40AF));
    case 'In Home':
    case 'In Shop':
      return (const Color(0xFFEDE9FE), const Color(0xFF5B21B6));
    case 'In Process':
      return (const Color(0xFFFCE7F3), const Color(0xFF9D174D));
    case 'Waiting for Parts':
      return (const Color(0xFFFEE2E2), const Color(0xFF991B1B));
    case 'Completed':
      return (const Color(0xFFDCFCE7), const Color(0xFF166534));
    case 'Declined':
      return (const Color(0xFFFEE2E2), const Color(0xFF7F1D1D));
    default:
      return (const Color(0xFFF3F4F6), const Color(0xFF374151));
  }
}

/// Bottom sheet para sa pag-update ng status ng isang repair request.
///
/// Day 16 update: hindi na lahat ng status pareho ang required fields —
///   - In Process / Waiting for Parts → REQUIRED ang note (parts source
///     lumalabas din dito dahil dito lang ito relevant)
///   - In Home → REQUIRED ang schedule (date + time ng technician visit)
///   - Iba pang status → may scripted/template message na, note ay
///     OPTIONAL na lang (extra remarks sa ibabaw ng template)
/// Technician assignment ay laging optional, available sa anumang status.
class _UpdateStatusSheet extends StatefulWidget {
  final String docId;
  final String currentStatus;
  final String trackingId;
  final String contactNumber;
  final String applianceType;
  final String? currentTechnician;
  final DateTime? initialScheduledDate;

  const _UpdateStatusSheet({
    required this.docId,
    required this.currentStatus,
    required this.trackingId,
    required this.contactNumber,
    required this.applianceType,
    this.currentTechnician,
    this.initialScheduledDate,
  });

  @override
  State<_UpdateStatusSheet> createState() => _UpdateStatusSheetState();
}

class _UpdateStatusSheetState extends State<_UpdateStatusSheet> {
  final FirestoreService _firestoreService = FirestoreService();
  final SmsService _smsService = SmsService();
  final StorageService _storageService = StorageService();
  final TextEditingController _noteController = TextEditingController();

  late String _selectedStatus;
  String? _partsSource;
  String? _selectedTechnician;
  DateTime? _scheduledDateTime;
  Uint8List? _selectedImage;
  bool _isSubmitting = false;

  // Sa mga status na ito, REQUIRED ang note (at relevant ang parts source).
  static const _statusesNeedingNote = {'In Process', 'Waiting for Parts'};

  bool get _noteRequired => _statusesNeedingNote.contains(_selectedStatus);
  bool get _partsSourceRelevant => _statusesNeedingNote.contains(_selectedStatus);
  bool get _scheduleRequired => _selectedStatus == 'In Home';

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.currentStatus;
    _selectedTechnician = widget.currentTechnician;
    _scheduledDateTime = widget.initialScheduledDate;
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickSchedule() async {
    final date = await showDatePicker(
      context: context,
      initialDate:
          _scheduledDateTime ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: _scheduledDateTime != null
          ? TimeOfDay.fromDateTime(_scheduledDateTime!)
          : const TimeOfDay(hour: 9, minute: 0),
    );
    if (time == null) return;

    setState(() {
      _scheduledDateTime =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  String _formatSchedule(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} • $hour:$minute $period';
  }

  Future<void> _pickPhoto() async {
    ImageSource source = ImageSource.gallery;

    // Sa Web, diretso lang sa gallery — kung dadaan pa muna sa ibang
    // dialog/await bago tawagin ang pickImage, "nababasag" ang
    // user-gesture chain na kailangan ng browser para buksan ang file
    // dialog, kaya nabi-block 'to nang tahimik (walang error).
    // Sa mobile (Android/iOS), okay lang dumaan sa choice ng Camera
    // o Gallery dahil iba ang plugin implementation dun.
    if (!kIsWeb) {
      final chosen = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Kuhanan ng Camera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Piliin mula sa Gallery'),
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

  Future<String?> _showAddTechnicianDialog() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bagong Technician'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Pangalan ng technician'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Idagdag'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitUpdate() async {
    if (_scheduleRequired && _scheduledDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pumili ng date at oras ng pagpunta ng technician.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_partsSourceRelevant && _partsSource == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Piliin muna ang parts source.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_noteRequired && _noteController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maglagay ng note/remarks para sa update na ito.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // 0. I-upload muna ang photo (kung may pinili) sa Supabase Storage
      String? photoUrl;
      if (_selectedImage != null) {
        photoUrl = await _storageService.uploadPhoto(
          bytes: _selectedImage!,
          trackingId: widget.trackingId,
        );
      }

      // 1. I-update sa Firestore: status + history entry
      await _firestoreService.updateRepairStatus(
        docId: widget.docId,
        trackingId: widget.trackingId,
        newStatus: _selectedStatus,
        note: _noteController.text,
        partsSource: _partsSourceRelevant ? _partsSource : null,
        assignedTechnician: _selectedTechnician,
        scheduledDate: _scheduleRequired ? _scheduledDateTime : null,
        photoUrl: photoUrl,
      );

      // 2. I-trigger ang SMS notification sa customer (may template na
      //    base sa status, plus optional note sa taas nito)
      await _smsService.sendStatusUpdateSms(
        contactNumber: widget.contactNumber,
        trackingId: widget.trackingId,
        applianceType: widget.applianceType,
        newStatus: _selectedStatus,
        note: _noteController.text,
        technician: _selectedTechnician,
        scheduledDate: _scheduleRequired ? _scheduledDateTime : null,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Na-update ang status at na-notify ang customer.'),
            backgroundColor: Color(0xFF166534),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
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

  Widget _buildTechnicianField() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestoreService.streamTechnicians(),
      builder: (context, snapshot) {
        final technicians = (snapshot.data?.docs ?? [])
            .map((doc) => (doc.data() as Map<String, dynamic>)['name'] as String)
            .toList();

        // Kung may existing technician na naka-assign na pero wala pa sa
        // listahan (hal. unang pagkakataon), isama natin para hindi mawala.
        if (_selectedTechnician != null &&
            !technicians.contains(_selectedTechnician)) {
          technicians.add(_selectedTechnician!);
        }

        return DropdownButtonFormField<String>(
          initialValue: _selectedTechnician,
          hint: const Text('Walang naka-assign pa'),
          items: [
            ...technicians.map(
              (name) => DropdownMenuItem(value: name, child: Text(name)),
            ),
            const DropdownMenuItem(
              value: '__add_new__',
              child: Row(
                children: [
                  Icon(Icons.add, size: 16, color: Color(0xFF2563EB)),
                  SizedBox(width: 6),
                  Text('Magdagdag ng Bagong Technician',
                      style: TextStyle(color: Color(0xFF2563EB))),
                ],
              ),
            ),
          ],
          onChanged: (value) async {
            if (value == '__add_new__') {
              final newName = await _showAddTechnicianDialog();
              if (newName != null && newName.trim().isNotEmpty) {
                await _firestoreService.addTechnician(newName.trim());
                setState(() => _selectedTechnician = newName.trim());
              }
            } else {
              setState(() => _selectedTechnician = value);
            }
          },
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'I-update ang Status — ${widget.trackingId}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 20),

              // Status dropdown
              const Text('Bagong Status',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151))),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _selectedStatus,
                items: AppConstants.allStatuses
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _selectedStatus = value);
                },
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Schedule — lumalabas lang pag "In Home"
              if (_scheduleRequired) ...[
                const Text('Schedule ng Pagpunta ng Technician',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151))),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _pickSchedule,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined,
                            size: 18, color: Color(0xFF2563EB)),
                        const SizedBox(width: 10),
                        Text(
                          _scheduledDateTime != null
                              ? _formatSchedule(_scheduledDateTime!)
                              : 'Pumili ng date at oras',
                          style: TextStyle(
                            fontSize: 13,
                            color: _scheduledDateTime != null
                                ? const Color(0xFF111827)
                                : const Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Parts source — lumalabas lang pag In Process o Waiting for Parts
              if (_partsSourceRelevant) ...[
                const Text('Parts Source',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151))),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Customer Supplied'),
                        selected: _partsSource == 'Customer Supplied',
                        onSelected: (_) => setState(
                            () => _partsSource = 'Customer Supplied'),
                        selectedColor: const Color(0xFF2563EB),
                        backgroundColor: const Color(0xFFF9FAFB),
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _partsSource == 'Customer Supplied'
                              ? Colors.white
                              : const Color(0xFF6B7280),
                        ),
                        side: BorderSide(
                          color: _partsSource == 'Customer Supplied'
                              ? const Color(0xFF2563EB)
                              : const Color(0xFFE5E7EB),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Shop Supplied'),
                        selected: _partsSource == 'Shop Supplied',
                        onSelected: (_) =>
                            setState(() => _partsSource = 'Shop Supplied'),
                        selectedColor: const Color(0xFF2563EB),
                        backgroundColor: const Color(0xFFF9FAFB),
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _partsSource == 'Shop Supplied'
                              ? Colors.white
                              : const Color(0xFF6B7280),
                        ),
                        side: BorderSide(
                          color: _partsSource == 'Shop Supplied'
                              ? const Color(0xFF2563EB)
                              : const Color(0xFFE5E7EB),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // Assigned technician — laging available, optional
              const Text('Assigned Technician',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151))),
              const SizedBox(height: 6),
              _buildTechnicianField(),
              const SizedBox(height: 16),

              // Notes/remarks
              Text(
                _noteRequired
                    ? 'Notes / Remarks (required)'
                    : 'Notes / Remarks (optional — may template na message)',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151)),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _noteController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: _noteRequired
                      ? 'Hal: Na-check na ang compressor, kailangan ng bagong fan motor...'
                      : 'Optional — extra na detalye na idadagdag sa template message',
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Photo upload — optional, per status
              const Text('Appliance Photo (optional)',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151))),
              const SizedBox(height: 6),
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
                          'I-tap para magdagdag ng photo',
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFF9CA3AF)),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitUpdate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('I-update at Notify Customer'),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
/// Review sheet para sa mga BAGONG (Pending) request — ipapakita muna
/// dito ang buong detalye ng request (sira, contact, photo kung meron)
/// bago payagan ang admin na mag-Accept o Decline. Sa Accept, magiging
/// "Accepted" ang status at tuloy na sa normal update flow paglipas
/// nito. Sa Decline, kailangan ng reason — magiging "Declined" ang
/// status, terminal na 'yon (parang Completed, hindi na uu-update pa).
class _ReviewRequestSheet extends StatefulWidget {
  final String docId;
  final String trackingId;
  final String name;
  final String contactNumber;
  final String address;
  final String applianceType;
  final String problemDescription;
  final String? initialPhotoUrl;

  const _ReviewRequestSheet({
    required this.docId,
    required this.trackingId,
    required this.name,
    required this.contactNumber,
    required this.address,
    required this.applianceType,
    required this.problemDescription,
    this.initialPhotoUrl,
  });

  @override
  State<_ReviewRequestSheet> createState() => _ReviewRequestSheetState();
}

class _ReviewRequestSheetState extends State<_ReviewRequestSheet> {
  final FirestoreService _firestoreService = FirestoreService();
  final SmsService _smsService = SmsService();
  final TextEditingController _noteController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _decide(String newStatus) async {
    // Required ang reason/remarks kapag Decline — para malinaw sa
    // customer kung bakit. Optional lang kapag Accept.
    if (newStatus == 'Declined' && _noteController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maglagay ng reason kung bakit dini-decline.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _firestoreService.updateRepairStatus(
        docId: widget.docId,
        trackingId: widget.trackingId,
        newStatus: newStatus,
        note: _noteController.text,
      );

      await _smsService.sendStatusUpdateSms(
        contactNumber: widget.contactNumber,
        trackingId: widget.trackingId,
        applianceType: widget.applianceType,
        newStatus: newStatus,
        note: _noteController.text,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus == 'Accepted'
                  ? 'Na-accept ang request at na-notify ang customer.'
                  : 'Na-decline ang request at na-notify ang customer.',
            ),
            backgroundColor: newStatus == 'Accepted'
                ? const Color(0xFF166534)
                : const Color(0xFF7F1D1D),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
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

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF6B7280)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF9CA3AF))),
                Text(value,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF111827))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto =
        widget.initialPhotoUrl != null && widget.initialPhotoUrl!.isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Pending — Need Review',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF92400E)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'I-review ang Request — ${widget.trackingId}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 16),

              if (hasPhoto) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    widget.initialPhotoUrl!,
                    width: double.infinity,
                    height: 160,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        height: 160,
                        alignment: Alignment.center,
                        child:
                            const CircularProgressIndicator(strokeWidth: 2),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 100,
                      alignment: Alignment.center,
                      color: const Color(0xFFF3F4F6),
                      child: const Text('Hindi ma-load ang photo'),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              _buildDetailRow(
                  Icons.person_outline, 'Customer', widget.name),
              _buildDetailRow(
                  Icons.phone_outlined, 'Contact', widget.contactNumber),
              _buildDetailRow(
                  Icons.location_on_outlined, 'Address', widget.address),
              _buildDetailRow(
                  Icons.kitchen_outlined, 'Appliance', widget.applianceType),
              _buildDetailRow(Icons.description_outlined, 'Problem',
                  widget.problemDescription),

              const SizedBox(height: 12),
              const Text('Remarks',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151))),
              const SizedBox(height: 6),
              TextField(
                controller: _noteController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText:
                      'Optional kapag Accept • Required kapag Decline (reason)',
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _isSubmitting ? null : () => _decide('Declined'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF991B1B),
                        side: const BorderSide(color: Color(0xFF991B1B)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed:
                          _isSubmitting ? null : () => _decide('Accepted'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Accept'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dialog para sa pag-view at pag-download ng QR code ng isang
/// COMPLETED repair request — para sa shop's record/printout.
///
/// Ang QR ay naka-encode sa parehong deep link scheme na ginagamit na
/// ng buong app (repairtrack://track/TRACKINGID), kaya kung may
/// device na naka-install ng RepairTrack at nag-scan dito, diretso
/// itong magbubukas sa Tracking Screen ng record na 'yon.
class _QrCodeDialog extends StatefulWidget {
  final String trackingId;
  final String customerName;

  const _QrCodeDialog({
    required this.trackingId,
    required this.customerName,
  });

  @override
  State<_QrCodeDialog> createState() => _QrCodeDialogState();
}

class _QrCodeDialogState extends State<_QrCodeDialog> {
  final GlobalKey _qrBoundaryKey = GlobalKey();
  bool _isSaving = false;

  String get _qrData => 'repairtrack://track/${widget.trackingId}';

  Future<void> _downloadQr() async {
    setState(() => _isSaving = true);
    try {
      // I-capture ang QR widget (sa loob ng RepaintBoundary) bilang
      // isang PNG image sa memory.
      final boundary = _qrBoundaryKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Hindi ma-convert ang QR image sa PNG.');
      }
      final bytes = byteData.buffer.asUint8List();
      final fileName = 'QR_${widget.trackingId}.png';

      if (kIsWeb) {
        // Sa Web: totoong browser file download (diretso sa Downloads
        // folder), hindi ang OS Share dialog.
        downloadBytesAsFile(bytes, fileName);
      } else {
        // Sa mobile: share_plus — lalabas ang native share sheet na
        // may "Save to Files/Gallery" option, mas akma sa mobile UX.
        await Share.shareXFiles(
          [XFile.fromData(bytes, name: fileName, mimeType: 'image/png')],
          text: 'RepairTrack QR Code — ${widget.trackingId}',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download QR: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle,
                color: Color(0xFF166534), size: 32),
            const SizedBox(height: 8),
            Text(
              widget.customerName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFF111827),
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              widget.trackingId,
              style: const TextStyle(
                fontSize: 12,
                letterSpacing: 1,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 16),
            RepaintBoundary(
              key: _qrBoundaryKey,
              child: Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: QrImageView(
                  data: _qrData,
                  version: QrVersions.auto,
                  size: 200,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Scan to view the full service record',
              style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Plain-text version ng laman ng QR — para makita/ma-verify
            // ang actual data nito kahit walang scanner sa kamay.
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _qrData,
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: Color(0xFF374151),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 16),
                    color: const Color(0xFF6B7280),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Copy',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _qrData));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('QR data copied to clipboard.'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Close'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _downloadQr,
                    icon: _isSaving
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.download, size: 18),
                    label: const Text('Download'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}