import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../../utils/qr_downloader.dart';
import '../../utils/qr_printer.dart';
import '../../utils/qr_sticker.dart';
import '../../services/firestore_service.dart';
import '../../services/sms_service.dart';
import '../../services/storage_service.dart';
import 'admin_theme.dart';
import '../../utils/technician_availability.dart';
import '../../utils/constants.dart';


/// Requests page.
class RequestsScreen extends StatefulWidget {
  /// Tab to open first: 0 = New Request, 1 = Accepted, 2 = In Process.
  final int initialTab;

  const RequestsScreen({super.key, this.initialTab = 0});

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

    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 2),
    );

    _firestoreService.applyExpiredPartsDecisionDefaults();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kAdminBg,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: TabBar(
              controller: _tabController,
              labelColor: kAdminTextDark,
              unselectedLabelColor: kAdminTextGray,
              indicatorColor: kAdminTextDark,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
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
      ),
    );
  }

  Widget _buildList(List<QueryDocumentSnapshot> docs,
      {required String emptyText}) {
    if (docs.isEmpty) {
      return Center(
        child: Text(emptyText, style: const TextStyle(color: kAdminTextGray)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: docs.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final doc = docs[index];
        final data = doc.data() as Map<String, dynamic>;
        return buildRequestCard(context, doc.id, data);
      },
    );
  }
}

// "Technician reassigned from X to Y — Oct 5, 2:30 PM" lines, oldest first,
// built from the status-history entries that carry `reassignedFrom`.
List<String> _reassignmentLog(Map<String, dynamic> data) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final history = data['statusHistory'];
  if (history is! List) return const [];

  final lines = <String>[];
  for (final h in history) {
    if (h is! Map) continue;
    final declinedBy = h['declinedBy'];
    if (h['reassignedFrom'] == null && declinedBy == null) continue;
    final to = h['technician'] ?? '';
    var stamp = '';
    if (h['timestamp'] is Timestamp) {
      final t = (h['timestamp'] as Timestamp).toDate();
      final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
      final minute = t.minute.toString().padLeft(2, '0');
      stamp =
          ' — ${months[t.month - 1]} ${t.day}, $hour:$minute ${t.hour >= 12 ? 'PM' : 'AM'}';
    }
    // Why the technician declined (shown to Admin only)
    final why = (h['declineReason'] ?? '').toString();
    final extra = (h['declineNote'] ?? '').toString();
    final reason = why.isEmpty
        ? ''
        : ' (reason: $why${extra.isEmpty ? '' : ' - $extra'})';

    if (h['reassignedFrom'] == null) {
      // Declined and nobody was free: waiting for Admin
      lines.add('$declinedBy declined this job$reason$stamp. '
          'Needs reassignment.');
      continue;
    }
    lines.add('Technician reassigned from ${h['reassignedFrom']} to $to$stamp'
        '${declinedBy != null ? ' - declined$reason' : ''}'
        '${h['assignedManually'] == true ? ' (chosen by admin)' : ''}');
  }
  return lines;
}

// TECHNICIAN QUEUE
// Called after a job is assigned. Admin still picks the technician manually;
// this only keeps the queue order fair:
//  - technicians AHEAD of the assigned one who could not take the job
//    (off duty, on a tech call/visit, or full) go to the back of the queue,
//  - the previous technician (when Admin reassigns) goes to the back,
//  - the technician who just got the job goes to the back.
// Best-effort: a failure here never blocks the assignment itself.
Future<void> _advanceTechnicianQueue({
  required String assignedName,
  String? previousName,
}) async {
  try {
    final fs = FirestoreService();
    final techSnap = await fs.streamTechnicians().first;
    final reqSnap = await fs.streamRepairRequests().first;
    final requests = reqSnap.docs
        .map((d) => d.data() as Map<String, dynamic>)
        .toList();
    final techs = techSnap.docs.map((d) {
      final m = Map<String, dynamic>.from(d.data() as Map);
      m['id'] = d.id;
      return m;
    }).toList();

    final ordered = orderTechnicianQueue(techs);
    final assignedIndex = ordered.indexWhere((t) => t['name'] == assignedName);
    if (assignedIndex < 0) return;

    // Technicians ahead in the queue who are clocked in but could not take
    // the job (busy / full) go to the back. Technicians who are not clocked
    // in are simply skipped and keep their place.
    final moveToEnd = <String>[];
    for (var i = 0; i < assignedIndex; i++) {
      final t = ordered[i];
      if (isTechnicianClockedIn(t) && !isTechnicianAssignable(requests, t)) {
        moveToEnd.add(t['id'] as String);
      }
    }
    // Reassigned away from someone (declined / unavailable): back of the queue
    if (previousName != null) {
      final prev = ordered.indexWhere((t) => t['name'] == previousName);
      if (prev >= 0) moveToEnd.add(ordered[prev]['id'] as String);
    }
    // The technician who just got the job goes to the back too
    moveToEnd.add(ordered[assignedIndex]['id'] as String);

    await fs.moveTechniciansToQueueEnd(
      currentOrderIds: ordered.map((t) => t['id'] as String).toList(),
      moveToEnd: moveToEnd,
    );
  } catch (_) {
    // Non-fatal.
  }
}

