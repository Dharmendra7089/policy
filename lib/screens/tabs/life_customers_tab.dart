import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../utils/commission_engine.dart';

import '../../utils/audit_log_service.dart';
import '../../utils/lead_status_guard.dart';
import '../../utils/lead_workflow_rules.dart';
import '../../utils/pdf_picker.dart';
import '../../utils/policy_serial_service.dart';
import '../../widgets/company_logo.dart';
import '../../widgets/customer_files_card.dart';

bool _policyMatchesCustomer(Map<String, dynamic> policy, String customerId) {
  final policyCustomerId = (policy['customerId'] ?? '').toString().trim();
  return policyCustomerId.isNotEmpty && policyCustomerId == customerId;
}

DateTime _linkedPolicySortDate(Map<String, dynamic> policy) {
  final value = policy['createdAt'] ?? policy['issueDate'];
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.fromMillisecondsSinceEpoch(0);
}

List<QueryDocumentSnapshot<Map<String, dynamic>>> _policiesForCustomer(
  Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> policies,
  String customerId,
  String category,
) {
  final normalizedCategory = category.toLowerCase();
  final matching = policies.where((policy) {
    final data = policy.data();
    return _policyMatchesCustomer(data, customerId) &&
        (data['category'] ?? '').toString().toLowerCase() == normalizedCategory;
  }).toList();
  matching.sort(
    (a, b) => _linkedPolicySortDate(
      b.data(),
    ).compareTo(_linkedPolicySortDate(a.data())),
  );
  return matching;
}

double _lifeNum(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse((value ?? '').toString().replaceAll(',', '').trim()) ??
      0;
}

DateTime? _lifeDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

int _lifePolicyYears(Map<String, dynamic> linkedPolicy) {
  final term = (linkedPolicy['policyTerm'] ?? '10 Years').toString();
  final match = RegExp(r'\d+').firstMatch(term);
  if (match != null) return int.parse(match.group(0)!);
  final start = _lifeDate(linkedPolicy['policyStartDate']);
  final end = _lifeDate(linkedPolicy['policyEndDate']);
  if (start == null || end == null) return 10;
  return ((end.difference(start).inDays + 1) / 365).round().clamp(1, 100);
}

Map<String, dynamic>? _lifeCommissionGroup(
  Map<String, dynamic> plan,
  Map<String, dynamic> linkedPolicy,
) {
  final groups = plan['lifeCommissions'];
  if (groups is! List || groups.isEmpty) return null;
  final effectiveDate =
      _lifeDate(linkedPolicy['issueDate']) ??
      _lifeDate(linkedPolicy['policyStartDate']) ??
      DateTime.now();
  for (final raw in groups) {
    if (raw is! Map) continue;
    final group = Map<String, dynamic>.from(raw);
    final start = _lifeDate(group['startDate']);
    final end = _lifeDate(group['endDate']);
    if (start != null &&
        end != null &&
        !effectiveDate.isBefore(start) &&
        !effectiveDate.isAfter(end)) {
      return group;
    }
  }
  return groups.last is Map
      ? Map<String, dynamic>.from(groups.last as Map)
      : null;
}

Map<String, dynamic> _withLiveLifeCommission(
  Map<String, dynamic> linkedPolicy,
  Map<String, dynamic>? plan,
) {
  if (plan == null) return linkedPolicy;
  if (plan['commissionRules'] is List) {
    final calculated = CommissionEngine.calculate(plan, linkedPolicy);
    return {
      ...linkedPolicy,
      'commissionPercent': calculated.percent,
      'commissionAmount': calculated.amount,
      'commissionRule': calculated.rule,
    };
  }
  final group = _lifeCommissionGroup(plan, linkedPolicy);
  final slabs = group?['slabs'];
  var percent = _lifeNum(
    plan['renewalCommission'] ?? plan['renewalCommissionPercent'],
  );
  var rule = 'Renewal Fallback';
  if (slabs is List && slabs.isNotEmpty && slabs.first is Map) {
    final slab = Map<String, dynamic>.from(slabs.first as Map);
    if ((slab['slabType'] ?? 'premium').toString() == 'term') {
      final years = _lifePolicyYears(linkedPolicy);
      final multiplier = _lifeNum(slab['multiplier']);
      percent = years * multiplier;
      rule = '$years years x ${multiplier.toStringAsFixed(2)}';
    } else {
      percent = _lifeNum(slab['percent']);
      rule = 'Premium Slab';
    }
  }
  final premium = _lifeNum(
    linkedPolicy['premiumAmount'] ?? linkedPolicy['premium'],
  );
  return {
    ...linkedPolicy,
    'commissionPercent': percent,
    'commissionAmount': premium * percent / 100,
    'commissionRule': rule,
  };
}

bool _allowsLinkedPolicyDisplay(Map<String, dynamic> customer) {
  return customer['policyLinkedManually'] != false;
}

bool _customerBelongsToCategory(
  Map<String, dynamic> customer,
  List<QueryDocumentSnapshot<Map<String, dynamic>>> linkedPolicies,
  Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> allPolicies,
  String customerId,
  String category,
) {
  if (linkedPolicies.isNotEmpty) return true;
  final savedCategory = (customer['customerCategory'] ?? '')
      .toString()
      .toLowerCase();
  if (savedCategory.isNotEmpty) return savedCategory == category.toLowerCase();
  final hasPolicyInAnotherCategory = allPolicies.any(
    (policy) => _policyMatchesCustomer(policy.data(), customerId),
  );
  if (hasPolicyInAnotherCategory) return false;
  return category.toLowerCase() == 'health';
}

String _safePdfFileName(String name) {
  final cleaned = name.trim().replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  if (cleaned.toLowerCase().endsWith('.pdf')) return cleaned;
  return cleaned.isEmpty ? 'policy.pdf' : '$cleaned.pdf';
}

Color _leadStatusColor(String status) {
  final value = status.toLowerCase();
  if (value == 'green') return const Color(0xFF16A34A);
  if (value == 'red') return const Color(0xFFDC2626);
  return const Color(0xFF2563EB);
}

