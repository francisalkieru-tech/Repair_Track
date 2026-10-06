import 'package:flutter/material.dart';

import '../services/firestore_service.dart';
import '../utils/colors.dart';
import '../utils/constants.dart';
import '../utils/technician_availability.dart';

/// Technician "On Duty" button: Clock In / Clock Out, shown at the top of the
/// technician app. Every clock event is saved to technicians/{id}/dutyLogs so
/// Admin can monitor attendance. No password is asked — one tap.
///
/// Only technicians who are clocked in today receive jobs from the queue.
class DutyClockCard extends StatefulWidget {
  final String technicianDocId;
  final Map<String, dynamic>? data; // technicians/{id} document data

  const DutyClockCard({
    super.key,
    required this.technicianDocId,
    required this.data,
  });

  @override
  State<DutyClockCard> createState() => _DutyClockCardState();
}

class _DutyClockCardState extends State<DutyClockCard> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _busy = false;

  String _formatTime(DateTime t) {
    final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final minute = t.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${t.hour >= 12 ? 'PM' : 'AM'}';
  }

  Future<void> _toggle(bool clockedIn) async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      // Warn before clocking out with unfinished jobs
      if (clockedIn) {
        final jobs =
            await _firestoreService.streamMyJobs(widget.technicianDocId).first;
        final active = jobs.docs.where((d) {
          final s = (d.data() as Map<String, dynamic>)['status'];
          return s != AppConstants.statusCompleted &&
              s != AppConstants.statusDeclined;
        }).length;

        if (active > 0 && mounted) {
          final proceed = await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
              title: const Text('Clock out?'),
              content: Text(
                'You still have $active active job${active == 1 ? '' : 's'}. '
                'You will not receive new jobs while clocked out.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: const Text('Stay on duty'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(c, true),
                  child: const Text('Clock out'),
                ),
              ],
            ),
          );
          if (proceed != true) return;
        }
      }

      if (!mounted) return;

      if (clockedIn) {
        await _firestoreService.clockOutTechnician(widget.technicianDocId);
      } else {
        await _firestoreService.clockInTechnician(widget.technicianDocId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update duty status: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data ?? const <String, dynamic>{};
    final clockedIn = isTechnicianClockedIn(data);
    final since = technicianClockedInSince(data);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: clockedIn ? Colors.green : Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  clockedIn ? 'On duty' : 'Off duty',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700),
                ),
                Text(
                  clockedIn && since != null
                      ? 'Since ${_formatTime(since)} — you can receive jobs'
                      : 'Clock in to receive jobs',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: _busy ? null : () => _toggle(clockedIn),
            style: FilledButton.styleFrom(
              backgroundColor: clockedIn ? Colors.white : AppColors.dark,
              foregroundColor: clockedIn ? AppColors.dark : Colors.white,
              side: clockedIn ? BorderSide(color: AppColors.dark) : null,
            ),
            child: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(clockedIn ? 'Clock Out' : 'Clock In'),
          ),
        ],
      ),
    );
  }
}
