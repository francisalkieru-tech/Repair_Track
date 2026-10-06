import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'report_data.dart';
import 'technician_profile.dart';

const _ink = PdfColor.fromInt(0xFF111827);
const _gray = PdfColor.fromInt(0xFF6B7280);
const _line = PdfColor.fromInt(0xFFD1D5DB);
const _soft = PdfColor.fromInt(0xFFF3F4F6);

const _shopName = 'Repair Tracker';

/// Opens the browser/system print dialog (which also has "Save as PDF").
Future<void> printAdminReport(AdminReport r) => Printing.layoutPdf(
      name: 'Admin Report - ${r.period.label}',
      onLayout: (_) => _adminPdf(r),
    );

Future<void> printTechnicianReport(TechnicianReport r) => Printing.layoutPdf(
      name: '${r.technicianName} - ${r.period.label}',
      onLayout: (_) => _technicianPdf(r),
    );

// Direct PDF download (on web this saves the file; on phones it opens
// the share sheet).

String _fileName(String text) =>
    '${text.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '')}.pdf';

Future<void> downloadAdminReport(AdminReport r) async => Printing.sharePdf(
      bytes: await _adminPdf(r),
      filename: _fileName('Admin Report ${r.period.label}'),
    );

Future<void> downloadTechnicianReport(TechnicianReport r) async =>
    Printing.sharePdf(
      bytes: await _technicianPdf(r),
      filename: _fileName('${r.technicianName} ${r.period.label}'),
    );

Future<void> downloadTechnicianResume(TechnicianResume r) async =>
    Printing.sharePdf(
      bytes: await _resumePdf(r),
      filename: _fileName('Resume ${r.name}'),
    );

// shared bits

pw.Widget _header(String title, String subtitle, String generatedFor) =>
    pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(_shopName,
                style: pw.TextStyle(
                    fontSize: 11, fontWeight: pw.FontWeight.bold, color: _gray)),
            pw.Text('Generated ${formatDateTime(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 9, color: _gray)),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Text(title,
            style: pw.TextStyle(
                fontSize: 20, fontWeight: pw.FontWeight.bold, color: _ink)),
        pw.Text(subtitle,
            style: const pw.TextStyle(fontSize: 11, color: _gray)),
        if (generatedFor.isNotEmpty)
          pw.Text(generatedFor,
              style: const pw.TextStyle(fontSize: 11, color: _gray)),
        pw.SizedBox(height: 6),
        pw.Divider(color: _line, thickness: 1),
      ],
    );

pw.Widget _stat(String label, String value) => pw.Container(
      width: 100,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: _soft,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 16, fontWeight: pw.FontWeight.bold, color: _ink)),
          pw.SizedBox(height: 2),
          pw.Text(label, style: const pw.TextStyle(fontSize: 8.5, color: _gray)),
        ],
      ),
    );

pw.Widget _section(String text) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
      child: pw.Text(text,
          style: pw.TextStyle(
              fontSize: 12, fontWeight: pw.FontWeight.bold, color: _ink)),
    );

pw.Widget _table(List<String> headers, List<List<String>> rows,
    {Map<int, pw.TableColumnWidth>? widths}) {
  return pw.TableHelper.fromTextArray(
    headers: headers,
    data: rows,
    columnWidths: widths,
    headerStyle: pw.TextStyle(
        fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: _ink),
    cellStyle: const pw.TextStyle(fontSize: 8.5, color: _ink),
    headerDecoration: const pw.BoxDecoration(color: _soft),
    border: pw.TableBorder(
      horizontalInside: const pw.BorderSide(color: _line, width: 0.5),
      bottom: const pw.BorderSide(color: _line, width: 0.5),
    ),
    cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
    cellAlignment: pw.Alignment.centerLeft,
  );
}

pw.Widget _footer(pw.Context c) => pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Text('Page ${c.pageNumber} of ${c.pagesCount}',
          style: const pw.TextStyle(fontSize: 8, color: _gray)),
    );

pw.Widget _signatureLine(String label) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 36),
        pw.Container(width: 170, height: 0.8, color: _ink),
        pw.SizedBox(height: 3),
        pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: _gray)),
      ],
    );

