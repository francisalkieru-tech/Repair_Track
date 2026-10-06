import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/colors.dart';
import '../../utils/ui_widgets.dart';
import '../../utils/constants.dart';
import '../../services/firestore_service.dart';
import '../../services/sms_service.dart';

class TrackingScreen extends StatelessWidget {
  final String trackingId;
  const TrackingScreen({super.key, required this.trackingId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Track Repair',
            style: TextStyle(
                color: AppColors.textDark, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('repairRequests')
            .where('trackingId', isEqualTo: trackingId)
            .limit(1)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingIndicator(
                message: 'Loading repair details...');
          }

          if (snapshot.hasError) {
            return AppErrorState(
                message: friendlyErrorMessage(snapshot.error));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildNotFound();
          }

          final doc = snapshot.data!.docs.first;
          final data = doc.data() as Map<String, dynamic>;
          return _buildTrackingContent(context, doc.id, data);
        },
      ),
    );
  }

  Widget _buildNotFound() {
    return AppEmptyState(
      icon: Icons.search_off,
      title: 'Tracking ID not found',
      subtitle: 'No repair request found for tracking ID: $trackingId',
    );
  }

  Widget _buildTrackingContent(
      BuildContext context, String docId, Map<String, dynamic> data) {
    final status = (data['status'] ?? 'Pending') as String;
    final stepInfo = _buildStepInfo(data);
    final isDeclined = status == AppConstants.statusDeclined;

    // Build the timeline from the real lifecycle (incl. Queued / Pending Review)
    final steps = _buildSteps(status, stepInfo);
    final currentIndex = steps.indexWhere((s) => s.keys.contains(status));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1) Header: tracking ID + current status + plain-language message
              _buildHeaderCard(status),
              const SizedBox(height: 16),

              // 2) Customer action needed (parts decision) goes first
              if (data['partsDecisionStatus'] ==
                  AppConstants.partsDecisionAwaitingCustomer) ...[
                _CustomerPartsDecisionPanel(docId: docId, data: data),
                const SizedBox(height: 16),
              ],

              // 3) Status timeline (the core of this screen)
              if (isDeclined)
                _buildDeclinedCard(stepInfo[status])
              else
                _buildTimelineCard(steps, currentIndex),
              const SizedBox(height: 16),

              // 4) Repair details
              _buildInfoCard(context, data),
            ],
          ),
        ),
      ),
    );
  }

  // Dark header card with ID, status badge and a short message
  Widget _buildHeaderCard(String status) {
    final message = _statusMessage(status);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.darkGradient,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TRACKING ID',
            style: TextStyle(
                color: Colors.white70,
                fontSize: AppColors.fontCaption,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2),
          ),
          const SizedBox(height: 4),
          Text(
            trackingId,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 2),
          ),
          const SizedBox(height: 14),
          _buildStatusBadge(status),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: AppColors.fontLabel,
                  height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  // Short customer-friendly sentence for each status
  String _statusMessage(String status) {
    switch (AppConstants.normalizeStatus(status)) {
      case 'Pending':
        return 'We received your request. The shop will review it shortly.';
      case 'Accepted':
        return 'Your request was accepted. A technician will be assigned.';
      case 'Tech Visit':
        return 'A technician will visit you at your address for the repair.';
      case 'On-Site':
        return 'Your repair will be done on-site at the shop.';
      case 'Queued':
        return 'A technician is assigned and will start after finishing another job.';
      case 'In Process':
        return 'Your appliance is being repaired.';
      case 'Waiting for Parts':
        return 'A part is needed to continue your repair.';
      case 'Pending Review':
        return 'The repair is done and is waiting for the shop\'s final confirmation.';
      case 'Completed':
        return 'Your repair is complete. Thank you!';
      case 'Declined':
        return 'This request was declined by the shop.';
      default:
        return '';
    }
  }

  // Which steps appear in the timeline. Optional steps (Queued, Waiting for
  // Parts) only show once the request has actually reached them.
  List<_TimelineStep> _buildSteps(
      String rawStatus, Map<String, _StepInfo> rawInfo) {
    // Old records may still say 'In Home' / 'In Shop' until migrated.
    final status = AppConstants.normalizeStatus(rawStatus);
    final info = <String, _StepInfo>{
      for (final e in rawInfo.entries)
        AppConstants.normalizeStatus(e.key): e.value,
    };
    bool reached(String key) => status == key || info.containsKey(key);

    _TimelineStep step(String label, List<String> keys) => _TimelineStep(
          label: label,
          keys: keys,
          reached: keys.any(reached),
          info: keys.map((k) => info[k]).whereType<_StepInfo>().firstOrNull,
        );

    final steps = <_TimelineStep>[
      step('Pending', ['Pending']),
      step('Accepted', ['Accepted']),
    ];

    // Location step: show the one that applies, or both until decided
    if (reached(AppConstants.statusTechVisit)) {
      steps.add(step(AppConstants.statusTechVisit,
          [AppConstants.statusTechVisit]));
    } else if (reached(AppConstants.statusOnSite)) {
      steps.add(step(AppConstants.statusOnSite, [AppConstants.statusOnSite]));
    } else {
      steps.add(step(
          '${AppConstants.statusTechVisit} / ${AppConstants.statusOnSite}',
          [AppConstants.statusTechVisit, AppConstants.statusOnSite]));
    }

    if (reached('Queued')) {
      steps.add(step(AppConstants.displayLabel('Queued'), ['Queued']));
    }
    steps.add(step('In Process', ['In Process']));
    if (reached('Waiting for Parts')) {
      steps.add(step('Waiting for Parts', ['Waiting for Parts']));
    }
    steps.add(step('Pending Review', ['Pending Review']));
    steps.add(step('Completed', ['Completed']));
    return steps;
  }

  Widget _buildTimelineCard(List<_TimelineStep> steps, int currentIndex) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(Icons.timeline_outlined, 'Repair Progress'),
          const SizedBox(height: 18),
          for (int i = 0; i < steps.length; i++)
            _buildTimelineRow(
              steps[i],
              index: i,
              currentIndex: currentIndex,
              isLast: i == steps.length - 1,
            ),
        ],
      ),
    );
  }

  Widget _buildTimelineRow(
    _TimelineStep step, {
    required int index,
    required int currentIndex,
    required bool isLast,
  }) {
    final isCurrent = index == currentIndex;
    final isDone = index <= currentIndex || step.reached;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left rail: step circle + connector line
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isDone ? AppColors.dark : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDone
                          ? AppColors.dark
                          : const Color(0xFFD1D5DB),
                      width: 1.5,
                    ),
                    // Soft ring around the current step
                    boxShadow: isCurrent
                        ? const [
                            BoxShadow(
                                color: Color(0x33111827), spreadRadius: 4)
                          ]
                        : null,
                  ),
                  child: Center(
                    child: isDone
                        ? Icon(isCurrent ? Icons.circle : Icons.check,
                            color: Colors.white, size: isCurrent ? 9 : 15)
                        : Text('${index + 1}',
                            style: const TextStyle(
                                fontSize: AppColors.fontCaption,
                                color: AppColors.textLightGray,
                                fontWeight: FontWeight.bold)),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 2,
                        color: index < currentIndex
                            ? AppColors.dark
                            : const Color(0xFFE5E7EB),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // Right side: label, date, optional note
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          step.label,
                          style: TextStyle(
                            fontSize: AppColors.fontBody,
                            fontWeight:
                                isCurrent ? FontWeight.w700 : FontWeight.w500,
                            color: isDone
                                ? AppColors.textDark
                                : AppColors.textLightGray,
                          ),
                        ),
                      ),
                      if (isCurrent) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.dark,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Current',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (step.info?.date != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        step.info!.date!,
                        style: const TextStyle(
                            fontSize: AppColors.fontCaption,
                            color: AppColors.textGray),
                      ),
                    ),
                  if (step.info?.note != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Text(
                        step.info!.note!,
                        softWrap: true,
                        style: const TextStyle(
                            fontSize: AppColors.fontLabel,
                            height: 1.35,
                            color: Color(0xFF4B5563)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Shown instead of the timeline when the shop declined the request
  Widget _buildDeclinedCard(_StepInfo? info) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.dangerBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.block, color: AppColors.danger, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Request Declined',
                    style: TextStyle(
                        fontSize: AppColors.fontBody,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF991B1B))),
                if (info?.note != null) ...[
                  const SizedBox(height: 4),
                  Text(info!.note!,
                      style: const TextStyle(
                          fontSize: AppColors.fontLabel,
                          color: Color(0xFF7F1D1D))),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Map<String, _StepInfo> _buildStepInfo(Map<String, dynamic> data) {
    final result = <String, _StepInfo>{};
    final history = data['statusHistory'] as List<dynamic>? ?? [];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];

    for (final entry in history) {
      final map = entry as Map<String, dynamic>;
      // Internal reassignment after a technician declined: not part of the
      // customer's timeline.
      if (map['declinedBy'] != null) continue;
      final status = map['status'] as String? ?? '';
      final timestamp = map['timestamp'] as Timestamp?;
      final note = map['note'] as String?;

      // Clearer date format, e.g. "Oct 4, 2026"
      String? date;
      if (timestamp != null) {
        final d = timestamp.toDate();
        date = '${months[d.month - 1]} ${d.day}, ${d.year}';
      }

      result[status] = _StepInfo(
        date: date,
        note: (note != null && note.isNotEmpty) ? note : null,
      );
    }

    return result;
  }

  BoxDecoration _cardDecoration() => BoxDecoration(
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
      );

  // Card title with icon box (same look as settings sections)
  Widget _sectionTitle(IconData icon, String text) => Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 19, color: const Color(0xFF374151)),
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: const TextStyle(
                fontSize: AppColors.fontSubtitle + 2,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark),
          ),
        ],
      );

  Widget _buildInfoCard(BuildContext context, Map<String, dynamic> data) {
    final model = (data['applianceModel'] as String?) ?? '';
    final photoUrl = data['initialPhotoUrl'] as String?;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(Icons.receipt_long_outlined, 'Repair Details'),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.kitchen_outlined, 'Appliance',
              data['applianceType'] ?? ''),
          if (model.isNotEmpty)
            _buildInfoRow(Icons.label_outline, 'Model', model),
          _buildInfoRow(Icons.description_outlined, 'Problem',
              data['problemDescription'] ?? ''),
          _buildInfoRow(Icons.person_outline, 'Name', data['name'] ?? ''),
          _buildInfoRow(
              Icons.phone_outlined, 'Contact', data['contactNumber'] ?? ''),
          _buildInfoRow(
              Icons.location_on_outlined, 'Address', data['address'] ?? ''),
          if (photoUrl != null && photoUrl.isNotEmpty) ...[
            const SizedBox(height: 4),
            const Text(
              'Submitted Photo',
              style: TextStyle(
                  fontSize: AppColors.fontCaption,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textGray),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _openPhotoViewer(context, photoUrl),
              child: Stack(
                children: [
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
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 100,
                        alignment: Alignment.center,
                        color: const Color(0xFFF3F4F6),
                        child: const Text(
                          'Failed to load photo',
                          style: TextStyle(
                              fontSize: AppColors.fontCaption,
                              color: AppColors.textGray),
                        ),
                      ),
                    ),
                  ),
                  // Tap-to-zoom hint
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.zoom_in,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _openPhotoViewer(BuildContext context, String photoUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PhotoViewerScreen(photoUrl: photoUrl),
        fullscreenDialog: true,
      ),
    );
  }

  // Label on top, value below: easier to read than a cramped side-by-side row
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textGray),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                      fontSize: AppColors.fontCaption,
                      color: AppColors.textGray),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isEmpty ? '—' : value,
                  style: const TextStyle(
                      fontSize: AppColors.fontBody - 1,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textDark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    const textColor = Colors.white;

    switch (status) {
      case 'Accepted':
      case 'Completed':
        bgColor = AppColors.success;
        break;
      case 'Tech Visit':
      case 'On-Site':
      case 'In Home': // old value, until migrated
      case 'In Shop': // old value, until migrated
        bgColor = const Color(0xFF5B21B6);
        break;
      case 'In Process':
        bgColor = const Color(0xFF9D174D);
        break;
      case 'Waiting for Parts':
      case 'Declined':
        bgColor = AppColors.danger;
        break;
      case 'Queued':
      case 'Pending Review':
        bgColor = const Color(0xFFB45309);
        break;
      default:
        // Pending and anything unknown
        bgColor = Colors.white24;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            // Queued is shown to customers as "Waiting to Process"
            AppConstants.displayLabel(status),
            style: const TextStyle(
                fontSize: AppColors.fontLabel,
                fontWeight: FontWeight.w600,
                color: textColor),
          ),
        ],
      ),
    );
  }
}