Future<void> _openPdfUrl(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null ||
      !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Unable to open policy PDF.')));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// The selected policy PDF is read locally and mapped into form fields.
// ─────────────────────────────────────────────────────────────────────────────

class LifeCustomersTab extends StatefulWidget {
  final Map<String, dynamic>? currentUser;
  final String? initialCustomerId;
  final String title;
  final String initialView;
  final bool lockView;

  const LifeCustomersTab({
    super.key,
    this.currentUser,
    this.initialCustomerId,
    this.title = 'Life Customers',
    this.initialView = 'Leads',
    this.lockView = false,
  });

  @override
  State<LifeCustomersTab> createState() => _LifeCustomersTabState();
}

class _LifeCustomersTabState extends State<LifeCustomersTab> {
  static const _category = 'Life';
  // ── palette ────────────────────────────────────────────────────────────────
  static const _primary = Color(0xFF0D2D4F);
  static const _accent = Color(0xFF1A6EBD);
  static const _bg = Color(0xFFF4F6F9);
  static const _surface = Color(0xFFFFFFFF);
  static const _border = Color(0xFFE4E7EC);
  static const _textMain = Color(0xFF0D1B2A);
  static const _textMuted = Color(0xFF8A94A6);
  static const _red = Color(0xFFDC2626);
  static const _green = Color(0xFF16A34A);

  // ── state ──────────────────────────────────────────────────────────────────
  final _searchCtrl = TextEditingController();
  String _search = '';
  String _customerView = 'Leads';
  String _leadFilter = 'All';
  bool _openedInitialCustomer = false;
  QueryDocumentSnapshot<Map<String, dynamic>>? _selectedCustomer;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _policyLinksStream;

  @override
  void initState() {
    super.initState();
    _stream = FirebaseFirestore.instance
        .collection('customers')
        .orderBy('createdAt', descending: true)
        .snapshots();
    _policyLinksStream = FirebaseFirestore.instance
        .collection('customer_policies')
        .snapshots();
    _customerView = widget.initialView;
    if (widget.initialCustomerId != null) {
      _customerView = 'Policy Holders';
    }
    if (_isExecutive && _customerView == 'Leads') {
      _leadFilter = 'Green';
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── stream ─────────────────────────────────────────────────────────────────
  bool get _isAdmin =>
      (widget.currentUser?['role'] ?? 'admin').toString().toLowerCase() ==
      'admin';

  bool get _isExecutive =>
      (widget.currentUser?['role'] ?? '').toString().toLowerCase() ==
      'executive';

  String get _currentEmployeeId =>
      (widget.currentUser?['_profileDocId'] ?? widget.currentUser?['uid'] ?? '')
          .toString();

  String get _currentEmployeeName =>
      (widget.currentUser?['name'] ??
              widget.currentUser?['username'] ??
              widget.currentUser?['email'] ??
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

  // ── helpers ────────────────────────────────────────────────────────────────
  String _clean(TextEditingController c) => c.text.trim();
  bool _validEmail(String v) =>
      v.isEmpty || RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v);
  bool _validMobile(String v) => RegExp(r'^[6-9]\d{9}$').hasMatch(v);
  bool _validPan(String v) =>
      v.isEmpty || RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(v);
  bool _validAadhaar(String v) => v.isEmpty || RegExp(r'^\d{12}$').hasMatch(v);

  void _showError(String msg) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: _red));

  String _leadStatus(Map<String, dynamic> data) {
    final value = (data['leadStatus'] ?? 'Green').toString().toLowerCase();
    if (value == 'hot' || value == 'green') return 'Green';
    if (value == 'cold' || value == 'red') return 'Red';
    return 'Green';
  }

  void _openInitialCustomerIfNeeded(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final id = widget.initialCustomerId;
    if (_openedInitialCustomer || id == null || _selectedCustomer != null) {
      return;
    }
    final matches = docs.where((doc) => doc.id == id).toList();
    if (matches.isEmpty) return;
    _openedInitialCustomer = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _selectedCustomer = matches.first);
      }
    });
  }

  static const _sheetRows = [
    _LifeSheetRow(
      name: 'Shaik Mastan',
      policyNumber: '652802395',
      month: 'Feb-26',
      issuedDate: '13.03.2026',
      policyEndDate: '12.03.2027',
      sumAssured: 100000000,
      premium: 500195,
      phone: '9966250000',
      product: 'E Touch - Term',
    ),
    _LifeSheetRow(
      name: 'Shaik Mastan Vali',
      policyNumber: '654462902',
      month: 'Mar-26',
      issuedDate: '18.03.2026',
      policyEndDate: '17.03.2027',
      sumAssured: 2750000,
      premium: 250000,
      phone: '7731001493',
      product: 'ACE - Traditional',
    ),
    _LifeSheetRow(
      name: 'Sk Karima',
      policyNumber: '656204593',
      month: 'Mar-26',
      issuedDate: '31.03.2026',
      policyEndDate: '30.03.2027',
      sumAssured: 100000000,
      premium: 1093303,
      phone: '9666250000',
      product: 'Invest Protect Goal',
    ),
    _LifeSheetRow(
      name: 'H Phani',
      policyNumber: '6167308861',
      month: 'Mar-26',
      issuedDate: '31.03.2026',
      policyEndDate: '30.03.2027',
      sumAssured: 2250000,
      premium: 57196,
      phone: '9032401493',
      product: 'Invest Protect Goal',
    ),
    _LifeSheetRow(
      name: 'Dr Chandra Sekhar',
      policyNumber: '656418445',
      month: 'Mar-26',
      issuedDate: '31.03.2026',
      policyEndDate: '30.03.2027',
      sumAssured: 50000000,
      premium: 379642,
      phone: '9701551551',
      product: 'E Touch - Term',
    ),
    _LifeSheetRow(
      name: 'Dawar Abdul Kalam',
      policyNumber: '6167353657',
      month: 'Mar-26',
      issuedDate: '31.03.2026',
      policyEndDate: '30.03.2027',
      sumAssured: 1000000,
      premium: 100000,
      phone: '9966250000',
      product: 'Supreme_ULIP',
    ),
    _LifeSheetRow(
      name: 'Shaik Kismath',
      policyNumber: '6167353818',
      month: 'Mar-26',
      issuedDate: '31.03.2026',
      policyEndDate: '30.03.2027',
      sumAssured: 1000000,
      premium: 100000,
      phone: '9966250000',
      product: 'Supreme_ULIP',
    ),
    _LifeSheetRow(
      name: 'M Jyothi',
      policyNumber: '10000161734',
      month: 'Mar-26',
      issuedDate: '31.03.2026',
      policyEndDate: '30.03.2027',
      sumAssured: 250000,
      premium: 25000,
      phone: '9885118378',
      product: 'Goal Suraksha',
    ),
    _LifeSheetRow(
      name: 'Ch VLN Pranava Sai',
      policyNumber: '658440672',
      month: 'May-26',
      issuedDate: '10.05.2026',
      policyEndDate: '09.05.2027',
      sumAssured: 10000000,
      premium: 31555,
      phone: '8074756497',
      product: 'E Touch - Term',
    ),
    _LifeSheetRow(
      name: 'B Srinivasa Reddy',
      policyNumber: '658680570',
      month: 'May-26',
      issuedDate: '09.05.2026',
      policyEndDate: '08.05.2027',
      sumAssured: 5000000,
      premium: 50791,
      phone: '8520092969',
      product: 'E Touch - Term',
    ),
  ];

  String _normalizedProduct(String value) {
    final normalized = value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return normalized.contains('ulip') ? 'ulip' : normalized;
  }

  DateTime _sheetDate(String value) {
    final parts = value.split('.');
    return DateTime(
      int.parse(parts[2]),
      int.parse(parts[1]),
      int.parse(parts[0]),
    );
  }

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse((value ?? '').toString().replaceAll(',', '')) ?? 0;
  }

  int _policyYears(DateTime start, DateTime end, String term) {
    final specified = RegExp(r'\d+').firstMatch(term);
    if (specified != null) return int.parse(specified.group(0)!);
    final days = end.difference(start).inDays + 1;
    return (days / 365).round().clamp(1, 100);
  }

  double _lifePercentage(
    Map<String, dynamic> plan,
    DateTime start,
    DateTime end,
    String term,
  ) {
    final groups = plan['lifeCommissions'];
    if (groups is List && groups.isNotEmpty) {
      Map<String, dynamic>? chosen;
      for (final raw in groups) {
        if (raw is! Map) continue;
        final group = Map<String, dynamic>.from(raw);
        final from = group['startDate'] is Timestamp
            ? (group['startDate'] as Timestamp).toDate()
            : null;
        final to = group['endDate'] is Timestamp
            ? (group['endDate'] as Timestamp).toDate()
            : null;
        if (from != null &&
            to != null &&
            !start.isBefore(from) &&
            !start.isAfter(to)) {
          chosen = group;
          break;
        }
      }
      chosen ??= groups.last is Map
          ? Map<String, dynamic>.from(groups.last as Map)
          : null;
      final slabs = chosen?['slabs'];
      if (slabs is List && slabs.isNotEmpty && slabs.first is Map) {
        final slab = Map<String, dynamic>.from(slabs.first as Map);
        if ((slab['slabType'] ?? 'premium').toString() == 'term') {
          return _policyYears(start, end, term) * _number(slab['multiplier']);
        }
        return _number(slab['percent']);
      }
    }
    return _number(
      plan['renewalCommission'] ?? plan['renewalCommissionPercent'],
    );
  }

  Future<void> _importLifeSheetData(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import Life Customer Policies'),
        content: const Text(
          'Import the 10 supplied life-policy rows and link them to matching active Life plans? Existing policy numbers will be skipped.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final db = FirebaseFirestore.instance;
      final user = FirebaseAuth.instance.currentUser;
      final uid = user?.uid ?? '';
      final plansSnapshot = await db
          .collection('life_policies')
          .where('status', isEqualTo: 'Active')
          .get();
      final plans = <String, Map<String, dynamic>>{};
      for (final doc in plansSnapshot.docs) {
        final plan = {'id': doc.id, ...doc.data()};
        plans[_normalizedProduct((plan['planName'] ?? '').toString())] = plan;
      }

      final missingPlans = _sheetRows
          .where((row) => !plans.containsKey(_normalizedProduct(row.product)))
          .map((row) => row.product)
          .toSet()
          .toList();
      if (missingPlans.isNotEmpty) {
        _showError(
          'Missing active Life plans: ${missingPlans.join(', ')}. Add them in Life Policies first.',
        );
        return;
      }

      final existingSnapshot = await db
          .collection('customer_policies')
          .where('category', isEqualTo: _category)
          .get();
      final existingNumbers = existingSnapshot.docs
          .map((doc) => (doc.data()['policyNumber'] ?? '').toString())
          .toSet();

      final batch = db.batch();
      final employeeName = _currentEmployeeName;
      final employeeId = _currentEmployeeId;
      var added = 0;
      var skipped = 0;
      for (final row in _sheetRows) {
        if (existingNumbers.contains(row.policyNumber)) {
          skipped++;
          continue;
        }
        final matchingMobileCustomers = await db
            .collection('customers')
            .where('mobileNumber', isEqualTo: row.phone)
            .get();
        final matchingCustomers = matchingMobileCustomers.docs.where(
          (doc) =>
              (doc.data()['fullName'] ?? '').toString().trim().toLowerCase() ==
              row.name.toLowerCase(),
        );
        final existingCustomer = matchingCustomers.isEmpty
            ? null
            : matchingCustomers.first;
        final customerRef = existingCustomer != null
            ? existingCustomer.reference
            : db.collection('customers').doc();
        final plan = plans[_normalizedProduct(row.product)]!;
        final issued = _sheetDate(row.issuedDate);
        final ends = _sheetDate(row.policyEndDate);
        final commissionPercent = _lifePercentage(
          plan,
          issued,
          ends,
          '10 Years',
        );
        final commissionAmount = row.premium * commissionPercent / 100;
        final policyRef = db.collection('customer_policies').doc();
        final policySerial = await PolicySerialService.reserve(
          category: _category,
          policyId: policyRef.id,
          customerId: customerRef.id,
          customerName: row.name,
          firestore: db,
        );

        if (existingCustomer == null) {
          batch.set(customerRef, {
            'fullName': row.name,
            'mobileNumber': row.phone,
            'email': '',
            'address': '',
            'city': '',
            'state': '',
            'pincode': '',
            'dateOfBirth': '',
            'guardianName': '',
            'aadharNumber': '',
            'panNumber': '',
            'gender': '',
            'customerType': 'Individual',
            'maritalStatus': '',
            'status': 'Active',
            'employee': employeeName,
            'employeeName': employeeName,
            'employeeId': employeeId,
            'customerCategory': _category,
            'policyLinkedManually': true,
            'searchKey': '${row.name.toLowerCase()} ${row.phone}',
            'createdAt': FieldValue.serverTimestamp(),
            'createdBy': uid,
          });
        }

        final policyFields = <String, dynamic>{
          ...policySerial.toFirestoreFields(),
          'customerId': customerRef.id,
          'customerName': row.name,
          'customerMobile': row.phone,
          'policyPhone': row.phone,
          'policyId': plan['id'],
          'policyName': plan['planName'] ?? row.product,
          'policyCode': plan['policyCode'] ?? '',
          'policyNumber': row.policyNumber,
          'companyId': plan['companyId'] ?? '',
          'companyName': plan['companyName'] ?? '',
          'category': _category,
          'productName': row.product,
          'month': row.month,
          'issueDate': Timestamp.fromDate(issued),
          'issueDateFormatted': row.issuedDate,
          'policyStartDate': Timestamp.fromDate(issued),
          'policyEndDate': Timestamp.fromDate(ends),
          'policyEndDateFormatted': row.policyEndDate,
          'premiumAmount': row.premium,
          'sumInsured': row.sumAssured,
          'policyTerm': '10 Years',
          'commissionPercent': commissionPercent,
          'renewalCommissionPercent': commissionPercent,
          'commissionAmount': commissionAmount,
          'status': 'Active',
          'notes': 'Imported from supplied Life Customers sheet',
        };
        final revenueRef = db.collection('revenue').doc();
        final logRef = db.collection('logs').doc();
        batch.set(policyRef, {
          ...policyFields,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': uid,
          'createdByEmail': user?.email ?? '',
        });
        batch.set(customerRef, {
          ...policyFields,
          'employee': employeeName,
          'employeeName': employeeName,
          'employeeId': employeeId,
          'customerCategory': _category,
          'policyLinkedManually': true,
          'policyLinkedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': uid,
        }, SetOptions(merge: true));
        batch.set(revenueRef, {
          ...policyFields,
          'source': 'Life Policy Sheet Import',
          'revenue': commissionAmount,
          'monthKey': row.month,
          'year': issued.year,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': uid,
        });
        batch.set(logRef, {
          'page': 'Life Customers',
          'action': 'Imported Life Policy',
          'serialNumber': policySerial.serialNumber,
          'description':
              'Linked ${policySerial.serialNumber} ${row.product} (${row.policyNumber}) to ${row.name}',
          'performedBy': user?.email ?? uid,
          'performedByUid': uid,
          'targetId': customerRef.id,
          'timestamp': FieldValue.serverTimestamp(),
        });
        added++;
      }
      if (added > 0) await batch.commit();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Life policy import complete: $added linked, $skipped already existed.',
          ),
          backgroundColor: _primary,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Unable to import Life policies: $error'),
          backgroundColor: _red,
        ),
      );
    }
  }

  // ── build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_selectedCustomer != null) {
      return _CustomerDetailView(
        doc: _selectedCustomer!,
        category: _category,
        currentUser: widget.currentUser,
        onBack: () => setState(() => _selectedCustomer = null),
        onEdit: () => _showCustomerDialog(
          context,
          docId: _selectedCustomer!.id,
          existing: _selectedCustomer!.data(),
        ),
        onDeleted: () => setState(() => _selectedCustomer = null),
        onAddPolicy: () => _openLinkPolicyDialog(
          context,
          customerId: _selectedCustomer!.id,
          customerData: _selectedCustomer!.data(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
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
                    return Center(child: Text('Error: ${snap.error}'));
                  }
                  var docs = snap.data?.docs ?? [];
                  if (_search.isNotEmpty) {
                    docs = docs.where((d) {
                      final data = d.data();
                      return (data['fullName'] ?? '')
                              .toString()
                              .toLowerCase()
                              .contains(_search) ||
                          (data['mobileNumber'] ?? '')
                              .toString()
                              .toLowerCase()
                              .contains(_search);
                    }).toList();
                  }
                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _policyLinksStream,
                    builder: (context, policySnap) {
                      if (policySnap.hasError) {
                        return Center(
                          child: Text('Error: ${policySnap.error}'),
                        );
                      }
                      if (!policySnap.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(color: _accent),
                        );
                      }
                      final policies = policySnap.data?.docs ?? [];
                      final visibleDocs = docs.where((customer) {
                        if (!_belongsToCurrentEmployee(customer.data())) {
                          return false;
                        }
                        final linkedPolicies =
                            _allowsLinkedPolicyDisplay(customer.data())
                            ? _policiesForCustomer(
                                policies,
                                customer.id,
                                _category,
                              )
                            : <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                        if (!_customerBelongsToCategory(
                          customer.data(),
                          linkedPolicies,
                          policies,
                          customer.id,
                          _category,
                        )) {
                          return false;
                        }
                        final isPolicyHolder = linkedPolicies.isNotEmpty;
                        if (_customerView == 'Policy Holders') {
                          return isPolicyHolder;
                        }
                        if (isPolicyHolder) return false;
                        if (_leadFilter == 'All') return true;
                        return _leadStatus(customer.data()) == _leadFilter;
                      }).toList();
                      _openInitialCustomerIfNeeded(visibleDocs);
                      if (visibleDocs.isEmpty) return _buildEmpty(context);
                      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('life_policies')
                            .snapshots(),
                        builder: (context, lifePlanSnap) {
                          final plans = {
                            for (final plan in lifePlanSnap.data?.docs ?? [])
                              plan.id: plan.data(),
                          };
                          return SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: 960,
                              child: Column(
                                children: [
                                  const _CustomerListHeader(),
                                  Expanded(
                                    child: ListView.separated(
                                      itemCount: visibleDocs.length,
                                      separatorBuilder: (_, __) =>
                                          const SizedBox(height: 0),
                                      itemBuilder: (_, i) {
                                        final customer = visibleDocs[i];
                                        final linkedPolicies =
                                            _allowsLinkedPolicyDisplay(
                                              customer.data(),
                                            )
                                            ? _policiesForCustomer(
                                                policies,
                                                customer.id,
                                                _category,
                                              )
                                            : <
                                                QueryDocumentSnapshot<
                                                  Map<String, dynamic>
                                                >
                                              >[];
                                        final linked = linkedPolicies.isEmpty
                                            ? null
                                            : linkedPolicies.first.data();
                                        return _CustomerRow(
                                          doc: customer,
                                          linkedPolicy: linked,
                                          masterPolicy: linked == null
                                              ? null
                                              : plans[linked['policyId']
                                                    ?.toString()],
                                          onTap: () => setState(
                                            () => _selectedCustomer = customer,
                                          ),
                                        );
                                      },
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Container(
      color: _surface,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        color: _textMain,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Search by name or mobile',
                      style: TextStyle(color: _textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _importLifeSheetData(context),
                icon: const Icon(Icons.upload_file_rounded, size: 15),
                label: const Text(
                  'Import Life Sheet',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _accent,
                  side: const BorderSide(color: _accent),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () => _showCustomerDialog(context),
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 15),
                label: Text(
                  _customerView == 'Leads' ? 'Add Lead' : 'Add Customer',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
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
                    borderRadius: BorderRadius.circular(10),
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
              hintText: 'Search by name or mobile...',
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
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _accent, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (!widget.lockView)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['Leads', 'Policy Holders'].map((view) {
                final selected = _customerView == view;
                return ChoiceChip(
                  label: Text(view),
                  selected: selected,
                  selectedColor: _accent.withValues(alpha: 0.12),
                  onSelected: (_) => setState(() => _customerView = view),
                );
              }).toList(),
            ),
          if (_customerView == 'Leads') ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  (_isExecutive ? ['Green', 'Red'] : ['All', 'Green', 'Red'])
                      .map((status) {
                        final selected = _leadFilter == status;
                        return ChoiceChip(
                          label: Text('$status Leads'),
                          avatar: status == 'All'
                              ? null
                              : Icon(
                                  Icons.circle,
                                  size: 10,
                                  color: _leadStatusColor(status),
                                ),
                          selected: selected,
                          selectedColor: status == 'All'
                              ? _primary.withValues(alpha: 0.1)
                              : _leadStatusColor(
                                  status,
                                ).withValues(alpha: 0.14),
                          onSelected: (_) =>
                              setState(() => _leadFilter = status),
                        );
                      })
                      .toList(),
            ),
          ],
        ],
      ),
    );
  }

  // ── empty state ────────────────────────────────────────────────────────────
  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.people_outline_rounded,
              color: _primary,
              size: 30,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'No customers yet',
            style: TextStyle(
              color: _textMain,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Add your first customer to get started.',
            style: TextStyle(color: _textMuted, fontSize: 13),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: () => _showCustomerDialog(context),
            icon: const Icon(Icons.add_rounded, size: 15),
            label: Text(_customerView == 'Leads' ? 'Add Lead' : 'Add Customer'),
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
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // ADD / EDIT CUSTOMER DIALOG
  // ════════════════════════════════════════════════════════════════════════════
  Future<void> _showCustomerDialog(
    BuildContext context, {
    String? docId,
    Map<String, dynamic>? existing,
  }) async {
    final isEdit = docId != null;
    final messenger = ScaffoldMessenger.of(context);

    final fullName = TextEditingController(
      text: existing?['fullName']?.toString() ?? '',
    );
    final mobileNumber = TextEditingController(
      text: existing?['mobileNumber']?.toString() ?? '',
    );
    final email = TextEditingController(
      text: existing?['email']?.toString() ?? '',
    );
    final address = TextEditingController(
      text: existing?['address']?.toString() ?? '',
    );
    final city = TextEditingController(
      text: existing?['city']?.toString() ?? '',
    );
    final state = TextEditingController(
      text: existing?['state']?.toString() ?? '',
    );
    final pincode = TextEditingController(
      text: existing?['pincode']?.toString() ?? '',
    );
    final dob = TextEditingController(
      text: existing?['dateOfBirth']?.toString() ?? '',
    );
    final guardianName = TextEditingController(
      text: existing?['guardianName']?.toString() ?? '',
    );
    final aadhar = TextEditingController(
      text: existing?['aadharNumber']?.toString() ?? '',
    );
    final pan = TextEditingController(
      text: existing?['panNumber']?.toString() ?? '',
    );
    final employee = TextEditingController(
      text:
          (existing?['employeeName'] ?? existing?['employee'] ?? '')
              .toString()
              .isNotEmpty
          ? (existing?['employeeName'] ?? existing?['employee']).toString()
          : _currentEmployeeName,
    );

    String selectedGender = existing?['gender']?.toString() ?? 'Male';
    String selectedCustomerType =
        existing?['customerType']?.toString() ?? 'Individual';
    String selectedStatus = existing?['status']?.toString() ?? 'Active';
    String selectedMaritalStatus =
        existing?['maritalStatus']?.toString() ?? 'Single';
    bool isSaving = false;

    final genders = ['Male', 'Female', 'Other'];
    final customerTypes = ['Individual', 'Family', 'Corporate'];
    final statuses = ['Active', 'Inactive'];
    final maritalStatuses = ['Single', 'Married', 'Divorced', 'Widowed'];

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setS) {
            Future<void> pickDob() async {
              final initial =
                  DateTime.tryParse(dob.text) ?? DateTime(1995, 1, 1);
              final picked = await showDatePicker(
                context: context,
                firstDate: DateTime(1900),
                lastDate: DateTime.now(),
                initialDate: initial.isAfter(DateTime.now())
                    ? DateTime(1995, 1, 1)
                    : initial,
                helpText: 'Select Date of Birth',
                builder: (c, child) => Theme(
                  data: Theme.of(c).copyWith(
                    colorScheme: const ColorScheme.light(
                      primary: _primary,
                      onPrimary: Colors.white,
                      onSurface: _textMain,
                    ),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) {
                setS(
                  () => dob.text = picked.toIso8601String().split('T').first,
                );
              }
            }

            Future<void> save() async {
              final nameValue = _clean(fullName);
              final mobileValue = _clean(mobileNumber);
              final emailValue = _clean(email).toLowerCase();
              final panValue = _clean(pan).toUpperCase();
              final aadhaarValue = _clean(aadhar);
              final pincodeValue = _clean(pincode);

              if (nameValue.isEmpty || mobileValue.isEmpty) {
                _showError('Full name and mobile number are required.');
                return;
              }
              if (!_validMobile(mobileValue)) {
                _showError('Mobile must be a valid 10-digit Indian number.');
                return;
              }
              if (!_validEmail(emailValue)) {
                _showError('Enter a valid email address.');
                return;
              }
              if (!_validPan(panValue)) {
                _showError('PAN must be in the format ABCDE1234F.');
                return;
              }
              if (!_validAadhaar(aadhaarValue)) {
                _showError('Aadhaar must be 12 digits.');
                return;
              }
              if (pincodeValue.isNotEmpty &&
                  !RegExp(r'^\d{6}$').hasMatch(pincodeValue)) {
                _showError('Pincode must be 6 digits.');
                return;
              }

              setS(() => isSaving = true);
              try {
                final dup = await FirebaseFirestore.instance
                    .collection('customers')
                    .where('mobileNumber', isEqualTo: mobileValue)
                    .limit(1)
                    .get();
                if (dup.docs.isNotEmpty && dup.docs.first.id != docId) {
                  final existingData = dup.docs.first.data();
                  final existingName =
                      (existingData['fullName'] ?? 'Existing record')
                          .toString();
                  final existingCategory =
                      (existingData['customerCategory'] ?? 'Lead').toString();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Record available with this mobile: $existingName ($existingCategory). Saving new entry also.',
                      ),
                      backgroundColor: _accent,
                    ),
                  );
                }

                final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
                final existingEmployeeName =
                    (existing?['employeeName'] ?? existing?['employee'] ?? '')
                        .toString();
                final existingEmployeeId = (existing?['employeeId'] ?? '')
                    .toString();
                final employeeName = _isAdmin && existingEmployeeName.isNotEmpty
                    ? existingEmployeeName
                    : _currentEmployeeName;
                final employeeId = _isAdmin && existingEmployeeId.isNotEmpty
                    ? existingEmployeeId
                    : _currentEmployeeId;
                final data = <String, dynamic>{
                  'fullName': nameValue,
                  'mobileNumber': mobileValue,
                  'email': emailValue,
                  'address': _clean(address),
                  'city': _clean(city),
                  'state': _clean(state),
                  'pincode': pincodeValue,
                  'dateOfBirth': _clean(dob),
                  'guardianName': _clean(guardianName),
                  'aadharNumber': aadhaarValue,
                  'panNumber': panValue,
                  'gender': selectedGender,
                  'customerType': selectedCustomerType,
                  'maritalStatus': selectedMaritalStatus,
                  'status': selectedStatus,
                  'leadStatus': existing?['leadStatus'] ?? 'Green',
                  'employee': employeeName,
                  'employeeName': employeeName,
                  'employeeId': employeeId,
                  'searchKey':
                      '${nameValue.toLowerCase()} $mobileValue $emailValue $panValue $aadhaarValue',
                  'updatedAt': FieldValue.serverTimestamp(),
                  'updatedBy': uid,
                };

                if (isEdit) {
                  await FirebaseFirestore.instance
                      .collection('customers')
                      .doc(docId)
                      .update(data);
                  await AuditLogService.write(
                    page: 'Life Customers',
                    action: 'Updated Customer',
                    description: 'Updated customer "$nameValue".',
                    targetId: docId,
                    targetType: 'Customer',
                    targetName: nameValue,
                    extra: {'customerName': nameValue},
                  );
                } else {
                  data['createdAt'] = FieldValue.serverTimestamp();
                  data['createdBy'] = uid;
                  data['customerCategory'] = _category;
                  data['policyLinkedManually'] = false;
                  final created = await FirebaseFirestore.instance
                      .collection('customers')
                      .add(data);
                  await AuditLogService.write(
                    page: 'Life Customers',
                    action: 'Added Customer',
                    description: 'Added customer "$nameValue".',
                    targetId: created.id,
                    targetType: 'Customer',
                    targetName: nameValue,
                    extra: {'customerName': nameValue},
                  );
                }

                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        isEdit ? 'Customer updated' : 'Customer added',
                      ),
                      backgroundColor: _primary,
                    ),
                  );
                }
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

            return AlertDialog(
              backgroundColor: _surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
              contentPadding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
              title: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(
                      Icons.person_outline_rounded,
                      color: _primary,
                      size: 17,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isEdit
                        ? 'Edit Customer'
                        : _customerView == 'Leads'
                        ? 'Add Lead'
                        : 'Add Customer',
                    style: const TextStyle(
                      color: _textMain,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 640,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      _sectionLabel('Basic Details'),
                      _row2(
                        _tf('Full Name *', fullName),
                        _tf(
                          'Mobile Number *',
                          mobileNumber,
                          type: TextInputType.phone,
                        ),
                      ),
                      _row2(
                        _tf('Email', email, type: TextInputType.emailAddress),
                        _drop(
                          'Gender',
                          genders,
                          selectedGender,
                          (v) => setS(() => selectedGender = v!),
                        ),
                      ),
                      _row2(
                        _drop(
                          'Customer Type',
                          customerTypes,
                          selectedCustomerType,
                          (v) => setS(() => selectedCustomerType = v!),
                        ),
                        _drop(
                          'Status',
                          statuses,
                          selectedStatus,
                          (v) => setS(() => selectedStatus = v!),
                        ),
                      ),
                      _row2(
                        _drop(
                          'Marital Status',
                          maritalStatuses,
                          selectedMaritalStatus,
                          (v) => setS(() => selectedMaritalStatus = v!),
                        ),
                        _tf('Date of Birth', dob),
                      ),
                      _row2(
                        _tf('Employee', employee, readOnly: true),
                        const SizedBox.shrink(),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: pickDob,
                          icon: const Icon(
                            Icons.calendar_month_rounded,
                            size: 16,
                            color: _accent,
                          ),
                          label: const Text(
                            'Pick DOB from Calendar',
                            style: TextStyle(
                              color: _accent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _sectionLabel('Address'),
                      _tf('Address', address, maxLines: 2),
                      _row2(_tf('City', city), _tf('State', state)),
                      _row2(
                        _tf('Pincode', pincode, type: TextInputType.number),
                        _tf('Guardian Name', guardianName),
                      ),
                      _row2(
                        _tf(
                          'Aadhar Number',
                          aadhar,
                          type: TextInputType.number,
                        ),
                        _tf('PAN Number', pan),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: _textMuted),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: isSaving ? null : save,
                  icon: isSaving
                      ? const SizedBox(
                          width: 13,
                          height: 13,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_rounded, size: 15),
                  label: Text(
                    isSaving
                        ? 'Saving...'
                        : isEdit
                        ? 'Update'
                        : 'Save Customer',
                  ),
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
            );
          },
        );
      },
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // PDF EXTRACTION  ← NEW
  // ════════════════════════════════════════════════════════════════════════════

  // ── Web-native file picker ─────────────────────────────────────────────────
  /// Reads searchable PDF text locally and maps policy values into the
  /// selected customer category's add-policy form.
  Future<Map<String, String>?> _extractPdfFields(
    Uint8List pdfBytes,
    BuildContext ctx,
  ) async {
    PdfDocument? document;
    try {
      document = PdfDocument(inputBytes: pdfBytes);
      final text = PdfTextExtractor(document).extractText();
      if (text.trim().isNotEmpty) {
        final fields = _parseLifePolicyDocument(text);
        if (fields.isNotEmpty) return fields;
        if (ctx.mounted) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            const SnackBar(
              content: Text(
                'No supported policy fields found in this PDF. Please enter details manually.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return null;
      }

      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(
            content: Text(
              'No readable text found in this PDF. Please enter details manually.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return null;
    } catch (_) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to read this PDF. Please enter policy details manually.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return null;
    } finally {
      document?.dispose();
    }
  }

  Map<String, String> _parseSbiHealthProposal(String source) {
    final text = source.replaceAll(RegExp(r'\s+'), ' ').trim();
    final fields = <String, String>{};

    String find(RegExp pattern, {int group = 1}) =>
        pattern.firstMatch(text)?.group(group)?.trim() ?? '';

    void add(String key, String value) {
      final cleaned = value.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (cleaned.isNotEmpty) fields[key] = cleaned;
    }

    String date(String value) => value.replaceAll(RegExp(r'\s+'), '');

    if (text.contains('SBI General Insurance Company Limited')) {
      fields['companyName'] = 'SBI General Insurance Company Limited';
    }
    if (text.contains('SBI General Health Alpha')) {
      fields['productName'] = 'SBI General Health Alpha';
      fields['planName'] = 'Health Alpha';
    }

    add(
      'branchCode',
      find(RegExp(r'Branch office Code:\s*(\S+)', caseSensitive: false)),
    );
    add(
      'intermediaryName',
      find(
        RegExp(
          r'Intermediary Name\s+(.+?)\s+Intermediary Code',
          caseSensitive: false,
        ),
      ),
    );
    add(
      'intermediaryCode',
      find(RegExp(r'Intermediary Code\s+(\S+)', caseSensitive: false)),
    );
    add('urn', find(RegExp(r'URN:\s*(\S+)', caseSensitive: false)));
    add(
      'proposerName',
      find(
        RegExp(
          r'Name of the Proposer\*?\s+(.+?)\s+Present Address',
          caseSensitive: false,
        ),
      ),
    );
    add(
      'proposerPan',
      find(RegExp(r'PAN No\.\s*\*?\s+(\S+)', caseSensitive: false)),
    );
    add(
      'proposerMobile',
      find(RegExp(r'Mobile No\.\s+(\d{10})', caseSensitive: false)),
    );
    add(
      'proposerEmail',
      find(RegExp(r'Email ID\s*\*?:\s*(\S+)', caseSensitive: false)),
    );
    add(
      'proposerDob',
      find(
        RegExp(r'Date of Birth\*?\s+(\d{2}/\d{2}/\d{4})', caseSensitive: false),
      ),
    );
    add(
      'proposerGender',
      find(RegExp(r'Gender\*?\s+(Male|Female|Other)', caseSensitive: false)),
    );
    add(
      'maritalStatus',
      find(RegExp(r'Marital Status\*?\s+(\w+)', caseSensitive: false)),
    );
    add(
      'profession',
      find(
        RegExp(
          r'Profession\*?:\s*(.+?)\s+Occupation and Nature',
          caseSensitive: false,
        ),
      ),
    );
    add(
      'annualIncome',
      find(RegExp(r'Annual Gross Income:\s*([\d,]+)', caseSensitive: false)),
    );
    add(
      'policyType',
      find(
        RegExp(r'Policy Type\*?\s+(.+?)\s+Policy Term', caseSensitive: false),
      ),
    );
    add(
      'policyTerm',
      find(
        RegExp(r'Policy Term\*?\s+(.+?)\s+Plan Opted', caseSensitive: false),
      ),
    );
    if (!fields.containsKey('planName')) {
      add(
        'planName',
        find(
          RegExp(
            r'Plan Opted:\s*(.+?)\s+(?:SBI General|Period of Insurance)',
            caseSensitive: false,
          ),
        ),
      );
    }

    final insurancePeriod = RegExp(
      r'Period of Insurance\*?:?\s*From\s+(\d{4}-\d{2}-\s*\d{2}T[\d:]+)\s+To\s+(\d{4}-\d{2}-\s*\d{2}T[\d:]+)',
      caseSensitive: false,
    ).firstMatch(text);
    if (insurancePeriod != null) {
      final start = date(insurancePeriod.group(1)!);
      fields['issueDate'] = start;
      fields['policyStartDate'] = start;
      fields['policyEndDate'] = date(insurancePeriod.group(2)!);
    }

    add(
      'premiumAmount',
      find(RegExp(r'Amount for\s*[^\d]*([\d,]+)', caseSensitive: false)),
    );
    add(
      'sumInsured',
      find(
        RegExp(
          r'Hospitalization Cover\s+Sum Insured\s+[^\d]*([\d,]+)',
          caseSensitive: false,
        ),
      ),
    );
    add(
      'preHospDays',
      find(
        RegExp(
          r'Pre\s*-\s*Hospitalization\s+(\d+\s+Days)',
          caseSensitive: false,
        ),
      ),
    );
    add(
      'postHospDays',
      find(
        RegExp(
          r'Post\s*-\s*Hospitalization\s+(\d+\s+Days)',
          caseSensitive: false,
        ),
      ),
    );
    add(
      'cumBonus',
      find(
        RegExp(
          r'Cumulative Bonus\s+(.+?)\s+Optional Covers',
          caseSensitive: false,
        ),
      ),
    );
    add(
      'roadAmbulanceLimit',
      find(
        RegExp(
          r'Road Ambulance\s*\(per hospitalization\)\s+[^\d]*([\d,]+)',
          caseSensitive: false,
        ),
      ),
    );
    add(
      'radioCabLimit',
      find(
        RegExp(
          r'Radio Cab\s*\(per hospitalization\)\s+[^\d]*([\d,]+)',
          caseSensitive: false,
        ),
      ),
    );
    add(
      'convalescenceLimit',
      find(RegExp(r'Convalescence\s+[^\d]*([\d,]+)', caseSensitive: false)),
    );
    add(
      'roomRentLimit',
      find(
        RegExp(
          r'Reduction in Room Rent Limits\s+(.+?)\s+Reduction in Specific',
          caseSensitive: false,
        ),
      ),
    );
    add(
      'specificWaitingPeriod',
      find(
        RegExp(
          r'Reduction in Specific Waiting Period\s+(.+?)\s+Change in PED',
          caseSensitive: false,
        ),
      ),
    );
    add(
      'pedWaitingPeriod',
      find(
        RegExp(
          r'Change in PED Waiting Period\s+(\d+\s+Months)',
          caseSensitive: false,
        ),
      ),
    );

    final insuredMatches = RegExp(
      r'Insured\s+([1-4])\s+(.+?)\s+(\d{2}/\d{2}/\d{4})\s+(Male|Female|Other)\b',
      caseSensitive: false,
    ).allMatches(text);
    for (final member in insuredMatches) {
      final number = member.group(1)!;
      add('insured${number}Name', member.group(2)!);
      add('insured${number}Dob', member.group(3)!);
      add('insured${number}Gender', member.group(4)!);
    }

    final nominee = RegExp(
      r'Nominee Details\*?.+?Address of the Nominee\s+(.+?)\s+100\s+\d{4}-\d{2}-\d{2}\s+(?:Male|Female|Other)\s+(\w+)',
      caseSensitive: false,
    ).firstMatch(text);
    if (nominee != null) {
      var name = nominee.group(1)!.trim();
      final proposerName = fields['proposerName'] ?? '';
      if (proposerName.isNotEmpty &&
          name.toLowerCase().startsWith(proposerName.toLowerCase())) {
        name = name.substring(proposerName.length).trim();
      }
      add('nomineeName', name);
      add('nomineeRelationship', nominee.group(2)!);
    }

    return fields;
  }

  Map<String, String> _parseLifePolicyDocument(String source) {
    final text = source.replaceAll(RegExp(r'\s+'), ' ').trim();
    final fields = <String, String>{'category': 'Life'};

    String first(Iterable<RegExp> patterns, {int group = 1}) {
      for (final pattern in patterns) {
        final value = pattern.firstMatch(text)?.group(group)?.trim() ?? '';
        if (value.isNotEmpty) return value;
      }
      return '';
    }

    String lineValue(Iterable<String> labels) {
      for (final line in source.split(RegExp(r'[\r\n]+'))) {
        for (final label in labels) {
          final match = RegExp(
            '^\\s*${RegExp.escape(label)}\\s*[:\\-]?\\s*(.+?)\\s*\$',
            caseSensitive: false,
          ).firstMatch(line);
          if (match != null) return match.group(1)!.trim();
        }
      }
      return '';
    }

    void add(String key, String value) {
      final cleaned = value
          .replaceAll(RegExp(r'\s+'), ' ')
          .replaceAll(RegExp(r'^(?:Rs\.?|INR|₹)\s*', caseSensitive: false), '')
          .trim();
      if (cleaned.isNotEmpty) fields[key] = cleaned;
    }

    final policyNumber = first([
      RegExp(
        r'(?:Policy\s*(?:No\.?|Number)|Policy\s*#)\s*[:\-]?\s*([A-Z0-9\/\-]{5,})',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:Certificate\s*(?:No\.?|Number))\s*[:\-]?\s*([A-Z0-9\/\-]{5,})',
        caseSensitive: false,
      ),
    ]);
    add('policyNumber', policyNumber);
    add(
      'sumInsured',
      first([
        RegExp(
          r'(?:Sum\s+Assured|Basic\s+Sum\s+Assured|Death\s+Benefit|Sum\s+Insured)\s*[:\-]?\s*(?:Rs\.?|INR|₹)?\s*([\d,]+(?:\.\d+)?)',
          caseSensitive: false,
        ),
      ]),
    );
    add(
      'premiumAmount',
      first([
        RegExp(
          r'(?:Premium(?:\s+Amount)?|Annual\s+Premium|Total\s+Premium)\s*[:\-]?\s*(?:Rs\.?|INR|₹)?\s*([\d,]+(?:\.\d+)?)',
          caseSensitive: false,
        ),
      ]),
    );
    add(
      'proposerMobile',
      first([
        RegExp(
          r'(?:Phone\s*No\.?|Mobile\s*(?:No\.?|Number)|Contact\s*(?:No\.?|Number))\s*[:\-]?\s*(?:\+91[\s-]?)?([6-9]\d{9})',
          caseSensitive: false,
        ),
      ]),
    );

    final holderName = lineValue([
      'Name of the Person',
      'Life Assured Name',
      'Customer Name',
      'Proposer Name',
    ]);
    add('proposerName', holderName);

    String product = lineValue([
      'Product',
      'Product Name',
      'Plan Name',
      'Plan',
    ]);
    const knownProducts = [
      'E Touch - Term',
      'ACE - Traditional',
      'Invest Protect Goal',
      'Supreme_ULIP',
      'Supreme ULIP',
      'Goal Suraksha',
    ];
    if (product.isEmpty) {
      for (final knownProduct in knownProducts) {
        if (text.toLowerCase().contains(knownProduct.toLowerCase())) {
          product = knownProduct;
          break;
        }
      }
    }
    if (product.isEmpty) {
      product = first([
        RegExp(
          r'(?:Product|Plan(?:\s+Name)?)\s*[:\-]\s*(.+?)(?=\s+(?:Policy|Premium|Sum\s+Assured|UIN|Phone|Mobile|Issued|Issue|Start|End|$))',
          caseSensitive: false,
        ),
      ]);
    }
    add('productName', product);
    add('planName', product);

    final issueDate = first([
      RegExp(
        r'(?:Issued?\s*Date|Date\s+of\s+Issue|Policy\s+Start\s+Date|Commencement\s+Date|Risk\s+Commencement\s+Date)\s*[:\-]?\s*(\d{1,2}[./-]\d{1,2}[./-]\d{4}|\d{4}[./-]\d{1,2}[./-]\d{1,2})',
        caseSensitive: false,
      ),
    ]);
    final policyEndDate = first([
      RegExp(
        r'(?:Policy\s+End\s+Date|End\s+Date|Maturity\s+Date|Expiry\s+Date)\s*[:\-]?\s*(\d{1,2}[./-]\d{1,2}[./-]\d{4}|\d{4}[./-]\d{1,2}[./-]\d{1,2})',
        caseSensitive: false,
      ),
    ]);
    add('issueDate', issueDate);
    add('policyStartDate', issueDate);
    add('policyEndDate', policyEndDate);
    add(
      'policyTerm',
      first([
        RegExp(
          r'(?:Policy\s+Term|Term)\s*[:\-]?\s*([0-9]+\s*(?:Year|Years|Yr|Yrs))',
          caseSensitive: false,
        ),
      ]),
    );
    add('nomineeName', lineValue(['Nominee Name', 'Name of Nominee']));
    add(
      'nomineeRelationship',
      lineValue(['Nominee Relationship', 'Relationship with Nominee']),
    );

    return fields;
  }

  // ════════════════════════════════════════════════════════════════════════════
  // LINK POLICY DIALOG  (updated with PDF upload + auto-prefill)
  // ════════════════════════════════════════════════════════════════════════════
  Future<void> _openLinkPolicyDialog(
    BuildContext context, {
    required String customerId,
    required Map<String, dynamic> customerData,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final customerName = customerData['fullName']?.toString() ?? '';
    final customerMobile = customerData['mobileNumber']?.toString() ?? '';
    const isHealthCategory = false;

    // ── load active policies ────────────────────────────────────────────────
    final policySnap = await FirebaseFirestore.instance
        .collection('life_policies')
        .where('status', isEqualTo: 'Active')
        .get();

    final uniquePolicies = <String, Map<String, dynamic>>{};
    for (final d in policySnap.docs) {
      final id = d.id.trim();
      if (id.isEmpty) continue;
      uniquePolicies[id] = {'id': id, ...d.data()};
    }

    final allPolicies = uniquePolicies.values.toList()
      ..removeWhere(
        (policy) =>
            (policy['category'] ?? '').toString().toLowerCase() !=
            _category.toLowerCase(),
      )
      ..sort(
        (a, b) => (a['planName'] ?? '').toString().toLowerCase().compareTo(
          (b['planName'] ?? '').toString().toLowerCase(),
        ),
      );

    if (!context.mounted) return;

    // ── controllers ─────────────────────────────────────────────────────────
    String? selectedPolicyId;
    Map<String, dynamic>? selectedPolicy;

    final premiumCtrl = TextEditingController();
    final sumInsuredCtrl = TextEditingController();
    final policyNumberCtrl = TextEditingController();
    final productNameCtrl = TextEditingController();
    final policyPhoneCtrl = TextEditingController(text: customerMobile);
    final notesCtrl = TextEditingController();

    // Extra PDF-sourced info controllers
    final urnCtrl = TextEditingController();
    final branchCodeCtrl = TextEditingController();
    final intermediaryNameCtrl = TextEditingController();
    final intermediaryCodeCtrl = TextEditingController();
    final policyTypeCtrl = TextEditingController();
    final policyTermCtrl = TextEditingController(text: '10 Years');
    final professionCtrl = TextEditingController();
    final annualIncomeCtrl = TextEditingController();
    final nomineeNameCtrl = TextEditingController();
    final nomineeRelCtrl = TextEditingController();

    // Insured members (up to 4)
    final insuredControllers = List.generate(
      4,
      (_) => {
        'name': TextEditingController(),
        'dob': TextEditingController(),
        'gender': TextEditingController(),
      },
    );

    // Coverage details controllers
    final roadAmbCtrl = TextEditingController();
    final radioCabCtrl = TextEditingController();
    final convalCtrl = TextEditingController();
    final cumBonusCtrl = TextEditingController();
    final preHospCtrl = TextEditingController();
    final postHospCtrl = TextEditingController();
    final roomRentCtrl = TextEditingController();
    final specWaitCtrl = TextEditingController();
    final pedWaitCtrl = TextEditingController();

    DateTime? issueDate;
    DateTime? policyStartDate;
    DateTime? policyEndDate;
    double commissionPercent = 0;

    // PDF state
    String? _uploadedFileName;
    Uint8List? selectedPdfBytes;
    String? selectedPdfName;
    bool _isExtracting = false;
    String? _extractionStatus; // "success" | "failed" | null

    // ── helpers ──────────────────────────────────────────────────────────────
    Future<DateTime?> pickDate(
      BuildContext ctx, {
      required DateTime initial,
      required String helpText,
    }) {
      return showDatePicker(
        context: ctx,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        initialDate: initial,
        helpText: helpText,
        builder: (c, child) => Theme(
          data: Theme.of(
            c,
          ).copyWith(colorScheme: const ColorScheme.light(primary: _primary)),
          child: child!,
        ),
      );
    }

    double parseNum(String v) =>
        double.tryParse(v.replaceAll(',', '').trim()) ?? 0;

    String fmtDate(DateTime? d) {
      if (d == null) return '';
      return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
    }

    String buildMonthKey(DateTime? d) {
      if (d == null) return '';
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final yy = d.year.toString().substring(2);
      return '${months[d.month - 1]}-$yy';
    }

    DateTime calcPolicyEndDate(DateTime start, int months) {
      int m = start.month + months;
      int y = start.year + (m - 1) ~/ 12;
      m = ((m - 1) % 12) + 1;
      return DateTime(y, m, start.day);
    }

    double getPolicyRenewalCommissionPercent(Map<String, dynamic> p) {
      final v = p['renewalCommission'] ?? p['renewalCommissionPercent'] ?? 0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }

    // ────────────────────────────────────────────────────────────────────────
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool isSaving = false;

        return StatefulBuilder(
          builder: (ctx, setS) {
            final premium = parseNum(premiumCtrl.text);
            final commissionAmount = (premium * commissionPercent) / 100;
            final validSelectedId =
                (selectedPolicyId != null &&
                    allPolicies.any(
                      (p) => p['id'].toString() == selectedPolicyId,
                    ))
                ? selectedPolicyId
                : null;

            // ── commission recompute ────────────────────────────────────────
            void recomputeCommission() {
              if (selectedPolicy == null) return;
              final category =
                  selectedPolicy!['category']?.toString().toLowerCase() ?? '';
              if (category == 'life') {
                final start = policyStartDate ?? issueDate ?? DateTime.now();
                final end = policyEndDate ?? calcPolicyEndDate(start, 12);
                setS(
                  () => commissionPercent = _lifePercentage(
                    selectedPolicy!,
                    start,
                    end,
                    policyTermCtrl.text,
                  ),
                );
                return;
              }
              if (category == 'health') {
                final groups = selectedPolicy!['healthCommissions'];
                if (groups is List && groups.isNotEmpty) {
                  final now = DateTime.now();
                  Map? activeGroup;
                  for (final g in groups) {
                    if (g is! Map) continue;
                    final start = g['startDate'] is Timestamp
                        ? (g['startDate'] as Timestamp).toDate()
                        : null;
                    final end = g['endDate'] is Timestamp
                        ? (g['endDate'] as Timestamp).toDate()
                        : null;
                    if (start != null &&
                        end != null &&
                        !now.isBefore(start) &&
                        !now.isAfter(end)) {
                      activeGroup = g;
                      break;
                    }
                  }
                  activeGroup ??= groups.last is Map ? groups.last : null;

                  if (activeGroup != null) {
                    final type =
                        activeGroup['type']?.toString() ?? 'sumInsured';
                    final slabs = activeGroup['slabs'];
                    if (slabs is List) {
                      final compareValue = type == 'sumInsured'
                          ? parseNum(sumInsuredCtrl.text)
                          : premium;
                      for (final s in slabs) {
                        if (s is! Map) continue;
                        final from =
                            double.tryParse(
                              s['fromAmount']?.toString() ?? '0',
                            ) ??
                            0;
                        final to = s['toAmount'] == null
                            ? double.infinity
                            : double.tryParse(
                                    s['toAmount']?.toString() ?? '',
                                  ) ??
                                  double.infinity;
                        final pct =
                            double.tryParse(s['percent']?.toString() ?? '0') ??
                            0;
                        if (compareValue >= from && compareValue <= to) {
                          setS(() => commissionPercent = pct);
                          return;
                        }
                      }
                    }
                  }
                }
              }
              setS(
                () => commissionPercent = getPolicyRenewalCommissionPercent(
                  selectedPolicy!,
                ),
              );
            }

            // ── PDF pick & extract ──────────────────────────────────────────
            Future<void> pickAndExtractPdf() async {
              ({Uint8List bytes, String name})? picked;
              try {
                picked = await pickPdfBytes();
              } catch (_) {
                if (!ctx.mounted) return;
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Unable to load the selected PDF. Please select it again.',
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              if (picked == null) return;
              final selectedPdf = picked;

              final extractionStarted = DateTime.now();
              setS(() {
                _uploadedFileName = selectedPdf.name;
                selectedPdfBytes = selectedPdf.bytes;
                selectedPdfName = selectedPdf.name;
                _isExtracting = true;
                _extractionStatus = null;
              });

              // Paint the processing panel before local PDF parsing begins.
              await WidgetsBinding.instance.endOfFrame;
              if (!ctx.mounted) return;

              final fields = await _extractPdfFields(selectedPdf.bytes, ctx);

              final visibleFor = DateTime.now().difference(extractionStarted);
              const minVisibleTime = Duration(milliseconds: 1200);
              if (visibleFor < minVisibleTime) {
                await Future<void>.delayed(minVisibleTime - visibleFor);
              }
              if (!ctx.mounted) return;

              if (fields == null) {
                setS(() {
                  _isExtracting = false;
                  _extractionStatus = 'failed';
                });
                return;
              }

              // ── prefill all available fields ──────────────────────────────
              setS(() {
                _isExtracting = false;
                _extractionStatus = 'success';

                void fill(TextEditingController c, String key) {
                  if ((fields[key] ?? '').isNotEmpty) c.text = fields[key]!;
                }

                fill(policyNumberCtrl, 'policyNumber');
                fill(productNameCtrl, 'productName');
                fill(policyPhoneCtrl, 'proposerMobile');
                fill(premiumCtrl, 'premiumAmount');
                fill(sumInsuredCtrl, 'sumInsured');
                fill(urnCtrl, 'urn');
                fill(branchCodeCtrl, 'branchCode');
                fill(intermediaryNameCtrl, 'intermediaryName');
                fill(intermediaryCodeCtrl, 'intermediaryCode');
                fill(policyTypeCtrl, 'policyType');
                fill(policyTermCtrl, 'policyTerm');
                fill(professionCtrl, 'profession');
                fill(annualIncomeCtrl, 'annualIncome');
                fill(nomineeNameCtrl, 'nomineeName');
                fill(nomineeRelCtrl, 'nomineeRelationship');

                // Coverage fields
                fill(roadAmbCtrl, 'roadAmbulanceLimit');
                fill(radioCabCtrl, 'radioCabLimit');
                fill(convalCtrl, 'convalescenceLimit');
                fill(cumBonusCtrl, 'cumBonus');
                fill(preHospCtrl, 'preHospDays');
                fill(postHospCtrl, 'postHospDays');
                fill(roomRentCtrl, 'roomRentLimit');
                fill(specWaitCtrl, 'specificWaitingPeriod');
                fill(pedWaitCtrl, 'pedWaitingPeriod');

                // Insured members
                final keys = [
                  ['insured1Name', 'insured1Dob', 'insured1Gender'],
                  ['insured2Name', 'insured2Dob', 'insured2Gender'],
                  ['insured3Name', 'insured3Dob', 'insured3Gender'],
                  ['insured4Name', 'insured4Dob', 'insured4Gender'],
                ];
                for (int i = 0; i < 4; i++) {
                  fill(insuredControllers[i]['name']!, keys[i][0]);
                  fill(insuredControllers[i]['dob']!, keys[i][1]);
                  fill(insuredControllers[i]['gender']!, keys[i][2]);
                }

                // Dates
                DateTime? tryParseDate(String? raw) {
                  if (raw == null || raw.isEmpty) return null;
                  // try ISO first
                  final iso = DateTime.tryParse(raw);
                  if (iso != null) return iso;
                  // try dd/MM/yyyy
                  final parts = raw.split(RegExp(r'[/\-\.]'));
                  if (parts.length == 3) {
                    final d = int.tryParse(parts[0]);
                    final m = int.tryParse(parts[1]);
                    final y = int.tryParse(parts[2]);
                    if (d != null && m != null && y != null) {
                      return DateTime(y, m, d);
                    }
                  }
                  return null;
                }

                final parsedIssue = tryParseDate(fields['issueDate']);
                final parsedStart = tryParseDate(fields['policyStartDate']);
                final parsedEnd = tryParseDate(fields['policyEndDate']);

                if (parsedIssue != null) issueDate = parsedIssue;
                if (parsedStart != null) policyStartDate = parsedStart;
                if (parsedEnd != null) policyEndDate = parsedEnd;

                // If start is set but end is not, default to +1 year
                if (policyStartDate != null && policyEndDate == null) {
                  policyEndDate = calcPolicyEndDate(policyStartDate!, 12);
                }

                // Auto-match policy by plan name / company name from PDF
                if (selectedPolicyId == null) {
                  final pdfPlan = (fields['planName'] ?? '').toLowerCase();
                  final pdfCompany = (fields['companyName'] ?? '')
                      .toLowerCase();
                  String comparable(String value) =>
                      value.replaceAll(RegExp(r'[^a-z0-9]'), '');
                  for (final p in allPolicies) {
                    final savedPlan = (p['planName'] ?? '')
                        .toString()
                        .toLowerCase();
                    final compactPdfPlan = comparable(pdfPlan);
                    final compactSavedPlan = comparable(savedPlan);
                    final planMatch =
                        pdfPlan.isNotEmpty &&
                        (savedPlan.contains(pdfPlan) ||
                            pdfPlan.contains(savedPlan) ||
                            (compactPdfPlan.isNotEmpty &&
                                (compactSavedPlan.contains(compactPdfPlan) ||
                                    compactPdfPlan.contains(
                                      compactSavedPlan,
                                    ))));
                    final compMatch =
                        pdfCompany.isNotEmpty &&
                        (p['companyName'] ?? '')
                            .toString()
                            .toLowerCase()
                            .contains(pdfCompany);
                    if (planMatch || compMatch) {
                      selectedPolicyId = p['id'].toString();
                      selectedPolicy = p;
                      if (productNameCtrl.text.isEmpty) {
                        productNameCtrl.text = p['planName']?.toString() ?? '';
                      }
                      break;
                    }
                  }
                }

                recomputeCommission();
              });
            }

            // ── save ──────────────────────────────────────────────────────
            Future<void> saveLink() async {
              if (validSelectedId == null || selectedPolicy == null) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Please select a policy'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              if (policyNumberCtrl.text.trim().isEmpty) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Please enter policy number'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              if (premiumCtrl.text.trim().isEmpty ||
                  parseNum(premiumCtrl.text) <= 0) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Please enter valid premium amount'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              if (sumInsuredCtrl.text.trim().isEmpty ||
                  parseNum(sumInsuredCtrl.text) <= 0) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Please enter valid sum insured'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              if (issueDate == null ||
                  policyStartDate == null ||
                  policyEndDate == null) {
                _showError(
                  'Issued date, active date and expiry date are required.',
                );
                return;
              }
              if (policyEndDate!.isBefore(policyStartDate!)) {
                _showError('Policy expiry date cannot be before active date.');
                return;
              }
              if (issueDate!.isAfter(policyStartDate!)) {
                _showError('Issued date cannot be after active date.');
                return;
              }

              setS(() => isSaving = true);
              try {
                final policyNumber = policyNumberCtrl.text.trim().toUpperCase();
                final existingNum = await FirebaseFirestore.instance
                    .collection('customer_policies')
                    .where('policyNumber', isEqualTo: policyNumber)
                    .limit(1)
                    .get();

                if (existingNum.docs.isNotEmpty) {
                  setS(() => isSaving = false);
                  _showError(
                    'This policy number is already linked to a customer.',
                  );
                  return;
                }

                final user = FirebaseAuth.instance.currentUser;
                final uid = user?.uid ?? '';
                final cpRef = FirebaseFirestore.instance
                    .collection('customer_policies')
                    .doc();
                String? pdfUrl;
                String? pdfPath;
                String? pdfFileName;
                if (selectedPdfBytes != null && selectedPdfName != null) {
                  pdfFileName = _safePdfFileName(selectedPdfName!);
                  pdfPath =
                      'customer_policy_pdfs/$customerId/${cpRef.id}/$pdfFileName';
                  final ref = FirebaseStorage.instance.ref(pdfPath);
                  await ref.putData(
                    selectedPdfBytes!,
                    SettableMetadata(
                      contentType: 'application/pdf',
                      customMetadata: {
                        'customerId': customerId,
                        'customerName': customerName,
                        'policyNumber': policyNumber,
                      },
                    ),
                  );
                  pdfUrl = await ref.getDownloadURL();
                }
                final companyId =
                    selectedPolicy!['companyId']?.toString() ?? '';
                final companyName =
                    selectedPolicy!['companyName']?.toString() ?? '';
                final category = selectedPolicy!['category']?.toString() ?? '';
                final policyName =
                    selectedPolicy!['planName']?.toString() ?? '';
                final policyCode =
                    selectedPolicy!['policyCode']?.toString() ?? '';
                final policySection =
                    selectedPolicy!['policySection']?.toString() ?? '';
                final productName = productNameCtrl.text.trim().isEmpty
                    ? policyName
                    : productNameCtrl.text.trim();

                final premiumAmount = parseNum(premiumCtrl.text);
                final insuredSum = parseNum(sumInsuredCtrl.text);
                final commissionEarned =
                    (premiumAmount * commissionPercent) / 100;
                final mKey = buildMonthKey(policyStartDate);
                final policySerial = await PolicySerialService.reserve(
                  category: category,
                  policyId: cpRef.id,
                  customerId: customerId,
                  customerName: customerName,
                );

                // Build insured members list
                final insuredList = insuredControllers
                    .where((c) => (c['name']?.text ?? '').isNotEmpty)
                    .map(
                      (c) => {
                        'name': c['name']!.text,
                        'dob': c['dob']!.text,
                        'gender': c['gender']!.text,
                      },
                    )
                    .toList();

                final batch = FirebaseFirestore.instance.batch();
                final revRef = FirebaseFirestore.instance
                    .collection('revenue')
                    .doc();
                final custRef = FirebaseFirestore.instance
                    .collection('customers')
                    .doc(customerId);
                final logRef = FirebaseFirestore.instance
                    .collection('logs')
                    .doc();

                final policyFields = {
                  ...policySerial.toFirestoreFields(),
                  'customerId': customerId,
                  'customerName': customerName,
                  'customerMobile': customerMobile,
                  'policyPhone': policyPhoneCtrl.text.trim(),
                  'policyId': validSelectedId,
                  'policyName': policyName,
                  'policyCode': policyCode,
                  'policySection': policySection,
                  'policyNumber': policyNumber,
                  'createdByName': _currentEmployeeName,
                  'companyId': companyId,
                  'companyName': companyName,
                  'category': category,
                  'productName': productName,
                  'month': mKey,
                  'issueDate': issueDate,
                  'issueDateFormatted': fmtDate(issueDate),
                  'policyStartDate': policyStartDate,
                  'policyEndDate': policyEndDate,
                  'policyEndDateFormatted': fmtDate(policyEndDate),
                  'premiumAmount': premiumAmount,
                  'sumInsured': insuredSum,
                  'commissionPercent': commissionPercent,
                  'renewalCommissionPercent': getPolicyRenewalCommissionPercent(
                    selectedPolicy!,
                  ),
                  'commissionAmount': commissionEarned,
                  'notes': notesCtrl.text.trim(),
                  if (pdfUrl != null) 'pdfUrl': pdfUrl,
                  if (pdfPath != null) 'pdfStoragePath': pdfPath,
                  if (pdfFileName != null) 'pdfFileName': pdfFileName,
                  if (pdfUrl != null)
                    'pdfUploadedAt': FieldValue.serverTimestamp(),
                  'status': 'Active',
                  // PDF-sourced extras
                  'urn': urnCtrl.text.trim(),
                  'branchCode': branchCodeCtrl.text.trim(),
                  'intermediaryName': intermediaryNameCtrl.text.trim(),
                  'intermediaryCode': intermediaryCodeCtrl.text.trim(),
                  'policyType': policyTypeCtrl.text.trim(),
                  'policyTerm': policyTermCtrl.text.trim().isEmpty
                      ? '10 Years'
                      : policyTermCtrl.text.trim(),
                  'profession': professionCtrl.text.trim(),
                  'annualIncome': annualIncomeCtrl.text.trim(),
                  'nomineeName': nomineeNameCtrl.text.trim(),
                  'nomineeRelationship': nomineeRelCtrl.text.trim(),
                  'insuredMembers': insuredList,
                  // Coverage extras
                  'roadAmbulanceLimit': roadAmbCtrl.text.trim(),
                  'radioCabLimit': radioCabCtrl.text.trim(),
                  'convalescenceLimit': convalCtrl.text.trim(),
                  'cumulativeBonus': cumBonusCtrl.text.trim(),
                  'preHospitalizationDays': preHospCtrl.text.trim(),
                  'postHospitalizationDays': postHospCtrl.text.trim(),
                  'roomRentLimit': roomRentCtrl.text.trim(),
                  'specificWaitingPeriod': specWaitCtrl.text.trim(),
                  'pedWaitingPeriod': pedWaitCtrl.text.trim(),
                };

                batch.set(cpRef, {
                  ...policyFields,
                  'createdAt': FieldValue.serverTimestamp(),
                  'createdBy': uid,
                  'createdByEmail': user?.email ?? '',
                });

                batch.set(custRef, {
                  ...policyFields,
                  'policyLinkedManually': true,
                  'policyLinkedAt': FieldValue.serverTimestamp(),
                  'updatedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));

                batch.set(revRef, {
                  ...policyFields,
                  'source': 'Policy Sale',
                  'revenue': commissionEarned,
                  'monthKey': mKey,
                  'year': policyStartDate!.year,
                  'createdAt': FieldValue.serverTimestamp(),
                  'createdBy': uid,
                  'createdByEmail': user?.email ?? '',
                });

                batch.set(logRef, {
                  'page': 'All Customers',
                  'action': 'Added Policy',
                  'serialNumber': policySerial.serialNumber,
                  'description':
                      'Linked policy ${policySerial.serialNumber} "$policyName" ($policyNumber) to "$customerName" — company "$companyName"',
                  'performedBy': user?.email ?? uid,
                  'performedByUid': uid,
                  'targetId': customerId,
                  'timestamp': FieldValue.serverTimestamp(),
                });

                if (pdfUrl != null && pdfFileName != null) {
                  final fileRef = FirebaseFirestore.instance
                      .collection('customer_files')
                      .doc();
                  batch.set(fileRef, {
                    'customerId': customerId,
                    'fileName': pdfFileName,
                    'fileUrl': pdfUrl,
                    'storagePath': pdfPath,
                    'uploadedAt': FieldValue.serverTimestamp(),
                    'uploadedBy': user?.email ?? uid,
                    'uploadedByUid': uid,
                    'type': 'Policy Document',
                    'policyNumber': policyNumber,
                    'policyName': policyName,
                  });
                }

                await batch.commit();

                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        'Policy ${policySerial.serialNumber} linked successfully',
                      ),
                      backgroundColor: _primary,
                    ),
                  );
                }
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

            // ── UI ────────────────────────────────────────────────────────
            return AlertDialog(
              backgroundColor: _surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
              contentPadding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
              title: const Text(
                'Add Policy To Customer',
                style: TextStyle(
                  color: _textMain,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              content: SizedBox(
                width: 720,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$customerName • $customerMobile',
                        style: const TextStyle(color: _textMuted, fontSize: 12),
                      ),
                      const SizedBox(height: 16),

                      // ════════════════════════════════════════════
                      // PDF UPLOAD CARD  ← NEW
                      // ════════════════════════════════════════════
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _accent.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _accent.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.picture_as_pdf,
                                  color: _accent,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Upload Life Policy PDF - auto-fill fields',
                                    style: const TextStyle(
                                      color: _accent,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                if (_isExtracting)
                                  const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: _accent,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ElevatedButton.icon(
                              onPressed:
                                  _isExtracting || validSelectedId == null
                                  ? null
                                  : pickAndExtractPdf,
                              icon: const Icon(Icons.upload_file, size: 15),
                              label: Text(
                                validSelectedId == null
                                    ? 'Select Policy First'
                                    : _uploadedFileName == null
                                    ? 'Choose PDF'
                                    : 'Replace PDF',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _accent,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                            if (validSelectedId == null) ...[
                              const SizedBox(height: 8),
                              const Text(
                                'Select a policy below before uploading a PDF.',
                                style: TextStyle(
                                  color: _textMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            if (_isExtracting) ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _accent.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: const Row(
                                  children: [
                                    SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: _accent,
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Reading PDF and extracting policy information...',
                                        style: TextStyle(
                                          color: _accent,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (_uploadedFileName != null) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    _extractionStatus == 'success'
                                        ? Icons.check_circle
                                        : _extractionStatus == 'failed'
                                        ? Icons.error_outline
                                        : Icons.hourglass_top,
                                    size: 14,
                                    color: _extractionStatus == 'success'
                                        ? _green
                                        : _extractionStatus == 'failed'
                                        ? _red
                                        : _accent,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _isExtracting
                                          ? 'Extracting fields...'
                                          : _extractionStatus == 'success'
                                          ? 'Fields pre-filled from: $_uploadedFileName'
                                          : _extractionStatus == 'failed'
                                          ? 'Extraction failed – fill manually'
                                          : _uploadedFileName!,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: _extractionStatus == 'success'
                                            ? _green
                                            : _extractionStatus == 'failed'
                                            ? _red
                                            : _textMuted,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ════════════════════════════════════════════
                      // POLICY SELECTOR
                      // ════════════════════════════════════════════
                      if (allPolicies.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _red.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _red.withValues(alpha: 0.2),
                            ),
                          ),
                          child: const Text(
                            'No active policies available.',
                            style: TextStyle(color: _red, fontSize: 12),
                          ),
                        )
                      else
                        DropdownButtonFormField<String>(
                          value: validSelectedId,
                          hint: const Text('Select a policy'),
                          isExpanded: true,
                          items: allPolicies.map((p) {
                            final pid = p['id'].toString();
                            return DropdownMenuItem<String>(
                              value: pid,
                              child: Text(
                                '${p['planName'] ?? ''} • ${p['policyCode'] ?? ''} • ${p['companyName'] ?? ''}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (v) {
                            final p = allPolicies.firstWhere(
                              (e) => e['id'].toString() == v,
                              orElse: () => <String, dynamic>{},
                            );
                            setS(() {
                              selectedPolicyId = v;
                              selectedPolicy = p.isEmpty ? null : p;
                              issueDate = DateTime.now();
                              policyStartDate = DateTime.now();
                              policyEndDate = calcPolicyEndDate(
                                DateTime.now(),
                                12,
                              );
                              commissionPercent = 0;
                              if (premiumCtrl.text.isEmpty) premiumCtrl.clear();
                              if (sumInsuredCtrl.text.isEmpty)
                                sumInsuredCtrl.clear();
                              if (policyNumberCtrl.text.isEmpty)
                                policyNumberCtrl.clear();
                              if (productNameCtrl.text.isEmpty) {
                                productNameCtrl.text =
                                    p['planName']?.toString() ?? '';
                              }
                            });
                            recomputeCommission();
                          },
                          decoration: InputDecoration(
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
                                color: _accent,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),

                      // ════════════════════════════════════════════
                      // POLICY CORE FIELDS
                      // ════════════════════════════════════════════
                      _sectionLabel('Life Policy Fields'),
                      _row2(
                        _tf('Policy Number *', policyNumberCtrl),
                        _tf('Product Name', productNameCtrl),
                      ),
                      if (!isHealthCategory)
                        _row2(
                          _tf(
                            'Phone No',
                            policyPhoneCtrl,
                            type: TextInputType.phone,
                          ),
                          const SizedBox.shrink(),
                        ),
                      _row2(
                        _tf('URN', urnCtrl),
                        _tf('Branch Code', branchCodeCtrl),
                      ),
                      _row2(
                        _tf('Policy Type', policyTypeCtrl),
                        _tf(
                          'Policy Term',
                          policyTermCtrl,
                          onChanged: (_) => recomputeCommission(),
                        ),
                      ),
                      _row2(
                        TextField(
                          controller: premiumCtrl,
                          keyboardType: TextInputType.number,
                          onChanged: (_) {
                            setS(() {});
                            recomputeCommission();
                          },
                          style: const TextStyle(
                            fontSize: 13,
                            color: _textMain,
                          ),
                          decoration: _tfDec('Premium Amount *'),
                        ),
                        TextField(
                          controller: sumInsuredCtrl,
                          keyboardType: TextInputType.number,
                          onChanged: (_) {
                            setS(() {});
                            recomputeCommission();
                          },
                          style: const TextStyle(
                            fontSize: 13,
                            color: _textMain,
                          ),
                          decoration: _tfDec('Sum Assured *'),
                        ),
                      ),

                      // month indicator
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 11,
                        ),
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: _bg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _border),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_view_month_outlined,
                              size: 15,
                              color: _textMuted,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Month: ${buildMonthKey(issueDate).isEmpty ? 'Auto from Issued Date' : buildMonthKey(issueDate)}',
                              style: TextStyle(
                                color: issueDate != null ? _accent : _textMuted,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // dates
                      Row(
                        children: [
                          Expanded(
                            child: _dateBox(
                              label: issueDate == null
                                  ? 'Issued Date *'
                                  : 'Issued: ${fmtDate(issueDate)}',
                              value: issueDate,
                              readOnly: false,
                              onTap: () async {
                                final picked = await pickDate(
                                  ctx,
                                  initial: issueDate ?? DateTime.now(),
                                  helpText: 'Select Issued Date',
                                );
                                if (picked != null) {
                                  setS(() {
                                    issueDate = picked;
                                    policyStartDate = picked;
                                    policyEndDate = calcPolicyEndDate(
                                      picked,
                                      12,
                                    );
                                  });
                                  recomputeCommission();
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _dateBox(
                              label: policyStartDate == null
                                  ? 'Active Date *'
                                  : 'Active: ${fmtDate(policyStartDate)}',
                              value: policyStartDate,
                              readOnly: false,
                              onTap: () async {
                                final picked = await pickDate(
                                  ctx,
                                  initial: policyStartDate ?? DateTime.now(),
                                  helpText: 'Policy Active Date',
                                );
                                if (picked != null) {
                                  setS(() {
                                    policyStartDate = picked;
                                    policyEndDate = calcPolicyEndDate(
                                      picked,
                                      12,
                                    );
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _dateBox(
                              label: policyEndDate == null
                                  ? 'Expiry Date (auto)'
                                  : 'Expiry: ${fmtDate(policyEndDate)}',
                              value: policyEndDate,
                              readOnly: true,
                              onTap: null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(child: SizedBox()),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // commission panel
                      if (selectedPolicy != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _primary.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Company: ${selectedPolicy!['companyName'] ?? '-'}',
                                style: const TextStyle(
                                  color: _textMain,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Commission %: $commissionPercent%',
                                style: const TextStyle(
                                  color: _textMuted,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Commission Amount: ₹${commissionAmount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: _accent,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),

                      // ════════════════════════════════════════════
                      // INTERMEDIARY
                      // ════════════════════════════════════════════
                      _sectionLabel('Intermediary Details'),
                      _row2(
                        _tf('Intermediary Name', intermediaryNameCtrl),
                        _tf('Intermediary Code', intermediaryCodeCtrl),
                      ),
                      const SizedBox(height: 4),

                      // ════════════════════════════════════════════
                      // PROPOSER EXTRAS
                      // ════════════════════════════════════════════
                      _sectionLabel('Proposer Details'),
                      _row2(
                        _tf('Profession', professionCtrl),
                        _tf(
                          'Annual Income',
                          annualIncomeCtrl,
                          type: TextInputType.number,
                        ),
                      ),
                      const SizedBox(height: 4),

                      // ════════════════════════════════════════════
                      // NOMINEE
                      // ════════════════════════════════════════════
                      _sectionLabel('Nominee Details'),
                      _row2(
                        _tf('Nominee Name', nomineeNameCtrl),
                        _tf('Relationship', nomineeRelCtrl),
                      ),
                      const SizedBox(height: 4),

                      // ════════════════════════════════════════════
                      // INSURED MEMBERS
                      // ════════════════════════════════════════════
                      if (isHealthCategory) ...[
                        _sectionLabel('Insured Members (from PDF)'),
                        ...List.generate(4, (i) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 28,
                                  child: Text(
                                    '${i + 1}.',
                                    style: const TextStyle(
                                      color: _textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: _tf(
                                    'Name',
                                    insuredControllers[i]['name']!,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 2,
                                  child: _tf(
                                    'DOB',
                                    insuredControllers[i]['dob']!,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 2,
                                  child: _tf(
                                    'Gender',
                                    insuredControllers[i]['gender']!,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),

                        // ════════════════════════════════════════════
                        // COVERAGE DETAILS
                        // ════════════════════════════════════════════
                        _sectionLabel('Coverage Details (from PDF)'),
                        _row2(
                          _tf('Road Ambulance Limit', roadAmbCtrl),
                          _tf('Radio Cab Limit', radioCabCtrl),
                        ),
                        _row2(
                          _tf('Convalescence', convalCtrl),
                          _tf('Cumulative Bonus', cumBonusCtrl),
                        ),
                        _row2(
                          _tf('Pre-Hosp Days', preHospCtrl),
                          _tf('Post-Hosp Days', postHospCtrl),
                        ),
                        _row2(
                          _tf('Room Rent Limit', roomRentCtrl),
                          _tf('Specific Waiting Period', specWaitCtrl),
                        ),
                        _tf('PED Waiting Period', pedWaitCtrl),
                        const SizedBox(height: 10),
                      ],

                      // ════════════════════════════════════════════
                      // NOTES
                      // ════════════════════════════════════════════
                      _tf('Notes', notesCtrl, maxLines: 3),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: _textMuted),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: isSaving ? null : saveLink,
                  icon: isSaving
                      ? const SizedBox(
                          width: 13,
                          height: 13,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_rounded, size: 15),
                  label: Text(isSaving ? 'Saving...' : 'Add Policy'),
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
            );
          },
        );
      },
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // SHARED WIDGET HELPERS
  // ════════════════════════════════════════════════════════════════════════════
  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        color: _primary,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.4,
      ),
    ),
  );

  Widget _row2(Widget a, Widget b) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Expanded(child: a),
        const SizedBox(width: 10),
        Expanded(child: b),
      ],
    ),
  );

  Widget _tf(
    String label,
    TextEditingController ctrl, {
    TextInputType type = TextInputType.text,
    int maxLines = 1,
    ValueChanged<String>? onChanged,
    bool readOnly = false,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      maxLines: maxLines,
      onChanged: onChanged,
      readOnly: readOnly,
      style: const TextStyle(fontSize: 13, color: _textMain),
      decoration: _tfDec(label),
    );
  }

  InputDecoration _tfDec(String label) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: _textMuted, fontSize: 12),
    filled: true,
    fillColor: _bg,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: _border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: _border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: _accent, width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
  );

  Widget _drop(
    String label,
    List<String> items,
    String value,
    ValueChanged<String?> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      value: items.contains(value) ? value : null,
      onChanged: onChanged,
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      style: const TextStyle(fontSize: 13, color: _textMain),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _textMuted, fontSize: 12),
        filled: true,
        fillColor: _bg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 11,
        ),
      ),
    );
  }

  Widget _dateBox({
    required String label,
    required DateTime? value,
    required bool readOnly,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: readOnly ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            Icon(
              readOnly
                  ? Icons.event_available_outlined
                  : Icons.calendar_today_outlined,
              size: 16,
              color: readOnly ? _green : _textMuted,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: value == null ? _textMuted : _textMain,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// _CustomerRow
// ════════════════════════════════════════════════════════════════════════════
class _CustomerListHeader extends StatelessWidget {
  const _CustomerListHeader();

  static const _primary = Color(0xFF0D2D4F);
  static const _surface = Color(0xFFFFFFFF);
  static const _border = Color(0xFFE4E7EC);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(
          top: BorderSide(color: _border),
          bottom: BorderSide(color: _border),
        ),
      ),
      child: const Row(
        children: [
          _HeaderCell('Customer', 138),
          _HeaderCell('Mobile', 96),
          _HeaderCell('Employee', 96),
          _HeaderCell('Policy No.', 98),
          _HeaderCell('Policy Added By', 120),
          _HeaderCell('Month', 64),
          _HeaderCell('Term', 76),
          _HeaderCell('Commission', 94),
          Expanded(child: _HeaderText('Company')),
          SizedBox(width: 82, child: _HeaderText('Status')),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;
  final double width;
  const _HeaderCell(this.label, this.width);

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: width, child: _HeaderText(label));
  }
}

class _HeaderText extends StatelessWidget {
  final String label;
  const _HeaderText(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: _CustomerListHeader._primary,
        fontSize: 11,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _CustomerRow extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final Map<String, dynamic>? linkedPolicy;
  final Map<String, dynamic>? masterPolicy;
  final VoidCallback onTap;

  static const _surface = Color(0xFFFFFFFF);
  static const _border = Color(0xFFE4E7EC);
  static const _textMain = Color(0xFF0D1B2A);
  static const _textMuted = Color(0xFF8A94A6);
  static const _red = Color(0xFFDC2626);
  static const _green = Color(0xFF16A34A);

  const _CustomerRow({
    required this.doc,
    required this.linkedPolicy,
    required this.masterPolicy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final effectivePolicy = linkedPolicy == null
        ? null
        : _withLiveLifeCommission(linkedPolicy!, masterPolicy);
    final name = data['fullName']?.toString() ?? '';
    final employee = (data['employeeName'] ?? data['employee'] ?? '')
        .toString();
    final savedMobile = data['mobileNumber']?.toString() ?? '';
    final policyPhone =
        effectivePolicy?['policyPhone']?.toString().trim() ?? '';
    final mobile = policyPhone.isNotEmpty ? policyPhone : savedMobile;
    final status = data['status']?.toString() ?? 'Active';
    final company = effectivePolicy?['companyName']?.toString() ?? '';
    final policyNumber = effectivePolicy?['policyNumber']?.toString() ?? '';
    final policyAddedBy =
        (effectivePolicy?['createdByName'] ??
                effectivePolicy?['createdByEmail'] ??
                effectivePolicy?['employeeName'] ??
                effectivePolicy?['createdBy'] ??
                '')
            .toString();
    final month = effectivePolicy?['month']?.toString() ?? '';
    final term = effectivePolicy?['policyTerm']?.toString() ?? '';
    final commission = effectivePolicy == null
        ? ''
        : 'Rs ${_lifeNum(effectivePolicy['commissionAmount']).toStringAsFixed(0)}';
    final isActive = status == 'Active';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: const BoxDecoration(
          color: _surface,
          border: Border(bottom: BorderSide(color: _border, width: 0.7)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 138,
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _textMain,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(
              width: 96,
              child: Text(
                mobile,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _textMain, fontSize: 13),
              ),
            ),
            SizedBox(
              width: 96,
              child: Text(
                employee.isEmpty ? '-' : employee,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _textMuted, fontSize: 12),
              ),
            ),
            SizedBox(
              width: 98,
              child: Text(
                policyNumber,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _textMuted, fontSize: 12),
              ),
            ),
            SizedBox(
              width: 120,
              child: Text(
                policyAddedBy.isEmpty ? '-' : policyAddedBy,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _textMuted, fontSize: 12),
              ),
            ),
            SizedBox(
              width: 64,
              child: Text(
                month,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _textMuted, fontSize: 12),
              ),
            ),
            SizedBox(
              width: 76,
              child: Text(
                term,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _textMuted, fontSize: 12),
              ),
            ),
            SizedBox(
              width: 94,
              child: Text(
                commission,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _green, fontSize: 12),
              ),
            ),
            Expanded(
              child: Text(
                company,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _textMuted, fontSize: 12),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isActive
                    ? Colors.green.withValues(alpha: 0.08)
                    : _red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: isActive ? Colors.green.shade700 : _red,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: Color(0xFF8A94A6),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// _CustomerDetailView
// ════════════════════════════════════════════════════════════════════════════
class _CustomerDetailView extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final String category;
  final VoidCallback onBack;
  final VoidCallback onEdit;
  final VoidCallback onDeleted;
  final VoidCallback onAddPolicy;
  final Map<String, dynamic>? currentUser;

  static const _primary = Color(0xFF0D2D4F);
  static const _accent = Color(0xFF1A6EBD);
  static const _bg = Color(0xFFF4F6F9);
  static const _surface = Color(0xFFFFFFFF);
  static const _border = Color(0xFFE4E7EC);
  static const _textMain = Color(0xFF0D1B2A);
  static const _textMuted = Color(0xFF8A94A6);
  static const _red = Color(0xFFDC2626);

  const _CustomerDetailView({
    required this.doc,
    required this.category,
    required this.onBack,
    required this.onEdit,
    required this.onDeleted,
    required this.onAddPolicy,
    required this.currentUser,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('customers')
          .doc(doc.id)
          .snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() ?? doc.data();
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('customer_policies')
              .snapshots(),
          builder: (context, policySnap) {
            final isAdmin =
                (currentUser?['role'] ?? 'admin').toString().toLowerCase() ==
                'admin';
            final policies = _allowsLinkedPolicyDisplay(data)
                ? _policiesForCustomer(
                    policySnap.data?.docs ?? [],
                    doc.id,
                    category,
                  )
                : <QueryDocumentSnapshot<Map<String, dynamic>>>[];
            if (policies.isNotEmpty) {
              final linkedPolicy = policies.first.data();
              final planId = linkedPolicy['policyId']?.toString() ?? '';
              if (planId.isNotEmpty && category.toLowerCase() == 'life') {
                return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('life_policies')
                      .doc(planId)
                      .snapshots(),
                  builder: (context, masterSnap) {
                    return _buildContent(
                      context,
                      data,
                      linkedPolicy: _withLiveLifeCommission(
                        linkedPolicy,
                        masterSnap.data?.data(),
                      ),
                      isAdmin: isAdmin,
                    );
                  },
                );
              }
            }
            return _buildContent(
              context,
              data,
              linkedPolicy: policies.isEmpty ? null : policies.first.data(),
              isAdmin: isAdmin,
            );
          },
        );
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    Map<String, dynamic> data, {
    required Map<String, dynamic>? linkedPolicy,
    required bool isAdmin,
  }) {
    final name = data['fullName']?.toString() ?? '';
    final mobile = data['mobileNumber']?.toString() ?? '';
    final email = data['email']?.toString() ?? '';
    final address = data['address']?.toString() ?? '';
    final city = data['city']?.toString() ?? '';
    final state = data['state']?.toString() ?? '';
    final pincode = data['pincode']?.toString() ?? '';
    final dob = data['dateOfBirth']?.toString() ?? '';
    final gender = data['gender']?.toString() ?? '';
    final marital = data['maritalStatus']?.toString() ?? '';
    final customerType = data['customerType']?.toString() ?? '';
    final status = data['status']?.toString() ?? 'Active';
    final employee = (data['employeeName'] ?? data['employee'] ?? '')
        .toString();
    final guardian = data['guardianName']?.toString() ?? '';
    final pan = data['panNumber']?.toString() ?? '';
    final aadhar = data['aadharNumber']?.toString() ?? '';

    final policyData = linkedPolicy ?? const <String, dynamic>{};
    final policyNumber = policyData['policyNumber']?.toString() ?? '';
    final policySerialNumber = policyData['serialNumber']?.toString() ?? '';
    final month = policyData['month']?.toString() ?? '';
    final issueDate = _fmt(policyData['issueDate']);
    final policyEndDate = _fmt(policyData['policyEndDate']);
    final sumInsured = policyData['sumInsured']?.toString() ?? '';
    final premium = policyData['premiumAmount']?.toString() ?? '';
    final policyPhone = policyData['policyPhone']?.toString() ?? mobile;
    final product =
        policyData['productName']?.toString() ??
        policyData['policyName']?.toString() ??
        '';
    final companyName = policyData['companyName']?.toString() ?? '';
    final category = policyData['category']?.toString() ?? '';
    final policyCode = policyData['policyCode']?.toString() ?? '';
    final commissionPct = policyData['commissionPercent']?.toString() ?? '';
    final renewalCommPct =
        policyData['renewalCommissionPercent']?.toString() ?? '';
    final commissionAmt = policyData['commissionAmount']?.toString() ?? '';
    final commissionRule = policyData['commissionRule']?.toString() ?? '';
    final policyStartDate = _fmt(policyData['policyStartDate']);
    final pdfUrl = (policyData['pdfUrl'] ?? '').toString();
    final pdfFileName = (policyData['pdfFileName'] ?? 'Policy PDF').toString();

    // PDF-sourced extras
    final urn = policyData['urn']?.toString() ?? '';
    final branchCode = policyData['branchCode']?.toString() ?? '';
    final intermediaryName = policyData['intermediaryName']?.toString() ?? '';
    final intermediaryCode = policyData['intermediaryCode']?.toString() ?? '';
    final policyType = policyData['policyType']?.toString() ?? '';
    final policyTerm = policyData['policyTerm']?.toString() ?? '';
    final profession = policyData['profession']?.toString() ?? '';
    final annualIncome = policyData['annualIncome']?.toString() ?? '';
    final nomineeName = policyData['nomineeName']?.toString() ?? '';
    final nomineeRel = policyData['nomineeRelationship']?.toString() ?? '';

    final insuredMembers =
        (policyData['insuredMembers'] as List?)?.cast<Map>() ?? [];

    final roadAmb = policyData['roadAmbulanceLimit']?.toString() ?? '';
    final radioCab = policyData['radioCabLimit']?.toString() ?? '';
    final conval = policyData['convalescenceLimit']?.toString() ?? '';
    final cumBonus = policyData['cumulativeBonus']?.toString() ?? '';
    final preHosp = policyData['preHospitalizationDays']?.toString() ?? '';
    final postHosp = policyData['postHospitalizationDays']?.toString() ?? '';
    final roomRent = policyData['roomRentLimit']?.toString() ?? '';
    final specWait = policyData['specificWaitingPeriod']?.toString() ?? '';
    final pedWait = policyData['pedWaitingPeriod']?.toString() ?? '';

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: _surface,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: onBack,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: _primary.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        color: _primary,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        color: _textMain,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (isAdmin && linkedPolicy == null) ...[
                    _headerBtn(
                      Icons.link_rounded,
                      _accent,
                      'Add Policy',
                      onAddPolicy,
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (isAdmin) ...[
                    _headerBtn(Icons.edit_outlined, _accent, 'Edit', onEdit),
                    const SizedBox(width: 8),
                    _headerBtn(
                      Icons.delete_outline_rounded,
                      _red,
                      'Delete',
                      () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete Customer'),
                            content: Text(
                              'Remove $name? This cannot be undone.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _red,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) {
                          await FirebaseFirestore.instance
                              .collection('customers')
                              .doc(doc.id)
                              .delete();
                          await AuditLogService.write(
                            page: 'Life Customers',
                            action: 'Deleted Customer',
                            description: 'Deleted customer "$name".',
                            targetId: doc.id,
                            targetType: 'Customer',
                            targetName: name,
                            extra: {'customerName': name},
                          );
                          onDeleted();
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1, color: _border),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _excelCard('Personal Information', [
                      _xlRow('Full Name', name),
                      _xlRow('Mobile', mobile),
                      _xlRow('Email', email),
                      _xlRow('Gender', gender),
                      _xlRow('Date of Birth', dob),
                      _xlRow('Marital Status', marital),
                      _xlRow('Customer Type', customerType),
                      _xlRow('Employee', employee),
                      _xlRow('Guardian', guardian),
                      _xlRow('PAN', pan),
                      _xlRow('Aadhar', aadhar),
                      _xlRow('Status', status),
                    ]),
                    if (address.isNotEmpty ||
                        city.isNotEmpty ||
                        state.isNotEmpty ||
                        pincode.isNotEmpty)
                      _excelCard('Address', [
                        _xlRow('Address', address),
                        _xlRow('City', city),
                        _xlRow('State', state),
                        _xlRow('Pincode', pincode),
                      ]),
                    _CustomerNotesCard(
                      customerId: doc.id,
                      customerName: name,
                      mobileNumber: mobile,
                      currentLeadStatus:
                          data['leadStatus']?.toString() ?? 'Green',
                      currentUser: currentUser,
                    ),
                    CustomerFilesCard(
                      customerId: doc.id,
                      customerName: name,
                      currentUser: currentUser,
                    ),
                    if (linkedPolicy != null) ...[
                      _excelCard('Policy Details', [
                        _xlRow('Policy Serial', policySerialNumber),
                        _xlRow('Policy No', policyNumber),
                        _xlRow('Month', month),
                        _xlRow('URN', urn),
                        _xlRow('Branch Code', branchCode),
                        _xlRow('Policy Type', policyType),
                        _xlRow('Policy Term', policyTerm),
                        _xlRow('Issued Date', issueDate),
                        _xlRow('Policy Active Date', policyStartDate),
                        _xlRow('Policy Expiry Date', policyEndDate),
                        _xlRow(
                          'Policy PDF',
                          pdfUrl.isEmpty ? '-' : pdfFileName,
                        ),
                        _xlRow(
                          'Sum Assured',
                          sumInsured.isNotEmpty ? '₹$sumInsured' : '-',
                        ),
                        _xlRow(
                          'Premium',
                          premium.isNotEmpty ? '₹$premium' : '-',
                        ),
                        _xlRow('Phone No', policyPhone),
                        _xlRow('Product', product),
                        _xlRow('Company', companyName),
                        _xlRow('Category', category),
                        _xlRow('Policy Code', policyCode),
                      ]),
                      if (pdfUrl.isNotEmpty)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 12),
                          child: OutlinedButton.icon(
                            onPressed: () => _openPdfUrl(context, pdfUrl),
                            icon: const Icon(
                              Icons.picture_as_pdf_outlined,
                              size: 16,
                            ),
                            label: Text('Open $pdfFileName'),
                          ),
                        ),
                      _excelCard('Commission', [
                        _xlRow(
                          'Commission %',
                          commissionPct.isNotEmpty ? '$commissionPct%' : '-',
                        ),
                        _xlRow(
                          'Renewal Commission %',
                          renewalCommPct.isNotEmpty ? '$renewalCommPct%' : '-',
                        ),
                        _xlRow(
                          'Commission Amount',
                          commissionAmt.isNotEmpty ? '₹$commissionAmt' : '-',
                        ),
                        _xlRow('Calculated From', commissionRule),
                      ]),
                      _excelCard('Intermediary', [
                        _xlRow('Name', intermediaryName),
                        _xlRow('Code', intermediaryCode),
                      ]),
                      _excelCard('Proposer Extras', [
                        _xlRow('Profession', profession),
                        _xlRow('Annual Income', annualIncome),
                        _xlRow('Nominee', nomineeName),
                        _xlRow('Nominee Rel.', nomineeRel),
                      ]),
                      if (category.toLowerCase() == 'health' &&
                          insuredMembers.isNotEmpty)
                        _excelCard(
                          'Insured Members',
                          insuredMembers.asMap().entries.map((e) {
                            final i = e.key + 1;
                            final m = e.value;
                            return _xlRow(
                              'Member $i',
                              '${m['name'] ?? '-'}  |  ${m['dob'] ?? '-'}  |  ${m['gender'] ?? '-'}',
                            );
                          }).toList(),
                        ),
                      if (category.toLowerCase() == 'health')
                        _excelCard('Coverage Details', [
                          _xlRow('Road Ambulance', roadAmb),
                          _xlRow('Radio Cab', radioCab),
                          _xlRow('Convalescence', conval),
                          _xlRow('Cumulative Bonus', cumBonus),
                          _xlRow('Pre-Hosp Days', preHosp),
                          _xlRow('Post-Hosp Days', postHosp),
                          _xlRow('Room Rent Limit', roomRent),
                          _xlRow('Specific Wait Period', specWait),
                          _xlRow('PED Wait Period', pedWait),
                        ]),
                      _LinkedPoliciesCard(
                        customerId: doc.id,
                        category: category,
                      ),
                    ],
                    if (isAdmin && linkedPolicy == null) ...[
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: onAddPolicy,
                        icon: const Icon(Icons.add_link_rounded, size: 16),
                        label: const Text('Add Policy'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _excelCard(String title, List<Widget> rows) {
    final expanded = title != 'Personal Information';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Theme(
            data: ThemeData().copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: expanded,
              tilePadding: const EdgeInsets.symmetric(horizontal: 12),
              childrenPadding: EdgeInsets.zero,
              title: Text(
                title,
                style: const TextStyle(
                  color: _primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
              children: [
                const Divider(height: 1, color: _border),
                ...rows
                    .expand(
                      (r) => [
                        r,
                        const Divider(
                          height: 1,
                          thickness: 0.7,
                          color: _border,
                        ),
                      ],
                    )
                    .toList()
                  ..removeLast(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _xlRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(
        children: [
          SizedBox(
            width: 170,
            child: Text(
              label,
              style: const TextStyle(
                color: _textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: label == 'Company'
                ? CompanyLogoLabel(
                    companyName: value,
                    logoSize: 24,
                    style: const TextStyle(
                      color: _textMain,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : Text(
                    value.isEmpty ? '-' : value,
                    style: const TextStyle(
                      color: _textMain,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _headerBtn(
    IconData icon,
    Color color,
    String label,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(dynamic v) {
    if (v == null) return '-';
    if (v is Timestamp) {
      final d = v.toDate();
      return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
    }
    if (v is DateTime) {
      return '${v.day.toString().padLeft(2, '0')}.${v.month.toString().padLeft(2, '0')}.${v.year}';
    }
    return v.toString();
  }
}

class _CustomerNotesCard extends StatefulWidget {
  final String customerId;
  final String customerName;
  final String mobileNumber;
  final String currentLeadStatus;
  final Map<String, dynamic>? currentUser;

  const _CustomerNotesCard({
    required this.customerId,
    required this.customerName,
    required this.mobileNumber,
    required this.currentLeadStatus,
    required this.currentUser,
  });

  @override
  State<_CustomerNotesCard> createState() => _CustomerNotesCardState();
}

class _CustomerNotesCardState extends State<_CustomerNotesCard> {
  static const _primary = Color(0xFF0D2D4F);
  static const _accent = Color(0xFF1A6EBD);
  static const _surface = Color(0xFFFFFFFF);
  static const _bg = Color(0xFFF4F6F9);
  static const _border = Color(0xFFE4E7EC);
  static const _textMain = Color(0xFF0D1B2A);
  static const _textMuted = Color(0xFF8A94A6);
  static const _red = Color(0xFFDC2626);
  static const _green = Color(0xFF16A34A);

  final _noteController = TextEditingController();
  DateTime? _scheduledAt;
  String? _selectedLeadStatus;
  bool _saving = false;

  String get _normalizedLeadStatus {
    final value = widget.currentLeadStatus.toLowerCase();
    if (value == 'hot' || value == 'green') return 'Green';
    if (value == 'cold' || value == 'red') return 'Red';
    return 'Green';
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> get _notesStream =>
      FirebaseFirestore.instance
          .collection('customer_notes')
          .where('customerId', isEqualTo: widget.customerId)
          .snapshots();

  String get _employeeId {
    final profile = widget.currentUser;
    final id = profile?['_profileDocId'] ?? profile?['uid'];
    return (id ?? FirebaseAuth.instance.currentUser?.uid ?? '').toString();
  }

  String get _employeeName {
    final profile = widget.currentUser;
    final name = profile?['name'] ?? profile?['username'] ?? profile?['email'];
    final fallback =
        FirebaseAuth.instance.currentUser?.displayName ??
        FirebaseAuth.instance.currentUser?.email ??
        'Signed-in user';
    return (name ?? fallback).toString();
  }

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<String?> _requestCallNote(int callNumber) async {
    final controller = TextEditingController();
    String? errorText;
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text('Add Note for Call $callNumber'),
          content: SizedBox(
            width: 400,
            child: TextField(
              controller: controller,
              maxLines: 4,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Call note',
                border: const OutlineInputBorder(),
                errorText: errorText,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final note = controller.text.trim();
                if (note.isEmpty) {
                  setDialogState(
                    () => errorText = 'Enter a note for this call.',
                  );
                  return;
                }
                Navigator.pop(dialogContext, note);
              },
              child: const Text('Save Call Note'),
            ),
          ],
        ),
      ),
    ).whenComplete(controller.dispose);
  }

  Future<void> _callCustomer(Map<String, dynamic> leadData) async {
    final mobile = widget.mobileNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    if (mobile.isEmpty) return;
    final currentCalls = (leadData['executiveCallCount'] as num?)?.toInt() ?? 0;
    if (currentCalls >= LeadWorkflowRules.executiveCallLimit) return;
    final lead = await LeadStatusGuard.linkedExecutiveLead(
      firestore: FirebaseFirestore.instance,
      customerId: widget.customerId,
    );
    if (!mounted) return;
    if (lead == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This customer is not linked to an executive lead.'),
          backgroundColor: _red,
        ),
      );
      return;
    }
    final opened = await launchUrl(Uri(scheme: 'tel', path: mobile));
    if (!opened) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open the phone dialer.')),
      );
      return;
    }
    final note = await _requestCallNote(currentCalls + 1);
    if (note == null || note.isEmpty) return;

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final latest = await transaction.get(lead.reference);
      final latestData = latest.data() ?? <String, dynamic>{};
      final count = (latestData['executiveCallCount'] as num?)?.toInt() ?? 0;
      if (count >= LeadWorkflowRules.executiveCallLimit) return;
      transaction.update(lead.reference, {
        'executiveCallCount': count + 1,
        'executiveLastCalledAt': FieldValue.serverTimestamp(),
        'executiveCallHistory': FieldValue.arrayUnion([
          {
            'callNumber': count + 1,
            'calledAt': Timestamp.now(),
            'calledById': _employeeId,
            'calledByName': _employeeName,
            'role': 'executive',
            'note': note,
          },
        ]),
        'executiveCallNotes': FieldValue.arrayUnion([
          {
            'callNumber': count + 1,
            'note': note,
            'addedAt': Timestamp.now(),
            'addedById': _employeeId,
            'addedByName': _employeeName,
          },
        ]),
        'executiveLastCallNote': note,
        'executiveNotesUpdatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Widget _callProgressCard(Map<String, dynamic>? leadData) {
    final calls = (leadData?['executiveCallCount'] as num?)?.toInt() ?? 0;
    final notes = ((leadData?['executiveCallNotes'] as List?) ?? const [])
        .whereType<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .toList();
    final noteCount = notes.length;
    final callProgress = (calls / LeadWorkflowRules.executiveCallLimit).clamp(
      0.0,
      1.0,
    );
    final noteProgress = (noteCount / LeadWorkflowRules.executiveCallLimit)
        .clamp(0.0, 1.0);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
                  'Call Tracking',
                  style: TextStyle(
                    color: _primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed:
                    leadData == null ||
                        calls >= LeadWorkflowRules.executiveCallLimit
                    ? null
                    : () => _callCustomer(leadData),
                icon: const Icon(Icons.call_rounded, size: 16),
                label: Text(
                  calls >= LeadWorkflowRules.executiveCallLimit
                      ? 'Call limit reached'
                      : 'Call ${calls + 1}',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _progressLine('Calls', calls, callProgress),
          const SizedBox(height: 10),
          _progressLine('Notes', noteCount, noteProgress),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Call Notes',
              style: TextStyle(color: _textMain, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            ...notes.map(
              (note) => Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _border),
                ),
                child: Text(
                  'Call ${note['callNumber'] ?? '-'}: ${note['note'] ?? ''}',
                  style: const TextStyle(color: _textMain, fontSize: 12),
                ),
              ),
            ),
          ],
          if (calls < LeadWorkflowRules.executiveCallLimit ||
              noteCount < LeadWorkflowRules.executiveCallLimit)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Complete 5 calls and 5 call notes before marking Red.',
                style: TextStyle(color: _textMuted, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _progressLine(String label, int count, double value) {
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: const TextStyle(
              color: _textMain,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 10,
              color: value >= 1 ? _green : _accent,
              backgroundColor: _border,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$count/${LeadWorkflowRules.executiveCallLimit}',
          style: const TextStyle(
            color: _textMuted,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Future<void> _pickScheduleDate() async {
    final now = DateTime.now();
    final base = _scheduledAt ?? DateTime(now.year, now.month, now.day, 9);
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: base,
    );
    if (picked == null) return;
    setState(() {
      _scheduledAt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        base.hour,
        base.minute,
      );
    });
  }

  Future<void> _pickScheduleTime() async {
    final now = DateTime.now();
    final base = _scheduledAt ?? DateTime(now.year, now.month, now.day, 9);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (picked == null) return;
    setState(() {
      _scheduledAt = DateTime(
        base.year,
        base.month,
        base.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  Future<void> _saveNote() async {
    final note = _noteController.text.trim();
    if (note.isEmpty || _saving) return;

    setState(() => _saving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final email = user?.email?.trim() ?? '';
      final author = (user?.displayName?.trim().isNotEmpty == true)
          ? user!.displayName!.trim()
          : _employeeName;
      final savedAt = Timestamp.now();
      final scheduledAt = _scheduledAt;
      final oldLeadStatus = _normalizedLeadStatus;
      final newLeadStatus = _selectedLeadStatus;
      final leadStatusChanged =
          newLeadStatus != null && newLeadStatus != oldLeadStatus;

      LeadRedGateResult? redGate;
      if (leadStatusChanged && newLeadStatus == 'Red') {
        redGate = await LeadStatusGuard.requireExecutiveRedGate(
          context: context,
          customerId: widget.customerId,
          currentUser: widget.currentUser,
        );
        if (redGate == null) return;
      }

      final effectiveLeadStatus = redGate?.routedLeadStatus ?? newLeadStatus;
      final effectiveLeadStatusChanged =
          effectiveLeadStatus != null && effectiveLeadStatus != oldLeadStatus;

      final noteRef = await FirebaseFirestore.instance
          .collection('customer_notes')
          .add({
            'customerId': widget.customerId,
            'customerName': widget.customerName,
            'note': note,
            'createdAt': savedAt,
            'createdBy': user?.uid ?? '',
            'createdByName': author,
            'createdByEmail': email,
            'employeeId': _employeeId,
            'employeeName': _employeeName,
            'isTask': scheduledAt != null,
            'isCompleted': false,
            'status': scheduledAt == null ? 'Note' : 'Pending',
            if (effectiveLeadStatus != null) 'leadStatus': effectiveLeadStatus,
            if (redGate != null) 'customerPurchaseValue': redGate.purchaseValue,
            if (effectiveLeadStatusChanged) 'leadStatusFrom': oldLeadStatus,
            if (effectiveLeadStatusChanged) 'leadStatusTo': effectiveLeadStatus,
            if (effectiveLeadStatusChanged) 'leadStatusChanged': true,
            if (scheduledAt != null)
              'scheduledAt': Timestamp.fromDate(scheduledAt),
            if (scheduledAt != null) 'dateKey': _dateKey(scheduledAt),
          });

      if (scheduledAt != null) {
        final taskRef = await FirebaseFirestore.instance
            .collection('employee_tasks')
            .add({
              'employeeId': _employeeId,
              'employeeName': _employeeName,
              'note': note,
              'taskDateTime': Timestamp.fromDate(scheduledAt),
              'dateKey': _dateKey(scheduledAt),
              'status': 'Pending',
              'isCompleted': false,
              'source': 'customer_note',
              'customerId': widget.customerId,
              'customerName': widget.customerName,
              'noteId': noteRef.id,
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
        await noteRef.update({'taskId': taskRef.id});
      }

      if (effectiveLeadStatus != null) {
        final batch = FirebaseFirestore.instance.batch();
        if (redGate != null) {
          batch.set(
            redGate.leadReference,
            redGate.leadUpdates,
            SetOptions(merge: true),
          );
        }
        batch.set(
          FirebaseFirestore.instance
              .collection('customers')
              .doc(widget.customerId),
          {
            'leadStatus': effectiveLeadStatus,
            'lastLeadStatusNote': note,
            if (redGate != null) 'customerPurchaseValue': redGate.purchaseValue,
            if (redGate != null)
              'executiveEscalatedToTeamLeader': redGate.escalateToTeamLeader,
            if (effectiveLeadStatusChanged) 'previousLeadStatus': oldLeadStatus,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        await batch.commit();
      }
      await AuditLogService.write(
        page: 'Life Customers',
        action: scheduledAt == null
            ? 'Added Customer Note'
            : 'Added Follow-up Task',
        description: scheduledAt == null
            ? 'Added note for ${widget.customerName}.'
            : 'Added follow-up task for ${widget.customerName}.',
        targetId: widget.customerId,
        targetType: 'Customer',
        targetName: widget.customerName,
        extra: {
          'customerName': widget.customerName,
          if (effectiveLeadStatus != null) 'leadStatus': effectiveLeadStatus,
          if (redGate != null) 'customerPurchaseValue': redGate.purchaseValue,
          if (effectiveLeadStatusChanged) 'leadStatusFrom': oldLeadStatus,
          if (effectiveLeadStatusChanged) 'leadStatusTo': effectiveLeadStatus,
        },
      );

      _noteController.clear();
      setState(() {
        _scheduledAt = null;
        _selectedLeadStatus = null;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Customer note saved'),
          backgroundColor: _accent,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to save note: $error'),
          backgroundColor: _red,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  String _formatDateTime(dynamic value) {
    final date = _date(value);
    if (date == null) return 'Saving...';
    final hour = date.hour == 0
        ? 12
        : (date.hour > 12 ? date.hour - 12 : date.hour);
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} '
        '${hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} $period';
  }

  Future<void> _toggleNoteTask(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    final done =
        (data['status'] ?? '').toString() == 'Done' ||
        data['isCompleted'] == true;
    final nextStatus = done ? 'Pending' : 'Done';
    await doc.reference.set({
      'status': nextStatus,
      'isCompleted': nextStatus == 'Done',
      'completedAt': nextStatus == 'Done' ? FieldValue.serverTimestamp() : null,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    final taskId = (data['taskId'] ?? '').toString();
    if (taskId.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('employee_tasks')
          .doc(taskId)
          .set({
            'status': nextStatus,
            'isCompleted': nextStatus == 'Done',
            'completedAt': nextStatus == 'Done'
                ? FieldValue.serverTimestamp()
                : null,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Customer Notes',
            style: TextStyle(
              color: _primary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Add updates and keep a dated history for this customer.',
            style: TextStyle(color: _textMuted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('telecaller_leads')
                .where('executiveCustomerIds', arrayContains: widget.customerId)
                .limit(1)
                .snapshots(),
            builder: (context, snapshot) {
              final leadData = snapshot.data?.docs.isEmpty == false
                  ? snapshot.data!.docs.first.data()
                  : null;
              return _callProgressCard(leadData);
            },
          ),
          TextField(
            controller: _noteController,
            minLines: 3,
            maxLines: 6,
            decoration: InputDecoration(
              hintText: 'Write a note for this customer...',
              hintStyle: const TextStyle(color: _textMuted, fontSize: 12),
              filled: true,
              fillColor: _bg,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: const BorderSide(color: _border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: const BorderSide(color: _accent, width: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Lead status with this note:',
                style: TextStyle(
                  color: _textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              ...['Green', 'Red'].map((status) {
                return ChoiceChip(
                  label: Text(status),
                  avatar: Icon(
                    Icons.circle,
                    size: 10,
                    color: _leadStatusColor(status),
                  ),
                  selected:
                      (_selectedLeadStatus ?? _normalizedLeadStatus) == status,
                  selectedColor: _leadStatusColor(
                    status,
                  ).withValues(alpha: 0.14),
                  onSelected: (_) => setState(() {
                    _selectedLeadStatus = status == _normalizedLeadStatus
                        ? null
                        : status;
                  }),
                );
              }),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _pickScheduleDate,
                icon: const Icon(Icons.calendar_month_rounded, size: 16),
                label: Text(
                  _scheduledAt == null
                      ? 'Set Date'
                      : _formatDateTime(_scheduledAt).split(' ').first,
                ),
              ),
              OutlinedButton.icon(
                onPressed: _pickScheduleTime,
                icon: const Icon(Icons.schedule_rounded, size: 16),
                label: Text(
                  _scheduledAt == null
                      ? 'Set Time'
                      : _formatDateTime(
                          _scheduledAt,
                        ).split(' ').skip(1).join(' '),
                ),
              ),
              if (_scheduledAt != null)
                TextButton.icon(
                  onPressed: () => setState(() => _scheduledAt = null),
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('Clear'),
                ),
              ElevatedButton.icon(
                onPressed: _saving ? null : _saveNote,
                icon: _saving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.note_add_outlined, size: 16),
                label: Text(_saving ? 'Saving...' : 'Save Note'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 26, color: _border),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _notesStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(color: _accent),
                  ),
                );
              }
              if (snapshot.hasError) {
                return const Text(
                  'Unable to load note history.',
                  style: TextStyle(color: _red, fontSize: 12),
                );
              }

              final notes = snapshot.data?.docs.toList() ?? [];
              notes.sort((a, b) {
                final aDate = _date(a.data()['createdAt']);
                final bDate = _date(b.data()['createdAt']);
                return (bDate ?? DateTime(1970)).compareTo(
                  aDate ?? DateTime(1970),
                );
              });

              if (notes.isEmpty) {
                return const Text(
                  'No notes saved yet.',
                  style: TextStyle(color: _textMuted, fontSize: 12),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notes History (${notes.length})',
                    style: const TextStyle(
                      color: _primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...notes.map((doc) {
                    final data = doc.data();
                    final author =
                        (data['createdByName'] ??
                                data['createdByEmail'] ??
                                'Unknown user')
                            .toString();
                    final isTask =
                        data['isTask'] == true ||
                        data['scheduledAt'] != null ||
                        (data['taskId'] ?? '').toString().isNotEmpty;
                    final leadFrom = (data['leadStatusFrom'] ?? '').toString();
                    final leadTo = (data['leadStatusTo'] ?? '').toString();
                    final leadStatus = (data['leadStatus'] ?? '').toString();
                    final done =
                        (data['status'] ?? '').toString() == 'Done' ||
                        data['isCompleted'] == true;
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _bg,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: _border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['note']?.toString() ?? '',
                            style: const TextStyle(
                              color: _textMain,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                          if (leadFrom.isNotEmpty && leadTo.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Lead status changed from $leadFrom to $leadTo',
                              style: const TextStyle(
                                color: _accent,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ] else if (leadStatus.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Lead status kept as $leadStatus',
                              style: const TextStyle(
                                color: _textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                          if (isTask) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Checkbox(
                                  value: done,
                                  activeColor: _green,
                                  onChanged: (_) => _toggleNoteTask(doc),
                                ),
                                Expanded(
                                  child: Text(
                                    'Task ${done ? 'completed' : 'pending'}'
                                    '${data['scheduledAt'] == null ? '' : ' - ${_formatDateTime(data['scheduledAt'])}'}',
                                    style: TextStyle(
                                      color: done ? _green : _accent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 6),
                          Text(
                            'By $author - ${_formatDateTime(data['createdAt'])}',
                            style: const TextStyle(
                              color: _textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// _LinkedPoliciesCard
// ════════════════════════════════════════════════════════════════════════════
class _LinkedPoliciesCard extends StatelessWidget {
  final String customerId;
  final String category;

  static const _primary = Color(0xFF0D2D4F);
  static const _accent = Color(0xFF1A6EBD);
  static const _surface = Color(0xFFFFFFFF);
  static const _border = Color(0xFFE4E7EC);
  static const _textMuted = Color(0xFF8A94A6);
  static const _green = Color(0xFF16A34A);
  static const _amber = Color(0xFFF59E0B);

  const _LinkedPoliciesCard({required this.customerId, required this.category});

  String _fmt(dynamic v) {
    if (v == null) return '-';
    if (v is Timestamp) {
      final d = v.toDate();
      return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
    }
    if (v is DateTime) {
      return '${v.day.toString().padLeft(2, '0')}.${v.month.toString().padLeft(2, '0')}.${v.year}';
    }
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('customer_policies')
          .snapshots(),
      builder: (context, snap) {
        final policies = _policiesForCustomer(
          snap.data?.docs ?? [],
          customerId,
          category,
        );
        if (policies.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: Row(
                  children: [
                    const Text(
                      'All Linked Policies',
                      style: TextStyle(
                        color: _primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${policies.length}',
                        style: const TextStyle(
                          color: _primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: _border),
              ...policies.asMap().entries.map((e) {
                final i = e.key;
                final p = e.value.data();
                final policyNo = p['policyNumber']?.toString() ?? '-';
                final serialNumber = p['serialNumber']?.toString() ?? '';
                final month = p['month']?.toString() ?? '-';
                final issued = _fmt(p['issueDate']);
                final endDate = _fmt(p['policyEndDate']);
                final si = p['sumInsured']?.toString() ?? '-';
                final prem = p['premiumAmount']?.toString() ?? '-';
                final pdfUrl = (p['pdfUrl'] ?? '').toString();
                final pdfFileName = (p['pdfFileName'] ?? 'Policy PDF')
                    .toString();
                final product =
                    p['productName']?.toString() ??
                    p['policyName']?.toString() ??
                    '-';
                final company = p['companyName']?.toString() ?? '-';

                return Column(
                  children: [
                    if (i > 0) const Divider(height: 1, color: _border),
                    Container(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (serialNumber.isNotEmpty) ...[
                            Text(
                              'Policy Serial: $serialNumber',
                              style: const TextStyle(
                                color: _primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: _accent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  policyNo,
                                  style: const TextStyle(
                                    color: _accent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: _amber.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  month,
                                  style: const TextStyle(
                                    color: _amber,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                company,
                                style: const TextStyle(
                                  color: _textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _infoChip(Icons.shield_outlined, '₹$si', _green),
                              const SizedBox(width: 8),
                              _infoChip(
                                Icons.payments_outlined,
                                '₹$prem',
                                _primary,
                              ),
                              const SizedBox(width: 8),
                              _infoChip(
                                Icons.description_outlined,
                                product,
                                _accent,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_outlined,
                                size: 12,
                                color: _textMuted,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Issued: $issued',
                                style: const TextStyle(
                                  color: _textMuted,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Icon(
                                Icons.event_available_outlined,
                                size: 12,
                                color: _textMuted,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Ends: $endDate',
                                style: const TextStyle(
                                  color: _textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          if (pdfUrl.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: () => _openPdfUrl(context, pdfUrl),
                              icon: const Icon(
                                Icons.picture_as_pdf_outlined,
                                size: 14,
                              ),
                              label: Text(pdfFileName),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _infoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _LifeSheetRow {
  final String name;
  final String policyNumber;
  final String month;
  final String issuedDate;
  final String policyEndDate;
  final double sumAssured;
  final double premium;
  final String phone;
  final String product;

  const _LifeSheetRow({
    required this.name,
    required this.policyNumber,
    required this.month,
    required this.issuedDate,
    required this.policyEndDate,
    required this.sumAssured,
    required this.premium,
    required this.phone,
    required this.product,
  });
}
