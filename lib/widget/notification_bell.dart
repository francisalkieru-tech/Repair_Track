import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../utils/colors.dart';


class NotificationBell extends StatelessWidget {
  final String recipientType; 
  final String? recipientId; 
  final Color iconColor;

  const NotificationBell({
    super.key,
    required this.recipientType,
    this.recipientId,
    this.iconColor = Colors.black87,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreService().streamNotifications(
        recipientType: recipientType,
        recipientId: recipientId,
      ),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final unread = docs.where((d) => d.data()['read'] != true).length;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: Icon(Icons.notifications_outlined, color: iconColor),
              tooltip: 'Notifications',
              onPressed: () => _openList(context, docs),
            ),
            if (unread > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  constraints: const BoxConstraints(minWidth: 18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: Colors.white, width: 1.2),
                  ),
                  child: Text(
                    unread > 99 ? '99+' : '$unread',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _openList(
      BuildContext context, List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final sorted = [...docs]..sort((a, b) {
        final at = a.data()['timestamp'] as Timestamp?;
        final bt = b.data()['timestamp'] as Timestamp?;
        return (bt ?? Timestamp(0, 0)).compareTo(at ?? Timestamp(0, 0));
      });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Notifications',
                    style: const TextStyle(
                        fontSize: AppColors.fontBody,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: sorted.isEmpty
                      ? const Center(
                          child: Text('No notifications yet.',
                              style:
                                  TextStyle(color: AppColors.textGray)),
                        )
                      : ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: sorted.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final doc = sorted[index];
                            final data = doc.data();
                            final isRead = data['read'] == true;
                            final title = data['title'] as String? ?? '';
                            final body = data['body'] as String? ?? '';
                            final ts = data['timestamp'] as Timestamp?;

                            return ListTile(
                              tileColor: isRead
                                  ? null
                                  : const Color(0xFFEFF6FF),
                              leading: Icon(
                                Icons.notifications_none,
                                color: isRead
                                    ? AppColors.textGray
                                    : const Color(0xFF1D4ED8),
                              ),
                              title: Text(
                                title,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: isRead
                                      ? FontWeight.normal
                                      : FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(body,
                                  style: const TextStyle(fontSize: 12.5)),
                              trailing: ts != null
                                  ? Text(
                                      _relativeTime(ts.toDate()),
                                      style: const TextStyle(
                                          fontSize: 10.5,
                                          color: AppColors.textGray),
                                    )
                                  : null,
                              onTap: () {
                                if (!isRead) {
                                  FirestoreService()
                                      .markNotificationRead(doc.id);
                                }
                              },
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _relativeTime(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}
