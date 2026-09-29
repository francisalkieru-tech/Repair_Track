import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firestore_service.dart';
import '../../services/sms_service.dart';
import '../../utils/colors.dart';
import '../../utils/constants.dart';
import '../../utils/technician_availability.dart';


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

  Future<void> _setStatus(String newStatus, {String? note}) async {
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _promptWaitingForParts() async {
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (context) => _WaitingForPartsDialog(controller: controller),
    );

    if (note != null && note.isNotEmpty) {
      await _setStatus('Waiting for Parts', note: note);

      try {
        final trackingId = widget.data['trackingId'] as String? ?? '';
        final applianceType = widget.data['applianceType'] as String? ?? '';
        final contactNumber = widget.data['contactNumber'] as String? ?? '';
        final techName =
            widget.data['assignedTechnician'] as String? ?? 'Technician';

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
            newStatus: 'Waiting for Parts',
            note: note,
          );
        }

        await _firestoreService.createNotification(
          recipientType: 'admin',
          title: 'Part needed for a repair',
          body: '$techName flagged "$note" for $applianceType '
              '(ID: $trackingId).',
          trackingId: trackingId,
        );

        final customerId = widget.data['customerId'] as String?;
        if (customerId != null && customerId.isNotEmpty) {
          await _firestoreService.createNotification(
            recipientType: 'customer',
            recipientId: customerId,
            title: 'Waiting on a part',
            body: 'Your $applianceType repair (ID: $trackingId) is '
                'currently waiting for a part.',
            trackingId: trackingId,
          );
        }
      } catch (_) {
        // Non-fatal.
      }
    }
  }

  Future<void> _confirmDone() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Mark as Done?'),
        content: const Text(
          'This tells Admin you\'ve finished the repair on your end. '
          'Admin will review it and confirm it as Completed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, Done'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _setStatus('Pending Review');
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

  Future<void> _startWorking() async {
    final techName = widget.data['assignedTechnician'] as String?;
    if (techName == null || techName.isEmpty) {
      await _setStatus('In Process');
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
      await _setStatus(nextStatus);
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
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

  Widget _buildStatusTab(BuildContext context, Map<String, dynamic> data) {
    final status = data['status'] as String? ?? 'Pending';
    final appliance = data['applianceType'] as String? ?? 'Appliance';
    final trackingId = data['trackingId'] as String? ?? '';
    final problem = data['problemDescription'] as String? ?? '';
    final brand = data['brand'] as String? ?? '';
    final model = data['model'] as String? ?? '';
    final customerName = data['name'] as String? ?? '';
    final contactNumber = data['contactNumber'] as String? ?? '';
    final address = data['address'] as String? ?? '';
    final createdAt = data['createdAt'] as Timestamp?;
    final partsDecisionStatus = data['partsDecisionStatus'] as String?;
    final partsSource = data['partsSource'] as String?;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header — appliance, status badge, tracking/brand/model.
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(appliance,
                          style: const TextStyle(
                              fontSize: AppColors.fontTitle,
                              fontWeight: FontWeight.bold)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.inProcess.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        AppConstants.displayLabel(status),
                        style: const TextStyle(
                          fontSize: AppColors.fontCaption,
                          fontWeight: FontWeight.w700,
                          color: AppColors.inProcess,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    'ID: $trackingId',
                    if (brand.isNotEmpty) 'Brand: $brand',
                    if (model.isNotEmpty) 'Model: $model',
                  ].join(' · '),
                  style: const TextStyle(
                      fontSize: AppColors.fontCaption,
                      color: AppColors.textGray),
                ),
              ],
            ),
          ),

          
          if (customerName.isNotEmpty ||
              contactNumber.isNotEmpty ||
              address.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Customer',
                      style: TextStyle(
                          fontSize: AppColors.fontCaption,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textGray)),
                  const SizedBox(height: 10),
                  if (customerName.isNotEmpty)
                    _InfoRow(icon: Icons.person_outline, text: customerName),
                  if (contactNumber.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _InfoRow(icon: Icons.phone_outlined, text: contactNumber),
                  ],
                  if (address.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _InfoRow(icon: Icons.location_on_outlined, text: address),
                  ],
                ],
              ),
            ),
          ],

          // Reported problem 
          if (problem.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Reported problem',
                      style: TextStyle(
                          fontSize: AppColors.fontCaption,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textGray)),
                  const SizedBox(height: 6),
                  Text(problem,
                      style: const TextStyle(
                          fontSize: AppColors.fontLabel, height: 1.4)),
                ],
              ),
            ),
          ],

          if (createdAt != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event_outlined,
                      size: 16, color: AppColors.textGray),
                  const SizedBox(width: 8),
                  const Text('Date submitted',
                      style: TextStyle(
                          fontSize: AppColors.fontCaption,
                          color: AppColors.textGray)),
                  const Spacer(),
                  Text(_formatDate(createdAt.toDate()),
                      style: const TextStyle(
                          fontSize: AppColors.fontLabel,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          const Text('Update Status',
              style: TextStyle(
                  fontSize: AppColors.fontBody, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ..._statusActions(status, partsDecisionStatus, partsSource),
          if (_isSubmitting) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
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
        ];

      case 'In Process':
        return [
          _actionButton(
            label: 'Waiting for Parts',
            icon: Icons.inventory_2_outlined,
            color: AppColors.waitingParts,
            onPressed: _isSubmitting ? null : _promptWaitingForParts,
          ),
          const SizedBox(height: 10),
          _actionButton(
            label: 'Mark as Done',
            icon: Icons.check_circle_outline,
            color: AppColors.completed,
            onPressed: _isSubmitting ? null : _confirmDone,
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
      case 'In Shop':
      case 'In Home':
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
        ];

      default:
        // Pending / Declined / Completed and anything else — not a
        // stage where the technician has an action to take.
        return [
          _InfoBanner(text: 'Current status: ${AppConstants.displayLabel(status)}'),
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
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
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

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textGray),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: const TextStyle(fontSize: AppColors.fontLabel)),
        ),
      ],
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
            fontSize: AppColors.fontLabel, color: AppColors.textGray),
      ),
    );
  }
}
