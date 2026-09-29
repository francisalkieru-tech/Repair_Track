import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../utils/colors.dart';

int _unreadCountFor({
  required Map<String, dynamic>? chatData,
  required String otherAuthor,
  required String lastReadField,
}) {
  if (chatData == null) return 0;
  final messages = (chatData['messages'] as List?) ?? const [];
  final lastRead = chatData[lastReadField] as Timestamp?;
  return messages.where((m) {
    final msg = m as Map;
    if (msg['author'] != otherAuthor) return false;
    final ts = msg['timestamp'] as Timestamp?;
    if (ts == null) return false;
    return lastRead == null || ts.compareTo(lastRead) > 0;
  }).length;
}

class AdminChatBubble extends StatefulWidget {
  const AdminChatBubble({super.key});

  @override
  State<AdminChatBubble> createState() => _AdminChatBubbleState();
}

class _AdminChatBubbleState extends State<AdminChatBubble> {
  bool _open = false;
  String? _selectedTechId;
  String? _selectedTechName;

  void _toggle() => setState(() => _open = !_open);

  void _openTech(String id, String name) {
    setState(() {
      _selectedTechId = id;
      _selectedTechName = name;
    });
    FirestoreService().markChatRead(technicianDocId: id, reader: 'admin');
  }

  void _backToList() => setState(() => _selectedTechId = null);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      bottom: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_open)
            _ChatPanel(
              title: _selectedTechId == null
                  ? 'Chat with Technician'
                  : _selectedTechName ?? '',
              onClose: _toggle,
              onBack: _selectedTechId == null ? null : _backToList,
              body: _selectedTechId == null
                  ? _TechnicianPickerList(onPick: _openTech)
                  : _ChatThread(
                      technicianDocId: _selectedTechId!,
                      currentAuthor: 'admin',
                      currentAuthorName: 'Admin',
                    ),
            ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirestoreService().streamAllChats(),
            builder: (context, snapshot) {
              var total = 0;
              for (final doc in snapshot.data?.docs ?? []) {
                total += _unreadCountFor(
                  chatData: doc.data(),
                  otherAuthor: 'technician',
                  lastReadField: 'adminLastRead',
                );
              }
              return _BubbleButton(
                  open: _open, onTap: _toggle, unreadCount: total);
            },
          ),
        ],
      ),
    );
  }
}

class TechnicianChatBubble extends StatefulWidget {
  final String technicianDocId;
  final String technicianName;

  const TechnicianChatBubble({
    super.key,
    required this.technicianDocId,
    required this.technicianName,
  });

  @override
  State<TechnicianChatBubble> createState() => _TechnicianChatBubbleState();
}

class _TechnicianChatBubbleState extends State<TechnicianChatBubble> {
  bool _open = false;

  void _toggle() {
    setState(() => _open = !_open);
    if (_open) {
      FirestoreService().markChatRead(
        technicianDocId: widget.technicianDocId,
        reader: 'technician',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      bottom: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_open)
            _ChatPanel(
              title: 'Chat with Admin',
              onClose: _toggle,
              body: _ChatThread(
                technicianDocId: widget.technicianDocId,
                currentAuthor: 'technician',
                currentAuthorName: widget.technicianName,
              ),
            ),
          const SizedBox(height: 12),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirestoreService().streamChat(widget.technicianDocId),
            builder: (context, snapshot) {
              final unread = _unreadCountFor(
                chatData: snapshot.data?.data(),
                otherAuthor: 'admin',
                lastReadField: 'technicianLastRead',
              );
              return _BubbleButton(
                  open: _open, onTap: _toggle, unreadCount: unread);
            },
          ),
        ],
      ),
    );
  }
}

