import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../utils/audit_log_service.dart';
import '../../utils/lead_serial_fields.dart';
import '../../utils/pdf_download.dart';
import '../../utils/revenue_invoice_pdf.dart';

class CompanyRevenueTab extends StatefulWidget {
  final String category;
  final String title;

  const CompanyRevenueTab({
    super.key,
    required this.category,
    required this.title,
  });

  @override
  State<CompanyRevenueTab> createState() => _CompanyRevenueTabState();
}

class _CompanyRevenueTabState extends State<CompanyRevenueTab> {
  static const _primary = Color(0xFF0D2D4F);
  static const _bg = Color(0xFFF4F6F9);
  static const _surface = Colors.white;
  static const _border = Color(0xFFE4E7EC);
  static const _muted = Color(0xFF667085);
  static const _green = Color(0xFF15803D);
  static const _orange = Color(0xFFB45309);

  late Stream<QuerySnapshot<Map<String, dynamic>>> _policiesStream;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _cachedDocs = const [];
  final Set<String> _selectedIds = <String>{};

  String? _draftCompanyId;
  DateTime? _draftStart;
  DateTime? _draftEnd;
  String? _appliedCompanyId;
  DateTime? _appliedStart;
  DateTime? _appliedEnd;
  bool _includeGst = true;
  bool _busy = false;
  bool _filtersExpanded = true;

  @override
  void initState() {
    super.initState();
    _policiesStream = _buildPolicyStream();
  }

  @override
  void didUpdateWidget(covariant CompanyRevenueTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_categoryKey(oldWidget.category) != _categoryKey(widget.category)) {
      _policiesStream = _buildPolicyStream();
      _cachedDocs = const [];
      _draftCompanyId = null;
      _draftStart = null;
      _draftEnd = null;
      _appliedCompanyId = null;
      _appliedStart = null;
      _appliedEnd = null;
      _selectedIds.clear();
      _filtersExpanded = true;
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _buildPolicyStream() {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection(
      'customer_policies',
    );
    if (_categoryKey(widget.category) == 'agriculture') {
      query = query.where(
        'category',
        whereIn: const ['Agriculture', 'Agricultural'],
      );
    } else {
      query = query.where('category', isEqualTo: widget.category);
    }
    return query.snapshots();
  }

  static double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(
          (value ?? '').toString().replaceAll(',', '').trim(),
        ) ??
        0;
  }

