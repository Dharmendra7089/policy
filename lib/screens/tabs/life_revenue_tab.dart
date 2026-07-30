import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../utils/commission_engine.dart';

class LifeRevenueTab extends StatefulWidget {
  const LifeRevenueTab({super.key});

  @override
  State<LifeRevenueTab> createState() => _LifeRevenueTabState();
}

class _LifeRevenueTabState extends State<LifeRevenueTab> {
  static const _primary = Color(0xFF0D2D4F);
  static const _accent = Color(0xFF1A6EBD);
  static const _bg = Color(0xFFF4F6F9);
  static const _surface = Color(0xFFFFFFFF);
  static const _border = Color(0xFFE4E7EC);
  static const _textMain = Color(0xFF0D1B2A);
  static const _textMuted = Color(0xFF8A94A6);
  static const _green = Color(0xFF16A34A);
  static const _amber = Color(0xFFF59E0B);
  String? _selectedPolicyId;
  Map<String, dynamic>? _selectedPolicy;
  DateTime? _fromDate;
  DateTime? _toDate;
  final Set<String> _selectedRows = {};
  bool _selectAll = false;
  bool _isWriting = false;

  Stream<QuerySnapshot<Map<String, dynamic>>> get _policyStream =>
      FirebaseFirestore.instance
          .collection('life_policies')
          .where('status', isEqualTo: 'Active')
          .snapshots();

  static double _num(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(
          (value ?? '').toString().replaceAll(',', '').trim(),
        ) ??
        0;
  }

  static String _money(double value) {
    if (value >= 10000000) {
      return 'Rs ${(value / 10000000).toStringAsFixed(2)} Cr';
    }
    if (value >= 100000) {
      return 'Rs ${(value / 100000).toStringAsFixed(2)} L';
    }
    return 'Rs ${value.toStringAsFixed(0)}';
  }