class _BubbleButton extends StatelessWidget {
  final bool open;
  final VoidCallback onTap;
  final int unreadCount;
  const _BubbleButton({
    required this.open,
    required this.onTap,
    this.unreadCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: AppColors.dark,
          shape: const CircleBorder(),
          elevation: 4,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 56,
              height: 56,
              child: Icon(
                open ? Icons.close : Icons.chat_bubble_outline,
                color: Colors.white,
              ),
            ),
          ),
        ),
        if (!open && unreadCount > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              constraints: const BoxConstraints(minWidth: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Text(
                unreadCount > 99 ? '99+' : '$unreadCount',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// The floating panel frame — title bar (with optional back button for
// Admin's picker-to-thread transition) + close button + body.
class _ChatPanel extends StatelessWidget {
  final String title;
  final VoidCallback onClose;
  final VoidCallback? onBack;
  final Widget body;

  const _ChatPanel({
    required this.title,
    required this.onClose,
    required this.body,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width < 380
        ? MediaQuery.of(context).size.width - 32
        : 320.0;

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: width,
        height: 420,
        color: Colors.white,
        child: Column(
          children: [
            Container(
              color: AppColors.dark,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  if (onBack != null)
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: onBack,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      iconSize: 20,
                    )
                  else
                    const SizedBox(width: 12),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: AppColors.fontLabel,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: onClose,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    iconSize: 20,
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

class _TechnicianPickerList extends StatelessWidget {
  final void Function(String id, String name) onPick;
  const _TechnicianPickerList({required this.onPick});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreService().streamTechnicians(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No technicians yet.',
                  style: TextStyle(color: AppColors.textGray)),
            ),
          );
        }
        // Nested so each row can show its own unread count without a
        // separate query per technician.
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirestoreService().streamAllChats(),
          builder: (context, chatsSnapshot) {
            final chatsByTechId = {
              for (final doc in chatsSnapshot.data?.docs ?? [])
                doc.id: doc.data(),
            };

            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final techId = docs[index].id;
                final data = docs[index].data() as Map<String, dynamic>;
                final name = data['name'] as String? ?? 'Technician';
                final lastSeen = data['lastSeen'] as Timestamp?;
                // Treat "active within the last 2 minutes" as online —
                // see updateTechnicianPresence() in
                // firestore_service.dart for why this is an
                // approximation rather than a real-time presence
                // system.
                final isOnline = lastSeen != null &&
                    DateTime.now().difference(lastSeen.toDate()) <
                        const Duration(minutes: 2);
                final unread = _unreadCountFor(
                  chatData: chatsByTechId[techId],
                  otherAuthor: 'technician',
                  lastReadField: 'adminLastRead',
                );

                return ListTile(
                  dense: true,
                  leading: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.dark,
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13),
                        ),
                      ),
                      Positioned(
                        right: -1,
                        bottom: -1,
                        child: Container(
                          width: 11,
                          height: 11,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isOnline
                                ? const Color(0xFF22C55E)
                                : const Color(0xFFD1D5DB),
                            border:
                                Border.all(color: Colors.white, width: 1.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                  title: Text(name, style: const TextStyle(fontSize: 14)),
                  subtitle: Text(
                    isOnline ? 'Online' : 'Offline',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isOnline
                          ? const Color(0xFF16A34A)
                          : AppColors.textGray,
                    ),
                  ),
                  trailing: unread > 0
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDC2626),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            unread > 99 ? '99+' : '$unread',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      : null,
                  onTap: () => onPick(techId, name),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _ChatThread extends StatefulWidget {
  final String technicianDocId;
  final String currentAuthor; // 'admin' or 'technician'
  final String currentAuthorName;

  const _ChatThread({
    required this.technicianDocId,
    required this.currentAuthor,
    required this.currentAuthorName,
  });

  @override
  State<_ChatThread> createState() => _ChatThreadState();
}

class _ChatThreadState extends State<_ChatThread> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);
    try {
      await FirestoreService().sendChatMessage(
        technicianDocId: widget.technicianDocId,
        author: widget.currentAuthor,
        authorName: widget.currentAuthorName,
        text: text,
      );
      _controller.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  String _formatTimestamp(Timestamp ts) {
    final d = ts.toDate();
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    final min = d.minute.toString().padLeft(2, '0');
    return '$h:$min $ampm';
  }

  @override
  Widget build(BuildContext context) {
    // Opening a thread marks it read (see the two bubbles' onTap/toggle
    // handlers), but a NEW message can still arrive while the thread is
    // already open — mark read again on every stream update so the
    // badge doesn't come back once they close the panel.
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirestoreService().streamChat(widget.technicianDocId),
            builder: (context, snapshot) {
              final messages =
                  (snapshot.data?.data()?['messages'] as List?) ?? const [];

              if (messages.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  FirestoreService().markChatRead(
                    technicianDocId: widget.technicianDocId,
                    reader: widget.currentAuthor,
                  );
                });
              }

              if (messages.isEmpty) {
                return const Center(
                  child: Text('No messages yet — say hi!',
                      style: TextStyle(
                          fontSize: 12.5, color: AppColors.textGray)),
                );
              }

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_scrollController.hasClients) {
                  _scrollController.jumpTo(
                      _scrollController.position.maxScrollExtent);
                }
              });

              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(10),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final m = messages[index] as Map;
                  final author = m['author'] as String? ?? '';
                  final text = m['text'] as String? ?? '';
                  final ts = m['timestamp'] as Timestamp?;
                  final isMine = author == widget.currentAuthor;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Align(
                      alignment: isMine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 220),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isMine
                              ? AppColors.dark
                              : const Color(0xFFF1F1F1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              text,
                              style: TextStyle(
                                fontSize: 13,
                                color: isMine ? Colors.white : Colors.black87,
                              ),
                            ),
                            if (ts != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                _formatTimestamp(ts),
                                style: TextStyle(
                                  fontSize: 9,
                                  color: isMine
                                      ? Colors.white.withValues(alpha: 0.6)
                                      : AppColors.textGray,
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
          ),
        ),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 3,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Message…',
                    hintStyle: const TextStyle(fontSize: 13),
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 6),
              _isSending
                  ? const SizedBox(
                      width: 32,
                      height: 32,
                      child: Padding(
                        padding: EdgeInsets.all(6),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.send, size: 20),
                      color: AppColors.dark,
                      onPressed: _send,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
            ],
          ),
        ),
      ],
    );
  }
}
