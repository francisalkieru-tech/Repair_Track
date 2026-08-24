import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/firestore_service.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();

    return Container(
      color: const Color(0xFFEFEFEF),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 18, 20, 24),
        child: StreamBuilder<QuerySnapshot>(
          stream: firestoreService.streamRepairRequests(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.only(top: 100),
                child: Center(
                  child: CircularProgressIndicator(
                    color: Colors.black,
                  ),
                ),
              );
            }

            final docs = snapshot.data?.docs ?? [];

            final allData = docs
                .map(
                  (d) => d.data() as Map<String, dynamic>,
                )
                .toList();

            // STATISTICS
            final activeJobs = allData.where((data) {
              final status = data['status'];
              return status != 'Completed' &&
                  status != 'Declined';
            }).length;

            final today = DateTime.now();

            bool isToday(Timestamp? timestamp) {
              if (timestamp == null) return false;

              final date = timestamp.toDate();

              return date.year == today.year &&
                  date.month == today.month &&
                  date.day == today.day;
            }

            final completedToday = allData.where((data) {
              return data['status'] == 'Completed' &&
                  isToday(data['updatedAt'] as Timestamp?);
            }).length;

            final pendingCount = allData
                .where((data) => data['status'] == 'Pending')
                .length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // STAT CARDS
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cards = [
                      _StatCard(
                        title: 'Active Jobs',
                        value: '$activeJobs',
                        icon: Icons.work_outline_rounded,
                      ),

                      StreamBuilder<QuerySnapshot>(
                        stream: firestoreService.streamTechnicians(),
                        builder: (context, techSnapshot) {
                          final count =
                              techSnapshot.data?.docs.length ?? 0;

                          return _StatCard(
                            title: 'Technicians',
                            value: '$count',
                            icon: Icons.person_outline_rounded,
                          );
                        },
                      ),

                      _StatCard(
                        title: 'Complete Today',
                        value: '$completedToday',
                        icon: Icons.check_circle_outline_rounded,
                        iconSuccess: true,
                      ),

                      _StatCard(
                        title: 'Pending Requests',
                        value: '$pendingCount',
                        icon: Icons.pending_actions_outlined,
                      ),
                    ];

                    if (constraints.maxWidth >= 700) {
                      return Row(
                        children: cards.map(
                          (card) {
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                child: card,
                              ),
                            );
                          },
                        ).toList(),
                      );
                    }

                    return GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics:
                          const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.9,
                      children: cards,
                    );
                  },
                ),

                const SizedBox(height: 26),

                // TECHNICIANS + RECENT ACTIVITY
                LayoutBuilder(
                  builder: (context, constraints) {
                    final techniciansPanel =
                        _TechnicianStatusPanel(
                      allRequests: allData,
                    );

                    final activityPanel =
                        _RecentActivityPanel(
                      docs: docs.take(8).toList(),
                    );

                    if (constraints.maxWidth >= 850) {
                      return IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              flex: 4,
                              child: techniciansPanel,
                            ),

                            const SizedBox(width: 16),

                            Expanded(
                              flex: 6,
                              child: activityPanel,
                            ),
                          ],
                        ),
                      );
                    }

                    return Column(
                      children: [
                        techniciansPanel,
                        const SizedBox(height: 16),
                        activityPanel,
                      ],
                    );
                  },
                ),

                const SizedBox(height: 22),

                // REPAIR TREND + TODAY'S SCHEDULE
                LayoutBuilder(
                  builder: (context, constraints) {
                    final trendPanel =
                        _RepairTrendPanel(
                      allRequests: allData,
                    );

                    final schedulePanel =
                        _TodayScheduleCard(
                      allRequests: allData,
                    );

                    if (constraints.maxWidth >= 850) {
                      return IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              flex: 6,
                              child: trendPanel,
                            ),

                            const SizedBox(width: 16),

                            Expanded(
                              flex: 4,
                              child: schedulePanel,
                            ),
                          ],
                        ),
                      );
                    }

                    return Column(
                      children: [
                        trendPanel,
                        const SizedBox(height: 16),
                        schedulePanel,
                      ],
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// STAT CARD

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final bool iconSuccess;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    this.iconSuccess = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 112,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFBDBDBD),
        ),
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
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),

              const Spacer(),

              Text(
                value,
                style: const TextStyle(
                  fontSize: 42,
                  height: 1,
                  fontWeight: FontWeight.w400,
                  color: Colors.black,
                ),
              ),
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
                border: Border.all(
                  color: iconSuccess
                      ? Colors.green
                      : Colors.black,
                  width: 1.5,
                ),
              ),
              child: Icon(
                icon,
                size: 17,
                color: iconSuccess
                    ? Colors.green
                    : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// COMMON PANEL

class _DashboardPanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _DashboardPanel({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: const Color(0xFFBDBDBD),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),

          const SizedBox(height: 2),

          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF666666),
            ),
          ),

          const SizedBox(height: 10),

          Expanded(
            child: child,
          ),
        ],
      ),
    );
  }
}