  static DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static DateTime _day(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static String _dateLabel(DateTime? value) {
    if (value == null) return 'Select date';
    return '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
  }

  static String _isoDate(DateTime? value) {
    if (value == null) return '';
    return '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }

  static String _safeInvoicePrefix(String raw, String companyName) {
    var value = raw.trim().toUpperCase();
    value = value.replaceFirst(RegExp(r'[-/]\d+$'), '');
    value = value.replaceAll(RegExp(r'[^A-Z0-9_/]+'), '_');
    value = value.replaceAll(RegExp(r'_+'), '_');
    value = value.replaceAll(RegExp(r'/+'), '/');
    value = value.replaceAll(RegExp(r'^_+|_+$'), '');
    if (value.isNotEmpty) return value;
    final initials = companyName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    return 'MAKK_${initials.isEmpty ? 'INV' : initials}';
  }

  Future<({String invoiceNo, int invoiceCount, Map<String, dynamic> company})>
  _nextInvoiceIdentity({
    required FirebaseFirestore db,
    required String companyId,
    required String companyName,
  }) {
    final companyRef = db.collection('insurance_companies').doc(companyId);
    return db.runTransaction((transaction) async {
      final snap = await transaction.get(companyRef);
      final company = snap.data() ?? <String, dynamic>{};
      final prefix = _safeInvoicePrefix(
        (company['invoiceCode'] ?? company['invoiceCodePrefix'] ?? '')
            .toString(),
        companyName,
      );
      final next = ((company['invoiceCount'] as num?)?.toInt() ?? 0) + 1;
      final invoiceSerial = next.toString().padLeft(3, '0');
      final separator = prefix.endsWith('/') ? '' : '-';
      final invoiceNo = '$prefix$separator$invoiceSerial';
      transaction.set(companyRef, {
        'invoiceCode': prefix,
        'invoiceCodePrefix': prefix,
        'invoiceCount': next,
        'lastInvoiceNo': invoiceNo,
        'lastInvoiceGeneratedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return (invoiceNo: invoiceNo, invoiceCount: next, company: company);
    });
  }

  static String _money(double value) =>
      'Rs ${value.toStringAsFixed(2).replaceFirst(RegExp(r'\.00$'), '')}';

  static String _percent(double value) {
    final text = value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
    return '$text%';
  }

  static String _categoryKey(String value) {
    final key = value.trim().toLowerCase();
    return key == 'agricultural' ? 'agriculture' : key;
  }

  bool _belongsToCategory(Map<String, dynamic> data) =>
      _categoryKey((data['category'] ?? '').toString()) ==
      _categoryKey(widget.category);

  DateTime? _recordDate(Map<String, dynamic> data) =>
      _date(data['issueDate']) ??
      _date(data['policyStartDate']) ??
      _date(data['createdAt']);

  bool _isSettled(Map<String, dynamic> data) =>
      data['settled'] == true ||
      (data['settlementStatus'] ?? '').toString().toLowerCase() == 'settled';

  bool _isFrozen(Map<String, dynamic> data) =>
      !_isSettled(data) &&
      (data['invoiceFrozen'] == true ||
          (data['settlementStatus'] ?? '').toString().toLowerCase() ==
              'invoice_frozen');

  bool _isOpen(Map<String, dynamic> data) =>
      !_isSettled(data) && !_isFrozen(data);

  double _commissionAmount(Map<String, dynamic> data) =>
      _number(data['commissionAmount']);

  double _commissionPercent(Map<String, dynamic> data) =>
      _number(data['commissionPercent']);

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _results(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    if (_appliedCompanyId == null ||
        _appliedStart == null ||
        _appliedEnd == null) {
      return const [];
    }
    final start = _day(_appliedStart!);
    final end = _day(_appliedEnd!);
    final result = docs.where((doc) {
      final data = doc.data();
      if (!_belongsToCategory(data)) return false;
      if ((data['companyId'] ?? '').toString() != _appliedCompanyId) {
        return false;
      }
      final recordDate = _recordDate(data);
      if (recordDate == null) return false;
      final date = _day(recordDate);
      return !date.isBefore(start) && !date.isAfter(end);
    }).toList();
    result.sort((a, b) {
      final aState = _sortState(a.data());
      final bState = _sortState(b.data());
      if (aState != bState) return aState.compareTo(bState);
      final aDate = _recordDate(a.data()) ?? DateTime(1900);
      final bDate = _recordDate(b.data()) ?? DateTime(1900);
      return bDate.compareTo(aDate);
    });
    return result;
  }

  int _sortState(Map<String, dynamic> data) {
    if (_isOpen(data)) return 0;
    if (_isFrozen(data)) return 1;
    return 2;
  }

  Future<void> _pickDate({required bool start}) async {
    if (_draftCompanyId == null) return;
    final initial = start
        ? (_draftStart ?? DateTime.now())
        : (_draftEnd ?? _draftStart ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: initial,
      helpText: start ? 'Select revenue start date' : 'Select revenue end date',
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (start) {
        _draftStart = picked;
        if (_draftEnd != null && _draftEnd!.isBefore(picked)) {
          _draftEnd = null;
        }
      } else {
        _draftEnd = picked;
      }
    });
  }

  void _apply() {
    if (_draftCompanyId == null || _draftStart == null || _draftEnd == null) {
      return;
    }
    setState(() {
      _appliedCompanyId = _draftCompanyId;
      _appliedStart = _draftStart;
      _appliedEnd = _draftEnd;
      _selectedIds.clear();
      _filtersExpanded = false;
    });
  }

  void _reset() {
    setState(() {
      _draftCompanyId = null;
      _draftStart = null;
      _draftEnd = null;
      _appliedCompanyId = null;
      _appliedStart = null;
      _appliedEnd = null;
      _selectedIds.clear();
    });
  }

  void _selectAllOpen(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    setState(() {
      _selectedIds
        ..clear()
        ..addAll(docs.where((doc) => _isOpen(doc.data())).map((doc) => doc.id));
    });
  }

  void _selectAllFrozen(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    setState(() {
      _selectedIds
        ..clear()
        ..addAll(
          docs.where((doc) => _isFrozen(doc.data())).map((doc) => doc.id),
        );
    });
  }

  void _unselectVisible(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    setState(() {
      for (final doc in docs) {
        _selectedIds.remove(doc.id);
      }
    });
  }

  Future<void> _overrideCommission(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    if (!_isOpen(data)) {
      _toast('This policy is frozen/settled and locked.');
      return;
    }
    final premium = _number(data['premiumAmount']);
    final percentCtrl = TextEditingController(
      text: _commissionPercent(
        data,
      ).toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), ''),
    );
    final reasonCtrl = TextEditingController(
      text: (data['commissionOverrideReason'] ?? '').toString(),
    );
    final permissionCtrl = TextEditingController(
      text: (data['commissionOverridePermissionBy'] ?? '').toString(),
    );
    double preview = _commissionAmount(data);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            void recalc() {
              final percent = _number(percentCtrl.text);
              setDialogState(() => preview = premium * percent / 100);
            }

            return AlertDialog(
              title: const Text('Override commission'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${data['customerName'] ?? '-'} | ${data['policyNumber'] ?? '-'}',
                      style: const TextStyle(color: _muted),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: percentCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Commission %',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => recalc(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: permissionCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Permission given by *',
                        hintText: 'Name of the person who approved this',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: reasonCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Reason / note *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Premium ${_money(premium)} -> Commission ${_money(preview)}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final percent = _number(percentCtrl.text);
                    final permissionBy = permissionCtrl.text.trim();
                    final reason = reasonCtrl.text.trim();
                    if (percent <= 0 ||
                        permissionBy.isEmpty ||
                        reason.isEmpty) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Enter commission %, permission person, and reason.',
                          ),
                        ),
                      );
                      return;
                    }
                    final amount = double.parse(
                      (premium * percent / 100).toStringAsFixed(2),
                    );
                    await doc.reference.update({
                      if (data['commissionOverridden'] != true) ...{
                        'originalCommissionPercent': _commissionPercent(data),
                        'originalCommissionAmount': _commissionAmount(data),
                      },
                      'commissionPercent': percent,
                      'commissionAmount': amount,
                      'commissionOverridden': true,
                      'commissionOverrideReason': reason,
                      'commissionOverridePermissionBy': permissionBy,
                      'commissionOverrideUpdatedAt':
                          FieldValue.serverTimestamp(),
                    });
                    await AuditLogService.write(
                      page: widget.title,
                      action: 'commission_override',
                      description:
                          'Commission overridden for ${data['customerName'] ?? '-'} / ${data['policyNumber'] ?? '-'} with permission from $permissionBy.',
                      targetId: doc.id,
                      targetType: 'customer_policy',
                      targetName: (data['customerName'] ?? '').toString(),
                      extra: {
                        'oldCommissionPercent': _commissionPercent(data),
                        'oldCommissionAmount': _commissionAmount(data),
                        'newCommissionPercent': percent,
                        'newCommissionAmount': amount,
                        'permissionBy': permissionBy,
                        'reason': reason,
                        'companyName': data['companyName'] ?? '',
                        'policyNumber': data['policyNumber'] ?? '',
                      },
                    );
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                    _toast('Commission override saved.');
                  },
                  child: const Text('Save override'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _markSelectedSettled(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final selected = docs
        .where((doc) => _selectedIds.contains(doc.id) && _isFrozen(doc.data()))
        .toList();
    if (selected.isEmpty) {
      _toast('Select frozen invoice policies first.');
      return;
    }
    setState(() => _busy = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in selected) {
        batch.update(doc.reference, {
          'settled': true,
          'locked': true,
          'settlementStatus': 'settled',
          'settledAt': FieldValue.serverTimestamp(),
          'invoiceFrozen': false,
        });
      }
      await batch.commit();
      await AuditLogService.write(
        page: widget.title,
        action: 'mark_settled',
        description:
            '${selected.length} frozen invoice policies marked settled.',
        targetType: 'customer_policy',
        extra: {
          'policyIds': selected.map((doc) => doc.id).toList(),
          'amountSettled': selected.fold<double>(
            0,
            (total, doc) => total + _commissionAmount(doc.data()),
          ),
        },
      );
      setState(() => _selectedIds.clear());
      _toast('${selected.length} policies marked settled and locked.');
    } catch (error) {
      _toast('Unable to settle: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _generateInvoiceAndFreeze(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final selected = docs
        .where((doc) => _selectedIds.contains(doc.id) && _isOpen(doc.data()))
        .toList();
    if (selected.isEmpty) {
      _toast('Select open policies for the invoice.');
      return;
    }
    setState(() => _busy = true);
    try {
      final db = FirebaseFirestore.instance;
      final invoiceRef = db.collection('invoices').doc();
      final now = DateTime.now();
      final companyName = (selected.first.data()['companyName'] ?? 'Company')
          .toString();
      final companyId =
          _appliedCompanyId ??
          (selected.first.data()['companyId'] ?? '').toString();
      if (companyId.trim().isEmpty) {
        _toast('Select a company before generating invoice.');
        return;
      }
      final invoiceIdentity = await _nextInvoiceIdentity(
        db: db,
        companyId: companyId,
        companyName: companyName,
      );
      final company = invoiceIdentity.company;
      final taxable = selected.fold<double>(
        0,
        (total, doc) => total + _commissionAmount(doc.data()),
      );
      final invoice = {
        'invoiceNo': invoiceIdentity.invoiceNo,
        'invoiceCode': _safeInvoicePrefix(
          (company['invoiceCode'] ?? company['invoiceCodePrefix'] ?? '')
              .toString(),
          companyName,
        ),
        'invoiceCount': invoiceIdentity.invoiceCount,
        'invoiceDate': _isoDate(now),
        'companyId': companyId,
        'companyName': companyName,
        'billedTo': companyName,
        'billedToAddress': (company['headOfficeAddress'] ?? '').toString(),
        'billedToGstin':
            (company['gstin'] ?? company['gstIn'] ?? company['gstNumber'] ?? '')
                .toString(),
        'category': widget.category,
        'periodStart': _isoDate(_appliedStart),
        'periodEnd': _isoDate(_appliedEnd),
        'includeGst': _includeGst,
        'taxableValue': double.parse(taxable.toStringAsFixed(2)),
        'cgst': _includeGst
            ? double.parse((taxable * 0.09).toStringAsFixed(2))
            : 0,
        'sgst': _includeGst
            ? double.parse((taxable * 0.09).toStringAsFixed(2))
            : 0,
        'totalGst': _includeGst
            ? double.parse((taxable * 0.18).toStringAsFixed(2))
            : 0,
        'totalInvoiceValue': _includeGst
            ? double.parse((taxable * 1.18).toStringAsFixed(2))
            : double.parse(taxable.toStringAsFixed(2)),
        'rows': selected.map((doc) {
          final data = doc.data();
          return {
            'customerPolicyId': doc.id,
            'customerId': data['customerId'],
            'customerName': data['customerName'],
            'policyNumber': data['policyNumber'],
            'policyName': data['productName'] ?? data['policyName'],
            'premiumAmount': _number(data['premiumAmount']),
            'commissionPercent': _commissionPercent(data),
            'commissionAmount': _commissionAmount(data),
            'commissionOverridden': data['commissionOverridden'] == true,
          };
        }).toList(),
      };
      await invoiceRef.set({
        'type': 'Revenue Invoice',
        'invoiceNo': invoice['invoiceNo'],
        'invoiceCode': invoice['invoiceCode'],
        'invoiceCount': invoice['invoiceCount'],
        'title': 'Invoice ${invoice['invoiceNo']} - $companyName',
        'companyId': companyId,
        'companyName': companyName,
        'category': widget.category,
        'periodStart': invoice['periodStart'],
        'periodEnd': invoice['periodEnd'],
        'invoiceDate': invoice['invoiceDate'],
        'includeGst': _includeGst,
        'taxableValue': invoice['taxableValue'],
        'totalGst': invoice['totalGst'],
        'totalInvoiceValue': invoice['totalInvoiceValue'],
        'status': 'generated',
        'policyIds': selected.map((doc) => doc.id).toList(),
        'payload': {'invoice': invoice, 'rows': invoice['rows']},
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final batch = db.batch();
      for (final doc in selected) {
        batch.update(doc.reference, {
          'settled': false,
          'locked': true,
          'invoiceFrozen': true,
          'settlementStatus': 'invoice_frozen',
          'invoiceFrozenAt': FieldValue.serverTimestamp(),
          'invoiceId': invoiceRef.id,
          'invoiceNo': invoice['invoiceNo'],
          'invoiceCode': invoice['invoiceCode'],
          'invoiceCount': invoice['invoiceCount'],
          'invoiceIncludesGst': _includeGst,
        });
      }
      await batch.commit();
      final pdfBytes = await RevenueInvoicePdf.build(invoice);
      await downloadPdfFile(
        bytes: pdfBytes,
        filename: '${invoice['invoiceNo']}.pdf',
      );
      await AuditLogService.write(
        page: widget.title,
        action: 'generate_invoice_freeze',
        description:
            'Invoice ${invoice['invoiceNo']} generated and ${selected.length} policies frozen.',
        targetId: invoiceRef.id,
        targetType: 'invoice',
        targetName: companyName,
        extra: {
          'invoiceNo': invoice['invoiceNo'],
          'invoiceId': invoiceRef.id,
          'policyIds': selected.map((doc) => doc.id).toList(),
          'taxableValue': invoice['taxableValue'],
          'totalInvoiceValue': invoice['totalInvoiceValue'],
          'includeGst': _includeGst,
        },
      );
      if (mounted) {
        setState(() {
          _selectedIds.clear();
          _busy = false;
        });
      }
      _toast(
        'Invoice ${invoice['invoiceNo']} generated, downloaded, and added to Account Management.',
      );
      return;
    } catch (error) {
      _toast('Unable to generate invoice: $error');
    } finally {
      if (mounted && _busy) setState(() => _busy = false);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            const Divider(height: 1, color: _border),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _policiesStream,
                builder: (context, snapshot) {
                  if (snapshot.hasData) _cachedDocs = snapshot.data!.docs;
                  if (_cachedDocs.isEmpty &&
                      snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError && _cachedDocs.isEmpty) {
                    return Center(
                      child: Text('Unable to load revenue: ${snapshot.error}'),
                    );
                  }

                  final categoryDocs = _cachedDocs
                      .where((doc) => _belongsToCategory(doc.data()))
                      .toList();
                  final companies = <String, String>{};
                  for (final doc in categoryDocs) {
                    final data = doc.data();
                    final id = (data['companyId'] ?? '').toString().trim();
                    final name = (data['companyName'] ?? '').toString().trim();
                    if (id.isNotEmpty && name.isNotEmpty) companies[id] = name;
                  }
                  final companyEntries = companies.entries.toList()
                    ..sort((a, b) => a.value.compareTo(b.value));
                  final results = _results(categoryDocs);

                  return Column(
                    children: [
                      _filters(companyEntries),
                      Expanded(child: _content(results)),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() => Container(
    color: _surface,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    child: Row(
      children: [
        const Icon(Icons.insights_rounded, color: _primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Text(
                'Select company/date range, override if needed, freeze invoice first, then settle later.',
                style: TextStyle(color: _muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _filters(List<MapEntry<String, String>> companies) {
    final ready =
        _draftCompanyId != null && _draftStart != null && _draftEnd != null;
    if (!_filtersExpanded && _appliedCompanyId != null) {
      String? companyName;
      for (final entry in companies) {
        if (entry.key == _appliedCompanyId) {
          companyName = entry.value;
          break;
        }
      }
      return Container(
        color: _surface,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          children: [
            const Icon(Icons.filter_alt_rounded, color: _primary, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${companyName ?? 'Selected company'} | ${_dateLabel(_appliedStart)} to ${_dateLabel(_appliedEnd)}',
                style: const TextStyle(fontWeight: FontWeight.w800),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton.icon(
              onPressed: () => setState(() => _filtersExpanded = true),
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              label: const Text('Change search'),
            ),
          ],
        ),
      );
    }
    return Container(
      color: _surface,
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fields = <Widget>[
            DropdownButtonFormField<String>(
              key: ValueKey(_draftCompanyId),
              initialValue: companies.any((e) => e.key == _draftCompanyId)
                  ? _draftCompanyId
                  : null,
              isExpanded: true,
              hint: const Text('1. Select company'),
              items: companies
                  .map(
                    (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                  )
                  .toList(),
              onChanged: (value) => setState(() {
                _draftCompanyId = value;
                _draftStart = null;
                _draftEnd = null;
                _selectedIds.clear();
                _filtersExpanded = true;
              }),
              decoration: const InputDecoration(
                labelText: 'Company',
                border: OutlineInputBorder(),
              ),
            ),
            _dateButton(
              label: '2. Start date',
              value: _draftStart,
              enabled: _draftCompanyId != null,
              onTap: () => _pickDate(start: true),
            ),
            _dateButton(
              label: '3. End date',
              value: _draftEnd,
              enabled: _draftStart != null,
              onTap: () => _pickDate(start: false),
            ),
            SizedBox(
              height: 56,
              child: FilledButton.icon(
                onPressed: ready ? _apply : null,
                icon: const Icon(Icons.search_rounded),
                label: const Text('Show Revenue'),
                style: FilledButton.styleFrom(backgroundColor: _primary),
              ),
            ),
            SizedBox(
              height: 56,
              child: OutlinedButton(
                onPressed: _reset,
                child: const Text('Reset'),
              ),
            ),
          ];
          if (constraints.maxWidth >= 1000) {
            return Row(
              children: [
                Expanded(flex: 3, child: fields[0]),
                const SizedBox(width: 10),
                Expanded(flex: 2, child: fields[1]),
                const SizedBox(width: 10),
                Expanded(flex: 2, child: fields[2]),
                const SizedBox(width: 10),
                fields[3],
                const SizedBox(width: 8),
                fields[4],
              ],
            );
          }
          return Column(
            children: fields
                .map(
                  (field) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SizedBox(width: double.infinity, child: field),
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }

  Widget _dateButton({
    required String label,
    required DateTime? value,
    required bool enabled,
    required VoidCallback onTap,
  }) => InkWell(
    onTap: enabled ? onTap : null,
    borderRadius: BorderRadius.circular(4),
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        enabled: enabled,
        border: const OutlineInputBorder(),
        suffixIcon: const Icon(Icons.calendar_month_outlined),
      ),
      child: Text(_dateLabel(value)),
    ),
  );

  Widget _content(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    if (_appliedCompanyId == null) {
      return const Center(
        child: Text(
          'Choose a company and date range to view revenue.',
          style: TextStyle(color: _muted),
        ),
      );
    }
    if (docs.isEmpty) {
      return const Center(
        child: Text(
          'No policies found for this company and date range.',
          style: TextStyle(color: _muted),
        ),
      );
    }

    _selectedIds.removeWhere((id) => !docs.any((doc) => doc.id == id));

    final premium = docs.fold<double>(
      0,
      (total, doc) => total + _number(doc.data()['premiumAmount']),
    );
    final totalCommission = docs.fold<double>(
      0,
      (total, doc) => total + _commissionAmount(doc.data()),
    );
    final settled = docs
        .where((doc) => _isSettled(doc.data()))
        .fold<double>(0, (total, doc) => total + _commissionAmount(doc.data()));
    final frozen = docs
        .where((doc) => _isFrozen(doc.data()))
        .fold<double>(0, (total, doc) => total + _commissionAmount(doc.data()));
    final yetToSettle = totalCommission - settled;
    final selectedTotal = docs
        .where((doc) => _selectedIds.contains(doc.id))
        .fold<double>(0, (total, doc) => total + _commissionAmount(doc.data()));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cards = [
                _summary('Policies', docs.length.toString()),
                _summary('Premium', _money(premium)),
                _summary('Commission', _money(totalCommission)),
                _summary('Amount settled', _money(settled), color: _green),
                _summary('Frozen invoice', _money(frozen), color: _primary),
                _summary('Yet to settle', _money(yetToSettle), color: _orange),
                _summary('Selected', _money(selectedTotal), color: _primary),
              ];
              if (constraints.maxWidth < 900) {
                return Wrap(
                  runSpacing: 10,
                  spacing: 10,
                  children: cards
                      .map((c) => SizedBox(width: 220, child: c))
                      .toList(),
                );
              }
              return Row(
                children: cards
                    .map(
                      (card) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: card,
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ),
        _actionBar(docs),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 900) {
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: docs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, index) => _mobileRow(docs[index]),
                );
              }
              return _table(docs);
            },
          ),
        ),
      ],
    );
  }

  Widget _summary(String label, String value, {Color? color}) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _surface,
      border: Border.all(color: _border),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: _muted, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    ),
  );

  Widget _actionBar(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final openCount = docs.where((doc) => _isOpen(doc.data())).length;
    final frozenCount = docs.where((doc) => _isFrozen(doc.data())).length;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final actions = [
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _selectAllOpen(docs),
              icon: const Icon(Icons.done_all_rounded, size: 18),
              label: Text('Select open ($openCount)'),
            ),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _selectAllFrozen(docs),
              icon: const Icon(Icons.inventory_2_rounded, size: 18),
              label: Text('Select frozen ($frozenCount)'),
            ),
            OutlinedButton(
              onPressed: _busy ? null : () => _unselectVisible(docs),
              child: const Text('Unselect visible'),
            ),
            OutlinedButton(
              onPressed: _busy ? null : () => setState(_selectedIds.clear),
              child: const Text('Clear all'),
            ),
            SwitchListTile.adaptive(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Include CGST + SGST'),
              subtitle: const Text('Adds CGST@9% and SGST@9% in invoice'),
              value: _includeGst,
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _includeGst = value),
            ),
            FilledButton.icon(
              onPressed: _busy ? null : () => _generateInvoiceAndFreeze(docs),
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.receipt_long_rounded, size: 18),
              label: const Text('Generate invoice & freeze'),
              style: FilledButton.styleFrom(backgroundColor: _primary),
            ),
            TextButton.icon(
              onPressed: _busy ? null : () => _markSelectedSettled(docs),
              icon: const Icon(Icons.lock_rounded, size: 18),
              label: const Text('Mark selected settled'),
            ),
          ];

          if (constraints.maxWidth < 920) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: actions
                  .map(
                    (w) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: w,
                    ),
                  )
                  .toList(),
            );
          }
          return Row(
            children: [
              actions[0],
              const SizedBox(width: 8),
              actions[1],
              const SizedBox(width: 8),
              actions[2],
              const SizedBox(width: 8),
              actions[3],
              const SizedBox(width: 14),
              SizedBox(width: 250, child: actions[4]),
              const Spacer(),
              actions[6],
              const SizedBox(width: 8),
              actions[5],
            ],
          );
        },
      ),
    );
  }

  Widget _table(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) =>
      SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 1180),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFEFF6FF)),
              columns: const [
                DataColumn(label: Text('Select')),
                DataColumn(label: Text('Customer')),
                DataColumn(label: Text('Unique ID')),
                DataColumn(label: Text('Policy No.')),
                DataColumn(label: Text('Product')),
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Premium')),
                DataColumn(label: Text('Rate')),
                DataColumn(label: Text('Commission')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Action')),
              ],
              rows: docs.map((doc) {
                final data = doc.data();
                final settled = _isSettled(data);
                final open = _isOpen(data);
                final selected = _selectedIds.contains(doc.id);
                return DataRow(
                  selected: selected,
                  cells: [
                    DataCell(
                      Checkbox(
                        value: selected,
                        onChanged: settled || _busy
                            ? null
                            : (value) => setState(() {
                                if (value == true) {
                                  _selectedIds.add(doc.id);
                                } else {
                                  _selectedIds.remove(doc.id);
                                }
                              }),
                      ),
                    ),
                    DataCell(Text((data['customerName'] ?? '-').toString())),
                    DataCell(
                      Text(
                        leadUniqueIdFromData(data).isEmpty
                            ? '-'
                            : leadUniqueIdFromData(data),
                      ),
                    ),
                    DataCell(Text((data['policyNumber'] ?? '-').toString())),
                    DataCell(
                      Text(
                        (data['productName'] ?? data['policyName'] ?? '-')
                            .toString(),
                      ),
                    ),
                    DataCell(Text(_dateLabel(_recordDate(data)))),
                    DataCell(Text(_money(_number(data['premiumAmount'])))),
                    DataCell(Text(_percent(_commissionPercent(data)))),
                    DataCell(
                      Text(
                        _money(_commissionAmount(data)),
                        style: const TextStyle(
                          color: _green,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    DataCell(_statusPill(data)),
                    DataCell(
                      TextButton(
                        onPressed: !open || _busy
                            ? null
                            : () => _overrideCommission(doc),
                        child: Text(
                          data['commissionOverridden'] == true
                              ? 'Edit override'
                              : 'Override',
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      );

  Widget _mobileRow(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final settled = _isSettled(data);
    final open = _isOpen(data);
    final selected = _selectedIds.contains(doc.id);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: selected ? _primary : _border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: selected,
                onChanged: settled || _busy
                    ? null
                    : (value) => setState(() {
                        if (value == true) {
                          _selectedIds.add(doc.id);
                        } else {
                          _selectedIds.remove(doc.id);
                        }
                      }),
              ),
              Expanded(
                child: Text(
                  (data['customerName'] ?? '-').toString(),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              _statusPill(data),
            ],
          ),
          Text(
            '${data['policyNumber'] ?? '-'} | ${data['productName'] ?? data['policyName'] ?? '-'}',
            style: const TextStyle(color: _muted),
          ),
          const SizedBox(height: 8),
          Text(
            '${_dateLabel(_recordDate(data))} | Premium ${_money(_number(data['premiumAmount']))} | ${_percent(_commissionPercent(data))} | ${_money(_commissionAmount(data))}',
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: !open || _busy ? null : () => _overrideCommission(doc),
              child: Text(
                data['commissionOverridden'] == true
                    ? 'Edit override'
                    : 'Override commission',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(Map<String, dynamic> data) {
    final settled = _isSettled(data);
    final frozen = _isFrozen(data);
    final label = settled
        ? 'Settled / locked'
        : frozen
        ? 'Invoice frozen'
        : 'Open';
    final fg = settled
        ? _green
        : frozen
        ? _primary
        : _orange;
    final bg = settled
        ? const Color(0xFFEAF7EE)
        : frozen
        ? const Color(0xFFEFF6FF)
        : const Color(0xFFFFF7ED);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w800),
      ),
    );
  }
}
