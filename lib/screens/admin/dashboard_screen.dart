import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/firestore_service.dart';
import '../../utils/constants.dart';
import '../../utils/technician_availability.dart';
import 'admin_theme.dart';

// Admin dashboard — kept minimal on purpose (panel feedback: not crowded).
//   Row 1: Active Jobs | Technicians (active today / registered) | Completed Tasks
//   Row 2: Today's Schedule (Tech Visits) — large
//   Row 3: Technicians (who is on duty, repairing, available)
//
// Active Jobs = the repairs in the "In Process" tab; clicking the card opens
// that tab. The card only mentions how many are Accepted / new.
// "Active" technician = clocked in today (Clock In on the technician app).
// Tapping Completed Tasks opens a list of the finished repairs for today /
// this week / this month.
class DashboardScreen extends StatelessWidget {
  final ValueChanged<int>? onNavigate;

  /// Opens Repair Request on a given tab (0 New, 1 Accepted, 2 In Process).
  final ValueChanged<int>? onOpenRequestsTab;

  const DashboardScreen({super.key, this.onNavigate, this.onOpenRequestsTab});

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();

    return Container(
      color: kAdminBg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        child: StreamBuilder<QuerySnapshot>(
          stream: firestoreService.streamRepairRequests(),
          builder: (context, requestSnap) {
            if (requestSnap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.only(top: 100),
                child: Center(
                  child: CircularProgressIndicator(color: Colors.black),
                ),
              );
            }

            final all = (requestSnap.data?.docs ?? [])
                .map((d) => d.data() as Map<String, dynamic>)
                .toList();

            return StreamBuilder<QuerySnapshot>(
              stream: firestoreService.streamTechnicians(),
              builder: (context, techSnap) {
                final techs = (techSnap.data?.docs ?? [])
                    .map((d) => d.data() as Map<String, dynamic>)
                    .toList();

                return _DashboardBody(
                  all: all,
                  techs: techs,
                  onNavigate: onNavigate,
                  onOpenRequestsTab: onOpenRequestsTab,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// HELPERS

// Statuses where the appliance is actually being worked on (at the
// customer's home, on the bench, or waiting on parts mid-repair).
const Set<String> _repairStatuses = {
  AppConstants.statusTechVisit,
  AppConstants.statusOnSite,
  AppConstants.statusInProcess,
  AppConstants.statusWaitingParts,
};

bool _isRepairing(Map<String, dynamic> data) => _repairStatuses
    .contains(AppConstants.normalizeStatus((data['status'] ?? '') as String));

// Active job = exactly what the "In Process" tab of Repair Request lists:
// not New (Pending), not just Accepted, not Completed, not Declined.
// (So the number on the card always matches the tab it opens.)
bool _isActive(Map<String, dynamic> data) {
  final status = data['status'];
  return status != AppConstants.statusPending &&
      status != 'Accepted' &&
      status != AppConstants.statusCompleted &&
      status != AppConstants.statusDeclined;
}

// When a request was completed: latest "Completed" entry in its status
// history (accurate even if the document is edited again later), falling
// back to updatedAt for older records.
DateTime? _completedAt(Map<String, dynamic> data) {
  if (data['status'] != AppConstants.statusCompleted) return null;

  DateTime? latest;
  final history = data['statusHistory'];
  if (history is List) {
    for (final h in history) {
      if (h is Map &&
          h['status'] == AppConstants.statusCompleted &&
          h['timestamp'] is Timestamp) {
        final t = (h['timestamp'] as Timestamp).toDate();
        if (latest == null || t.isAfter(latest)) latest = t;
      }
    }
  }
  if (latest != null) return latest;

  final updated = data['updatedAt'];
  return updated is Timestamp ? updated.toDate() : null;
}

// Monday 00:00 of the current week.
DateTime _weekStart(DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  return today.subtract(Duration(days: now.weekday - 1));
}

String _formatTime(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final period = date.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $period';
}

const _shortMonths = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

class _TechRow {
  final String name;
  final int activeJobs;
  final int inRepair;
  final bool clockedIn;
  final String state; // 'available' | 'visit' | 'full' | 'off'

  const _TechRow(
    this.name,
    this.activeJobs,
    this.inRepair,
    this.clockedIn,
    this.state,
  );
}

// Technician numbers for the dashboard, computed live. "Active" = clocked in
// today. Available = clocked in and able to take a job.
class _TechSummary {
  final List<_TechRow> rows;
  final int total;
  final int active;
  final int available;
  final int onVisit;
  final int fullyBooked;
  final int offDuty; // not clocked in today (day off / not yet in)
  final int queued; // has a job waiting to be processed

  const _TechSummary({
    required this.rows,
    required this.total,
    required this.active,
    required this.available,
    required this.onVisit,
    required this.fullyBooked,
    required this.offDuty,
    required this.queued,
  });

  factory _TechSummary.from(
    List<Map<String, dynamic>> all,
    List<Map<String, dynamic>> techs,
  ) {
    final rows = <_TechRow>[];
    var active = 0, available = 0, onVisit = 0, full = 0, queued = 0;

    for (final tech in techs) {
      final name = (tech['name'] ?? '') as String;
      final jobs = activeJobsForTechnician(all, name);
      final repairing = jobs.where(_isRepairing).length;
      final visiting =
          jobs.any((r) => AppConstants.isTechVisit(r['status'] as String?));
      final clockedIn = isTechnicianClockedIn(tech);
      final free = isTechnicianAssignable(all, tech);

      final state = !clockedIn
          ? 'off'
          : free
              ? 'available'
              : (visiting ? 'visit' : 'full');

      if (clockedIn) active++;
      if (state == 'available') available++;
      if (state == 'visit') onVisit++;
      if (state == 'full') full++;
      if (jobs.any((r) => r['status'] == AppConstants.statusQueued)) queued++;

      rows.add(_TechRow(name, jobs.length, repairing, clockedIn, state));
    }

    // Clocked-in technicians first
    rows.sort((a, b) {
      final byDuty = (a.clockedIn ? 0 : 1).compareTo(b.clockedIn ? 0 : 1);
      return byDuty != 0 ? byDuty : a.name.compareTo(b.name);
    });

    return _TechSummary(
      rows: rows,
      total: techs.length,
      active: active,
      available: available,
      onVisit: onVisit,
      fullyBooked: full,
      offDuty: techs.length - active,
      queued: queued,
    );
  }
}

// BODY
class _DashboardBody extends StatelessWidget {
  final List<Map<String, dynamic>> all;
  final List<Map<String, dynamic>> techs;
  final ValueChanged<int>? onNavigate;
  final ValueChanged<int>? onOpenRequestsTab;

  const _DashboardBody({
    required this.all,
    required this.techs,
    required this.onNavigate,
    this.onOpenRequestsTab,
  });

  VoidCallback? _go(int index) =>
      onNavigate == null ? null : () => onNavigate!(index);

  @override
  Widget build(BuildContext context) {
    final summary = _TechSummary.from(all, techs);

    // Active Jobs = assigned and in process. The subtitle splits them into
    // the ones being repaired and the ones not started yet; new requests are
    // only mentioned, not counted.
    final activeList = all.where(_isActive).toList();
    final accepted = all.where((d) => d['status'] == 'Accepted').length;
    final newRequests =
        all.where((d) => d['status'] == AppConstants.statusPending).length;

    final completedList = all
        .where((d) => d['status'] == AppConstants.statusCompleted)
        .toList();

    final activeCard = _StatCard(
      title: 'Active Jobs',
      value: '${activeList.length}',
      subtitle: '$accepted accepted • $newRequests new',
      icon: Icons.build_circle_rounded,
      // Straight to the In Process tab
      onTap: onOpenRequestsTab == null
          ? _go(1)
          : () => onOpenRequestsTab!(2),
    );

    final techCard = _StatCard(
      title: 'Technicians',
      value: '${summary.active}/${summary.total}',
      subtitle: 'Active today / registered',
      icon: Icons.engineering_rounded,
      onTap: _go(3),
    );

    final completedCard = _StatCard(
      title: 'Completed Tasks',
      value: '${completedList.length}',
      subtitle: 'Tap to see today, week, month',
      icon: Icons.task_alt_rounded,
      iconSuccess: true,
      onTap: () => _showCompletedTasksDialog(
        context,
        completedList,
        onViewAll: _go(2),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // STAT CARDS
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 640) {
              final cards = [activeCard, techCard, completedCard];
              return Row(
                children: [
                  for (int i = 0; i < cards.length; i++)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: i == 0 ? 0 : 6,
                          right: i == cards.length - 1 ? 0 : 6,
                        ),
                        child: cards[i],
                      ),
                    ),
                ],
              );
            }

            // Phones: two on top, Completed Tasks full width below.
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(child: activeCard),
                    const SizedBox(width: 12),
                    Expanded(child: techCard),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(width: double.infinity, child: completedCard),
              ],
            );
          },
        ),

        const SizedBox(height: 22),

        // TODAY'S SCHEDULE (big, full width)
        _TodayScheduleCard(all: all),

        const SizedBox(height: 22),

        // TECHNICIANS (bottom)
        _TechnicianPanel(summary: summary),
      ],
    );
  }
}

