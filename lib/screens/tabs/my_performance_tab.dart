import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class MyPerformanceTab extends StatefulWidget {
  final Map<String, dynamic> userData;
  const MyPerformanceTab({super.key, required this.userData});

  @override
  State<MyPerformanceTab> createState() => _MyPerformanceTabState();
}

class _MyPerformanceTabState extends State<MyPerformanceTab> {
  static const _primary = Color(0xFF0D2D4F);
  static const _accent = Color(0xFF1A6EBD);
  static const _bg = Color(0xFFF4F6F9);
  static const _surface = Color(0xFFFFFFFF);
  static const _border = Color(0xFFE4E7EC);
  static const _textMain = Color(0xFF0D1B2A);
  static const _textMuted = Color(0xFF8A94A6);
  static const _green = Color(0xFF16A34A);

  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  String _category = 'All';
  String? _selectedEmployeeId;
  String? _selectedEmployeeName;
  bool _generatingReport = false;

  String get _employeeId =>
      (widget.userData['_profileDocId'] ?? widget.userData['uid'] ?? '')
          .toString();

  String get _employeeName =>
      (widget.userData['name'] ??
              widget.userData['username'] ??
              widget.userData['email'] ??
              'Employee')
          .toString();

  bool get _isAdmin =>
      (widget.userData['role'] ?? '').toString().toLowerCase() == 'admin';

