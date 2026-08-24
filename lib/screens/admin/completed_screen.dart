import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firestore_service.dart';
import 'admin_theme.dart';
import 'requests_screen.dart' show buildRequestCard;

/// ── Completed Page ───────────────────────────────────────────────
/// Standalone sidebar section (separate from Repair Request) that
/// lists every repair request whose status is "Completed". Reuses
/// buildRequestCard from requests_screen.dart so the card look, QR
/// button, and "I-update" tap behavior stay identical to the ones in
/// the Repair Request screen.
class CompletedScreen extends StatelessWidget {
  const CompletedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();

    return StreamBuilder<QuerySnapshot>(
      stream: firestoreService.streamRepairRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final allDocs = snapshot.data?.docs ?? [];

        final completedDocs = allDocs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          return data['status'] == 'Completed';
        }).toList();

        if (completedDocs.isEmpty) {
          return const Center(
            child: Text(
              'No completed repairs yet.',
              style: TextStyle(color: kAdminTextGray),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: completedDocs.length,
          itemBuilder: (context, index) {
            final doc = completedDocs[index];
            final data = doc.data() as Map<String, dynamic>;
            return buildRequestCard(context, doc.id, data);
          },
        );
      },
    );
  }
}
