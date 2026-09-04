import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../utils/audit_log_service.dart';
import '../../utils/lead_serial_fields.dart';
import '../../widgets/auto_hide_controls.dart';
import '../../widgets/company_logo.dart';

class RenewalsTab extends StatefulWidget {
  final Map<String, dynamic>? userData;
  const RenewalsTab({super.key, this.userData});

  @override
  State<RenewalsTab> createState() => _RenewalsTabState();
}

class _RenewalsTabState extends State<RenewalsTab> {
  bool get _isAdmin =>
      (widget.userData?['role'] ?? 'admin').toString().toLowerCase() == 'admin';

  String get _currentEmployeeId =>
      (widget.userData?['_profileDocId'] ?? widget.userData?['uid'] ?? '')
          .toString();

  String get _currentEmployeeName =>
      (widget.userData?['name'] ??
              widget.userData?['username'] ??
              widget.userData?['email'] ??
              'Employee')
          .toString();

  bool _belongsToCurrentEmployee(Map<String, dynamic> data) {
    if (_isAdmin) return true;
    final id = _currentEmployeeId;
    final name = _currentEmployeeName.trim().toLowerCase();
    final employeeId = (data['employeeId'] ?? '').toString().trim();
    final createdBy = (data['createdBy'] ?? '').toString().trim();
    final employeeName = (data['employeeName'] ?? data['employee'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    return (id.isNotEmpty && (employeeId == id || createdBy == id)) ||
        (name.isNotEmpty && employeeName == name);
  }

  static const _primary = Color(0xFF2563EB);
  static const _primaryDark = Color(0xFF1D4ED8);
  static const _bg = Color(0xFFF8FAFC);
  static const _surface = Color(0xFFFFFFFF);
  static const _border = Color(0xFFE5E7EB);
  static const _textMain = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);
  static const _danger = Color(0xFFDC2626);
  static const _warning = Color(0xFFF59E0B);
  static const _success = Color(0xFF16A34A);

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filter = 'all';
  String _sectionFilter = 'All';
  String _sortBy = 'policyEndDate';
  bool _sortAsc = true;

  static const List<String> _sectionFilters = [
    'All',
    'Health',
    'Life',
    'General',
    'ECGC',
    'Agriculture',
  ];

  final List<_SortOption> _sortOptions = const [
    _SortOption('policyEndDate', 'Expiry Date', 'Oldest', 'Newest'),
    _SortOption('policyStartDate', 'Active Date', 'Oldest', 'Newest'),
    _SortOption('customerName', 'Customer', 'A→Z', 'Z→A'),
    _SortOption('policyName', 'Policy', 'A→Z', 'Z→A'),
    _SortOption('policyNumber', 'Policy No.', 'A→Z', 'Z→A'),
  ];

  static const _columns = [
    _ColDef('#', 45, Alignment.center),
    _ColDef('Customer', 160, Alignment.centerLeft),
    _ColDef('Mobile', 110, Alignment.centerLeft),
    _ColDef('Company', 175, Alignment.centerLeft),
    _ColDef('Policy Name', 170, Alignment.centerLeft),
    _ColDef('Policy No.', 130, Alignment.centerLeft),
    _ColDef('Unique ID', 120, Alignment.centerLeft),
    _ColDef('Active Date', 105, Alignment.center),
    _ColDef('Expiry Date', 105, Alignment.center),
    _ColDef('Status', 95, Alignment.center),
    _ColDef('Progress', 120, Alignment.center),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _stream() {
    return FirebaseFirestore.instance
        .collection('customer_policies')
        .orderBy('policyEndDate', descending: false)
        .snapshots();
  }

  DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  bool _isExpired(dynamic v) {
    final d = _toDate(v);
    if (d == null) return false;
    final now = DateTime.now();
    return d.isBefore(DateTime(now.year, now.month, now.day));
  }

  bool _isDueSoon(dynamic v) {
    final d = _toDate(v);
    if (d == null) return false;
    final now = DateTime.now();
    final diff = d.difference(DateTime(now.year, now.month, now.day)).inDays;
    return diff >= 0 && diff <= 60;
  }

  String _fmt(dynamic v) {
    final d = _toDate(v);
    if (d == null) return '-';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _fmtDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _statusFor(Map<String, dynamic> data) {
    final raw = (data['renewalStatus'] ?? data['status'] ?? '')
        .toString()
        .toLowerCase()
        .trim();
    if (raw == 'renewed') return 'Renewed';
    if (_isExpired(data['policyEndDate'])) return 'Expired';
    if (_isDueSoon(data['policyEndDate'])) return 'Due Soon';
    return raw.isEmpty ? 'Upcoming' : raw[0].toUpperCase() + raw.substring(1);
  }

  String _categoryKey(String value) {
    final key = value.trim().toLowerCase();
    return key == 'agricultural' ? 'agriculture' : key;
  }

  String _policyCategory(Map<String, dynamic> data) =>
      (data['category'] ??
              data['customerCategory'] ??
              data['policyCategory'] ??
              data['section'] ??
              '')
          .toString();

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'renewed':
        return _success;
      case 'expired':
        return _danger;
      case 'due soon':
        return _warning;
      case 'upcoming':
        return _primary;
      default:
        return _textMuted;
    }
  }

  void _setSort(String field) {
    setState(() {
      if (_sortBy == field) {
        _sortAsc = !_sortAsc;
      } else {
        _sortBy = field;
        _sortAsc = true;
      }
    });
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _process(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    Set<String> myCustomerIds,
  ) {
    docs = docs.where((d) {
      final data = d.data();

      // Filter renewals of his customers only
      final custId = (data['customerId'] ?? '').toString();
      final createdBy = (data['createdBy'] ?? '').toString();
      final isOwnPolicy =
          createdBy.isNotEmpty && createdBy == _currentEmployeeId;
      if (!myCustomerIds.contains(custId) && !isOwnPolicy) {
        return false;
      }

      final expired = _isExpired(data['policyEndDate']);
      final dueSoon = _isDueSoon(data['policyEndDate']);
      final renewalStatus = (data['renewalStatus'] ?? '')
          .toString()
          .toLowerCase();
      if (_sectionFilter != 'All' &&
          _categoryKey(_policyCategory(data)) != _categoryKey(_sectionFilter)) {
        return false;
      }

      if (_filter == 'expired' && !expired) return false;
      if (_filter == 'dueSoon' && (!dueSoon || renewalStatus == 'renewed')) {
        return false;
      }
      if (_filter == 'renewed' && renewalStatus != 'renewed') return false;
      if (_filter == 'all' &&
          !(renewalStatus != 'renewed' && (expired || dueSoon))) {
        return false;
      }

      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return (data['customerName'] ?? '').toString().toLowerCase().contains(
              q,
            ) ||
            (data['customerMobile'] ?? '').toString().toLowerCase().contains(
              q,
            ) ||
            leadUniqueIdFromData(data).toLowerCase().contains(q) ||
            (data['policyName'] ?? '').toString().toLowerCase().contains(q) ||
            (data['policyNumber'] ?? '').toString().toLowerCase().contains(q) ||
            (data['policyCode'] ?? '').toString().toLowerCase().contains(q) ||
            _policyCategory(data).toLowerCase().contains(q) ||
            (data['companyName'] ?? '').toString().toLowerCase().contains(q) ||
            (data['notes'] ?? '').toString().toLowerCase().contains(q) ||
            (data['renewalNotes'] ?? '').toString().toLowerCase().contains(q);
      }

      return true;
    }).toList();

    docs.sort((a, b) {
      final da = a.data();
      final db = b.data();
      int cmp = 0;

      if (_sortBy == 'customerName' ||
          _sortBy == 'policyName' ||
          _sortBy == 'policyNumber' ||
          _sortBy == 'leadUniqueId') {
        final av = _sortBy == 'leadUniqueId'
            ? leadUniqueIdFromData(da)
            : (da[_sortBy] ?? '').toString();
        final bv = _sortBy == 'leadUniqueId'
            ? leadUniqueIdFromData(db)
            : (db[_sortBy] ?? '').toString();
        cmp = av.compareTo(bv);
      } else {
        final ad = _toDate(da[_sortBy]);
        final bd = _toDate(db[_sortBy]);
        if (ad == null && bd == null) {
          cmp = 0;
        } else if (ad == null) {
          cmp = 1;
        } else if (bd == null) {
          cmp = -1;
        } else {
          cmp = ad.compareTo(bd);
        }
      }

      return _sortAsc ? cmp : -cmp;
    });

    return docs;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bg,
      child: AutoHideControlsRegion(
        controls: _buildTopBar(),
        divider: const Divider(height: 1, color: _border),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('customers')
              .snapshots(),
          builder: (context, customerSnap) {
            if (customerSnap.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: _primary),
              );
            }
            final customers = customerSnap.data?.docs ?? [];
            final myCustomerIds = <String>{};
            for (final c in customers) {
              if (_belongsToCurrentEmployee(c.data())) {
                myCustomerIds.add(c.id);
              }
            }

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _stream(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: _primary),
                  );
                }
                if (snap.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snap.error}',
                      style: const TextStyle(color: _danger),
                    ),
                  );
                }

                final docs = _process(snap.data?.docs ?? [], myCustomerIds);
                if (docs.isEmpty) return _emptyState();

                return Column(
                  children: [
                    Container(
                      color: _surface,
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                      child: Row(
                        children: [
                          Text(
                            '${docs.length} renewal record${docs.length == 1 ? '' : 's'}',
                            style: const TextStyle(
                              color: _textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          _chip('Expired', _danger),
                          const SizedBox(width: 8),
                          _chip('Due Soon 60d', _warning),
                          const SizedBox(width: 8),
                          _chip('Renewed', _success),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: _border),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _tableHeader(),
                              ...docs.asMap().entries.map(
                                (e) => _tableRow(context, e.key, e.value),
                              ),
                            ],
                          ),
                        ),
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

  Widget _buildTopBar() {
    return Container(
      color: _surface,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.autorenew_rounded,
                  color: _primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Policy Renewals',
                      style: TextStyle(
                        color: _textMain,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Expired and due policies from customer_policies.',
                      style: TextStyle(
                        color: _textMuted,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _sortOptions.map((opt) {
                    final active = _sortBy == opt.field;
                    final label = active
                        ? (_sortAsc ? opt.ascLabel : opt.descLabel)
                        : opt.displayName;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: GestureDetector(
                        onTap: () => _setSort(opt.field),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: active
                                ? _primary.withValues(alpha: 0.08)
                                : _bg,
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(
                              color: active
                                  ? _primary.withValues(alpha: 0.25)
                                  : _border,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                label,
                                style: TextStyle(
                                  color: active ? _primaryDark : _textMuted,
                                  fontSize: 11,
                                  fontWeight: active
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                ),
                              ),
                              if (active) ...[
                                const SizedBox(width: 4),
                                Icon(
                                  _sortAsc
                                      ? Icons.arrow_upward_rounded
                                      : Icons.arrow_downward_rounded,
                                  size: 10,
                                  color: _primary,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _sectionFilters
                  .map(
                    (section) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _sectionButton(section),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: _bg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _border),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: const InputDecoration(
                      hintText: 'Search customer, policy, company, notes...',
                      hintStyle: TextStyle(color: _textMuted, fontSize: 12),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: _textMuted,
                        size: 17,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _filterButton('All', 'all'),
              const SizedBox(width: 8),
              _filterButton('Expired', 'expired'),
              const SizedBox(width: 8),
              _filterButton('Due Soon 60d', 'dueSoon'),
              const SizedBox(width: 8),
              _filterButton('Renewed', 'renewed'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterButton(String label, String value) {
    final active = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: active ? _primary.withValues(alpha: 0.08) : _bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? _primary.withValues(alpha: 0.25) : _border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? _primaryDark : _textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _sectionButton(String label) {
    final active = _sectionFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _sectionFilter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: active ? _primary.withValues(alpha: 0.1) : _bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? _primary.withValues(alpha: 0.35) : _border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (active) ...[
              const Icon(Icons.check_rounded, size: 15, color: _primaryDark),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: active ? _primaryDark : _textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(28),
        margin: const EdgeInsets.all(24),
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
                color: _primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.event_busy_outlined,
                color: _primary,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No renewal items',
              style: TextStyle(
                color: _textMain,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Expired or policies due in the next 60 days will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _textMuted, fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tableHeader() {
    return Container(
      decoration: const BoxDecoration(
        color: _primaryDark,
        border: Border(
          bottom: BorderSide(color: Color(0xFF1E40AF), width: 1.5),
        ),
      ),
      child: Row(
        children: _columns.map((col) {
          final sortKey = _sortKeyFor(col.label);
          final isSort = _sortBy == sortKey;

          return GestureDetector(
            onTap: col.label == '#' ? null : () => _setSort(sortKey),
            child: Container(
              width: col.width,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
              decoration: const BoxDecoration(
                border: Border(
                  right: BorderSide(color: Color(0xFF3B82F6), width: 0.4),
                ),
              ),
              alignment: col.align,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: col.align == Alignment.center
                    ? MainAxisAlignment.center
                    : col.align == Alignment.centerRight
                    ? MainAxisAlignment.end
                    : MainAxisAlignment.start,
                children: [
                  Text(
                    col.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  if (isSort) ...[
                    const SizedBox(width: 4),
                    Icon(
                      _sortAsc
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      size: 10,
                      color: Colors.white70,
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _sortKeyFor(String label) {
    switch (label) {
      case 'Customer':
        return 'customerName';
      case 'Policy':
        return 'policyName';
      case 'Policy No.':
        return 'policyNumber';
      case 'Mobile':
        return 'customerMobile';
      case 'Company':
        return 'companyName';
      case 'Unique ID':
        return 'leadUniqueId';
      case 'Active Date':
        return 'policyStartDate';
      case 'Expiry Date':
        return 'policyEndDate';
      case 'Status':
        return 'status';
      default:
        return 'policyEndDate';
    }
  }

  Widget _tableRow(
    BuildContext context,
    int index,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final status = _statusFor(data);
    final statusColor = _statusColor(status);
    final expired = status == 'Expired';
    final note = (data['renewalNotes'] ?? data['notes'] ?? '')
        .toString()
        .trim();
    final uniqueId = leadUniqueIdFromData(data);
    final policyNumber = (data['policyNumber'] ?? '').toString().trim();

    return InkWell(
      onTap: () => _showRenewalDetails(context, doc.id, data),
      child: Container(
        decoration: BoxDecoration(
          color: index.isEven ? _surface : const Color(0xFFF9FBFF),
          border: Border(
            bottom: BorderSide(
              color: _border.withValues(alpha: 0.9),
              width: 0.7,
            ),
          ),
        ),
        child: Row(
          children: [
            _cell(
              '${index + 1}',
              45,
              Alignment.center,
              style: const TextStyle(color: _textMuted, fontSize: 11),
            ),
            _cell(
              data['customerName'] ?? '-',
              160,
              Alignment.centerLeft,
              style: const TextStyle(
                color: _textMain,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              clip: true,
            ),
            _cell(
              data['customerMobile'] ?? '-',
              110,
              Alignment.centerLeft,
              style: const TextStyle(color: _textMuted, fontSize: 11),
            ),
            _companyCell((data['companyName'] ?? '-').toString(), 175),
            _cell(
              data['policyName'] ?? '-',
              170,
              Alignment.centerLeft,
              style: const TextStyle(
                color: _textMain,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              clip: true,
            ),
            _cell(
              policyNumber.isEmpty ? '-' : policyNumber,
              130,
              Alignment.centerLeft,
              style: const TextStyle(
                color: _textMain,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
              clip: true,
            ),
            _cell(
              uniqueId.isEmpty ? '-' : uniqueId,
              120,
              Alignment.centerLeft,
              style: const TextStyle(color: _textMuted, fontSize: 11),
            ),
            _cell(
              _fmt(data['policyStartDate']),
              105,
              Alignment.center,
              style: const TextStyle(color: _textMain, fontSize: 11),
            ),
            _cell(
              _fmt(data['policyEndDate']),
              105,
              Alignment.center,
              style: TextStyle(
                color: expired ? _danger : _textMain,
                fontSize: 11,
                fontWeight: expired ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
            _cell(
              status,
              95,
              Alignment.center,
              style: TextStyle(
                color: statusColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(
              width: 120,
              child: Center(
                child: GestureDetector(
                  onTap: () => _showRenewDialog(context, doc.id, data),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: _primary.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Text(
                      note.isEmpty ? 'Renew' : 'Manage',
                      style: const TextStyle(
                        color: _primaryDark,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cell(
    String value,
    double width,
    Alignment align, {
    TextStyle? style,
    bool clip = false,
  }) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        alignment: align,
        child: Text(
          value,
          maxLines: clip ? 1 : null,
          overflow: clip ? TextOverflow.ellipsis : null,
          style: style ?? const TextStyle(color: _textMain, fontSize: 11),
        ),
      ),
    );
  }

  Widget _companyCell(String value, double width) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        alignment: Alignment.centerLeft,
        child: CompanyLogoLabel(
          companyName: value,
          logoSize: 22,
          style: const TextStyle(color: _textMain, fontSize: 11),
        ),
      ),
    );
  }

  Future<void> _showRenewDialog(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
  ) async {
    final notesCtrl = TextEditingController(
      text: (data['renewalNotes'] ?? '').toString(),
    );
    final monthsCtrl = TextEditingController(text: '12');

    // FIX: use non-nullable DateTime with guaranteed fallback
    DateTime nextEndDate = _toDate(data['policyEndDate']) ?? DateTime.now();

    bool saving = false;
    bool markRenewed = true;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setS) {
            DateTime computeEnd() {
              final base = _toDate(data['policyEndDate']) ?? DateTime.now();
              final months = int.tryParse(monthsCtrl.text.trim()) ?? 12;
              int m = base.month + months;
              int y = base.year + (m - 1) ~/ 12;
              m = ((m - 1) % 12) + 1;
              return DateTime(y, m, base.day);
            }

            void recalc() {
              setS(() => nextEndDate = computeEnd());
            }

            Future<void> save() async {
              setS(() => saving = true);
              try {
                final computedEnd = computeEnd();

                final update = <String, dynamic>{
                  'renewalNotes': notesCtrl.text.trim(),
                  'renewalStatus': markRenewed ? 'Renewed' : 'Pending',
                  'status': markRenewed ? 'Renewed' : 'Active',
                  'renewalMonths': int.tryParse(monthsCtrl.text.trim()) ?? 12,
                  'updatedAt': FieldValue.serverTimestamp(),
                };

                if (markRenewed) {
                  update['renewedAt'] = FieldValue.serverTimestamp();
                  update['policyStartDate'] = Timestamp.fromDate(computedEnd);
                  update['policyEndDate'] = Timestamp.fromDate(computedEnd);
                } else {
                  update['policyEndDate'] = Timestamp.fromDate(computedEnd);
                }

                await FirebaseFirestore.instance
                    .collection('customer_policies')
                    .doc(docId)
                    .set(update, SetOptions(merge: true));
                await AuditLogService.write(
                  page: 'Renewals',
                  action: 'Updated Renewal',
                  description:
                      '${markRenewed ? 'Marked renewed' : 'Updated renewal'} for ${data['customerName'] ?? data['name'] ?? 'customer policy'}.',
                  targetId: docId,
                  targetType: 'Renewal',
                  targetName: (data['customerName'] ?? data['name'] ?? '')
                      .toString(),
                  extra: {
                    'customerName': data['customerName'] ?? data['name'],
                    'policyName': data['policyName'],
                    'renewalStatus': markRenewed ? 'Renewed' : 'Pending',
                  },
                );

                // FIX: use ctx.mounted for dialog context, mounted for widget
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Renewal updated successfully'),
                      backgroundColor: _success,
                    ),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  setS(() => saving = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed: $e'),
                      backgroundColor: _danger,
                    ),
                  );
                }
              }
            }

            return AlertDialog(
              backgroundColor: _surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Manage Renewal',
                style: TextStyle(color: _textMain, fontWeight: FontWeight.w800),
              ),
              content: SizedBox(
                width: 540,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${data['customerName'] ?? ''} • ${data['policyName'] ?? ''}',
                        style: const TextStyle(color: _textMuted, fontSize: 12),
                      ),
                      const SizedBox(height: 14),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: markRenewed,
                        onChanged: (v) => setS(() => markRenewed = v),
                        title: const Text(
                          'Mark as renewed',
                          style: TextStyle(
                            color: _textMain,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: const Text(
                          'When enabled, record is updated and removed from renewals.',
                          style: TextStyle(color: _textMuted, fontSize: 12),
                        ),
                        activeThumbColor: _primary,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: monthsCtrl,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => recalc(),
                        decoration: InputDecoration(
                          labelText: 'Renewal Period in Months',
                          filled: true,
                          fillColor: _bg,
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
                            borderSide: const BorderSide(
                              color: _primary,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: notesCtrl,
                        maxLines: 5,
                        decoration: InputDecoration(
                          labelText: 'Renewal Notes',
                          hintText:
                              'Enter progress, payment status, remarks...',
                          filled: true,
                          fillColor: _bg,
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
                            borderSide: const BorderSide(
                              color: _primary,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // FIX: nextEndDate is now DateTime (non-nullable), no error
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _primary.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _primary.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Text(
                          'Next end date: ${_fmtDate(nextEndDate)}',
                          style: const TextStyle(
                            color: _primaryDark,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(ctx),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: _textMuted),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: saving ? null : save,
                  icon: saving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_rounded, size: 16),
                  label: Text(saving ? 'Saving...' : 'Save Renewal'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
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

  Future<void> _showRenewalDetails(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
  ) async {
    final note = (data['renewalNotes'] ?? '').toString();
    final status = _statusFor(data);
    final color = _statusColor(status);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.78,
          minChildSize: 0.55,
          maxChildSize: 0.95,
          builder: (ctx, scroll) {
            return SingleChildScrollView(
              controller: scroll,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Renewal Details',
                          style: TextStyle(
                            color: _textMain,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: const Icon(
                          Icons.close_rounded,
                          color: _textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _detailCard([
                    _detailRow('Customer', data['customerName'] ?? '-'),
                    _detailRow('Mobile', data['customerMobile'] ?? '-'),
                    _detailRow('Company', data['companyName'] ?? '-'),
                    _detailRow('Policy Name', data['policyName'] ?? '-'),
                    _detailRow('Policy No.', data['policyNumber'] ?? '-'),
                    _detailRow(
                      'Unique ID',
                      leadUniqueIdFromData(data).isEmpty
                          ? '-'
                          : leadUniqueIdFromData(data),
                    ),
                    _detailRow('Active Date', _fmt(data['policyStartDate'])),
                    _detailRow('Expiry Date', _fmt(data['policyEndDate'])),
                    _detailRow('Notes', note.isEmpty ? 'No notes added' : note),
                  ]),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showRenewDialog(context, docId, data);
                          },
                          icon: const Icon(Icons.edit_note_rounded, size: 16),
                          label: const Text('Manage Renewal'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _detailCard(List<Widget> rows) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        children:
            rows
                .expand((r) => [r, const Divider(height: 1, color: _border)])
                .toList()
              ..removeLast(),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: _textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: label == 'Company'
                ? CompanyLogoLabel(
                    companyName: value,
                    logoSize: 24,
                    style: const TextStyle(
                      color: _textMain,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  )
                : Text(
                    value.isEmpty ? '-' : value,
                    style: const TextStyle(
                      color: _textMain,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ColDef {
  final String label;
  final double width;
  final Alignment align;
  const _ColDef(this.label, this.width, this.align);
}

class _SortOption {
  final String field;
  final String displayName;
  final String ascLabel;
  final String descLabel;
  const _SortOption(
    this.field,
    this.displayName,
    this.ascLabel,
    this.descLabel,
  );
}
