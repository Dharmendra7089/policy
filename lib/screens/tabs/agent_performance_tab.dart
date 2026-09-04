import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AgentPerformanceTab extends StatefulWidget {
  final Map<String, dynamic> adminData;
  const AgentPerformanceTab({super.key, required this.adminData});

  @override
  State<AgentPerformanceTab> createState() => _AgentPerformanceTabState();
}

class _AgentPerformanceTabState extends State<AgentPerformanceTab> {
  static const _primary = Color(0xFF0D2D4F);
  static const _accent = Color(0xFF1A6EBD);
  static const _bg = Color(0xFFF4F6F9);
  static const _surface = Color(0xFFFFFFFF);
  static const _textMain = Color(0xFF0D1B2A);
  static const _textMuted = Color(0xFF8A94A6);
  static const _border = Color(0xFFE4E7EC);
  static const _green = Color(0xFF16A34A);

  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  String get _viewerRole =>
      (widget.adminData['role'] ?? 'admin').toString().toLowerCase();

  String get _viewerId =>
      (widget.adminData['_profileDocId'] ?? widget.adminData['uid'] ?? '')
          .toString()
          .trim();

  String get _viewerUid => (widget.adminData['uid'] ?? '').toString().trim();

  String get _viewerEmail =>
      (widget.adminData['email'] ?? '').toString().trim().toLowerCase();

  bool get _canSetTargets =>
      const {'admin', 'super_admin'}.contains(_viewerRole);

  String get _pageTitle => switch (_viewerRole) {
    'team_leader' => 'My Team Performance',
    'manager' => 'Team Leader Performance',
    _ => 'Employee Performance',
  };

  String get _pageSubtitle => switch (_viewerRole) {
    'team_leader' => 'Monthly leads, sales and premium for your executives.',
    'manager' => 'Team Leader totals with the performance of their executives.',
    _ => 'Complete organization performance across every employee and team.',
  };

  String get _tableTitle => switch (_viewerRole) {
    'team_leader' => 'Executives in my team',
    'manager' => 'Team Leaders and their executives',
    _ => 'All teams and employees',
  };

  String _roleOf(Map<String, dynamic> data) =>
      (data['role'] ?? 'agent').toString().trim().toLowerCase();

  bool _matchesViewer(dynamic value) {
    final candidate = (value ?? '').toString().trim();
    if (candidate.isEmpty) return false;
    return candidate == _viewerId ||
        candidate == _viewerUid ||
        candidate.toLowerCase() == _viewerEmail;
  }

  bool _executiveBelongsTo(
    Map<String, dynamic> executive,
    QueryDocumentSnapshot<Map<String, dynamic>> leader,
  ) {
    final leaderData = leader.data();
    final identifiers = <String>{
      leader.id,
      (leaderData['uid'] ?? '').toString(),
      (leaderData['email'] ?? '').toString().toLowerCase(),
    }..removeWhere((value) => value.isEmpty);
    return identifiers.contains((executive['teamLeaderId'] ?? '').toString()) ||
        identifiers.contains((executive['teamLeaderUid'] ?? '').toString()) ||
        identifiers.contains(
          (executive['teamLeaderEmail'] ?? '').toString().toLowerCase(),
        );
  }

  bool _executiveBelongsToViewer(Map<String, dynamic> executive) {
    return _matchesViewer(executive['teamLeaderId']) ||
        _matchesViewer(executive['teamLeaderUid']) ||
        _matchesViewer(executive['teamLeaderEmail']);
  }

  bool _leaderBelongsToManager(Map<String, dynamic> leader) {
    return _matchesViewer(leader['managerId']) ||
        _matchesViewer(leader['managerUid']) ||
        _matchesViewer(leader['managerEmail']);
  }

  String _monthKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';

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

  DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse((value ?? '').toString());
  }

  DateTime? _policyGivenDate(Map<String, dynamic> data) {
    return _date(data['policyGivenDate']) ??
        _date(data['givenDate']) ??
        _date(data['issueDate']) ??
        _date(data['issueDateFormatted']) ??
        _date(data['policyStartDate']) ??
        _date(data['policyStartDateFormatted']) ??
        _date(data['createdAt']);
  }

  double _num(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse((value ?? '').toString().replaceAll(',', '')) ?? 0;
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

  bool _linkedToEmployee(
    Map<String, dynamic> data,
    String employeeId,
    String employeeName,
  ) {
    for (final key in [
      'agentId',
      'assignedAgentId',
      'employeeId',
      'createdByAgentId',
      'createdBy',
    ]) {
      if ((data[key] ?? '').toString().trim() == employeeId) return true;
    }

    final name = employeeName.trim().toLowerCase();
    if (name.isEmpty) return false;
    for (final key in [
      'agentName',
      'assignedAgentName',
      'employeeName',
      'employee',
      'createdByAgentName',
    ]) {
      if ((data[key] ?? '').toString().trim().toLowerCase() == name) {
        return true;
      }
    }
    return false;
  }

  bool _policyForEmployee(
    Map<String, dynamic> policy,
    Map<String, dynamic>? customer,
    String employeeId,
    String employeeName,
  ) {
    return _linkedToEmployee(policy, employeeId, employeeName) ||
        (customer != null &&
            _linkedToEmployee(customer, employeeId, employeeName));
  }

  bool _inMonth(Map<String, dynamic> data) {
    final date = _policyGivenDate(data);
    return date != null &&
        date.year == _month.year &&
        date.month == _month.month;
  }

  bool _leadForEmployee(
    Map<String, dynamic> lead,
    QueryDocumentSnapshot<Map<String, dynamic>> employee,
  ) {
    final data = employee.data();
    final role = _roleOf(data);
    final ids = <String>{
      employee.id,
      (data['uid'] ?? '').toString(),
      (data['email'] ?? '').toString().toLowerCase(),
    }..removeWhere((value) => value.isEmpty);
    final keys = switch (role) {
      'executive' => const [
        'executiveAssignedToId',
        'executiveAssignedToUid',
        'executiveAssignedToEmail',
      ],
      'team_leader' => const [
        'teamLeaderAssignedToId',
        'teamLeaderAssignedToUid',
        'teamLeaderAssignedToEmail',
      ],
      'telecaller' => const [
        'assignedToId',
        'assignedToUid',
        'assignedToEmail',
      ],
      _ => const <String>[],
    };
    return keys.any((key) {
      final value = (lead[key] ?? '').toString().trim();
      return ids.contains(
        key.toLowerCase().contains('email') ? value.toLowerCase() : value,
      );
    });
  }

  bool _leadInMonth(Map<String, dynamic> lead, Map<String, dynamic> employee) {
    final role = _roleOf(employee);
    final date =
        switch (role) {
          'executive' => _date(lead['executiveAssignedAt']),
          'team_leader' => _date(lead['teamLeaderAssignedAt']),
          'telecaller' => _date(lead['assignedAt']),
          _ => null,
        } ??
        _date(lead['createdAt']);
    return date != null &&
        date.year == _month.year &&
        date.month == _month.month;
  }

  double _premium(Map<String, dynamic> data) =>
      _num(data['premiumAmount'] ?? data['premium']);

  double _commission(Map<String, dynamic> data) =>
      _num(data['commissionAmount'] ?? data['commission']);

  double _targetFor(
    String employeeId,
    String employeeName,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> targetDocs,
  ) {
    final name = employeeName.trim().toLowerCase();
    for (final doc in targetDocs) {
      final data = doc.data();
      final docId = (data['employeeId'] ?? '').toString();
      final docName = (data['employeeName'] ?? '').toString().toLowerCase();
      if (docId == employeeId || (name.isNotEmpty && docName == name)) {
        return _num(data['targetPremium']);
      }
    }
    return 0;
  }

  int _callCountForEmployeeLead(
    Map<String, dynamic> lead,
    Map<String, dynamic> employee,
  ) {
    return switch (_roleOf(employee)) {
      'telecaller' => (lead['telecallerCallCount'] as num?)?.toInt() ?? 0,
      'executive' => (lead['executiveCallCount'] as num?)?.toInt() ?? 0,
      'team_leader' => (lead['teamLeaderCallCount'] as num?)?.toInt() ?? 0,
      _ => 0,
    };
  }

  Future<void> _assignTarget(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> employee,
    double existingTarget,
  ) async {
    final data = employee.data();
    final name = (data['name'] ?? data['username'] ?? 'Employee').toString();
    final controller = TextEditingController(
      text: existingTarget <= 0 ? '' : existingTarget.toStringAsFixed(0),
    );
    final messenger = ScaffoldMessenger.of(context);

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        var saving = false;
        return StatefulBuilder(
          builder: (ctx, setS) => AlertDialog(
            title: Text('Set Target - $name'),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _monthLabel(_month),
                    style: const TextStyle(
                      color: _textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Monthly premium target',
                      prefixText: 'Rs ',
                      border: OutlineInputBorder(),
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
              ElevatedButton.icon(
                onPressed: saving
                    ? null
                    : () async {
                        final target = _num(controller.text);
                        setS(() => saving = true);
                        final docId = '${employee.id}_${_monthKey(_month)}';
                        await FirebaseFirestore.instance
                            .collection('employee_targets')
                            .doc(docId)
                            .set({
                              'employeeId': employee.id,
                              'employeeName': name,
                              'employeeRole': (data['role'] ?? 'agent')
                                  .toString(),
                              'monthKey': _monthKey(_month),
                              'monthStart': Timestamp.fromDate(_month),
                              'targetPremium': target,
                              'updatedAt': FieldValue.serverTimestamp(),
                              'updatedBy': widget.adminData['email'] ?? '',
                            }, SetOptions(merge: true));
                        if (ctx.mounted) Navigator.pop(ctx);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Target saved for $name'),
                            backgroundColor: _accent,
                          ),
                        );
                      },
                icon: const Icon(Icons.save_rounded, size: 16),
                label: Text(saving ? 'Saving...' : 'Save Target'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _visibleEmployees(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> allEmployees,
  ) {
    if (_viewerRole == 'team_leader') {
      return allEmployees
          .where(
            (employee) =>
                _roleOf(employee.data()) == 'executive' &&
                _executiveBelongsToViewer(employee.data()),
          )
          .toList();
    }
    if (_viewerRole == 'manager') {
      final leaders = allEmployees
          .where((employee) => _roleOf(employee.data()) == 'team_leader')
          .toList();
      final hasManagerAssignments = leaders.any((leader) {
        final data = leader.data();
        return [
          data['managerId'],
          data['managerUid'],
          data['managerEmail'],
        ].any((value) => (value ?? '').toString().trim().isNotEmpty);
      });
      final visibleLeaders = hasManagerAssignments
          ? leaders.where((leader) => _leaderBelongsToManager(leader.data()))
          : leaders;
      final leaderIds = visibleLeaders.map((leader) => leader.id).toSet();
      return allEmployees.where((employee) {
        final data = employee.data();
        final role = _roleOf(data);
        if (role == 'team_leader') return leaderIds.contains(employee.id);
        return role == 'executive' &&
            visibleLeaders.any((leader) => _executiveBelongsTo(data, leader));
      }).toList();
    }
    return allEmployees;
  }

  List<_EmployeeSalesRow> _buildEmployeeRows({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> employees,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> policies,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> leads,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> targets,
    required Map<String, Map<String, dynamic>> customersById,
  }) {
    return employees.map((employee) {
      final data = employee.data();
      final name = (data['name'] ?? data['username'] ?? '').toString();
      final employeePolicies = policies.where((policy) {
        final policyData = policy.data();
        final customerId = (policyData['customerId'] ?? '').toString();
        return _policyForEmployee(
          policyData,
          customersById[customerId],
          employee.id,
          name,
        );
      }).toList();
      final monthlyPolicies = employeePolicies
          .where((policy) => _inMonth(policy.data()))
          .toList();
      final employeeLeads = leads
          .where((lead) => _leadForEmployee(lead.data(), employee))
          .toList();
      final monthlyLeads = employeeLeads
          .where((lead) => _leadInMonth(lead.data(), data))
          .length;
      final lifetimeCalls = employeeLeads.fold<int>(
        0,
        (total, lead) => total + _callCountForEmployeeLead(lead.data(), data),
      );
      return _EmployeeSalesRow(
        doc: employee,
        name: name,
        role: _roleOf(data),
        teamLeaderId: (data['teamLeaderId'] ?? '').toString(),
        teamLeaderName: (data['teamLeaderName'] ?? '').toString(),
        allLeads: employeeLeads.length,
        monthlyLeads: monthlyLeads,
        lifetimeCalls: lifetimeCalls,
        allSales: employeePolicies.length,
        monthlySales: monthlyPolicies.length,
        totalPremium: employeePolicies.fold<double>(
          0,
          (total, policy) => total + _premium(policy.data()),
        ),
        monthlyPremium: monthlyPolicies.fold<double>(
          0,
          (total, policy) => total + _premium(policy.data()),
        ),
        monthlyCommission: monthlyPolicies.fold<double>(
          0,
          (total, policy) => total + _commission(policy.data()),
        ),
        targetPremium: _targetFor(employee.id, name, targets),
        monthlyPolicies: monthlyPolicies,
      );
    }).toList();
  }

  List<_EmployeeSalesRow> _groupedRows(
    List<_EmployeeSalesRow> rows,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> visibleEmployees,
  ) {
    if (_viewerRole == 'team_leader') {
      return rows..sort((a, b) => b.monthlyPremium.compareTo(a.monthlyPremium));
    }

    final leaders =
        visibleEmployees
            .where((employee) => _roleOf(employee.data()) == 'team_leader')
            .toList()
          ..sort(
            (a, b) => (a.data()['name'] ?? '').toString().compareTo(
              (b.data()['name'] ?? '').toString(),
            ),
          );
    final grouped = <_EmployeeSalesRow>[];
    final coveredIds = <String>{};
    for (final leader in leaders) {
      final executiveRows = rows.where((row) {
        return row.role == 'executive' &&
            _executiveBelongsTo(row.doc.data(), leader);
      }).toList()..sort((a, b) => b.monthlyPremium.compareTo(a.monthlyPremium));
      final leaderName = (leader.data()['name'] ?? 'Team Leader').toString();
      grouped.add(
        _EmployeeSalesRow.teamSummary(
          doc: leader,
          name: leaderName,
          executives: executiveRows,
        ),
      );
      grouped.addAll(executiveRows);
      coveredIds.add(leader.id);
      coveredIds.addAll(executiveRows.map((row) => row.doc.id));
    }

    if (_viewerRole == 'admin' || _viewerRole == 'super_admin') {
      final remaining =
          rows.where((row) => !coveredIds.contains(row.doc.id)).toList()
            ..sort((a, b) => b.monthlyPremium.compareTo(a.monthlyPremium));
      grouped.addAll(remaining);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('agents').snapshots(),
      builder: (context, employeeSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('customers')
              .snapshots(),
          builder: (context, customerSnap) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('customer_policies')
                  .snapshots(),
              builder: (context, policySnap) {
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('telecaller_leads')
                      .snapshots(),
                  builder: (context, leadSnap) {
                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('employee_targets')
                          .where('monthKey', isEqualTo: _monthKey(_month))
                          .snapshots(),
                      builder: (context, targetSnap) {
                        final allEmployees = (employeeSnap.data?.docs ?? [])
                            .where(
                              (employee) =>
                                  _roleOf(employee.data()) !=
                                  'customer_service',
                            )
                            .toList();
                        final visibleEmployees = _visibleEmployees(
                          allEmployees,
                        );
                        final customersById = <String, Map<String, dynamic>>{
                          for (final doc in customerSnap.data?.docs ?? [])
                            doc.id: doc.data(),
                        };
                        final metricRows = _buildEmployeeRows(
                          employees: visibleEmployees,
                          policies: policySnap.data?.docs ?? [],
                          leads: leadSnap.data?.docs ?? [],
                          targets: targetSnap.data?.docs ?? [],
                          customersById: customersById,
                        );
                        final displayRows = _groupedRows([
                          ...metricRows,
                        ], visibleEmployees);
                        final totalMonthlyPremium = metricRows.fold<double>(
                          0,
                          (total, row) => total + row.monthlyPremium,
                        );
                        return Scaffold(
                          backgroundColor: _bg,
                          body: SafeArea(
                            child: Column(
                              children: [
                                _header(),
                                const Divider(height: 1, color: _border),
                                Expanded(
                                  child: ListView(
                                    padding: const EdgeInsets.all(16),
                                    children: [
                                      Wrap(
                                        spacing: 12,
                                        runSpacing: 12,
                                        children: [
                                          _MetricTile(
                                            'Total Business',
                                            _currency(totalMonthlyPremium),
                                            Icons.currency_rupee_rounded,
                                            _green,
                                          ),
                                          _MetricTile(
                                            'Earned Commission',
                                            _currency(
                                              metricRows.fold<double>(
                                                0,
                                                (total, row) =>
                                                    total +
                                                    row.monthlyCommission,
                                              ),
                                            ),
                                            Icons
                                                .account_balance_wallet_outlined,
                                            _accent,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),
                                      _EmployeeSalesTable(
                                        title: _tableTitle,
                                        rows: displayRows,
                                        currency: _currency,
                                        canSetTargets: _canSetTargets,
                                        onSetTarget: (row) => _assignTarget(
                                          context,
                                          row.doc,
                                          row.targetPremium,
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
              },
            );
          },
        );
      },
    );
  }

  Widget _header() {
    return Container(
      color: _surface,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _pageTitle,
                  style: const TextStyle(
                    color: _textMain,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _pageSubtitle,
                  style: const TextStyle(color: _textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Previous month',
            onPressed: () => setState(
              () => _month = DateTime(_month.year, _month.month - 1),
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
              () => _month = DateTime(_month.year, _month.month + 1),
            ),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

class _EmployeeSalesRow {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final String name;
  final String role;
  final String teamLeaderId;
  final String teamLeaderName;
  final int allLeads;
  final int monthlyLeads;
  final int lifetimeCalls;
  final int allSales;
  final int monthlySales;
  final double totalPremium;
  final double monthlyPremium;
  final double monthlyCommission;
  final double targetPremium;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> monthlyPolicies;
  final bool isTeamSummary;

  const _EmployeeSalesRow({
    required this.doc,
    required this.name,
    required this.role,
    required this.teamLeaderId,
    required this.teamLeaderName,
    required this.allLeads,
    required this.monthlyLeads,
    required this.lifetimeCalls,
    required this.allSales,
    required this.monthlySales,
    required this.totalPremium,
    required this.monthlyPremium,
    required this.monthlyCommission,
    required this.targetPremium,
    required this.monthlyPolicies,
    this.isTeamSummary = false,
  });

  factory _EmployeeSalesRow.teamSummary({
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
    required String name,
    required List<_EmployeeSalesRow> executives,
  }) {
    return _EmployeeSalesRow(
      doc: doc,
      name: name,
      role: 'team_leader',
      teamLeaderId: doc.id,
      teamLeaderName: name,
      allLeads: executives.fold(0, (total, row) => total + row.allLeads),
      monthlyLeads: executives.fold(
        0,
        (total, row) => total + row.monthlyLeads,
      ),
      lifetimeCalls: executives.fold(
        0,
        (total, row) => total + row.lifetimeCalls,
      ),
      allSales: executives.fold(0, (total, row) => total + row.allSales),
      monthlySales: executives.fold(
        0,
        (total, row) => total + row.monthlySales,
      ),
      totalPremium: executives.fold(
        0,
        (total, row) => total + row.totalPremium,
      ),
      monthlyPremium: executives.fold(
        0,
        (total, row) => total + row.monthlyPremium,
      ),
      monthlyCommission: executives.fold(
        0,
        (total, row) => total + row.monthlyCommission,
      ),
      targetPremium: executives.fold(
        0,
        (total, row) => total + row.targetPremium,
      ),
      monthlyPolicies: executives.expand((row) => row.monthlyPolicies).toList(),
      isTeamSummary: true,
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  const _MetricTile(this.title, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 230,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _AgentPerformanceTabState._surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _AgentPerformanceTabState._border),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _AgentPerformanceTabState._textMain,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    color: _AgentPerformanceTabState._textMuted,
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

class _EmployeeSalesTable extends StatelessWidget {
  final String title;
  final List<_EmployeeSalesRow> rows;
  final String Function(double value) currency;
  final bool canSetTargets;
  final void Function(_EmployeeSalesRow row) onSetTarget;
  const _EmployeeSalesTable({
    required this.title,
    required this.rows,
    required this.currency,
    required this.canSetTargets,
    required this.onSetTarget,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _AgentPerformanceTabState._surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _AgentPerformanceTabState._border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: const TextStyle(
                color: _AgentPerformanceTabState._textMain,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const Divider(height: 1, color: _AgentPerformanceTabState._border),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No employees found.',
                style: TextStyle(color: _AgentPerformanceTabState._textMuted),
              ),
            )
          else
            ...rows.map((row) {
              final progress = row.targetPremium <= 0
                  ? 0.0
                  : (row.monthlyPremium / row.targetPremium).clamp(0.0, 1.0);
              return ExpansionTile(
                tilePadding: EdgeInsets.only(
                  left: row.isTeamSummary ? 16 : 34,
                  right: 16,
                ),
                leading: Icon(
                  row.isTeamSummary
                      ? Icons.groups_2_outlined
                      : _roleIcon(row.role),
                  color: row.isTeamSummary
                      ? _AgentPerformanceTabState._primary
                      : _AgentPerformanceTabState._accent,
                ),
                title: Row(
                  children: [
                    Flexible(
                      child: Text(
                        row.name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _AgentPerformanceTabState._textMain,
                          fontWeight: row.isTeamSummary
                              ? FontWeight.w900
                              : FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _roleBadge(row.isTeamSummary ? 'Team Total' : row.role),
                  ],
                ),
                subtitle: Text(
                  '${row.monthlyLeads} leads | ${row.monthlySales} sales this month'
                  '${row.isTeamSummary ? ' | Team lifetime sales ${row.allSales}' : ''}',
                  style: const TextStyle(
                    color: _AgentPerformanceTabState._textMuted,
                  ),
                ),
                trailing: canSetTargets && !row.isTeamSummary
                    ? ElevatedButton.icon(
                        onPressed: () => onSetTarget(row),
                        icon: const Icon(Icons.track_changes_rounded, size: 15),
                        label: const Text('Target'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _AgentPerformanceTabState._primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                        ),
                      )
                    : const Icon(
                        Icons.expand_more_rounded,
                        color: _AgentPerformanceTabState._textMuted,
                      ),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _mini('All Leads', '${row.allLeads}'),
                      _mini('Monthly Leads', '${row.monthlyLeads}'),
                      _mini('Lifetime Calls', '${row.lifetimeCalls}'),
                      _mini('Total Premium', currency(row.totalPremium)),
                      _mini('Monthly Premium', currency(row.monthlyPremium)),
                      _mini(
                        'Monthly Target',
                        row.targetPremium <= 0
                            ? 'Not set'
                            : currency(row.targetPremium),
                      ),
                      _mini('Commission', currency(row.monthlyCommission)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    color: progress >= 0.8
                        ? _AgentPerformanceTabState._green
                        : _AgentPerformanceTabState._accent,
                    backgroundColor: _AgentPerformanceTabState._border,
                  ),
                  const SizedBox(height: 12),
                  if (row.monthlyPolicies.isEmpty)
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'No monthly sales details for this employee.',
                        style: TextStyle(
                          color: _AgentPerformanceTabState._textMuted,
                        ),
                      ),
                    )
                  else
                    ...row.monthlyPolicies.map((policy) {
                      final data = policy.data();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                (data['customerName'] ?? '-').toString(),
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _AgentPerformanceTabState._textMain,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 120,
                              child: Text(
                                (data['category'] ?? '-').toString(),
                                style: const TextStyle(
                                  color: _AgentPerformanceTabState._textMuted,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 140,
                              child: Text(
                                (data['policyNumber'] ?? '-').toString(),
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _AgentPerformanceTabState._textMuted,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 120,
                              child: Text(
                                currency(
                                  _numStatic(
                                    data['premiumAmount'] ?? data['premium'],
                                  ),
                                ),
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  color: _AgentPerformanceTabState._textMain,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              );
            }),
        ],
      ),
    );
  }

  static double _numStatic(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse((value ?? '').toString().replaceAll(',', '')) ?? 0;
  }

  static IconData _roleIcon(String role) => switch (role) {
    'team_leader' => Icons.groups_2_outlined,
    'executive' => Icons.badge_outlined,
    'telecaller' => Icons.headset_mic_outlined,
    'manager' => Icons.manage_accounts_outlined,
    _ => Icons.person_outline,
  };

  static Widget _roleBadge(String role) {
    final label = switch (role) {
      'team_leader' => 'Team Leader',
      'executive' => 'Executive',
      'telecaller' => 'Telecaller',
      'manager' => 'Manager',
      _ => role,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: _AgentPerformanceTabState._accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: _AgentPerformanceTabState._accent,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _mini(String label, String value) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _AgentPerformanceTabState._bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _AgentPerformanceTabState._border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _AgentPerformanceTabState._textMain,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: _AgentPerformanceTabState._textMuted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