String _dateOrDash(DateTime? t) => t == null ? '-' : formatDate(t);

pw.Widget _jobTable(List<ReportJob> jobs, ReportPeriod p,
    {required bool showTechnician}) {
  final rows = jobs.map((j) {
    return [
      j.trackingId,
      j.appliance,
      j.customer,
      if (showTechnician) (j.technician.isEmpty ? '-' : j.technician),
      j.modeLabel,
      j.status,
      _dateOrDash(j.createdAt),
      _dateOrDash(j.completedAt ?? j.declinedAt),
    ];
  }).toList();

  return _table(
    [
      'Tracking ID',
      'Appliance',
      'Customer',
      if (showTechnician) 'Technician',
      'Mode',
      'Status',
      'Received',
      'Closed',
    ],
    rows,
  );
}

// ADMIN — monthly

Future<Uint8List> _adminPdf(AdminReport r) async {
  final doc = pw.Document(title: 'Admin Report - ${r.period.label}');

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      footer: _footer,
      build: (ctx) => [
        _header(
          'Monthly Transaction Report',
          '${r.period.label}  (${r.period.rangeText})',
          'Prepared for: Admin',
        ),
        pw.SizedBox(height: 8),
        pw.Wrap(spacing: 8, runSpacing: 8, children: [
          _stat('Requests received', '${r.received}'),
          _stat('Completed', '${r.completed}'),
          _stat('Declined', '${r.declined}'),
          _stat('Still open', '${r.stillOpen}'),
          _stat('Completion rate', '${r.completionRate.toStringAsFixed(0)}%'),
          _stat('Warranties issued', '${r.warrantiesIssued}'),
          _stat('Declined by technicians', '${r.technicianDeclines}'),
        ]),
        if (r.byAppliance.isNotEmpty) ...[
          _section('Requests by appliance'),
          _table(
            ['Appliance', 'Requests'],
            (r.byAppliance.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value)))
                .map((e) => [e.key, '${e.value}'])
                .toList(),
          ),
        ],
        if (r.byMode.isNotEmpty) ...[
          _section('Service mode'),
          _table(
            ['Mode', 'Requests'],
            r.byMode.entries.map((e) => [e.key, '${e.value}']).toList(),
          ),
        ],
        _section('Technician performance'),
        r.technicians.isEmpty
            ? pw.Text('No technician activity this month.',
                style: const pw.TextStyle(fontSize: 9, color: _gray))
            : _table(
                ['Technician', 'Tickets handled', 'Completed', 'Still active',
                  'Declined', 'Avg. repair time'],
                r.technicians
                    .map((t) => [
                          t.name,
                          '${t.handled}',
                          '${t.completed}',
                          '${t.stillActive}',
                          '${t.declinedByTech}',
                          t.averageRepairTime == null
                              ? '-'
                              : formatDuration(t.averageRepairTime!),
                        ])
                    .toList(),
              ),
        _section('All transactions (${r.jobs.length})'),
        r.jobs.isEmpty
            ? pw.Text('No transactions this month.',
                style: const pw.TextStyle(fontSize: 9, color: _gray))
            : _jobTable(r.jobs, r.period, showTechnician: true),
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [_signatureLine('Prepared by'), _signatureLine('Noted by')],
        ),
      ],
    ),
  );

  return doc.save();
}

// TECHNICIAN — weekly / monthly