// TECHNICIAN STATUS

class _TechnicianStatusPanel extends StatelessWidget {
  final List<Map<String, dynamic>> allRequests;

  const _TechnicianStatusPanel({
    required this.allRequests,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: const Color(0xFFBDBDBD),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Technicians Status',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),

          const SizedBox(height: 2),

          const Text(
            'Current active jobs load per technicians',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF666666),
            ),
          ),

          const SizedBox(height: 10),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirestoreService().streamTechnicians(),
              builder: (context, snapshot) {
                final technicians =
                    snapshot.data?.docs ?? [];

                if (technicians.isEmpty) {
                  return const Center(
                    child: Text(
                      'No technicians yet.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF777777),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: technicians.length,
                  itemBuilder: (context, index) {
                    final doc = technicians[index];

                    final data =
                        doc.data()
                            as Map<String, dynamic>;

                    final name =
                        data['name'] ?? '';

                    final assignedJobs =
                        allRequests.where((request) {
                      return request[
                                  'assignedTechnician'] ==
                              name &&
                          request['status'] !=
                              'Completed' &&
                          request['status'] !=
                              'Declined';
                    }).toList();

                    String location =
                        'Available';

                    Color locationColor =
                        Colors.green;

                    Color locationBackground =
                        const Color(0xFFD9F8E4);

                    if (assignedJobs.isNotEmpty) {
                      final status =
                          assignedJobs.first[
                              'status'];

                      if (status == 'In Home') {
                        location = 'In Home';
                        locationColor =
                            const Color(0xFF5B21B6);
                        locationBackground =
                            const Color(0xFFEBDDFF);
                      } else if (status ==
                          'In Shop') {
                        location = 'In Shop';
                        locationColor =
                            const Color(0xFF1565C0);
                        locationBackground =
                            const Color(0xFFDDEEFF);
                      } else {
                        location =
                            status ?? 'Assigned';
                        locationColor =
                            Colors.black;
                        locationBackground =
                            const Color(0xFFEFEFEF);
                      }
                    }

                    return Padding(
                      padding:
                          const EdgeInsets.only(
                        bottom: 9,
                      ),
                      child: Row(
                        children: [
                          // Avatar
                          Container(
                            width: 32,
                            height: 32,
                            decoration:
                                const BoxDecoration(
                              color: Colors.black,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                name.isNotEmpty
                                    ? name[0]
                                        .toUpperCase()
                                    : '?',
                                style:
                                    const TextStyle(
                                  fontSize: 13,
                                  fontWeight:
                                      FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 9),

                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,
                              children: [
                                Text(
                                  name,
                                  maxLines: 1,
                                  overflow:
                                      TextOverflow
                                          .ellipsis,
                                  style:
                                      const TextStyle(
                                    fontSize: 11,
                                    fontWeight:
                                        FontWeight.w700,
                                    color:
                                        Colors.black,
                                  ),
                                ),

                                Text(
                                  '${assignedJobs.length} job(s) assigned',
                                  style:
                                      const TextStyle(
                                    fontSize: 11,
                                    color:
                                        Color(0xFF777777),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Container(
                            padding:
                                const EdgeInsets
                                    .symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration:
                                BoxDecoration(
                              color:
                                  locationBackground,
                              borderRadius:
                                  BorderRadius
                                      .circular(10),
                            ),
                            child: Text(
                              location,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight:
                                    FontWeight.w700,
                                color:
                                    locationColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// RECENT ACTIVITY

class _RecentActivityPanel extends StatelessWidget {
  final List<QueryDocumentSnapshot> docs;

  const _RecentActivityPanel({
    required this.docs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: const Color(0xFFBDBDBD),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Activity',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),

          const SizedBox(height: 2),

          Text(
            'Latest ${docs.length} repair requests',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF666666),
            ),
          ),

          const SizedBox(height: 10),

          // Header
          const Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  'Tracking ID',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'Appliance Type',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Assign Tech.',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ),
              SizedBox(
                width: 72,
                child: Text(
                  'Status',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          Expanded(
            child: docs.isEmpty
                ? const Center(
                    child: Text(
                      'No requests yet.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF777777),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data =
                          docs[index].data()
                              as Map<String, dynamic>;

                      final status =
                          data['status'] ??
                              'Pending';

                      final colors =
                          _statusColors(status);

                      return Padding(
                        padding:
                            const EdgeInsets.only(
                          bottom: 7,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                data['trackingId'] ??
                                    '',
                                maxLines: 1,
                                overflow:
                                    TextOverflow
                                        .ellipsis,
                                style:
                                    const TextStyle(
                                  fontSize: 11,
                                  fontWeight:
                                      FontWeight.w600,
                                  color: Colors.black,
                                ),
                              ),
                            ),

                            Expanded(
                              flex: 3,
                              child: Text(
                                data['applianceType'] ??
                                    '',
                                maxLines: 1,
                                overflow:
                                    TextOverflow
                                        .ellipsis,
                                style:
                                    const TextStyle(
                                  fontSize: 11,
                                  color:
                                      Color(0xFF555555),
                                ),
                              ),
                            ),

                            Expanded(
                              flex: 2,
                              child: Text(
                                data[
                                        'assignedTechnician'] ??
                                    '—',
                                maxLines: 1,
                                overflow:
                                    TextOverflow
                                        .ellipsis,
                                style:
                                    const TextStyle(
                                  fontSize: 11,
                                  color:
                                      Color(0xFF555555),
                                ),
                              ),
                            ),

                            SizedBox(
                              width: 72,
                              child: Align(
                                alignment:
                                    Alignment.centerLeft,
                                child: Container(
                                  padding:
                                      const EdgeInsets
                                          .symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration:
                                      BoxDecoration(
                                    color: colors.$1,
                                    borderRadius:
                                        BorderRadius
                                            .circular(
                                      10,
                                    ),
                                  ),
                                  child: Text(
                                    status,
                                    maxLines: 1,
                                    overflow:
                                        TextOverflow
                                            .ellipsis,
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight:
                                          FontWeight.w700,
                                      color:
                                          colors.$2,
                                    ),
                                  ),
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

// REPAIR TREND

class _RepairTrendPanel extends StatelessWidget {
  final List<Map<String, dynamic>> allRequests;

  const _RepairTrendPanel({
    required this.allRequests,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    const weekdays = [
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ];

    final monday = now.subtract(
      Duration(days: now.weekday - 1),
    );

    final dayCounts = <int>[];

    for (int i = 0; i < 7; i++) {
      final day = monday.add(
        Duration(days: i),
      );

      final count = allRequests.where((data) {
        if (data['status'] != 'Completed') {
          return false;
        }

        final timestamp =
            data['updatedAt'] as Timestamp?;

        if (timestamp == null) {
          return false;
        }

        final date = timestamp.toDate();

        return date.year == day.year &&
            date.month == day.month &&
            date.day == day.day;
      }).length;

      dayCounts.add(count);
    }

    final maxCount = dayCounts.isEmpty
        ? 1
        : dayCounts.reduce(
            (a, b) => a > b ? a : b,
          );

    final safeMax =
        maxCount < 1 ? 1 : maxCount;

    return Container(
      height: 250,
      padding: const EdgeInsets.fromLTRB(
        12,
        10,
        12,
        10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: const Color(0xFFBDBDBD),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Repair Trend',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),

          const Text(
            'Repair completed per day, last 7 days',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF666666),
            ),
          ),

          const SizedBox(height: 8),

          Expanded(
            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment.end,
              children: List.generate(
                7,
                (index) {
                  final barHeight =
                      (dayCounts[index] /
                              safeMax) *
                          70;

                  return Expanded(
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 6,
                      ),
                      child: Column(
                        mainAxisAlignment:
                            MainAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${dayCounts[index]}',
                            style:
                                const TextStyle(
                              fontSize: 11,
                              color:
                                  Colors.blue,
                              fontWeight:
                                  FontWeight.w500,
                            ),
                          ),

                          const SizedBox(height: 3),

                          Container(
                            width: double.infinity,
                            height: barHeight < 3
                                ? 3
                                : barHeight,
                            decoration:
                                BoxDecoration(
                              color:
                                  const Color(
                                0xFFD5D5D5,
                              ),
                              borderRadius:
                                  BorderRadius.circular(
                                5,
                              ),
                            ),
                          ),

                          const SizedBox(height: 5),

                          Text(
                            weekdays[index],
                            style:
                                const TextStyle(
                              fontSize: 12,
                              fontWeight:
                                  FontWeight.w600,
                              color:
                                  Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// TODAY'S SCHEDULE
class _TodayScheduleCard extends StatelessWidget {
  final List<Map<String, dynamic>> allRequests;

  const _TodayScheduleCard({
    required this.allRequests,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    bool isToday(DateTime date) {
      return date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    }

    final todayJobs =
        allRequests.where((data) {
      final timestamp =
          data['scheduledVisit']
              as Timestamp?;

      if (timestamp == null) {
        return false;
      }

      return isToday(timestamp.toDate());
    }).toList();

    todayJobs.sort((a, b) {
      final aDate =
          (a['scheduledVisit'] as Timestamp)
              .toDate();

      final bDate =
          (b['scheduledVisit'] as Timestamp)
              .toDate();

      return aDate.compareTo(bDate);
    });

    return Container(
      height: 250,
      padding: const EdgeInsets.fromLTRB(
        12,
        10,
        12,
        10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: const Color(0xFFBDBDBD),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            "Today's Schedule",
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),

          const Text(
            'Schedule for home visit',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF666666),
            ),
          ),

          const SizedBox(height: 9),

          // Table header
          const Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  'Technicians',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                flex: 5,
                child: Text(
                  'Customer Address',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'Date & Time',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          Expanded(
            child: todayJobs.isEmpty
                ? const Center(
                    child: Text(
                      'No home visits scheduled today.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF777777),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: todayJobs.length,
                    itemBuilder: (context, index) {
                      final data =
                          todayJobs[index];

                      final timestamp =
                          data['scheduledVisit']
                              as Timestamp;

                      final date =
                          timestamp.toDate();

                      final hour =
                          date.hour % 12 == 0
                              ? 12
                              : date.hour % 12;

                      final ampm =
                          date.hour >= 12
                              ? 'PM'
                              : 'AM';

                      final time =
                          '$hour:${date.minute.toString().padLeft(2, '0')} $ampm';

                      final technician =
                          data[
                                  'assignedTechnician'] ??
                              'Unassigned';

                      final address =
                          data['address'] ??
                              data[
                                  'customerAddress'] ??
                              '';

                      return Padding(
                        padding:
                            const EdgeInsets.only(
                          bottom: 8,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                technician,
                                maxLines: 1,
                                overflow:
                                    TextOverflow
                                        .ellipsis,
                                style:
                                    const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight:
                                      FontWeight.w600,
                                ),
                              ),
                            ),

                            Expanded(
                              flex: 5,
                              child: Text(
                                address,
                                maxLines: 1,
                                overflow:
                                    TextOverflow
                                        .ellipsis,
                                style:
                                    const TextStyle(
                                  fontSize: 10.5,
                                  color:
                                      Color(0xFF555555),
                                ),
                              ),
                            ),

                            Expanded(
                              flex: 3,
                              child: Text(
                                time,
                                maxLines: 1,
                                overflow:
                                    TextOverflow
                                        .ellipsis,
                                style:
                                    const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight:
                                      FontWeight.w600,
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

// STATUS COLORS

(Color, Color) _statusColors(String status) {
  switch (status) {
    case 'New Request':
      return (
        const Color(0xFFFFE8D6),
        const Color(0xFFEA580C),
      );

    case 'In Home':
      return (
        const Color(0xFFE8D8FF),
        const Color(0xFF6D28D9),
      );

    case 'In Shop':
      return (
        const Color(0xFFDCEEFF),
        const Color(0xFF1565C0),
      );

    case 'Completed':
      return (
        const Color(0xFFD9F8E4),
        const Color(0xFF16A34A),
      );

    case 'Cancelled':
    case 'Declined':
      return (
        const Color(0xFFFFDDDD),
        const Color(0xFFDC2626),
      );

    default:
      return (
        const Color(0xFFEFEFEF),
        const Color(0xFF444444),
      );
  }
}