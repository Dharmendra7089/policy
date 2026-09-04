import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../utils/pdf_download.dart';
import '../../utils/revenue_invoice_pdf.dart';

class InvoicesTab extends StatefulWidget {
  const InvoicesTab({super.key});

  @override
  State<InvoicesTab> createState() => _InvoicesTabState();
}

class _InvoicesTabState extends State<InvoicesTab> {
  static const _primary = Color(0xFF0D2D4F);
  static const _bg = Color(0xFFF4F6F9);
  static const _surface = Colors.white;
  static const _border = Color(0xFFE4E7EC);
  static const _muted = Color(0xFF667085);
  static const _green = Color(0xFF15803D);

  String? _downloadingId;

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  String _date(dynamic value) {
    if (value is Timestamp) {
      final d = value.toDate();
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    }
    final raw = (value ?? '').toString();
    if (raw.isEmpty) return '-';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
  }

  String _money(dynamic value) {
    final number = value is num
        ? value.toDouble()
        : double.tryParse((value ?? '').toString()) ?? 0;
    if (number >= 10000000) {
      return 'Rs ${(number / 10000000).toStringAsFixed(2)} Cr';
    }
    if (number >= 100000) {
      return 'Rs ${(number / 100000).toStringAsFixed(2)} L';
    }
    return 'Rs ${number.toStringAsFixed(0)}';
  }

  Future<void> _download(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    if (_downloadingId != null) return;
    setState(() => _downloadingId = doc.id);
    try {
      final data = doc.data();
      final payload = _map(data['payload']);
      final invoice = _map(payload['invoice']).isNotEmpty
          ? _map(payload['invoice'])
          : data;
      final invoiceNo = (data['invoiceNo'] ?? invoice['invoiceNo'] ?? 'invoice')
          .toString();
      final bytes = await RevenueInvoicePdf.build(invoice);
      await downloadPdfFile(bytes: bytes, filename: '$invoiceNo.pdf');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to download invoice: $error')),
      );
    } finally {
      if (mounted) setState(() => _downloadingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: _surface,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
              child: const Row(
                children: [
                  Icon(Icons.receipt_long_rounded, color: _primary),
                  SizedBox(width: 10),
                  Text(
                    'Invoices',
                    style: TextStyle(
                      color: _primary,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: _border),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('invoices')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Unable to load invoices: ${snapshot.error}'),
                    );
                  }
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Center(
                      child: Text(
                        'No invoices generated yet.',
                        style: TextStyle(color: _muted),
                      ),
                    );
                  }
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 1050),
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                          const Color(0xFFEFF6FF),
                        ),
                        columns: const [
                          DataColumn(label: Text('Invoice No.')),
                          DataColumn(label: Text('Company')),
                          DataColumn(label: Text('Category')),
                          DataColumn(label: Text('Invoice Date')),
                          DataColumn(label: Text('Period')),
                          DataColumn(label: Text('Amount')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Download')),
                        ],
                        rows: docs.map((doc) {
                          final data = doc.data();
                          final status = (data['status'] ?? 'generated')
                              .toString();
                          final downloading = _downloadingId == doc.id;
                          return DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  (data['invoiceNo'] ?? '-').toString(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text((data['companyName'] ?? '-').toString()),
                              ),
                              DataCell(
                                Text((data['category'] ?? '-').toString()),
                              ),
                              DataCell(Text(_date(data['invoiceDate']))),
                              DataCell(
                                Text(
                                  '${_date(data['periodStart'])} to ${_date(data['periodEnd'])}',
                                ),
                              ),
                              DataCell(Text(_money(data['totalInvoiceValue']))),
                              DataCell(
                                Text(
                                  status,
                                  style: const TextStyle(
                                    color: _green,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              DataCell(
                                FilledButton.icon(
                                  onPressed: downloading
                                      ? null
                                      : () => _download(doc),
                                  icon: downloading
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.download_rounded,
                                          size: 16,
                                        ),
                                  label: Text(
                                    downloading ? 'Downloading' : 'Download',
                                  ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _primary,
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
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
