import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firestore_service.dart';
import 'admin_theme.dart';

//Technicians Page
class TechniciansScreen extends StatefulWidget {
  const TechniciansScreen({super.key});

  @override
  State<TechniciansScreen> createState() => _TechniciansScreenState();
}

class _TechniciansScreenState extends State<TechniciansScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  Future<void> _showAddTechnicianDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Add New Technician'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. Juan Dela Cruz',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: kAdminBrand,
              foregroundColor: Colors.white,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await _firestoreService.addTechnician(result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"$result" added as a technician.')),
        );
      }
    }
  }

  Future<void> _deleteTechnician(String docId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Remove Technician?'),
        content: Text(
          '"$name" will be removed from your technician list. Existing '
          'repair records assigned to them will not be affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseFirestore.instance
          .collection('technicians')
          .doc(docId)
          .delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"$name" removed.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Manage your repair technicians',
                style: TextStyle(fontSize: 13, color: kAdminTextGray),
              ),
              ElevatedButton.icon(
                onPressed: _showAddTechnicianDialog,
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: const Text('Add Technician'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kAdminBrand,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestoreService.streamRepairRequests(),
              builder: (context, requestsSnap) {
                final allData = (requestsSnap.data?.docs ?? [])
                    .map((d) => d.data() as Map<String, dynamic>)
                    .toList();

                return StreamBuilder<QuerySnapshot>(
                  stream: _firestoreService.streamTechnicians(),
                  builder: (context, techSnap) {
                    if (techSnap.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator());
                    }
                    final techs = techSnap.data?.docs ?? [];
                    if (techs.isEmpty) {
                      return const Center(
                        child: Text(
                          'No technicians yet. Tap "Add Technician" '
                          'to add one.',
                          style: TextStyle(color: kAdminTextGray),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final crossAxisCount =
                            (constraints.maxWidth / 320).floor().clamp(1, 4);
                        return GridView.builder(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 1.6,
                          ),
                          itemCount: techs.length,
                          itemBuilder: (context, index) {
                            final doc = techs[index];
                            final data = doc.data() as Map<String, dynamic>;
                            final name = data['name'] ?? '';

                            final assignedJobs = allData.where((r) {
                              return r['assignedTechnician'] == name &&
                                  r['status'] != 'Completed' &&
                                  r['status'] != 'Declined';
                            }).toList();

                            final completedJobs = allData.where((r) {
                              return r['assignedTechnician'] == name &&
                                  r['status'] == 'Completed';
                            }).length;

                            String currentLocation = 'Available';
                            Color locColor = const Color(0xFF16A34A);
                            Color locBg = const Color(0xFF16A34A)
                                .withValues(alpha: .1);
                            if (assignedJobs.isNotEmpty) {
                              final currentStatus =
                                  assignedJobs.first['status'];
                              if (currentStatus == 'In Home') {
                                currentLocation = 'In Home';
                                locColor = const Color(0xFF5B21B6);
                                locBg = const Color(0xFF5B21B6)
                                    .withValues(alpha: .1);
                              } else if (currentStatus == 'In Shop') {
                                currentLocation = 'In Shop';
                                locColor = const Color(0xFF1565C0);
                                locBg = const Color(0xFF1565C0)
                                    .withValues(alpha: .1);
                              } else {
                                currentLocation = currentStatus ?? 'Assigned';
                                locColor = kAdminTextGray;
                                locBg = const Color(0xFFF3F4F6);
                              }
                            }

                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: kAdminCardBorder),
                              ),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundColor:
                                            kAdminBrand.withValues(alpha: 0.1),
                                        child: Text(
                                          name.isNotEmpty
                                              ? name[0].toUpperCase()
                                              : '?',
                                          style: const TextStyle(
                                            color: kAdminBrand,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          name,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: kAdminTextDark,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                            Icons.delete_outline_rounded,
                                            size: 20),
                                        color: const Color(0xFFDC2626),
                                        visualDensity: VisualDensity.compact,
                                        tooltip: 'Remove technician',
                                        onPressed: () => _deleteTechnician(
                                            doc.id, name),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _MiniStat(
                                          label: 'Assigned',
                                          value: '${assignedJobs.length}',
                                        ),
                                      ),
                                      Expanded(
                                        child: _MiniStat(
                                          label: 'Completed',
                                          value: '$completedJobs',
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 6),
                                    decoration: BoxDecoration(
                                      color: locBg,
                                      borderRadius:
                                          BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      currentLocation,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: locColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
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

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: kAdminTextDark,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: kAdminTextGray),
        ),
      ],
    );
  }
}

