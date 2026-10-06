import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firestore_service.dart';
import '../../services/job_decline_service.dart';
import '../../widget/decline_job_dialog.dart';
import '../../services/sms_service.dart';
import '../../utils/colors.dart';
import '../../utils/constants.dart';
import '../../utils/technician_availability.dart';
import '../../utils/ui_widgets.dart';
import '../../widget/tech_job_ui.dart';

class TechnicianJobDetailScreen extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;

  const TechnicianJobDetailScreen({
    super.key,
    required this.docId,
    required this.data,
  });

  @override
  State<TechnicianJobDetailScreen> createState() =>
      _TechnicianJobDetailScreenState();
}

class _TechnicianJobDetailScreenState
    extends State<TechnicianJobDetailScreen> {
  final _firestoreService = FirestoreService();
  bool _isSubmitting = false;

  /// Returns true only if the status was actually saved.
  Future<bool> _setStatus(String newStatus, {String? note}) async {
    setState(() => _isSubmitting = true);
    try {
      await _firestoreService.updateRepairStatus(
        docId: widget.docId,
        trackingId: widget.data['trackingId'] ?? '',
        newStatus: newStatus,
        note: note ?? '',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status updated to "$newStatus".')),
        );
        Navigator.pop(context);
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyErrorMessage(e)),
            backgroundColor: AppColors.danger,
          ),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// Tells the customer (SMS + in-app) when the technician starts the
  /// job (In Process / Queued). Parts and completion go through Admin. Best-effort: never throws.
  Future<void> _notifyCustomer(String newStatus, {String? note}) async {
    try {
      final trackingId = widget.data['trackingId'] as String? ?? '';
      final applianceType = widget.data['applianceType'] as String? ?? '';
      final contactNumber = widget.data['contactNumber'] as String? ?? '';
      final techName = widget.data['assignedTechnician'] as String?;

      final shopDoc = await FirebaseFirestore.instance
          .collection('shopSettings')
          .doc('config')
          .get();
      final shopName = shopDoc.data()?['shopName'] as String? ?? 'RepairTrack';

      if (contactNumber.isNotEmpty) {
        await SmsService().sendStatusUpdateSms(
          shopName: shopName,
          contactNumber: contactNumber,
          trackingId: trackingId,
          applianceType: applianceType,
          newStatus: newStatus,
          note: note,
          technician: techName,
        );
      }

      final customerId = widget.data['customerId'] as String?;
      if (customerId != null && customerId.isNotEmpty) {
        final (title, body) = switch (newStatus) {
          'In Process' => (
              'Repair started',
              'Work has started on your $applianceType (ID: $trackingId).'
            ),
          'Queued' => (
              'Repair queued',
              'Your $applianceType (ID: $trackingId) is in the queue and '
                  'will be started soon.'
            ),
          _ => (
              'Repair update',
              'Your $applianceType (ID: $trackingId) is now "$newStatus".'
            ),
        };
        await _firestoreService.createNotification(
          recipientType: 'customer',
          recipientId: customerId,
          title: title,
          body: body,
          trackingId: trackingId,
        );
      }
    } catch (_) {
      // Non-fatal.
    }
  }

  Future<void> _promptWaitingForParts() async {
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (context) => _WaitingForPartsDialog(controller: controller),
    );

    if (note != null && note.isNotEmpty) {
      final saved = await _setStatus('Waiting for Parts', note: note);
      if (!saved) return;

      // Admin is the one who tells the customer about parts (parts
      // decision request), so the technician only alerts Admin here.
      try {
        final trackingId = widget.data['trackingId'] as String? ?? '';
        final applianceType = widget.data['applianceType'] as String? ?? '';
        final techName =
            widget.data['assignedTechnician'] as String? ?? 'Technician';
        await _firestoreService.createNotification(
          recipientType: 'admin',
          title: 'Part needed for a repair',
          body: '$techName flagged "$note" for $applianceType '
              '(ID: $trackingId).',
          trackingId: trackingId,
        );
      } catch (_) {
        // Non-fatal.
      }
    }
  }

  Future<void> _confirmDone() async {
    // Shared app dialog so it matches the other confirmations
    final confirmed = await showAppDialog<bool>(
      context: context,
      title: 'Mark as Done?',
      content: const Text(
        'This tells Admin you\'ve finished the repair on your end. '
        'Admin will review it and confirm it as Completed.',
        style: TextStyle(
            fontSize: AppColors.fontLabel, color: AppColors.textGray),
      ),
      actions: [
        AppDialogAction(
          label: 'Cancel',
          onPressed: () => Navigator.pop(context, false),
        ),
        AppDialogAction(
          label: 'Yes, Done',
          isPrimary: true,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );

    if (confirmed == true) {
      final saved = await _setStatus('Pending Review');
      if (!saved) return;
      try {
        final trackingId = widget.data['trackingId'] as String? ?? '';
        final applianceType = widget.data['applianceType'] as String? ?? '';
        final techName =
            widget.data['assignedTechnician'] as String? ?? 'Technician';
        await _firestoreService.createNotification(
          recipientType: 'admin',
          title: 'Job marked done — needs review',
          body: '$techName finished $applianceType (ID: $trackingId). '
              'Ready for your review.',
          trackingId: trackingId,
        );
      } catch (_) {
        // Non-fatal.
      }
    }
  }

  /// Technician gives the job back (only before the repair is started).
  Future<void> _declineJob() async {
    final techId = widget.data['assignedTechnicianUid'] as String? ?? '';
    final techName = widget.data['assignedTechnician'] as String? ?? '';
    final service = JobDeclineService();

    setState(() => _isSubmitting = true);
    int left;
    try {
      left = await service.declinesLeftThisWeek(techId);
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(friendlyErrorMessage(e)),
          backgroundColor: AppColors.danger,
        ));
      }
      return;
    }
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (left <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('You reached the limit of $kMaxDeclinesPerWeek '
            'declines this week. Please contact Admin.'),
        backgroundColor: AppColors.danger,
      ));
      return;
    }

    final choice = await showDeclineJobDialog(context, declinesLeft: left);
    if (choice == null || !mounted) return;

    setState(() => _isSubmitting = true);
    try {
      final result = await service.decline(
        docId: widget.docId,
        technicianDocId: techId,
        technicianName: techName,
        reason: choice.reason,
        note: choice.note,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.needsAdmin
            ? 'Job declined. No technician is free, so Admin was notified '
                'to reassign it.'
            : 'Job declined and reassigned to ${result.reassignedTo}.'),
      ));
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e is DeclineException
              ? e.message
              : friendlyErrorMessage(e)),
          backgroundColor: AppColors.danger,
        ));
      }
    }
  }

  Widget _declineButton() => SizedBox(
        width: double.infinity,
        height: 48,
        child: OutlinedButton.icon(
          onPressed: _isSubmitting ? null : _declineJob,
          icon: const Icon(Icons.block_outlined, size: 18),
          label: const Text('Decline This Job'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.danger,
            side: const BorderSide(color: AppColors.danger),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );

  Future<void> _startWorking() async {
    final techName = widget.data['assignedTechnician'] as String?;
    if (techName == null || techName.isEmpty) {
      final saved = await _setStatus('In Process');
      if (saved) await _notifyCustomer('In Process');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final allJobsSnap =
          await FirebaseFirestore.instance.collection('repairRequests').get();
      final allJobs =
          allJobsSnap.docs.map((d) => {...d.data(), 'id': d.id}).toList();
      final otherActiveJobs = activeJobsForTechnician(allJobs, techName)
          .where((j) => j['id'] != widget.docId);
      final nextStatus =
          otherActiveJobs.length >= kMaxActiveJobsPerTechnician
              ? 'Queued'
              : 'In Process';
      if (mounted) setState(() => _isSubmitting = false);
      final saved = await _setStatus(nextStatus);
      if (saved) await _notifyCustomer(nextStatus);
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyErrorMessage(e)),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        backgroundColor: AppColors.dark,
        foregroundColor: Colors.white,
        title: const Text('Job Details'),
      ),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('repairRequests')
              .doc(widget.docId)
              .snapshots(),
          builder: (context, snapshot) {
            final data = snapshot.data?.data() ?? widget.data;
            return _buildStatusTab(context, data);
          },
        ),
      ),
    );
  }

  // Card look shared by every block on this screen
  BoxDecoration _cardDecoration() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x07000000),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      );

  // Card with an icon + title, then content
  Widget _section({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: const Color(0xFF374151)),
                ),
                const SizedBox(width: 10),
                Text(title,
                    style: const TextStyle(
                        fontSize: AppColors.fontBody,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark)),
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      );

  Widget _buildStatusTab(BuildContext context, Map<String, dynamic> data) {
    final status = data['status'] as String? ?? 'Pending';
    final appliance = data['applianceType'] as String? ?? 'Appliance';
    final trackingId = data['trackingId'] as String? ?? '';
    final problem = data['problemDescription'] as String? ?? '';
    final brand = data['brand'] as String? ?? '';
    // The request form saves the model as "applianceModel"
    final model = (data['applianceModel'] as String?) ??
        (data['model'] as String?) ??
        '';
    final photoUrl = data['initialPhotoUrl'] as String? ?? '';
    final customerName = data['name'] as String? ?? '';
    final contactNumber = data['contactNumber'] as String? ?? '';
    final address = data['address'] as String? ?? '';
    final createdAt = data['createdAt'] as Timestamp?;
    final partsDecisionStatus = data['partsDecisionStatus'] as String?;
    final partsSource = data['partsSource'] as String?;
    final partsDetails = data['partsDecisionDetails'] as String? ?? '';

    final showParts = partsDetails.isNotEmpty || status == 'Waiting for Parts';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1) Status header: what is this job and where does it stand
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppColors.darkGradient,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appliance,
                      style: const TextStyle(
                          fontSize: AppColors.fontTitle,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: $trackingId',
                      style: const TextStyle(
                          fontSize: AppColors.fontLabel,
                          letterSpacing: 0.5,
                          color: Colors.white70),
                    ),
                    const SizedBox(height: 14),
                    TechStatusBadge(status: status, solid: true),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 2) What to do now (actions come right after the status)
              _section(
                icon: Icons.bolt_outlined,
                title: 'Next Step',
                children: [
                  ..._statusActions(status, partsDecisionStatus, partsSource),
                  if (_isSubmitting) ...[
                    const SizedBox(height: 16),
                    const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.dark)),
                  ],
                ],
              ),
              const SizedBox(height: 14),

              // 3) Part needed (only when relevant)
              if (showParts) ...[
                _section(
                  icon: Icons.inventory_2_outlined,
                  title: 'Part Needed',
                  children: [
                    _DetailRow(
                      icon: Icons.build_outlined,
                      label: 'Part',
                      value: partsDetails.isEmpty ? '—' : partsDetails,
                    ),
                    _DetailRow(
                      icon: Icons.local_shipping_outlined,
                      label: 'Who supplies it',
                      value: partsDecisionStatus == 'decided'
                          ? (partsSource ?? '—')
                          : 'Waiting for customer decision',
                      isLast: true,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ],

              // 4) Customer
              if (customerName.isNotEmpty ||
                  contactNumber.isNotEmpty ||
                  address.isNotEmpty) ...[
                _section(
                  icon: Icons.person_outline,
                  title: 'Customer',
                  children: [
                    if (customerName.isNotEmpty)
                      _DetailRow(
                          icon: Icons.person_outline,
                          label: 'Name',
                          value: customerName),
                    if (contactNumber.isNotEmpty)
                      _DetailRow(
                          icon: Icons.phone_outlined,
                          label: 'Contact',
                          value: contactNumber),
                    if (address.isNotEmpty)
                      _DetailRow(
                          icon: Icons.location_on_outlined,
                          label: 'Address',
                          value: address,
                          isLast: true),
                  ],
                ),
                const SizedBox(height: 14),
              ],

              // 5) Appliance + reported problem
              _section(
                icon: Icons.kitchen_outlined,
                title: 'Appliance',
                children: [
                  _DetailRow(
                      icon: Icons.devices_other_outlined,
                      label: 'Type',
                      value: appliance),
                  if (brand.isNotEmpty)
                    _DetailRow(
                        icon: Icons.sell_outlined,
                        label: 'Brand',
                        value: brand),
                  if (model.isNotEmpty)
                    _DetailRow(
                        icon: Icons.label_outline,
                        label: 'Model',
                        value: model),
                  if (problem.isNotEmpty)
                    _DetailRow(
                        icon: Icons.report_problem_outlined,
                        label: 'Reported problem',
                        value: problem,
                        isLast: photoUrl.isEmpty && createdAt == null),
                  if (photoUrl.isNotEmpty) ...[
                    const Text('Customer photo',
                        style: TextStyle(
                            fontSize: AppColors.fontCaption,
                            color: AppColors.textGray)),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        photoUrl,
                        width: double.infinity,
                        height: 170,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            height: 170,
                            alignment: Alignment.center,
                            child: const CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.dark),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) =>
                            Container(
                          height: 80,
                          alignment: Alignment.center,
                          color: const Color(0xFFF3F4F6),
                          child: const Text('Photo could not be loaded',
                              style: TextStyle(
                                  fontSize: AppColors.fontCaption,
                                  color: AppColors.textGray)),
                        ),
                      ),
                    ),
                    if (createdAt != null) const SizedBox(height: 14),
                  ],
                  if (createdAt != null)
                    _DetailRow(
                        icon: Icons.event_outlined,
                        label: 'Date submitted',
                        value: _formatDate(createdAt.toDate()),
                        isLast: true),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  List<Widget> _statusActions(
    String status,
    String? partsDecisionStatus,
    String? partsSource,
  ) {
    switch (status) {
      case 'Queued':
        return [
          const _InfoBanner(
            text: 'This job is queued behind your other active jobs. '
                'Start it whenever you\'re ready.',
          ),
          const SizedBox(height: 12),
          _actionButton(
            label: 'Start Working',
            icon: Icons.play_circle_outline,
            color: AppColors.inProcess,
            onPressed: _isSubmitting ? null : _startWorking,
          ),
          const SizedBox(height: 10),
          _declineButton(),
        ];

      case 'In Process':
        return [
          _actionButton(
            label: 'Mark as Done',
            icon: Icons.check_circle_outline,
            color: AppColors.success,
            onPressed: _isSubmitting ? null : _confirmDone,
          ),
          const SizedBox(height: 10),
          _actionButton(
            label: 'Waiting for Parts',
            icon: Icons.inventory_2_outlined,
            color: AppColors.waitingParts,
            onPressed: _isSubmitting ? null : _promptWaitingForParts,
          ),
        ];

      case 'Waiting for Parts':
        // Reflect exactly where the parts decision stands:
        if (partsDecisionStatus == 'decided') {
          final resolvedText = partsSource == 'Customer Supplied'
              ? 'Customer will supply this part themselves. Sit tight — '
                  'Admin will move this back to "In Process" once it '
                  'arrives at the shop.'
              : 'Shop will supply this part. Admin is sourcing it and '
                  'will move this back to "In Process" once it\'s ready.';
          return [_InfoBanner(text: resolvedText)];
        }
        if (partsDecisionStatus == 'awaiting_customer') {
          return const [
            _InfoBanner(
              text: 'Waiting for the customer to decide who supplies '
                  'this part. You\'ll be able to continue once that\'s '
                  'settled and Admin moves this back to "In Process".',
            ),
          ];
        }
        return const [
          _InfoBanner(
            text: 'Waiting on Admin to source the part. You\'ll be able '
                'to continue once it arrives.',
          ),
        ];

      case 'Pending Review':
        return [
          const _InfoBanner(
            text: 'Marked as done — waiting for Admin to confirm and '
                'close out this job.',
          ),
        ];

      case 'Accepted':
      case 'On-Site':
      case 'Tech Visit':
      case 'In Shop': // old value, until migrated
      case 'In Home': // old value, until migrated
        // Admin has accepted and assigned this job to you but hasn't
        // moved it into your active queue yet — you decide when to
        // pick it up, same as a job sitting in "Waiting to process".
        return [
          const _InfoBanner(
            text: 'Assigned to you. Start whenever you\'re ready to '
                'begin the repair.',
          ),
          const SizedBox(height: 12),
          _actionButton(
            label: 'Start to Repair',
            icon: Icons.play_circle_outline,
            color: AppColors.inProcess,
            onPressed: _isSubmitting ? null : _startWorking,
          ),
          const SizedBox(height: 10),
          _declineButton(),
        ];

      default:
        // Pending / Declined / Completed and anything else — not a
        // stage where the technician has an action to take.
        return [
          _InfoBanner(
              text: 'Current status: ${AppConstants.displayLabel(status)}'),
        ];
    }
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          textStyle: const TextStyle(
              fontSize: AppColors.fontBody, fontWeight: FontWeight.w600),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

class _WaitingForPartsDialog extends StatefulWidget {
  final TextEditingController controller;

  const _WaitingForPartsDialog({required this.controller});

  @override
  State<_WaitingForPartsDialog> createState() =>
      _WaitingForPartsDialogState();
}

class _WaitingForPartsDialogState extends State<_WaitingForPartsDialog> {
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('What part is needed?'),
      content: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        maxLines: 2,
        decoration: const InputDecoration(
          hintText: 'e.g. Compressor, door seal, control board',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, widget.controller.text.trim()),
          child: const Text('Submit'),
        ),
      ],
    );
  }
}

/// Label-on-top detail row used inside the section cards.
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textGray),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: AppColors.fontCaption,
                        color: AppColors.textGray)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        fontSize: AppColors.fontBody - 1,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textDark)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final String text;
  const _InfoBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: Color(0xFF4B5563)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  fontSize: AppColors.fontLabel,
                  height: 1.4,
                  color: Color(0xFF374151)),
            ),
          ),
        ],
      ),
    );
  }
}
