import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../utils/audit_log_service.dart';

class ClaimsTab extends StatefulWidget {
  final Map<String, dynamic>? currentUser;
  const ClaimsTab({super.key, this.currentUser});

  @override
  State<ClaimsTab> createState() => _ClaimsTabState();
}

class _ClaimsTabState extends State<ClaimsTab> {
  static const _primary = Color(0xFF2563EB);
  static const _primaryDark = Color(0xFF1D4ED8);
  static const _bg = Color(0xFFF8FAFC);
  static const _surface = Color(0xFFFFFFFF);
  static const _border = Color(0xFFE5E7EB);
  static const _textMain = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);
  static const _requested = Color(0xFF2563EB);
  static const _inReview = Color(0xFFF59E0B);
  static const _approved = Color(0xFF16A34A);
  static const _rejected = Color(0xFFDC2626);

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'requestedAt';
  bool _sortAsc = false;

  final List<_SortOption> _sortOptions = const [
    _SortOption('requestedAt', 'Requested', 'Oldest', 'Newest'),
    _SortOption('customerName', 'Customer', 'A→Z', 'Z→A'),
    _SortOption('customerMobile', 'Mobile', 'Low→High', 'High→Low'),
    _SortOption('claimAmount', 'Amount', 'Low→High', 'High→Low'),
    _SortOption('claimStatus', 'Status', 'A→Z', 'Z→A'),
  ];

  static const _columns = [
    _ColDef('#', 45, Alignment.center),
    _ColDef('Customer', 150, Alignment.centerLeft),
    _ColDef('Mobile', 110, Alignment.centerLeft),
    _ColDef('Policy', 150, Alignment.centerLeft),
    _ColDef('Policy Code', 110, Alignment.centerLeft),
    _ColDef('Claim Type', 110, Alignment.centerLeft),
    _ColDef('Amount', 100, Alignment.centerRight),
    _ColDef('Requested On', 110, Alignment.center),
    _ColDef('Status', 100, Alignment.center),
    _ColDef('Progress', 120, Alignment.center),
    _ColDef('Action', 90, Alignment.center),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _claimsStream() {
    return FirebaseFirestore.instance.collection('claims').snapshots();
  }

  bool get _isAdmin =>
      (widget.currentUser?['role'] ?? 'admin').toString().toLowerCase() ==
      'admin';

  String get _employeeId =>
      (widget.currentUser?['_profileDocId'] ?? widget.currentUser?['uid'] ?? '')
          .toString();

  String get _employeeName =>
      (widget.currentUser?['name'] ??
              widget.currentUser?['username'] ??
              widget.currentUser?['email'] ??
              '')
          .toString();

  bool _belongsToCurrentUser(Map<String, dynamic> data) {
    if (_isAdmin) return true;
    final id = _employeeId;
    final name = _employeeName.trim().toLowerCase();
    final employeeId = (data['employeeId'] ?? data['createdBy'] ?? '')
        .toString()
        .trim();
    final employeeName = (data['employeeName'] ?? data['employee'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    return (id.isNotEmpty && employeeId == id) ||
        (name.isNotEmpty && employeeName == name);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _customersStream() {
    return FirebaseFirestore.instance.collection('customers').snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _policiesStream() {
    return FirebaseFirestore.instance
        .collection('customer_policies')
        .snapshots();
  }

  Set<String> _activeCustomerKeys(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs.map((doc) => 'id:${doc.id}').toSet();
  }

  bool _hasActiveCustomer(Map<String, dynamic> data, Set<String> keys) {
    final customerId = (data['customerId'] ?? '').toString().trim();
    return customerId.isNotEmpty && keys.contains('id:$customerId');
  }

  Set<String> _linkedPolicyKeys(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    Set<String> activeCustomers,
  ) {
    final keys = <String>{};
    for (final doc in docs) {
      final data = doc.data();
      if (!_hasActiveCustomer(data, activeCustomers)) continue;

      keys.add('policy:${doc.id}');
    }
    return keys;
  }

  bool _hasLinkedPolicy(Map<String, dynamic> data, Set<String> keys) {
    final policyDocId = (data['policyDocId'] ?? '').toString().trim();
    return policyDocId.isNotEmpty && keys.contains('policy:$policyDocId');
  }

  Map<String, dynamic>? _linkedPolicyForClaim(
    Map<String, dynamic> claim,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> policies,
    Set<String> activeCustomers,
  ) {
    final policyDocId = (claim['policyDocId'] ?? '').toString().trim();
    if (policyDocId.isNotEmpty) {
      for (final policy in policies) {
        if (policy.id == policyDocId &&
            _hasActiveCustomer(policy.data(), activeCustomers)) {
          return policy.data();
        }
      }
    }
    return null;
  }

  DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  String _fmt(dynamic v) {
    final d = _toDate(v);
    if (d == null) return '-';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _norm(String s) => s.toLowerCase().trim();

  String _statusText(Map<String, dynamic> data) {
    final s = (data['claimStatus'] ?? 'Requested').toString().trim();
    if (s.isEmpty) return 'Requested';
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }

  Color _statusColor(String status) {
    switch (_norm(status)) {
      case 'requested':
        return _requested;
      case 'under review':
        return _inReview;
      case 'approved':
        return _approved;
      case 'rejected':
        return _rejected;
      default:
        return _textMuted;
    }
  }

  Color _statusBg(String status) {
    switch (_norm(status)) {
      case 'requested':
        return const Color(0xFFEFF6FF);
      case 'under review':
        return const Color(0xFFFFFBEB);
      case 'approved':
        return const Color(0xFFF0FDF4);
      case 'rejected':
        return const Color(0xFFFEF2F2);
      default:
        return _bg;
    }
  }

  int _progressValue(String status) {
    switch (_norm(status)) {
      case 'requested':
        return 10;
      case 'under review':
        return 50;
      case 'approved':
        return 100;
      case 'rejected':
        return 0;
      default:
        return 0;
    }
  }

  int _progressForClaim(Map<String, dynamic> claim) {
    final raw = claim['claimProgress'];
    if (raw is num) return raw.clamp(0, 100).round();
    final parsed = int.tryParse((raw ?? '').toString());
    if (parsed != null) return parsed.clamp(0, 100);
    return _progressValue(_statusText(claim));
  }

  List<Map<String, dynamic>> _claimNotes(Map<String, dynamic> claim) {
    final rawNotes = claim['claimNotesLog'];
    final notes = <Map<String, dynamic>>[];
    if (rawNotes is List) {
      for (final item in rawNotes) {
        if (item is Map) {
          notes.add(Map<String, dynamic>.from(item));
        }
      }
    }
    if (notes.isEmpty) {
      final legacy = (claim['claimNotes'] ?? '').toString().trim();
      if (legacy.isNotEmpty) {
        notes.add({
          'note': legacy,
          'status': claim['claimStatus'] ?? 'Requested',
          'createdAt': claim['updatedAt'] ?? claim['createdAt'],
          'createdBy': claim['employeeName'] ?? claim['employee'] ?? '',
        });
      }
    }
    notes.sort((a, b) {
      final ad = _toDate(a['createdAt']) ?? DateTime(1900);
      final bd = _toDate(b['createdAt']) ?? DateTime(1900);
      return bd.compareTo(ad);
    });
    return notes;
  }

  List<Map<String, dynamic>> _process(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    Map<String, Map<String, dynamic>> policiesByClaim,
  ) {
    final list = docs
        .map((doc) {
          final data = doc.data();
          final policy = policiesByClaim[doc.id] ?? const <String, dynamic>{};
          return {
            'id': doc.id,
            'policyDocId': (data['policyDocId'] ?? '').toString(),
            'customerId': (data['customerId'] ?? '').toString(),
            'customerName': (data['customerName'] ?? data['name'] ?? '')
                .toString(),
            'customerMobile': (data['customerMobile'] ?? data['contact'] ?? '')
                .toString(),
            'policyName': (policy['policyName'] ?? data['policyName'] ?? '')
                .toString(),
            'policyCode': (policy['policyCode'] ?? data['policyCode'] ?? '')
                .toString(),
            'claimType': (data['claimType'] ?? 'General').toString(),
            'claimAmount': (data['claimAmount'] is num)
                ? (data['claimAmount'] as num).toDouble()
                : double.tryParse((data['claimAmount'] ?? '0').toString()) ?? 0,
            'requestedAt':
                data['requestedAt'] ?? data['createdAt'] ?? data['claimDate'],
            'claimStatus': (data['claimStatus'] ?? 'Requested').toString(),
            'claimProgress': data['claimProgress'],
            'claimNotes': (data['claimNotes'] ?? '').toString(),
            'claimNotesLog': data['claimNotesLog'],
            'claimReference': (data['claimReference'] ?? '').toString(),
            'createdAt': data['createdAt'],
            'updatedAt': data['updatedAt'],
            'raw': data,
          };
        })
        .where((m) {
          final q = _searchQuery.trim().toLowerCase();
          if (q.isEmpty) return true;
          return (m['customerName'] ?? '').toString().toLowerCase().contains(
                q,
              ) ||
              (m['customerMobile'] ?? '').toString().toLowerCase().contains(
                q,
              ) ||
              (m['policyName'] ?? '').toString().toLowerCase().contains(q) ||
              (m['policyCode'] ?? '').toString().toLowerCase().contains(q) ||
              (m['claimType'] ?? '').toString().toLowerCase().contains(q) ||
              (m['claimStatus'] ?? '').toString().toLowerCase().contains(q);
        })
        .toList();

    list.sort((a, b) {
      int cmp = 0;
      if (_sortBy == 'customerName' ||
          _sortBy == 'customerMobile' ||
          _sortBy == 'claimStatus') {
        cmp = (a[_sortBy] ?? '').toString().compareTo(
          (b[_sortBy] ?? '').toString(),
        );
      } else if (_sortBy == 'claimAmount') {
        cmp = ((a['claimAmount'] ?? 0) as double).compareTo(
          (b['claimAmount'] ?? 0) as double,
        );
      } else {
        final ad = _toDate(a[_sortBy]);
        final bd = _toDate(b[_sortBy]);
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

    return list;
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

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bg,
      child: Column(
        children: [
          _buildToolbar(),
          _buildStatsRow(),
          const Divider(height: 1, color: _border),
          _buildSortRow(),
          const Divider(height: 1, color: _border),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _customersStream(),
              builder: (context, customersSnap) {
                if (customersSnap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: _primary),
                  );
                }
                if (customersSnap.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${customersSnap.error}',
                      style: const TextStyle(color: _rejected),
                    ),
                  );
                }

                final activeCustomers = _activeCustomerKeys(
                  customersSnap.data?.docs ?? [],
                );

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _policiesStream(),
                  builder: (context, policiesSnap) {
                    if (policiesSnap.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: _primary),
                      );
                    }
                    if (policiesSnap.hasError) {
                      return Center(
                        child: Text(
                          'Error: ${policiesSnap.error}',
                          style: const TextStyle(color: _rejected),
                        ),
                      );
                    }

                    final linkedPolicies = _linkedPolicyKeys(
                      policiesSnap.data?.docs ?? [],
                      activeCustomers,
                    );

                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _claimsStream(),
                      builder: (context, claimsSnap) {
                        if (claimsSnap.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(color: _primary),
                          );
                        }
                        if (claimsSnap.hasError) {
                          return Center(
                            child: Text(
                              'Error: ${claimsSnap.error}',
                              style: const TextStyle(color: _rejected),
                            ),
                          );
                        }

                        final visibleDocs =
                            <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                        final policiesByClaim =
                            <String, Map<String, dynamic>>{};
                        for (final claim in claimsSnap.data?.docs ?? []) {
                          if (!_hasActiveCustomer(
                                claim.data(),
                                activeCustomers,
                              ) ||
                              !_hasLinkedPolicy(claim.data(), linkedPolicies) ||
                              !_belongsToCurrentUser(claim.data())) {
                            continue;
                          }
                          final policy = _linkedPolicyForClaim(
                            claim.data(),
                            policiesSnap.data?.docs ?? [],
                            activeCustomers,
                          );
                          if (policy == null) continue;
                          visibleDocs.add(claim);
                          policiesByClaim[claim.id] = policy;
                        }
                        final claims = _process(visibleDocs, policiesByClaim);
                        if (claims.isEmpty) return _emptyState();

                        return Column(
                          children: [
                            Container(
                              color: _surface,
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                              child: Row(
                                children: [
                                  Text(
                                    '${claims.length} claim${claims.length == 1 ? '' : 's'}',
                                    style: const TextStyle(
                                      color: _textMuted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const Spacer(),
                                  const Text(
                                    'Requested, review, approved and rejected claims are shown here',
                                    style: TextStyle(
                                      color: _textMuted,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _tableHeader(),
                                      ...claims.asMap().entries.map(
                                        (e) =>
                                            _tableRow(context, e.key, e.value),
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      color: _surface,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.assignment_turned_in_outlined,
              color: _primary,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Claims Requests',
                  style: TextStyle(
                    color: _textMain,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Search by customer name or mobile, then create claim requests.',
                  style: TextStyle(
                    color: _textMuted,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 260,
            height: 40,
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search by name or mobile',
                hintStyle: const TextStyle(color: _textMuted, fontSize: 12),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 17,
                  color: _textMuted,
                ),
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
                  borderSide: const BorderSide(color: _primary, width: 1.4),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: () => _showNewClaimDialog(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text(
              'Request Claim',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _customersStream(),
      builder: (context, customerSnap) {
        final activeCustomers = _activeCustomerKeys(
          customerSnap.data?.docs ?? [],
        );
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _policiesStream(),
          builder: (context, policySnap) {
            final linkedPolicies = _linkedPolicyKeys(
              policySnap.data?.docs ?? [],
              activeCustomers,
            );
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('claims')
                  .snapshots(),
              builder: (context, snap) {
                final docs = (snap.data?.docs ?? [])
                    .where(
                      (doc) =>
                          _hasActiveCustomer(doc.data(), activeCustomers) &&
                          _hasLinkedPolicy(doc.data(), linkedPolicies) &&
                          _belongsToCurrentUser(doc.data()),
                    )
                    .toList();
                final requested = docs
                    .where(
                      (d) =>
                          _norm((d.data()['claimStatus'] ?? '')) == 'requested',
                    )
                    .length;
                final underReview = docs
                    .where(
                      (d) =>
                          _norm((d.data()['claimStatus'] ?? '')) ==
                          'under review',
                    )
                    .length;
                final approved = docs
                    .where(
                      (d) =>
                          _norm((d.data()['claimStatus'] ?? '')) == 'approved',
                    )
                    .length;
                final rejected = docs
                    .where(
                      (d) =>
                          _norm((d.data()['claimStatus'] ?? '')) == 'rejected',
                    )
                    .length;

                final stats = [
                  _Stat(
                    'Requested',
                    requested.toString(),
                    _primary,
                    const Color(0xFFEFF6FF),
                  ),
                  _Stat(
                    'Under Review',
                    underReview.toString(),
                    _inReview,
                    const Color(0xFFFFFBEB),
                  ),
                  _Stat(
                    'Approved',
                    approved.toString(),
                    _approved,
                    const Color(0xFFF0FDF4),
                  ),
                  _Stat(
                    'Rejected',
                    rejected.toString(),
                    _rejected,
                    const Color(0xFFFEF2F2),
                  ),
                ];

                return Container(
                  color: _surface,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: stats.map((s) {
                        return Container(
                          margin: const EdgeInsets.only(right: 10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: s.bgColor,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: s.color.withOpacity(0.15),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.value,
                                style: TextStyle(
                                  color: s.color,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                s.label,
                                style: const TextStyle(
                                  color: _textMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSortRow() {
    return Container(
      color: _surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _sortOptions.map((opt) {
            final active = _sortBy == opt.field;
            final label = active
                ? (_sortAsc ? opt.ascLabel : opt.descLabel)
                : opt.displayName;
            return GestureDetector(
              onTap: () => _setSort(opt.field),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: active ? _primaryDark : _bg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: active ? _primaryDark : _border),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: active ? Colors.white : _textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            );
          }).toList(),
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
            onTap: col.label == '#' || col.label == 'Action'
                ? null
                : () => _setSort(sortKey),
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
      case 'Mobile':
        return 'customerMobile';
      case 'Policy':
        return 'policyName';
      case 'Policy Code':
        return 'policyCode';
      case 'Claim Type':
        return 'claimType';
      case 'Amount':
        return 'claimAmount';
      case 'Requested On':
        return 'requestedAt';
      case 'Status':
        return 'claimStatus';
      case 'Progress':
        return 'claimProgress';
      default:
        return 'requestedAt';
    }
  }

  Widget _tableRow(
    BuildContext context,
    int index,
    Map<String, dynamic> claim,
  ) {
    final status = _statusText(claim);
    final statusColor = _statusColor(status);
    final typeColor = _primary;
    final amount = (claim['claimAmount'] ?? 0).toString();
    final progress = _progressForClaim(claim);

    return InkWell(
      onTap: () => _showClaimDetails(context, claim),
      child: Container(
        decoration: BoxDecoration(
          color: index.isEven ? _surface : const Color(0xFFF9FBFF),
          border: Border(
            bottom: BorderSide(color: _border.withOpacity(0.9), width: 0.7),
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
              claim['customerName'] ?? '-',
              150,
              Alignment.centerLeft,
              style: const TextStyle(
                color: _textMain,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              clip: true,
            ),
            _cell(
              claim['customerMobile'] ?? '-',
              110,
              Alignment.centerLeft,
              style: const TextStyle(color: _textMuted, fontSize: 11),
            ),
            _cell(
              claim['policyName'] ?? '-',
              150,
              Alignment.centerLeft,
              style: TextStyle(
                color: typeColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              clip: true,
            ),
            _cell(
              claim['policyCode'] ?? '-',
              110,
              Alignment.centerLeft,
              style: const TextStyle(color: _textMuted, fontSize: 11),
            ),
            _cell(
              claim['claimType'] ?? '-',
              110,
              Alignment.centerLeft,
              style: const TextStyle(
                color: _textMain,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            _cell(
              '₹${amount}',
              100,
              Alignment.centerRight,
              style: const TextStyle(
                color: _textMain,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            _cell(
              _fmt(claim['requestedAt']),
              110,
              Alignment.center,
              style: const TextStyle(color: _textMuted, fontSize: 11),
            ),
            SizedBox(
              width: 100,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _statusBg(status),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: statusColor.withOpacity(0.18)),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 120,
              child: Center(
                child: SizedBox(
                  width: 88,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress / 100,
                      minHeight: 8,
                      backgroundColor: _bg,
                      valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 90,
              child: Center(
                child: GestureDetector(
                  onTap: () => _showClaimDetails(context, claim),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: _primary.withOpacity(0.22)),
                    ),
                    child: const Text(
                      'Manage',
                      style: TextStyle(
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
                color: _primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.assignment_outlined,
                color: _primary,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No requested claims',
              style: TextStyle(
                color: _textMain,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Requested claims will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _textMuted, fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  void _showNewClaimDialog(BuildContext context) {
    final searchCtrl = TextEditingController();
    final claimTypeCtrl = TextEditingController(text: 'General');
    final claimAmountCtrl = TextEditingController();
    final claimNotesCtrl = TextEditingController();
    final claimRefCtrl = TextEditingController();

    String selectedPolicyId = '';
    String selectedCustomerId = '';
    String selectedCustomerName = '';
    String selectedCustomerMobile = '';
    String selectedPolicyName = '';
    String selectedPolicyCode = '';
    DateTime requestedAt = DateTime.now();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setS) {
            Future<void> saveRequest() async {
              if (selectedPolicyId.isEmpty ||
                  selectedCustomerName.isEmpty ||
                  selectedCustomerMobile.isEmpty) {
                return;
              }
              final messenger = ScaffoldMessenger.of(context);

              final data = <String, dynamic>{
                'policyDocId': selectedPolicyId,
                'customerId': selectedCustomerId,
                'customerName': selectedCustomerName,
                'customerMobile': selectedCustomerMobile,
                'policyName': selectedPolicyName,
                'policyCode': selectedPolicyCode,
                'claimType': claimTypeCtrl.text.trim(),
                'claimAmount':
                    double.tryParse(claimAmountCtrl.text.trim()) ?? 0,
                'requestedAt': Timestamp.fromDate(requestedAt),
                'claimStatus': 'Requested',
                'claimProgress': 10,
                'claimReference': claimRefCtrl.text.trim(),
                'claimNotes': claimNotesCtrl.text.trim(),
                if (claimNotesCtrl.text.trim().isNotEmpty)
                  'claimNotesLog': [
                    {
                      'note': claimNotesCtrl.text.trim(),
                      'status': 'Requested',
                      'progress': 10,
                      'reference': claimRefCtrl.text.trim(),
                      'createdAt': Timestamp.now(),
                      'createdBy': _employeeName,
                      'createdById': _employeeId,
                    },
                  ],
                'employeeId': _employeeId,
                'employeeName': _employeeName,
                'createdAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
              };

              final created = await FirebaseFirestore.instance
                  .collection('claims')
                  .add(data);
              await AuditLogService.write(
                page: 'Claims',
                action: 'Created Claim',
                description:
                    'Created claim request for $selectedCustomerName - $selectedPolicyName.',
                targetId: created.id,
                targetType: 'Claim',
                targetName: selectedCustomerName,
                extra: {
                  'customerName': selectedCustomerName,
                  'policyName': selectedPolicyName,
                },
              );

              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Claim request created successfully'),
                    backgroundColor: _primary,
                  ),
                );
              }
            }

            return AlertDialog(
              backgroundColor: _surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: const Text(
                'Request Claim',
                style: TextStyle(
                  color: _textMain,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              content: SizedBox(
                width: 820,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: searchCtrl,
                        onChanged: (_) => setS(() {}),
                        decoration: _inputDec(
                          'Search customer by name or mobile',
                        ),
                      ),
                      const SizedBox(height: 14),
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _customersStream(),
                        builder: (context, customerSnap) {
                          final activeCustomers = _activeCustomerKeys(
                            customerSnap.data?.docs ?? [],
                          );
                          return StreamBuilder<
                            QuerySnapshot<Map<String, dynamic>>
                          >(
                            stream: FirebaseFirestore.instance
                                .collection('customer_policies')
                                .snapshots(),
                            builder: (context, snap) {
                              final docs = snap.data?.docs ?? [];
                              final q = searchCtrl.text.toLowerCase().trim();
                              final filtered = docs.where((d) {
                                final data = d.data();
                                if (!_hasActiveCustomer(
                                      data,
                                      activeCustomers,
                                    ) ||
                                    !_belongsToCurrentUser(data)) {
                                  return false;
                                }
                                final name =
                                    (data['name'] ?? data['customerName'] ?? '')
                                        .toString()
                                        .toLowerCase();
                                final mobile =
                                    (data['contact'] ??
                                            data['customerMobile'] ??
                                            '')
                                        .toString()
                                        .toLowerCase();
                                return q.isEmpty ||
                                    name.contains(q) ||
                                    mobile.contains(q);
                              }).toList();

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Select Customer',
                                    style: TextStyle(
                                      color: _textMain,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  ...filtered.map((d) {
                                    final data = d.data();
                                    final customerId =
                                        (data['customerId'] ?? '').toString();
                                    final name =
                                        (data['name'] ??
                                                data['customerName'] ??
                                                '')
                                            .toString();
                                    final mobile =
                                        (data['contact'] ??
                                                data['customerMobile'] ??
                                                '')
                                            .toString();
                                    final policyName =
                                        (data['policyName'] ?? '').toString();
                                    final policyCode =
                                        (data['policyCode'] ?? '').toString();
                                    final isSelected = selectedPolicyId == d.id;

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? _primary.withOpacity(0.06)
                                            : _bg,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected
                                              ? _primary
                                              : _border,
                                        ),
                                      ),
                                      child: ListTile(
                                        onTap: () {
                                          setS(() {
                                            selectedPolicyId = d.id;
                                            selectedCustomerId = customerId;
                                            selectedCustomerName = name;
                                            selectedCustomerMobile = mobile;
                                            selectedPolicyName = policyName;
                                            selectedPolicyCode = policyCode;
                                          });
                                        },
                                        leading: CircleAvatar(
                                          backgroundColor: _primary.withOpacity(
                                            0.12,
                                          ),
                                          child: const Icon(
                                            Icons.person_outline_rounded,
                                            color: _primary,
                                          ),
                                        ),
                                        title: Text(
                                          name.isEmpty ? '-' : name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        subtitle: Text(
                                          '$mobile • $policyName • $policyCode',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        trailing: isSelected
                                            ? const Icon(
                                                Icons.check_circle_rounded,
                                                color: _approved,
                                              )
                                            : const Icon(
                                                Icons.arrow_forward_ios_rounded,
                                                size: 14,
                                              ),
                                      ),
                                    );
                                  }),
                                ],
                              );
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      if (selectedPolicyId.isNotEmpty) ...[
                        const Divider(height: 24),
                        const Text(
                          'Claim Request Details',
                          style: TextStyle(
                            color: _textMain,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: claimTypeCtrl,
                          decoration: _inputDec('Claim Type'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: claimAmountCtrl,
                          keyboardType: TextInputType.number,
                          decoration: _inputDec('Claim Amount'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: claimRefCtrl,
                          decoration: _inputDec('Claim Reference / Receipt No'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: claimNotesCtrl,
                          maxLines: 4,
                          decoration: _inputDec('Claim Notes'),
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: requestedAt,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setS(() => requestedAt = picked);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: _bg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _border),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today_outlined,
                                  size: 15,
                                  color: _textMuted,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Requested On: ${_fmt(requestedAt)}',
                                  style: const TextStyle(
                                    color: _textMain,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: selectedPolicyId.isEmpty ? null : saveRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  icon: const Icon(Icons.save_rounded, size: 16),
                  label: const Text('Save Request'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showClaimDetails(BuildContext context, Map<String, dynamic> claim) {
    final status = _statusText(claim);
    final color = _statusColor(status);
    final progress = _progressForClaim(claim);
    final notes = _claimNotes(claim);

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
          initialChildSize: 0.8,
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
                          'Claim Request',
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
                      color: color.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Text(
                          status,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '$progress%',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _detailCard([
                    _detailRow(
                      'Customer',
                      claim['customerName']?.toString() ?? '-',
                    ),
                    _detailRow(
                      'Mobile',
                      claim['customerMobile']?.toString() ?? '-',
                    ),
                    _detailRow(
                      'Policy Name',
                      claim['policyName']?.toString() ?? '-',
                    ),
                    _detailRow(
                      'Policy Code',
                      claim['policyCode']?.toString() ?? '-',
                    ),
                    _detailRow(
                      'Claim Type',
                      claim['claimType']?.toString() ?? '-',
                    ),
                    _detailRow('Amount', '₹${(claim['claimAmount'] ?? 0)}'),
                    _detailRow('Requested On', _fmt(claim['requestedAt'])),
                    _detailRow(
                      'Reference',
                      claim['claimReference']?.toString().isEmpty == true
                          ? '-'
                          : claim['claimReference'].toString(),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  _notesCard(notes),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showUpdateClaimDialog(context, claim);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.edit_note_rounded, size: 16),
                          label: const Text('Update Progress'),
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

  void _showUpdateClaimDialog(
    BuildContext context,
    Map<String, dynamic> claim,
  ) {
    final notesCtrl = TextEditingController();
    final refCtrl = TextEditingController(
      text: (claim['claimReference'] ?? '').toString(),
    );
    String status = (claim['claimStatus'] ?? 'Requested').toString();
    double progress = _progressForClaim(claim).toDouble();
    var saving = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setS) {
            return AlertDialog(
              backgroundColor: _surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Update Claim',
                style: TextStyle(color: _textMain, fontWeight: FontWeight.w800),
              ),
              content: SizedBox(
                width: 540,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: refCtrl,
                        decoration: _inputDec('Claim Reference / Receipt No'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: notesCtrl,
                        maxLines: 5,
                        decoration: _inputDec('Add New Progress Note'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: status,
                        decoration: _inputDec('Status'),
                        items: const [
                          DropdownMenuItem(
                            value: 'Requested',
                            child: Text('Requested'),
                          ),
                          DropdownMenuItem(
                            value: 'Under Review',
                            child: Text('Under Review'),
                          ),
                          DropdownMenuItem(
                            value: 'Approved',
                            child: Text('Approved'),
                          ),
                          DropdownMenuItem(
                            value: 'Rejected',
                            child: Text('Rejected'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setS(() {
                              status = v;
                              progress = _progressValue(v).toDouble();
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _bg,
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
                                    'Progress',
                                    style: TextStyle(
                                      color: _textMain,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${progress.round()}%',
                                  style: const TextStyle(
                                    color: _primary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                            Slider(
                              value: progress,
                              min: 0,
                              max: 100,
                              divisions: 20,
                              activeColor: _primary,
                              label: '${progress.round()}%',
                              onChanged: (v) => setS(() => progress = v),
                            ),
                          ],
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
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final claimId = (claim['id'] ?? '').toString();
                          if (claimId.isEmpty) return;
                          final messenger = ScaffoldMessenger.of(context);
                          setS(() => saving = true);
                          final note = notesCtrl.text.trim();
                          final update = <String, dynamic>{
                            'claimStatus': status,
                            'claimProgress': progress.round(),
                            'claimReference': refCtrl.text.trim(),
                            'updatedAt': FieldValue.serverTimestamp(),
                          };
                          if (note.isNotEmpty) {
                            final noteEntry = {
                              'note': note,
                              'status': status,
                              'progress': progress.round(),
                              'reference': refCtrl.text.trim(),
                              'createdAt': Timestamp.now(),
                              'createdBy': _employeeName,
                              'createdById': _employeeId,
                            };
                            update['claimNotes'] = note;
                            update['claimNotesLog'] = FieldValue.arrayUnion([
                              noteEntry,
                            ]);
                          }
                          await FirebaseFirestore.instance
                              .collection('claims')
                              .doc(claimId)
                              .set(update, SetOptions(merge: true));
                          await AuditLogService.write(
                            page: 'Claims',
                            action: 'Updated Claim',
                            description:
                                'Updated claim for ${claim['customerName'] ?? 'customer'} to $status (${progress.round()}%).',
                            targetId: claimId,
                            targetType: 'Claim',
                            targetName: (claim['customerName'] ?? '')
                                .toString(),
                            extra: {
                              'customerName': claim['customerName'],
                              'policyName': claim['policyName'],
                              'claimStatus': status,
                              'claimProgress': progress.round(),
                            },
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Claim updated successfully'),
                                backgroundColor: _primary,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(saving ? 'Saving...' : 'Save'),
                ),
              ],
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

  Widget _notesCard(List<Map<String, dynamic>> notes) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.notes_rounded, color: _primary, size: 18),
              SizedBox(width: 8),
              Text(
                'Progress Notes',
                style: TextStyle(
                  color: _textMain,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (notes.isEmpty)
            const Text(
              'No notes added yet.',
              style: TextStyle(color: _textMuted, fontSize: 12),
            )
          else
            ...notes.map((note) {
              final status = (note['status'] ?? 'Updated').toString();
              final color = _statusColor(status);
              final progress = note['progress'] is num
                  ? (note['progress'] as num).round()
                  : int.tryParse((note['progress'] ?? '').toString());
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _statusBg(status),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              color: color,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (progress != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            '$progress%',
                            style: const TextStyle(
                              color: _textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                        const Spacer(),
                        Text(
                          _fmt(note['createdAt']),
                          style: const TextStyle(
                            color: _textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      (note['note'] ?? '').toString().isEmpty
                          ? '-'
                          : note['note'].toString(),
                      style: const TextStyle(
                        color: _textMain,
                        fontSize: 12,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if ((note['createdBy'] ?? '').toString().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'By ${(note['createdBy'] ?? '').toString()}',
                        style: const TextStyle(
                          color: _textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
        ],
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
            child: Text(
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

  InputDecoration _inputDec(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _textMuted, fontSize: 13),
      filled: true,
      fillColor: _bg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _primary, width: 1.5),
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

class _Stat {
  final String label;
  final String value;
  final Color color;
  final Color bgColor;
  const _Stat(this.label, this.value, this.color, this.bgColor);
}