// STAT CARD
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final bool iconSuccess;
  final Widget? footer;
  final VoidCallback? onTap;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    this.subtitle,
    this.iconSuccess = false,
    this.footer,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = iconSuccess ? Colors.green : Colors.black;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        mouseCursor:
            onTap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
        child: Container(
          height: 124,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFBDBDBD)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 36),
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 36,
                      height: 1,
                      fontWeight: FontWeight.w400,
                      color: Colors.black,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF666666),
                      ),
                    ),
                  ],
                  if (footer != null) ...[
                    const SizedBox(height: 6),
                    footer!,
                  ],
                ],
              ),
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: accent, width: 1.5),
                  ),
                  child: Icon(icon, size: 17, color: accent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Small pill used for the Today / Week / Month style toggles.
class _ToggleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ToggleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: selected ? Colors.black : const Color(0xFFEFEFEF),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : const Color(0xFF444444),
          ),
        ),
      ),
    );
  }
}

// COMPLETED TASKS DIALOG (Today / This Week / This Month)
// Opened from the Completed Tasks card: lists the repairs that were
// finished in the chosen period, newest first.
void _showCompletedTasksDialog(
  BuildContext context,
  List<Map<String, dynamic>> completed, {
  VoidCallback? onViewAll,
}) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) {
      var period = 0; // 0 = today, 1 = this week, 2 = this month

      return StatefulBuilder(
        builder: (context, setState) {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);

          late final DateTime from;
          late final DateTime to;
          switch (period) {
            case 1:
              from = _weekStart(now);
              to = from.add(const Duration(days: 7));
              break;
            case 2:
              from = DateTime(now.year, now.month, 1);
              to = DateTime(now.year, now.month + 1, 1);
              break;
            default:
              from = today;
              to = today.add(const Duration(days: 1));
          }

          final items = completed.where((d) {
            final t = _completedAt(d);
            return t != null && !t.isBefore(from) && t.isBefore(to);
          }).toList()
            ..sort((a, b) => _completedAt(b)!.compareTo(_completedAt(a)!));

          const labels = ['Today', 'This Week', 'This Month'];

          return Dialog(
            backgroundColor: Colors.white,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520, maxHeight: 560),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Completed Tasks',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        for (int i = 0; i < labels.length; i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          _ToggleChip(
                            label: labels[i],
                            selected: period == i,
                            onTap: () => setState(() => period = i),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${items.length} repair${items.length == 1 ? '' : 's'} '
                      'completed ${labels[period].toLowerCase()}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF666666),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: items.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 36),
                              child: Center(
                                child: Text(
                                  'No completed repairs in this period.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF777777),
                                  ),
                                ),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              itemCount: items.length,
                              separatorBuilder: (_, __) => const Divider(
                                height: 14,
                                color: Color(0xFFEDEDED),
                              ),
                              itemBuilder: (context, index) {
                                final d = items[index];
                                final done = _completedAt(d)!;
                                final appliance =
                                    (d['applianceType'] ?? '') as String;
                                final model =
                                    ((d['applianceModel'] ?? '') as String)
                                        .trim();
                                final customer = (d['name'] ?? '') as String;
                                final tech = (d['assignedTechnician'] ??
                                    'Unassigned') as String;
                                final trackingId =
                                    (d['trackingId'] ?? '') as String;

                                // Today: just the time. Otherwise date + time.
                                final when = period == 0
                                    ? _formatTime(done)
                                    : '${_shortMonths[done.month - 1]} '
                                        '${done.day} • ${_formatTime(done)}';

                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.only(top: 1),
                                      child: Icon(
                                        Icons.check_circle,
                                        size: 18,
                                        color: Colors.green,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            model.isEmpty
                                                ? appliance
                                                : '$appliance • $model',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.black,
                                            ),
                                          ),
                                          Text(
                                            trackingId.isEmpty
                                                ? customer
                                                : '$customer • $trackingId',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF555555),
                                            ),
                                          ),
                                          Text(
                                            'Technician: $tech',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF374151),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      when,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF666666),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                    ),
                    if (onViewAll != null) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            onViewAll();
                          },
                          child: const Text('View all completed'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

// COMMON PANEL SHELL
class _Panel extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final double height;

  const _Panel({
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.height = 290,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFFBDBDBD)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF666666),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 10),
          Expanded(child: child),
        ],
      ),
    );
  }
}