  static String _date(dynamic value) {
    DateTime? date;
    if (value is Timestamp) date = value.toDate();
    if (value is DateTime) date = value;
    if (date == null) return value?.toString() ?? '-';
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  DateTime? _dateValue(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  bool _inSchedule(Map<String, dynamic> row) {
    if (_fromDate == null || _toDate == null) return false;
    final event =
        _dateValue(row['issueDate']) ??
        _dateValue(row['policyStartDate']) ??
        _dateValue(row['startDate']);
    if (event == null) return false;
    final day = DateTime(event.year, event.month, event.day);
    final from = DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day);
    final to = DateTime(_toDate!.year, _toDate!.month, _toDate!.day);
    return !day.isBefore(from) && !day.isAfter(to);
  }

  bool _isSettled(Map<String, dynamic> row) =>
      (row['settled'] ?? 'Not Settled').toString() == 'Settled';

  Map<String, dynamic>? _commissionGroup(
    Map<String, dynamic> policy,
    Map<String, dynamic> row,
  ) {
    final rawGroups = policy['lifeCommissions'];
    if (rawGroups is! List || rawGroups.isEmpty) return null;
    final effectiveDate =
        _dateValue(row['issueDate']) ??
        _dateValue(row['policyStartDate']) ??
        DateTime.now();
    for (final raw in rawGroups) {
      if (raw is! Map) continue;
      final group = Map<String, dynamic>.from(raw);
      final from = _dateValue(group['startDate']);
      final to = _dateValue(group['endDate']);
      if (from != null &&
          to != null &&
          !effectiveDate.isBefore(from) &&
          !effectiveDate.isAfter(to)) {
        return group;
      }
    }
    return rawGroups.last is Map
        ? Map<String, dynamic>.from(rawGroups.last as Map)
        : null;
  }

  int _termYears(Map<String, dynamic> row) {
    final termText = (row['policyTerm'] ?? '').toString();
    final match = RegExp(r'\d+').firstMatch(termText);
    if (match != null) return int.parse(match.group(0)!);
    final start = _dateValue(row['policyStartDate'] ?? row['startDate']);
    final end = _dateValue(row['policyEndDate'] ?? row['endDate']);
    if (start == null || end == null) return 0;
    final days = end.difference(start).inDays + 1;
    return (days / 365).round().clamp(1, 100);
  }

  _LifeCommission _calculation(
    Map<String, dynamic> policy,
    Map<String, dynamic> row,
  ) {
    if (policy['commissionRules'] is List) {
      final calculated = CommissionEngine.calculate(policy, row);
      return _LifeCommission(
        type: 'Policy Rule',
        label: calculated.rule,
        termYears: _termYears(row),
        percent: calculated.percent,
        amount: calculated.amount,
      );
    }
    final premium = _num(row['premiumAmount'] ?? row['premium']);
    final termYears = _termYears(row);
    final manualPercent = _num(row['manualSlabPercent']);
    if (manualPercent > 0) {
      final note = (row['manualSlabNote'] ?? '').toString();
      return _LifeCommission(
        type: 'Manual Override',
        label: note.isEmpty ? 'Manual slab override' : note,
        termYears: termYears,
        percent: manualPercent,
        amount: premium * manualPercent / 100,
      );
    }
    final group = _commissionGroup(policy, row);
    final slabs = group?['slabs'];
    if (slabs is List && slabs.isNotEmpty && slabs.first is Map) {
      final slab = Map<String, dynamic>.from(slabs.first as Map);
      final label = (slab['label'] ?? '').toString();
      if ((slab['slabType'] ?? 'premium').toString() == 'term') {
        final multiplier = _num(slab['multiplier']);
        final percent = termYears * multiplier;
        return _LifeCommission(
          type: 'Term',
          label: label,
          termYears: termYears,
          multiplier: multiplier,
          percent: percent,
          amount: premium * percent / 100,
        );
      }
      final percent = _num(slab['percent']);
      return _LifeCommission(
        type: 'Premium',
        label: label,
        termYears: termYears,
        percent: percent,
        amount: premium * percent / 100,
      );
    }
    final percent = _num(
      policy['renewalCommission'] ?? policy['renewalCommissionPercent'],
    );
    return _LifeCommission(
      type: 'Renewal Fallback',
      label: 'No life slab configured',
      termYears: termYears,
      percent: percent,
      amount: premium * percent / 100,
    );
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate:
          (isStart ? _fromDate : _toDate) ?? _fromDate ?? DateTime.now(),
      helpText: isStart ? 'Select Start Date' : 'Select End Date',
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _fromDate = picked;
        if (_toDate != null && _toDate!.isBefore(picked)) _toDate = picked;
      } else {
        _toDate = picked;
      }
      _selectedRows.clear();
      _selectAll = false;
    });
  }

  Future<void> _editDate(String docId, String field, dynamic value) async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: _dateValue(value) ?? DateTime.now(),
      helpText: field == 'policyStartDate'
          ? 'Select Policy Active Date'
          : 'Select Policy Expiry Date',
    );
    if (picked == null) return;
    await FirebaseFirestore.instance
        .collection('customer_policies')
        .doc(docId)
        .update({field: Timestamp.fromDate(picked)});
  }

  Future<void> _generateRevenue(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final policy = _selectedPolicy;
    if (policy == null || docs.isEmpty) return;
    setState(() => _isWriting = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final document in docs) {
        final data = document.data();
        final result = _calculation(policy, data);
        final generated = {
          'commissionPercent': result.percent,
          'commissionAmount': result.amount,
          'revenue': result.amount,
          'commissionRule': result.description,
          'revenueGeneratedFromSlab': true,
          'revenueGeneratedAt': FieldValue.serverTimestamp(),
        };
        batch.update(document.reference, generated);
        final matchingRevenue = await FirebaseFirestore.instance
            .collection('revenue')
            .where('policyNumber', isEqualTo: data['policyNumber'])
            .get();
        for (final revenue in matchingRevenue.docs) {
          if ((revenue.data()['category'] ?? '').toString() == 'Life') {
            batch.update(revenue.reference, generated);
          }
        }
      }
      batch.set(FirebaseFirestore.instance.collection('logs').doc(), {
        'page': 'Life Revenue',
        'action': 'Generated Revenue From Slabs',
        'description':
            'Generated ${docs.length} Life commission entries using configured policy slabs.',
        'policyId': _selectedPolicyId,
        'policyName': policy['planName'] ?? '',
        'timestamp': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Revenue generated from Life slabs for ${docs.length} customers.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isWriting = false);
    }
  }

  Future<void> _markSelectedSettled(
    String value,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final policy = _selectedPolicy;
    if (policy == null || docs.isEmpty || _selectedRows.isEmpty) return;
    setState(() => _isWriting = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      final now = FieldValue.serverTimestamp();
      for (final id in _selectedRows) {
        final document = docs.firstWhere((doc) => doc.id == id);
        final calculation = _calculation(policy, document.data());
        batch.update(document.reference, {
          'settled': value,
          'settledSlabPercent': calculation.percent,
          'settledCommissionAmount': calculation.amount,
          'settledAt': now,
        });
        final ledgerRef = FirebaseFirestore.instance
            .collection('life_policies')
            .doc(_selectedPolicyId)
            .collection('settlement_ledger')
            .doc(id);
        batch.set(ledgerRef, {
          'customerPolicyId': id,
          'settled': value,
          'settledAt': now,
          'settledSlabPercent': calculation.percent,
          'settledCommissionAmount': calculation.amount,
          'policyId': _selectedPolicyId,
          'updatedAt': now,
        }, SetOptions(merge: true));
      }
      await batch.commit();
      if (!mounted) return;
      setState(() {
        _selectedRows.clear();
        _selectAll = false;
      });
    } finally {
      if (mounted) setState(() => _isWriting = false);
    }
  }

  Future<void> _showOverrideDialog({
    required String docId,
    required Map<String, dynamic> row,
    required Map<String, dynamic> policy,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final changedBy =
        (user?.displayName?.isNotEmpty == true
            ? user!.displayName
            : user?.email) ??
        'Admin';
    final existing = _num(row['manualSlabPercent']);
    final percentCtrl = TextEditingController(
      text: existing > 0 ? existing.toStringAsFixed(2) : '',
    );
    final noteCtrl = TextEditingController(
      text: (row['manualSlabNote'] ?? '').toString(),
    );
    final managementNameCtrl = TextEditingController(
      text: (row['manualSlabManagementName'] ?? '').toString(),
    );
    var permissionSource = (row['manualSlabPermissionSource'] ?? 'MD Sir')
        .toString();
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        var saving = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            Future<void> save() async {
              final percent = double.tryParse(percentCtrl.text.trim());
              final note = noteCtrl.text.trim();
              if (percent == null || percent <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter a valid percentage.')),
                );
                return;
              }
              if (note.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Reason / note is required.')),
                );
                return;
              }
              if (permissionSource != 'MD Sir' &&
                  permissionSource != 'Senior Management') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Select who gave permission.')),
                );
                return;
              }
              final managementName = managementNameCtrl.text.trim();
              if (managementName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter management name.')),
                );
                return;
              }
              setDialogState(() => saving = true);
              try {
                final batch = FirebaseFirestore.instance.batch();
                final now = FieldValue.serverTimestamp();
                batch.update(
                  FirebaseFirestore.instance
                      .collection('customer_policies')
                      .doc(docId),
                  {
                    'manualSlabPercent': percent,
                    'manualSlabNote': note,
                    'manualSlabPermissionSource': permissionSource,
                    'manualSlabManagementName': managementName,
                    'manualSlabChangedBy': user?.uid ?? '',
                    'manualSlabChangedByName': changedBy,
                    'manualSlabChangedAt': now,
                    'updatedAt': now,
                  },
                );
                batch.set(FirebaseFirestore.instance.collection('logs').doc(), {
                  'page': 'Life Revenue',
                  'action': 'Manual Slab Override',
                  'customerPolicyId': docId,
                  'policyId': _selectedPolicyId,
                  'policyName': policy['planName'] ?? '',
                  'customerName': row['customerName'] ?? '',
                  'previousPercent': _calculation(policy, row).percent,
                  'newPercent': percent,
                  'reason': note,
                  'permissionSource': permissionSource,
                  'managementName': managementName,
                  'changedBy': changedBy,
                  'changedByUid': user?.uid ?? '',
                  'timestamp': now,
                });
                await batch.commit();
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (error) {
                if (!ctx.mounted) return;
                setDialogState(() => saving = false);
                ScaffoldMessenger.of(
                  ctx,
                ).showSnackBar(SnackBar(content: Text('Error: $error')));
              }
            }

            return AlertDialog(
              title: const Text(
                'Override Slab %',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: percentCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'New Percentage *',
                        hintText: 'e.g. 12.5',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: permissionSource,
                      decoration: const InputDecoration(
                        labelText: 'Permission Given By *',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'MD Sir',
                          child: Text('MD Sir'),
                        ),
                        DropdownMenuItem(
                          value: 'Senior Management',
                          child: Text('Senior Management'),
                        ),
                      ],
                      onChanged: saving
                          ? null
                          : (value) => setDialogState(
                              () => permissionSource = value ?? 'MD Sir',
                            ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: managementNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Management Name *',
                        hintText: 'Enter approver name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: noteCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Reason / Note *',
                        hintText: 'Why are you changing this percentage?',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Changed by: $changedBy',
                        style: const TextStyle(color: _textMuted, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: saving ? null : save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                  ),
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save Override'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            const Divider(height: 1, color: _border),
            Expanded(
              child: _selectedPolicy == null
                  ? _policySelection()
                  : _policyRevenue(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return Container(
      color: _surface,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (_selectedPolicy != null) ...[
            IconButton(
              onPressed: () => setState(() {
                _selectedPolicyId = null;
                _selectedPolicy = null;
                _fromDate = null;
                _toDate = null;
                _selectedRows.clear();
                _selectAll = false;
              }),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(width: 8),
          ],
          const Expanded(
            child: Text(
              'Life Revenue',
              style: TextStyle(
                color: _textMain,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          if (_isWriting)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }

  Widget _policySelection() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _policyStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final policies =
            (snapshot.data?.docs ?? [])
                .map((doc) => {'id': doc.id, ...doc.data()})
                .toList()
              ..sort(
                (a, b) => (a['planName'] ?? '').toString().compareTo(
                  (b['planName'] ?? '').toString(),
                ),
              );
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Select Life Policy',
              style: TextStyle(
                fontSize: 20,
                color: _textMain,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Choose a policy, choose the issue-date schedule, then generate commission from its Life slabs.',
              style: TextStyle(color: _textMuted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedPolicyId,
              hint: const Text('Search / select Life policy'),
              isExpanded: true,
              items: policies
                  .map(
                    (policy) => DropdownMenuItem<String>(
                      value: policy['id'].toString(),
                      child: Text(
                        '${policy['planName']} - ${policy['policyCode']} - ${policy['companyName']}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (id) {
                final selected = policies.firstWhere(
                  (policy) => policy['id'].toString() == id,
                );
                setState(() {
                  _selectedPolicyId = id;
                  _selectedPolicy = selected;
                  _fromDate = null;
                  _toDate = null;
                  _selectedRows.clear();
                  _selectAll = false;
                });
              },
              decoration: _fieldDecoration(),
            ),
          ],
        );
      },
    );
  }

  Widget _policyRevenue() {
    final policy = _selectedPolicy!;
    final policyId = _selectedPolicyId!;
    final groups = policy['lifeCommissions'];
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('customer_policies')
          .where('policyId', isEqualTo: policyId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = _fromDate != null && _toDate != null
            ? (snapshot.data?.docs ?? [])
                  .where((doc) => _inSchedule(doc.data()))
                  .toList()
            : <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        var premiumTotal = 0.0;
        var commissionTotal = 0.0;
        var settledTotal = 0.0;
        for (final doc in docs) {
          final row = doc.data();
          final premium = _num(row['premiumAmount'] ?? row['premium']);
          final calculation = _calculation(policy, row);
          final settled = _isSettled(row);
          final commission = settled
              ? _num(row['settledCommissionAmount'] ?? row['commissionAmount'])
              : calculation.amount;
          premiumTotal += premium;
          commissionTotal += commission;
          if (settled) settledTotal += commission;
        }
        final yetToSettleTotal = commissionTotal - settledTotal;
        final unsettledDocs = docs
            .where((doc) => !_isSettled(doc.data()))
            .toList();
        final docIds = docs.map((doc) => doc.id).toSet();
        _selectedRows.removeWhere((id) => !docIds.contains(id));
        _selectAll =
            unsettledDocs.isNotEmpty &&
            _selectedRows.length == unsettledDocs.length;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              '${policy['planName']} - ${policy['policyCode']}',
              style: const TextStyle(
                fontSize: 20,
                color: _textMain,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 16),
            _Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Choose Issue Date Schedule',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _dateButton(
                          _fromDate == null ? 'Start Date' : _date(_fromDate),
                          () => _pickDate(isStart: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _dateButton(
                          _toDate == null ? 'End Date' : _date(_toDate),
                          () => _pickDate(isStart: false),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _slabPanel(groups),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _Metric(
                  'Customers',
                  '${docs.length}',
                  Icons.people_outline,
                  _primary,
                ),
                _Metric(
                  'Premium',
                  _money(premiumTotal),
                  Icons.currency_rupee,
                  _accent,
                ),
                _Metric(
                  'Commission',
                  _money(commissionTotal),
                  Icons.payments_outlined,
                  _green,
                ),
                _Metric(
                  'Settled',
                  _money(settledTotal),
                  Icons.verified_outlined,
                  _green,
                ),
                _Metric(
                  'Yet to Settle',
                  _money(yetToSettleTotal),
                  Icons.pending_actions_outlined,
                  _amber,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Linked Customers And Calculated Revenue',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (docs.isNotEmpty)
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _selectAll = !_selectAll;
                              if (_selectAll) {
                                _selectedRows
                                  ..clear()
                                  ..addAll(unsettledDocs.map((doc) => doc.id));
                              } else {
                                _selectedRows.clear();
                              }
                            });
                          },
                          icon: Icon(
                            _selectAll
                                ? Icons.check_box
                                : Icons.check_box_outline_blank,
                          ),
                          label: Text(
                            _selectAll ? 'Unselect All' : 'Select All',
                          ),
                        ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: docs.isEmpty || _isWriting
                            ? null
                            : () => _generateRevenue(docs),
                        icon: const Icon(Icons.calculate_outlined, size: 16),
                        label: const Text('Generate Revenue'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _selectedRows.isEmpty || _isWriting
                            ? null
                            : () => _markSelectedSettled('Settled', docs),
                        icon: const Icon(Icons.done_all_rounded, size: 16),
                        label: const Text('Mark Settled'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _selectedRows.isEmpty || _isWriting
                            ? null
                            : () => _markSelectedSettled('Not Settled', docs),
                        icon: const Icon(Icons.undo_rounded, size: 16),
                        label: const Text('Mark Not Settled'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_fromDate == null || _toDate == null)
                    const Text(
                      'Select start and end dates to load customers.',
                      style: TextStyle(color: _textMuted),
                    )
                  else if (docs.isEmpty)
                    const Text(
                      'No customers found in this schedule.',
                      style: TextStyle(color: _textMuted),
                    )
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        showCheckboxColumn: false,
                        columns: const [
                          DataColumn(label: Text('Select')),
                          DataColumn(label: Text('Customer')),
                          DataColumn(label: Text('Policy No')),
                          DataColumn(label: Text('Issued Date')),
                          DataColumn(label: Text('Term Years')),
                          DataColumn(label: Text('Premium')),
                          DataColumn(label: Text('Rule')),
                          DataColumn(label: Text('Percent')),
                          DataColumn(label: Text('Commission')),
                          DataColumn(label: Text('Active Date')),
                          DataColumn(label: Text('Expiry Date')),
                          DataColumn(label: Text('Settled')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Override')),
                        ],
                        rows: docs.map((doc) {
                          final row = doc.data();
                          final id = doc.id;
                          final value = _calculation(policy, row);
                          final settled = _isSettled(row);
                          final premium = _num(
                            row['premiumAmount'] ?? row['premium'],
                          );
                          final percent = settled
                              ? _num(
                                  row['settledSlabPercent'] ??
                                      row['commissionPercent'],
                                )
                              : value.percent;
                          final commission = settled
                              ? _num(
                                  row['settledCommissionAmount'] ??
                                      row['commissionAmount'],
                                )
                              : value.amount;
                          final hasManual =
                              _num(row['manualSlabPercent']) > 0 && !settled;
                          return DataRow(
                            selected: _selectedRows.contains(id),
                            cells: [
                              DataCell(
                                settled
                                    ? const Icon(
                                        Icons.lock_rounded,
                                        color: _textMuted,
                                        size: 18,
                                      )
                                    : Checkbox(
                                        value: _selectedRows.contains(id),
                                        onChanged: (checked) {
                                          setState(() {
                                            if (checked == true) {
                                              _selectedRows.add(id);
                                            } else {
                                              _selectedRows.remove(id);
                                            }
                                            _selectAll =
                                                unsettledDocs.isNotEmpty &&
                                                _selectedRows.length ==
                                                    unsettledDocs.length;
                                          });
                                        },
                                      ),
                              ),
                              DataCell(
                                Text((row['customerName'] ?? '').toString()),
                              ),
                              DataCell(
                                Text((row['policyNumber'] ?? '').toString()),
                              ),
                              DataCell(
                                Text(
                                  _date(
                                    row['issueDate'] ?? row['policyStartDate'],
                                  ),
                                ),
                              ),
                              DataCell(Text('${value.termYears}')),
                              DataCell(Text(_money(premium))),
                              DataCell(Text(value.description)),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('${percent.toStringAsFixed(2)}%'),
                                    if (hasManual) ...[
                                      const SizedBox(width: 4),
                                      Tooltip(
                                        message:
                                            'Manual override\n${row['manualSlabNote'] ?? ''}',
                                        child: const Icon(
                                          Icons.edit_note_rounded,
                                          size: 14,
                                          color: _amber,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              DataCell(Text(_money(commission))),
                              DataCell(
                                settled
                                    ? Text(
                                        _date(
                                          row['policyStartDate'] ??
                                              row['startDate'],
                                        ),
                                      )
                                    : _dateCell(
                                        docId: id,
                                        field: 'policyStartDate',
                                        value:
                                            row['policyStartDate'] ??
                                            row['startDate'],
                                      ),
                              ),
                              DataCell(
                                settled
                                    ? Text(
                                        _date(
                                          row['policyEndDate'] ??
                                              row['endDate'],
                                        ),
                                      )
                                    : _dateCell(
                                        docId: id,
                                        field: 'policyEndDate',
                                        value:
                                            row['policyEndDate'] ??
                                            row['endDate'],
                                      ),
                              ),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: settled
                                        ? _green.withValues(alpha: 0.1)
                                        : _amber.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    settled ? 'Settled' : 'Not Settled',
                                    style: TextStyle(
                                      color: settled ? _green : _amber,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                Text((row['status'] ?? 'Active').toString()),
                              ),
                              DataCell(
                                settled
                                    ? const SizedBox.shrink()
                                    : TextButton.icon(
                                        onPressed: () => _showOverrideDialog(
                                          docId: id,
                                          row: row,
                                          policy: policy,
                                        ),
                                        icon: const Icon(
                                          Icons.edit_rounded,
                                          size: 14,
                                        ),
                                        label: const Text('Override'),
                                        style: TextButton.styleFrom(
                                          foregroundColor: _primary,
                                        ),
                                      ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _slabPanel(dynamic groups) {
    final rows = <Widget>[];
    if (groups is List) {
      for (final rawGroup in groups) {
        if (rawGroup is! Map) continue;
        final slabs = rawGroup['slabs'];
        if (slabs is! List) continue;
        for (final rawSlab in slabs) {
          if (rawSlab is! Map) continue;
          final type = (rawSlab['slabType'] ?? 'premium').toString();
          final calculation = type == 'term'
              ? 'Term years x ${_num(rawSlab['multiplier']).toStringAsFixed(2)}'
              : '${_num(rawSlab['percent']).toStringAsFixed(2)}% of premium';
          rows.add(
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Expanded(child: Text((rawSlab['label'] ?? '-').toString())),
                  Text(type == 'term' ? 'Term' : 'Premium'),
                  const SizedBox(width: 24),
                  Text(
                    calculation,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          );
        }
      }
    }
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Life Commission Slabs',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'No Life slabs configured.',
                style: TextStyle(color: _textMuted),
              ),
            )
          else
            ...rows,
        ],
      ),
    );
  }

  Widget _dateCell({
    required String docId,
    required String field,
    required dynamic value,
  }) {
    return SizedBox(
      width: 120,
      child: TextFormField(
        initialValue: _date(value),
        readOnly: true,
        decoration: const InputDecoration(
          isDense: true,
          border: OutlineInputBorder(),
        ),
        onTap: () => _editDate(docId, field, value),
      ),
    );
  }

  Widget _dateButton(String label, VoidCallback onPressed) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.date_range_outlined),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        alignment: Alignment.centerLeft,
      ),
    );
  }

  InputDecoration _fieldDecoration() => InputDecoration(
    filled: true,
    fillColor: _surface,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: _border),
    ),
  );
}

class _LifeCommission {
  final String type;
  final String label;
  final int termYears;
  final double multiplier;
  final double percent;
  final double amount;

  const _LifeCommission({
    required this.type,
    required this.label,
    this.termYears = 0,
    this.multiplier = 0,
    required this.percent,
    required this.amount,
  });

  String get description => type == 'Term'
      ? '$termYears years x ${multiplier.toStringAsFixed(2)}'
      : label.isEmpty
      ? type
      : '$type - $label';
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _Metric(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _LifeRevenueTabState._surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _LifeRevenueTabState._border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          Text(
            label,
            style: const TextStyle(color: _LifeRevenueTabState._textMuted),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;

  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _LifeRevenueTabState._surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _LifeRevenueTabState._border),
      ),
      child: child,
    );
  }
}
