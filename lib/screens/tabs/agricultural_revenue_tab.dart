import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AgriculturalRevenueTab extends StatefulWidget {
  final String category;
  final String title;

  const AgriculturalRevenueTab({
    super.key,
    this.category = 'Agricultural',
    this.title = 'Agricultural Revenue',
  });

  @override
  State<AgriculturalRevenueTab> createState() => _AgriculturalRevenueTabState();
}

class _AgriculturalRevenueTabState extends State<AgriculturalRevenueTab> {
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
  bool _isUpdating = false;

  // ─── Streams ───────────────────────────────────────────────────────────────

  Stream<QuerySnapshot<Map<String, dynamic>>> get _policyStream =>
      FirebaseFirestore.instance
          .collection('agricultural_policies')
          .where('category', isEqualTo: widget.category)
          .where('status', isEqualTo: 'Active')
          .snapshots();

  // ─── Formatters ────────────────────────────────────────────────────────────

  static String _fmtMoney(double v) {
    if (v >= 10000000) return 'Rs ${(v / 10000000).toStringAsFixed(2)} Cr';
    if (v >= 100000) return 'Rs ${(v / 100000).toStringAsFixed(2)} L';
    return 'Rs ${v.toStringAsFixed(0)}';
  }

  static double _num(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse((v ?? '').toString().replaceAll(',', '').trim()) ??
        0;
  }

  static String _fmtDate(dynamic v) {
    if (v == null) return '-';
    if (v is Timestamp) {
      final d = v.toDate();
      return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
    }
    if (v is DateTime) {
      return '${v.day.toString().padLeft(2, '0')}.${v.month.toString().padLeft(2, '0')}.${v.year}';
    }
    return v.toString();
  }

  static String _compactDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  // ─── Helpers ───────────────────────────────────────────────────────────────

  DateTime? _asDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  bool _withinRange(dynamic value, DateTime from, DateTime to) {
    final d = _asDate(value);
    if (d == null) return false;
    final x = DateTime(d.year, d.month, d.day);
    final f = DateTime(from.year, from.month, from.day);
    final t = DateTime(to.year, to.month, to.day);
    return !x.isBefore(f) && !x.isAfter(t);
  }

  bool _isSettled(Map<String, dynamic> row) =>
      (row['settled'] ?? 'Not Settled').toString() == 'Settled';

