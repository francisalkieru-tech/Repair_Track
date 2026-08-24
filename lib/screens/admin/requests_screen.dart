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
import 'admin_theme.dart';

// Repair request management screen.
// Tabs: New Request, Accepted, and In Process.
// Handles request listing and filtering.
// Handles request review actions.
// Handles repair status updates.
// Handles QR code display.

/// Requests page.
class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen>
    with SingleTickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
// Creates the three request tabs.
// Keeps the TabBar and TabBarView synchronized.
// Prevents tab count mismatch errors.
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: kAdminBrand,
            unselectedLabelColor: kAdminTextGray,
            indicatorColor: kAdminBrand,
            labelStyle:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            tabs: const [
              Tab(text: 'New Request'),
              Tab(text: 'Accepted'),
              Tab(text: 'In Process'),
            ],
          ),
        ),
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

// Filters requests using their Firestore status.
// Each request is checked by its status.
// Status values must match exactly.
// Firestore status matching is case-sensitive.
// Example: "Pending" is different from "pending".

// New Request: pending admin review.
              final pendingDocs = allDocs.where((d) {
                final data = d.data() as Map<String, dynamic>;
                return data['status'] == 'Pending';
              }).toList();

// Accepted: approved requests.
// Requests not yet in active repair.
              final acceptedDocs = allDocs.where((d) {
                final data = d.data() as Map<String, dynamic>;
                return data['status'] == 'Accepted';
              }).toList();

