import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SalesTab extends StatefulWidget {
  final Map<String, dynamic>? userData;
  const SalesTab({super.key, this.userData});

  @override
  State<SalesTab> createState() => _SalesTabState();
}

class _SalesTabState extends State<SalesTab> {
  static const _primary = Color(0xFF0D2D4F);
  static const _accent = Color(0xFF1A6EBD);
  static const _bg = Color(0xFFF4F6F9);
  static const _surface = Color(0xFFFFFFFF);
  static const _textMain = Color(0xFF0F172A);
  static const _textMuted = Color(0xFF64748B);
  static const _border = Color(0xFFE2E8F0);
  static const _green = Color(0xFF16A34A);
  static const _amber = Color(0xFFF59E0B);
  static const _red = Color(0xFFDC2626);

  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  bool _generatingReport = false;

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

  static DateTime? _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    final raw = (value ?? '').toString().trim();
    if (raw.isEmpty) return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) return parsed;

    final dateParts = raw.split(RegExp(r'[./\-]'));
    if (dateParts.length == 3) {
      final first = int.tryParse(dateParts[0]);
      final second = int.tryParse(dateParts[1]);
      final third = int.tryParse(dateParts[2]);
      if (first != null && second != null && third != null) {
        if (dateParts[0].length == 4) return DateTime(first, second, third);
        return DateTime(third, second, first);
      }
    }
    return null;
  }

  static double _num(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse((value ?? '').toString().replaceAll(',', '')) ?? 0;
  }

  static String _currency(double value) {
    if (value >= 10000000) {
      return 'Rs ${(value / 10000000).toStringAsFixed(2)} Cr';
    }
    if (value >= 100000) {
      return 'Rs ${(value / 100000).toStringAsFixed(2)} L';
    }
    return 'Rs ${value.toStringAsFixed(0)}';
  }

  static DateTime? _policyGivenDateFrom(Map<String, dynamic> data) {
    return _toDate(data['policyGivenDate']) ??
        _toDate(data['givenDate']) ??
        _toDate(data['issueDate']) ??
        _toDate(data['issueDateFormatted']) ??
        _toDate(data['policyStartDate']) ??
        _toDate(data['policyStartDateFormatted']) ??
        _toDate(data['createdAt']);
  }

  static String _dateLabel(Map<String, dynamic> data) {
    final date = _policyGivenDateFrom(data);
    if (date == null) {
      final month = (data['month'] ?? data['monthKey'] ?? '').toString();
      return month.isEmpty ? '-' : month;
    }
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  DateTime? _customerDate(Map<String, dynamic> data) {
    return _toDate(data['createdAt']) ?? _toDate(data['updatedAt']);
  }

  DateTime? _policyGivenDate(Map<String, dynamic> data) {
    return _policyGivenDateFrom(data);
  }

  bool _isSelectedMonth(DateTime? date) {
    return date != null &&
        date.year == _month.year &&
        date.month == _month.month;
  }

  String _normalizedMonthToken(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  List<String> _selectedMonthTokens() {
    const shortMonths = [
      'jan',
      'feb',
      'mar',
      'apr',
      'may',
      'jun',
      'jul',
      'aug',
      'sep',
      'oct',
      'nov',
      'dec',
    ];
    const longMonths = [
      'january',
      'february',
      'march',
      'april',
      'may',
      'june',
      'july',
      'august',
      'september',
      'october',
      'november',
      'december',
    ];
    final month = _month.month.toString().padLeft(2, '0');
    final year = _month.year.toString();
    final yy = year.substring(2);
    final short = shortMonths[_month.month - 1];
    final long = longMonths[_month.month - 1];
    return [
      '$year$month',
      '$month$year',
      '$short$yy',
      '$short$year',
      '$long$yy',
      '$long$year',
    ];
  }

  bool _selectedMonthFromSavedFields(Map<String, dynamic> data) {
    final tokens = _selectedMonthTokens();
    for (final key in [
      'month',
      'monthKey',
      'policyMonth',
      'issueMonth',
      'salesMonth',
    ]) {
      final value = (data[key] ?? '').toString().trim();
      if (value.isEmpty) continue;
      final normalized = _normalizedMonthToken(value);
      if (tokens.contains(normalized)) return true;
    }

    final monthValue = (data['month'] ?? '').toString().trim();
    final yearValue = int.tryParse((data['year'] ?? '').toString());
    if (monthValue.isNotEmpty && yearValue == _month.year) {
      final normalized = _normalizedMonthToken(monthValue);
      const shortMonths = [
        'jan',
        'feb',
        'mar',
        'apr',
        'may',
        'jun',
        'jul',
        'aug',
        'sep',
        'oct',
        'nov',
        'dec',
      ];
      const longMonths = [
        'january',
        'february',
        'march',
        'april',
        'may',
        'june',
        'july',
        'august',
        'september',
        'october',
        'november',
        'december',
      ];
      final numericMonth = _month.month.toString().padLeft(2, '0');
      if (normalized == shortMonths[_month.month - 1] ||
          normalized == longMonths[_month.month - 1] ||
          normalized == numericMonth ||
          normalized == _month.month.toString() ||
          _selectedMonthTokens().any((token) => normalized.contains(token))) {
        return true;
      }
    }
    return false;
  }

  bool _customerInMonth(Map<String, dynamic> data) {
    return _isSelectedMonth(_customerDate(data));
  }

  bool _policyInMonth(Map<String, dynamic> data) {
    return _isSelectedMonth(_policyGivenDate(data)) ||
        _selectedMonthFromSavedFields(data);
  }

  static String _category(Map<String, dynamic> data) {
    final raw = (data['category'] ?? data['customerCategory'] ?? 'Health')
        .toString()
        .toLowerCase();
    if (raw.contains('agri')) return 'Agricultural';
    if (raw.contains('ecgc') || raw.contains('export')) return 'ECGC';
    if (raw == 'life') return 'Life';
    if (raw == 'general') return 'General';
    return 'Health';
  }

  static String _lookupToken(dynamic value) {
    return (value ?? '').toString().trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]+'),
      '',
    );
  }

  static Map<String, Map<String, dynamic>> _policyCatalog(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> masterPolicies,
  ) {
    final catalog = <String, Map<String, dynamic>>{};
    void add(String key, Map<String, dynamic> data) {
      if (key.isNotEmpty) catalog.putIfAbsent(key, () => data);
    }

    for (final doc in masterPolicies) {
      final data = doc.data();
      final category = _category(data);
      final id = _lookupToken(doc.id);
      final code = _lookupToken(data['policyCode']);
      final name = _lookupToken(data['planName'] ?? data['policyName']);
      add('id:$id', data);
      add('$category|id:$id', data);
      add('code:$code', data);
      add('$category|code:$code', data);
      add('name:$name', data);
      add('$category|name:$name', data);
    }
    return catalog;
  }

  static String _policySection(
    Map<String, dynamic> data,
    Map<String, Map<String, dynamic>> catalog,
  ) {
    final direct = (data['policySection'] ?? data['section'] ?? '')
        .toString()
        .trim();
    if (direct.isNotEmpty) return direct;

    final category = _category(data);
    final id = _lookupToken(data['policyId']);
    final code = _lookupToken(data['policyCode']);
    final name = _lookupToken(data['policyName'] ?? data['productName']);
    for (final key in [
      '$category|id:$id',
      'id:$id',
      '$category|code:$code',
      'code:$code',
      '$category|name:$name',
      'name:$name',
    ]) {
      final found = catalog[key];
      final section = (found?['policySection'] ?? found?['section'] ?? '')
          .toString()
          .trim();
      if (section.isNotEmpty) return section;
    }
    return 'Unsectioned';
  }

  bool _linkedToEmployee(
    Map<String, dynamic> data,
    String employeeId,
    String employeeName,
  ) {
    for (final key in [
      'employeeId',
      'createdBy',
      'agentId',
      'assignedAgentId',
    ]) {
      if ((data[key] ?? '').toString().trim() == employeeId) return true;
    }
    final name = employeeName.trim().toLowerCase();
    if (name.isEmpty) return false;
    for (final key in ['employeeName', 'employee', 'agentName']) {
      if ((data[key] ?? '').toString().trim().toLowerCase() == name) {
        return true;
      }
    }
    return false;
  }

  _SalesDashboardData _buildDashboard({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> customers,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> policies,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> masterPolicies,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> employees,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> targets,
  }) {
    final customersById = {for (final doc in customers) doc.id: doc.data()};
    final catalog = _policyCatalog(masterPolicies);
    final monthCustomers = customers
        .where((doc) => _customerInMonth(doc.data()))
        .toList();
    final monthPolicies = policies
        .where((doc) => _policyInMonth(doc.data()))
        .toList();
    final policyCustomerIds = policies
        .map((doc) => (doc.data()['customerId'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toSet();
    final categoryRows = {
      'Health': _CategorySales.empty('Health'),
      'Life': _CategorySales.empty('Life'),
      'General': _CategorySales.empty('General'),
      'Agricultural': _CategorySales.empty('Agricultural'),
      'ECGC': _CategorySales.empty('ECGC'),
    };
    final leadStatus = {'Green': 0, 'Red': 0};
    final companyPremium = <String, double>{};
    final subSections = <String, Map<String, _SubSectionSales>>{};
    final policyHolderKeys = <String>{};

    for (final doc in monthCustomers) {
      final data = doc.data();
      final cat = _category(data);
      final row = categoryRows[cat]!;
      final isLead =
          !policyCustomerIds.contains(doc.id) &&
          data['policyLinkedManually'] != true;
      categoryRows[cat] = row.copyWith(
        customers: row.customers + 1,
        leads: row.leads + (isLead ? 1 : 0),
      );
      if (!isLead) continue;
      final status = (data['leadStatus'] ?? 'Green').toString().toLowerCase();
      if (status == 'green' || status == 'hot') {
        leadStatus['Green'] = leadStatus['Green']! + 1;
      } else if (status == 'red' || status == 'cold') {
        leadStatus['Red'] = leadStatus['Red']! + 1;
      } else {
        leadStatus['Green'] = leadStatus['Green']! + 1;
      }
    }

    for (final doc in monthPolicies) {
      final data = doc.data();
      final customer = customersById[(data['customerId'] ?? '').toString()];
      final cat = _category(
        data['category'] == null && customer != null ? customer : data,
      );
      final premium = _num(data['premiumAmount'] ?? data['premium']);
      final commission = _num(data['commissionAmount'] ?? data['commission']);
      final section = _policySection(data, catalog);
      final customerId = (data['customerId'] ?? '').toString();
      final holderKey = customerId.isNotEmpty
          ? '$cat:$customerId'
          : '$cat:${doc.id}';
      final holderIncrement = policyHolderKeys.add(holderKey) ? 1 : 0;
      final row = categoryRows[cat]!;
      categoryRows[cat] = row.copyWith(
        conversions: row.conversions + 1,
        policyHolders: row.policyHolders + holderIncrement,
        premium: row.premium + premium,
        commission: row.commission + commission,
      );
      final company = (data['companyName'] ?? 'Unassigned').toString();
      companyPremium[company] = (companyPremium[company] ?? 0) + premium;

      final sectionRows = subSections.putIfAbsent(cat, () => {});
      final existingSection =
          sectionRows[section] ?? _SubSectionSales.empty(cat, section);
      sectionRows[section] = existingSection.copyWith(
        policies: existingSection.policies + 1,
        premium: existingSection.premium + premium,
        commission: existingSection.commission + commission,
      );
    }

    final employeeRows =
        employees
            .where((doc) {
              final role = (doc.data()['role'] ?? 'agent').toString();
              return role != 'customer_service';
            })
            .map((employee) {
              final e = employee.data();
              final name = (e['name'] ?? e['username'] ?? 'Employee')
                  .toString();
              final employeePolicies = monthPolicies.where((policy) {
                final p = policy.data();
                final customer =
                    customersById[(p['customerId'] ?? '').toString()];
                return _linkedToEmployee(p, employee.id, name) ||
                    (customer != null &&
                        _linkedToEmployee(customer, employee.id, name));
              }).toList();
              final premium = employeePolicies.fold<double>(
                0,
                (total, doc) =>
                    total +
                    _num(doc.data()['premiumAmount'] ?? doc.data()['premium']),
              );
              final target = targets
                  .where((target) {
                    final t = target.data();
                    final id = (t['employeeId'] ?? '').toString();
                    final targetName = (t['employeeName'] ?? '')
                        .toString()
                        .toLowerCase();
                    return id == employee.id ||
                        targetName == name.toLowerCase();
                  })
                  .fold<double>(
                    0,
                    (total, doc) => total + _num(doc.data()['targetPremium']),
                  );
              return _EmployeeTargetRow(
                name: name,
                premium: premium,
                target: target,
                conversions: employeePolicies.length,
              );
            })
            .toList()
          ..sort((a, b) => b.premium.compareTo(a.premium));

    final totalPremium = categoryRows.values.fold<double>(
      0,
      (total, row) => total + row.premium,
    );
    final totalCommission = categoryRows.values.fold<double>(
      0,
      (total, row) => total + row.commission,
    );
    final totalConversions = categoryRows.values.fold<int>(
      0,
      (total, row) => total + row.conversions,
    );
    final totalLeads = categoryRows.values.fold<int>(
      0,
      (total, row) => total + row.leads,
    );
    final totalPolicyHolders = categoryRows.values.fold<int>(
      0,
      (total, row) => total + row.policyHolders,
    );
    final totalCustomers = categoryRows.values.fold<int>(
      0,
      (total, row) => total + row.customers,
    );
    final totalTargets = employeeRows.fold<double>(
      0,
      (total, row) => total + row.target,
    );
    final targetProgress = totalTargets <= 0
        ? 0.0
        : (totalPremium / totalTargets).clamp(0.0, 1.0);

    final sortedCompanies = Map.fromEntries(
      companyPremium.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value)),
    );
    final sortedSubSections = subSections.map((category, rows) {
      final sortedRows = rows.values.toList()
        ..sort((a, b) => b.premium.compareTo(a.premium));
      return MapEntry(category, sortedRows);
    });

    return _SalesDashboardData(
      categories: categoryRows.values.toList(),
      employees: employeeRows,
      leadStatus: leadStatus,
      companyPremium: sortedCompanies,
      subSections: sortedSubSections,
      recentPolicies: monthPolicies
        ..sort((a, b) {
          final ad = _policyGivenDate(a.data()) ?? DateTime(1900);
          final bd = _policyGivenDate(b.data()) ?? DateTime(1900);
          return bd.compareTo(ad);
        }),
      totalPremium: totalPremium,
      totalCommission: totalCommission,
      totalCustomers: totalCustomers,
      totalLeads: totalLeads,
      totalPolicyHolders: totalPolicyHolders,
      totalConversions: totalConversions,
      targetProgress: targetProgress,
    );
  }

  Future<void> _generateSalesReport(_SalesDashboardData dashboard) async {
    if (_generatingReport) return;
    setState(() => _generatingReport = true);
    try {
      final creatorName =
          (widget.userData?['name'] ??
                  widget.userData?['username'] ??
                  widget.userData?['email'] ??
                  'Admin')
              .toString();
      final creatorId =
          (widget.userData?['_profileDocId'] ?? widget.userData?['uid'] ?? '')
              .toString();
      final monthLabel = _monthLabel(_month);
      final title = 'Sales Report - $monthLabel';

      final policyRows = dashboard.recentPolicies.map((doc) {
        final data = doc.data();
        return {
          'customerName': (data['customerName'] ?? '').toString(),
          'policyName': (data['policyName'] ?? '').toString(),
          'policyNumber': (data['policyNumber'] ?? '').toString(),
          'category': _category(data),
          'companyName': (data['companyName'] ?? 'Unassigned').toString(),
          'premiumAmount': _num(data['premiumAmount'] ?? data['premium']),
          'commissionAmount': _num(
            data['commissionAmount'] ?? data['commission'],
          ),
          'employeeName': (data['employeeName'] ?? data['employee'] ?? '')
              .toString(),
          'policyGivenDate': _dateLabel(data),
        };
      }).toList();

      await FirebaseFirestore.instance.collection('reports').add({
        'title': title,
        'type': 'Sales',
        'month': monthLabel,
        'monthKey': _monthKey(_month),
        'category': 'All',
        'scope': 'All employees',
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': creatorId,
        'createdByName': creatorName,
        'createdByEmail': (widget.userData?['email'] ?? '').toString(),
        'format': 'pdf',
        'payload': {
          'totalPremium': dashboard.totalPremium,
          'totalCommission': dashboard.totalCommission,
          'totalCustomers': dashboard.totalCustomers,
          'totalLeads': dashboard.totalLeads,
          'totalPolicyHolders': dashboard.totalPolicyHolders,
          'totalConversions': dashboard.totalConversions,
          'targetProgress': dashboard.targetProgress,
          'policiesCount': dashboard.recentPolicies.length,
          'categories': dashboard.categories
              .map(
                (row) => {
                  'category': row.category,
                  'customers': row.customers,
                  'leads': row.leads,
                  'policyHolders': row.policyHolders,
                  'conversions': row.conversions,
                  'premium': row.premium,
                  'commission': row.commission,
                },
              )
              .toList(),
          'employees': dashboard.employees
              .map(
                (row) => {
                  'name': row.name,
                  'premium': row.premium,
                  'target': row.target,
                  'conversions': row.conversions,
                  'progress': row.progress,
                },
              )
              .toList(),
          'leadStatus': dashboard.leadStatus,
          'companyPremium': dashboard.companyPremium,
          'subSections': dashboard.subSections.map(
            (category, rows) => MapEntry(
              category,
              rows
                  .map(
                    (row) => {
                      'category': row.category,
                      'section': row.section,
                      'policies': row.policies,
                      'premium': row.premium,
                      'commission': row.commission,
                    },
                  )
                  .toList(),
            ),
          ),
          'rows': policyRows,
        },
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sales report generated in Reports'),
          backgroundColor: _green,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to generate sales report: $error')),
      );
    } finally {
      if (mounted) setState(() => _generatingReport = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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
                      .collection('agents')
                      .snapshots(),
                  builder: (context, employeeSnap) {
                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('employee_targets')
                          .where('monthKey', isEqualTo: _monthKey(_month))
                          .snapshots(),
                      builder: (context, targetSnap) {
                        return StreamBuilder<
                          QuerySnapshot<Map<String, dynamic>>
                        >(
                          stream: FirebaseFirestore.instance
                              .collection('policies')
                              .snapshots(),
                          builder: (context, healthPolicySnap) {
                            return StreamBuilder<
                              QuerySnapshot<Map<String, dynamic>>
                            >(
                              stream: FirebaseFirestore.instance
                                  .collection('life_policies')
                                  .snapshots(),
                              builder: (context, lifePolicySnap) {
                                return StreamBuilder<
                                  QuerySnapshot<Map<String, dynamic>>
                                >(
                                  stream: FirebaseFirestore.instance
                                      .collection('general_policies')
                                      .snapshots(),
                                  builder: (context, generalPolicySnap) {
                                    if (customerSnap.connectionState ==
                                            ConnectionState.waiting ||
                                        policySnap.connectionState ==
                                            ConnectionState.waiting ||
                                        employeeSnap.connectionState ==
                                            ConnectionState.waiting ||
                                        healthPolicySnap.connectionState ==
                                            ConnectionState.waiting ||
                                        lifePolicySnap.connectionState ==
                                            ConnectionState.waiting ||
                                        generalPolicySnap.connectionState ==
                                            ConnectionState.waiting) {
                                      return const Center(
                                        child: CircularProgressIndicator(
                                          color: _accent,
                                        ),
                                      );
                                    }
                                    final dashboard = _buildDashboard(
                                      customers: customerSnap.data?.docs ?? [],
                                      policies: policySnap.data?.docs ?? [],
                                      masterPolicies: [
                                        ...healthPolicySnap.data?.docs ?? [],
                                        ...lifePolicySnap.data?.docs ?? [],
                                        ...generalPolicySnap.data?.docs ?? [],
                                      ],
                                      employees: employeeSnap.data?.docs ?? [],
                                      targets: targetSnap.data?.docs ?? [],
                                    );
                                    return ListView(
                                      padding: const EdgeInsets.all(16),
                                      children: [
                                        _Header(
                                          monthLabel: _monthLabel(_month),
                                          onPrev: () => setState(
                                            () => _month = DateTime(
                                              _month.year,
                                              _month.month - 1,
                                            ),
                                          ),
                                          onNext: () => setState(
                                            () => _month = DateTime(
                                              _month.year,
                                              _month.month + 1,
                                            ),
                                          ),
                                          onToday: () => setState(() {
                                            final now = DateTime.now();
                                            _month = DateTime(
                                              now.year,
                                              now.month,
                                            );
                                          }),
                                          isGeneratingReport: _generatingReport,
                                          onGenerateReport: () =>
                                              _generateSalesReport(dashboard),
                                        ),
                                        const SizedBox(height: 14),
                                        Wrap(
                                          spacing: 10,
                                          runSpacing: 10,
                                          children: [
                                            _MetricTile(
                                              'Premium',
                                              _currency(dashboard.totalPremium),
                                              Icons.currency_rupee_rounded,
                                              _green,
                                            ),
                                            _MetricTile(
                                              'Commission',
                                              _currency(
                                                dashboard.totalCommission,
                                              ),
                                              Icons
                                                  .account_balance_wallet_outlined,
                                              _amber,
                                            ),
                                            _MetricTile(
                                              'Leads + customers',
                                              '${dashboard.totalCustomers}',
                                              Icons.groups_2_outlined,
                                              _primary,
                                            ),
                                            _MetricTile(
                                              'Leads this month',
                                              '${dashboard.totalLeads}',
                                              Icons.person_add_alt_rounded,
                                              _accent,
                                            ),
                                            _MetricTile(
                                              'Policy holders',
                                              '${dashboard.totalPolicyHolders}',
                                              Icons.verified_user_outlined,
                                              _green,
                                            ),
                                            _MetricTile(
                                              'Conversions',
                                              '${dashboard.totalConversions}',
                                              Icons.verified_outlined,
                                              _primary,
                                            ),
                                            _MetricTile(
                                              'Target reached',
                                              '${(dashboard.targetProgress * 100).round()}%',
                                              Icons.track_changes_rounded,
                                              dashboard.targetProgress >= 0.8
                                                  ? _green
                                                  : _red,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 14),
                                        _CategoryDashboard(
                                          categories: dashboard.categories,
                                        ),
                                        const SizedBox(height: 12),
                                        _SubSectionRevenueDashboard(
                                          sections: dashboard.subSections,
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: _ChartCard(
                                                title: 'Lead status this month',
                                                child: _LeadStatusCard(
                                                  counts: dashboard.leadStatus,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: _ChartCard(
                                                title:
                                                    'Employee target progress',
                                                child: _EmployeeTargets(
                                                  rows: dashboard.employees,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        _ChartCard(
                                          title: 'Top company premium',
                                          child: _CompanyMix(
                                            companies: dashboard.companyPremium,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        _RecentSalesTable(
                                          rows: dashboard.recentPolicies,
                                        ),
                                      ],
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
              },
            );
          },
        ),
      ),
    );
  }
}

class _SalesDashboardData {
  final List<_CategorySales> categories;
  final List<_EmployeeTargetRow> employees;
  final Map<String, int> leadStatus;
  final Map<String, double> companyPremium;
  final Map<String, List<_SubSectionSales>> subSections;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> recentPolicies;
  final double totalPremium;
  final double totalCommission;
  final int totalCustomers;
  final int totalLeads;
  final int totalPolicyHolders;
  final int totalConversions;
  final double targetProgress;

  const _SalesDashboardData({
    required this.categories,
    required this.employees,
    required this.leadStatus,
    required this.companyPremium,
    required this.subSections,
    required this.recentPolicies,
    required this.totalPremium,
    required this.totalCommission,
    required this.totalCustomers,
    required this.totalLeads,
    required this.totalPolicyHolders,
    required this.totalConversions,
    required this.targetProgress,
  });
}

class _SubSectionSales {
  final String category;
  final String section;
  final int policies;
  final double premium;
  final double commission;

  const _SubSectionSales({
    required this.category,
    required this.section,
    required this.policies,
    required this.premium,
    required this.commission,
  });

  factory _SubSectionSales.empty(String category, String section) {
    return _SubSectionSales(
      category: category,
      section: section,
      policies: 0,
      premium: 0,
      commission: 0,
    );
  }

  _SubSectionSales copyWith({
    int? policies,
    double? premium,
    double? commission,
  }) {
    return _SubSectionSales(
      category: category,
      section: section,
      policies: policies ?? this.policies,
      premium: premium ?? this.premium,
      commission: commission ?? this.commission,
    );
  }
}

class _CategorySales {
  final String category;
  final int customers;
  final int leads;
  final int policyHolders;
  final int conversions;
  final double premium;
  final double commission;

  const _CategorySales({
    required this.category,
    required this.customers,
    required this.leads,
    required this.policyHolders,
    required this.conversions,
    required this.premium,
    required this.commission,
  });

  factory _CategorySales.empty(String category) {
    return _CategorySales(
      category: category,
      customers: 0,
      leads: 0,
      policyHolders: 0,
      conversions: 0,
      premium: 0,
      commission: 0,
    );
  }

  _CategorySales copyWith({
    int? customers,
    int? leads,
    int? policyHolders,
    int? conversions,
    double? premium,
    double? commission,
  }) {
    return _CategorySales(
      category: category,
      customers: customers ?? this.customers,
      leads: leads ?? this.leads,
      policyHolders: policyHolders ?? this.policyHolders,
      conversions: conversions ?? this.conversions,
      premium: premium ?? this.premium,
      commission: commission ?? this.commission,
    );
  }
}

class _EmployeeTargetRow {
  final String name;
  final double premium;
  final double target;
  final int conversions;
  const _EmployeeTargetRow({
    required this.name,
    required this.premium,
    required this.target,
    required this.conversions,
  });

  double get progress => target <= 0 ? 0 : (premium / target).clamp(0.0, 1.0);
}

class _Header extends StatelessWidget {
  final String monthLabel;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final VoidCallback onGenerateReport;
  final bool isGeneratingReport;
  const _Header({
    required this.monthLabel,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
    required this.onGenerateReport,
    required this.isGeneratingReport,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sales',
                style: TextStyle(
                  color: _SalesTabState._textMain,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Sales use policy given date; leads use customer added date.',
                style: TextStyle(
                  color: _SalesTabState._textMuted,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Previous month',
          onPressed: onPrev,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _SalesTabState._surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _SalesTabState._border),
          ),
          child: Text(
            monthLabel,
            style: const TextStyle(
              color: _SalesTabState._textMain,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: onToday,
          icon: const Icon(Icons.today_rounded, size: 16),
          label: const Text('This month'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _SalesTabState._primary,
            side: const BorderSide(color: _SalesTabState._border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: isGeneratingReport ? null : onGenerateReport,
          icon: isGeneratingReport
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.summarize_outlined, size: 16),
          label: Text(isGeneratingReport ? 'Generating...' : 'Generate Report'),
          style: FilledButton.styleFrom(
            backgroundColor: _SalesTabState._primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Next month',
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricTile(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _SalesTabState._surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _SalesTabState._border),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
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
                    color: _SalesTabState._textMain,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    color: _SalesTabState._textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
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

class _CategoryDashboard extends StatelessWidget {
  final List<_CategorySales> categories;
  const _CategoryDashboard({required this.categories});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth < 760
            ? constraints.maxWidth
            : (constraints.maxWidth - 20) / 3;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: categories.map((row) {
            final color = row.category == 'Health'
                ? _SalesTabState._green
                : row.category == 'Life'
                ? _SalesTabState._primary
                : row.category == 'Agricultural'
                ? _SalesTabState._green
                : row.category == 'ECGC'
                ? _SalesTabState._accent
                : _SalesTabState._amber;
            return SizedBox(
              width: cardWidth,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _SalesTabState._surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _SalesTabState._border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.pie_chart_outline_rounded,
                          color: color,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          row.category,
                          style: const TextStyle(
                            color: _SalesTabState._textMain,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _mini('Premium', _SalesTabState._currency(row.premium)),
                    _mini('Leads', '${row.leads}'),
                    _mini('Policy holders', '${row.policyHolders}'),
                    _mini('Total people', '${row.customers}'),
                    _mini('Conversions', '${row.conversions}'),
                    _mini(
                      'Commission',
                      _SalesTabState._currency(row.commission),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _mini(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: _SalesTabState._textMuted),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: _SalesTabState._textMain,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _ChartCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _SalesTabState._surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _SalesTabState._border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _SalesTabState._textMain,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _SubSectionRevenueDashboard extends StatelessWidget {
  final Map<String, List<_SubSectionSales>> sections;
  const _SubSectionRevenueDashboard({required this.sections});

  @override
  Widget build(BuildContext context) {
    final categories = ['Health', 'Life', 'General', 'Agricultural', 'ECGC'];
    final hasData = sections.values.any((rows) => rows.isNotEmpty);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _SalesTabState._surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _SalesTabState._border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.account_tree_outlined,
                color: _SalesTabState._primary,
                size: 18,
              ),
              SizedBox(width: 8),
              Text(
                'Revenue by policy subsection',
                style: TextStyle(
                  color: _SalesTabState._textMain,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Premium and commission split inside each department section.',
            style: TextStyle(color: _SalesTabState._textMuted, fontSize: 12),
          ),
          const SizedBox(height: 14),
          if (!hasData)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text(
                  'No subsection revenue this month.',
                  style: TextStyle(color: _SalesTabState._textMuted),
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = constraints.maxWidth < 900
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 20) / 3;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: categories.map((category) {
                    final rows =
                        sections[category] ?? const <_SubSectionSales>[];
                    return SizedBox(
                      width: cardWidth,
                      child: _SubSectionCategoryCard(
                        category: category,
                        rows: rows,
                      ),
                    );
                  }).toList(),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _SubSectionCategoryCard extends StatelessWidget {
  final String category;
  final List<_SubSectionSales> rows;
  const _SubSectionCategoryCard({required this.category, required this.rows});

  @override
  Widget build(BuildContext context) {
    final totalPremium = rows.fold<double>(
      0,
      (total, row) => total + row.premium,
    );
    final totalCommission = rows.fold<double>(
      0,
      (total, row) => total + row.commission,
    );
    final color = category == 'Health'
        ? _SalesTabState._green
        : category == 'Life'
        ? _SalesTabState._primary
        : category == 'Agricultural'
        ? _SalesTabState._green
        : category == 'ECGC'
        ? _SalesTabState._accent
        : _SalesTabState._amber;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _SalesTabState._border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.folder_copy_outlined, color: color, size: 17),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  category,
                  style: const TextStyle(
                    color: _SalesTabState._textMain,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                _SalesTabState._currency(totalPremium),
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Commission ${_SalesTabState._currency(totalCommission)}',
            style: const TextStyle(
              color: _SalesTabState._textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          if (rows.isEmpty)
            const Text(
              'No policies in this month',
              style: TextStyle(color: _SalesTabState._textMuted, fontSize: 12),
            )
          else
            ...rows.take(8).map((row) {
              final pct = totalPremium <= 0 ? 0.0 : row.premium / totalPremium;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            row.section,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _SalesTabState._textMain,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          '${row.policies} policies',
                          style: const TextStyle(
                            color: _SalesTabState._textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    LinearProgressIndicator(
                      value: pct,
                      minHeight: 7,
                      color: color,
                      backgroundColor: _SalesTabState._border,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Premium ${_SalesTabState._currency(row.premium)}',
                            style: const TextStyle(
                              color: _SalesTabState._textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          'Comm ${_SalesTabState._currency(row.commission)}',
                          style: const TextStyle(
                            color: _SalesTabState._textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
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
    );
  }
}

class _LeadStatusCard extends StatelessWidget {
  final Map<String, int> counts;
  const _LeadStatusCard({required this.counts});

  @override
  Widget build(BuildContext context) {
    final total = counts.values.fold<int>(0, (total, value) => total + value);
    if (total == 0) {
      return const SizedBox(
        height: 120,
        child: Center(
          child: Text(
            'No leads this month',
            style: TextStyle(color: _SalesTabState._textMuted),
          ),
        ),
      );
    }
    return Column(
      children: counts.entries.map((entry) {
        final pct = total == 0 ? 0.0 : entry.value / total;
        final color = entry.key == 'Green'
            ? _SalesTabState._green
            : _SalesTabState._red;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              SizedBox(
                width: 70,
                child: Text(
                  entry.key,
                  style: const TextStyle(
                    color: _SalesTabState._textMain,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 9,
                  color: color,
                  backgroundColor: _SalesTabState._border,
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 38,
                child: Text(
                  '${entry.value}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: _SalesTabState._textMuted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _EmployeeTargets extends StatelessWidget {
  final List<_EmployeeTargetRow> rows;
  const _EmployeeTargets({required this.rows});

  @override
  Widget build(BuildContext context) {
    final visible = rows.take(6).toList();
    if (visible.isEmpty) {
      return const SizedBox(
        height: 120,
        child: Center(
          child: Text(
            'No employee target data',
            style: TextStyle(color: _SalesTabState._textMuted),
          ),
        ),
      );
    }
    return Column(
      children: visible.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${row.name} (${row.conversions})',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _SalesTabState._textMain,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    row.target <= 0
                        ? 'No target'
                        : '${(row.progress * 100).round()}%',
                    style: const TextStyle(
                      color: _SalesTabState._textMuted,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: row.progress,
                minHeight: 8,
                color: row.progress >= 0.8
                    ? _SalesTabState._green
                    : _SalesTabState._accent,
                backgroundColor: _SalesTabState._border,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _CompanyMix extends StatelessWidget {
  final Map<String, double> companies;
  const _CompanyMix({required this.companies});

  @override
  Widget build(BuildContext context) {
    final entries = companies.entries.take(6).toList();
    final total = entries.fold<double>(
      0,
      (totalValue, e) => totalValue + e.value,
    );
    if (entries.isEmpty) {
      return const SizedBox(
        height: 80,
        child: Center(
          child: Text(
            'No company premium this month',
            style: TextStyle(color: _SalesTabState._textMuted),
          ),
        ),
      );
    }
    return Column(
      children: entries.map((entry) {
        final pct = total == 0 ? 0.0 : entry.value / total;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              SizedBox(
                width: 170,
                child: Text(
                  entry.key,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _SalesTabState._textMain,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 9,
                  color: _SalesTabState._primary,
                  backgroundColor: _SalesTabState._border,
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 100,
                child: Text(
                  _SalesTabState._currency(entry.value),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: _SalesTabState._textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _RecentSalesTable extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> rows;
  const _RecentSalesTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _SalesTabState._surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _SalesTabState._border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text(
              'Monthly conversion details (${rows.length})',
              style: const TextStyle(
                color: _SalesTabState._textMain,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const Divider(height: 1, color: _SalesTabState._border),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                'No conversions this month.',
                style: TextStyle(color: _SalesTabState._textMuted),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingTextStyle: const TextStyle(
                  color: _SalesTabState._textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
                dataTextStyle: const TextStyle(
                  color: _SalesTabState._textMain,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                columns: const [
                  DataColumn(label: Text('Customer')),
                  DataColumn(label: Text('Category')),
                  DataColumn(label: Text('Policy')),
                  DataColumn(label: Text('Policy Date')),
                  DataColumn(label: Text('Employee')),
                  DataColumn(label: Text('Company')),
                  DataColumn(label: Text('Premium')),
                  DataColumn(label: Text('Commission')),
                ],
                rows: rows.map((doc) {
                  final data = doc.data();
                  return DataRow(
                    cells: [
                      DataCell(Text((data['customerName'] ?? '-').toString())),
                      DataCell(Text(_SalesTabState._category(data))),
                      DataCell(Text((data['policyName'] ?? '-').toString())),
                      DataCell(Text(_SalesTabState._dateLabel(data))),
                      DataCell(
                        Text(
                          (data['employeeName'] ?? data['employee'] ?? '-')
                              .toString(),
                        ),
                      ),
                      DataCell(Text((data['companyName'] ?? '-').toString())),
                      DataCell(
                        Text(
                          _SalesTabState._currency(
                            _SalesTabState._num(
                              data['premiumAmount'] ?? data['premium'],
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          _SalesTabState._currency(
                            _SalesTabState._num(
                              data['commissionAmount'] ?? data['commission'],
                            ),
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
    );
  }
}
