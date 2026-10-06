import 'package:flutter/material.dart';
import '../services/job_decline_service.dart';
import '../utils/colors.dart';

class DeclineChoice {
  final String reason;
  final String note;
  const DeclineChoice(this.reason, this.note);
}

/// Asks the technician why they are declining. Returns null if cancelled.
Future<DeclineChoice?> showDeclineJobDialog(
  BuildContext context, {
  required int declinesLeft,
}) {
  return showDialog<DeclineChoice>(
    context: context,
    builder: (_) => _DeclineDialog(declinesLeft: declinesLeft),
  );
}

class _DeclineDialog extends StatefulWidget {
  final int declinesLeft;
  const _DeclineDialog({required this.declinesLeft});

  @override
  State<_DeclineDialog> createState() => _DeclineDialogState();
}

class _DeclineDialogState extends State<_DeclineDialog> {
  String? _reason;
  final _note = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    if (_reason == null) {
      setState(() => _error = 'Please pick a reason.');
      return;
    }
    if (_reason == 'Other' && _note.text.trim().isEmpty) {
      setState(() => _error = 'Please tell us the reason.');
      return;
    }
    Navigator.pop(context, DeclineChoice(_reason!, _note.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Decline this job?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The job will be handed to the next available technician, '
              'or back to Admin if nobody is free.',
              style: TextStyle(fontSize: 13, color: AppColors.textGray),
            ),
            const SizedBox(height: 4),
            Text(
              'Declines left this week: ${widget.declinesLeft} of '
              '$kMaxDeclinesPerWeek',
              style: const TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            for (final r in kDeclineReasons)
              RadioListTile<String>(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: r,
                groupValue: _reason,
                onChanged: (v) => setState(() {
                  _reason = v;
                  _error = null;
                }),
                title: Text(r, style: const TextStyle(fontSize: 14)),
              ),
            TextField(
              controller: _note,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: _reason == 'Other'
                    ? 'Reason (required)'
                    : 'Note for Admin (optional)',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style: const TextStyle(
                      color: AppColors.danger, fontSize: 12.5)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
          ),
          child: const Text('Decline Job'),
        ),
      ],
    );
  }
}