  // ─── Slab logic ────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> _generalSlabs(Map<String, dynamic> policy) {
    final groups = policy['agriculturalCommissions'];
    if (groups is! List) return [];
    final result = <Map<String, dynamic>>[];
    for (final group in groups) {
      if (group is! Map) continue;
      final slabs = group['slabs'];
      if (slabs is! List) continue;
      for (final slab in slabs) {
        if (slab is Map) result.add(Map<String, dynamic>.from(slab));
      }
    }
    return result;
  }

  /// For a not-settled row: use manualSlabPercent if set, else selected slab.
  double _effectivePct(Map<String, dynamic> row, Map<String, dynamic> policy) {
    final manual = _num(row['manualSlabPercent']);
    if (manual > 0) return manual;
    final selected = _num(row['selectedSlabPercent']);
    if (selected > 0) return selected;
    final slab = row['selectedAgriculturalSlab'];
    if (slab is Map) {
      final pct = _num(slab['percent']);
      if (pct > 0) return pct;
    }
    return _num(
      policy['renewalCommission'] ?? policy['renewalCommissionPercent'],
    );
  }

  double _commissionAmountForRow(
    Map<String, dynamic> row,
    Map<String, dynamic> policy,
  ) {
    final premium = _num(row['premiumAmount'] ?? row['premium']);
    return (premium * _effectivePct(row, policy)) / 100;
  }

  // ─── Date pickers ──────────────────────────────────────────────────────────

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: _fromDate ?? DateTime.now(),
      helpText: 'Select Start Date',
      builder: (c, child) => Theme(
        data: Theme.of(
          c,
        ).copyWith(colorScheme: const ColorScheme.light(primary: _primary)),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _fromDate = picked;
        if (_toDate != null && _toDate!.isBefore(_fromDate!)) {
          _toDate = _fromDate;
        }
        _selectedRows.clear();
        _selectAll = false;
      });
    }
  }

  Future<void> _pickToDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: _toDate ?? (_fromDate ?? DateTime.now()),
      helpText: 'Select End Date',
      builder: (c, child) => Theme(
        data: Theme.of(
          c,
        ).copyWith(colorScheme: const ColorScheme.light(primary: _primary)),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _toDate = picked;
        _selectedRows.clear();
        _selectAll = false;
      });
    }
  }

  Future<void> _editDate(String docId, String field, dynamic value) async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: value is Timestamp ? value.toDate() : DateTime.now(),
      builder: (c, child) => Theme(
        data: Theme.of(
          c,
        ).copyWith(colorScheme: const ColorScheme.light(primary: _primary)),
        child: child!,
      ),
    );
    if (picked != null) {
      await FirebaseFirestore.instance
          .collection('customer_policies')
          .doc(docId)
          .update({field: Timestamp.fromDate(picked)});
    }
  }

  // ─── Settle / Unsettle ─────────────────────────────────────────────────────

  Future<void> _markSelectedSettled(
    String value,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    if (_selectedRows.isEmpty || _selectedPolicyId == null) return;
    setState(() => _isUpdating = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      final now = FieldValue.serverTimestamp();

      for (final id in _selectedRows) {
        final docSnap = docs.firstWhere((d) => d.id == id);
        final data = docSnap.data();
        final policy = _selectedPolicy!;
        final premium = _num(data['premiumAmount'] ?? data['premium']);
        final pct = _effectivePct(data, policy);
        final commission = (premium * pct) / 100;

        final ref = FirebaseFirestore.instance
            .collection('customer_policies')
            .doc(id);
        batch.update(ref, {
          'settled': value,
          'settledAt': now,
          // Freeze the amounts at the moment of settlement
          'settledSlabPercent': pct,
          'settledCommissionAmount': commission,
        });

        final ledgerRef = FirebaseFirestore.instance
            .collection('policies')
            .doc(_selectedPolicyId)
            .collection('settlement_ledger')
            .doc(id);
        batch.set(ledgerRef, {
          'customerPolicyId': id,
          'settled': value,
          'settledAt': now,
          'settledSlabPercent': pct,
          'settledCommissionAmount': commission,
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
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  // ─── Admin override dialog ─────────────────────────────────────────────────

  Future<void> _showOverrideDialog({
    required String docId,
    required Map<String, dynamic> row,
    required Map<String, dynamic> policy,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final name =
        (user?.displayName?.isNotEmpty == true
            ? user!.displayName
            : user?.email) ??
        'Admin';

    final percentCtrl = TextEditingController(
      text: _num(row['manualSlabPercent']) > 0
          ? _num(row['manualSlabPercent']).toStringAsFixed(2)
          : '',
    );
    final noteCtrl = TextEditingController();
    final managementNameCtrl = TextEditingController(
      text: (row['manualSlabManagementName'] ?? '').toString(),
    );
    String permissionSource = (row['manualSlabPermissionSource'] ?? 'MD Sir')
        .toString();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool saving = false;
        return StatefulBuilder(
          builder: (ctx, setS) {
            Future<void> save() async {
              final pct = double.tryParse(percentCtrl.text.trim());
              final note = noteCtrl.text.trim();
              if (pct == null || pct <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter a valid percentage')),
                );
                return;
              }
              if (note.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Reason / note is required')),
                );
                return;
              }
              if (permissionSource != 'MD Sir' &&
                  permissionSource != 'Senior Management') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Select who gave permission')),
                );
                return;
              }
              final managementName = managementNameCtrl.text.trim();
              if (managementName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter management name')),
                );
                return;
              }
              setS(() => saving = true);
              try {
                final batch = FirebaseFirestore.instance.batch();
                final now = FieldValue.serverTimestamp();

                batch.update(
                  FirebaseFirestore.instance
                      .collection('customer_policies')
                      .doc(docId),
                  {
                    'manualSlabPercent': pct,
                    'manualSlabNote': note,
                    'manualSlabPermissionSource': permissionSource,
                    'manualSlabManagementName': managementName,
                    'manualSlabChangedBy': user?.uid ?? '',
                    'manualSlabChangedByName': name,
                    'manualSlabChangedAt': now,
                    'updatedAt': now,
                  },
                );

                batch.set(FirebaseFirestore.instance.collection('logs').doc(), {
                  'page': 'Agricultural Revenue',
                  'action': 'Manual Slab Override',
                  'customerPolicyId': docId,
                  'policyId': _selectedPolicyId,
                  'policyName': policy['planName'] ?? '',
                  'customerName': row['customerName'] ?? '',
                  'previousPercent': _effectivePct(row, policy),
                  'newPercent': pct,
                  'reason': note,
                  'permissionSource': permissionSource,
                  'managementName': managementName,
                  'changedBy': name,
                  'changedByUid': user?.uid ?? '',
                  'timestamp': now,
                });

                await batch.commit();
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                setS(() => saving = false);
                if (!mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Error: $e')));
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
                          : (value) => setS(
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
                        'Changed by: $name',
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

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            const Divider(height: 1, color: _border),
            Expanded(
              child: _selectedPolicyId == null
                  ? _policyPickerView()
                  : _selectedPolicyView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      color: _surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          if (_selectedPolicyId != null)
            GestureDetector(
              onTap: () => setState(() {
                _selectedPolicyId = null;
                _selectedPolicy = null;
                _fromDate = null;
                _toDate = null;
                _selectedRows.clear();
                _selectAll = false;
              }),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  color: _primary,
                  size: 18,
                ),
              ),
            ),
          if (_selectedPolicyId != null) const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Agricultural Revenue',
              style: TextStyle(
                color: _textMain,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          if (_isUpdating)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }

  // ─── Policy Picker ─────────────────────────────────────────────────────────

  Widget _policyPickerView() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _policyStream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _LoadingView();
        }
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));

        final docs = snap.data?.docs ?? [];
        final policies = docs.map((d) => {'id': d.id, ...d.data()}).toList()
          ..sort(
            (a, b) => (a['planName'] ?? '').toString().toLowerCase().compareTo(
              (b['planName'] ?? '').toString().toLowerCase(),
            ),
          );

        if (policies.isEmpty) {
          return const Center(
            child: Text(
              'No active Agricultural policies found.',
              style: TextStyle(color: _textMuted),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Select Policy',
              style: TextStyle(
                color: _textMain,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Choose a Agricultural policy, then select start and end dates.',
              style: TextStyle(color: _textMuted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedPolicyId,
              hint: const Text('Select Agricultural policy'),
              isExpanded: true,
              items: policies.map((p) {
                return DropdownMenuItem<String>(
                  value: p['id'].toString(),
                  child: Text(
                    '${p['planName'] ?? ''} • ${p['policyCode'] ?? ''} • ${p['companyName'] ?? ''}',
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (v) {
                final p = policies.firstWhere(
                  (e) => e['id'].toString() == v,
                  orElse: () => <String, dynamic>{},
                );
                setState(() {
                  _selectedPolicyId = v;
                  _selectedPolicy = p.isEmpty ? null : p;
                  _fromDate = null;
                  _toDate = null;
                  _selectedRows.clear();
                  _selectAll = false;
                });
              },
              decoration: InputDecoration(
                filled: true,
                fillColor: _surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _accent, width: 1.5),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ─── Selected Policy View ──────────────────────────────────────────────────

  Widget _selectedPolicyView() {
    final policy = _selectedPolicy;
    if (policy == null) return const _LoadingView();

    final policyId = _selectedPolicyId!;
    final policyName = policy['planName']?.toString() ?? '';
    final companyName = policy['companyName']?.toString() ?? '';
    final policyCode = policy['policyCode']?.toString() ?? '';
    final category = policy['category']?.toString() ?? '';
    final renewalCommission = _num(
      policy['renewalCommission'] ?? policy['renewalCommissionPercent'],
    );
    final slabs = _generalSlabs(policy);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('customer_policies')
          .where('policyId', isEqualTo: policyId)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _LoadingView();
        }
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));

        final allDocs = snap.data?.docs ?? [];
        final docs = allDocs.where((d) {
          final data = d.data();
          final start = data['policyStartDate'] ?? data['startDate'];
          final end = data['policyEndDate'] ?? data['endDate'];
          if (_fromDate != null && _toDate != null) {
            return _withinRange(start, _fromDate!, _toDate!) ||
                _withinRange(end, _fromDate!, _toDate!);
          }
          if (_fromDate != null && _toDate == null) {
            return _withinRange(start, _fromDate!, DateTime.now());
          }
          return true;
        }).toList();

        double totalPremium = 0;
        double totalCommission = 0;
        double settledAmount = 0;
        double yetToSettleAmount = 0;

        for (final d in docs) {
          final data = d.data();
          final premium = _num(data['premiumAmount'] ?? data['premium']);
          totalPremium += premium;
          if (_isSettled(data)) {
            final c = _num(
              data['settledCommissionAmount'] ?? data['commissionAmount'],
            );
            settledAmount += c;
            totalCommission += c;
          } else {
            final c = _commissionAmountForRow(data, policy);
            yetToSettleAmount += c;
            totalCommission += c;
          }
        }

        final ids = docs.map((e) => e.id).toSet();
        _selectedRows.removeWhere((id) => !ids.contains(id));
        final unsettledDocs = docs.where((d) => !_isSettled(d.data())).toList();
        _selectAll =
            unsettledDocs.isNotEmpty &&
            _selectedRows.length == unsettledDocs.length;

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Header ──
            const Text(
              'Policy Details',
              style: TextStyle(
                color: _textMain,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$policyName • $policyCode • $companyName',
              style: const TextStyle(color: _textMuted, fontSize: 13),
            ),
            const SizedBox(height: 16),

            // ── Policy info ──
            _Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detailRow('Category', category),
                  _detailRow('Company', companyName),
                  _detailRow('Policy Code', policyCode),
                  _detailRow('Renewal Commission', '$renewalCommission%'),
                  _detailRow('Configured Slabs', slabs.length.toString()),
                  _detailRow(
                    'Selected From',
                    _fromDate == null ? '-' : _compactDate(_fromDate!),
                  ),
                  _detailRow(
                    'Selected To',
                    _toDate == null ? '-' : _compactDate(_toDate!),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Summary cards ──
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _Card(
                  'Customers',
                  docs.length.toString(),
                  Icons.people_alt_rounded,
                  _primary,
                ),
                _Card(
                  'Premium',
                  _fmtMoney(totalPremium),
                  Icons.currency_rupee_rounded,
                  _accent,
                ),
                _Card(
                  'Commission',
                  _fmtMoney(totalCommission),
                  Icons.account_balance_wallet_outlined,
                  _green,
                ),
                _Card(
                  'Settled',
                  _fmtMoney(settledAmount),
                  Icons.verified_rounded,
                  _green,
                ),
                _Card(
                  'Yet to Settle',
                  _fmtMoney(yetToSettleAmount),
                  Icons.schedule_rounded,
                  _amber,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Date range ──
            _Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Choose Date Range',
                    style: TextStyle(
                      color: _textMain,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _dateBox(
                          label: _fromDate == null
                              ? 'Start Date'
                              : _compactDate(_fromDate!),
                          onTap: _pickFromDate,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _dateBox(
                          label: _toDate == null
                              ? 'End Date'
                              : _compactDate(_toDate!),
                          onTap: _pickToDate,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Slab table ──
            _Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Agricultural Slabs',
                    style: TextStyle(
                      color: _textMain,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (slabs.isEmpty)
                    const Text(
                      'No slabs found.',
                      style: TextStyle(color: _textMuted),
                    )
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: const WidgetStatePropertyAll(
                          Color(0x0F0D2D4F),
                        ),
                        columns: const [
                          DataColumn(label: Text('Label')),
                          DataColumn(label: Text('Percent')),
                          DataColumn(label: Text('Notes')),
                        ],
                        rows: slabs.map<DataRow>((m) {
                          return DataRow(
                            cells: [
                              DataCell(Text((m['label'] ?? '').toString())),
                              DataCell(Text('${_num(m['percent'])}%')),
                              DataCell(Text((m['notes'] ?? '').toString())),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Customers table ──
            _Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Linked Customers',
                        style: TextStyle(
                          color: _textMain,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      if (docs.isNotEmpty)
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _selectAll = !_selectAll;
                              if (_selectAll) {
                                _selectedRows
                                  ..clear()
                                  ..addAll(unsettledDocs.map((e) => e.id));
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
                        onPressed: _selectedRows.isEmpty || _isUpdating
                            ? null
                            : () => _markSelectedSettled('Settled', docs),
                        icon: const Icon(Icons.done_all_rounded, size: 16),
                        label: const Text('Mark Settled'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _green,
                          foregroundColor: Colors.white,
                          elevation: 0,
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _selectedRows.isEmpty || _isUpdating
                            ? null
                            : () => _markSelectedSettled('Not Settled', docs),
                        icon: const Icon(Icons.undo_rounded, size: 16),
                        label: const Text('Mark Not Settled'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_fromDate == null || _toDate == null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _accent.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _border),
                      ),
                      child: const Text(
                        'Select both start date and end date to load customers.',
                        style: TextStyle(color: _textMuted, fontSize: 12),
                      ),
                    )
                  else if (docs.isEmpty)
                    const Text(
                      'No customers found for this date range.',
                      style: TextStyle(color: _textMuted),
                    )
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        showCheckboxColumn: false,
                        headingRowColor: const WidgetStatePropertyAll(
                          Color(0x0F0D2D4F),
                        ),
                        columns: const [
                          DataColumn(label: Text('Select')),
                          DataColumn(label: Text('Customer')),
                          DataColumn(label: Text('Mobile')),
                          DataColumn(label: Text('Policy No')),
                          DataColumn(label: Text('Sum Insured')),
                          DataColumn(label: Text('Premium')),
                          DataColumn(label: Text('Selected Slab')),
                          DataColumn(label: Text('Slab %')),
                          DataColumn(label: Text('Commission')),
                          DataColumn(label: Text('Start Date')),
                          DataColumn(label: Text('End Date')),
                          DataColumn(label: Text('Settled')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Override')),
                        ],
                        rows: docs.map((d) {
                          final data = d.data();
                          final id = d.id;
                          final settled = _isSettled(data);
                          final sumInsured = _num(
                            data['sumInsured'] ?? data['policySumInsured'],
                          );
                          final premium = _num(
                            data['premiumAmount'] ?? data['premium'],
                          );
                          final slabLabel = (data['selectedSlabLabel'] ?? '')
                              .toString();

                          final pct = settled
                              ? _num(
                                  data['settledSlabPercent'] ??
                                      data['selectedSlabPercent'],
                                )
                              : _effectivePct(data, policy);

                          final commission = settled
                              ? _num(
                                  data['settledCommissionAmount'] ??
                                      data['commissionAmount'],
                                )
                              : (premium * pct) / 100;

                          final hasManual =
                              _num(data['manualSlabPercent']) > 0 && !settled;

                          return DataRow(
                            selected: _selectedRows.contains(id),
                            cells: [
                              // Select
                              DataCell(
                                settled
                                    ? const Icon(
                                        Icons.lock_rounded,
                                        color: _textMuted,
                                        size: 18,
                                      )
                                    : Checkbox(
                                        value: _selectedRows.contains(id),
                                        onChanged: (v) {
                                          setState(() {
                                            if (v == true) {
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
                                Text((data['customerName'] ?? '').toString()),
                              ),
                              DataCell(
                                Text((data['customerMobile'] ?? '').toString()),
                              ),
                              DataCell(
                                Text((data['policyNumber'] ?? '').toString()),
                              ),
                              DataCell(Text(_fmtMoney(sumInsured))),
                              DataCell(Text(_fmtMoney(premium))),
                              DataCell(
                                Text(slabLabel.isEmpty ? '-' : slabLabel),
                              ),
                              // Slab % — highlight if manually overridden
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('${pct.toStringAsFixed(2)}%'),
                                    if (hasManual) ...[
                                      const SizedBox(width: 4),
                                      Tooltip(
                                        message:
                                            'Manual override\n${data['manualSlabNote'] ?? ''}',
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
                              DataCell(Text(_fmtMoney(commission))),
                              // Start date
                              DataCell(
                                settled
                                    ? Text(
                                        _fmtDate(
                                          data['policyStartDate'] ??
                                              data['startDate'],
                                        ),
                                      )
                                    : _dateCell(
                                        docId: id,
                                        field: 'policyStartDate',
                                        value:
                                            data['policyStartDate'] ??
                                            data['startDate'],
                                      ),
                              ),
                              // End date
                              DataCell(
                                settled
                                    ? Text(
                                        _fmtDate(
                                          data['policyEndDate'] ??
                                              data['endDate'],
                                        ),
                                      )
                                    : _dateCell(
                                        docId: id,
                                        field: 'policyEndDate',
                                        value:
                                            data['policyEndDate'] ??
                                            data['endDate'],
                                      ),
                              ),
                              // Settled badge
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
                                Text((data['status'] ?? 'Active').toString()),
                              ),
                              // Override button — only for unsettled
                              DataCell(
                                settled
                                    ? const SizedBox.shrink()
                                    : TextButton.icon(
                                        onPressed: () => _showOverrideDialog(
                                          docId: id,
                                          row: data,
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

  // ─── Small widgets ─────────────────────────────────────────────────────────

  Widget _dateCell({
    required String docId,
    required String field,
    required dynamic value,
  }) {
    return SizedBox(
      width: 120,
      child: TextFormField(
        initialValue: _fmtDate(value),
        readOnly: true,
        decoration: const InputDecoration(
          isDense: true,
          border: OutlineInputBorder(),
        ),
        onTap: () => _editDate(docId, field, value),
      ),
    );
  }

  Widget _dateBox({required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            const Icon(Icons.date_range_rounded, size: 16, color: _textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: _textMain,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(
                color: _textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(
                color: _textMain,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Helper widgets ─────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          SizedBox(height: 12),
          Text(
            'Loading data...',
            style: TextStyle(color: Color(0xFF8A94A6), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _Card(this.title, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _AgriculturalRevenueTabState._surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _AgriculturalRevenueTabState._border),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: _AgriculturalRevenueTabState._textMain,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    color: _AgriculturalRevenueTabState._textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _AgriculturalRevenueTabState._surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _AgriculturalRevenueTabState._border),
      ),
      child: child,
    );
  }
}
