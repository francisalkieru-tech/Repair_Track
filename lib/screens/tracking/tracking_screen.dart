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
    final status = data['status'] ?? 'Pending';
    final allStatuses = [
      'Pending',
      'Accepted',
      'In Home',
      'In Shop',
      'In Process',
      'Waiting for Parts',
      'Complete',
    ];
    final normalizedStatus = status == 'Completed' ? 'Complete' : status;
    final currentIndex = allStatuses.indexOf(normalizedStatus);

    final stepInfo = _buildStepInfo(data);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AppColors.darkGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tracking ID:',
                  style: TextStyle(
                      color: Colors.white70, fontSize: AppColors.fontLabel),
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
                const SizedBox(height: 12),
                _buildStatusBadge(normalizedStatus),
              ],
            ),
          ),
          const SizedBox(height: 20),

          if (data['partsDecisionStatus'] ==
              AppConstants.partsDecisionAwaitingCustomer) ...[
            _CustomerPartsDecisionPanel(docId: docId, data: data),
            const SizedBox(height: 20),
          ],

          _buildInfoCard(context, data),
          const SizedBox(height: 20),

          const Text(
            'Repair Status:',
            style: TextStyle(
                fontSize: AppColors.fontTitle,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark),
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB), width: 1.2),
            ),
            child: Column(
              children: List.generate(allStatuses.length, (index) {
                final isCompleted = index <= currentIndex;
                final isCurrent = index == currentIndex;
                final isLast = index == allStatuses.length - 1;
                final info = stepInfo[allStatuses[index]];

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Step indicator: check circle if reached, number if not.
                    Column(
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: isCompleted
                                ? AppColors.dark
                                : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isCompleted
                                  ? AppColors.dark
                                  : const Color(0xFFD1D5DB),
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: isCompleted
                                ? const Icon(Icons.check,
                                    color: Colors.white, size: 14)
                                : Text(
                                    '${index + 1}',
                                    style: const TextStyle(
                                        fontSize: AppColors.fontCaption,
                                        color: AppColors.textLightGray,
                                        fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ),
                        if (!isLast)
                          Container(
                            width: 2,
                            height: 40,
                            color: index < currentIndex
                                ? AppColors.dark
                                : const Color(0xFFE5E7EB),
                          ),
                      ],
                    ),
                    const SizedBox(width: 16),

                    // Step label + date + "Current status" tag, tapos
                    // vertical divider, tapos "Note:" column sa kanan.
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 32),
                        child: IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Left column — status label, date, tag.
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      allStatuses[index],
                                      style: TextStyle(
                                        fontSize: AppColors.fontLabel,
                                        fontWeight: isCurrent
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        color: isCompleted
                                            ? AppColors.textDark
                                            : AppColors.textLightGray,
                                      ),
                                    ),
                                    if (info?.date != null)
                                      Text(
                                        info!.date!,
                                        style: const TextStyle(
                                            fontSize: AppColors.fontCaption,
                                            color: AppColors.textLightGray),
                                      ),
                                    if (isCurrent)
                                      const Text(
                                        'Current status',
                                        style: TextStyle(
                                            fontSize: AppColors.fontCaption,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.dark),
                                      ),
                                  ],
                                ),
                              ),
                              // Vertical divider between status info and note.
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: VerticalDivider(
                                  width: 1,
                                  thickness: 1,
                                  color: Color(0xFFE5E7EB),
                                ),
                              ),
                              
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Note:',
                                      style: TextStyle(
                                          fontSize: AppColors.fontCaption,
                                          color: AppColors.textLightGray),
                                    ),
                                    if (info?.note != null)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(top: 2),
                                        child: Text(
                                          info!.note!,
                                          softWrap: true,
                                          style: const TextStyle(
                                              fontSize: AppColors.fontCaption,
                                              color: AppColors.textGray),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, _StepInfo> _buildStepInfo(Map<String, dynamic> data) {
    final result = <String, _StepInfo>{};
    final history = data['statusHistory'] as List<dynamic>? ?? [];

    for (final entry in history) {
      final map = entry as Map<String, dynamic>;
      final status = map['status'] as String? ?? '';
      final label = status == 'Completed' ? 'Complete' : status;
      final timestamp = map['timestamp'] as Timestamp?;
      final note = map['note'] as String?;

      result[label] = _StepInfo(
        date: timestamp != null
            ? '${timestamp.toDate().month}/${timestamp.toDate().day}/${timestamp.toDate().year.toString().substring(2)}'
            : null,
        note: (note != null && note.isNotEmpty) ? note : null,
      );
    }

    return result;
  }

  Widget _buildInfoCard(BuildContext context, Map<String, dynamic> data) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Repair Details:',
            style: TextStyle(
                fontSize: AppColors.fontTitle,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark),
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.person_outline, 'Name', data['name'] ?? ''),
          _buildInfoRow(
              Icons.phone_outlined, 'Contact', data['contactNumber'] ?? ''),
          _buildInfoRow(
              Icons.location_on_outlined, 'Address', data['address'] ?? ''),
          _buildInfoRow(
              Icons.kitchen, 'Appliance', data['applianceType'] ?? ''),
          _buildInfoRow(Icons.description_outlined, 'Problem',
              data['problemDescription'] ?? ''),
          if (data['initialPhotoUrl'] != null &&
              (data['initialPhotoUrl'] as String).isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'Submitted Photo:',
              style: TextStyle(
                  fontSize: AppColors.fontCaption,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textGray),
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => _openPhotoViewer(
                  context, data['initialPhotoUrl'] as String),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      data['initialPhotoUrl'],
                      width: double.infinity,
                      height: 160,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          height: 160,
                          alignment: Alignment.center,
                          child: const CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.dark),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) =>
                          Container(
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
                  // Tap-to-zoom hint — malinaw sa customer na pwedeng
                  // i-tap ang photo para makita nang mas malapitan.
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

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textGray),
          const SizedBox(width: 8),
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: const TextStyle(
                  fontSize: AppColors.fontCaption, color: AppColors.textGray),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  fontSize: AppColors.fontCaption,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;

    switch (status) {
      case 'Pending':
        bgColor = Colors.white24;
        textColor = Colors.white;
        break;
      case 'Accepted':
        bgColor = AppColors.success;
        textColor = Colors.white;
        break;
      case 'In Home':
      case 'In Shop':
        bgColor = const Color(0xFF5B21B6);
        textColor = Colors.white;
        break;
      case 'In Process':
        bgColor = const Color(0xFF9D174D);
        textColor = Colors.white;
        break;
      case 'Waiting for Parts':
        bgColor = AppColors.danger;
        textColor = Colors.white;
        break;
      case 'Complete':
        bgColor = AppColors.success;
        textColor = Colors.white;
        break;
      default:
        bgColor = Colors.white24;
        textColor = Colors.white;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            status,
            style: TextStyle(
                fontSize: AppColors.fontLabel,
                fontWeight: FontWeight.w600,
                color: textColor),
          ),
        ],
      ),
    );
  }
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
                fontSize: 11, color: Color(0xFF9A3412)),
          ),
        ],
      ),
    );
  }
}