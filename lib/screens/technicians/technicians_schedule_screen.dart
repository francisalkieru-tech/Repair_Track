import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firestore_service.dart';
import '../../utils/colors.dart';
import 'technicians_job_details.dart';
import '../../utils/constants.dart';


class TechnicianScheduleTabContent extends StatefulWidget {
  final String technicianDocId;

  const TechnicianScheduleTabContent({super.key, required this.technicianDocId});

  @override
  State<TechnicianScheduleTabContent> createState() =>
      _TechnicianScheduleTabContentState();
}

class _TechnicianScheduleTabContentState
    extends State<TechnicianScheduleTabContent> {
  DateTime _selectedDay = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );
  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreService().streamMyJobs(widget.technicianDocId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // Only jobs Admin actually gave a date/time to — most jobs
        // won't have one until scheduled.
        final scheduledJobs = (snapshot.data?.docs ?? [])
            .where((d) =>
                d.data() is Map &&
                (d.data() as Map)['scheduledVisit'] != null &&
                (d.data() as Map)['status'] != 'Declined' &&
                (d.data() as Map)['status'] != 'Completed')
            .toList();

        final jobsByDay = <DateTime, List<QueryDocumentSnapshot>>{};
        for (final doc in scheduledJobs) {
          final ts = (doc.data() as Map)['scheduledVisit'] as Timestamp;
          final day =
              DateTime(ts.toDate().year, ts.toDate().month, ts.toDate().day);
          jobsByDay.putIfAbsent(day, () => []).add(doc);
        }

        final daysWithJobs = jobsByDay.keys.toSet();
        final selectedDayJobs = jobsByDay[_selectedDay] ?? const [];

        return Column(
          children: [
            _MonthGrid(
              visibleMonth: _visibleMonth,
              selectedDay: _selectedDay,
              daysWithJobs: daysWithJobs,
              onMonthChanged: (m) => setState(() => _visibleMonth = m),
              onDaySelected: (d) => setState(() => _selectedDay = d),
            ),
            const Divider(height: 1),
            Expanded(
              child: selectedDayJobs.isEmpty
                  ? Center(
                      child: Text(
                        'No jobs scheduled for '
                        '${_selectedDay.month}/${_selectedDay.day}/${_selectedDay.year}.',
                        style: const TextStyle(color: AppColors.textGray),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: selectedDayJobs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final doc = selectedDayJobs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        return _ScheduledJobCard(
                          data: data,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TechnicianJobDetailScreen(
                                docId: doc.id,
                                data: data,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _MonthGrid extends StatelessWidget {
  final DateTime visibleMonth;
  final DateTime selectedDay;
  final Set<DateTime> daysWithJobs;
  final void Function(DateTime) onMonthChanged;
  final void Function(DateTime) onDaySelected;

  const _MonthGrid({
    required this.visibleMonth,
    required this.selectedDay,
    required this.daysWithJobs,
    required this.onMonthChanged,
    required this.onDaySelected,
  });

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  static const _weekdayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  @override
  Widget build(BuildContext context) {
    final firstOfMonth = DateTime(visibleMonth.year, visibleMonth.month, 1);
    final daysInMonth =
        DateTime(visibleMonth.year, visibleMonth.month + 1, 0).day;
    final leadingBlanks = firstOfMonth.weekday % 7; // Sunday = 0

    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => onMonthChanged(
                    DateTime(visibleMonth.year, visibleMonth.month - 1)),
              ),
              Text(
                '${_monthNames[visibleMonth.month - 1]} ${visibleMonth.year}',
                style: const TextStyle(
                    fontSize: AppColors.fontBody, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => onMonthChanged(
                    DateTime(visibleMonth.year, visibleMonth.month + 1)),
              ),
            ],
          ),
          Row(
            children: _weekdayLabels
                .map((l) => Expanded(
                      child: Center(
                        child: Text(l,
                            style: const TextStyle(
                                fontSize: AppColors.fontCaption,
                                color: AppColors.textGray,
                                fontWeight: FontWeight.w600)),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 4),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: leadingBlanks + daysInMonth,
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
            ),
            itemBuilder: (context, index) {
              if (index < leadingBlanks) return const SizedBox.shrink();
              final day = index - leadingBlanks + 1;
              final date =
                  DateTime(visibleMonth.year, visibleMonth.month, day);
              final isSelected = date.year == selectedDay.year &&
                  date.month == selectedDay.month &&
                  date.day == selectedDay.day;
              final isToday = date.year == todayDay.year &&
                  date.month == todayDay.month &&
                  date.day == todayDay.day;
              final hasJobs = daysWithJobs.any((d) =>
                  d.year == date.year &&
                  d.month == date.month &&
                  d.day == date.day);

              return GestureDetector(
                onTap: () => onDaySelected(date),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.dark
                        : isToday
                            ? AppColors.dark.withValues(alpha: 0.08)
                            : null,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$day',
                        style: TextStyle(
                          fontSize: AppColors.fontLabel,
                          fontWeight:
                              isToday ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.white : null,
                        ),
                      ),
                      if (hasJobs)
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? Colors.white
                                : AppColors.inProcess,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ScheduledJobCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  const _ScheduledJobCard({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final appliance = data['applianceType'] as String? ?? 'Appliance';
    final trackingId = data['trackingId'] as String? ?? '';
    final status = data['status'] as String? ?? '';
    final isHomeVisit = status == AppConstants.statusInHome;
    final customerName = data['name'] as String? ?? '';
    final contactNumber = data['contactNumber'] as String? ?? '';
    final address = data['address'] as String? ?? '';
    final ts = data['scheduledVisit'] as Timestamp?;
    final time = ts != null ? TimeOfDay.fromDateTime(ts.toDate()) : null;

    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isHomeVisit ? AppColors.inProcess : AppColors.border,
              width: isHomeVisit ? 1.4 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(appliance,
                      style: const TextStyle(
                          fontSize: AppColors.fontLabel,
                          fontWeight: FontWeight.bold)),
                  if (isHomeVisit)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.inProcess.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('Home visit',
                          style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.inProcess)),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text('Tracking ID: $trackingId',
                  style: const TextStyle(
                      fontSize: AppColors.fontCaption,
                      color: AppColors.textGray)),
              if (customerName.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.person_outline,
                        size: 14, color: AppColors.textGray),
                    const SizedBox(width: 4),
                    Text(customerName,
                        style: const TextStyle(
                            fontSize: AppColors.fontCaption,
                            color: AppColors.textGray)),
                    if (contactNumber.isNotEmpty) ...[
                      const Text(' · ',
                          style: TextStyle(
                              fontSize: AppColors.fontCaption,
                              color: AppColors.textGray)),
                      Text(contactNumber,
                          style: const TextStyle(
                              fontSize: AppColors.fontCaption,
                              color: AppColors.textGray)),
                    ],
                  ],
                ),
              ],
              if (time != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.access_time,
                        size: 14, color: AppColors.textGray),
                    const SizedBox(width: 4),
                    Text(time.format(context),
                        style: const TextStyle(
                            fontSize: AppColors.fontCaption,
                            color: AppColors.textGray)),
                  ],
                ),
              ],
              if (address.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 14, color: AppColors.textGray),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(address,
                          style: const TextStyle(
                              fontSize: AppColors.fontCaption,
                              color: AppColors.textGray)),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