// QR is available only for eligible statuses.
const _kQrEligibleStatuses = {
  AppConstants.statusTechVisit,
  AppConstants.statusOnSite,
  AppConstants.legacyInHome, // un-migrated data
  AppConstants.legacyInShop, // un-migrated data
  'In Process',
  'Waiting for Parts',
  'Completed',
};

Widget buildRequestCard(BuildContext context, String docId, Map<String, dynamic> data) {
    final status = data['status'] ?? 'Pending';
    final trackingId = data['trackingId'] ?? '';
    final name = data['name'] ?? '';
    final applianceType = data['applianceType'] ?? '';
    final contactNumber = data['contactNumber'] ?? '';
    final assignedTechnician = data['assignedTechnician'] as String?;
    final partsDecisionStatus = data['partsDecisionStatus'] as String?;
    final partsSource = data['partsSource'] as String?;
    final showPartsReadyBadge =
        status == 'Waiting for Parts' && partsDecisionStatus == 'decided';

    return Material(
      color: const Color(0xFFD9D9D9),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _handleCardTap(context, docId, data),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tracking ID:',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF555555),
                      ),
                    ),
                    // Wrap so the status badge drops to the next line on
                    // narrow phone screens instead of overflowing.
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 14,
                      runSpacing: 4,
                      children: [
                        Text(
                          trackingId,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            letterSpacing: 1,
                            color: Colors.black,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Status : ',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                            _buildStatusBadge(status),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Name: $name',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF444444),
                      ),
                    ),
                    Text(
                      'Appliance: $applianceType',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF444444),
                      ),
                    ),
                    Text(
                      'Contact Number: $contactNumber',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF444444),
                      ),
                    ),
                    if (assignedTechnician != null &&
                        assignedTechnician.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.engineering_outlined,
                              size: 13, color: Color(0xFF666666)),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              assignedTechnician,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF666666),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    // Reassignment log (from the ticket's status history)
                    for (final line in _reassignmentLog(data)) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.swap_horiz_rounded,
                              size: 13, color: Color(0xFF666666)),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              line,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF666666),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (showPartsReadyBadge) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1FAE5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          partsSource == 'Customer Supplied'
                              ? 'Customer will supply part — ready to resume'
                              : 'Shop to supply part — ready to resume',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF065F46),
                          ),
                        ),
                      ),
                    ],
                    if (_kQrEligibleStatuses.contains(status)) ...[
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () =>
                            showQrDialog(context, trackingId, name),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.qr_code_2,
                                size: 15, color: Colors.black),
                            SizedBox(width: 4),
                            Text(
                              'View QR',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Material(
                color: Colors.black,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _handleCardTap(context, docId, data),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal:
                            MediaQuery.of(context).size.width < 600 ? 12 : 18,
                        vertical: 10),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Update',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 2),
                        Icon(Icons.chevron_right,
                            size: 18, color: Colors.white),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

void _handleCardTap(BuildContext context, String docId, Map<String, dynamic> data) {
    final status = data['status'] ?? 'Pending';
    if (status == 'Pending') {
      _openReviewSheet(context, docId, data);
    } else {
      _openUpdateSheet(context, docId, data);
    }
  }

void showQrDialog(BuildContext context, String trackingId, String customerName) {
    showDialog(
      context: context,
      builder: (context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: _QrCodeDialog(
            trackingId: trackingId,
            customerName: customerName,
          ),
        ),
      ),
    );
  }

void _showCenteredDialog(BuildContext context, Widget child) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black.withOpacity(0.35),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, animation, secondaryAnimation) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720, maxHeight: 760),
            child: Material(
              color: Colors.transparent,
              child: child,
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: 6 * animation.value,
          sigmaY: 6 * animation.value,
        ),
        child: FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOut),
            ),
            child: child,
          ),
        ),
      );
    },
  );
}