// TECHNICIANS (registered / available / on Tech Visit / fully booked / online)
class _TechnicianPanel extends StatelessWidget {
  final _TechSummary summary;

  const _TechnicianPanel({required this.summary});

  Widget _summaryChip(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '$label $value',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
        ],
      ),
    );
  }

  (String, Color, Color) _badge(String state) {
    switch (state) {
      case 'available':
        return ('Available', Colors.green, const Color(0xFFD9F8E4));
      case 'visit':
        return (
          'On ${AppConstants.statusTechVisit}',
          const Color(0xFF5B21B6),
          const Color(0xFFEBDDFF),
        );
      case 'off':
        return ('Off duty', const Color(0xFF555555), const Color(0xFFE5E5E5));
      default:
        return ('Fully booked', const Color(0xFF92400E), const Color(0xFFFEF3C7));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Technicians',
      subtitle: 'Who is on duty, repairing and available',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _summaryChip('Registered', summary.total, Colors.black),
              _summaryChip('On duty', summary.active, Colors.green),
              _summaryChip('Off duty', summary.offDuty, Colors.grey),
              _summaryChip('Available', summary.available,
                  const Color(0xFF2563EB)),
              _summaryChip('On Tech Visit', summary.onVisit,
                  const Color(0xFF5B21B6)),
              _summaryChip('Queued', summary.queued,
                  const Color(0xFF0E7490)),
              _summaryChip('Fully booked', summary.fullyBooked,
                  const Color(0xFFD97706)),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: summary.rows.isEmpty
                ? const Center(
                    child: Text(
                      'No technicians yet.',
                      style:
                          TextStyle(fontSize: 12, color: Color(0xFF777777)),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: summary.rows.length,
                    itemBuilder: (context, index) {
                      final row = summary.rows[index];
                      final badge = _badge(row.state);

                      final jobsText = row.activeJobs == 0
                          ? 'No active jobs'
                          : '${row.activeJobs} active job'
                              '${row.activeJobs == 1 ? '' : 's'}'
                              ' • ${row.inRepair} in repair';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 9),
                        child: Row(
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: const BoxDecoration(
                                    color: Colors.black,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      row.name.isNotEmpty
                                          ? row.name[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                // Green dot = clocked in today
                                if (row.clockedIn)
                                  Positioned(
                                    right: -1,
                                    bottom: -1,
                                    child: Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Colors.white, width: 1.5),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    row.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black,
                                    ),
                                  ),
                                  Text(
                                    jobsText,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF777777),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: badge.$3,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                badge.$1,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: badge.$2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// TODAY'S SCHEDULE (Tech Visits)
// Each row: date, time, customer name, address and the problem.
const _weekdayNames = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday',
  'Friday', 'Saturday', 'Sunday',
];

class _TodayScheduleCard extends StatelessWidget {
  final List<Map<String, dynamic>> all;

  const _TodayScheduleCard({required this.all});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    final todayJobs = all.where((data) {
      final ts = data['scheduledVisit'];
      if (ts is! Timestamp) return false;
      if (data['status'] == AppConstants.statusDeclined) return false;
      final d = ts.toDate();
      return d.year == now.year && d.month == now.month && d.day == now.day;
    }).toList()
      ..sort((a, b) => (a['scheduledVisit'] as Timestamp)
          .compareTo(b['scheduledVisit'] as Timestamp));

    final dateLabel = '${_weekdayNames[now.weekday - 1]}, '
        '${_shortMonths[now.month - 1]} ${now.day}';

    return _Panel(
      title: "Today's Schedule",
      subtitle: todayJobs.isEmpty
          ? '$dateLabel • No Tech Visits'
          : '$dateLabel • ${todayJobs.length} Tech Visit'
              '${todayJobs.length == 1 ? '' : 's'}',
      height: 460,
      child: todayJobs.isEmpty
          ? const Center(
              child: Text(
                'No Tech Visits scheduled today.',
                style: TextStyle(fontSize: 14, color: Color(0xFF777777)),
              ),
            )
          : ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: todayJobs.length,
              separatorBuilder: (context, index) =>
                  const Divider(height: 24, color: Color(0xFFEDEDED)),
              itemBuilder: (context, index) {
                final data = todayJobs[index];
                final visit = (data['scheduledVisit'] as Timestamp).toDate();

                final customer = (data['name'] ?? '') as String;
                final address = (data['address'] ?? '') as String;
                final issue = (data['problemDescription'] ?? '') as String;
                final technician =
                    (data['assignedTechnician'] ?? 'Unassigned') as String;
                final appliance = (data['applianceType'] ?? '') as String;
                final brand = ((data['brand'] ?? '') as String).trim();
                final model = ((data['applianceModel'] ?? '') as String).trim();
                final brandModel =
                    [brand, model].where((s) => s.isNotEmpty).join(' • ');
                final status = (data['status'] ?? '') as String;
                final badgeColors = statusColors(status);

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date + time
                    SizedBox(
                      width: 92,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_shortMonths[visit.month - 1]} ${visit.day}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF666666),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatTime(visit),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Customer, address, problem
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            appliance.isEmpty
                                ? customer
                                : '$customer • $appliance',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.engineering_outlined,
                                size: 15,
                                color: Color(0xFF666666),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Technician: $technician  •  '
                                  'Ticket ${data['trackingId'] ?? ''}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF444444),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (brandModel.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.devices_other_outlined,
                                  size: 15,
                                  color: Color(0xFF666666),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Brand / Model: $brandModel',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF444444),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (address.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 1),
                                  child: Icon(
                                    Icons.location_on_outlined,
                                    size: 15,
                                    color: Color(0xFF666666),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    address,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF444444),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (issue.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 1),
                                  child: Icon(
                                    Icons.build_outlined,
                                    size: 15,
                                    color: Color(0xFF666666),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    issue,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF444444),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: badgeColors.$1,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        AppConstants.displayLabel(status),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: badgeColors.$2,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
