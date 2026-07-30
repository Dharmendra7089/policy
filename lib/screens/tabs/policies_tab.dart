import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../utils/audit_log_service.dart';
import '../../widgets/company_logo.dart';
import '../../widgets/list_serial_number.dart';

class PoliciesTab extends StatefulWidget {
  final String title;
  final String? initialSection;

  const PoliciesTab({
    super.key,
    this.title = 'Health Insurance',
    this.initialSection,
  });

  @override
  State<PoliciesTab> createState() => _PoliciesTabState();
}

class _PoliciesTabState extends State<PoliciesTab> {
  static const _primary = Color(0xFF0D2D4F);
  static const _accent = Color(0xFF1A6EBD);
  static const _bg = Color(0xFFF4F6F9);
  static const _surface = Color(0xFFFFFFFF);
  static const _border = Color(0xFFE4E7EC);
  static const _textMain = Color(0xFF0D1B2A);
  static const _textMuted = Color(0xFF8A94A6);
  static const _red = Color(0xFFDC2626);
  static const _healthSections = [
    'Individual Health',
    'Family Floater',
    'Group Health',
    'Senior Citizen',
    'International Travel',
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
      .collection('policies')
      .orderBy('createdAt', descending: true)
      .snapshots();

  bool _isHealthPolicy(Map<String, dynamic> data) {
    final category = (data['category'] ?? 'Health')
        .toString()
        .trim()
        .toLowerCase();
    return category.isEmpty || category == 'health';
  }

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
      return _PolicyDetailView(
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
        child: Column(
          children: [
            _buildHeader(context),
            const Divider(height: 1, color: _border),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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
                  var docs = (snap.data?.docs ?? [])
                      .where((d) => _isHealthPolicy(d.data()))
                      .toList();
                  if (_selectedSection != null) {
                    docs = docs
                        .where(
                          (d) =>
                              (d.data()['policySection'] ?? '')
                                  .toString()
                                  .trim() ==
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
                  if (docs.isEmpty) return _buildEmpty(context);
                  return ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _PolicyRow(
                      doc: docs[i],
                      serialNumber: i + 1,
                      onTap: () => setState(() => _selectedDoc = docs[i]),
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
                          ? 'Tap a health policy to view full details'
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
              ..._healthSections
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
            child: const Icon(
              Icons.description_outlined,
              color: _primary,
              size: 26,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'No policies yet',
            style: TextStyle(
              color: _textMain,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Add your first policy to get started.',
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

    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
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
        _healthSections.first;
    final customPolicySection = TextEditingController(
      text: _healthSections.contains(selectedPolicySection)
          ? ''
          : selectedPolicySection,
    );
    if (!_healthSections.contains(selectedPolicySection)) {
      selectedPolicySection = 'Other';
    }

    String selectedCategory = 'Health';
    String selectedStatus = existing?['status']?.toString() ?? 'Active';
    bool isFamilyFloater = existing?['isFamilyFloater'] ?? false;
    bool isSaving = false;

    // ── Health commission groups ──
    List<_CommSlabGroup> healthCommGroups = [];
    if (existing != null && existing['healthCommissions'] is List) {
      for (final g in (existing['healthCommissions'] as List)) {
        if (g is Map) {
          final rawSlabs = g['slabs'];
          final slabs = rawSlabs is List
              ? rawSlabs
                    .map(
                      (s) => _CommSlab(
                        label: TextEditingController(
                          text: s['label']?.toString() ?? '',
                        ),
                        from: TextEditingController(
                          text: s['fromAmount']?.toString() ?? '',
                        ),
                        to: TextEditingController(
                          text: s['toAmount']?.toString() ?? '',
                        ),
                        percent: TextEditingController(
                          text: s['percent']?.toString() ?? '',
                        ),
                      ),
                    )
                    .toList()
              : <_CommSlab>[];
          healthCommGroups.add(
            _CommSlabGroup(
              type: g['type']?.toString() ?? 'sumInsured',
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
              final g = healthCommGroups[gi];
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

              // Validate health commission groups
              if (selectedCategory == 'Health') {
                for (int gi = 0; gi < healthCommGroups.length; gi++) {
                  final g = healthCommGroups[gi];
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
                    final from = double.tryParse(s.from.text.trim());
                    final pct = double.tryParse(s.percent.text.trim());
                    if (from == null || pct == null) {
                      _showError(
                        'Commission group ${gi + 1}, Slab ${si + 1}: From amount and % are required.',
                      );
                      return;
                    }
                  }
                }
              }

              setS(() => isSaving = true);

              try {
                final dup = await FirebaseFirestore.instance
                    .collection('policies')
                    .where('policyCode', isEqualTo: codeValue)
                    .limit(1)
                    .get();
                if (dup.docs.isNotEmpty && dup.docs.first.id != docId) {
                  setS(() => isSaving = false);
                  _showError('A policy with this policy code already exists.');
                  return;
                }

                final healthCommPayload = healthCommGroups.map((g) {
                  return {
                    'type': g.type,
                    'startDate': g.startDate != null
                        ? Timestamp.fromDate(g.startDate!)
                        : null,
                    'endDate': g.endDate != null
                        ? Timestamp.fromDate(g.endDate!)
                        : null,
                    'slabs': g.slabs.map((s) {
                      return {
                        'label': s.label.text.trim(),
                        'fromAmount': double.tryParse(s.from.text.trim()) ?? 0,
                        'toAmount': s.to.text.trim().isEmpty
                            ? null
                            : double.tryParse(s.to.text.trim()),
                        'percent': double.tryParse(s.percent.text.trim()) ?? 0,
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
                  'category': selectedCategory,
                  'policySection': policySectionValue,
                  'status': selectedStatus,
                  'renewalCommission': renewalCommissionValue,
                  'isFamilyFloater': isFamilyFloater,
                  'specialBenefits': _clean(specialBenefits),
                  'exclusions': _clean(exclusions),
                  'healthCommissions': healthCommPayload,
                  'searchKey':
                      '$planValue $codeValue $selectedCompanyName $selectedCategory $policySectionValue'
                          .toLowerCase(),
                  'updatedAt': FieldValue.serverTimestamp(),
                  'updatedBy': uid,
                };

                if (isEdit) {
                  await FirebaseFirestore.instance
                      .collection('policies')
                      .doc(docId)
                      .update(data);
                  await AuditLogService.write(
                    page: 'Health Policies',
                    action: 'Updated Policy',
                    description: 'Updated health policy "$planValue".',
                    targetId: docId,
                    targetType: 'Policy',
                    targetName: planValue,
                    extra: {'policyName': planValue},
                  );
                } else {
                  data['createdAt'] = FieldValue.serverTimestamp();
                  data['createdBy'] = uid;
                  final created = await FirebaseFirestore.instance
                      .collection('policies')
                      .add(data);
                  await AuditLogService.write(
                    page: 'Health Policies',
                    action: 'Added Policy',
                    description: 'Added health policy "$planValue".',
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
              final g = healthCommGroups[gi];
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
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: g.type,
                              isDense: true,
                              style: const TextStyle(
                                fontSize: 12,
                                color: _textMain,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Commission Type',
                                labelStyle: const TextStyle(
                                  color: _textMuted,
                                  fontSize: 11,
                                ),
                                filled: true,
                                fillColor: _surface,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
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
                                  borderSide: const BorderSide(
                                    color: _accent,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'sumInsured',
                                  child: Text('Sum Insured Based'),
                                ),
                                DropdownMenuItem(
                                  value: 'premium',
                                  child: Text('Premium Based'),
                                ),
                              ],
                              onChanged: (v) =>
                                  setS(() => g.type = v ?? 'sumInsured'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (healthCommGroups.length > 1)
                            GestureDetector(
                              onTap: () => setS(() {
                                healthCommGroups[gi].disposeAll();
                                healthCommGroups.removeAt(gi);
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
                              Expanded(
                                child: Text(
                                  g.type == 'sumInsured'
                                      ? 'Sum Insured Slabs'
                                      : 'Premium Slabs',
                                  style: const TextStyle(
                                    color: _primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () =>
                                    setS(() => g.slabs.add(_CommSlab.empty())),
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
                            return Container(
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
                                  Row(
                                    children: [
                                      Container(
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          color: _accent.withValues(alpha: 0.1),
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
                                            'Label (e.g. Below 10 Lakh SA)',
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
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: s.from,
                                          keyboardType: TextInputType.number,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: _textMain,
                                          ),
                                          decoration: _slabDec(
                                            g.type == 'sumInsured'
                                                ? 'From ₹ SA'
                                                : 'From ₹ Premium',
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextField(
                                          controller: s.to,
                                          keyboardType: TextInputType.number,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: _textMain,
                                          ),
                                          decoration: _slabDec(
                                            'To ₹ (blank = above)',
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextField(
                                          controller: s.percent,
                                          keyboardType: TextInputType.number,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: _textMain,
                                          ),
                                          decoration: _slabDec('Payout %'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
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
                      color: _primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(
                      Icons.description_outlined,
                      color: _primary,
                      size: 17,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isEdit ? 'Edit Policy' : 'Add Policy',
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

                      _sectionLabel('Tag Insurance Company *'),
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
                                child: Text(c['companyName']?.toString() ?? ''),
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
                        _readonlyCategory(),
                        _drop(
                          'Status',
                          statuses,
                          selectedStatus,
                          (v) => setS(() => selectedStatus = v!),
                        ),
                      ),
                      _row2(
                        _drop(
                          'Policy Section',
                          _healthSections,
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

                      // ── Commission ──
                      _sectionLabel('Commission'),
                      _row2(
                        _tf(
                          'Renewal Commission (%)',
                          renewalComm,
                          type: TextInputType.number,
                        ),
                        const SizedBox(),
                      ),

                      // Health commission slabs
                      if (selectedCategory == 'Health') ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Health Commission Slabs',
                                    style: TextStyle(
                                      color: _primary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                  SizedBox(height: 3),
                                  Text(
                                    'Add Sum Insured or Premium based payout slabs with validity period',
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
                                () => healthCommGroups.add(
                                  _CommSlabGroup(
                                    type: 'sumInsured',
                                    startDate: null,
                                    endDate: null,
                                    slabs: [_CommSlab.empty()],
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

                        if (healthCommGroups.isEmpty)
                          GestureDetector(
                            onTap: () => setS(
                              () => healthCommGroups.add(
                                _CommSlabGroup(
                                  type: 'sumInsured',
                                  startDate: null,
                                  endDate: null,
                                  slabs: [_CommSlab.empty()],
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
                          ...healthCommGroups.asMap().entries.map(
                            (e) => commGroupWidget(e.key),
                          ),
                      ],

                      const SizedBox(height: 16),
                      _sectionLabel('Additional Details'),
                      SwitchListTile(
                        value: isFamilyFloater,
                        onChanged: (v) => setS(() => isFamilyFloater = v),
                        title: const Text('Family Floater Plan'),
                        subtitle: const Text(
                          'Covers entire family under one sum insured',
                        ),
                        activeColor: _accent,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
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
      borderSide: const BorderSide(color: Color(0xFF1A6EBD), width: 1.5),
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

  Widget _readonlyCategory() {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Category',
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 11,
        ),
      ),
      child: const Text(
        'Health',
        style: TextStyle(fontSize: 13, color: _textMain),
      ),
    );
  }
}

// ─── Commission Models ───────────────────────────────────────────────────────

class _CommSlab {
  TextEditingController label;
  TextEditingController from;
  TextEditingController to;
  TextEditingController percent;

  _CommSlab({
    required this.label,
    required this.from,
    required this.to,
    required this.percent,
  });

  factory _CommSlab.empty() => _CommSlab(
    label: TextEditingController(),
    from: TextEditingController(),
    to: TextEditingController(),
    percent: TextEditingController(),
  );

  void disposeAll() {
    label.dispose();
    from.dispose();
    to.dispose();
    percent.dispose();
  }
}

class _CommSlabGroup {
  String type;
  DateTime? startDate;
  DateTime? endDate;
  List<_CommSlab> slabs;

  _CommSlabGroup({
    required this.type,
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

// ─── Policy Row ──────────────────────────────────────────────────────────────

class _PolicyRow extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final int serialNumber;
  final VoidCallback onTap;

  static const _primary = Color(0xFF0D2D4F);
  static const _surface = Color(0xFFFFFFFF);
  static const _border = Color(0xFFE4E7EC);
  static const _textMain = Color(0xFF0D1B2A);
  static const _textMuted = Color(0xFF8A94A6);
  static const _red = Color(0xFFDC2626);

  const _PolicyRow({
    required this.doc,
    required this.serialNumber,
    required this.onTap,
  });

  Color _catColor(String cat) {
    switch (cat.toLowerCase()) {
      case 'health':
        return const Color(0xFF0891B2);
      case 'life':
        return const Color(0xFF7C3AED);
      case 'motor':
        return const Color(0xFFD97706);
      case 'travel':
        return const Color(0xFF059669);
      default:
        return const Color(0xFF475569);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final planName = data['planName'] ?? '';
    final policyCode = data['policyCode'] ?? '';
    final category = data['category'] ?? '';
    final status = data['status'] ?? 'Active';
    final companyName = data['companyName'] ?? '';
    final isActive = status == 'Active';
    final catColor = _catColor(category);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            ListSerialNumber(number: serialNumber),
            const SizedBox(width: 10),
            CompanyLogo(
              companyName: companyName.toString(),
              customLogoUrl: data['companyLogoUrl']?.toString(),
              size: 36,
              radius: 9,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    planName,
                    style: const TextStyle(
                      color: _textMain,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (companyName.toString().isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _primary.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: CompanyLogoLabel(
                            companyName: companyName.toString(),
                            customLogoUrl: data['companyLogoUrl']?.toString(),
                            logoSize: 16,
                            style: const TextStyle(
                              color: _primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      const SizedBox(width: 6),
                      Text(
                        policyCode,
                        style: const TextStyle(color: _textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: catColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                category,
                style: TextStyle(
                  color: catColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: Color(0xFF8A94A6),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Policy Detail View ──────────────────────────────────────────────────────

class _PolicyDetailView extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final VoidCallback onBack;
  final VoidCallback onEdit;
  final VoidCallback onDeleted;

  static const _primary = Color(0xFF0D2D4F);
  static const _accent = Color(0xFF1A6EBD);
  static const _bg = Color(0xFFF4F6F9);
  static const _surface = Color(0xFFFFFFFF);
  static const _border = Color(0xFFE4E7EC);
  static const _textMain = Color(0xFF0D1B2A);
  static const _textMuted = Color(0xFF8A94A6);
  static const _red = Color(0xFFDC2626);
  static const _green = Color(0xFF16A34A);
  static const _amber = Color(0xFFF59E0B);

  const _PolicyDetailView({
    required this.doc,
    required this.onBack,
    required this.onEdit,
    required this.onDeleted,
  });

  Color _catColor(String cat) {
    switch (cat.toLowerCase()) {
      case 'health':
        return const Color(0xFF0891B2);
      case 'life':
        return const Color(0xFF7C3AED);
      case 'motor':
        return const Color(0xFFD97706);
      case 'travel':
        return const Color(0xFF059669);
      default:
        return const Color(0xFF475569);
    }
  }

  String _fmtTs(dynamic v) {
    if (v == null) return '-';
    final d = v is Timestamp ? v.toDate() : (v is DateTime ? v : null);
    if (d == null) return '-';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _currency(dynamic v) {
    final n = double.tryParse(v?.toString() ?? '') ?? 0;
    final s = n.toStringAsFixed(0);
    final chars = s.split('').reversed.toList();
    final out = <String>[];
    for (int i = 0; i < chars.length; i++) {
      if (i == 3 || (i > 3 && (i - 1) % 2 == 0)) out.add(',');
      out.add(chars[i]);
    }
    return '₹${out.reversed.join()}';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('policies')
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
    final category = data['category'] ?? '';
    final status = data['status'] ?? 'Active';
    final companyName = data['companyName'] ?? '';
    final description = data['description'] ?? '';
    final isActive = status == 'Active';
    final catColor = _catColor(category);
    final rawHealthComm = data['healthCommissions'];
    final healthGroups = rawHealthComm is List ? rawHealthComm : [];

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar
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
                            .collection('policies')
                            .doc(doc.id)
                            .delete();
                        await AuditLogService.write(
                          page: 'Health Policies',
                          action: 'Deleted Policy',
                          description: 'Deleted health policy "$planName".',
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
                              _badge(
                                Icons.category_outlined,
                                category,
                                catColor,
                              ),
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

                    // ── Policy details
                    _sectionCard('Policy Details', [
                      _detailRow(
                        Icons.apartment_outlined,
                        'Company',
                        companyName.toString(),
                      ),
                      _detailRow(
                        Icons.category_outlined,
                        'Category',
                        category.toString(),
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
                      _detailRow(
                        Icons.family_restroom_outlined,
                        'Family Floater',
                        (data['isFamilyFloater'] == true) ? 'Yes' : 'No',
                      ),
                    ]),

                    // ── Health commission slabs
                    if (category.toString().toLowerCase() == 'health' &&
                        healthGroups.isNotEmpty) ...[
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
                                'Health Commission Slabs',
                                style: TextStyle(
                                  color: _primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                            const Divider(height: 1, color: _border),
                            ...healthGroups.asMap().entries.map((ge) {
                              final gi = ge.key;
                              final g = ge.value;
                              if (g is! Map) {
                                return const SizedBox.shrink();
                              }
                              final type =
                                  g['type']?.toString() ?? 'sumInsured';
                              final slabs = g['slabs'];
                              final isSumInsured = type == 'sumInsured';
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
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 9,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isSumInsured
                                                ? _accent.withValues(alpha: 0.1)
                                                : _amber.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                isSumInsured
                                                    ? Icons.shield_outlined
                                                    : Icons.payments_outlined,
                                                size: 11,
                                                color: isSumInsured
                                                    ? _accent
                                                    : _amber,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                isSumInsured
                                                    ? 'Sum Insured Based'
                                                    : 'Premium Based',
                                                style: TextStyle(
                                                  color: isSumInsured
                                                      ? _accent
                                                      : _amber,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          '${_fmtTs(g['startDate'])} – ${_fmtTs(g['endDate'])}',
                                          style: const TextStyle(
                                            color: _textMuted,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (slabs is List)
                                    ...slabs.map((s) {
                                      if (s is! Map) {
                                        return const SizedBox.shrink();
                                      }
                                      final from = s['fromAmount'];
                                      final to = s['toAmount'];
                                      final pct = s['percent'];
                                      final label =
                                          s['label']?.toString() ?? '';
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
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    if (label.isNotEmpty)
                                                      Text(
                                                        label,
                                                        style: const TextStyle(
                                                          color: _textMain,
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                      ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      to == null
                                                          ? '${_currency(from)} and above'
                                                          : '${_currency(from)} → ${_currency(to)}',
                                                      style: const TextStyle(
                                                        color: _textMuted,
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 5,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: _green.withValues(
                                                    alpha: 0.1,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: Text(
                                                  '$pct%',
                                                  style: const TextStyle(
                                                    color: _green,
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
                    ],

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
