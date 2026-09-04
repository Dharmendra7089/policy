import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../widgets/auto_hide_controls.dart';
import '../../utils/audit_log_service.dart';
import '../../widgets/company_logo.dart';

// ─── Life Policies Revenue Tab ───────────────────────────────────────────────

class LifePoliciesTab extends StatefulWidget {
  final String title;
  final String? initialSection;

  const LifePoliciesTab({
    super.key,
    this.title = 'Life Insurance',
    this.initialSection,
  });

  @override
  State<LifePoliciesTab> createState() => _LifePoliciesTabState();
}

class _LifePoliciesTabState extends State<LifePoliciesTab> {
  static const _primary = Color(0xFF0D2D4F);
  static const _accent = Color(0xFF7C3AED); // purple for life
  static const _bg = Color(0xFFF4F6F9);
  static const _surface = Color(0xFFFFFFFF);
  static const _border = Color(0xFFE4E7EC);
  static const _textMain = Color(0xFF0D1B2A);
  static const _textMuted = Color(0xFF8A94A6);
  static const _red = Color(0xFFDC2626);
  static const _lifeSections = [
    'Term Insurance',
    'Endowment',
    'Money Back',
    'Whole Life',
    'ULIP',
    'Child Plans',
    'Pension Plans',
    'Group Life',
    'Other',
  ];

  String _search = '';
  final _searchCtrl = TextEditingController();
  QueryDocumentSnapshot<Map<String, dynamic>>? _selectedDoc;
  String? _selectedSection;