Future<Uint8List> _technicianPdf(TechnicianReport r) async {
  final kind = r.period.isMonthly ? 'Monthly' : 'Weekly';
  final doc = pw.Document(title: '${r.technicianName} - ${r.period.label}');

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      footer: _footer,
      build: (ctx) => [
        _header(
          '$kind Technician Report',
          '${r.period.label}  (${r.period.rangeText})',
          'Technician: ${r.technicianName}',
        ),
        pw.SizedBox(height: 8),
        pw.Wrap(spacing: 8, runSpacing: 8, children: [
          _stat('Jobs completed', '${r.completed}'),
          _stat('Still in progress', '${r.stillOpen}'),
          _stat('Declined by customer/admin', '${r.declined}'),
          _stat('Jobs I declined', '${r.declinedJobs.length}'),
          _stat('Avg. repair time',
              r.averageRepairTime == null ? '-' : formatDuration(r.averageRepairTime!)),
          _stat('Days on duty', '${r.daysOnDuty}'),
          _stat('Hours on duty', formatDuration(r.dutyTime)),
        ]),
        _section('Repair requests (${r.jobs.length})'),
        r.jobs.isEmpty
            ? pw.Text('No repair activity in this period.',
                style: const pw.TextStyle(fontSize: 9, color: _gray))
            : _jobTable(r.jobs, r.period, showTechnician: false),
        if (r.declinedJobs.isNotEmpty) ...[
          _section('Jobs I declined (${r.declinedJobs.length})'),
          _table(
            ['Tracking ID', 'Appliance', 'Reason', 'Date'],
            r.declinedJobs
                .map((d) => [
                      d.trackingId,
                      d.appliance,
                      d.reason.isEmpty ? '-' : d.reason,
                      formatDate(d.at),
                    ])
                .toList(),
          ),
        ],
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _signatureLine('Technician signature'),
            _signatureLine('Admin signature'),
          ],
        ),
      ],
    ),
  );

  return doc.save();
}

// TECHNICIAN — resume

Future<void> printTechnicianResume(TechnicianResume r) => Printing.layoutPdf(
      name: 'Resume - ${r.name}',
      onLayout: (_) => _resumePdf(r),
    );

Future<Uint8List> _resumePdf(TechnicianResume r) async {
  final doc = pw.Document(title: 'Technician Resume - ${r.name}');

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      footer: _footer,
      build: (ctx) => [
        _header(
          r.name,
          [
            if (r.email.isNotEmpty) r.email,
            if (r.phone.isNotEmpty) r.phone,
          ].join('   |   '),
          r.memberSince == null
              ? 'Technician'
              : 'Technician since ${formatDate(r.memberSince!)}',
        ),
        if (r.bio.trim().isNotEmpty) ...[
          _section('About'),
          pw.Text(r.bio.trim(), style: const pw.TextStyle(fontSize: 10)),
        ],
        _section('Specializations'),
        pw.Text(
          r.specializations.isEmpty
              ? 'General repairs'
              : r.specializations.join(', '),
          style: const pw.TextStyle(fontSize: 10),
        ),
        if (r.yearsExperience > 0)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4),
            child: pw.Text(
              'Experience: ${r.yearsExperience} year${r.yearsExperience == 1 ? '' : 's'}',
              style: const pw.TextStyle(fontSize: 10, color: _gray),
            ),
          ),
        _section('Certifications & Training'),
        r.certifications.isEmpty
            ? pw.Text('No certifications listed.',
                style: const pw.TextStyle(fontSize: 9, color: _gray))
            : _table(
                ['Certificate', 'Issued by', 'Cert. No.', 'Issued', 'Valid until',
                  'Status'],
                r.certifications
                    .map((c) => [
                          c.title,
                          c.issuer.isEmpty ? '-' : c.issuer,
                          c.certNo.isEmpty ? '-' : c.certNo,
                          _dateOrDash(c.issued),
                          _dateOrDash(c.expires),
                          c.isExpired
                              ? 'Expired'
                              : (c.verified ? 'Verified by shop' : 'Not verified'),
                        ])
                    .toList(),
              ),
        _section('Work record'),
        pw.Wrap(spacing: 8, runSpacing: 8, children: [
          _stat('Repairs completed', '${r.completed}'),
          _stat('Active jobs', '${r.active}'),
          _stat('Jobs declined', '${r.declinedByMe}'),
          _stat('Avg. repair time',
              r.averageRepairTime == null ? '-' : formatDuration(r.averageRepairTime!)),
        ]),
        if (r.completedByAppliance.isNotEmpty) ...[
          _section('Completed repairs by appliance'),
          _table(
            ['Appliance', 'Completed'],
            (r.completedByAppliance.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value)))
                .map((e) => [e.key, '${e.value}'])
                .toList(),
          ),
        ],
      ],
    ),
  );

  return doc.save();
}