// In Process: active repair requests.
// Includes current active repair stages.
// Add new active statuses here when needed.
// Excludes completed and declined requests.
// Displays active repair requests.
              final inProcessDocs = allDocs.where((d) {
                final data = d.data() as Map<String, dynamic>;
                final s = data['status'];
                return s != 'Pending' &&
                    s != 'Accepted' &&
                    s != 'Completed' &&
                    s != 'Declined';
              }).toList();

              return TabBarView(
                controller: _tabController,
                children: [
                  _buildList(pendingDocs,
                      emptyText: 'No new repair requests.'),
                  _buildList(acceptedDocs,
                      emptyText: 'No accepted requests yet.'),
                  _buildList(inProcessDocs,
                      emptyText: 'No ongoing repairs right now.'),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildList(List<QueryDocumentSnapshot> docs,
      {required String emptyText}) {
    if (docs.isEmpty) {
      return Center(
        child: Text(emptyText, style: const TextStyle(color: kAdminTextGray)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final doc = docs[index];
        final data = doc.data() as Map<String, dynamic>;
        return buildRequestCard(context, doc.id, data);
      },
    );
  }
}

// QR is available only for eligible statuses.
// Checks whether the current status allows QR viewing.
// Status matching is case-sensitive.
const _kQrEligibleStatuses = {
  'In Home',
  'In Shop',
  'In Process',
  'Waiting for Parts',
  'Completed',
};

// Builds a repair request card.
// Used by all three request tabs.
// Displays request information and actions.
// Shows tracking and repair details.
// Includes status and update controls.
Widget buildRequestCard(BuildContext context, String docId, Map<String, dynamic> data) {
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
        onTap: () => _handleCardTap(context, docId, data),
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
                mainAxisAlignment: _kQrEligibleStatuses.contains(status)
                    ? MainAxisAlignment.spaceBetween
                    : MainAxisAlignment.end,
                children: [
                  if (_kQrEligibleStatuses.contains(status))
                    TextButton.icon(
                      onPressed: () => _showQrDialog(context, trackingId, name),
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
                        'Update',
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

// Opens the correct modal for the request status.
// Pending requests open the review sheet.
// Other requests open the status update sheet.
// Selects the appropriate modal.
void _handleCardTap(BuildContext context, String docId, Map<String, dynamic> data) {
    final status = data['status'] ?? 'Pending';
    if (status == 'Pending') {
      _openReviewSheet(context, docId, data);
    } else {
      _openUpdateSheet(context, docId, data);
    }
  }

void _showQrDialog(BuildContext context, String trackingId, String customerName) {
    showDialog(
      context: context,
      builder: (context) => _QrCodeDialog(
        trackingId: trackingId,
        customerName: customerName,
      ),
    );
  }

void _openReviewSheet(BuildContext context, String docId, Map<String, dynamic> data) {
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

void _openUpdateSheet(BuildContext context, String docId, Map<String, dynamic> data) {
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
    final colors = statusColors(status);
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
// Repair status update modal.
// Handles the repair status progression.
// Provides the main status update form.
// Fields depend on the selected status.
// Required fields vary by status.
// Uses conditional field rules below.
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

  int? _warrantyMonths = 2;
  final TextEditingController _warrantyTermsController =
      TextEditingController(
    text: 'Covers the same issue that was repaired. Does not cover new '
        'damage or misuse.',
  );

// Defines the allowed repair status flow.
// Controls the next status options.
// Edit this map to change the status flow.
// Format: current status -> next statuses.
// Gets valid next statuses for the current stage.
// Prevents selecting previous stages.
// Keeps status progression in order.
// Hides invalid previous statuses.
  static const Map<String, List<String>> _nextStatusOptions = {
    'Accepted': ['In Shop', 'In Home'],
    'In Shop': ['In Process', 'Waiting for Parts'],
    'In Home': ['In Process', 'Waiting for Parts', 'Completed'],
    'Waiting for Parts': ['In Process'],
    'In Process': ['Waiting for Parts', 'Completed'],
  };

  List<String> get _availableStatuses =>
      _nextStatusOptions[widget.currentStatus] ?? [widget.currentStatus];

// Parts source is optional for active repairs.
// Records where the replacement part comes from.
// Used when a parts source must be recorded.
// Supports customer- or shop-supplied parts.
  static const _statusesNeedingPartsSource = {
    'In Process',
    'Waiting for Parts',
  };

// Controls fields shown for each status.
// Fields are displayed based on the selected status.
// Checks whether conditional fields are visible.
// Controls warranty and parts source fields.
// Completion requires a service note.
// The note stores the service summary.
// Waiting for Parts also requires a note.
// Records the required repair details.
  bool get _noteRequired =>
      _selectedStatus == 'Completed' || _selectedStatus == 'Waiting for Parts';
  bool get _partsSourceRelevant =>
      _statusesNeedingPartsSource.contains(_selectedStatus);
  bool get _scheduleRequired => _selectedStatus == 'In Home';
  bool get _warrantyRelevant => _selectedStatus == 'Completed';

  @override
  void initState() {
    super.initState();
// Selects the first valid next status by default.
// The current status is not selectable.
// Keeps the status flow moving forward.
    _selectedStatus = _availableStatuses.first;
    _selectedTechnician = widget.currentTechnician;
    _scheduledDateTime = widget.initialScheduledDate;
  }

  @override
  void dispose() {
    _noteController.dispose();
    _warrantyTermsController.dispose();
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

    if (!kIsWeb) {
      final chosen = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Take Photo with Camera'),
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

  Future<String?> _showAddTechnicianDialog() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Technician'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Technician name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

// Validates and submits the repair status update.
// Uploads photos, updates Firestore, creates QR status, and sends SMS.
// Stops submission when required data is missing.
// Handles update errors through the try/catch block.
// SMS errors are handled by the SMS service.
// The SMS service manages customer notifications.
  Future<void> _submitUpdate() async {
    if (_scheduleRequired && _scheduledDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select the date and time of the technician visit.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_partsSourceRelevant && _partsSource == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a parts source first.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_noteRequired && _noteController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a note/remarks for this update.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      String? photoUrl;
      if (_selectedImage != null) {
        photoUrl = await _storageService.uploadPhoto(
          bytes: _selectedImage!,
          trackingId: widget.trackingId,
        );
      }

      await _firestoreService.updateRepairStatus(
        docId: widget.docId,
        trackingId: widget.trackingId,
        newStatus: _selectedStatus,
        note: _noteController.text,
        partsSource: _partsSourceRelevant ? _partsSource : null,
        assignedTechnician: _selectedTechnician,
        scheduledDate: _scheduleRequired ? _scheduledDateTime : null,
        photoUrl: photoUrl,
        warrantyMonths: _warrantyRelevant ? _warrantyMonths : null,
        warrantyTerms: _warrantyRelevant
            ? _warrantyTermsController.text
            : null,
      );

// Creates the QR record when the status becomes In Home.
// Creates it only if needed.
// Makes the QR available without another shop visit.
// Stores the tracking ID as the QR content.
// Creates the QR only once.
// Scanned details are loaded from Firestore.
      if (_selectedStatus == 'In Home') {
        await FirebaseFirestore.instance
            .collection('repairRequests')
            .doc(widget.docId)
            .set({'hasQrCode': true}, SetOptions(merge: true));
      }

      final shopInfoDoc = await FirebaseFirestore.instance
          .collection('shopSettings')
          .doc('config')
          .get();
      final shopName = shopInfoDoc.data()?['shopName'] ?? 'RepairTrack';

      await _smsService.sendStatusUpdateSms(
        shopName: shopName,
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
            content: Text('Status updated and customer notified.'),
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

        if (_selectedTechnician != null &&
            !technicians.contains(_selectedTechnician)) {
          technicians.add(_selectedTechnician!);
        }

        return DropdownButtonFormField<String>(
          initialValue: _selectedTechnician,
          hint: const Text('Not yet assigned'),
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
                  Text('Add New Technician',
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusColors(widget.currentStatus).$1,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.currentStatus,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColors(widget.currentStatus).$2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Update the Status of ${widget.trackingId}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 20),

              const Text('Update Status',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151))),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _selectedStatus,
                items: _availableStatuses
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

              if (_scheduleRequired) ...[
                const Text('Technician Visit Schedule',
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
                              : 'Select date and time',
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

              if (_warrantyRelevant) ...[
                const Text('Warranty Period',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151))),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [1, 2, 3].map((months) {
                    final isSelected = _warrantyMonths == months;
                    return ChoiceChip(
                      label: Text(months == 1 ? '1 Month' : '$months Month'),
                      selected: isSelected,
                      onSelected: (_) =>
                          setState(() => _warrantyMonths = months),
                      selectedColor: const Color(0xFF166534),
                      backgroundColor: const Color(0xFFF9FAFB),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF6B7280),
                      ),
                      side: BorderSide(
                        color: isSelected
                            ? const Color(0xFF166534)
                            : const Color(0xFFE5E7EB),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                const Text('Warranty Terms',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151))),
                const SizedBox(height: 6),
                TextField(
                  controller: _warrantyTermsController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'What does this warranty cover?',
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              const Text('Assigned Technician',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151))),
              const SizedBox(height: 6),
              _buildTechnicianField(),
              const SizedBox(height: 16),

              Text(
                _selectedStatus == 'Completed'
                    ? 'Notes / Remarks (Required)'
                    : _noteRequired
                        ? 'Notes / Remarks (Required)'
                        : 'Notes / Remarks (Optional — template message included)',
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
                  hintText: _selectedStatus == 'Completed'
                      ? 'Put details on what is being repaired on the appliance.'
                      : _noteRequired
                          ? 'Provide details on the delay or the expected '
                              'arrival of the part.'
                          : 'Optional — additional details to add to the '
                              'template message',
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

              const Text('Appliance Photo (Optional)',
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
                          'Tap to add a photo',
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
                      : const Text('Update'),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'When you hit Update, it automatically updates the '
                'customer through SMS or in-app notification.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// Repair request review modal.
// Opens for pending requests.
// Supports accepting or declining a request.
// Displays customer and repair details.
// Includes the request photo when available.
// Uses data passed from the review sheet opener.
// =====================================================================
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

// Updates a request to Accepted or Declined.
// A decline requires a reason.
// Saves the new status and notifies the customer.
  Future<void> _decide(String newStatus) async {
    if (newStatus == 'Declined' && _noteController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a reason for declining.'),
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

      final shopInfoDoc = await FirebaseFirestore.instance
          .collection('shopSettings')
          .doc('config')
          .get();
      final shopName = shopInfoDoc.data()?['shopName'] ?? 'RepairTrack';

      await _smsService.sendStatusUpdateSms(
        shopName: shopName,
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
                  ? 'Request accepted and customer notified.'
                  : 'Request declined and customer notified.',
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
                      'Pending - Need to Review',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF92400E)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Review The Request - ${widget.trackingId}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildDetailRow(
                            Icons.person_outline, 'Customer', widget.name),
                        _buildDetailRow(Icons.phone_outlined, 'Contact Number',
                            widget.contactNumber),
                        _buildDetailRow(Icons.location_on_outlined,
                            'Location', widget.address),
                        _buildDetailRow(Icons.kitchen_outlined, 'Appliance',
                            widget.applianceType),
                        _buildDetailRow(Icons.description_outlined,
                            'Appliance Problem', widget.problemDescription),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Appliances Photo',
                            style: TextStyle(
                                fontSize: 11, color: Color(0xFF9CA3AF))),
                        const SizedBox(height: 6),
                        if (hasPhoto)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              widget.initialPhotoUrl!,
                              width: double.infinity,
                              height: 130,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return Container(
                                  height: 130,
                                  alignment: Alignment.center,
                                  color: const Color(0xFFF3F4F6),
                                  child: const CircularProgressIndicator(
                                      strokeWidth: 2),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                height: 130,
                                alignment: Alignment.center,
                                color: const Color(0xFFF3F4F6),
                                child: const Text('Unable to load photo',
                                    style: TextStyle(fontSize: 11)),
                              ),
                            ),
                          )
                        else
                          Container(
                            width: double.infinity,
                            height: 130,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
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
                      'Optional notes if Accept, Required if decline (reason)',
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
                          : const Text('Accepted'),
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

// QR code dialog.
// Displays the generated repair QR code.
// Encodes the tracking ID as a deep link.
// QR details are retrieved from Firestore.
// The QR does not need regeneration after status updates.
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
      final boundary = _qrBoundaryKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Unable to convert the QR image to PNG.');
      }
      final bytes = byteData.buffer.asUint8List();
      final fileName = 'QR_${widget.trackingId}.png';

      if (kIsWeb) {
        downloadBytesAsFile(bytes, fileName);
      } else {
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
