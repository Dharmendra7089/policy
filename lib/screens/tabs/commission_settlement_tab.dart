import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../utils/lead_serial_fields.dart';
import '../../widgets/auto_hide_controls.dart';
import '../../widgets/company_logo.dart';

class CommissionSettlementTab extends StatefulWidget {
  const CommissionSettlementTab({super.key});

  @override
  State<CommissionSettlementTab> createState() =>
      _CommissionSettlementTabState();
}

class _CommissionSettlementTabState extends State<CommissionSettlementTab> {
  static const _primary = Color(0xFF0D2D4F);
  static const _bg = Color(0xFFF4F6F9);
  static const _surface = Colors.white;
  static const _border = Color(0xFFE4E7EC);
  static const _textMain = Color(0xFF0D1B2A);
  static const _muted = Color(0xFF667085);
  static const _green = Color(0xFF15803D);
  static const _orange = Color(0xFFB45309);
  static const _blue = Color(0xFF2563EB);

  String _sectionFilter = 'All';
  String? _selectedCompanyKey;

  static const _sections = [
    'All',
    'Health',
    'Life',
    'General',
    'Agriculture',
    'ECGC',
  ];

  Stream<QuerySnapshot<Map<String, dynamic>>> _policyStream() {
    return FirebaseFirestore.instance
        .collection('customer_policies')
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _invoiceStream() {
    return FirebaseFirestore.instance.collection('invoices').snapshots();
  }

  static DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static DateTime? _issueDate(Map<String, dynamic> data) =>
      _date(data['issueDate']) ??
      _date(data['policyStartDate']) ??
      _date(data['createdAt']);

  static String _dateText(dynamic value) {
    final date = _date(value);
    if (date == null) return '-';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  static String _categoryKey(String value) {
    final key = value.trim().toLowerCase();
    return key == 'agricultural' ? 'agriculture' : key;
  }

  static double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(
          (value ?? '').toString().replaceAll(',', '').trim(),
        ) ??
        0;
  }

  static double _premium(Map<String, dynamic> data) =>
      _number(data['premiumAmount'] ?? data['premium']);

  static double _commission(Map<String, dynamic> data) => _number(
    data['settled'] == true
        ? data['settledCommissionAmount'] ?? data['commissionAmount']
        : data['commissionAmount'] ?? data['commission'] ?? data['revenue'],
  );

  static bool _isSettled(Map<String, dynamic> data) =>
      data['settled'] == true ||
      (data['settled'] ?? '').toString().toLowerCase() == 'settled' ||
      (data['settlementStatus'] ?? '').toString().toLowerCase() == 'settled';

  static bool _isFrozen(Map<String, dynamic> data) =>
      !_isSettled(data) &&
      (data['invoiceFrozen'] == true ||
          (data['settlementStatus'] ?? '').toString().toLowerCase() ==
              'invoice_frozen');

  static String _money(double value) {
    final clean = value.toStringAsFixed(2).replaceFirst(RegExp(r'\.00$'), '');
    return 'Rs $clean';
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _validPolicies(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs.where((doc) {
      final data = doc.data();
      if (_premium(data) <= 0 && _commission(data) <= 0) return false;
      if (_sectionFilter == 'All') return true;
      return _categoryKey((data['category'] ?? '').toString()) ==
          _categoryKey(_sectionFilter);
    }).toList();
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _validInvoices(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs.where((doc) {
      final data = doc.data();
      if (_number(data['totalInvoiceValue']) <= 0) return false;
      if (_sectionFilter == 'All') return true;
      return _categoryKey((data['category'] ?? '').toString()) ==
          _categoryKey(_sectionFilter);
    }).toList();
  }

  List<_CompanySettlement> _companies({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> policies,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> invoices,
  }) {
    final map = <String, _CompanySettlement>{};

    for (final doc in policies) {
      final data = doc.data();
      final company = (data['companyName'] ?? 'Unknown Company').toString();
      final key = (data['companyId'] ?? company).toString();
      final item = map.putIfAbsent(
        key,
        () => _CompanySettlement(key: key, companyName: company),
      );
      final premium = _premium(data);
      final commission = _commission(data);
      item.policyCount += 1;
      item.lifetimePremium += premium;
      item.lifetimeCommission += commission;
      if (_isSettled(data)) {
        item.settledAmount += commission;
        item.settledPolicies += 1;
      } else {
        item.yetToSettleAmount += commission;
      }
      if (_isFrozen(data)) item.frozenAmount += commission;
      item.policies.add(data);
    }

    for (final invoice in invoices) {
      final data = invoice.data();
      final company = (data['companyName'] ?? 'Unknown Company').toString();
      final key = (data['companyId'] ?? company).toString();
      final item = map.putIfAbsent(
        key,
        () => _CompanySettlement(key: key, companyName: company),
      );
      item.invoiceGeneratedAmount += _number(data['totalInvoiceValue']);
      item.invoiceCount += 1;
      item.invoices.add(data);
    }

    final list = map.values.toList()
      ..sort((a, b) => b.lifetimeCommission.compareTo(a.lifetimeCommission));
    return list;
  }

  _CompanySettlement _totals(List<_CompanySettlement> companies) {
    final totals = _CompanySettlement(key: 'all', companyName: 'All');
    totals.companyCount = companies.length;
    for (final company in companies) {
      totals.policyCount += company.policyCount;
      totals.settledPolicies += company.settledPolicies;
      totals.invoiceCount += company.invoiceCount;
      totals.lifetimePremium += company.lifetimePremium;
      totals.lifetimeCommission += company.lifetimeCommission;
      totals.frozenAmount += company.frozenAmount;
      totals.invoiceGeneratedAmount += company.invoiceGeneratedAmount;
      totals.settledAmount += company.settledAmount;
      totals.yetToSettleAmount += company.yetToSettleAmount;
    }
    return totals;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bg,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _policyStream(),
        builder: (context, policySnapshot) {
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _invoiceStream(),
            builder: (context, invoiceSnapshot) {
              if (policySnapshot.connectionState == ConnectionState.waiting ||
                  invoiceSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: _primary),
                );
              }
              if (policySnapshot.hasError || invoiceSnapshot.hasError) {
                return const Center(
                  child: Text(
                    'Unable to load commission settlement.',
                    style: TextStyle(color: Colors.red),
                  ),
                );
              }

              final policies = _validPolicies(policySnapshot.data?.docs ?? []);
              final invoices = _validInvoices(invoiceSnapshot.data?.docs ?? []);
              final companies = _companies(
                policies: policies,
                invoices: invoices,
              );
              if (companies.isEmpty) return _empty();

              final selectedCompany =
                  companies
                      .where((item) => item.key == _selectedCompanyKey)
                      .firstOrNull ??
                  companies.first;
              if (_selectedCompanyKey != selectedCompany.key) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() => _selectedCompanyKey = selectedCompany.key);
                  }
                });
              }

              return AutoHideControlsRegion(
                controls: _toolbar(),
                divider: const Divider(height: 1, color: _border),
                body: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                      child: _summaryGrid(_totals(companies), isOverall: true),
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final wide = constraints.maxWidth >= 980;
                          if (!wide) {
                            return ListView(
                              padding: const EdgeInsets.all(16),
                              children: [
                                ...companies.map(
                                  (company) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _companyCard(
                                      company,
                                      selected:
                                          company.key == selectedCompany.key,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _companyDetail(selectedCompany),
                              ],
                            );
                          }
                          return Row(
                            children: [
                              SizedBox(
                                width: 390,
                                child: ListView.separated(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: companies.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    final company = companies[index];
                                    return _companyCard(
                                      company,
                                      selected:
                                          company.key == selectedCompany.key,
                                    );
                                  },
                                ),
                              ),
                              const VerticalDivider(width: 1, color: _border),
                              Expanded(
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.all(16),
                                  child: _companyDetail(selectedCompany),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _toolbar() {
    return Container(
      color: _surface,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: _blue,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Commission Settlement',
                      style: TextStyle(
                        color: _textMain,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Lifetime premium, commission, invoices, frozen and settled amount by company.',
                      style: TextStyle(color: _muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _sections.map((section) {
                final active = _sectionFilter == section;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(section),
                    selected: active,
                    onSelected: (_) => setState(() {
                      _sectionFilter = section;
                      _selectedCompanyKey = null;
                    }),
                    selectedColor: _blue.withValues(alpha: 0.12),
                    backgroundColor: _bg,
                    side: BorderSide(
                      color: active ? _blue.withValues(alpha: 0.35) : _border,
                    ),
                    labelStyle: TextStyle(
                      color: active ? _blue : _muted,
                      fontSize: 12,
                      fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryGrid(_CompanySettlement company, {bool isOverall = false}) {
    final cards = [
      _summary(isOverall ? 'Companies' : 'Policies', '${company.companyCount}'),
      _summary('Life Tym Premium', _money(company.lifetimePremium)),
      _summary('Life Tym Commission', _money(company.lifetimeCommission)),
      _summary('Frozen Amount', _money(company.frozenAmount), color: _blue),
      _summary(
        'Invoice Generated',
        _money(company.invoiceGeneratedAmount),
        color: _orange,
      ),
      _summary('Settled Amount', _money(company.settledAmount), color: _green),
    ];
    if (!isOverall) cards[0] = _summary('Policies', '${company.policyCount}');
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1200
            ? 6
            : width >= 900
            ? 3
            : width >= 560
            ? 2
            : 1;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: columns == 1 ? 5.6 : 2.9,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          children: cards,
        );
      },
    );
  }

  Widget _summary(String title, String value, {Color color = _primary}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _companyCard(_CompanySettlement company, {required bool selected}) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => setState(() => _selectedCompanyKey = company.key),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEFF6FF) : _surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? _blue : _border, width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: CompanyLogoLabel(
                    companyName: company.companyName,
                    logoSize: 30,
                    style: const TextStyle(
                      color: _textMain,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: _muted),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _mini('Premium', _money(company.lifetimePremium)),
                _mini('Commission', _money(company.lifetimeCommission)),
                _mini('Settled', _money(company.settledAmount), color: _green),
                _mini('Frozen', _money(company.frozenAmount), color: _blue),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _mini(String label, String value, {Color color = _textMain}) {
    return Container(
      width: 160,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _muted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _companyDetail(_CompanySettlement company) {
    final policies = [...company.policies]
      ..sort((a, b) {
        final ad = _issueDate(a) ?? DateTime(1900);
        final bd = _issueDate(b) ?? DateTime(1900);
        return bd.compareTo(ad);
      });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CompanyLogoLabel(
                companyName: company.companyName,
                logoSize: 36,
                style: const TextStyle(
                  color: _textMain,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              _summaryGrid(company),
              const SizedBox(height: 14),
              Text(
                '${company.invoiceCount} invoice(s) generated | ${company.settledPolicies} settled policy row(s)',
                style: const TextStyle(
                  color: _muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _border),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFEFF6FF)),
              columns: const [
                DataColumn(label: Text('Lead ID')),
                DataColumn(label: Text('Customer')),
                DataColumn(label: Text('Policy No')),
                DataColumn(label: Text('Issue Date')),
                DataColumn(label: Text('Premium')),
                DataColumn(label: Text('Commission')),
                DataColumn(label: Text('Invoice')),
                DataColumn(label: Text('Status')),
              ],
              rows: policies.map((data) {
                final settled = _isSettled(data);
                final frozen = _isFrozen(data);
                final status = settled
                    ? 'Settled'
                    : frozen
                    ? 'Invoice Frozen'
                    : 'Pending';
                return DataRow(
                  cells: [
                    DataCell(Text(leadUniqueIdFromData(data).ifEmpty('-'))),
                    DataCell(Text((data['customerName'] ?? '-').toString())),
                    DataCell(Text((data['policyNumber'] ?? '-').toString())),
                    DataCell(Text(_dateText(data['issueDate']))),
                    DataCell(Text(_money(_premium(data)))),
                    DataCell(Text(_money(_commission(data)))),
                    DataCell(Text((data['invoiceNo'] ?? '-').toString())),
                    DataCell(
                      Text(
                        status,
                        style: TextStyle(
                          color: settled
                              ? _green
                              : frozen
                              ? _blue
                              : _orange,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _empty() {
    return const Center(
      child: Text(
        'No commission settlement data found.',
        style: TextStyle(color: _muted, fontSize: 13),
      ),
    );
  }
}

class _CompanySettlement {
  _CompanySettlement({required this.key, required this.companyName});

  final String key;
  final String companyName;
  int companyCount = 0;
  int policyCount = 0;
  int settledPolicies = 0;
  int invoiceCount = 0;
  double lifetimePremium = 0;
  double lifetimeCommission = 0;
  double frozenAmount = 0;
  double invoiceGeneratedAmount = 0;
  double settledAmount = 0;
  double yetToSettleAmount = 0;
  final List<Map<String, dynamic>> policies = [];
  final List<Map<String, dynamic>> invoices = [];
}

extension _EmptyString on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
