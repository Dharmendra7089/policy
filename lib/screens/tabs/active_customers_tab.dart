import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/lead_serial_fields.dart';
import '../../widgets/auto_hide_controls.dart';
import '../../widgets/company_logo.dart';
import '../../widgets/customer_files_card.dart';

class ActiveCustomersTab extends StatefulWidget {
  final void Function({required String customerId, required String category})?
  onOpenCustomerNotes;

  const ActiveCustomersTab({super.key, this.onOpenCustomerNotes});

  @override
  State<ActiveCustomersTab> createState() => _ActiveCustomersTabState();
}

class _ActiveCustomersTabState extends State<ActiveCustomersTab> {
  static const _primary = Color(0xFF2563EB);
  static const _primaryDark = Color(0xFF1D4ED8);
  static const _bg = Color(0xFFF8FAFC);
  static const _surface = Color(0xFFFFFFFF);
  static const _border = Color(0xFFE5E7EB);
  static const _textMain = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);
  static const _danger = Color(0xFFDC2626);
  static const _success = Color(0xFF16A34A);

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'createdAt';
  bool _sortAsc = false;
  String _categoryFilter = 'All';

  Future<void> _openPdfUrl(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open policy PDF.')),
      );
    }
  }

  final List<_SortOption> _sortOptions = const [
    _SortOption('customerName', 'Customer', 'A→Z', 'Z→A'),
    _SortOption('policyName', 'Policy', 'A→Z', 'Z→A'),
    _SortOption('leadUniqueId', 'Unique ID', 'A→Z', 'Z→A'),
    _SortOption('policyStartDate', 'Active Date', 'Oldest', 'Newest'),
    _SortOption('policyEndDate', 'Expiry Date', 'Oldest', 'Newest'),
    _SortOption('createdAt', 'Created', 'Oldest', 'Newest'),
  ];

  static const _categoryFilters = [
    'All',
    'Health',
    'Life',
    'General',
    'Agriculture',
    'ECGC',
  ];

  static const _columns = [
    _ColDef('#', 45, Alignment.center),
    _ColDef('Customer', 160, Alignment.centerLeft),
    _ColDef('Mobile', 110, Alignment.centerLeft),
    _ColDef('Category', 95, Alignment.center),
    _ColDef('Company', 175, Alignment.centerLeft),
    _ColDef('Policy Name', 170, Alignment.centerLeft),
    _ColDef('Unique ID', 120, Alignment.centerLeft),
    _ColDef('Policy No.', 125, Alignment.centerLeft),
    _ColDef('Policy Added By', 135, Alignment.centerLeft),
    _ColDef('Active Date', 105, Alignment.center),
    _ColDef('Expiry Date', 105, Alignment.center),
    _ColDef('Status', 95, Alignment.center),
    _ColDef('Notes', 95, Alignment.center),
  ];

  static String _categoryKey(String value) {
    final key = value.trim().toLowerCase();
    return key == 'agricultural' ? 'agriculture' : key;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _stream() {
    return FirebaseFirestore.instance
        .collection('customer_policies')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _employeesStream() {
    return FirebaseFirestore.instance.collection('agents').snapshots();
  }

  Map<String, String> _employeeNameLookup(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final lookup = <String, String>{};
    for (final doc in docs) {
      final data = doc.data();
      final name = (data['name'] ?? '').toString().trim();
      if (name.isEmpty) continue;

      void add(dynamic value) {
        final key = (value ?? '').toString().trim().toLowerCase();
        if (key.isNotEmpty) lookup[key] = name;
      }

      add(doc.id);
      add(data['uid']);
      add(data['email']);
      add(data['username']);
      add(data['name']);
    }
    return lookup;
  }

  String _policyAddedBy(
    Map<String, dynamic> data,
    Map<String, String> employees,
  ) {
    for (final key in [
      'createdByName',
      'createdBy',
      'createdByEmail',
      'employeeId',
      'employeeName',
      'employee',
    ]) {
      final value = (data[key] ?? '').toString().trim();
      if (value.isEmpty) continue;
      final employeeName = employees[value.toLowerCase()];
      if (employeeName != null && employeeName.isNotEmpty) {
        return employeeName;
      }
    }

    final directName = (data['createdByName'] ?? '').toString().trim();
    if (directName.isNotEmpty) return directName;

    final fallback =
        (data['createdByEmail'] ??
                data['employeeName'] ??
                data['createdBy'] ??
                '')
            .toString()
            .trim();
    return fallback.isEmpty ? '-' : fallback;
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _process(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    if (_categoryFilter != 'All') {
      final selected = _categoryKey(_categoryFilter);
      docs = docs.where((d) {
        final category = _categoryKey((d.data()['category'] ?? '').toString());
        return category == selected;
      }).toList();
    }

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      docs = docs.where((d) {
        final data = d.data();
        return (data['customerName'] ?? '').toString().toLowerCase().contains(
              q,
            ) ||
            (data['customerMobile'] ?? '').toString().toLowerCase().contains(
              q,
            ) ||
            leadUniqueIdFromData(data).toLowerCase().contains(q) ||
            (data['policyNumber'] ?? '').toString().toLowerCase().contains(q) ||
            (data['policyName'] ?? '').toString().toLowerCase().contains(q) ||
            (data['policyCode'] ?? '').toString().toLowerCase().contains(q) ||
            (data['companyName'] ?? '').toString().toLowerCase().contains(q) ||
            (data['category'] ?? '').toString().toLowerCase().contains(q) ||
            (data['notes'] ?? '').toString().toLowerCase().contains(q);
      }).toList();
    }

    docs.sort((a, b) {
      final da = a.data();
      final db = b.data();
      int cmp = 0;

      if (_sortBy == 'policyStartDate' ||
          _sortBy == 'policyEndDate' ||
          _sortBy == 'createdAt') {
        cmp = _cmpDate(da[_sortBy], db[_sortBy]);
      } else if (_sortBy == 'leadUniqueId') {
        cmp = leadUniqueIdFromData(da).compareTo(leadUniqueIdFromData(db));
      } else {
        cmp = (da[_sortBy] ?? '').toString().compareTo(
          (db[_sortBy] ?? '').toString(),
        );
      }

      return _sortAsc ? cmp : -cmp;
    });

    return docs;
  }

  int _cmpDate(dynamic a, dynamic b) {
    final ad = _toDate(a);
    final bd = _toDate(b);
    if (ad == null && bd == null) return 0;
    if (ad == null) return 1;
    if (bd == null) return -1;
    return ad.compareTo(bd);
  }

  DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
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

  String _fmt(dynamic v) {
    final d = _toDate(v);
    if (d == null) return '-';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  bool _isExpired(dynamic v) {
    final d = _toDate(v);
    if (d == null) return false;
    return d.isBefore(DateTime.now());
  }

  Future<void> _openCustomerNotes(Map<String, dynamic> data) async {
    final customerId = (data['customerId'] ?? '').toString().trim();
    if (customerId.isEmpty || widget.onOpenCustomerNotes == null) return;
    try {
      final customerRef = FirebaseFirestore.instance
          .collection('customers')
          .doc(customerId);
      final customerSnap = await customerRef.get();
      if (!customerSnap.exists) {
        final name = (data['customerName'] ?? data['name'] ?? '')
            .toString()
            .trim();
        final mobile = (data['customerMobile'] ?? data['contact'] ?? '')
            .toString()
            .trim();
        final category = (data['category'] ?? '').toString().trim();
        final now = Timestamp.now();
        await customerRef.set({
          'fullName': name,
          'name': name,
          'mobileNumber': mobile,
          'phone': mobile,
          'mobile': mobile,
          'customerCategory': category,
          'category': category,
          'leadStatus': 'Green',
          'status': 'Active',
          'source': 'Policy holder notes repair',
          'policyLinkedManually': true,
          'createdAt': data['createdAt'] ?? now,
          'updatedAt': now,
          'createdBy': data['createdBy'] ?? data['employeeId'] ?? '',
          'createdByName': data['createdByName'] ?? data['employeeName'] ?? '',
          'employeeId': data['employeeId'] ?? data['createdBy'] ?? '',
          'employeeName': data['employeeName'] ?? data['createdByName'] ?? '',
          'notes': data['notes'] ?? '',
          ...leadUniqueIdCopyFields(data),
          'searchKey': '$name $mobile $category ${leadUniqueIdFromData(data)}'
              .toLowerCase(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not prepare customer notes: $e')),
      );
      return;
    }
    widget.onOpenCustomerNotes!(
      customerId: customerId,
      category: (data['category'] ?? '').toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bg,
      child: AutoHideControlsRegion(
        controls: _buildTopBar(),
        divider: const Divider(height: 1, color: _border),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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

            final docs = _process(snap.data?.docs ?? []);
            if (docs.isEmpty) return _emptyState();

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _employeesStream(),
              builder: (context, employeeSnap) {
                final employees = _employeeNameLookup(
                  employeeSnap.data?.docs ?? [],
                );
                return Column(
                  children: [
                    Container(
                      color: _surface,
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                      child: Row(
                        children: [
                          Text(
                            '${_categoryFilter == 'All' ? 'All sections' : _categoryFilter}: ${docs.length} policy record${docs.length == 1 ? '' : 's'}',
                            style: const TextStyle(
                              color: _textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: _primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: _primary.withValues(alpha: 0.2),
                              ),
                            ),
                            child: const Text(
                              'customer_policies',
                              style: TextStyle(
                                color: _primaryDark,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
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
                                (e) => _tableRow(
                                  context,
                                  e.key,
                                  e.value,
                                  employees,
                                ),
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
                  Icons.policy_outlined,
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
                      'Active Customers',
                      style: TextStyle(
                        color: _textMain,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Showing linked customer policies with notes support.',
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
              children: _categoryFilters.map((category) {
                final active = _categoryFilter == category;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(category),
                    selected: active,
                    onSelected: (_) =>
                        setState(() => _categoryFilter = category),
                    selectedColor: _primary.withValues(alpha: 0.12),
                    backgroundColor: _bg,
                    side: BorderSide(
                      color: active
                          ? _primary.withValues(alpha: 0.35)
                          : _border,
                    ),
                    labelStyle: TextStyle(
                      color: active ? _primaryDark : _textMuted,
                      fontSize: 12,
                      fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          Container(
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
        ],
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
                Icons.folder_open_outlined,
                color: _primary,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No active policies found',
              style: TextStyle(
                color: _textMain,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Customer policies will appear here automatically.',
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
      case 'Unique ID':
        return 'leadUniqueId';
      case 'Policy No.':
        return 'policyNumber';
      case 'Active Date':
        return 'policyStartDate';
      case 'Expiry Date':
        return 'policyEndDate';
      case 'Status':
        return 'status';
      case 'Notes':
        return 'notes';
      default:
        return 'createdAt';
    }
  }

  Widget _tableRow(
    BuildContext context,
    int index,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    Map<String, String> employees,
  ) {
    final data = doc.data();
    final expired = _isExpired(data['policyEndDate']);
    final noteText = (data['notes'] ?? '').toString().trim();
    final hasNotes = noteText.isNotEmpty;
    final addedBy = _policyAddedBy(data, employees);
    final uniqueId = leadUniqueIdFromData(data);
    final policyNumber = (data['policyNumber'] ?? '').toString().trim();

    return InkWell(
      onTap: () => _showPolicyDetails(context, doc.id, data, addedBy),
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
              style: const TextStyle(
                color: _textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
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
            _cell(
              (data['category'] ?? '-').toString(),
              95,
              Alignment.center,
              style: const TextStyle(
                color: _primaryDark,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
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
              uniqueId.isEmpty ? '-' : uniqueId,
              120,
              Alignment.centerLeft,
              style: const TextStyle(color: _textMuted, fontSize: 11),
            ),
            _cell(
              policyNumber.isEmpty ? '-' : policyNumber,
              125,
              Alignment.centerLeft,
              style: const TextStyle(
                color: _textMain,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
              clip: true,
            ),
            _cell(
              addedBy,
              135,
              Alignment.centerLeft,
              style: const TextStyle(
                color: _primaryDark,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
              clip: true,
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
              (data['status'] ?? '-').toString(),
              95,
              Alignment.center,
              style: TextStyle(
                color:
                    (data['status'] ?? '').toString().toLowerCase() == 'active'
                    ? _success
                    : _danger,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(
              width: 95,
              child: Center(
                child: GestureDetector(
                  onTap: () => _openCustomerNotes(data),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: hasNotes ? _primary.withValues(alpha: 0.08) : _bg,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: hasNotes
                            ? _primary.withValues(alpha: 0.22)
                            : _border,
                      ),
                    ),
                    child: Text(
                      hasNotes ? 'View Notes' : 'Open Notes',
                      style: TextStyle(
                        color: hasNotes ? _primaryDark : _textMuted,
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

  void _showPolicyDetails(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
    String addedBy,
  ) {
    final customerId = (data['customerId'] ?? '').toString().trim();
    final customerName = (data['customerName'] ?? '').toString().trim();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        final note = (data['notes'] ?? '').toString().trim();
        final pdfUrl = (data['pdfUrl'] ?? '').toString();
        final pdfFileName = (data['pdfFileName'] ?? 'Policy PDF').toString();
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
                          'Policy Details',
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
                  const SizedBox(height: 16),
                  _detailCard([
                    _detailRow('Customer', data['customerName'] ?? '-'),
                    _detailRow('Mobile', data['customerMobile'] ?? '-'),
                    _detailRow('Category', data['category'] ?? '-'),
                    _detailRow('Company', data['companyName'] ?? '-'),
                    _detailRow('Policy Name', data['policyName'] ?? '-'),
                    _detailRow('Policy No.', data['policyNumber'] ?? '-'),
                    _detailRow(
                      'Unique ID',
                      leadUniqueIdFromData(data).isEmpty
                          ? '-'
                          : leadUniqueIdFromData(data),
                    ),
                    _detailRow('Policy Added By', addedBy),
                    _detailRow(
                      'Policy PDF',
                      pdfUrl.isEmpty ? '-' : pdfFileName,
                    ),
                    _detailRow('Active Date', _fmt(data['policyStartDate'])),
                    _detailRow('Expiry Date', _fmt(data['policyEndDate'])),
                    _detailRow('Status', data['status'] ?? '-'),
                    _detailRow('Notes', note.isEmpty ? 'No notes added' : note),
                  ]),
                  const SizedBox(height: 14),
                  if (customerId.isNotEmpty) ...[
                    CustomerFilesCard(
                      customerId: customerId,
                      customerName: customerName.isNotEmpty
                          ? customerName
                          : 'Customer',
                      currentUser: null,
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (pdfUrl.isNotEmpty) ...[
                    OutlinedButton.icon(
                      onPressed: () => _openPdfUrl(context, pdfUrl),
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                      label: Text('Open $pdfFileName'),
                    ),
                    const SizedBox(height: 14),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _openCustomerNotes(data);
                          },
                          icon: const Icon(Icons.edit_note_rounded, size: 16),
                          label: Text(
                            note.isEmpty ? 'Open Notes' : 'View Notes',
                          ),
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
