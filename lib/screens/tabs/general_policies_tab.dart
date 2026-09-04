import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../widgets/auto_hide_controls.dart';
import '../../utils/audit_log_service.dart';
import '../../widgets/company_logo.dart';

class GeneralPoliciesTab extends StatefulWidget {
  final String category;
  final String title;
  final String? initialSection;

  const GeneralPoliciesTab({
    super.key,
    this.category = 'General',
    this.title = 'General Insurance',
    this.initialSection,
  });

  @override
  State<GeneralPoliciesTab> createState() => _GeneralPoliciesTabState();
}

class _GeneralPoliciesTabState extends State<GeneralPoliciesTab> {
  static const _primary = Color(0xFF0D2D4F);
  static const _accent = Color(0xFF0F766E);
  static const _bg = Color(0xFFF4F6F9);
  static const _surface = Color(0xFFFFFFFF);
  static const _border = Color(0xFFE4E7EC);
  static const _textMain = Color(0xFF0D1B2A);
  static const _textMuted = Color(0xFF8A94A6);
  static const _red = Color(0xFFDC2626);

  String _search = '';
  final _searchCtrl = TextEditingController();
  QueryDocumentSnapshot<Map<String, dynamic>>? _selectedDoc;
  String? _selectedSection;

  static const _policySections = [
    'Health',
    'Personal Accident',
    'Engineering',
    'Liability',
    'Rural & Agriculture (Agro)',
    'Travel',
    'Home & Property',
    'Credit & Financial',
    'Aviation',
    'Cyber Insurance',
    'Fire',
    'Marine',
    'Motor',
    'Other',
  ];

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
      .collection('general_policies')
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
      return _GeneralPolicyDetailView(
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

              var docs = (snap.data?.docs ?? [])
                  .where(
                    (d) =>
                        (d.data()['category'] ?? 'General').toString() ==
                        widget.category,
                  )
                  .toList();
              if (widget.initialSection != null) {
                docs = docs
                    .where(
                      (d) =>
                          (d.data()['policySection'] ?? '').toString().trim() ==
                          widget.initialSection,
                    )
                    .toList();
              }
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
                itemBuilder: (context, i) => _GeneralPolicyGridCard(
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
                    const Text(
                      'Tap a policy to view insurer slabs and details',
                      style: TextStyle(color: _textMuted, fontSize: 12),
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
              ..._policySections
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
              Icons.home_work_outlined,
              color: _primary,
              size: 26,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'No general policies yet',
            style: TextStyle(
              color: _textMain,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Add your first general policy to get started.',
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
    final isEdit = docId != null;
    final messenger = ScaffoldMessenger.of(context);

    // Fetch insurance companies
    List<Map<String, dynamic>> allCompanies = [];
    try {
      final snap = await FirebaseFirestore.instance
          .collection('insurance_companies')
          .get();
      allCompanies = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      allCompanies.sort(
        (a, b) => (a['companyName'] ?? '').toString().toLowerCase().compareTo(
          (b['companyName'] ?? '').toString().toLowerCase(),
        ),
      );
    } catch (_) {}

    String? selectedCompanyId = existing?['companyId']?.toString();
    String? selectedCompanyName = existing?['companyName']?.toString();
    String? selectedCompanyLogoUrl = existing?['companyLogoUrl']?.toString();

    if (selectedCompanyId != null && selectedCompanyName == null) {
      for (final c in allCompanies) {
        if (c['id'].toString() == selectedCompanyId) {
          selectedCompanyName = c['companyName']?.toString();
          selectedCompanyLogoUrl = c['logoUrl']?.toString();
          break;
        }
      }
    }
    if (selectedCompanyName != null && selectedCompanyId == null) {
      for (final c in allCompanies) {
        if ((c['companyName'] ?? '').toString().trim().toLowerCase() ==
            selectedCompanyName.trim().toLowerCase()) {
          selectedCompanyId = c['id'].toString();
          selectedCompanyLogoUrl ??= c['logoUrl']?.toString();
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
        _policySections.first;
    final customPolicySection = TextEditingController(
      text: _policySections.contains(selectedPolicySection)
          ? ''
          : selectedPolicySection,
    );
    if (!_policySections.contains(selectedPolicySection)) {
      selectedPolicySection = 'Other';
    }

    String selectedStatus = existing?['status']?.toString() ?? 'Active';
    bool isSaving = false;

    final slabRows = <_GeneralCommSlab>[];
    final rawGroups = existing?['generalCommissions'];
    if (rawGroups is List) {
      for (final group in rawGroups) {
        if (group is! Map) continue;
        final slabs = group['slabs'];
        if (slabs is! List) continue;
        for (final slab in slabs) {
          if (slab is! Map) continue;
          slabRows.add(
            _GeneralCommSlab(
              label: TextEditingController(
                text: slab['label']?.toString() ?? '',
              ),
              percent: TextEditingController(
                text: slab['percent']?.toString() ?? '',
              ),
              notes: TextEditingController(
                text: slab['notes']?.toString() ?? '',
              ),
            ),
          );
        }
      }
    }
    if (slabRows.isEmpty) {
      slabRows.add(_GeneralCommSlab.empty());
    }

    final statuses = ['Active', 'Inactive', 'Discontinued'];

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setS) {
            Future<void> save() async {
              final planValue = _clean(planName);
              final codeValue = _clean(policyCode).toUpperCase();
              final renewalCommissionValue = _optionalPercent(renewalComm);
              final policySectionValue = selectedPolicySection == 'Other'
                  ? _clean(customPolicySection)
                  : selectedPolicySection;

              if (selectedCompanyName == null || selectedCompanyName!.isEmpty) {
                _showError('Please select an insurance company.');
                return;
              }
              if (planValue.isEmpty || codeValue.isEmpty) {
                _showError('Plan name and policy code are required.');
                return;
              }
              if (policySectionValue.isEmpty) {
                _showError('Policy section is required.');
                return;
              }
              if (renewalCommissionValue == null) {
                _showError('Renewal commission must be between 0 and 100.');
                return;
              }

              final cleanSlabs = <Map<String, dynamic>>[];
              for (int i = 0; i < slabRows.length; i++) {
                final s = slabRows[i];
                final label = s.label.text.trim();
                final percent = double.tryParse(s.percent.text.trim());
                final notes = s.notes.text.trim();
                if (label.isEmpty && s.percent.text.trim().isEmpty) continue;
                if (label.isEmpty || percent == null || percent < 0) {
                  _showError(
                    'Slab ${i + 1}: Label and valid payout percentage are required.',
                  );
                  return;
                }
                cleanSlabs.add({
                  'label': label,
                  'percent': percent,
                  if (notes.isNotEmpty) 'notes': notes,
                });
              }
              if (cleanSlabs.isEmpty) {
                _showError('At least one commission slab is required.');
                return;
              }

              setS(() => isSaving = true);
              try {
                final dup = await FirebaseFirestore.instance
                    .collection('general_policies')
                    .where('policyCode', isEqualTo: codeValue)
                    .limit(1)
                    .get();
                if (dup.docs.isNotEmpty && dup.docs.first.id != docId) {
                  setS(() => isSaving = false);
                  _showError('A policy with this policy code already exists.');
                  return;
                }

                final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
                final companyId =
                    selectedCompanyId ??
                    selectedCompanyName!
                        .toLowerCase()
                        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
                        .replaceAll(RegExp(r'^-|-$'), '');
                final data = <String, dynamic>{
                  'companyId': companyId,
                  'companyName': selectedCompanyName,
                  if (selectedCompanyLogoUrl != null &&
                      selectedCompanyLogoUrl!.isNotEmpty)
                    'companyLogoUrl': selectedCompanyLogoUrl,
                  'planName': planValue,
                  'policyCode': codeValue,
                  'description': _clean(description),
                  'category': widget.category,
                  'policySection': policySectionValue,
                  'status': selectedStatus,
                  'renewalCommission': renewalCommissionValue,
                  'specialBenefits': _clean(specialBenefits),
                  'exclusions': _clean(exclusions),
                  'generalCommissions': [
                    {'type': 'premium', 'slabs': cleanSlabs},
                  ],
                  'searchKey':
                      '$planValue $codeValue $selectedCompanyName ${widget.category} $policySectionValue'
                          .toLowerCase(),
                  'updatedAt': FieldValue.serverTimestamp(),
                  'updatedBy': uid,
                };

                if (isEdit) {
                  await FirebaseFirestore.instance
                      .collection('general_policies')
                      .doc(docId)
                      .update(data);
                  await AuditLogService.write(
                    page: widget.title,
                    action: 'Updated Policy',
                    description:
                        'Updated ${widget.category.toLowerCase()} policy "$planValue".',
                    targetId: docId,
                    targetType: 'Policy',
                    targetName: planValue,
                    extra: {'policyName': planValue},
                  );
                } else {
                  data['createdAt'] = FieldValue.serverTimestamp();
                  data['createdBy'] = uid;
                  final created = await FirebaseFirestore.instance
                      .collection('general_policies')
                      .add(data);
                  await AuditLogService.write(
                    page: widget.title,
                    action: 'Added Policy',
                    description:
                        'Added ${widget.category.toLowerCase()} policy "$planValue".',
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

            Widget slabWidget(int i) {
              final slab = slabRows[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: _dialogField(
                            controller: slab.label,
                            label: 'Slab / vehicle category',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _dialogField(
                            controller: slab.percent,
                            label: 'Payout %',
                            keyboard: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Remove slab',
                          onPressed: slabRows.length == 1
                              ? null
                              : () => setS(() {
                                  slab.disposeAll();
                                  slabRows.removeAt(i);
                                }),
                          icon: const Icon(Icons.delete_outline_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _dialogField(controller: slab.notes, label: 'Notes'),
                  ],
                ),
              );
            }

            return Dialog(
              insetPadding: const EdgeInsets.all(20),
              backgroundColor: _surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 900,
                  maxHeight: 720,
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 18, 12, 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              isEdit
                                  ? 'Edit ${widget.category} Policy'
                                  : 'Add ${widget.category} Policy',
                              style: const TextStyle(
                                color: _textMain,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: isSaving
                                ? null
                                : () => Navigator.pop(ctx),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: _border),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(22),
                        children: [
                          Wrap(
                            spacing: 14,
                            runSpacing: 14,
                            children: [
                              _companyDropdownSelect(
                                selectedId: selectedCompanyId,
                                allCompanies: allCompanies,
                                onChanged: (v) {
                                  setS(() {
                                    selectedCompanyId = v;
                                    final match = allCompanies.where(
                                      (c) => c['id'].toString() == v,
                                    );
                                    if (match.isNotEmpty) {
                                      selectedCompanyName = match
                                          .first['companyName']
                                          ?.toString();
                                      selectedCompanyLogoUrl = match
                                          .first['logoUrl']
                                          ?.toString();
                                    }
                                  });
                                },
                                width: 340,
                              ),
                              _dialogField(
                                controller: planName,
                                label: 'Plan / Product Name',
                                width: 260,
                              ),
                              _dialogField(
                                controller: policyCode,
                                label: 'Policy Code',
                                width: 180,
                              ),
                              _dropdownSelect(
                                label: 'Status',
                                value: selectedStatus,
                                items: statuses,
                                onChanged: (v) =>
                                    setS(() => selectedStatus = v),
                                width: 150,
                              ),
                              _dropdownSelect(
                                label: 'Policy Section',
                                value: selectedPolicySection,
                                items: _policySections,
                                onChanged: (v) =>
                                    setS(() => selectedPolicySection = v),
                                width: 220,
                              ),
                              if (selectedPolicySection == 'Other')
                                _dialogField(
                                  controller: customPolicySection,
                                  label: 'Other Section Name',
                                  width: 230,
                                ),
                              _dialogField(
                                controller: renewalComm,
                                label: 'Renewal Commission %',
                                keyboard: TextInputType.number,
                                width: 190,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _dialogField(
                            controller: description,
                            label: 'Description',
                            maxLines: 2,
                          ),
                          const SizedBox(height: 14),
                          _dialogField(
                            controller: specialBenefits,
                            label: 'Special Benefits',
                            maxLines: 2,
                          ),
                          const SizedBox(height: 14),
                          _dialogField(
                            controller: exclusions,
                            label: 'Exclusions',
                            maxLines: 2,
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${widget.category} commission slabs',
                                  style: const TextStyle(
                                    color: _textMain,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () => setS(
                                  () => slabRows.add(_GeneralCommSlab.empty()),
                                ),
                                icon: const Icon(Icons.add_rounded, size: 16),
                                label: const Text('Add Slab'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...slabRows.asMap().entries.map(
                            (e) => slabWidget(e.key),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: _border),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: isSaving
                                ? null
                                : () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            onPressed: isSaving ? null : save,
                            icon: isSaving
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.check_rounded, size: 16),
                            label: Text(isEdit ? 'Update' : 'Save'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    planName.dispose();
    policyCode.dispose();
    description.dispose();
    customPolicySection.dispose();
    renewalComm.dispose();
    specialBenefits.dispose();
    exclusions.dispose();
    for (final slab in slabRows) {
      slab.disposeAll();
    }
  }

  Widget _companyDropdownSelect({
    required String? selectedId,
    required List<Map<String, dynamic>> allCompanies,
    required ValueChanged<String> onChanged,
    double width = 340,
  }) {
    final validId = allCompanies.any((c) => c['id'].toString() == selectedId)
        ? selectedId
        : null;

    return SizedBox(
      width: width,
      child: DropdownButtonFormField<String>(
        isExpanded: true,
        value: validId,
        hint: const Text(
          'Select Company',
          style: TextStyle(color: _textMuted, fontSize: 13),
        ),
        items: allCompanies
            .map(
              (c) => DropdownMenuItem<String>(
                value: c['id'].toString(),
                child: Row(
                  children: [
                    CompanyLogo(
                      companyName: c['companyName']?.toString() ?? '',
                      customLogoUrl: c['logoUrl']?.toString(),
                      size: 20,
                      radius: 5,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        c['companyName']?.toString() ?? '',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: _textMain),
                      ),
                    ),
                    if ((c['companyType']?.toString() ?? '').isNotEmpty)
                      Text(
                        '(${c['companyType']})',
                        style: const TextStyle(color: _textMuted, fontSize: 11),
                      ),
                  ],
                ),
              ),
            )
            .toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
        decoration: _inputDecoration('Company'),
      ),
    );
  }

  Widget _dropdownSelect({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String> onChanged,
    double width = 170,
  }) {
    final validValue = items.contains(value)
        ? value
        : (items.isNotEmpty ? items.first : null);

    return SizedBox(
      width: width,
      child: DropdownButtonFormField<String>(
        isExpanded: true,
        value: validValue,
        items: items
            .map(
              (s) => DropdownMenuItem<String>(
                value: s,
                child: Text(
                  s,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: _textMain),
                ),
              ),
            )
            .toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
        decoration: _inputDecoration(label),
      ),
    );
  }

  Widget _dialogField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboard,
    int maxLines = 1,
    double? width,
  }) {
    final field = TextField(
      controller: controller,
      keyboardType: keyboard,
      maxLines: maxLines,
      decoration: _inputDecoration(label),
    );
    if (width == null) return field;
    return SizedBox(width: width, child: field);
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _textMuted, fontSize: 12),
      filled: true,
      fillColor: _bg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
        borderSide: const BorderSide(color: _accent, width: 1.4),
      ),
    );
  }
}

class _GeneralCommSlab {
  final TextEditingController label;
  final TextEditingController percent;
  final TextEditingController notes;

  _GeneralCommSlab({
    required this.label,
    required this.percent,
    required this.notes,
  });

  factory _GeneralCommSlab.empty() => _GeneralCommSlab(
    label: TextEditingController(),
    percent: TextEditingController(),
    notes: TextEditingController(),
  );

  void disposeAll() {
    label.dispose();
    percent.dispose();
    notes.dispose();
  }
}

class _GeneralPolicyGridCard extends StatefulWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final int serialNumber;
  final VoidCallback onTap;

  const _GeneralPolicyGridCard({
    required this.doc,
    required this.serialNumber,
    required this.onTap,
  });

  @override
  State<_GeneralPolicyGridCard> createState() => _GeneralPolicyGridCardState();
}

class _GeneralPolicyGridCardState extends State<_GeneralPolicyGridCard> {
  bool _isHovered = false;

  static int _slabCount(Map<String, dynamic> data) {
    final groups = data['generalCommissions'];
    if (groups is! List) return 0;
    var count = 0;
    for (final group in groups) {
      if (group is Map && group['slabs'] is List) {
        count += (group['slabs'] as List).length;
      }
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.doc.data();
    final companyName = (data['companyName'] ?? '').toString();
    final planName = (data['planName'] ?? 'General Policy').toString();
    final policyCode = (data['policyCode'] ?? '').toString();
    final slabs = _slabCount(data);
    final status = (data['status'] ?? 'Active').toString();
    final isActive = status.toLowerCase().contains('active');
    final statusColor = isActive
        ? const Color(0xFF16A34A)
        : const Color(0xFFF59E0B);

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
            color: _GeneralPoliciesTabState._surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovered
                  ? _GeneralPoliciesTabState._accent
                  : _GeneralPoliciesTabState._border,
              width: _isHovered ? 1.5 : 1.0,
            ),
            boxShadow: [
              if (_isHovered)
                BoxShadow(
                  color: _GeneralPoliciesTabState._accent.withValues(
                    alpha: 0.08,
                  ),
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
                    color: _GeneralPoliciesTabState._bg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _GeneralPoliciesTabState._border),
                  ),
                  child: Text(
                    '#${widget.serialNumber}',
                    style: const TextStyle(
                      color: _GeneralPoliciesTabState._textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -8,
                right: -8,
                child: _MiniPill(label: status, color: statusColor),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(width: 4),
                  CompanyLogo(
                    companyName: companyName,
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
                          companyName.isNotEmpty ? companyName : '-',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _GeneralPoliciesTabState._textMain,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          planName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _GeneralPoliciesTabState._textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          policyCode.isNotEmpty
                              ? '$policyCode  |  $slabs slabs'
                              : '$slabs slabs',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _GeneralPoliciesTabState._textMuted,
                            fontSize: 11,
                          ),
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

class _GeneralPolicyDetailView extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final VoidCallback onBack;
  final VoidCallback onEdit;
  final VoidCallback onDeleted;

  const _GeneralPolicyDetailView({
    required this.doc,
    required this.onBack,
    required this.onEdit,
    required this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final groups = data['generalCommissions'];

    return Scaffold(
      backgroundColor: _GeneralPoliciesTabState._bg,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: _GeneralPoliciesTabState._surface,
              padding: const EdgeInsets.fromLTRB(16, 14, 18, 14),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (data['planName'] ?? 'General Policy').toString(),
                          style: const TextStyle(
                            color: _GeneralPoliciesTabState._textMain,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        CompanyLogoLabel(
                          companyName: (data['companyName'] ?? '-').toString(),
                          logoSize: 18,
                          style: const TextStyle(
                            color: _GeneralPoliciesTabState._textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit'),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => _delete(context),
                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                    label: const Text('Delete'),
                    style: TextButton.styleFrom(
                      foregroundColor: _GeneralPoliciesTabState._red,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: _GeneralPoliciesTabState._border),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _InfoCard(
                        title: 'Policy Code',
                        value: (data['policyCode'] ?? '-').toString(),
                        icon: Icons.tag_rounded,
                      ),
                      _InfoCard(
                        title: 'Category',
                        value: (data['category'] ?? 'General').toString(),
                        icon: Icons.category_outlined,
                      ),
                      _InfoCard(
                        title: 'Section',
                        value: (data['policySection'] ?? '-').toString(),
                        icon: Icons.view_list_outlined,
                      ),
                      _InfoCard(
                        title: 'Renewal',
                        value: '${data['renewalCommission'] ?? 0}%',
                        icon: Icons.repeat_rounded,
                      ),
                      _InfoCard(
                        title: 'Status',
                        value: (data['status'] ?? 'Active').toString(),
                        icon: Icons.verified_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Policy Details',
                          style: TextStyle(
                            color: _GeneralPoliciesTabState._textMain,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _kv('Description', data['description']),
                        _kv('Special Benefits', data['specialBenefits']),
                        _kv('Exclusions', data['exclusions']),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Commission Slabs',
                          style: TextStyle(
                            color: _GeneralPoliciesTabState._textMain,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (groups is! List || groups.isEmpty)
                          const Text(
                            'No general slabs configured.',
                            style: TextStyle(
                              color: _GeneralPoliciesTabState._textMuted,
                            ),
                          )
                        else
                          ...groups.map((group) => _slabGroup(group)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _slabGroup(dynamic group) {
    if (group is! Map) return const SizedBox.shrink();
    final slabs = group['slabs'];
    if (slabs is! List || slabs.isEmpty) {
      return const Text(
        'No slabs found.',
        style: TextStyle(color: _GeneralPoliciesTabState._textMuted),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStatePropertyAll(
          _GeneralPoliciesTabState._primary.withValues(alpha: 0.06),
        ),
        columns: const [
          DataColumn(label: Text('Slab / Category')),
          DataColumn(label: Text('Payout')),
          DataColumn(label: Text('Notes')),
        ],
        rows: slabs.map<DataRow>((raw) {
          final slab = raw is Map ? raw : <String, dynamic>{};
          final pct = slab['percent'];
          return DataRow(
            cells: [
              DataCell(Text((slab['label'] ?? '-').toString())),
              DataCell(Text(pct == null ? '-' : '${pct.toString()}%')),
              DataCell(Text((slab['notes'] ?? '').toString())),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _kv(String label, dynamic value) {
    final text = (value ?? '').toString().trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                color: _GeneralPoliciesTabState._textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text.isEmpty ? '-' : text,
              style: const TextStyle(
                color: _GeneralPoliciesTabState._textMain,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete policy?'),
        content: const Text('This removes the general policy configuration.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _GeneralPoliciesTabState._red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final data = doc.data();
    final deletedPlanName = (data['planName'] ?? 'General Policy').toString();
    await FirebaseFirestore.instance
        .collection('general_policies')
        .doc(doc.id)
        .delete();
    await AuditLogService.write(
      page: 'General Policies',
      action: 'Deleted Policy',
      description: 'Deleted general policy "$deletedPlanName".',
      targetId: doc.id,
      targetType: 'Policy',
      targetName: deletedPlanName,
      extra: {'policyName': deletedPlanName},
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Policy deleted'),
          backgroundColor: _GeneralPoliciesTabState._primary,
        ),
      );
      onDeleted();
    }
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _InfoCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _GeneralPoliciesTabState._surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _GeneralPoliciesTabState._border),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _GeneralPoliciesTabState._accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: _GeneralPoliciesTabState._accent,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _GeneralPoliciesTabState._textMain,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    color: _GeneralPoliciesTabState._textMuted,
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
        color: _GeneralPoliciesTabState._surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _GeneralPoliciesTabState._border),
      ),
      child: child,
    );
  }
}

class _MiniPill extends StatelessWidget {
  final String label;
  final Color color;

  const _MiniPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
