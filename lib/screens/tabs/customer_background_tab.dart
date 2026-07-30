import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CustomerBackgroundTab extends StatefulWidget {
  const CustomerBackgroundTab({super.key});

  @override
  State<CustomerBackgroundTab> createState() => _CustomerBackgroundTabState();
}

class _CustomerBackgroundTabState extends State<CustomerBackgroundTab> {
  static const _primary = Color(0xFF0D2D4F);
  static const _accent = Color(0xFF1A6EBD);
  static const _bg = Color(0xFFF4F6F9);
  static const _surface = Color(0xFFFFFFFF);
  static const _border = Color(0xFFE4E7EC);
  static const _textMain = Color(0xFF0D1B2A);
  static const _textMuted = Color(0xFF667085);
  static const _green = Color(0xFF16A34A);
  static const _amber = Color(0xFFF59E0B);
  static const _red = Color(0xFFDC2626);

  final _searchCtrl = TextEditingController();
  String _query = '';
  String _filter = 'All';
  String? _selectedCustomerId;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> get _customersStream =>
      FirebaseFirestore.instance
          .collection('customers')
          .orderBy('createdAt', descending: true)
          .snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> get _profilesStream =>
      FirebaseFirestore.instance
          .collection('customer_background_profiles')
          .snapshots();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _customersStream,
          builder: (context, customerSnap) {
            if (customerSnap.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: _accent),
              );
            }
            if (customerSnap.hasError) {
              return Center(
                child: Text(
                  'Error: ${customerSnap.error}',
                  style: const TextStyle(color: _red),
                ),
              );
            }

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _profilesStream,
              builder: (context, profileSnap) {
                if (profileSnap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: _accent),
                  );
                }
                if (profileSnap.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${profileSnap.error}',
                      style: const TextStyle(color: _red),
                    ),
                  );
                }

                final profileMap = {
                  for (final doc in profileSnap.data?.docs ?? [])
                    doc.id: doc.data(),
                };
                final records = (customerSnap.data?.docs ?? [])
                    .map(
                      (doc) => _BackgroundCustomerRecord.fromCustomerDoc(
                        doc,
                        profileMap[doc.id],
                      ),
                    )
                    .where(_matchesFilter)
                    .toList();

                final selectedRecord = _resolveSelectedRecord(records);
                final completedCount = records
                    .where((record) => record.profileStatus == 'Completed')
                    .length;
                final inProgressCount = records
                    .where((record) => record.profileStatus == 'In Progress')
                    .length;
                final needsAttentionCount = records
                    .where((record) => record.needsAttention)
                    .length;

                return Column(
                  children: [
                    _Header(
                      controller: _searchCtrl,
                      onSearchChanged: (value) =>
                          setState(() => _query = value.trim().toLowerCase()),
                      filter: _filter,
                      onFilterChanged: (value) =>
                          setState(() => _filter = value),
                      total: records.length,
                      completed: completedCount,
                      inProgress: inProgressCount,
                      needsAttention: needsAttentionCount,
                    ),
                    const Divider(height: 1, color: _border),
                    Expanded(
                      child: records.isEmpty
                          ? const _EmptyState()
                          : LayoutBuilder(
                              builder: (context, constraints) {
                                final stacked = constraints.maxWidth < 1080;
                                if (stacked) {
                                  return ListView(
                                    padding: const EdgeInsets.all(18),
                                    children: [
                                      _CustomerList(
                                        records: records,
                                        selectedId: selectedRecord?.id,
                                        onSelect: (record) => setState(
                                          () => _selectedCustomerId = record.id,
                                        ),
                                        compact: false,
                                      ),
                                      const SizedBox(height: 16),
                                      if (selectedRecord != null)
                                        _QuestionnairePanel(
                                          key: ValueKey(selectedRecord.id),
                                          record: selectedRecord,
                                        ),
                                    ],
                                  );
                                }

                                return Padding(
                                  padding: const EdgeInsets.all(18),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                        width: 360,
                                        child: _CustomerList(
                                          records: records,
                                          selectedId: selectedRecord?.id,
                                          onSelect: (record) => setState(
                                            () =>
                                                _selectedCustomerId = record.id,
                                          ),
                                          compact: true,
                                        ),
                                      ),
                                      const SizedBox(width: 18),
                                      Expanded(
                                        child: selectedRecord == null
                                            ? const _SelectPrompt()
                                            : _QuestionnairePanel(
                                                key: ValueKey(
                                                  selectedRecord.id,
                                                ),
                                                record: selectedRecord,
                                              ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  bool _matchesFilter(_BackgroundCustomerRecord record) {
    final query = _query;
    final matchesSearch =
        query.isEmpty ||
        record.name.toLowerCase().contains(query) ||
        record.mobile.toLowerCase().contains(query) ||
        record.policyName.toLowerCase().contains(query) ||
        record.policyCode.toLowerCase().contains(query);

    final matchesStatus =
        _filter == 'All' ||
        (_filter == 'Completed' && record.profileStatus == 'Completed') ||
        (_filter == 'In Progress' && record.profileStatus == 'In Progress') ||
        (_filter == 'Not Started' && record.profileStatus == 'Not Started') ||
        (_filter == 'Needs Attention' && record.needsAttention);

    return matchesSearch && matchesStatus;
  }

  _BackgroundCustomerRecord? _resolveSelectedRecord(
    List<_BackgroundCustomerRecord> records,
  ) {
    if (records.isEmpty) {
      _selectedCustomerId = null;
      return null;
    }

    if (_selectedCustomerId == null) {
      _selectedCustomerId = records.first.id;
      return records.first;
    }

    for (final record in records) {
      if (record.id == _selectedCustomerId) return record;
    }

    _selectedCustomerId = records.first.id;
    return records.first;
  }
}

class _BackgroundCustomerRecord {
  final String id;
  final String name;
  final String mobile;
  final String customerType;
  final String maritalStatus;
  final String gender;
  final String policyName;
  final String policyCode;
  final String profileStatus;
  final int completion;
  final String healthRisk;
  final Map<String, dynamic> profileData;
  final Map<String, dynamic> customerData;

  const _BackgroundCustomerRecord({
    required this.id,
    required this.name,
    required this.mobile,
    required this.customerType,
    required this.maritalStatus,
    required this.gender,
    required this.policyName,
    required this.policyCode,
    required this.profileStatus,
    required this.completion,
    required this.healthRisk,
    required this.profileData,
    required this.customerData,
  });

  factory _BackgroundCustomerRecord.fromCustomerDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> customerDoc,
    Map<String, dynamic>? profileData,
  ) {
    final customer = customerDoc.data();
    final answers = Map<String, dynamic>.from(
      (profileData?['answers'] as Map<String, dynamic>?) ?? const {},
    );
    final completion = (profileData?['completion'] as num?)?.toInt() ?? 0;
    final status = (profileData?['profileStatus'] ?? '').toString().trim();
    final profileStatus = status.isEmpty
        ? 'Not Started'
        : status == 'Completed'
        ? 'Completed'
        : 'In Progress';

    return _BackgroundCustomerRecord(
      id: customerDoc.id,
      name: (customer['fullName'] ?? '').toString(),
      mobile: (customer['mobileNumber'] ?? '').toString(),
      customerType: (customer['customerType'] ?? '').toString(),
      maritalStatus: (customer['maritalStatus'] ?? '').toString(),
      gender: (customer['gender'] ?? '').toString(),
      policyName: (customer['policyName'] ?? '').toString(),
      policyCode: (customer['policyCode'] ?? '').toString(),
      profileStatus: profileStatus,
      completion: completion,
      healthRisk: _QuestionnaireSummary.fromAnswers(
        answers,
        completion: completion,
      ).healthRisk,
      profileData: profileData ?? const {},
      customerData: customer,
    );
  }

  bool get needsAttention =>
      profileStatus != 'Completed' || healthRisk == 'High' || completion < 60;
}

class _Header extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSearchChanged;
  final String filter;
  final ValueChanged<String> onFilterChanged;
  final int total;
  final int completed;
  final int inProgress;
  final int needsAttention;

  const _Header({
    required this.controller,
    required this.onSearchChanged,
    required this.filter,
    required this.onFilterChanged,
    required this.total,
    required this.completed,
    required this.inProgress,
    required this.needsAttention,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _CustomerBackgroundTabState._surface,
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Customer Background',
                      style: TextStyle(
                        color: _CustomerBackgroundTabState._textMain,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Family and health questionnaire with progressive next-step logic.',
                      style: TextStyle(
                        color: _CustomerBackgroundTabState._textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              _StatPill(
                label: 'Customers',
                value: total.toString(),
                color: _CustomerBackgroundTabState._primary,
              ),
              const SizedBox(width: 8),
              _StatPill(
                label: 'Completed',
                value: completed.toString(),
                color: _CustomerBackgroundTabState._green,
              ),
              const SizedBox(width: 8),
              _StatPill(
                label: 'Drafts',
                value: inProgress.toString(),
                color: _CustomerBackgroundTabState._amber,
              ),
              const SizedBox(width: 8),
              _StatPill(
                label: 'Attention',
                value: needsAttention.toString(),
                color: _CustomerBackgroundTabState._red,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: onSearchChanged,
                  decoration: InputDecoration(
                    hintText:
                        'Search by customer name, mobile, policy name, or code...',
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: _CustomerBackgroundTabState._textMuted,
                      size: 18,
                    ),
                    filled: true,
                    fillColor: _CustomerBackgroundTabState._bg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: _CustomerBackgroundTabState._border,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: _CustomerBackgroundTabState._border,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: _CustomerBackgroundTabState._accent,
                        width: 1.4,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: _CustomerBackgroundTabState._bg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _CustomerBackgroundTabState._border,
                  ),
                ),
                child: DropdownButton<String>(
                  value: filter,
                  underline: const SizedBox.shrink(),
                  borderRadius: BorderRadius.circular(8),
                  items:
                      const [
                            'All',
                            'Completed',
                            'In Progress',
                            'Not Started',
                            'Needs Attention',
                          ]
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(item),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    if (value != null) onFilterChanged(value);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: _CustomerBackgroundTabState._textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerList extends StatelessWidget {
  final List<_BackgroundCustomerRecord> records;
  final String? selectedId;
  final ValueChanged<_BackgroundCustomerRecord> onSelect;
  final bool compact;

  const _CustomerList({
    required this.records,
    required this.selectedId,
    required this.onSelect,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _CustomerBackgroundTabState._surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _CustomerBackgroundTabState._border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 15, 16, 10),
            child: Text(
              'Customers',
              style: TextStyle(
                color: _CustomerBackgroundTabState._textMain,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const Divider(height: 1, color: _CustomerBackgroundTabState._border),
          if (compact)
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(10),
                itemCount: records.length,
                separatorBuilder: (_, separatorIndex) =>
                    const SizedBox(height: 8),
                itemBuilder: (_, index) => _CustomerListCard(
                  record: records[index],
                  selected: records[index].id == selectedId,
                  onTap: () => onSelect(records[index]),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: records
                    .map(
                      (record) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _CustomerListCard(
                          record: record,
                          selected: record.id == selectedId,
                          onTap: () => onSelect(record),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _CustomerListCard extends StatelessWidget {
  final _BackgroundCustomerRecord record;
  final bool selected;
  final VoidCallback onTap;

  const _CustomerListCard({
    required this.record,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (record.profileStatus) {
      'Completed' => _CustomerBackgroundTabState._green,
      'In Progress' => _CustomerBackgroundTabState._amber,
      _ => _CustomerBackgroundTabState._textMuted,
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? _CustomerBackgroundTabState._accent.withValues(alpha: 0.05)
              : _CustomerBackgroundTabState._surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? _CustomerBackgroundTabState._accent
                : _CustomerBackgroundTabState._border,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: _CustomerBackgroundTabState._primary.withValues(
                alpha: 0.08,
              ),
              child: Text(
                record.name.isNotEmpty ? record.name[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: _CustomerBackgroundTabState._primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.name.isEmpty ? 'Unnamed customer' : record.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _CustomerBackgroundTabState._textMain,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    record.mobile,
                    style: const TextStyle(
                      color: _CustomerBackgroundTabState._textMuted,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _SmallChip(
                        label: record.profileStatus,
                        color: statusColor,
                      ),
                      const SizedBox(width: 6),
                      _SmallChip(
                        label: '${record.completion}%',
                        color: _CustomerBackgroundTabState._accent,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: _CustomerBackgroundTabState._textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionnairePanel extends StatefulWidget {
  final _BackgroundCustomerRecord record;

  const _QuestionnairePanel({super.key, required this.record});

  @override
  State<_QuestionnairePanel> createState() => _QuestionnairePanelState();
}

class _QuestionnairePanelState extends State<_QuestionnairePanel> {
  static const _primary = _CustomerBackgroundTabState._primary;
  static const _accent = _CustomerBackgroundTabState._accent;
  static const _surface = _CustomerBackgroundTabState._surface;
  static const _border = _CustomerBackgroundTabState._border;
  static const _textMain = _CustomerBackgroundTabState._textMain;
  static const _textMuted = _CustomerBackgroundTabState._textMuted;
  static const _green = _CustomerBackgroundTabState._green;
  static const _red = _CustomerBackgroundTabState._red;

  late Map<String, dynamic> _answers;
  late int _stepIndex;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _answers = Map<String, dynamic>.from(
      (widget.record.profileData['answers'] as Map<String, dynamic>?) ?? {},
    );
    _applyCustomerDefaults();
    _stepIndex = 0;
  }

  List<_QuestionStep> get _steps =>
      _buildSteps(customer: widget.record, answers: _answers);

  _QuestionStep get _currentStep {
    final steps = _steps;
    if (_stepIndex >= steps.length) _stepIndex = steps.length - 1;
    if (_stepIndex < 0) _stepIndex = 0;
    return steps[_stepIndex];
  }

  void _applyCustomerDefaults() {
    if ((_answers['householdType'] ?? '').toString().isEmpty) {
      final marital = widget.record.maritalStatus.toLowerCase();
      if (marital == 'married') {
        _answers['householdType'] = 'Married';
      } else if (widget.record.customerType.toLowerCase() == 'family') {
        _answers['householdType'] = 'Joint Family';
      } else {
        _answers['householdType'] = 'Single';
      }
    }
    _answers['customerName'] = widget.record.name;
    _answers['customerMobile'] = widget.record.mobile;
  }

  @override
  Widget build(BuildContext context) {
    final steps = _steps;
    final summary = _QuestionnaireSummary.fromAnswers(
      _answers,
      completion: _completion(steps),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHero(summary),
        const SizedBox(height: 16),
        _buildProgress(summary, steps),
        const SizedBox(height: 16),
        _buildStepCard(_currentStep, summary, steps),
      ],
    );
  }

  Widget _buildHero(_QuestionnaireSummary summary) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: _primary.withValues(alpha: 0.08),
                child: Text(
                  widget.record.name.isNotEmpty
                      ? widget.record.name[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: _primary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.record.name.isEmpty
                          ? 'Unnamed customer'
                          : widget.record.name,
                      style: const TextStyle(
                        color: _textMain,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        widget.record.mobile,
                        if (widget.record.policyName.isNotEmpty)
                          widget.record.policyName,
                      ].join('  |  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              _RiskBadge(label: summary.healthRisk, color: summary.healthColor),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MetricTile(
                label: 'Family members',
                value: summary.familyMemberCount.toString(),
              ),
              _MetricTile(label: 'Completion', value: '${summary.completion}%'),
              _MetricTile(label: 'Questionnaire', value: summary.profileStatus),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgress(
    _QuestionnaireSummary summary,
    List<_QuestionStep> steps,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Questionnaire progress',
                  style: TextStyle(
                    color: _textMain,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                'Step ${_stepIndex + 1} of ${steps.length}',
                style: const TextStyle(
                  color: _textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: summary.completion / 100,
              minHeight: 8,
              color: _accent,
              backgroundColor: _border,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: steps.asMap().entries.map((entry) {
              final isCurrent = entry.key == _stepIndex;
              final isDone = _isAnswered(entry.value);
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? _accent.withValues(alpha: 0.08)
                      : isDone
                      ? _green.withValues(alpha: 0.08)
                      : _surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isCurrent
                        ? _accent
                        : isDone
                        ? _green.withValues(alpha: 0.25)
                        : _border,
                  ),
                ),
                child: Text(
                  entry.value.shortLabel,
                  style: TextStyle(
                    color: isCurrent
                        ? _accent
                        : isDone
                        ? _green
                        : _textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard(
    _QuestionStep step,
    _QuestionnaireSummary summary,
    List<_QuestionStep> steps,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            step.section,
            style: const TextStyle(
              color: _accent,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            step.title,
            style: const TextStyle(
              color: _textMain,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (step.helper.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              step.helper,
              style: const TextStyle(
                color: _textMuted,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 18),
          _AnswerField(
            step: step,
            value: _answers[step.id],
            onChanged: (value) {
              setState(() {
                _answers[step.id] = value;
                _cleanupAnswers();
              });
            },
          ),
          const SizedBox(height: 18),
          const Divider(height: 1, color: _border),
          const SizedBox(height: 16),
          Row(
            children: [
              TextButton(
                onPressed: _stepIndex == 0
                    ? null
                    : () => setState(() => _stepIndex -= 1),
                child: const Text('Back'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _isSaving ? null : () => _saveDraft(steps),
                icon: _isSaving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined, size: 16),
                label: const Text('Save Draft'),
              ),
              const Spacer(),
              if (_stepIndex < steps.length - 1)
                ElevatedButton.icon(
                  onPressed: !_isAnswered(step)
                      ? null
                      : () => setState(() => _stepIndex += 1),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: const Text('Next Question'),
                )
              else
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : () => _complete(steps, summary),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.task_alt_rounded, size: 16),
                  label: const Text('Complete Questionnaire'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _cleanupAnswers() {
    final stepIds = _steps.map((step) => step.id).toSet();
    _answers.removeWhere(
      (key, value) =>
          !_reservedAnswerKeys.contains(key) && !stepIds.contains(key),
    );
    if (_stepIndex >= _steps.length) {
      _stepIndex = _steps.length - 1;
    }
  }

  bool _isAnswered(_QuestionStep step) {
    final value = _answers[step.id];
    if (!step.required) return true;
    if (value == null) return false;
    if (value is String) return value.trim().isNotEmpty;
    if (value is List) return value.isNotEmpty;
    return true;
  }

  int _completion(List<_QuestionStep> steps) {
    if (steps.isEmpty) return 0;
    final answered = steps.where(_isAnswered).length;
    return ((answered / steps.length) * 100).round();
  }

  Future<void> _saveDraft(List<_QuestionStep> steps) async {
    await _persist(
      steps: steps,
      profileStatus: 'In Progress',
      completion: _completion(steps),
    );
  }

  Future<void> _complete(
    List<_QuestionStep> steps,
    _QuestionnaireSummary summary,
  ) async {
    final missing = steps.where((step) => !_isAnswered(step)).toList();
    if (missing.isNotEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Complete "${missing.first.title}" before finishing the questionnaire.',
          ),
          backgroundColor: _red,
        ),
      );
      return;
    }

    await _persist(
      steps: steps,
      profileStatus: 'Completed',
      completion: 100,
      summary: summary.copyWith(completion: 100, profileStatus: 'Completed'),
    );
  }

  Future<void> _persist({
    required List<_QuestionStep> steps,
    required String profileStatus,
    required int completion,
    _QuestionnaireSummary? summary,
  }) async {
    setState(() => _isSaving = true);
    try {
      final profileRef = FirebaseFirestore.instance
          .collection('customer_background_profiles')
          .doc(widget.record.id);
      final customerRef = FirebaseFirestore.instance
          .collection('customers')
          .doc(widget.record.id);
      final now = FieldValue.serverTimestamp();
      final computedSummary =
          summary ??
          _QuestionnaireSummary.fromAnswers(
            _answers,
            completion: completion,
            profileStatus: profileStatus,
          );

      final batch = FirebaseFirestore.instance.batch();
      batch.set(profileRef, {
        'customerId': widget.record.id,
        'customerName': widget.record.name,
        'customerMobile': widget.record.mobile,
        'answers': _answers,
        'completion': completion,
        'profileStatus': profileStatus,
        'healthRisk': computedSummary.healthRisk,
        'familyMemberCount': computedSummary.familyMemberCount,
        'updatedAt': now,
        'createdAt': widget.record.profileData.isEmpty
            ? now
            : widget.record.profileData['createdAt'] ?? now,
      }, SetOptions(merge: true));

      batch.set(customerRef, {
        'backgroundProfileStatus': profileStatus,
        'backgroundCompletion': completion,
        'backgroundHealthRisk': computedSummary.healthRisk,
        'backgroundUpdatedAt': now,
      }, SetOptions(merge: true));

      await batch.commit();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            profileStatus == 'Completed'
                ? 'Customer background questionnaire completed.'
                : 'Customer background draft saved.',
          ),
          backgroundColor: profileStatus == 'Completed'
              ? _green
              : _CustomerBackgroundTabState._primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save questionnaire: $e'),
          backgroundColor: _red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

const _reservedAnswerKeys = {'customerName', 'customerMobile'};

class _QuestionnaireSummary {
  final int completion;
  final String profileStatus;
  final String healthRisk;
  final int familyMemberCount;

  const _QuestionnaireSummary({
    required this.completion,
    required this.profileStatus,
    required this.healthRisk,
    required this.familyMemberCount,
  });

  factory _QuestionnaireSummary.fromAnswers(
    Map<String, dynamic> answers, {
    required int completion,
    String? profileStatus,
  }) {
    int riskScore = 0;
    if (_boolValue(answers['preExistingDisease'])) riskScore += 3;
    if (_boolValue(answers['hospitalisedLastFiveYears'])) riskScore += 2;
    if (_boolValue(answers['currentMedication'])) riskScore += 2;
    if ((answers['smoker'] ?? '').toString() == 'Yes') riskScore += 2;
    if ((answers['alcoholFrequency'] ?? '').toString() == 'Regular') {
      riskScore += 1;
    }
    if (_boolValue(answers['hazardousActivities'])) riskScore += 1;

    final children =
        int.tryParse((answers['childrenCount'] ?? '0').toString()) ?? 0;
    final parents = switch ((answers['dependentParents'] ?? '').toString()) {
      'One Parent' => 1,
      'Both Parents' => 2,
      _ => 0,
    };
    final spouse = _boolValue(answers['spouseIncluded']) ? 1 : 0;
    final familyMemberCount = 1 + spouse + children + parents;

    String healthRisk;
    if (riskScore >= 5) {
      healthRisk = 'High';
    } else if (riskScore >= 2) {
      healthRisk = 'Medium';
    } else {
      healthRisk = 'Low';
    }

    return _QuestionnaireSummary(
      completion: completion,
      profileStatus:
          profileStatus ??
          (completion >= 100
              ? 'Completed'
              : completion > 0
              ? 'In Progress'
              : 'Not Started'),
      healthRisk: healthRisk,
      familyMemberCount: familyMemberCount,
    );
  }

  Color get healthColor => switch (healthRisk) {
    'High' => _CustomerBackgroundTabState._red,
    'Medium' => _CustomerBackgroundTabState._amber,
    _ => _CustomerBackgroundTabState._green,
  };

  _QuestionnaireSummary copyWith({
    int? completion,
    String? profileStatus,
    String? healthRisk,
    int? familyMemberCount,
  }) {
    return _QuestionnaireSummary(
      completion: completion ?? this.completion,
      profileStatus: profileStatus ?? this.profileStatus,
      healthRisk: healthRisk ?? this.healthRisk,
      familyMemberCount: familyMemberCount ?? this.familyMemberCount,
    );
  }
}

bool _boolValue(dynamic value) {
  if (value is bool) return value;
  final text = (value ?? '').toString().toLowerCase();
  return text == 'yes' || text == 'true';
}

List<_QuestionStep> _buildSteps({
  required _BackgroundCustomerRecord customer,
  required Map<String, dynamic> answers,
}) {
  final householdType = (answers['householdType'] ?? '').toString();
  final spouseIncluded = _boolValue(answers['spouseIncluded']);
  final childrenCount =
      int.tryParse((answers['childrenCount'] ?? '0').toString()) ?? 0;
  final dependentParents = (answers['dependentParents'] ?? '').toString();
  final hasFamilyMedicalHistory = _boolValue(answers['familyMedicalHistory']);
  final hasDisease = _boolValue(answers['preExistingDisease']);
  final hasMedication = _boolValue(answers['currentMedication']);
  final hasHospitalisation = _boolValue(answers['hospitalisedLastFiveYears']);
  final smoker = (answers['smoker'] ?? '').toString();
  final hazardousActivities = _boolValue(answers['hazardousActivities']);

  final steps = <_QuestionStep>[
    const _QuestionStep.choice(
      id: 'householdType',
      section: 'Family Structure',
      shortLabel: 'Household',
      title: 'What best describes this customer household?',
      helper: 'This drives the rest of the family questions.',
      options: ['Single', 'Married', 'Joint Family', 'Parent + Children'],
    ),
    const _QuestionStep.choice(
      id: 'coverFor',
      section: 'Family Structure',
      shortLabel: 'Coverage Need',
      title: 'Who needs to be included in the insurance recommendation?',
      helper: 'Choose the main coverage intent for this customer.',
      options: [
        'Self Only',
        'Self + Spouse',
        'Self + Children',
        'Whole Family',
      ],
    ),
  ];

  if (householdType == 'Married' || householdType == 'Joint Family') {
    steps.add(
      const _QuestionStep.yesNo(
        id: 'spouseIncluded',
        section: 'Family Structure',
        shortLabel: 'Spouse',
        title: 'Should spouse details be considered in this profile?',
        helper: 'If yes, the next step asks for spouse age.',
      ),
    );
  }

  if (spouseIncluded) {
    steps.add(
      const _QuestionStep.number(
        id: 'spouseAge',
        section: 'Family Structure',
        shortLabel: 'Spouse Age',
        title: 'What is the spouse age?',
        helper: 'Enter completed years.',
      ),
    );
  }

  if (householdType != 'Single') {
    steps.add(
      const _QuestionStep.number(
        id: 'childrenCount',
        section: 'Family Structure',
        shortLabel: 'Children',
        title: 'How many children are financially dependent on the customer?',
        helper: 'Enter 0 when there are no dependent children.',
      ),
    );
  }

  if (childrenCount > 0) {
    steps.add(
      const _QuestionStep.text(
        id: 'childrenAges',
        section: 'Family Structure',
        shortLabel: 'Children Ages',
        title: 'Enter the children ages.',
        helper: 'Use comma-separated ages, for example 4, 8, 12.',
      ),
    );
  }

  steps.add(
    const _QuestionStep.choice(
      id: 'dependentParents',
      section: 'Family Structure',
      shortLabel: 'Parents',
      title: 'Are dependent parents part of this insurance evaluation?',
      helper: 'This helps identify elder-care coverage needs.',
      options: ['None', 'One Parent', 'Both Parents'],
    ),
  );

  if (dependentParents == 'One Parent' || dependentParents == 'Both Parents') {
    steps.add(
      const _QuestionStep.text(
        id: 'parentAges',
        section: 'Family Structure',
        shortLabel: 'Parent Ages',
        title: 'Enter the parent ages.',
        helper: 'Use comma-separated ages if more than one parent is included.',
      ),
    );
  }

  steps.add(
    const _QuestionStep.yesNo(
      id: 'familyMedicalHistory',
      section: 'Family Health',
      shortLabel: 'Family History',
      title:
          'Is there any family medical history that affects coverage choice?',
      helper: 'Examples include diabetes, cardiac history, stroke, or cancer.',
    ),
  );

  if (hasFamilyMedicalHistory) {
    steps.add(
      const _QuestionStep.text(
        id: 'familyMedicalHistoryDetails',
        section: 'Family Health',
        shortLabel: 'Family Details',
        title: 'Describe the relevant family medical history.',
        helper: 'Keep it short and underwriting-friendly.',
      ),
    );
  }

  steps.addAll(const [
    _QuestionStep.number(
      id: 'heightCm',
      section: 'Applicant Health',
      shortLabel: 'Height',
      title: 'What is the customer height in centimeters?',
      helper: 'Used to estimate health risk and suitability.',
    ),
    _QuestionStep.number(
      id: 'weightKg',
      section: 'Applicant Health',
      shortLabel: 'Weight',
      title: 'What is the customer weight in kilograms?',
      helper: 'Used along with height for BMI estimation.',
    ),
    _QuestionStep.yesNo(
      id: 'preExistingDisease',
      section: 'Applicant Health',
      shortLabel: 'Disease',
      title: 'Does the customer have any pre-existing disease?',
      helper: 'If yes, the next step captures details.',
    ),
  ]);

  if (hasDisease) {
    steps.add(
      const _QuestionStep.text(
        id: 'preExistingDiseaseDetails',
        section: 'Applicant Health',
        shortLabel: 'Disease Detail',
        title: 'Describe the pre-existing disease and diagnosis timeline.',
        helper: 'Examples: diabetes for 4 years, hypertension since 2022.',
      ),
    );
  }

  steps.add(
    const _QuestionStep.yesNo(
      id: 'currentMedication',
      section: 'Applicant Health',
      shortLabel: 'Medication',
      title: 'Is the customer on regular medication?',
      helper: 'If yes, mention the medicine or treatment category next.',
    ),
  );

  if (hasMedication) {
    steps.add(
      const _QuestionStep.text(
        id: 'medicationDetails',
        section: 'Applicant Health',
        shortLabel: 'Medication Detail',
        title: 'What medication or treatment is currently ongoing?',
        helper: 'Examples: insulin, BP tablets, thyroid medication.',
      ),
    );
  }

  steps.add(
    const _QuestionStep.yesNo(
      id: 'hospitalisedLastFiveYears',
      section: 'Applicant Health',
      shortLabel: 'Hospitalisation',
      title: 'Has the customer been hospitalised in the last 5 years?',
      helper: 'Surgeries, admissions, and major procedures matter here.',
    ),
  );

  if (hasHospitalisation) {
    steps.add(
      const _QuestionStep.text(
        id: 'hospitalisationDetails',
        section: 'Applicant Health',
        shortLabel: 'Hospital Detail',
        title: 'Describe the hospitalisation or surgery history.',
        helper: 'Include year and reason when possible.',
      ),
    );
  }

  steps.addAll(const [
    _QuestionStep.choice(
      id: 'smoker',
      section: 'Lifestyle',
      shortLabel: 'Smoking',
      title: 'What is the customer tobacco status?',
      helper: 'This changes pricing and insurer eligibility.',
      options: ['No', 'Yes', 'Past Smoker'],
    ),
    _QuestionStep.choice(
      id: 'alcoholFrequency',
      section: 'Lifestyle',
      shortLabel: 'Alcohol',
      title: 'How often does the customer consume alcohol?',
      helper: 'Choose the closest option.',
      options: ['Never', 'Occasional', 'Regular'],
    ),
  ]);

  if (smoker == 'Yes' || smoker == 'Past Smoker') {
    steps.add(
      const _QuestionStep.text(
        id: 'smokerDetails',
        section: 'Lifestyle',
        shortLabel: 'Smoking Detail',
        title: 'Add smoking details.',
        helper: 'Mention frequency, quantity, or quit period.',
      ),
    );
  }

  steps.addAll(const [
    _QuestionStep.choice(
      id: 'occupationRisk',
      section: 'Occupation',
      shortLabel: 'Occupation',
      title: 'What is the occupation risk level?',
      helper: 'Field work and hazardous jobs may need different insurers.',
      options: [
        'Office / Low Risk',
        'Field / Medium Risk',
        'High Risk',
        'Retired',
      ],
    ),
    _QuestionStep.yesNo(
      id: 'hazardousActivities',
      section: 'Occupation',
      shortLabel: 'Activities',
      title: 'Does the customer do any hazardous activity or sport?',
      helper: 'Examples: mining, racing, trekking, diving, flying.',
    ),
  ]);

  if (hazardousActivities) {
    steps.add(
      const _QuestionStep.text(
        id: 'hazardousActivitiesDetails',
        section: 'Occupation',
        shortLabel: 'Activity Detail',
        title: 'Describe the hazardous activity or sport.',
        helper: 'Include frequency if it matters for underwriting.',
      ),
    );
  }

  steps.addAll(const [
    _QuestionStep.choice(
      id: 'coveragePriority',
      section: 'Recommendation Intent',
      shortLabel: 'Priority',
      title: 'What is the customer priority for the recommendation?',
      helper: 'This helps us guide the policy comparison.',
      options: [
        'Lowest Premium',
        'Highest Coverage',
        'Family Protection',
        'Critical Illness Focus',
        'Parents Cover',
      ],
    ),
    _QuestionStep.text(
      id: 'advisorNotes',
      section: 'Recommendation Intent',
      shortLabel: 'Notes',
      title: 'Any advisor notes before final policy recommendation?',
      helper: 'Summarise concerns, preferences, or exclusions to remember.',
      required: false,
    ),
  ]);

  return steps;
}

class _QuestionStep {
  final String id;
  final String section;
  final String shortLabel;
  final String title;
  final String helper;
  final _QuestionType type;
  final List<String> options;
  final bool required;

  const _QuestionStep._({
    required this.id,
    required this.section,
    required this.shortLabel,
    required this.title,
    required this.helper,
    required this.type,
    this.options = const [],
    this.required = true,
  });

  const _QuestionStep.choice({
    required String id,
    required String section,
    required String shortLabel,
    required String title,
    required String helper,
    required List<String> options,
    bool required = true,
  }) : this._(
         id: id,
         section: section,
         shortLabel: shortLabel,
         title: title,
         helper: helper,
         type: _QuestionType.choice,
         options: options,
         required: required,
       );

  const _QuestionStep.yesNo({
    required String id,
    required String section,
    required String shortLabel,
    required String title,
    required String helper,
    bool required = true,
  }) : this._(
         id: id,
         section: section,
         shortLabel: shortLabel,
         title: title,
         helper: helper,
         type: _QuestionType.yesNo,
         options: const ['Yes', 'No'],
         required: required,
       );

  const _QuestionStep.number({
    required String id,
    required String section,
    required String shortLabel,
    required String title,
    required String helper,
    bool required = true,
  }) : this._(
         id: id,
         section: section,
         shortLabel: shortLabel,
         title: title,
         helper: helper,
         type: _QuestionType.number,
         required: required,
       );

  const _QuestionStep.text({
    required String id,
    required String section,
    required String shortLabel,
    required String title,
    required String helper,
    bool required = true,
  }) : this._(
         id: id,
         section: section,
         shortLabel: shortLabel,
         title: title,
         helper: helper,
         type: _QuestionType.text,
         required: required,
       );
}

enum _QuestionType { choice, yesNo, number, text }

class _AnswerField extends StatefulWidget {
  final _QuestionStep step;
  final dynamic value;
  final ValueChanged<dynamic> onChanged;

  const _AnswerField({
    required this.step,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_AnswerField> createState() => _AnswerFieldState();
}

class _AnswerFieldState extends State<_AnswerField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value?.toString() ?? '');
  }

  @override
  void didUpdateWidget(covariant _AnswerField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextText = widget.value?.toString() ?? '';
    if (_controller.text != nextText &&
            widget.step.type == _QuestionType.number ||
        widget.step.type == _QuestionType.text) {
      _controller.text = nextText;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.step.type) {
      case _QuestionType.choice:
      case _QuestionType.yesNo:
        final current = widget.value?.toString();
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: widget.step.options.map((option) {
            final selected = current == option;
            return InkWell(
              onTap: () => widget.onChanged(option),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 220,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: selected
                      ? _CustomerBackgroundTabState._accent.withValues(
                          alpha: 0.08,
                        )
                      : _CustomerBackgroundTabState._surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected
                        ? _CustomerBackgroundTabState._accent
                        : _CustomerBackgroundTabState._border,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      selected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                      color: selected
                          ? _CustomerBackgroundTabState._accent
                          : _CustomerBackgroundTabState._textMuted,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        option,
                        style: TextStyle(
                          color: selected
                              ? _CustomerBackgroundTabState._accent
                              : _CustomerBackgroundTabState._textMain,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      case _QuestionType.number:
        return TextField(
          controller: _controller,
          keyboardType: TextInputType.number,
          onChanged: widget.onChanged,
          decoration: _inputDecoration('Enter a number'),
        );
      case _QuestionType.text:
        return TextField(
          controller: _controller,
          keyboardType: TextInputType.multiline,
          maxLines: 4,
          onChanged: widget.onChanged,
          decoration: _inputDecoration('Type the answer'),
        );
    }
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: _CustomerBackgroundTabState._textMuted,
        fontSize: 13,
      ),
      filled: true,
      fillColor: _CustomerBackgroundTabState._bg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
          color: _CustomerBackgroundTabState._border,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
          color: _CustomerBackgroundTabState._border,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
          color: _CustomerBackgroundTabState._accent,
          width: 1.4,
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;

  const _MetricTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _CustomerBackgroundTabState._bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _CustomerBackgroundTabState._border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: _CustomerBackgroundTabState._textMain,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: _CustomerBackgroundTabState._textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RiskBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _RiskBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label Risk',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SmallChip extends StatelessWidget {
  final String label;
  final Color color;

  const _SmallChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.manage_search_rounded,
            color: _CustomerBackgroundTabState._primary,
            size: 34,
          ),
          SizedBox(height: 10),
          Text(
            'No customers found for this filter',
            style: TextStyle(
              color: _CustomerBackgroundTabState._textMain,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Add customers or adjust the filter to continue.',
            style: TextStyle(
              color: _CustomerBackgroundTabState._textMuted,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectPrompt extends StatelessWidget {
  const _SelectPrompt();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _CustomerBackgroundTabState._surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _CustomerBackgroundTabState._border),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.assignment_ind_outlined,
              size: 42,
              color: _CustomerBackgroundTabState._primary,
            ),
            SizedBox(height: 12),
            Text(
              'Select a customer to begin',
              style: TextStyle(
                color: _CustomerBackgroundTabState._textMain,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'The questionnaire will guide the next question from the previous answer.',
              style: TextStyle(
                color: _CustomerBackgroundTabState._textMuted,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