/// One row in the status timeline.
class _TimelineStep {
  final String label;
  final List<String> keys; // status values that map to this step
  final bool reached; // status/history shows this step was reached
  final _StepInfo? info;
  const _TimelineStep({
    required this.label,
    required this.keys,
    required this.reached,
    this.info,
  });
}

/// Holds the date/note text shown for one step in the status timeline.
class _StepInfo {
  final String? date;
  final String? note;
  const _StepInfo({this.date, this.note});
}

/// Full-screen, pinch-to-zoom photo viewer
class _PhotoViewerScreen extends StatelessWidget {
  final String photoUrl;
  const _PhotoViewerScreen({required this.photoUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 4.0,
          child: Image.network(
            photoUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const CircularProgressIndicator(color: Colors.white);
            },
            errorBuilder: (context, error, stackTrace) => const Text(
              'Failed to load photo',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomerPartsDecisionPanel extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;

  const _CustomerPartsDecisionPanel({
    required this.docId,
    required this.data,
  });

  @override
  State<_CustomerPartsDecisionPanel> createState() =>
      _CustomerPartsDecisionPanelState();
}

class _CustomerPartsDecisionPanelState
    extends State<_CustomerPartsDecisionPanel> {
  bool _isSubmitting = false;

  Future<void> _choose(String partsSource) async {
    setState(() => _isSubmitting = true);
    try {
      await FirestoreService().submitPartsDecision(
        docId: widget.docId,
        partsSource: partsSource,
      );

      try {
        await FirestoreService().createNotification(
          recipientType: 'admin',
          title: 'Customer chose part source',
          body: '${widget.data['name'] ?? 'A customer'} chose: $partsSource '
              'for ${widget.data['applianceType'] ?? 'appliance'} '
              '(ID: ${widget.data['trackingId'] ?? ''}).',
          trackingId: widget.data['trackingId'] as String?,
        );
      } catch (_) {
        // Non-fatal.
      }

      // Best-effort alert to the shop — a customer decision arriving
      // silently is exactly the gap we're closing here, but a failed
      // notification shouldn't block the decision itself from saving.
      try {
        final shopDoc = await FirebaseFirestore.instance
            .collection('shopSettings')
            .doc('config')
            .get();
        final shopContactNumber =
            shopDoc.data()?['contactNumber'] as String? ?? '';
        if (shopContactNumber.isNotEmpty) {
          await SmsService().sendPartsDecisionAlertToShop(
            shopContactNumber: shopContactNumber,
            trackingId: widget.data['trackingId'] ?? '',
            applianceType: widget.data['applianceType'] ?? '',
            partsSource: partsSource,
            customerName: widget.data['name'] as String?,
          );
        }
      } catch (_) {
        // Non-fatal — the decision itself already saved successfully.
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Got it — $partsSource.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyErrorMessage(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _deadlineLabel() {
    final deadline = widget.data['partsDecisionDeadline'] as Timestamp?;
    if (deadline == null) return '';
    final hoursLeft = deadline.toDate().difference(DateTime.now()).inHours;
    if (hoursLeft <= 0) return 'Responding soon keeps this with you';
    return 'Respond within $hoursLeft hour${hoursLeft == 1 ? '' : 's'}, or '
        'the shop will supply it by default';
  }

  @override
  Widget build(BuildContext context) {
    final details = widget.data['partsDecisionDetails'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDBA74)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.inventory_2_outlined,
                  size: 18, color: Color(0xFF9A3412)),
              SizedBox(width: 6),
              Text('A Part Is Needed',
                  style: TextStyle(
                      fontSize: AppColors.fontLabel,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF9A3412))),
            ],
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(details,
                style: const TextStyle(
                    fontSize: AppColors.fontBody,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF7C2D12))),
          ],
          const SizedBox(height: 6),
          Text(
            'Who should supply it?',
            style: const TextStyle(
                fontSize: AppColors.fontCaption, color: Color(0xFF7C2D12)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => _choose(AppConstants.partsSourceShop),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF9A3412),
                    side: const BorderSide(color: Color(0xFF9A3412)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('The Shop Will Supply It'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => _choose(AppConstants.partsSourceCustomer),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9A3412),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('I\'ll Supply It'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _deadlineLabel(),
            style: const TextStyle(
                fontSize: AppColors.fontCaption, color: Color(0xFF9A3412)),
          ),
        ],
      ),
    );
  }
}