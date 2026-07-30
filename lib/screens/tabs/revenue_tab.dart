import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class RevenueTab extends StatefulWidget {
  const RevenueTab({super.key});

  @override
  State<RevenueTab> createState() => _RevenueTabState();
}

class _RevenueTabState extends State<RevenueTab> {
  static const _primary = Color(0xFF0D2D4F);
  static const _accent = Color(0xFF1A6EBD);
  static const _bg = Color(0xFFF4F6F9);
  static const _surface = Color(0xFFFFFFFF);
  static const _border = Color(0xFFE4E7EC);
  static const _textMain = Color(0xFF0D1B2A);
  static const _textMuted = Color(0xFF8A94A6);
  static const _green = Color(0xFF16A34A);
  static const _red = Color(0xFFDC2626);
  static const _amber = Color(0xFFF59E0B);

  final TextEditingController _searchCtrl = TextEditingController();

  String _search = '';
  String _selectedCompany = 'All';
  String _selectedStatus = 'All';
  _RevenueSortField _sortField = _RevenueSortField.startDate;
  bool _sortAsc = false;

  Stream<QuerySnapshot<Map<String, dynamic>>> get _stream => FirebaseFirestore
      .instance
      .collection('revenue')
      .orderBy('createdAt', descending: true)
      .snapshots();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
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
                    return Center(
                      child: Text(
                        'Error: ${snap.error}',
                        style: const TextStyle(color: _red),
                      ),
                    );
                  }

                  final rawDocs = snap.data?.docs ?? [];

                  final companies = <String>{
                    'All',
                    ...rawDocs
                        .map((d) => (d.data()['companyName'] ?? '').toString().trim())
                        .where((e) => e.isNotEmpty),
                  }.toList()
                    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

                  final docs = _applyFilters(rawDocs);

                  final totalRevenue = docs.fold<double>(
                    0,
                        (sum, d) => sum + _toDouble(d.data()['revenue']),
                  );
                  final totalPremium = docs.fold<double>(
                    0,
                        (sum, d) => sum + _toDouble(d.data()['premium']),
                  );
                  final totalCommission = docs.fold<double>(
                    0,
                        (sum, d) =>
                    sum + _toDouble(d.data()['commissionAmount'] ?? d.data()['commission']),
                  );
                  final totalPolicies = docs.length;

                  if (rawDocs.isEmpty) {
                    return _buildEmptyState(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'No revenue records yet',
                      subtitle: 'Revenue entries will appear here after policies are linked.',
                    );
                  }

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _buildStatsRow(
                              totalRevenue: totalRevenue,
                              totalPremium: totalPremium,
                              totalCommission: totalCommission,
                              totalPolicies: totalPolicies,
                              isWide: isWide,
                            ),
                            const SizedBox(height: 14),
                            _buildFilters(companies, isWide),
                          ],
                        ),
                      ),
                      Expanded(
                        child: docs.isEmpty
                            ? _buildEmptyState(
                          icon: Icons.filter_alt_off_rounded,
                          title: 'No matching revenue found',
                          subtitle: 'Try changing search, company, status, or sorting.',
                        )
                            : isWide
                            ? _buildDesktopTable(docs)
                            : _buildMobileList(docs),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: _surface,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Revenue',
                  style: TextStyle(
                    color: _textMain,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Track commissions, premium collections, company-wise revenue, and policy dates.',
                  style: TextStyle(
                    color: _textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _primary.withOpacity(0.12)),
            ),
            child: const Row(
              children: [
                Icon(Icons.insights_rounded, size: 16, color: _primary),
                SizedBox(width: 8),
                Text(
                  'Professional Revenue View',
                  style: TextStyle(
                    color: _primary,
                    fontSize: 12,
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

  Widget _buildStatsRow({
    required double totalRevenue,
    required double totalPremium,
    required double totalCommission,
    required int totalPolicies,
    required bool isWide,
  }) {
    final cards = [
      _StatCardData(
        title: 'Total Revenue',
        value: _currency(totalRevenue),
        icon: Icons.account_balance_wallet_rounded,
        color: _green,
      ),
      _StatCardData(
        title: 'Total Premium',
        value: _currency(totalPremium),
        icon: Icons.payments_outlined,
        color: _accent,
      ),
      _StatCardData(
        title: 'Commission Amount',
        value: _currency(totalCommission),
        icon: Icons.percent_rounded,
        color: _amber,
      ),
      _StatCardData(
        title: 'Policies',
        value: totalPolicies.toString(),
        icon: Icons.description_outlined,
        color: _primary,
      ),
    ];

    if (isWide) {
      return Row(
        children: cards
            .map(
              (e) => Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: e == cards.last ? 0 : 12),
              child: _StatCard(data: e),
            ),
          ),
        )
            .toList(),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _StatCard(data: cards[0])),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(data: cards[1])),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _StatCard(data: cards[2])),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(data: cards[3])),
          ],
        ),
      ],
    );
  }

  Widget _buildFilters(List<String> companies, bool isWide) {
    final sortItems = const [
      DropdownMenuItem(
        value: _RevenueSortField.company,
        child: Text('Company'),
      ),
      DropdownMenuItem(
        value: _RevenueSortField.startDate,
        child: Text('Start Date'),
      ),
      DropdownMenuItem(
        value: _RevenueSortField.endDate,
        child: Text('End Date'),
      ),
      DropdownMenuItem(
        value: _RevenueSortField.createdAt,
        child: Text('Created At'),
      ),
      DropdownMenuItem(
        value: _RevenueSortField.revenue,
        child: Text('Revenue'),
      ),
    ];

    final statusItems = const [
      DropdownMenuItem(value: 'All', child: Text('All Status')),
      DropdownMenuItem(value: 'Booked', child: Text('Booked')),
      DropdownMenuItem(value: 'Pending', child: Text('Pending')),
      DropdownMenuItem(value: 'Cancelled', child: Text('Cancelled')),
    ];

    final companyItems = companies
        .map((c) => DropdownMenuItem(value: c, child: Text(c == 'All' ? 'All Companies' : c)))
        .toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: isWide
          ? Row(
        children: [
          Expanded(
            flex: 3,
            child: _searchField(),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: _dropdownBox<String>(
              value: _selectedCompany,
              items: companyItems,
              onChanged: (v) => setState(() => _selectedCompany = v ?? 'All'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: _dropdownBox<String>(
              value: _selectedStatus,
              items: statusItems,
              onChanged: (v) => setState(() => _selectedStatus = v ?? 'All'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: _dropdownBox<_RevenueSortField>(
              value: _sortField,
              items: sortItems,
              onChanged: (v) => setState(() => _sortField = v ?? _RevenueSortField.startDate),
            ),
          ),
          const SizedBox(width: 12),
          _sortToggle(),
        ],
      )
          : Column(
        children: [
          _searchField(),
          const SizedBox(height: 12),
          _dropdownBox<String>(
            value: _selectedCompany,
            items: companyItems,
            onChanged: (v) => setState(() => _selectedCompany = v ?? 'All'),
          ),
          const SizedBox(height: 12),
          _dropdownBox<String>(
            value: _selectedStatus,
            items: statusItems,
            onChanged: (v) => setState(() => _selectedStatus = v ?? 'All'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _dropdownBox<_RevenueSortField>(
                  value: _sortField,
                  items: sortItems,
                  onChanged: (v) =>
                      setState(() => _sortField = v ?? _RevenueSortField.startDate),
                ),
              ),
              const SizedBox(width: 12),
              _sortToggle(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _searchField() {
    return TextField(
      controller: _searchCtrl,
      onChanged: (v) => setState(() => _search = v.toLowerCase().trim()),
      decoration: InputDecoration(
        hintText: 'Search by customer, policy, company, policy number, or mobile...',
        hintStyle: const TextStyle(color: _textMuted, fontSize: 13),
        prefixIcon: const Icon(Icons.search_rounded, color: _textMuted, size: 18),
        filled: true,
        fillColor: _bg,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
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
          borderSide: const BorderSide(color: _accent, width: 1.4),
        ),
      ),
    );
  }

  Widget _sortToggle() {
    return InkWell(
      onTap: () => setState(() => _sortAsc = !_sortAsc),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _sortAsc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
              size: 16,
              color: _primary,
            ),
            const SizedBox(width: 8),
            Text(
              _sortAsc ? 'Asc' : 'Desc',
              style: const TextStyle(
                color: _textMain,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopTable(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
        ),
        child: Column(
          children: [
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: const BoxDecoration(
                color: Color(0xFFF9FAFB),
                borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: const Row(
                children: [
                  _TableHead(width: 140, label: 'Customer'),
                  _TableHead(width: 130, label: 'Company'),
                  _TableHead(width: 150, label: 'Policy'),
                  _TableHead(width: 100, label: 'Premium'),
                  _TableHead(width: 100, label: 'Comm. %'),
                  _TableHead(width: 120, label: 'Comm. Amount'),
                  _TableHead(width: 110, label: 'Revenue'),
                  _TableHead(width: 110, label: 'Start Date'),
                  _TableHead(width: 110, label: 'End Date'),
                  _TableHead(width: 100, label: 'Status'),
                ],
              ),
            ),
            const Divider(height: 1, color: _border),
            Expanded(
              child: ListView.separated(
                itemCount: docs.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: _border),
                itemBuilder: (_, i) {
                  final d = docs[i].data();
                  return _RevenueTableRow(data: d);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileList(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: docs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _RevenueMobileCard(data: docs[i].data()),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: _primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: _primary, size: 30),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: _textMain,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(
                color: _textMuted,
                fontSize: 13,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyFilters(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      ) {
    final filtered = docs.where((doc) {
      final d = doc.data();

      final company = (d['companyName'] ?? '').toString().trim();
      final status = (d['status'] ?? '').toString().trim();

      final searchBag = [
        d['customerName'],
        d['customerMobile'],
        d['policyName'],
        d['policyCode'],
        d['policyNumber'],
        d['companyName'],
        d['category'],
        d['source'],
      ].map((e) => (e ?? '').toString().toLowerCase()).join(' ');

      final matchesSearch = _search.isEmpty || searchBag.contains(_search);
      final matchesCompany = _selectedCompany == 'All' || company == _selectedCompany;
      final matchesStatus = _selectedStatus == 'All' || status == _selectedStatus;

      return matchesSearch && matchesCompany && matchesStatus;
    }).toList();

    filtered.sort((a, b) {
      final da = a.data();
      final db = b.data();

      int result;
      switch (_sortField) {
        case _RevenueSortField.company:
          result = (da['companyName'] ?? '')
              .toString()
              .toLowerCase()
              .compareTo((db['companyName'] ?? '').toString().toLowerCase());
          break;
        case _RevenueSortField.startDate:
          result = _extractDate(da['policyStartDate'])
              .compareTo(_extractDate(db['policyStartDate']));
          break;
        case _RevenueSortField.endDate:
          result = _extractDate(da['policyEndDate'])
              .compareTo(_extractDate(db['policyEndDate']));
          break;
        case _RevenueSortField.createdAt:
          result =
              _extractDate(da['createdAt']).compareTo(_extractDate(db['createdAt']));
          break;
        case _RevenueSortField.revenue:
          result = _toDouble(da['revenue']).compareTo(_toDouble(db['revenue']));
          break;
      }

      return _sortAsc ? result : -result;
    });

    return filtered;
  }

  DateTime _extractDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime(1900);
    return DateTime(1900);
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    return double.tryParse(value.toString()) ?? 0;
  }

  String _currency(double value) {
    final fixed = value.toStringAsFixed(0);
    final chars = fixed.split('').reversed.toList();
    final out = <String>[];

    for (int i = 0; i < chars.length; i++) {
      if (i == 3 || (i > 3 && (i - 1) % 2 == 0)) {
        out.add(',');
      }
      out.add(chars[i]);
    }

    return '₹${out.reversed.join()}';
  }

  Widget _dropdownBox<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      style: const TextStyle(
        color: _textMain,
        fontSize: 13,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: _bg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
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
          borderSide: const BorderSide(color: _accent, width: 1.4),
        ),
      ),
    );
  }
}

enum _RevenueSortField {
  company,
  startDate,
  endDate,
  createdAt,
  revenue,
}

class _StatCardData {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCardData({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
}

class _StatCard extends StatelessWidget {
  final _StatCardData data;

  static const _surface = Color(0xFFFFFFFF);
  static const _border = Color(0xFFE4E7EC);
  static const _textMain = Color(0xFF0D1B2A);
  static const _textMuted = Color(0xFF8A94A6);

  const _StatCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 102,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: data.color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(data.icon, color: data.color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  style: const TextStyle(
                    color: _textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  data.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _textMain,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
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

class _TableHead extends StatelessWidget {
  final double width;
  final String label;

  const _TableHead({
    required this.width,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF8A94A6),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _RevenueTableRow extends StatelessWidget {
  final Map<String, dynamic> data;

  static const _textMain = Color(0xFF0D1B2A);
  static const _textMuted = Color(0xFF8A94A6);
  static const _green = Color(0xFF16A34A);
  static const _amber = Color(0xFFF59E0B);
  static const _red = Color(0xFFDC2626);

  const _RevenueTableRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final customerName = (data['customerName'] ?? '-').toString();
    final companyName = (data['companyName'] ?? '-').toString();
    final policyName = (data['policyName'] ?? '-').toString();
    final premium = _toDouble(data['premium']);
    final commissionPercent = _toDouble(data['commissionPercent']);
    final commissionAmount = _toDouble(data['commissionAmount'] ?? data['commission']);
    final revenue = _toDouble(data['revenue']);
    final startDate = _fmt(data['policyStartDate']);
    final endDate = _fmt(data['policyEndDate']);
    final status = (data['status'] ?? 'Booked').toString();

    final statusColor = status == 'Booked'
        ? _green
        : status == 'Pending'
        ? _amber
        : _red;

    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          _cell(140, customerName, bold: true),
          _cell(130, companyName),
          _cell(150, policyName),
          _cell(100, _currency(premium)),
          _cell(100, '${commissionPercent.toStringAsFixed(0)}%'),
          _cell(120, _currency(commissionAmount)),
          _cell(110, _currency(revenue), color: _green, bold: true),
          _cell(110, startDate, color: _textMuted),
          _cell(110, endDate, color: _textMuted),
          SizedBox(
            width: 100,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cell(
      double width,
      String text, {
        Color color = _textMain,
        bool bold = false,
      }) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 12.5,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    return double.tryParse(value.toString()) ?? 0;
  }

  static String _currency(double value) {
    final fixed = value.toStringAsFixed(0);
    final chars = fixed.split('').reversed.toList();
    final out = <String>[];
    for (int i = 0; i < chars.length; i++) {
      if (i == 3 || (i > 3 && (i - 1) % 2 == 0)) {
        out.add(',');
      }
      out.add(chars[i]);
    }
    return '₹${out.reversed.join()}';
  }

  static String _fmt(dynamic v) {
    if (v == null) return '-';
    DateTime? d;
    if (v is Timestamp) d = v.toDate();
    if (v is DateTime) d = v;
    if (v is String) d = DateTime.tryParse(v);
    if (d == null) return '-';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}

class _RevenueMobileCard extends StatelessWidget {
  final Map<String, dynamic> data;

  static const _surface = Color(0xFFFFFFFF);
  static const _border = Color(0xFFE4E7EC);
  static const _textMain = Color(0xFF0D1B2A);
  static const _textMuted = Color(0xFF8A94A6);
  static const _green = Color(0xFF16A34A);
  static const _amber = Color(0xFFF59E0B);
  static const _red = Color(0xFFDC2626);
  static const _accent = Color(0xFF1A6EBD);

  const _RevenueMobileCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final customerName = (data['customerName'] ?? '-').toString();
    final companyName = (data['companyName'] ?? '-').toString();
    final policyName = (data['policyName'] ?? '-').toString();
    final policyNumber = (data['policyNumber'] ?? '-').toString();
    final premium = _toDouble(data['premium']);
    final commissionPercent = _toDouble(data['commissionPercent']);
    final commissionAmount = _toDouble(data['commissionAmount'] ?? data['commission']);
    final revenue = _toDouble(data['revenue']);
    final startDate = _fmt(data['policyStartDate']);
    final endDate = _fmt(data['policyEndDate']);
    final status = (data['status'] ?? 'Booked').toString();

    final statusColor = status == 'Booked'
        ? _green
        : status == 'Pending'
        ? _amber
        : _red;

    return Container(
      padding: const EdgeInsets.all(14),
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
              const Icon(Icons.receipt_long_outlined, color: _accent, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  customerName,
                  style: const TextStyle(
                    color: _textMain,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '$policyName • $policyNumber',
            style: const TextStyle(
              color: _textMain,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            companyName,
            style: const TextStyle(
              color: _textMuted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _miniTile('Premium', _currency(premium))),
              const SizedBox(width: 10),
              Expanded(child: _miniTile('Revenue', _currency(revenue), valueColor: _green)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _miniTile(
                  'Commission',
                  '${commissionPercent.toStringAsFixed(0)}% / ${_currency(commissionAmount)}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _miniTile('Start Date', startDate, muted: true)),
              const SizedBox(width: 10),
              Expanded(child: _miniTile('End Date', endDate, muted: true)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniTile(
      String label,
      String value, {
        bool muted = false,
        Color? valueColor,
      }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: valueColor ?? (muted ? _textMuted : _textMain),
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    return double.tryParse(value.toString()) ?? 0;
  }

  static String _currency(double value) {
    final fixed = value.toStringAsFixed(0);
    final chars = fixed.split('').reversed.toList();
    final out = <String>[];
    for (int i = 0; i < chars.length; i++) {
      if (i == 3 || (i > 3 && (i - 1) % 2 == 0)) {
        out.add(',');
      }
      out.add(chars[i]);
    }
    return '₹${out.reversed.join()}';
  }

  static String _fmt(dynamic v) {
    if (v == null) return '-';
    DateTime? d;
    if (v is Timestamp) d = v.toDate();
    if (v is DateTime) d = v;
    if (v is String) d = DateTime.tryParse(v);
    if (d == null) return '-';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}