void _openReviewSheet(BuildContext context, String docId, Map<String, dynamic> data) {
    _showCenteredDialog(
      context,
      _ReviewRequestSheet(
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

    _showCenteredDialog(
      context,
      _UpdateStatusSheet(
        docId: docId,
        currentStatus: data['status'] ?? 'Pending',
        trackingId: data['trackingId'] ?? '',
        contactNumber: data['contactNumber'] ?? '',
        applianceType: data['applianceType'] ?? '',
        currentTechnician: data['assignedTechnician'] as String?,
        initialScheduledDate: scheduledVisit?.toDate(),
        partsDecisionStatus: data['partsDecisionStatus'] as String?,
        partsNeededNote: _latestPartsNote(data),
        resolvedPartsSource: data['partsSource'] as String?,
      ),
    );
  }

// The technician's "what part is needed" note lives as the most
// recent statusHistory entry with status == 'Waiting for Parts'.
String? _latestPartsNote(Map<String, dynamic> data) {
  final history = (data['statusHistory'] as List?)?.cast<dynamic>() ?? [];
  for (final entry in history.reversed) {
    final e = entry as Map<String, dynamic>;
    if (e['status'] == 'Waiting for Parts' &&
        (e['note'] as String?)?.isNotEmpty == true) {
      return e['note'] as String;
    }
  }
  return null;
}

// TECHNICIAN ASSIGNMENT — fair queue by default, Admin can still override.
// The system suggests the next technician in the queue who is clocked in
// today and available (fair rotation). Admin can accept that, or choose a
// different available technician when the job needs another skill (the
// override is flagged in the ticket history). For an already-assigned ticket
// Admin can "Reassign to next in queue" or choose someone else.
class _TechnicianPickerField extends StatefulWidget {
  /// Technician already on the ticket (null when accepting a new request).
  final String? initialTechnician;

  /// Allows "Reassign to next in queue" for a ticket that already has a
  /// technician.
  final bool allowReassign;

  /// Appliance of the ticket — used to prefer a specialist technician.
  final String? applianceType;

  /// [manual] is true when Admin overrode the queue's suggestion.
  final void Function(String? name, String? id, bool manual) onChanged;

  const _TechnicianPickerField({
    this.initialTechnician,
    this.allowReassign = false,
    this.applianceType,
    required this.onChanged,
  });

  @override
  State<_TechnicianPickerField> createState() =>
      _TechnicianPickerFieldState();
}

class _TechnicianPickerFieldState extends State<_TechnicianPickerField> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _reassigning = false;
  String? _manualName; // technician Admin chose instead of the queue pick
  String? _reportedKey; // last "name|manual" sent through onChanged

  void _report(String? name, String? id, bool manual) {
    final key = '$name|$manual';
    if (_reportedKey == key) return;
    _reportedKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onChanged(name, id, manual);
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestoreService.streamRepairRequests(),
      builder: (context, requestsSnap) {
        final allData = (requestsSnap.data?.docs ?? [])
            .map((d) => d.data() as Map<String, dynamic>)
            .toList();

        return StreamBuilder<QuerySnapshot>(
          stream: _firestoreService.streamTechnicians(),
          builder: (context, snapshot) {
            final techs = (snapshot.data?.docs ?? []).map((d) {
              final m = Map<String, dynamic>.from(d.data() as Map);
              m['id'] = d.id;
              return m;
            }).toList();
            final queue = orderTechnicianQueue(techs);

            final current = widget.initialTechnician;
            final hasCurrent = current != null && current.isNotEmpty;

            // Technicians Admin may choose from (clocked in and free)
            final choices = queue
                .where((t) =>
                    isTechnicianAssignable(allData, t) &&
                    (!hasCurrent || t['name'] != current))
                .toList();
            final manualTech = _manualName == null
                ? null
                : choices
                    .where((t) => t['name'] == _manualName)
                    .cast<Map<String, dynamic>?>()
                    .firstOrNull;
            final isManual = manualTech != null;
            final reassigning = _reassigning || isManual;

            // Who is (or will be) on the ticket
            Map<String, dynamic>? chosen;
            if (isManual) {
              chosen = manualTech;
            } else if (hasCurrent && !reassigning) {
              for (final t in techs) {
                if (t['name'] == current) chosen = t;
              }
            } else {
              chosen = nextTechnicianInQueue(
                allData,
                techs,
                excludeName: hasCurrent ? current : null,
                applianceType: widget.applianceType,
              );
            }
            _report(
              chosen?['name'] as String? ??
                  (hasCurrent && !reassigning ? current : null),
              chosen?['id'] as String?,
              isManual,
            );

            String tag(Map<String, dynamic> t) {
              if (!isTechnicianClockedIn(t)) return 'Off duty';
              if (isTechnicianAssignable(allData, t)) return 'Available';
              return 'Busy';
            }

            final noOne = chosen == null && !(hasCurrent && !reassigning);
            final specialistMatch = chosen != null &&
                technicianCoversAppliance(chosen, widget.applianceType);
            final anySpecialist = techs
                .any((t) => technicianCoversAppliance(t, widget.applianceType));

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.engineering_outlined,
                          size: 18, color: Color(0xFF374151)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          noOne
                              ? 'No technician available'
                              : (chosen?['name'] ?? current ?? '') as String,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: noOne
                                ? const Color(0xFF991B1B)
                                : const Color(0xFF111827),
                          ),
                        ),
                      ),
                      if (!noOne)
                        Text(
                          isManual
                              ? 'Chosen by admin'
                              : reassigning
                                  ? 'Next in queue'
                                  : hasCurrent
                                      ? 'Assigned'
                                      : 'Next in queue',
                          style: const TextStyle(
                              fontSize: 11.5, color: Color(0xFF6B7280)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    noOne
                        ? 'No technician is clocked in and free right now. '
                            'Technicians must Clock In on their app first.'
                        : specialistMatch
                            ? 'Matched to a technician who specializes in '
                                '${widget.applianceType}. Jobs are still shared '
                                'fairly within the specialists.'
                            : anySpecialist
                                ? 'No ${widget.applianceType} specialist is free '
                                    'right now, so the next available technician '
                                    'was picked. You can choose another one below.'
                                : 'Default is the next technician in the queue, so '
                                    'jobs are shared fairly. You can choose another '
                                    'technician if this job needs a different skill.',
                    style: const TextStyle(
                        fontSize: 11.5, color: Color(0xFF6B7280)),
                  ),
                  if (hasCurrent && widget.allowReassign) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _reassigning = !reassigning;
                            _manualName = null;
                            _reportedKey = null;
                          });
                        },
                        icon: Icon(
                            reassigning ? Icons.undo : Icons.swap_horiz,
                            size: 16),
                        label: Text(reassigning
                            ? 'Keep $current'
                            : 'Reassign to next in queue'),
                      ),
                    ),
                  ],
                  // Override: choose a different available technician
                  if (choices.isNotEmpty &&
                      (!hasCurrent || widget.allowReassign)) ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: isManual ? _manualName : null,
                      isExpanded: true,
                      hint: const Text('Choose a different technician'),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      items: [
                        for (final t in choices)
                          DropdownMenuItem(
                            value: t['name'] as String,
                            child: Text(
                              '${t['name']}'
                              '${technicianSpecializations(t).isEmpty ? '' : ' — ${technicianSpecializations(t).join(', ')}'}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (value) => setState(() {
                        _manualName = value;
                        _reportedKey = null;
                      }),
                    ),
                    if (isManual)
                      TextButton(
                        onPressed: () => setState(() {
                          _manualName = null;
                          _reportedKey = null;
                        }),
                        child: const Text('Back to the queue pick'),
                      ),
                  ],
                  if (queue.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Text('Queue',
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF374151))),
                    const SizedBox(height: 2),
                    for (int i = 0; i < queue.length; i++)
                      Text(
                        '${i + 1}. ${queue[i]['name']} — ${tag(queue[i])}'
                        '${technicianCoversAppliance(queue[i], widget.applianceType) ? ' • Specialist' : ''}',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: queue[i]['name'] == chosen?['name']
                              ? Colors.black
                              : const Color(0xFF6B7280),
                          fontWeight: queue[i]['name'] == chosen?['name']
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}

