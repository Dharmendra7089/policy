import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../utils/pdf_download.dart';
import '../../utils/revenue_invoice_pdf.dart';

class ReportsTab extends StatelessWidget {
  final Map<String, dynamic>? userData;
  const ReportsTab({super.key, this.userData});

  static const _primary = Color(0xFF0D2D4F);
  static const _accent = Color(0xFF1A6EBD);
  static const _bg = Color(0xFFF4F6F9);
  static const _surface = Color(0xFFFFFFFF);
  static const _textMain = Color(0xFF0D1B2A);
  static const _textMuted = Color(0xFF6B7280);
  static const _border = Color(0xFFE5E7EB);
  static const _maxPdfDetailRows = 100;

  String _fmtDate(dynamic value) {
    DateTime? date;
    if (value is Timestamp) date = value.toDate();
    if (value is DateTime) date = value;
    date ??= DateTime.tryParse((value ?? '').toString());
    if (date == null) return '-';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  double _num(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse((value ?? '').toString().replaceAll(',', '')) ?? 0;
  }

  String _currency(dynamic value) {
    final amount = _num(value);
    if (amount >= 10000000) {
      return 'Rs ${(amount / 10000000).toStringAsFixed(2)} Cr';
    }
    if (amount >= 100000) {
      return 'Rs ${(amount / 100000).toStringAsFixed(2)} L';
    }
    return 'Rs ${amount.toStringAsFixed(0)}';
  }

  String _safeFileName(String title) {
    final cleaned = title
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    return cleaned.isEmpty ? 'performance_report.pdf' : '$cleaned.pdf';
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _rows(dynamic value) {
    if (value is! List) return <Map<String, dynamic>>[];
    return value.whereType<Map>().map(Map<String, dynamic>.from).toList();
  }

  dynamic _payloadPremium(Map<String, dynamic> payload) {
    return payload['premium'] ?? payload['totalPremium'];
  }

  String _payloadPolicies(Map<String, dynamic> payload) {
    return (payload['policiesCount'] ?? payload['totalConversions'] ?? 0)
        .toString();
  }

  Future<Uint8List> _buildReportPdf(Map<String, dynamic> data) async {
    final payload = _map(data['payload']);
    if ((data['type'] ?? '').toString().toLowerCase() == 'revenue invoice') {
      return RevenueInvoicePdf.build(_map(payload['invoice']));
    }
    final rows = _rows(payload['rows']);
    final pdfRows = rows.take(_maxPdfDetailRows).toList();
    final type = (data['type'] ?? 'Report').toString();
    final isSales = type.toLowerCase() == 'sales';
    final title = (data['title'] ?? '$type Report').toString();
    final createdBy = (data['createdByName'] ?? 'Admin').toString();
    final createdEmail = (data['createdByEmail'] ?? '').toString();
    final creatorText = createdEmail.trim().isEmpty
        ? createdBy
        : '$createdBy ($createdEmail)';

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text('Type: ${data['type'] ?? '-'}'),
          pw.Text('Month: ${data['month'] ?? '-'}'),
          pw.Text('Scope: ${data['scope'] ?? 'All employees'}'),
          pw.Text('Category: ${data['category'] ?? 'All'}'),
          pw.Text('Created by: $creatorText'),
          pw.Text('Created on: ${_fmtDate(data['createdAt'])}'),
          pw.SizedBox(height: 16),
          pw.Text(
            'Summary',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: const {
              0: pw.FlexColumnWidth(2),
              1: pw.FlexColumnWidth(3),
            },
            children: [
              _summaryRow(
                'Customers',
                '${payload['customersCount'] ?? payload['totalCustomers'] ?? 0}',
              ),
              _summaryRow('Policies', '${payload['policiesCount'] ?? 0}'),
              if (isSales)
                _summaryRow(
                  'Conversions',
                  '${payload['totalConversions'] ?? 0}',
                ),
              if (isSales)
                _summaryRow('Leads', '${payload['totalLeads'] ?? 0}'),
              _summaryRow('Premium', _currency(_payloadPremium(payload))),
              if (isSales)
                _summaryRow(
                  'Commission',
                  _currency(payload['totalCommission']),
                ),
              if (!isSales)
                _summaryRow('Target', _currency(payload['targetPremium'])),
              _summaryRow(
                'Target Progress',
                '${(_num(payload['targetProgress']) * 100).round()}%',
              ),
              if (!isSales)
                _summaryRow(
                  'Health Customers',
                  '${payload['healthCustomers'] ?? 0}',
                ),
              if (!isSales)
                _summaryRow(
                  'Life Customers',
                  '${payload['lifeCustomers'] ?? 0}',
                ),
              if (!isSales)
                _summaryRow(
                  'General Customers',
                  '${payload['generalCustomers'] ?? 0}',
                ),
            ],
          ),
          pw.SizedBox(height: 18),
          if (isSales) ...[
            _salesCategoryTable(payload),
            pw.SizedBox(height: 14),
            _salesEmployeeTable(payload),
            pw.SizedBox(height: 14),
            _salesLeadAndCompanyTable(payload),
            pw.SizedBox(height: 18),
          ],
          pw.Text(
            isSales ? 'Sales Policy Details' : 'Policy Details',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          if (rows.isEmpty)
            pw.Text('No policy rows for this report.')
          else ...[
            if (rows.length > _maxPdfDetailRows)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 6),
                child: pw.Text(
                  'Showing first $_maxPdfDetailRows of ${rows.length} rows for faster PDF download.',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey700,
                  ),
                ),
              ),
            pw.TableHelper.fromTextArray(
              headers: [
                'Customer',
                'Category',
                'Policy No',
                'Policy',
                'Company',
                'Premium',
                'Commission',
                'Employee',
                if (isSales) 'Given Date',
              ],
              data: pdfRows.map((row) {
                return [
                  (row['customerName'] ?? '-').toString(),
                  (row['category'] ?? '-').toString(),
                  (row['policyNumber'] ?? '-').toString(),
                  (row['policyName'] ?? '-').toString(),
                  (row['companyName'] ?? '-').toString(),
                  _currency(row['premiumAmount']),
                  _currency(row['commissionAmount']),
                  (row['employeeName'] ?? '-').toString(),
                  if (isSales) (row['policyGivenDate'] ?? '-').toString(),
                ];
              }).toList(),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              headerStyle: pw.TextStyle(
                fontSize: 7,
                fontWeight: pw.FontWeight.bold,
              ),
              cellStyle: const pw.TextStyle(fontSize: 7),
              cellAlignment: pw.Alignment.centerLeft,
            ),
          ],
        ],
      ),
    );
    return pdf.save();
  }

  Future<void> _downloadReport(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    final title = (data['title'] ?? 'Performance Report').toString();
    final filename = _safeFileName(title);
    try {
      final payload = _map(data['payload']);
      if ((data['type'] ?? '').toString().toLowerCase() == 'revenue invoice') {
        final bytes = await RevenueInvoicePdf.build(_map(payload['invoice']));
        await downloadPdfFile(bytes: bytes, filename: filename);
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 30));
      final bytes = await _buildReportPdf(data);
      await downloadPdfFile(bytes: bytes, filename: filename);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to download report: $error')),
      );
    }
  }

  pw.TableRow _summaryRow(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(
            label,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(value)),
      ],
    );
  }

  pw.Widget _salesCategoryTable(Map<String, dynamic> payload) {
    final rows = _rows(payload['categories']);
    if (rows.isEmpty) return pw.SizedBox();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Category Breakdown',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headers: const [
            'Category',
            'Customers',
            'Leads',
            'Conversions',
            'Premium',
            'Commission',
          ],
          data: rows
              .map(
                (row) => [
                  row['category'] ?? '-',
                  row['customers'] ?? 0,
                  row['leads'] ?? 0,
                  row['conversions'] ?? 0,
                  _currency(row['premium']),
                  _currency(row['commission']),
                ],
              )
              .toList(),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          headerStyle: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
          ),
          cellStyle: const pw.TextStyle(fontSize: 8),
          cellAlignment: pw.Alignment.centerLeft,
        ),
      ],
    );
  }

  pw.Widget _salesEmployeeTable(Map<String, dynamic> payload) {
    final rows = _rows(payload['employees']);
    if (rows.isEmpty) return pw.SizedBox();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Employee Target Progress',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headers: const ['Employee', 'Premium', 'Target', 'Conversions', '%'],
          data: rows
              .map(
                (row) => [
                  row['name'] ?? '-',
                  _currency(row['premium']),
                  _currency(row['target']),
                  row['conversions'] ?? 0,
                  '${(_num(row['progress']) * 100).round()}%',
                ],
              )
              .toList(),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          headerStyle: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
          ),
          cellStyle: const pw.TextStyle(fontSize: 8),
          cellAlignment: pw.Alignment.centerLeft,
        ),
      ],
    );
  }

  pw.Widget _salesLeadAndCompanyTable(Map<String, dynamic> payload) {
    final leadStatus = _map(payload['leadStatus']);
    final companyPremium = _map(payload['companyPremium']);
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: _keyValueTable(
            title: 'Lead Temperature',
            rows: leadStatus.entries
                .map((entry) => [entry.key, entry.value.toString()])
                .toList(),
          ),
        ),
        pw.SizedBox(width: 12),
        pw.Expanded(
          child: _keyValueTable(
            title: 'Top Company Premium',
            rows: companyPremium.entries
                .take(8)
                .map((entry) => [entry.key, _currency(entry.value)])
                .toList(),
          ),
        ),
      ],
    );
  }

  pw.Widget _keyValueTable({
    required String title,
    required List<List<String>> rows,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        if (rows.isEmpty)
          pw.Text('-')
        else
          pw.TableHelper.fromTextArray(
            headers: const ['Name', 'Value'],
            data: rows,
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            headerStyle: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignment: pw.Alignment.centerLeft,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserName =
        (userData?['name'] ?? userData?['username'] ?? userData?['email'] ?? '')
            .toString();

    return Scaffold(
      backgroundColor: _bg,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reports',
                      style: TextStyle(
                        color: _textMain,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Generated performance reports with download support',
                      style: TextStyle(color: _textMuted, fontSize: 13),
                    ),
                  ],
                ),
                if (currentUserName.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _border),
                    ),
                    child: Text(
                      'Viewing as $currentUserName',
                      style: const TextStyle(
                        color: _textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('reports')
                    .orderBy('createdAt', descending: true)
                    .limit(100)
                    .snapshots(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: _primary),
                    );
                  }
                  if (snap.hasError) {
                    return Center(child: Text('Error: ${snap.error}'));
                  }

                  final docs = (snap.data?.docs ?? []).where((doc) {
                    final type = (doc.data()['type'] ?? '').toString();
                    return type.toLowerCase() != 'revenue invoice';
                  }).toList();
                  if (docs.isEmpty) {
                    return const Center(
                      child: Text(
                        'No reports generated yet.',
                        style: TextStyle(color: _textMuted),
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final data = docs[i].data();
                      final payload = _map(data['payload']);
                      final type = (data['type'] ?? 'Report').toString();
                      final month = (data['month'] ?? '-').toString();
                      final scope = (data['scope'] ?? 'All employees')
                          .toString();
                      final createdBy = (data['createdByName'] ?? '-')
                          .toString();

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: _accent.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.picture_as_pdf_rounded,
                                color: _accent,
                                size: 21,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (data['title'] ?? 'Report').toString(),
                                    style: const TextStyle(
                                      color: _textMain,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$type  |  $month  |  $scope',
                                    style: const TextStyle(
                                      color: _textMuted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Created by $createdBy on ${_fmtDate(data['createdAt'])}',
                                    style: const TextStyle(
                                      color: _textMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            _MiniMetric(
                              label: 'Policies',
                              value: _payloadPolicies(payload),
                            ),
                            const SizedBox(width: 8),
                            _MiniMetric(
                              label: 'Premium',
                              value: _currency(_payloadPremium(payload)),
                            ),
                            const SizedBox(width: 12),
                            _ReportDownloadButton(
                              onPressed: () => _downloadReport(context, data),
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
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final String label;
  final String value;
  const _MiniMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 96),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ReportsTab._border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: ReportsTab._textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: ReportsTab._textMain,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportDownloadButton extends StatefulWidget {
  final Future<void> Function() onPressed;

  const _ReportDownloadButton({required this.onPressed});

  @override
  State<_ReportDownloadButton> createState() => _ReportDownloadButtonState();
}

class _ReportDownloadButtonState extends State<_ReportDownloadButton> {
  bool _busy = false;

  Future<void> _run() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onPressed();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: _busy ? null : _run,
      icon: _busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.download_rounded, size: 18),
      label: Text(_busy ? 'Preparing...' : 'Download'),
      style: FilledButton.styleFrom(
        backgroundColor: ReportsTab._primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