  bool _matchesSelectedEmployee(Map<String, dynamic> data) {
    final selectedId = (_selectedEmployeeId ?? '').trim();
    final selectedName = (_selectedEmployeeName ?? '').trim().toLowerCase();
    if (selectedId.isEmpty && selectedName.isEmpty) return true;
    final employeeId = (data['employeeId'] ?? data['createdBy'] ?? '')
        .toString()
        .trim();
    final employeeName = (data['employeeName'] ?? data['employee'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    return (selectedId.isNotEmpty && employeeId == selectedId) ||
        (selectedName.isNotEmpty && employeeName == selectedName);
  }

  bool _ownedByUser(Map<String, dynamic> data) {
    if (_isAdmin) return _matchesSelectedEmployee(data);
    final id = _employeeId;
    final name = _employeeName.trim().toLowerCase();
    final employeeId = (data['employeeId'] ?? '').toString().trim();
    final createdBy = (data['createdBy'] ?? '').toString().trim();
    final employeeName = (data['employeeName'] ?? data['employee'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    return (id.isNotEmpty && (employeeId == id || createdBy == id)) ||
        (name.isNotEmpty && employeeName == name);
  }

  DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse((value ?? '').toString());
  }

  double _num(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse((value ?? '').toString().replaceAll(',', '')) ?? 0;
  }

  bool _inMonth(Map<String, dynamic> data) {
    final date =
        _date(data['createdAt']) ??
        _date(data['issueDate']) ??
        _date(data['policyStartDate']);
    if (date == null) return false;
    return date.year == _month.year && date.month == _month.month;
  }

  bool _matchesCategory(Map<String, dynamic> data) {
    if (_category == 'All') return true;
    return (data['category'] ?? data['customerCategory'] ?? '')
            .toString()
            .toLowerCase() ==
        _category.toLowerCase();
  }

  String _monthLabel(DateTime month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[month.month - 1]} ${month.year}';
  }

  String _monthKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';

  Stream<QuerySnapshot<Map<String, dynamic>>> _targetStream() {
    return FirebaseFirestore.instance
        .collection('employee_targets')
        .where('monthKey', isEqualTo: _monthKey(_month))
        .snapshots();
  }

  bool _targetBelongsToUser(Map<String, dynamic> data) {
    if (_isAdmin) return _matchesSelectedEmployee(data);
    final id = _employeeId;
    final name = _employeeName.trim().toLowerCase();
    final employeeId = (data['employeeId'] ?? '').toString().trim();
    final employeeName = (data['employeeName'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    return (id.isNotEmpty && employeeId == id) ||
        (name.isNotEmpty && employeeName == name);
  }

  String _currency(double value) {
    if (value >= 10000000) {
      return 'Rs ${(value / 10000000).toStringAsFixed(2)} Cr';
    }
    if (value >= 100000) {
      return 'Rs ${(value / 100000).toStringAsFixed(2)} L';
    }
    return 'Rs ${value.toStringAsFixed(0)}';
  }

  Future<void> _generatePerformanceReport({
    required int customersCount,
    required int policiesCount,
    required int healthCustomers,
    required int lifeCustomers,
    required int generalCustomers,
    required double premium,
    required double targetPremium,
    required double targetProgress,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> policies,
  }) async {
    if (!_isAdmin || _generatingReport) return;
    setState(() => _generatingReport = true);
    try {
      final creatorName =
          (widget.userData['name'] ??
                  widget.userData['username'] ??
                  widget.userData['email'] ??
                  'Admin')
              .toString();
      final creatorId =
          (widget.userData['_profileDocId'] ?? widget.userData['uid'] ?? '')
              .toString();
      final audienceName = (_selectedEmployeeName ?? '').trim().isEmpty
          ? 'All employees'
          : _selectedEmployeeName!.trim();
      final monthLabel = _monthLabel(_month);
      final title = 'Performance Report - $audienceName - $monthLabel';
      final rows = policies.map((doc) {
        final data = doc.data();
        return {
          'customerName': (data['customerName'] ?? '').toString(),
          'policyName': (data['policyName'] ?? '').toString(),
          'policyNumber': (data['policyNumber'] ?? '').toString(),
          'category': (data['category'] ?? '').toString(),
          'companyName': (data['companyName'] ?? '').toString(),
          'premiumAmount': _num(data['premiumAmount'] ?? data['premium']),
          'commissionAmount': _num(
            data['commissionAmount'] ?? data['commission'],
          ),
          'employeeName': (data['employeeName'] ?? data['employee'] ?? '')
              .toString(),
        };
      }).toList();

      await FirebaseFirestore.instance.collection('reports').add({
        'title': title,
        'type': 'Performance',
        'month': monthLabel,
        'monthKey': _monthKey(_month),
        'category': _category,
        'scope': audienceName,
        'employeeId': _selectedEmployeeId,
        'employeeName': _selectedEmployeeName,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': creatorId,
        'createdByName': creatorName,
        'createdByEmail': (widget.userData['email'] ?? '').toString(),
        'format': 'pdf',
        'payload': {
          'customersCount': customersCount,
          'policiesCount': policiesCount,
          'healthCustomers': healthCustomers,
          'lifeCustomers': lifeCustomers,
          'generalCustomers': generalCustomers,
          'premium': premium,
          'targetPremium': targetPremium,
          'targetProgress': targetProgress,
          'rows': rows,
        },
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Performance report generated in Reports'),
          backgroundColor: _green,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to generate report: $error')),
      );
    } finally {
      if (mounted) setState(() => _generatingReport = false);
    }
  }

  Widget _employeeSelector() {
    if (!_isAdmin) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('agents').snapshots(),
      builder: (context, snap) {
        final employees =
            (snap.data?.docs ?? []).where((doc) {
              final role = (doc.data()['role'] ?? 'agent').toString();
              return role != 'customer_service';
            }).toList()..sort((a, b) {
              final an = (a.data()['name'] ?? '').toString();
              final bn = (b.data()['name'] ?? '').toString();
              return an.compareTo(bn);
            });

        return SizedBox(
          width: 260,
          child: DropdownButtonFormField<String>(
            initialValue: _selectedEmployeeId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Employee',
              filled: true,
              fillColor: _surface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _border),
              ),
            ),
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('All employees'),
              ),
              ...employees.map((doc) {
                final name = (doc.data()['name'] ?? 'Employee').toString();
                return DropdownMenuItem<String>(
                  value: doc.id,
                  child: Text(name),
                );
              }),
            ],
            onChanged: (value) {
              QueryDocumentSnapshot<Map<String, dynamic>>? selected;
              for (final doc in employees) {
                if (doc.id == value) {
                  selected = doc;
                  break;
                }
              }
              setState(() {
                _selectedEmployeeId = value;
                _selectedEmployeeName = selected == null
                    ? null
                    : (selected.data()['name'] ?? '').toString();
              });
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('customers').snapshots(),
      builder: (context, customerSnap) {
        final allCustomers = (customerSnap.data?.docs ?? [])
            .where((doc) => _ownedByUser(doc.data()))
            .toList();
        final monthCustomers = allCustomers.where((doc) {
          final data = doc.data();
          return _inMonth(data) && _matchesCategory(data);
        }).toList();

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('customer_policies')
              .snapshots(),
          builder: (context, policySnap) {
            final customerIds = allCustomers.map((doc) => doc.id).toSet();
            final policies = (policySnap.data?.docs ?? []).where((doc) {
              final data = doc.data();
              final customerId = (data['customerId'] ?? '').toString();
              return customerIds.contains(customerId) &&
                  _inMonth(data) &&
                  _matchesCategory(data);
            }).toList();

            final healthCustomers = monthCustomers
                .where(
                  (doc) =>
                      (doc.data()['customerCategory'] ?? 'Health')
                          .toString()
                          .toLowerCase() ==
                      'health',
                )
                .length;
            final lifeCustomers = monthCustomers
                .where(
                  (doc) =>
                      (doc.data()['customerCategory'] ?? '')
                          .toString()
                          .toLowerCase() ==
                      'life',
                )
                .length;
            final generalCustomers = monthCustomers
                .where(
                  (doc) =>
                      (doc.data()['customerCategory'] ?? '')
                          .toString()
                          .toLowerCase() ==
                      'general',
                )
                .length;
            final premium = policies.fold<double>(
              0,
              (total, doc) =>
                  total +
                  _num(doc.data()['premiumAmount'] ?? doc.data()['premium']),
            );

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _targetStream(),
              builder: (context, targetSnap) {
                final targetPremium = (targetSnap.data?.docs ?? [])
                    .where((doc) => _targetBelongsToUser(doc.data()))
                    .fold<double>(
                      0,
                      (total, doc) => total + _num(doc.data()['targetPremium']),
                    );
                final targetProgress = targetPremium <= 0
                    ? 0.0
                    : (premium / targetPremium).clamp(0.0, 1.0);

                return Container(
                  color: _bg,
                  child: Column(
                    children: [
                      Container(
                        color: _surface,
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'My Performance',
                                    style: TextStyle(
                                      color: _textMain,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Monthly customers and linked policies.',
                                    style: TextStyle(
                                      color: _textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Previous month',
                              onPressed: () => setState(
                                () => _month = DateTime(
                                  _month.year,
                                  _month.month - 1,
                                ),
                              ),
                              icon: const Icon(Icons.chevron_left_rounded),
                            ),
                            Text(
                              _monthLabel(_month),
                              style: const TextStyle(
                                color: _textMain,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Next month',
                              onPressed: () => setState(
                                () => _month = DateTime(
                                  _month.year,
                                  _month.month + 1,
                                ),
                              ),
                              icon: const Icon(Icons.chevron_right_rounded),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: _border),
                      Container(
                        color: _surface,
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _employeeSelector(),
                            ...['All', 'Health', 'Life', 'General'].map((cat) {
                              final selected = _category == cat;
                              return ChoiceChip(
                                label: Text(cat),
                                selected: selected,
                                selectedColor: _accent.withValues(alpha: 0.12),
                                onSelected: (_) =>
                                    setState(() => _category = cat),
                              );
                            }),
                            if (_isAdmin)
                              ElevatedButton.icon(
                                onPressed: _generatingReport
                                    ? null
                                    : () => _generatePerformanceReport(
                                        customersCount: monthCustomers.length,
                                        policiesCount: policies.length,
                                        healthCustomers: healthCustomers,
                                        lifeCustomers: lifeCustomers,
                                        generalCustomers: generalCustomers,
                                        premium: premium,
                                        targetPremium: targetPremium,
                                        targetProgress: targetProgress,
                                        policies: policies,
                                      ),
                                icon: _generatingReport
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.picture_as_pdf_outlined,
                                        size: 16,
                                      ),
                                label: Text(
                                  _generatingReport
                                      ? 'Generating...'
                                      : 'Generate Report',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                _MetricCard(
                                  title: 'Customers added',
                                  value: '${monthCustomers.length}',
                                  icon: Icons.group_add_outlined,
                                  color: _primary,
                                ),
                                _MetricCard(
                                  title: 'Policies linked',
                                  value: '${policies.length}',
                                  icon: Icons.verified_outlined,
                                  color: _accent,
                                ),
                                _MetricCard(
                                  title: 'Premium',
                                  value: _currency(premium),
                                  icon: Icons.currency_rupee_rounded,
                                  color: _green,
                                ),
                                _MetricCard(
                                  title: 'Monthly target',
                                  value: targetPremium <= 0
                                      ? 'Not set'
                                      : _currency(targetPremium),
                                  icon: Icons.track_changes_rounded,
                                  color: _primary,
                                ),
                                _MetricCard(
                                  title: 'Target progress',
                                  value: targetPremium <= 0
                                      ? '-'
                                      : '${(targetProgress * 100).round()}%',
                                  icon: Icons.insights_rounded,
                                  color: targetProgress >= 0.8
                                      ? _green
                                      : _accent,
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _BreakdownCard(
                              health: healthCustomers,
                              life: lifeCustomers,
                              general: generalCustomers,
                            ),
                            const SizedBox(height: 14),
                            _PolicyListCard(policies: policies),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 230,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _MyPerformanceTabState._surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _MyPerformanceTabState._border),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
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
                    color: _MyPerformanceTabState._textMain,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    color: _MyPerformanceTabState._textMuted,
                    fontSize: 12,
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

class _BreakdownCard extends StatelessWidget {
  final int health;
  final int life;
  final int general;
  const _BreakdownCard({
    required this.health,
    required this.life,
    required this.general,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _MyPerformanceTabState._surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _MyPerformanceTabState._border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Customer category breakdown',
            style: TextStyle(
              color: _MyPerformanceTabState._textMain,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          _row('Health', health),
          _row('Life', life),
          _row('General', general),
        ],
      ),
    );
  }

  Widget _row(String label, int value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: _MyPerformanceTabState._textMuted),
            ),
          ),
          Text(
            '$value',
            style: const TextStyle(
              color: _MyPerformanceTabState._textMain,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PolicyListCard extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> policies;
  const _PolicyListCard({required this.policies});

  @override
  Widget build(BuildContext context) {
    final sorted = [...policies]
      ..sort((a, b) {
        final aDate = _date(a.data()) ?? DateTime(1900);
        final bDate = _date(b.data()) ?? DateTime(1900);
        return bDate.compareTo(aDate);
      });
    return Container(
      decoration: BoxDecoration(
        color: _MyPerformanceTabState._surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _MyPerformanceTabState._border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Linked policy details',
              style: TextStyle(
                color: _MyPerformanceTabState._textMain,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const Divider(height: 1, color: _MyPerformanceTabState._border),
          if (sorted.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No linked policies for this selection.',
                style: TextStyle(color: _MyPerformanceTabState._textMuted),
              ),
            )
          else
            ...sorted.map((doc) {
              final data = doc.data();
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        (data['customerName'] ?? data['policyName'] ?? '-')
                            .toString(),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _MyPerformanceTabState._textMain,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      child: Text(
                        (data['category'] ?? '-').toString(),
                        style: const TextStyle(
                          color: _MyPerformanceTabState._textMuted,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 130,
                      child: Text(
                        (data['policyNumber'] ?? '-').toString(),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _MyPerformanceTabState._textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  DateTime? _date(Map<String, dynamic> data) {
    final value =
        data['createdAt'] ?? data['issueDate'] ?? data['policyStartDate'];
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse((value ?? '').toString());
  }
}