Widget _buildStatusBadge(String status) {
    final colors = statusColors(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        AppConstants.displayLabel(status),
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: colors.$2,
        ),
      ),
    );
  }

class _PartsDecisionPanel extends StatefulWidget {
  final String docId;
  final String? partsNeededNote;
  final String? partsDecisionStatus;

  const _PartsDecisionPanel({
    required this.docId,
    this.partsNeededNote,
    this.partsDecisionStatus,
  });

  @override
  State<_PartsDecisionPanel> createState() => _PartsDecisionPanelState();
}

class _PartsDecisionPanelState extends State<_PartsDecisionPanel> {
  final _detailsController = TextEditingController();
  bool _isSending = false;
  // widget.partsDecisionStatus is a one-time snapshot passed in when
  // this panel was built 
  bool _locallyMarkedAwaiting = false;

  @override
  void initState() {
    super.initState();
    if (widget.partsNeededNote != null && widget.partsNeededNote!.isNotEmpty) {
      _detailsController.text = widget.partsNeededNote!;
    }
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _notifyCustomer() async {
    if (_detailsController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter the part name/price to show the customer.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSending = true);
    try {
      await FirestoreService().openPartsDecision(
        docId: widget.docId,
        partDetails: _detailsController.text,
      );

      // Best-effort bell notification to the customer so they know
      // they have a 24-hour decision to make.
      try {
        final reqDoc = await FirebaseFirestore.instance
            .collection('repairRequests')
            .doc(widget.docId)
            .get();
        final reqData = reqDoc.data();
        final shopDoc = await FirebaseFirestore.instance
            .collection('shopSettings')
            .doc('config')
            .get();
        await SmsService().sendPartsDecisionRequestSms(
          shopName: shopDoc.data()?['shopName'] as String? ?? 'RepairTrack',
          contactNumber: reqData?['contactNumber'] as String? ?? '',
          trackingId: reqData?['trackingId'] as String? ?? '',
          applianceType: reqData?['applianceType'] as String? ?? 'appliance',
          partDetails: _detailsController.text,
        );
        final customerId = reqData?['customerId'] as String?;
        if (customerId != null && customerId.isNotEmpty) {
          await FirestoreService().createNotification(
            recipientType: 'customer',
            recipientId: customerId,
            title: 'Action needed: choose who supplies the part',
            body: 'Your ${reqData?['applianceType'] ?? 'appliance'} '
                '(ID: ${reqData?['trackingId'] ?? ''}) needs a part. '
                'Please choose within 24 hours.',
            trackingId: reqData?['trackingId'] as String?,
          );
        }
      } catch (_) {
        // Non-fatal — the decision window already opened.
      }

      if (mounted) {
        setState(() => _locallyMarkedAwaiting = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Customer notified. They have 24 hours to choose — '
                'if they don\'t, the shop will supply it by default.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to notify customer: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final awaitingCustomer =
        widget.partsDecisionStatus == AppConstants.partsDecisionAwaitingCustomer ||
            _locallyMarkedAwaiting;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFDBA74)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.inventory_2_outlined,
                  size: 16, color: Color(0xFF9A3412)),
              SizedBox(width: 6),
              Text('Part Needed',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF9A3412))),
            ],
          ),
          if (widget.partsNeededNote != null &&
              widget.partsNeededNote!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Technician\'s note: "${widget.partsNeededNote}"',
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF7C2D12))),
          ],
          const SizedBox(height: 10),
          if (awaitingCustomer)
            const Text(
              'Waiting for the customer to choose who supplies the part. '
              'If they don\'t respond within 24 hours, the shop will '
              'supply it by default.',
              style: TextStyle(fontSize: 13, color: Color(0xFF7C2D12)),
            )
          else ...[
            const Text(
              'Enter the part and price to notify the customer, so they '
              'can choose whether the shop or they will supply it:',
              style: TextStyle(fontSize: 13, color: Color(0xFF7C2D12)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _detailsController,
              decoration: InputDecoration(
                hintText: 'e.g. Compressor — ₱1,200',
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.all(10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFFDBA74)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSending ? null : _notifyCustomer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9A3412),
                  foregroundColor: Colors.white,
                ),
                child: _isSending
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Notify Customer'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UpdateStatusSheet extends StatefulWidget {
  final String docId;
  final String currentStatus;
  final String trackingId;
  final String contactNumber;
  final String applianceType;
  final String? currentTechnician;
  final DateTime? initialScheduledDate;
  final String? partsDecisionStatus;
  final String? partsNeededNote;
  final String? resolvedPartsSource;

  const _UpdateStatusSheet({
    required this.docId,
    required this.currentStatus,
    required this.trackingId,
    required this.contactNumber,
    required this.applianceType,
    this.currentTechnician,
    this.initialScheduledDate,
    this.partsDecisionStatus,
    this.partsNeededNote,
    this.resolvedPartsSource,
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
  String? _selectedTechnicianId;
  bool _assignedManually = false; // Admin overrode the queue pick
  DateTime? _scheduledDateTime;
  Uint8List? _selectedImage;
  bool _isSubmitting = false;

  int? _warrantyMonths = 2;
  final TextEditingController _warrantyTermsController =
      TextEditingController(
    text: 'Covers the same issue that was repaired. Does not cover new '
        'damage or misuse.',
  );

  static const Map<String, List<String>> _nextStatusOptions = {
    'Accepted': ['On-Site', 'Tech Visit'],
    'On-Site': ['In Process', 'Waiting for Parts'],
    'Tech Visit': ['In Process', 'Waiting for Parts', 'Completed'],
    'Queued': ['In Process'],
    'Waiting for Parts': ['In Process'],
    'In Process': ['Waiting for Parts', 'Pending Review', 'Completed'],
    'Pending Review': ['Completed', 'In Process'],
  };

  // normalizeStatus: a ticket still holding an old 'In Home' / 'In Shop'
  // value (before the migration) gets the same next-step options.
  List<String> get _availableStatuses =>
      _nextStatusOptions[AppConstants.normalizeStatus(widget.currentStatus)] ??
      [widget.currentStatus];

  static const _statusesNeedingPartsSource = {
    'In Process',
    'Waiting for Parts',
  };

  bool get _noteRequired =>
      _selectedStatus == 'Completed' || _selectedStatus == 'Waiting for Parts';
  bool get _partsSourceRelevant =>
      _statusesNeedingPartsSource.contains(_selectedStatus);
  bool get _scheduleRequired => AppConstants.isTechVisit(_selectedStatus);
  bool get _warrantyRelevant => _selectedStatus == 'Completed';

  @override
  void initState() {
    super.initState();

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
    if (!mounted) return;

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
      if (!mounted) return;
      setState(() => _selectedImage = bytes);
    }
  }

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

      // If Admin is moving this job to "In Process" but the assigned
      // technician is still busy with other active jobs, downgrade
      // automatically to "Queued" instead — Admin doesn't pick
      // between these manually, the system decides based on the
      // technician's actual workload.
      var finalStatus = _selectedStatus;
      if (_selectedStatus == 'In Process' && _selectedTechnician != null) {
        final allJobsSnap =
            await FirebaseFirestore.instance.collection('repairRequests').get();
        final allJobs = allJobsSnap.docs
            .map((d) => {...d.data(), 'id': d.id})
            .toList();
        final otherActiveJobs = activeJobsForTechnician(
                allJobs, _selectedTechnician!)
            .where((j) => j['id'] != widget.docId);
        if (otherActiveJobs.isNotEmpty) {
          finalStatus = 'Queued';
        }
      }

      // Transparency: if Admin changed the technician on a ticket that
      // already had one, say so in the ticket history.
      final previousTech = widget.currentTechnician;
      final wasReassigned = previousTech != null &&
          _selectedTechnician != null &&
          previousTech != _selectedTechnician;
      final historyNote = wasReassigned
          ? 'Technician reassigned from $previousTech to $_selectedTechnician.'
              '${_noteController.text.trim().isEmpty ? '' : ' ${_noteController.text.trim()}'}'
          : _noteController.text;

      await _firestoreService.updateRepairStatus(
        docId: widget.docId,
        trackingId: widget.trackingId,
        newStatus: finalStatus,
        note: historyNote,
        reassignedFrom: wasReassigned ? previousTech : null,
        assignedManually: _assignedManually && wasReassigned,
        partsSource: _partsSourceRelevant ? _partsSource : null,
        assignedTechnician: _selectedTechnician,
        assignedTechnicianUid: _selectedTechnicianId,
        scheduledDate: _scheduleRequired ? _scheduledDateTime : null,
        photoUrl: photoUrl,
        warrantyMonths: _warrantyRelevant ? _warrantyMonths : null,
        warrantyTerms: _warrantyRelevant
            ? _warrantyTermsController.text
            : null,
      );

      // Move technicians in the assignment queue (new / changed technician)
      if (_selectedTechnician != null &&
          _selectedTechnician != previousTech) {
        await _advanceTechnicianQueue(
          assignedName: _selectedTechnician!,
          previousName: previousTech,
        );
      }

      // QR flag is set when a ticket goes to Tech Visit (was 'In Home').
      if (AppConstants.isTechVisit(_selectedStatus)) {
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

      if (_selectedStatus == 'Completed') {
        try {
          final reqDoc = await FirebaseFirestore.instance
              .collection('repairRequests')
              .doc(widget.docId)
              .get();
          final customerId = reqDoc.data()?['customerId'] as String?;
          if (customerId != null && customerId.isNotEmpty) {
            await _firestoreService.createNotification(
              recipientType: 'customer',
              recipientId: customerId,
              title: 'Repair completed',
              body: 'Your ${widget.applianceType} (ID: ${widget.trackingId}) '
                  'is ready. Check your warranty details.',
              trackingId: widget.trackingId,
            );
          }
        } catch (_) {
          // Non-fatal.
        }
      }

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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusColors(widget.currentStatus).$1,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      AppConstants.displayLabel(widget.currentStatus),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColors(widget.currentStatus).$2,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    customBorder: const CircleBorder(),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close,
                          size: 20, color: Color(0xFF6B7280)),
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

              if (widget.currentStatus == 'Waiting for Parts' &&
                  widget.partsDecisionStatus != 'decided') ...[
                _PartsDecisionPanel(
                  docId: widget.docId,
                  partsNeededNote: widget.partsNeededNote,
                  partsDecisionStatus: widget.partsDecisionStatus,
                ),
                const SizedBox(height: 20),
              ] else if (widget.currentStatus == 'Waiting for Parts' &&
                  widget.partsDecisionStatus == 'decided') ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF6EE7B7)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle,
                          size: 18, color: Color(0xFF059669)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.resolvedPartsSource == 'Customer Supplied'
                              ? 'Customer decided: they\'ll supply the '
                                  'part themselves. Move back to "In '
                                  'Process" once it arrives.'
                              : 'Customer decided: the shop will supply '
                                  'the part. Move back to "In Process" '
                                  'once it\'s sourced.',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF065F46),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 420;

                  final techOwnsThisStage = widget.currentTechnician != null &&
                      const {
                        'On-Site',
                        'Tech Visit',
                        'In Shop', // old value, until migrated
                        'In Home', // old value, until migrated
                        'Queued',
                        'In Process',
                        'Waiting for Parts',
                      }.contains(widget.currentStatus);

                  final leftFields = <Widget>[
                    if (techOwnsThisStage) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline,
                                size: 16, color: Color(0xFF1D4ED8)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${widget.currentTechnician} usually moves '
                                'this forward from their own app. Only '
                                'change it below if you need to override.',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF1D4ED8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    const Text('Update Status',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151))),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedStatus,
                      items: _availableStatuses
                          .map((s) =>
                              DropdownMenuItem(
                              value: s,
                              child: Text(AppConstants.displayLabel(s))))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedStatus = value);
                        }
                      },
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
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
                            border:
                                Border.all(color: const Color(0xFFE5E7EB)),
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
                      const SizedBox(height: 12),
                    ],
                    if (_partsSourceRelevant) ...[
                      const Text('Parts Source',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF374151))),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
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
                          ChoiceChip(
                            label: const Text('Shop Supplied'),
                            selected: _partsSource == 'Shop Supplied',
                            onSelected: (_) => setState(
                                () => _partsSource = 'Shop Supplied'),
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
                        ],
                      ),
                      const SizedBox(height: 12),
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
                            label: Text(
                                months == 1 ? '1 Month' : '$months Month'),
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
                      const SizedBox(height: 10),
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
                            borderSide:
                                const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    const Text('Assigned Technician',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151))),
                    const SizedBox(height: 6),
                    _TechnicianPickerField(
                      initialTechnician: widget.currentTechnician,
                      allowReassign: true,
                      applianceType: widget.applianceType,
                      onChanged: (name, id, manual) {
                        _selectedTechnician = name;
                        _selectedTechnicianId = id;
                        _assignedManually = manual;
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _selectedStatus == 'Completed'
                          ? 'Notes / Remarks (Required)'
                          : _noteRequired
                              ? 'Notes / Remarks (Required)'
                              : 'Notes / Remarks (Optional — template '
                                  'message included)',
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
                            ? 'Put details on what is being repaired on '
                                'the appliance.'
                            : _noteRequired
                                ? 'Provide details on the delay or the '
                                    'expected arrival of the part.'
                                : 'Optional — additional details to add '
                                    'to the template message',
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        contentPadding: const EdgeInsets.all(12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                      ),
                    ),
                  ];

                  final photoField = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                                height: isWide ? 220 : 140,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 6,
                              right: 6,
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _selectedImage = null),
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
                            height: isWide ? 220 : null,
                            padding: EdgeInsets.symmetric(
                                vertical: isWide ? 0 : 20),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(8),
                              border:
                                  Border.all(color: const Color(0xFFE5E7EB)),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.add_a_photo_outlined,
                                    color: Color(0xFF9CA3AF), size: 24),
                                SizedBox(height: 6),
                                Text(
                                  'Tap to add a photo',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF9CA3AF)),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );

                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: leftFields,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(flex: 2, child: photoField),
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...leftFields,
                      const SizedBox(height: 14),
                      photoField,
                    ],
                  );
                },
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
  String? _selectedTechnician;
  String? _selectedTechnicianId;
  bool _assignedManually = false; // Admin overrode the queue pick
  // 'shop' = customer brings the appliance in, 'home' = technician visits
  String _serviceMode = 'shop';

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

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

    // Accept now assigns a technician in the same step — no more
    // separate "Requests" then "Assign" trip. The job goes straight
    // into that technician's queue as soon as it's accepted.
    if (newStatus == 'Accepted' && _selectedTechnician == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No technician is clocked in and available. Technicians must Clock In first.'),
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
        assignedTechnician:
            newStatus == 'Accepted' ? _selectedTechnician : null,
        assignedTechnicianUid:
            newStatus == 'Accepted' ? _selectedTechnicianId : null,
        serviceMode: newStatus == 'Accepted' ? _serviceMode : null,
        assignedManually: newStatus == 'Accepted' && _assignedManually,
      );

      if (newStatus == 'Accepted' && _selectedTechnician != null) {
        await _advanceTechnicianQueue(assignedName: _selectedTechnician!);
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
        newStatus: newStatus,
        note: _noteController.text,
        technician: newStatus == 'Accepted' ? _selectedTechnician : null,
        serviceMode: newStatus == 'Accepted' ? _serviceMode : null,
      );

      if (newStatus == 'Accepted') {
        try {
          final reqDoc = await FirebaseFirestore.instance
              .collection('repairRequests')
              .doc(widget.docId)
              .get();
          final customerId = reqDoc.data()?['customerId'] as String?;
          if (customerId != null && customerId.isNotEmpty) {
            await _firestoreService.createNotification(
              recipientType: 'customer',
              recipientId: customerId,
              title: 'Repair request accepted',
              body: 'Your ${widget.applianceType} '
                  '(ID: ${widget.trackingId}) was accepted'
                  '${_selectedTechnician != null ? ' and assigned to $_selectedTechnician' : ''}.',
              trackingId: widget.trackingId,
            );
          }
        } catch (_) {
          // Non-fatal.
        }
      }

      // Best-effort alert to the assigned technician — phoneNumber is
      // an optional field on their technicians/ doc, so this is
      // skipped quietly (not an error) when it isn't on file, and a
      // failure here never blocks the acceptance itself from saving.
      if (newStatus == 'Accepted' && _selectedTechnicianId != null) {
        try {
          final techDoc = await FirebaseFirestore.instance
              .collection('technicians')
              .doc(_selectedTechnicianId)
              .get();
          final techPhone = techDoc.data()?['phoneNumber'] as String? ?? '';
          await _smsService.sendJobAssignedSms(
            technicianPhoneNumber: techPhone,
            technicianName: _selectedTechnician ?? '',
            trackingId: widget.trackingId,
            applianceType: widget.applianceType,
          );
          await _firestoreService.createNotification(
            recipientType: 'technician',
            recipientId: _selectedTechnicianId,
            title: 'New job assigned',
            body: '${widget.applianceType} (ID: ${widget.trackingId})',
            trackingId: widget.trackingId,
          );
        } catch (_) {
          // Non-fatal — the assignment itself already saved successfully.
        }
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus == 'Accepted'
                  ? 'Request accepted, assigned to $_selectedTechnician, and customer notified.'
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
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    customBorder: const CircleBorder(),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close,
                          size: 20, color: Color(0xFF6B7280)),
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
              const Text('Service Type',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151))),
              const SizedBox(height: 4),
              const Text(
                'On-Site = customer brings the appliance to the shop. '
                'Tech Visit = technician goes to the customer\'s address.',
                style: TextStyle(fontSize: 11.5, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: 'shop',
                      icon: Icon(Icons.store_outlined, size: 18),
                      label: Text('On-Site'),
                    ),
                    ButtonSegment(
                      value: 'home',
                      icon: Icon(Icons.home_outlined, size: 18),
                      label: Text('Tech Visit'),
                    ),
                  ],
                  selected: {_serviceMode},
                  onSelectionChanged: (v) =>
                      setState(() => _serviceMode = v.first),
                ),
              ),

              const SizedBox(height: 16),
              const Text('Technician (assigned by queue)',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151))),
              const SizedBox(height: 4),
              const Text(
                'The next available technician in the queue gets the job '
                'automatically.',
                style: TextStyle(fontSize: 11.5, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 6),
              _TechnicianPickerField(
                initialTechnician: _selectedTechnician,
                applianceType: widget.applianceType,
                onChanged: (name, id, manual) {
                  _selectedTechnician = name;
                  _selectedTechnicianId = id;
                  _assignedManually = manual;
                },
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
  bool _busy = false;
  double _sizeMm = 50; // sticker width
  late Future<QrSticker> _stickerFuture;

  String get _qrData => 'repairtrack://track/${widget.trackingId}';

  String get _fileName =>
      'QR_Sticker_${widget.trackingId}_${_sizeMm.round()}mm.png';

  @override
  void initState() {
    super.initState();
    _stickerFuture = _renderSticker();
  }

  // Print-ready sticker at an exact size (mm) and 600 DPI
  Future<QrSticker> _renderSticker() => renderQrSticker(
        data: _qrData,
        trackingId: widget.trackingId,
        widthMm: _sizeMm,
      );

  Future<void> _run(Future<void> Function(QrSticker sticker) action) async {
    setState(() => _busy = true);
    try {
      final sticker = await _stickerFuture;
      await action(sticker);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to prepare the sticker: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shareFile(QrSticker sticker) {
    return Share.shareXFiles(
      [XFile.fromData(sticker.png, name: _fileName, mimeType: 'image/png')],
      text: 'RepairTrack QR sticker — ${widget.trackingId}',
    );
  }

  // Save the sticker PNG (web: download; phone: share sheet)
  Future<void> _download() => _run((sticker) async {
        if (kIsWeb) {
          downloadBytesAsFile(sticker.png, _fileName);
        } else {
          await _shareFile(sticker);
        }
      });

  // Print the sticker (web: print dialog at the exact sticker size;
  // phone: share to a printer app / print service)
  Future<void> _print() => _run((sticker) async {
        if (kIsWeb) {
          printStickerPng(sticker.png, sticker.widthMm, sticker.heightMm);
        } else {
          await _shareFile(sticker);
        }
      });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
            const SizedBox(height: 14),

            // Sticker size
            Wrap(
              spacing: 8,
              children: [
                for (final size in kQrStickerSizes)
                  ChoiceChip(
                    label: Text('${size.$1} • ${size.$2.round()} mm'),
                    selected: _sizeMm == size.$2,
                    selectedColor: Colors.black,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _sizeMm == size.$2 ? Colors.white : Colors.black,
                    ),
                    onSelected: _busy
                        ? null
                        : (_) => setState(() {
                              _sizeMm = size.$2;
                              _stickerFuture = _renderSticker();
                            }),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // Live preview of the sticker that will be printed
            FutureBuilder<QrSticker>(
              future: _stickerFuture,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Text('Could not draw the sticker.'),
                  );
                }
                final sticker = snapshot.data;
                if (sticker == null) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                }
                return Column(
                  children: [
                    Container(
                      decoration: const BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Image.memory(
                        sticker.png,
                        width: 190,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${sticker.widthMm.round()} × '
                      '${sticker.heightMm.round()} mm • 600 DPI',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _busy ? null : _print,
                icon: _busy
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Icon(kIsWeb ? Icons.print : Icons.ios_share, size: 18),
                label: Text(kIsWeb ? 'Print Sticker' : 'Print / Share Sticker'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            if (kIsWeb) ...[
              const SizedBox(height: 6),
              const Text(
                'In the print window set Margins: None and Scale: 100%.',
                style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _download,
                icon: const Icon(Icons.download, size: 18),
                label: const Text('Download PNG'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF111827),
                  side: const BorderSide(color: Color(0xFFD1D5DB)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}
