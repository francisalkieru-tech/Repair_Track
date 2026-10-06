import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/colors.dart';
import '../../utils/constants.dart';
import '../../utils/report_data.dart';
import '../../utils/technician_availability.dart';
import '../../utils/technician_profile.dart';
import '../../widget/technician_resume_screen.dart';

/// Where a technician fills in their resume: experience, what appliances
/// they specialize in, and certificates (TESDA NC II, trainings...).
/// The system uses the specializations to give them matching jobs first.
class TechnicianCredentialsScreen extends StatefulWidget {
  final String technicianDocId;
  const TechnicianCredentialsScreen({super.key, required this.technicianDocId});

  @override
  State<TechnicianCredentialsScreen> createState() =>
      _TechnicianCredentialsScreenState();
}

class _TechnicianCredentialsScreenState
    extends State<TechnicianCredentialsScreen> {
  final _bio = TextEditingController();
  final _years = TextEditingController();
  final Set<String> _specs = {};
  List<TechCertification> _certs = [];
  bool _loading = true;
  bool _saving = false;

  DocumentReference<Map<String, dynamic>> get _ref => FirebaseFirestore.instance
      .collection('technicians')
      .doc(widget.technicianDocId);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _bio.dispose();
    _years.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final doc = await _ref.get();
    final data = doc.data() ?? {};
    if (!mounted) return;
    setState(() {
      _bio.text = (data['bio'] ?? '') as String;
      final y = data['yearsExperience'];
      _years.text = y is num && y > 0 ? '${y.toInt()}' : '';
      _specs
        ..clear()
        ..addAll(technicianSpecializations(data));
      _certs = technicianCertifications(data);
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final specs = _specs.toList()..sort();
      await _ref.update({
        'bio': _bio.text.trim(),
        'yearsExperience': int.tryParse(_years.text.trim()) ?? 0,
        'specializations': specs,
        // Keep the old free-text field in sync so older screens still work.
        'specialization': specs.join(', '),
        'certifications': _certs.map((c) => c.toMap()).toList(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Credentials saved.'),
        backgroundColor: AppColors.success,
      ));
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not save: $e'),
          backgroundColor: AppColors.danger,
        ));
      }
    }
  }

  Future<void> _editCert([int? index]) async {
    final result = await showDialog<TechCertification>(
      context: context,
      builder: (_) => _CertDialog(existing: index == null ? null : _certs[index]),
    );
    if (result == null) return;
    setState(() {
      if (index == null) {
        _certs.add(result);
      } else {
        _certs[index] = result;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Appliance types plus anything custom already on the profile.
    final options = <String>{...AppConstants.applianceTypes, ..._specs}.toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        title: const Text('My Credentials'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TechnicianResumeScreen(
                    technicianDocId: widget.technicianDocId),
              ),
            ),
            icon: const Icon(Icons.badge_outlined, size: 18),
            label: const Text('View resume'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _box('About you', Column(children: [
                        TextField(
                          controller: _bio,
                          maxLines: 3,
                          maxLength: 300,
                          decoration: const InputDecoration(
                            labelText: 'Short bio',
                            hintText: 'e.g. Aircon and refrigerator technician...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _years,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Years of experience',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ])),
                      _box(
                        'Specializations',
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Pick the appliances you can repair. You will be '
                              'given these jobs first.',
                              style: TextStyle(
                                  fontSize: 12.5, color: AppColors.textGray),
                            ),
                            const SizedBox(height: 10),
                            Wrap(spacing: 8, runSpacing: 8, children: [
                              for (final o in options)
                                FilterChip(
                                  label: Text(o),
                                  selected: _specs.contains(o),
                                  onSelected: (v) => setState(() =>
                                      v ? _specs.add(o) : _specs.remove(o)),
                                ),
                            ]),
                          ],
                        ),
                      ),
                      _box(
                        'Certifications & Training',
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Add your TESDA NC II and other certificates. '
                              'Admin will verify them.',
                              style: TextStyle(
                                  fontSize: 12.5, color: AppColors.textGray),
                            ),
                            const SizedBox(height: 8),
                            for (var i = 0; i < _certs.length; i++)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(
                                    Icons.workspace_premium_outlined),
                                title: Text(_certs[i].title,
                                    style: const TextStyle(fontSize: 14)),
                                subtitle: Text(
                                  [
                                    if (_certs[i].issuer.isNotEmpty)
                                      _certs[i].issuer,
                                    if (_certs[i].expires != null)
                                      'Valid until ${formatDate(_certs[i].expires!)}',
                                    _certs[i].verified
                                        ? 'Verified'
                                        : 'Not verified yet',
                                  ].join(' • '),
                                  style: const TextStyle(fontSize: 12),
                                ),
                                onTap: () => _editCert(i),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () =>
                                      setState(() => _certs.removeAt(i)),
                                ),
                              ),
                            OutlinedButton.icon(
                              onPressed: () => _editCert(),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Add certificate'),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.dark,
                            foregroundColor: Colors.white,
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Text('Save credentials'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _box(String title, Widget child) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            child,
          ],
        ),
      );
}

class _CertDialog extends StatefulWidget {
  final TechCertification? existing;
  const _CertDialog({this.existing});

  @override
  State<_CertDialog> createState() => _CertDialogState();
}

class _CertDialogState extends State<_CertDialog> {
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _issuer = TextEditingController(
      text: widget.existing?.issuer ??
          (widget.existing == null ? 'TESDA' : ''));
  late final _certNo = TextEditingController(text: widget.existing?.certNo ?? '');
  DateTime? _issued;
  DateTime? _expires;
  String? _error;

  @override
  void initState() {
    super.initState();
    _issued = widget.existing?.issued;
    _expires = widget.existing?.expires;
  }

  @override
  void dispose() {
    _title.dispose();
    _issuer.dispose();
    _certNo.dispose();
    super.dispose();
  }

  Future<void> _pick(bool issued) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (issued ? _issued : _expires) ?? now,
      firstDate: DateTime(1990),
      lastDate: DateTime(now.year + 15),
    );
    if (picked != null) {
      setState(() {
        if (issued) {
          _issued = picked;
        } else {
          _expires = picked;
        }
      });
    }
  }

  void _save() {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Enter the certificate name.');
      return;
    }
    final old = widget.existing;
    final changed = old == null ||
        old.title != _title.text.trim() ||
        old.issuer != _issuer.text.trim() ||
        old.certNo != _certNo.text.trim();
    Navigator.pop(
      context,
      TechCertification(
        title: _title.text.trim(),
        issuer: _issuer.text.trim(),
        certNo: _certNo.text.trim(),
        issued: _issued,
        expires: _expires,
        // Changing the certificate details cancels an earlier verification.
        verified: changed ? false : old!.verified,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add certificate' : 'Edit certificate'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                  labelText: 'Certificate / qualification',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 0, children: [
              for (final s in kCertificationSuggestions)
                ActionChip(
                  label: Text(s, style: const TextStyle(fontSize: 11)),
                  onPressed: () => setState(() => _title.text = s),
                ),
            ]),
            const SizedBox(height: 10),
            TextField(
              controller: _issuer,
              decoration: const InputDecoration(
                  labelText: 'Issued by', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _certNo,
              decoration: const InputDecoration(
                  labelText: 'Certificate no.', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pick(true),
                  child: Text(_issued == null
                      ? 'Date issued'
                      : formatDate(_issued!)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pick(false),
                  child: Text(_expires == null
                      ? 'Valid until'
                      : formatDate(_expires!)),
                ),
              ),
            ]),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!,
                    style: const TextStyle(color: AppColors.danger)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
