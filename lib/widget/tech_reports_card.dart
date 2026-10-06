import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../utils/colors.dart';
import '../utils/report_data.dart';
import '../utils/report_pdf.dart';

/// Technician Settings -> Reports. Lists the recent weeks (and months),
/// newest first, each with a Print / Save PDF button.
class TechnicianReportsCard extends StatefulWidget {
  final String technicianDocId;
  final String technicianName;

  const TechnicianReportsCard({
    super.key,
    required this.technicianDocId,
    required this.technicianName,
  });

  @override
  State<TechnicianReportsCard> createState() => _TechnicianReportsCardState();
}

class _TechnicianReportsCardState extends State<TechnicianReportsCard> {
  bool _weekly = true;
  String? _busyLabel;

  late final List<ReportPeriod> _weeks = ReportPeriod.recentWeeks(weeks: 8);
  late final List<ReportPeriod> _months = ReportPeriod.recentMonths(months: 6);

  Future<void> _print(ReportPeriod period, {bool download = false}) async {
    setState(() => _busyLabel = period.label);
    try {
      // Jobs are keyed by the technician's document id (assignedTechnicianUid).
      final jobsSnap =
          await FirestoreService().streamMyJobs(widget.technicianDocId).first;
      final jobs = jobsFromDocs(
        jobsSnap.docs.map((d) => d.data() as Map<String, dynamic>),
      );

      // Clock in/out rows that start inside the period (plus a day of
      // slack so a shift that ends after midnight is still paired).
      final logsSnap = await FirebaseFirestore.instance
          .collection('technicians')
          .doc(widget.technicianDocId)
          .collection('dutyLogs')
          .where('timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(period.start))
          .where('timestamp',
              isLessThan: Timestamp.fromDate(
                  period.end.add(const Duration(days: 1))))
          .get();

      // Jobs this technician declined are no longer assigned to them,
      // so they are fetched separately.
      var declinedJobs = <ReportJob>[];
      try {
        final declinedSnap = await FirebaseFirestore.instance
            .collection('repairRequests')
            .where('declinedByTechnicianIds',
                arrayContains: widget.technicianDocId)
            .get();
        declinedJobs = jobsFromDocs(declinedSnap.docs.map((d) => d.data()));
      } catch (_) {
        // Non-fatal: the report just won't list declines.
      }

      final report = buildTechnicianReport(
        technicianDocId: widget.technicianDocId,
        declinedJobs: declinedJobs,
        technicianName: widget.technicianName.isEmpty
            ? 'Technician'
            : widget.technicianName,
        jobs: jobs,
        dutyLogs: logsSnap.docs.map((d) => d.data()).toList(),
        period: period,
      );
      if (download) {
        await downloadTechnicianReport(report);
      } else {
        await printTechnicianReport(report);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not create the report: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busyLabel = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final periods = _weekly ? _weeks : _months;
    final current = periods.first;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.summarize_outlined, size: 20),
              SizedBox(width: 8),
              Text('My Reports',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark)),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Printable summary of the repair requests you handled.',
            style: TextStyle(fontSize: 12.5, color: AppColors.textGray),
          ),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Weekly')),
              ButtonSegment(value: false, label: Text('Monthly')),
            ],
            selected: {_weekly},
            onSelectionChanged: (s) => setState(() => _weekly = s.first),
          ),
          const SizedBox(height: 8),
          for (final p in periods)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                _weekly ? p.rangeText : p.label,
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                identical(p, current)
                    ? (_weekly ? 'This week (so far)' : 'This month (so far)')
                    : (_weekly ? 'Weekly report' : p.rangeText),
                style: const TextStyle(fontSize: 11.5),
              ),
              trailing: _busyLabel == p.label
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Download PDF',
                          icon: const Icon(Icons.download_outlined),
                          onPressed: _busyLabel == null
                              ? () => _print(p, download: true)
                              : null,
                        ),
                        IconButton(
                          tooltip: 'Print',
                          icon: const Icon(Icons.print_outlined),
                          onPressed:
                              _busyLabel == null ? () => _print(p) : null,
                        ),
                      ],
                    ),
            ),
        ],
      ),
    );
  }
}
