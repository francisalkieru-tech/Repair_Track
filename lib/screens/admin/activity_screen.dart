import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/firestore_service.dart';
import '../../utils/report_data.dart';
import '../../utils/ui_widgets.dart';
import '../../utils/report_pdf.dart';
import 'admin_theme.dart';

/// Recent Activity (own tab): the latest status changes across all tickets,
/// newest first — ticket number, appliance, status badge, who and when.
/// Reassignments show as "Technician reassigned from X to Y".
class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _formatStamp(DateTime t) {
    final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final minute = t.minute.toString().padLeft(2, '0');
    return '${_months[t.month - 1]} ${t.day}, $hour:$minute '
        '${t.hour >= 12 ? 'PM' : 'AM'}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kAdminBg,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirestoreService().streamRepairRequests(),
        builder: (context, snapshot) {
          // Show a clear error instead of an endless spinner / blank screen.
          if (snapshot.hasError) {
            return AppErrorState(message: friendlyErrorMessage(snapshot.error));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.black),
            );
          }

          // Flatten every ticket's status history into one feed
          final events = <_Event>[];
          for (final doc in snapshot.data?.docs ?? []) {
            final data = doc.data() as Map<String, dynamic>;
            final history = data['statusHistory'];
            if (history is! List) continue;

            for (final h in history) {
              if (h is! Map || h['timestamp'] is! Timestamp) continue;
              events.add(_Event(
                ticket: (data['trackingId'] ?? '') as String,
                appliance: (data['applianceType'] ?? '') as String,
                status: (h['status'] ?? '') as String,
                technician: h['technician'] as String?,
                reassignedFrom: h['reassignedFrom'] as String?,
                declinedBy: h['declinedBy'] as String?,
                declineReason: (h['declineReason'] ?? '') as String,
                note: (h['note'] ?? '') as String,
                time: (h['timestamp'] as Timestamp).toDate(),
              ));
            }
          }
          events.sort((a, b) => b.time.compareTo(a.time));
          final shown = events.take(60).toList();

          final reportBar = _ReportBar(
            requests: [
              for (final doc in snapshot.data?.docs ?? [])
                doc.data() as Map<String, dynamic>,
            ],
          );

          if (shown.isEmpty) {
            return Column(
              children: [
                reportBar,
                const Expanded(
                  child: Center(
                    child: Text(
                      'No activity yet.',
                      style: TextStyle(color: kAdminTextGray),
                    ),
                  ),
                ),
              ],
            );
          }

          final list = ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: shown.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final e = shown[index];
              final detail = e.declinedBy != null && e.reassignedFrom == null
                  ? '${e.declinedBy} declined'
                      '${e.declineReason.isEmpty ? '' : ': ${e.declineReason}'}'
                      ' - needs reassignment'
                  : e.reassignedFrom != null
                  ? 'Technician reassigned from ${e.reassignedFrom} to '
                      '${e.technician ?? ''}'
                      '${e.declinedBy != null ? ' (declined${e.declineReason.isEmpty ? '' : ': ${e.declineReason}'})' : ''}'
                  : e.technician != null
                      ? 'Technician: ${e.technician}'
                      : '';

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBDBDBD)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ticket ${e.ticket} • ${e.appliance}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                          if (detail.isNotEmpty)
                            Text(
                              detail,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF555555),
                              ),
                            ),
                          if (e.note.isNotEmpty && e.reassignedFrom == null)
                            Text(
                              e.note,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF777777),
                              ),
                            ),
                          const SizedBox(height: 4),
                          Text(
                            _formatStamp(e.time),
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF777777),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    TicketBadge(status: e.status),
                  ],
                ),
              );
            },
          );

          return Column(
            children: [
              reportBar,
              Expanded(child: list),
            ],
          );
        },
      ),
    );
  }
}

/// Printable monthly report for Admin: pick a month, then Print / Save PDF.
class _ReportBar extends StatefulWidget {
  final List<Map<String, dynamic>> requests;
  const _ReportBar({required this.requests});

  @override
  State<_ReportBar> createState() => _ReportBarState();
}

class _ReportBarState extends State<_ReportBar> {
  late final List<ReportPeriod> _months = ReportPeriod.recentMonths(months: 12);
  late ReportPeriod _selected = _months.first;
  bool _busy = false;

  Future<void> _print({bool download = false}) async {
    setState(() => _busy = true);
    try {
      final jobs = jobsFromDocs(widget.requests);
      final report = buildAdminReport(jobs, _selected);
      if (download) {
        await downloadAdminReport(report);
      } else {
        await printAdminReport(report);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not create the report: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBDBDBD)),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          const Icon(Icons.summarize_outlined, size: 20, color: Colors.black),
          const Text(
            'Monthly Report',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          DropdownButton<ReportPeriod>(
            value: _selected,
            underline: const SizedBox.shrink(),
            items: [
              for (final m in _months)
                DropdownMenuItem(value: m, child: Text(m.label)),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _selected = v);
            },
          ),
          ElevatedButton.icon(
            onPressed: _busy ? null : _print,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.print_outlined, size: 18),
            label: const Text('Print'),
            style: ElevatedButton.styleFrom(
              backgroundColor: kAdminBrand,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
          ),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _print(download: true),
            icon: const Icon(Icons.download_outlined, size: 18),
            label: const Text('Download PDF'),
          ),
        ],
      ),
    );
  }
}

class _Event {
  final String ticket;
  final String appliance;
  final String status;
  final String? technician;
  final String? reassignedFrom;
  final String? declinedBy;
  final String declineReason;
  final String note;
  final DateTime time;

  const _Event({
    required this.ticket,
    required this.appliance,
    required this.status,
    required this.technician,
    required this.reassignedFrom,
    this.declinedBy,
    this.declineReason = '',
    required this.note,
    required this.time,
  });
}