  @override
  void initState() {
    super.initState();
    _selectedSection = widget.initialSection;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> get _stream => FirebaseFirestore
      .instance
      .collection('life_policies')
      .orderBy('createdAt', descending: true)
      .snapshots();

  String _clean(TextEditingController c) => c.text.trim();

  double? _optionalPercent(TextEditingController c) {
    final v = c.text.trim();
    if (v.isEmpty) return 0;
    final p = double.tryParse(v);
    return p == null || p < 0 || p > 100 ? null : p;
  }

  void _showError(String msg) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: _red));

  @override
  Widget build(BuildContext context) {
    if (_selectedDoc != null) {
      return _LifePolicyDetailView(
        doc: _selectedDoc!,
        onBack: () => setState(() => _selectedDoc = null),
        onEdit: () => _openPolicyDialog(
          context,
          docId: _selectedDoc!.id,
          existing: _selectedDoc!.data(),
        ),
        onDeleted: () => setState(() => _selectedDoc = null),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: AutoHideControlsRegion(
          controls: _buildHeader(context),
          divider: const Divider(height: 1, color: _border),
          body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _stream,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: _accent),
                );
              }
              if (snap.hasError) {
                return Center(child: Text('Error: ${snap.error}'));
              }
              var docs = snap.data?.docs ?? [];
              if (_selectedSection != null) {
                docs = docs
                    .where(
                      (d) =>
                          (d.data()['policySection'] ?? '').toString().trim() ==
                          _selectedSection,
                    )
                    .toList();
              }
              if (_search.isNotEmpty) {
                docs = docs.where((d) {
                  final data = d.data();
                  return (data['planName'] ?? '')
                          .toString()
                          .toLowerCase()
                          .contains(_search) ||
                      (data['policyCode'] ?? '')
                          .toString()
                          .toLowerCase()
                          .contains(_search) ||
                      (data['companyName'] ?? '')
                          .toString()
                          .toLowerCase()
                          .contains(_search) ||
                      (data['policySection'] ?? '')
                          .toString()
                          .toLowerCase()
                          .contains(_search);
                }).toList();
              }
              docs.sort(_comparePolicyCompanyThenPlan);
              if (docs.isEmpty) return _buildEmpty(context);
              return GridView.builder(
                padding: const EdgeInsets.all(20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 3.05,
                ),
                itemCount: docs.length,
                itemBuilder: (context, i) => _LifePolicyGridCard(
                  doc: docs[i],
                  serialNumber: i + 1,
                  onTap: () => setState(() => _selectedDoc = docs[i]),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  static int _comparePolicyCompanyThenPlan(
    QueryDocumentSnapshot<Map<String, dynamic>> a,
    QueryDocumentSnapshot<Map<String, dynamic>> b,
  ) {
    final aData = a.data();
    final bData = b.data();
    final companyCompare = (aData['companyName'] ?? '')
        .toString()
        .toLowerCase()
        .compareTo((bData['companyName'] ?? '').toString().toLowerCase());
    if (companyCompare != 0) return companyCompare;
    return (aData['planName'] ?? '').toString().toLowerCase().compareTo(
      (bData['planName'] ?? '').toString().toLowerCase(),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: _surface,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 14),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: _textMain,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.initialSection == null
                          ? 'Tap a policy to view full details'
                          : 'Tap a ${widget.initialSection!.toLowerCase()} policy to view full details',
                      style: const TextStyle(color: _textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _openPolicyDialog(
                  context,
                  preferredSection: _selectedSection,
                ),
                icon: const Icon(Icons.add_rounded, size: 15),
                label: const Text(
                  'Add Policy',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 11,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _search = v.toLowerCase().trim()),
            decoration: InputDecoration(
              hintText: 'Search by plan name, code or company...',
              hintStyle: const TextStyle(color: _textMuted, fontSize: 13),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: _textMuted,
                size: 17,
              ),
              filled: true,
              fillColor: _bg,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: const BorderSide(color: _border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: const BorderSide(color: _border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: const BorderSide(color: _accent, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('All Sections'),
                selected: _selectedSection == null,
                onSelected: (_) => setState(() => _selectedSection = null),
              ),
              ..._lifeSections
                  .where((section) => section != 'Other')
                  .map(
                    (section) => ChoiceChip(
                      label: Text(section),
                      selected: _selectedSection == section,
                      onSelected: (_) =>
                          setState(() => _selectedSection = section),
                    ),
                  ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.shield_outlined, color: _primary, size: 26),
          ),
          const SizedBox(height: 14),
          const Text(
            'No life policies yet',
            style: TextStyle(
              color: _textMain,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Add your first life policy to get started.',
            style: TextStyle(color: _textMuted, fontSize: 13),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: () =>
                _openPolicyDialog(context, preferredSection: _selectedSection),
            icon: const Icon(Icons.add_rounded, size: 15),
            label: const Text('Add Policy'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openPolicyDialog(
    BuildContext context, {
    String? docId,
    Map<String, dynamic>? existing,
    String? preferredSection,
  }) async {
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _LoadingDialog(),
    );

    List<Map<String, dynamic>> allCompanies = [];
    try {
      final snap = await FirebaseFirestore.instance
          .collection('insurance_companies')
          .where('status', isEqualTo: 'Active')
          .get();
      allCompanies = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      allCompanies.sort(
        (a, b) => (a['companyName'] ?? '').toString().toLowerCase().compareTo(
          (b['companyName'] ?? '').toString().toLowerCase(),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to load companies: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    if (!context.mounted) return;

    await _showPolicyDialog(
      context,
      docId: docId,
      existing: existing,
      preferredSection: preferredSection,
      allCompanies: allCompanies,
    );
  }

  Future<void> _showPolicyDialog(
    BuildContext context, {
    String? docId,
    Map<String, dynamic>? existing,
    String? preferredSection,
    required List<Map<String, dynamic>> allCompanies,
  }) async {
    final isEdit = docId != null;
    final messenger = ScaffoldMessenger.of(context);

    String? selectedCompanyId = existing?['companyId']?.toString();
    String? selectedCompanyName = existing?['companyName']?.toString();
    String? selectedCompanyLogoUrl = existing?['companyLogoUrl']?.toString();

    if (selectedCompanyId != null &&
        (selectedCompanyName == null ||
            selectedCompanyLogoUrl == null ||
            selectedCompanyLogoUrl.isEmpty)) {
      for (final c in allCompanies) {
        if (c['id'].toString() == selectedCompanyId) {
          selectedCompanyName ??= c['companyName']?.toString();
          selectedCompanyLogoUrl = c['logoUrl']?.toString();
          break;
        }
      }
    }

    final planName = TextEditingController(
      text: existing?['planName']?.toString() ?? '',
    );
    final policyCode = TextEditingController(
      text: existing?['policyCode']?.toString() ?? '',
    );
    final description = TextEditingController(
      text: existing?['description']?.toString() ?? '',
    );
    final renewalComm = TextEditingController(
      text: existing?['renewalCommission']?.toString() ?? '',
    );
    final specialBenefits = TextEditingController(
      text: existing?['specialBenefits']?.toString() ?? '',
    );
    final exclusions = TextEditingController(
      text: existing?['exclusions']?.toString() ?? '',
    );
    var selectedPolicySection =
        existing?['policySection']?.toString().trim() ??
        preferredSection ??
        widget.initialSection ??
        _lifeSections.first;
    final customPolicySection = TextEditingController(
      text: _lifeSections.contains(selectedPolicySection)
          ? ''
          : selectedPolicySection,
    );
    if (!_lifeSections.contains(selectedPolicySection)) {
      selectedPolicySection = 'Other';
    }

    String selectedStatus = existing?['status']?.toString() ?? 'Active';
    bool isSaving = false;

    // ── Life commission groups ──
    List<_LifeCommSlabGroup> lifeCommGroups = [];
    if (existing != null && existing['lifeCommissions'] is List) {
      for (final g in (existing['lifeCommissions'] as List)) {
        if (g is Map) {
          final rawSlabs = g['slabs'];
          final slabs = rawSlabs is List
              ? rawSlabs
                    .map(
                      (s) => _LifeCommSlab(
                        label: TextEditingController(
                          text: s['label']?.toString() ?? '',
                        ),
                        slabType: s['slabType']?.toString() ?? 'premium',
                        percent: TextEditingController(
                          text: s['percent']?.toString() ?? '',
                        ),
                        multiplier: TextEditingController(
                          text: s['multiplier']?.toString() ?? '',
                        ),
                      ),
                    )
                    .toList()
              : <_LifeCommSlab>[];
          lifeCommGroups.add(
            _LifeCommSlabGroup(
              startDate: g['startDate'] is Timestamp
                  ? (g['startDate'] as Timestamp).toDate()
                  : null,
              endDate: g['endDate'] is Timestamp
                  ? (g['endDate'] as Timestamp).toDate()
                  : null,
              slabs: slabs,
            ),
          );
        }
      }
    }

    final statuses = ['Active', 'Inactive', 'Discontinued'];

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setS) {
            Future<void> pickGroupDate(int gi, bool isStart) async {
              final g = lifeCommGroups[gi];
              final initial = isStart
                  ? (g.startDate ?? DateTime.now())
                  : (g.endDate ??
                        DateTime.now().add(const Duration(days: 365)));
              final picked = await showDatePicker(
                context: ctx,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
                initialDate: initial,
                helpText: isStart
                    ? 'Commission Start Date'
                    : 'Commission End Date',
                builder: (c, child) => Theme(
                  data: Theme.of(c).copyWith(
                    colorScheme: const ColorScheme.light(
                      primary: _primary,
                      onPrimary: Colors.white,
                      onSurface: _textMain,
                    ),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) {
                setS(() {
                  if (isStart) {
                    g.startDate = picked;
                  } else {
                    g.endDate = picked;
                  }
                });
              }
            }

            Future<void> save() async {
              final planValue = _clean(planName);
              final codeValue = _clean(policyCode).toUpperCase();
              final renewalCommissionValue = _optionalPercent(renewalComm);
              final policySectionValue = selectedPolicySection == 'Other'
                  ? _clean(customPolicySection)
                  : selectedPolicySection;

              if (planValue.isEmpty || codeValue.isEmpty) {
                _showError('Plan name and policy code are required.');
                return;
              }
              if (policySectionValue.isEmpty) {
                _showError('Policy section is required.');
                return;
              }
              if (selectedCompanyId == null) {
                _showError('Please select an active insurance company.');
                return;
              }
              if (renewalCommissionValue == null) {
                _showError('Renewal commission must be between 0 and 100.');
                return;
              }

              // Validate life commission groups
              for (int gi = 0; gi < lifeCommGroups.length; gi++) {
                final g = lifeCommGroups[gi];
                if (g.startDate == null || g.endDate == null) {
                  _showError(
                    'Commission group ${gi + 1}: Start and end dates are required.',
                  );
                  return;
                }
                if (g.endDate!.isBefore(g.startDate!)) {
                  _showError(
                    'Commission group ${gi + 1}: End date must be after start date.',
                  );
                  return;
                }
                for (int si = 0; si < g.slabs.length; si++) {
                  final s = g.slabs[si];
                  if (s.slabType == 'premium') {
                    final pct = double.tryParse(s.percent.text.trim());
                    if (pct == null || pct < 0 || pct > 100) {
                      _showError(
                        'Commission group ${gi + 1}, Slab ${si + 1}: Valid base % (0–100) is required for Premium slab.',
                      );
                      return;
                    }
                  } else {
                    final mult = double.tryParse(s.multiplier.text.trim());
                    if (mult == null || mult <= 0) {
                      _showError(
                        'Commission group ${gi + 1}, Slab ${si + 1}: Valid multiplier (> 0) is required for Term slab.',
                      );
                      return;
                    }
                  }
                }
              }

              setS(() => isSaving = true);

              try {
                final dup = await FirebaseFirestore.instance
                    .collection('life_policies')
                    .where('policyCode', isEqualTo: codeValue)
                    .limit(1)
                    .get();
                if (dup.docs.isNotEmpty && dup.docs.first.id != docId) {
                  setS(() => isSaving = false);
                  _showError('A policy with this policy code already exists.');
                  return;
                }

                final lifeCommPayload = lifeCommGroups.map((g) {
                  return {
                    'startDate': g.startDate != null
                        ? Timestamp.fromDate(g.startDate!)
                        : null,
                    'endDate': g.endDate != null
                        ? Timestamp.fromDate(g.endDate!)
                        : null,
                    'slabs': g.slabs.map((s) {
                      return {
                        'label': s.label.text.trim(),
                        'slabType': s.slabType,
                        if (s.slabType == 'premium')
                          'percent':
                              double.tryParse(s.percent.text.trim()) ?? 0,
                        if (s.slabType == 'term')
                          'multiplier':
                              double.tryParse(s.multiplier.text.trim()) ?? 1,
                      };
                    }).toList(),
                  };
                }).toList();

                final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
                final data = <String, dynamic>{
                  'companyId': selectedCompanyId,
                  'companyName': selectedCompanyName,
                  'companyLogoUrl': selectedCompanyLogoUrl ?? '',
                  'planName': planValue,
                  'policyCode': codeValue,
                  'description': _clean(description),
                  'category': 'Life',
                  'policySection': policySectionValue,
                  'status': selectedStatus,
                  'renewalCommission': renewalCommissionValue,
                  'specialBenefits': _clean(specialBenefits),
                  'exclusions': _clean(exclusions),
                  'lifeCommissions': lifeCommPayload,
                  'searchKey':
                      '$planValue $codeValue $selectedCompanyName Life $policySectionValue'
                          .toLowerCase(),
                  'updatedAt': FieldValue.serverTimestamp(),
                  'updatedBy': uid,
                };

                if (isEdit) {
                  await FirebaseFirestore.instance
                      .collection('life_policies')
                      .doc(docId)
                      .update(data);
                  await AuditLogService.write(
                    page: 'Life Policies',
                    action: 'Updated Policy',
                    description: 'Updated life policy "$planValue".',
                    targetId: docId,
                    targetType: 'Policy',
                    targetName: planValue,
                    extra: {'policyName': planValue},
                  );
                } else {
                  data['createdAt'] = FieldValue.serverTimestamp();
                  data['createdBy'] = uid;
                  final created = await FirebaseFirestore.instance
                      .collection('life_policies')
                      .add(data);
                  await AuditLogService.write(
                    page: 'Life Policies',
                    action: 'Added Policy',
                    description: 'Added life policy "$planValue".',
                    targetId: created.id,
                    targetType: 'Policy',
                    targetName: planValue,
                    extra: {'policyName': planValue},
                  );
                }

                if (ctx.mounted) Navigator.pop(ctx);
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(isEdit ? 'Policy updated' : 'Policy added'),
                    backgroundColor: _primary,
                  ),
                );
              } catch (e) {
                setS(() => isSaving = false);
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }

            String fmtDate(DateTime? d) {
              if (d == null) return 'Pick date';
              return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
            }

            Widget commGroupWidget(int gi) {
              final g = lifeCommGroups[gi];
              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Group header
                    Container(
                      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                      decoration: BoxDecoration(
                        color: _primary.withValues(alpha: 0.04),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                        border: const Border(
                          bottom: BorderSide(color: _border),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: _primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                'G${gi + 1}',
                                style: const TextStyle(
                                  color: _primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Life Commission Group',
                              style: TextStyle(
                                color: _primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (lifeCommGroups.length > 1)
                            GestureDetector(
                              onTap: () => setS(() {
                                lifeCommGroups[gi].disposeAll();
                                lifeCommGroups.removeAt(gi);
                              }),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: _red.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                child: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 14,
                                  color: _red,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Date range
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => pickGroupDate(gi, true),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 11,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _surface,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: _border),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.calendar_today_outlined,
                                          size: 13,
                                          color: g.startDate != null
                                              ? _accent
                                              : _textMuted,
                                        ),
                                        const SizedBox(width: 7),
                                        Expanded(
                                          child: Text(
                                            'Start: ${fmtDate(g.startDate)}',
                                            style: TextStyle(
                                              color: g.startDate != null
                                                  ? _accent
                                                  : _textMuted,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => pickGroupDate(gi, false),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 11,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _surface,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: _border),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.event_available_outlined,
                                          size: 13,
                                          color: g.endDate != null
                                              ? const Color(0xFF16A34A)
                                              : _textMuted,
                                        ),
                                        const SizedBox(width: 7),
                                        Expanded(
                                          child: Text(
                                            'End: ${fmtDate(g.endDate)}',
                                            style: TextStyle(
                                              color: g.endDate != null
                                                  ? const Color(0xFF16A34A)
                                                  : _textMuted,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Slabs header
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Commission Slabs',
                                  style: TextStyle(
                                    color: _primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () => setS(
                                  () => g.slabs.add(_LifeCommSlab.empty()),
                                ),
                                icon: const Icon(
                                  Icons.add_rounded,
                                  size: 13,
                                  color: _accent,
                                ),
                                label: const Text(
                                  'Add Slab',
                                  style: TextStyle(
                                    color: _accent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                style: TextButton.styleFrom(
                                  minimumSize: Size.zero,
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Slab rows
                          ...g.slabs.asMap().entries.map((se) {
                            final si = se.key;
                            final s = se.value;
                            return StatefulBuilder(
                              builder: (ctx2, setS2) => Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: _surface,
                                  borderRadius: BorderRadius.circular(9),
                                  border: Border.all(color: _border),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Row 1: index badge + label + delete
                                    Row(
                                      children: [
                                        Container(
                                          width: 22,
                                          height: 22,
                                          decoration: BoxDecoration(
                                            color: _accent.withValues(
                                              alpha: 0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              '${si + 1}',
                                              style: const TextStyle(
                                                color: _accent,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: TextField(
                                            controller: s.label,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: _textMain,
                                            ),
                                            decoration: _slabDec(
                                              'Label (e.g. Year 1 Premium)',
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        if (g.slabs.length > 1)
                                          GestureDetector(
                                            onTap: () => setS(() {
                                              g.slabs[si].disposeAll();
                                              g.slabs.removeAt(si);
                                            }),
                                            child: const Icon(
                                              Icons.close_rounded,
                                              size: 15,
                                              color: _red,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),

                                    // Row 2: slab type toggle + value input
                                    Row(
                                      children: [
                                        // Type selector: Premium | Term
                                        Expanded(
                                          flex: 2,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: _bg,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: _border,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: GestureDetector(
                                                    onTap: () {
                                                      setS(
                                                        () => s.slabType =
                                                            'premium',
                                                      );
                                                      setS2(() {});
                                                    },
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            vertical: 9,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color:
                                                            s.slabType ==
                                                                'premium'
                                                            ? _accent
                                                            : Colors
                                                                  .transparent,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              7,
                                                            ),
                                                      ),
                                                      child: Center(
                                                        child: Text(
                                                          'Premium %',
                                                          style: TextStyle(
                                                            color:
                                                                s.slabType ==
                                                                    'premium'
                                                                ? Colors.white
                                                                : _textMuted,
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  child: GestureDetector(
                                                    onTap: () {
                                                      setS(
                                                        () =>
                                                            s.slabType = 'term',
                                                      );
                                                      setS2(() {});
                                                    },
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            vertical: 9,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color:
                                                            s.slabType == 'term'
                                                            ? const Color(
                                                                0xFF059669,
                                                              )
                                                            : Colors
                                                                  .transparent,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              7,
                                                            ),
                                                      ),
                                                      child: Center(
                                                        child: Text(
                                                          'Term ×',
                                                          style: TextStyle(
                                                            color:
                                                                s.slabType ==
                                                                    'term'
                                                                ? Colors.white
                                                                : _textMuted,
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),

                                        // Value input based on type
                                        Expanded(
                                          flex: 3,
                                          child: s.slabType == 'premium'
                                              ? TextField(
                                                  controller: s.percent,
                                                  keyboardType:
                                                      TextInputType.number,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: _textMain,
                                                  ),
                                                  decoration: _slabDec(
                                                    'Base % (e.g. 15)',
                                                  ),
                                                )
                                              : TextField(
                                                  controller: s.multiplier,
                                                  keyboardType:
                                                      TextInputType.number,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: _textMain,
                                                  ),
                                                  decoration: _slabDec(
                                                    '× Times (e.g. 3)',
                                                  ),
                                                ),
                                        ),
                                      ],
                                    ),

                                    // Helper text
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(
                                        s.slabType == 'premium'
                                            ? '💡 Enter base commission % of premium amount'
                                            : '💡 Enter multiplier e.g. 3 = ×3 times payout',
                                        style: const TextStyle(
                                          color: _textMuted,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            return AlertDialog(
              backgroundColor: _surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
              contentPadding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
              title: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: _accent,
                      size: 17,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isEdit ? 'Edit Life Policy' : 'Add Life Policy',
                    style: const TextStyle(
                      color: _textMain,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 680,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),

                      _sectionLabel('Select Company *'),
                      DropdownButtonFormField<String>(
                        value: selectedCompanyId,
                        hint: const Text(
                          'Select a company',
                          style: TextStyle(color: _textMuted, fontSize: 13),
                        ),
                        onChanged: (v) {
                          setS(() {
                            selectedCompanyId = v;
                            final match = allCompanies.where(
                              (c) => c['id'].toString() == v,
                            );
                            selectedCompanyName = match.isNotEmpty
                                ? match.first['companyName']?.toString()
                                : null;
                            selectedCompanyLogoUrl = match.isNotEmpty
                                ? match.first['logoUrl']?.toString()
                                : null;
                          });
                        },
                        items: allCompanies
                            .map(
                              (c) => DropdownMenuItem<String>(
                                value: c['id'].toString(),
                                child: Row(
                                  children: [
                                    CompanyLogo(
                                      companyName:
                                          c['companyName']?.toString() ?? '',
                                      customLogoUrl: c['logoUrl']?.toString(),
                                      size: 22,
                                      radius: 5,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        c['companyName']?.toString() ?? '',
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ),
                                    if ((c['companyType']?.toString() ?? '')
                                        .isNotEmpty)
                                      Text(
                                        '(${c['companyType']})',
                                        style: const TextStyle(
                                          color: _textMuted,
                                          fontSize: 11,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: _bg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: _border),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 11,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      _sectionLabel('Plan Identification'),
                      _row2(
                        _tf('Plan Name *', planName),
                        _tf('Policy Code *', policyCode),
                      ),
                      _row2(
                        _drop(
                          'Status',
                          statuses,
                          selectedStatus,
                          (v) => setS(() => selectedStatus = v!),
                        ),
                        const SizedBox(),
                      ),
                      _row2(
                        _drop(
                          'Policy Section',
                          _lifeSections,
                          selectedPolicySection,
                          (v) => setS(() => selectedPolicySection = v!),
                        ),
                        selectedPolicySection == 'Other'
                            ? _tf('Other Section Name *', customPolicySection)
                            : const SizedBox(),
                      ),
                      _tf(
                        'Description / Coverage Summary',
                        description,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),

                      _sectionLabel('Commission'),
                      _row2(
                        _tf(
                          'Renewal Commission (%)',
                          renewalComm,
                          type: TextInputType.number,
                        ),
                        const SizedBox(),
                      ),

                      // Life commission slabs
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Life Commission Slabs',
                                  style: TextStyle(
                                    color: _primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Add Premium (base %) or Term (×times) based slabs with validity',
                                  style: TextStyle(
                                    color: _textMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => setS(
                              () => lifeCommGroups.add(
                                _LifeCommSlabGroup(
                                  startDate: null,
                                  endDate: null,
                                  slabs: [_LifeCommSlab.empty()],
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.add_rounded, size: 13),
                            label: const Text(
                              'Add Group',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (lifeCommGroups.isEmpty)
                        GestureDetector(
                          onTap: () => setS(
                            () => lifeCommGroups.add(
                              _LifeCommSlabGroup(
                                startDate: null,
                                endDate: null,
                                slabs: [_LifeCommSlab.empty()],
                              ),
                            ),
                          ),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: _primary.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _primary.withValues(alpha: 0.15),
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.add_circle_outline_rounded,
                                  color: _primary.withValues(alpha: 0.4),
                                  size: 28,
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Tap to add first commission group',
                                  style: TextStyle(
                                    color: _textMuted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ...lifeCommGroups.asMap().entries.map(
                          (e) => commGroupWidget(e.key),
                        ),

                      const SizedBox(height: 16),
                      _sectionLabel('Additional Details'),
                      _tf(
                        'Special Benefits / Riders',
                        specialBenefits,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 10),
                      _tf('Exclusions', exclusions, maxLines: 2),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: _textMuted),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: isSaving ? null : save,
                  icon: isSaving
                      ? const SizedBox(
                          width: 13,
                          height: 13,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_rounded, size: 15),
                  label: Text(
                    isSaving
                        ? 'Saving...'
                        : isEdit
                        ? 'Update'
                        : 'Save Policy',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static InputDecoration _slabDec(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFF8A94A6), fontSize: 11),
    filled: true,
    fillColor: const Color(0xFFF4F6F9),
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(7),
      borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(7),
      borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(7),
      borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.5),
    ),
  );

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        color: _primary,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.4,
      ),
    ),
  );

  Widget _row2(Widget a, Widget b) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Expanded(child: a),
        const SizedBox(width: 10),
        Expanded(child: b),
      ],
    ),
  );

  Widget _tf(
    String label,
    TextEditingController ctrl, {
    TextInputType type = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 13, color: _textMain),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _textMuted, fontSize: 12),
        filled: true,
        fillColor: _bg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 11,
        ),
      ),
    );
  }

  Widget _drop(
    String label,
    List<String> items,
    String value,
    ValueChanged<String?> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      value: value,
      onChanged: onChanged,
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      style: const TextStyle(fontSize: 13, color: _textMain),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _textMuted, fontSize: 12),
        filled: true,
        fillColor: _bg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 11,
        ),
      ),
    );
  }
}

// ─── Life Commission Models ──────────────────────────────────────────────────

class _LifeCommSlab {
  TextEditingController label;
  String slabType; // 'premium' or 'term'
  TextEditingController percent; // used when slabType == 'premium'
  TextEditingController multiplier; // used when slabType == 'term'

  _LifeCommSlab({
    required this.label,
    required this.slabType,
    required this.percent,
    required this.multiplier,
  });

  factory _LifeCommSlab.empty() => _LifeCommSlab(
    label: TextEditingController(),
    slabType: 'premium',
    percent: TextEditingController(),
    multiplier: TextEditingController(),
  );

  void disposeAll() {
    label.dispose();
    percent.dispose();
    multiplier.dispose();
  }
}

class _LifeCommSlabGroup {
  DateTime? startDate;
  DateTime? endDate;
  List<_LifeCommSlab> slabs;

  _LifeCommSlabGroup({
    required this.startDate,
    required this.endDate,
    required this.slabs,
  });

  void disposeAll() {
    for (final s in slabs) s.disposeAll();
  }
}

// ─── Loading Dialog ──────────────────────────────────────────────────────────

class _LoadingDialog extends StatelessWidget {
  const _LoadingDialog();

  @override
  Widget build(BuildContext context) {
    return const Dialog(
      backgroundColor: Colors.white,
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 14),
            Text('Loading...'),
          ],
        ),
      ),
    );
  }
}

// ─── Life Policy Grid Card ────────────────────────────────────────────────────

class _LifePolicyGridCard extends StatefulWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final int serialNumber;
  final VoidCallback onTap;

  const _LifePolicyGridCard({
    required this.doc,
    required this.serialNumber,
    required this.onTap,
  });

  @override
  State<_LifePolicyGridCard> createState() => _LifePolicyGridCardState();
}

class _LifePolicyGridCardState extends State<_LifePolicyGridCard> {
  bool _isHovered = false;

  static const _accent = Color(0xFF7C3AED);
  static const _surface = Color(0xFFFFFFFF);
  static const _border = Color(0xFFE4E7EC);
  static const _textMain = Color(0xFF0D1B2A);
  static const _textMuted = Color(0xFF8A94A6);
  static const _red = Color(0xFFDC2626);
  static const _bg = Color(0xFFF4F6F9);
  static const _blueAccent = Color(0xFF1A6EBD);

  @override
  Widget build(BuildContext context) {
    final data = widget.doc.data();
    final planName = data['planName'] ?? '';
    final policyCode = data['policyCode'] ?? '';
    final status = data['status'] ?? 'Active';
    final companyName = data['companyName'] ?? '';
    final isActive = status == 'Active';

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovered ? _blueAccent : _border,
              width: _isHovered ? 1.5 : 1.0,
            ),
            boxShadow: [
              if (_isHovered)
                BoxShadow(
                  color: _blueAccent.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                )
              else
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: -8,
                left: -8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _bg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _border),
                  ),
                  child: Text(
                    '#${widget.serialNumber}',
                    style: const TextStyle(
                      color: _textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -8,
                right: -8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.green.withValues(alpha: 0.08)
                        : _red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: isActive ? Colors.green.shade700 : _red,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(width: 4),
                  CompanyLogo(
                    companyName: companyName.toString(),
                    customLogoUrl: data['companyLogoUrl']?.toString(),
                    size: 64,
                    radius: 12,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          companyName.toString().isNotEmpty
                              ? companyName.toString()
                              : '-',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _textMain,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          planName.toString(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _accent.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: const Text(
                                'Life',
                                style: TextStyle(
                                  color: _accent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (policyCode.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Text(
                                policyCode,
                                style: const TextStyle(
                                  color: _textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Life Policy Detail View ─────────────────────────────────────────────────

class _LifePolicyDetailView extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final VoidCallback onBack;
  final VoidCallback onEdit;
  final VoidCallback onDeleted;

  static const _primary = Color(0xFF0D2D4F);
  static const _accent = Color(0xFF7C3AED);
  static const _bg = Color(0xFFF4F6F9);
  static const _surface = Color(0xFFFFFFFF);
  static const _border = Color(0xFFE4E7EC);
  static const _textMain = Color(0xFF0D1B2A);
  static const _textMuted = Color(0xFF8A94A6);
  static const _red = Color(0xFFDC2626);
  static const _green = Color(0xFF16A34A);

  const _LifePolicyDetailView({
    required this.doc,
    required this.onBack,
    required this.onEdit,
    required this.onDeleted,
  });

  String _fmtTs(dynamic v) {
    if (v == null) return '-';
    final d = v is Timestamp ? v.toDate() : (v is DateTime ? v : null);
    if (d == null) return '-';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('life_policies')
          .doc(doc.id)
          .snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() ?? doc.data();
        return _buildContent(context, data);
      },
    );
  }

  Widget _buildContent(BuildContext context, Map<String, dynamic> data) {
    final planName = data['planName'] ?? '';
    final policyCode = data['policyCode'] ?? '';
    final status = data['status'] ?? 'Active';
    final companyName = data['companyName'] ?? '';
    final description = data['description'] ?? '';
    final isActive = status == 'Active';
    final rawLifeComm = data['lifeCommissions'];
    final lifeGroups = rawLifeComm is List ? rawLifeComm : [];

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: _surface,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: onBack,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: _primary.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        color: _primary,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      planName,
                      style: const TextStyle(
                        color: _textMain,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  _headerBtn(Icons.edit_outlined, _accent, 'Edit', onEdit),
                  const SizedBox(width: 8),
                  _headerBtn(
                    Icons.delete_outline_rounded,
                    _red,
                    'Delete',
                    () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete Policy'),
                          content: Text(
                            'Remove "$planName"? This cannot be undone.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _red,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (ok == true) {
                        await FirebaseFirestore.instance
                            .collection('life_policies')
                            .doc(doc.id)
                            .delete();
                        await AuditLogService.write(
                          page: 'Life Policies',
                          action: 'Deleted Policy',
                          description: 'Deleted life policy "$planName".',
                          targetId: doc.id,
                          targetType: 'Policy',
                          targetName: planName,
                          extra: {'policyName': planName},
                        );
                        onDeleted();
                      }
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: _border),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CompanyLogo(
                                companyName: companyName.toString(),
                                customLogoUrl: data['companyLogoUrl']
                                    ?.toString(),
                                size: 46,
                                radius: 12,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      planName,
                                      style: const TextStyle(
                                        color: _textMain,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      policyCode,
                                      style: const TextStyle(
                                        color: _textMuted,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (companyName.toString().isNotEmpty)
                                _badge(
                                  Icons.business_outlined,
                                  companyName,
                                  _primary,
                                ),
                              _badge(Icons.shield_outlined, 'Life', _accent),
                              _badge(
                                isActive
                                    ? Icons.check_circle_outline
                                    : Icons.cancel_outlined,
                                status,
                                isActive ? Colors.green.shade700 : _red,
                              ),
                            ],
                          ),
                          if (description.toString().isNotEmpty) ...[
                            const SizedBox(height: 14),
                            const Divider(height: 1, color: _border),
                            const SizedBox(height: 12),
                            Text(
                              description.toString(),
                              style: const TextStyle(
                                color: _textMuted,
                                fontSize: 13,
                                height: 1.6,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    _sectionCard('Policy Details', [
                      _detailRow(
                        Icons.apartment_outlined,
                        'Company',
                        companyName.toString(),
                      ),
                      _detailRow(
                        Icons.view_list_outlined,
                        'Section',
                        (data['policySection'] ?? '-').toString(),
                      ),
                      _detailRow(
                        Icons.verified_outlined,
                        'Status',
                        status.toString(),
                      ),
                      if ((data['renewalCommission'] ?? '') != '')
                        _detailRow(
                          Icons.replay_outlined,
                          'Renewal Commission',
                          '${data['renewalCommission']}%',
                        ),
                    ]),

                    // Life commission slabs
                    if (lifeGroups.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
                              child: Text(
                                'Life Commission Slabs',
                                style: TextStyle(
                                  color: _primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                            const Divider(height: 1, color: _border),
                            ...lifeGroups.asMap().entries.map((ge) {
                              final gi = ge.key;
                              final g = ge.value;
                              if (g is! Map) return const SizedBox.shrink();
                              final slabs = g['slabs'];
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (gi > 0)
                                    const Divider(height: 1, color: _border),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      12,
                                      16,
                                      8,
                                    ),
                                    child: Text(
                                      '${_fmtTs(g['startDate'])} – ${_fmtTs(g['endDate'])}',
                                      style: const TextStyle(
                                        color: _textMuted,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                  if (slabs is List)
                                    ...slabs.map((s) {
                                      if (s is! Map) {
                                        return const SizedBox.shrink();
                                      }
                                      final slabType =
                                          s['slabType']?.toString() ??
                                          'premium';
                                      final label =
                                          s['label']?.toString() ?? '';
                                      final isPremium = slabType == 'premium';
                                      final valueText = isPremium
                                          ? '${s['percent']}%'
                                          : '×${s['multiplier']} times';
                                      final valueColor = isPremium
                                          ? _green
                                          : _accent;

                                      return Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          16,
                                          0,
                                          16,
                                          0,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 10,
                                          ),
                                          margin: const EdgeInsets.only(
                                            bottom: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _bg,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(color: _border),
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: valueColor.withValues(
                                                    alpha: 0.1,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(5),
                                                ),
                                                child: Text(
                                                  isPremium
                                                      ? 'Premium'
                                                      : 'Term',
                                                  style: TextStyle(
                                                    color: valueColor,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  label.isNotEmpty
                                                      ? label
                                                      : (isPremium
                                                            ? 'Premium Based'
                                                            : 'Term Based'),
                                                  style: const TextStyle(
                                                    color: _textMain,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 5,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: valueColor.withValues(
                                                    alpha: 0.1,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: Text(
                                                  valueText,
                                                  style: TextStyle(
                                                    color: valueColor,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }),
                                  const SizedBox(height: 8),
                                ],
                              );
                            }),
                          ],
                        ),
                      ),

                    if ((data['specialBenefits'] ?? '').toString().isNotEmpty)
                      _sectionCard('Special Benefits', [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            data['specialBenefits'].toString(),
                            style: const TextStyle(
                              color: _textMain,
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ]),

                    if ((data['exclusions'] ?? '').toString().isNotEmpty)
                      _sectionCard('Exclusions', [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            data['exclusions'].toString(),
                            style: const TextStyle(
                              color: _textMuted,
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ]),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerBtn(
    IconData icon,
    Color color,
    String label,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard(String title, List<Widget> rows) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Text(
              title,
              style: const TextStyle(
                color: _primary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const Divider(height: 1, color: _border),
          ...rows,
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: _textMuted),
          const SizedBox(width: 12),
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(color: _textMuted, fontSize: 13),
            ),
          ),
          Expanded(
            child: label == 'Company'
                ? CompanyLogoLabel(
                    companyName: value,
                    logoSize: 24,
                    style: const TextStyle(
                      color: _textMain,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  )
                : Text(
                    value,
                    style: const TextStyle(
                      color: _textMain,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
