import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';
import 'tabs/all_customers_tab.dart';
import 'tabs/general_customers_tab.dart';
import 'tabs/agricultural_customers_tab.dart';
import 'tabs/ecgc_customers_tab.dart';
import 'tabs/life_customers_tab.dart';
import 'tabs/active_customers_tab.dart';
import 'tabs/policies_tab.dart';
import 'tabs/general_policies_tab.dart';
import 'tabs/agricultural_policies_tab.dart';
import 'tabs/ecgc_policies_tab.dart';
import 'tabs/life_policies_tab.dart';
import 'tabs/targets_tab.dart';
import 'tabs/agents_tab.dart';
import 'tabs/claims_tab.dart';
import 'tabs/insurance_companies_tab.dart';
import 'tabs/sales_tab.dart';
import 'tabs/agent_performance_tab.dart';
import 'tabs/reports_tab.dart';
import 'tabs/invoices_tab.dart';
import 'tabs/approve_expenses_tab.dart';
import 'tabs/logs_tab.dart';
import 'tabs/renewals_tab.dart';
import 'tabs/company_revenue_tab.dart';
import 'tabs/commission_settlement_tab.dart';
import 'tabs/my_tasks_tab.dart';
import 'tabs/my_performance_tab.dart';
import 'tabs/data_transfer_tab.dart';
import 'tabs/telecaller_leads_tab.dart';
import '../utils/audit_log_service.dart';

const Color _primary = Color(0xFF0D2D4F);
const Color _bg = Color(0xFFF4F6F9);
const Color _surface = Color(0xFFFFFFFF);
const Color _textMain = Color(0xFF0D1B2A);
const Color _textMuted = Color(0xFF8A94A6);
const Color _red = Color(0xFFDC2626);
const Color _accent = Color(0xFF1A6EBD);
const Color _green = Color(0xFF16A34A);
const Color _amber = Color(0xFFF59E0B);
const Color _border = Color(0xFFE4E7EC);

class HomeScreen extends StatefulWidget {
  final Map<String, dynamic> adminData;
  const HomeScreen({super.key, required this.adminData});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _activePageLabel;
  String? _pendingCustomerId;
  late String _userRole;

  static const _categories = [
    _Category(
      title: 'Masters',
      icon: Icons.folder_open_rounded,
      pages: [
        _PageItem(
          'All Companies',
          Icons.business_outlined,
          allowedRoles: ['admin'],
        ),
        _PageItem(
          'All Health insurance Companies & products',
          Icons.health_and_safety_outlined,
          allowedRoles: ['admin'],
        ),
        _PageItem(
          'All Life insurance Companies & products',
          Icons.shield_outlined,
          allowedRoles: ['admin'],
        ),
        _PageItem(
          'All General insurance Companies & products',
          Icons.home_work_outlined,
          allowedRoles: ['admin'],
        ),
        _PageItem(
          'All Agriculture insurance Companies & products',
          Icons.agriculture_outlined,
          allowedRoles: ['admin'],
        ),
        _PageItem(
          'All ECGC insurance Companies & products',
          Icons.public_outlined,
          allowedRoles: ['admin'],
        ),
        _PageItem(
          'Employees',
          Icons.support_agent_outlined,
          allowedRoles: ['admin'],
        ),
      ],
    ),
    _Category(
      title: 'Data',
      icon: Icons.send_to_mobile_outlined,
      pages: [
        _PageItem(
          'DataBank and send data to telecaller',
          Icons.move_to_inbox_outlined,
          allowedRoles: ['admin', 'manager'],
        ),
        _PageItem(
          'Leads and send data to the team',
          Icons.support_agent_outlined,
          allowedRoles: ['admin', 'manager', 'team_leader'],
        ),
        _PageItem(
          'Transfer the leads employee to employee',
          Icons.swap_horiz_rounded,
          allowedRoles: ['admin', 'manager', 'team_leader'],
        ),
      ],
    ),
    _Category(
      title: 'Leads',
      icon: Icons.person_search_outlined,
      pages: [
        _PageItem('Health Leads', Icons.health_and_safety_outlined),
        _PageItem('Life Leads', Icons.shield_outlined),
        _PageItem('General Leads', Icons.home_work_outlined),
        _PageItem('Agriculture Leads', Icons.agriculture_outlined),
        _PageItem('ECGC Leads', Icons.public_outlined),
      ],
    ),

    _Category(
      title: 'Policy Management',
      icon: Icons.assignment_outlined,
      pages: [
        _PageItem(
          'Policy Holders',
          Icons.how_to_reg_outlined,
          allowedRoles: ['admin', 'customer_service'],
        ),
        _PageItem(
          'Claims',
          Icons.inbox_outlined,
          allowedRoles: ['admin', 'agent', 'customer_service'],
        ),
        _PageItem(
          'Renewals',
          Icons.autorenew_rounded,
          allowedRoles: ['admin', 'customer_service', 'agent'],
        ),
      ],
    ),
    _Category(
      title: 'Track',
      icon: Icons.track_changes_rounded,
      pages: [
        _PageItem(
          'My Tasks',
          Icons.task_alt_rounded,
          allowedRoles: ['admin', 'agent', 'customer_service'],
        ),
        _PageItem(
          'My Performance',
          Icons.insights_rounded,
          allowedRoles: ['admin', 'agent', 'customer_service'],
        ),
        _PageItem(
          'Expenses',
          Icons.receipt_long_outlined,
          allowedRoles: ['agent', 'customer_service'],
        ),
        _PageItem(
          'My Assigned Leads',
          Icons.phone_in_talk_outlined,
          allowedRoles: ['telecaller', 'team_leader', 'executive'],
        ),
      ],
    ),
    _Category(
      title: 'Performance Analysis',
      icon: Icons.bar_chart_rounded,
      pages: [
        _PageItem('Sales', Icons.trending_up_rounded, allowedRoles: ['admin']),
        _PageItem(
          'Employee Performance',
          Icons.leaderboard_outlined,
          allowedRoles: ['admin', 'manager', 'team_leader'],
        ),
        _PageItem(
          'Policy Targets',
          Icons.track_changes_rounded,
          allowedRoles: ['admin'],
        ),
      ],
    ),
    _Category(
      title: 'Revenue',
      icon: Icons.currency_rupee_rounded,
      pages: [
        _PageItem(
          'Commission Settlement',
          Icons.account_balance_wallet_outlined,
          allowedRoles: ['admin'],
        ),
        _PageItem(
          'Health Revenue',
          Icons.favorite_border_rounded,
          allowedRoles: ['admin'],
        ),
        _PageItem(
          'Life Revenue',
          Icons.shield_outlined,
          allowedRoles: ['admin'],
        ),
        _PageItem(
          'General Revenue',
          Icons.home_work_outlined,
          allowedRoles: ['admin'],
        ),
        _PageItem(
          'Agriculture Revenue',
          Icons.agriculture_outlined,
          allowedRoles: ['admin'],
        ),
        _PageItem(
          'ECGC Revenue',
          Icons.public_outlined,
          allowedRoles: ['admin'],
        ),
      ],
    ),
    _Category(
      title: 'Account Management',
      icon: Icons.manage_accounts_outlined,
      pages: [
        _PageItem(
          'Invoices',
          Icons.receipt_long_rounded,
          allowedRoles: ['admin'],
        ),
        _PageItem('Reports', Icons.summarize_outlined, allowedRoles: ['admin']),
        _PageItem(
          'Approve Expenses',
          Icons.receipt_long_outlined,
          allowedRoles: ['admin'],
        ),
        _PageItem('Logs', Icons.history_rounded, allowedRoles: ['admin']),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _userRole = (widget.adminData['role'] ?? 'admin').toString().toLowerCase();
  }

  bool _canAccess(_PageItem p) {
    if (_userRole == 'executive' &&
        (p.label == 'Data Transfer Field' ||
            p.label == 'Data Field' ||
            p.label.endsWith(' Customers'))) {
      return false;
    }
    final permissionRole =
        const {
          'telecaller',
          'executive',
          'team_leader',
          'manager',
        }.contains(_userRole)
        ? 'agent'
        : _userRole;
    if (p.allowedRoles == null ||
        p.allowedRoles!.contains(_userRole) ||
        p.allowedRoles!.contains(permissionRole)) {
      return true;
    }
    return _userRole == 'super_admin' && p.allowedRoles!.contains('admin');
  }

  Widget _buildPageWidget(String label) {
    final d = widget.adminData;
    switch (label) {
      case 'Employee Performance':
        return AgentPerformanceTab(adminData: d);
      case 'Policy Targets':
        return TargetsTab(adminData: d);
      case 'Health Leads':
        return AllCustomersTab(
          currentUser: d,
          title: 'Health Leads',
          initialView: 'Leads',
          lockView: true,
        );
      case 'Life Leads':
        return LifeCustomersTab(
          currentUser: d,
          title: 'Life Leads',
          initialView: 'Leads',
          lockView: true,
        );
      case 'General Leads':
        return GeneralCustomersTab(
          currentUser: d,
          title: 'General Leads',
          initialView: 'Leads',
          lockView: true,
        );
      case 'Agriculture Leads':
        return AgricultureCustomersTab(
          currentUser: d,
          title: 'Agriculture Leads',
          initialView: 'Leads',
          lockView: true,
        );
      case 'ECGC Leads':
        return EcgcCustomersTab(
          currentUser: d,
          title: 'ECGC Leads',
          initialView: 'Leads',
          lockView: true,
        );
      case 'Health Customers':
        final pendingCustomerId = _takePendingCustomerId('Health Customers');
        return AllCustomersTab(
          currentUser: d,
          title: 'Health Customers',
          initialView: 'Policy Holders',
          lockView: true,
          initialCustomerId: pendingCustomerId,
          onBackToPolicyHolders: pendingCustomerId == null
              ? null
              : _returnToPolicyHolders,
        );
      case 'Life Customers':
        final pendingCustomerId = _takePendingCustomerId('Life Customers');
        return LifeCustomersTab(
          currentUser: d,
          title: 'Life Customers',
          initialView: 'Policy Holders',
          lockView: true,
          initialCustomerId: pendingCustomerId,
          onBackToPolicyHolders: pendingCustomerId == null
              ? null
              : _returnToPolicyHolders,
        );
      case 'General Customers':
        final pendingCustomerId = _takePendingCustomerId('General Customers');
        return GeneralCustomersTab(
          currentUser: d,
          title: 'General Customers',
          initialView: 'Policy Holders',
          lockView: true,
          initialCustomerId: pendingCustomerId,
          onBackToPolicyHolders: pendingCustomerId == null
              ? null
              : _returnToPolicyHolders,
        );
      case 'Agriculture Customers':
        final pendingCustomerId = _takePendingCustomerId(
          'Agriculture Customers',
        );
        return AgricultureCustomersTab(
          currentUser: d,
          title: 'Agriculture Customers',
          initialView: 'Policy Holders',
          lockView: true,
          initialCustomerId: pendingCustomerId,
          onBackToPolicyHolders: pendingCustomerId == null
              ? null
              : _returnToPolicyHolders,
        );
      case 'ECGC Customers':
        final pendingCustomerId = _takePendingCustomerId('ECGC Customers');
        return EcgcCustomersTab(
          currentUser: d,
          title: 'ECGC Customers',
          initialView: 'Policy Holders',
          lockView: true,
          initialCustomerId: pendingCustomerId,
          onBackToPolicyHolders: pendingCustomerId == null
              ? null
              : _returnToPolicyHolders,
        );
      case 'Policy Holders':
        return ActiveCustomersTab(
          onOpenCustomerNotes: _openCustomerNotesFromPolicy,
        );
      case 'Health Insurance':
      case 'All Health insurance Companies & products':
        return const PoliciesTab(
          title: 'All Health insurance Companies & products',
        );
      case 'General Insurance':
      case 'All General insurance Companies & products':
        return const GeneralPoliciesTab(
          title: 'All General insurance Companies & products',
        );
      case 'Agriculture Insurance':
      case 'All Agriculture insurance Companies & products':
        return const AgriculturePoliciesTab(
          title: 'All Agriculture insurance Companies & products',
        );
      case 'ECGC Insurance':
      case 'All ECGC insurance Companies & products':
        return const EcgcPoliciesTab(
          title: 'All ECGC insurance Companies & products',
        );
      case 'Life Insurance':
      case 'All Life insurance Companies & products':
        return const LifePoliciesTab(
          title: 'All Life insurance Companies & products',
        );
      case 'Claims':
        return ClaimsTab(currentUser: d);
      case 'Employees':
        return const AgentsTab();
      case 'All Companies':
      case 'Insurance Companies':
        return const InsuranceCompaniesTab();
      case 'Sales':
        return SalesTab(userData: d);
      case 'Health Revenue':
        return const CompanyRevenueTab(
          key: ValueKey('Health Revenue'),
          category: 'Health',
          title: 'Health Revenue',
        );
      case 'Life Revenue':
        return const CompanyRevenueTab(
          key: ValueKey('Life Revenue'),
          category: 'Life',
          title: 'Life Revenue',
        );
      case 'General Revenue':
        return const CompanyRevenueTab(
          key: ValueKey('General Revenue'),
          category: 'General',
          title: 'General Revenue',
        );
      case 'Agriculture Revenue':
        return const CompanyRevenueTab(
          key: ValueKey('Agriculture Revenue'),
          category: 'Agriculture',
          title: 'Agriculture Revenue',
        );
      case 'ECGC Revenue':
        return const CompanyRevenueTab(
          key: ValueKey('ECGC Revenue'),
          category: 'ECGC',
          title: 'ECGC Revenue',
        );
      case 'Commission Settlement':
        return const CommissionSettlementTab();
      case 'Reports':
        return ReportsTab(userData: d);
      case 'Invoices':
        return const InvoicesTab();
      case 'Approve Expenses':
        return ApproveExpensesTab(userData: d);
      case 'Expenses':
        return ApproveExpensesTab(userData: d);
      case 'Logs':
        return const LogsTab();
      case 'Renewals':
        return RenewalsTab(userData: d);
      case 'My Tasks':
        return MyTasksTab(userData: d);
      case 'My Performance':
        return MyPerformanceTab(userData: d);
      case 'Import Data':
      case 'DataBank':
      case 'DataBank and send data to telecaller':
      case 'Import & Assign Data':
        return DataTransferTab(userData: d, page: DataTransferPage.importData);
      case 'Assign Data':
      case 'Send data to telecallers':
      case 'Leads and send data to the team':
      case 'Assign Leads':
      case 'Data Field':
      case 'Data Transfer Field':
        return DataTransferTab(userData: d, page: DataTransferPage.assignData);
      case 'Transfer the leads employee to employee':
        return DataTransferTab(
          userData: d,
          page: DataTransferPage.transferLeads,
        );
      case 'My Assigned Leads':
        return _roleDashboard();
      default:
        return const Center(child: Text('Page not found'));
    }
  }

  Widget _roleDashboard() {
    if (_userRole == 'telecaller') {
      return TelecallerLeadsDashboard(userData: widget.adminData);
    }
    if (_userRole == 'team_leader' || _userRole == 'executive') {
      return ForwardedLeadsDashboard(
        userData: widget.adminData,
        role: _userRole,
      );
    }
    return _SimpleHomeDashboard(userData: widget.adminData);
  }

  String? _takePendingCustomerId(String label) {
    if (_activePageLabel != label) return null;
    final id = _pendingCustomerId;
    _pendingCustomerId = null;
    return id;
  }

  void _openCustomerNotesFromPolicy({
    required String customerId,
    required String category,
  }) {
    final normalized = category.toLowerCase();
    final label = normalized == 'life'
        ? 'Life Customers'
        : normalized == 'general'
        ? 'General Customers'
        : normalized == 'agriculture' || normalized == 'agricultural'
        ? 'Agriculture Customers'
        : normalized == 'ecgc'
        ? 'ECGC Customers'
        : 'Health Customers';
    setState(() {
      _pendingCustomerId = customerId;
      _activePageLabel = label;
    });
  }

  void _returnToPolicyHolders() {
    setState(() {
      _pendingCustomerId = null;
      _activePageLabel = 'Policy Holders';
    });
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.adminData['name'] ?? 'Admin';
    final role = widget.adminData['role'] ?? 'admin';
    final isWide = MediaQuery.of(context).size.width > 700;

    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          _BrandBar(
            name: name,
            role: role,
            isWide: isWide,
            userData: widget.adminData,
            onLogout: () async {
              final ok = await _showLogoutDialog();
              if (ok == true && mounted) {
                await FirebaseAuth.instance.signOut();
                if (mounted) {
                  Navigator.pushReplacement(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (_, __, ___) => const LoginScreen(),
                      transitionsBuilder: (_, a, __, child) =>
                          FadeTransition(opacity: a, child: child),
                      transitionDuration: const Duration(milliseconds: 300),
                    ),
                  );
                }
              }
            },
          ),
          if (_userRole != 'telecaller') ...[
            _CategoryNavBar(
              categories: _categories,
              canAccess: _canAccess,
              activePageLabel: _activePageLabel,
              onHomeSelected: () => setState(() => _activePageLabel = null),
              onPageSelected: (label) =>
                  setState(() => _activePageLabel = label),
            ),
            const Divider(height: 1, color: _border),
          ],
          Expanded(
            child: _activePageLabel == null
                ? _roleDashboard()
                : _buildPageWidget(_activePageLabel!),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showLogoutDialog() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Sign out',
          style: TextStyle(
            color: _textMain,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: const Text(
          'Are you sure you want to sign out?',
          style: TextStyle(color: _textMuted, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: _textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _red,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

class _BrandBar extends StatelessWidget {
  final String name, role;
  final bool isWide;
  final Map<String, dynamic> userData;
  final VoidCallback onLogout;

  const _BrandBar({
    required this.name,
    required this.role,
    required this.isWide,
    required this.userData,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 520;
    return Container(
      color: _primary,
      padding: EdgeInsets.fromLTRB(
        isWide
            ? 34
            : compact
            ? 10
            : 14,
        MediaQuery.of(context).padding.top +
            (isWide
                ? 14
                : compact
                ? 7
                : 10),
        isWide
            ? 20
            : compact
            ? 6
            : 10,
        isWide
            ? 14
            : compact
            ? 7
            : 10,
      ),
      child: Row(
        children: [
          Container(
            width: isWide
                ? 260
                : compact
                ? 116
                : 154,
            height: isWide
                ? 76
                : compact
                ? 38
                : 50,
            padding: EdgeInsets.symmetric(
              horizontal: isWide
                  ? 18
                  : compact
                  ? 7
                  : 10,
              vertical: isWide
                  ? 9
                  : compact
                  ? 5
                  : 7,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(compact ? 7 : 10),
            ),
            child: Image.asset(
              'assets/images/Makk-Finsol-logo.png',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
          SizedBox(width: compact ? 6 : 12),
          if (!compact)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(5),
              ),
              child: const Text(
                'Insurance Management',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          const Spacer(),
          if (isWide) ...[
            Text(
              name,
              style: const TextStyle(color: Colors.white60, fontSize: 13),
            ),
            const SizedBox(width: 10),
          ],
          Container(
            constraints: BoxConstraints(maxWidth: compact ? 88 : 150),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 7 : 10,
              vertical: compact ? 2 : 3,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              role.replaceAll('_', ' ').toUpperCase(),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(width: compact ? 4 : 10),
          _NotificationBell(userData: userData),
          SizedBox(width: compact ? 3 : 8),
          if (!compact)
            CircleAvatar(
              radius: 15,
              backgroundColor: Colors.white.withOpacity(0.12),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'A',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          SizedBox(width: compact ? 0 : 2),
          IconButton(
            constraints: BoxConstraints.tightFor(
              width: compact ? 34 : 40,
              height: compact ? 34 : 40,
            ),
            padding: EdgeInsets.zero,
            icon: const Icon(
              Icons.logout_rounded,
              color: Colors.white38,
              size: 18,
            ),
            tooltip: 'Sign out',
            splashRadius: 18,
            onPressed: onLogout,
          ),
        ],
      ),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  final Map<String, dynamic> userData;
  const _NotificationBell({required this.userData});

  bool get _isAdmin => const {
    'admin',
    'super_admin',
  }.contains((userData['role'] ?? '').toString().toLowerCase());

  String get _readKey {
    final id = (userData['_profileDocId'] ?? userData['uid'] ?? '').toString();
    if (id.isNotEmpty) return id;
    final email = (userData['email'] ?? '').toString();
    return email.isNotEmpty ? email : 'admin';
  }

  bool _visibleToUser(Map<String, dynamic> data) {
    if (_isAdmin) return true;
    final audience = (data['audience'] ?? 'all_employees').toString();
    if (audience == 'all_employees') return true;
    final employeeId = (userData['_profileDocId'] ?? userData['uid'] ?? '')
        .toString();
    return (data['employeeId'] ?? '').toString() == employeeId;
  }

  bool _isRead(Map<String, dynamic> data) {
    final readBy = data['readBy'];
    return readBy is List && readBy.map((e) => e.toString()).contains(_readKey);
  }

  Future<void> _markRead(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final unread = docs.where((doc) => !_isRead(doc.data())).toList();
    if (unread.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in unread) {
      batch.update(doc.reference, {
        'readBy': FieldValue.arrayUnion([_readKey]),
      });
    }
    await batch.commit();
  }

  DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  String _fmt(dynamic value) {
    final d = _date(value);
    if (d == null) return '';
    final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final suffix = d.hour >= 12 ? 'PM' : 'AM';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} '
        '$hour:${d.minute.toString().padLeft(2, '0')} $suffix';
  }

  Future<void> _sendMessage(BuildContext context) async {
    final title = TextEditingController();
    final message = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        var saving = false;
        return StatefulBuilder(
          builder: (ctx, setS) => AlertDialog(
            title: const Text('Send message'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: message,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Message to all employees',
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
                        final text = message.text.trim();
                        if (text.isEmpty) return;
                        setS(() => saving = true);
                        await FirebaseFirestore.instance
                            .collection('messages')
                            .add({
                              'title': title.text.trim().isEmpty
                                  ? 'Admin message'
                                  : title.text.trim(),
                              'message': text,
                              'audience': 'all_employees',
                              'createdAt': FieldValue.serverTimestamp(),
                              'createdBy': userData['email'] ?? '',
                              'createdByName': userData['name'] ?? 'Admin',
                              'readBy': [_readKey],
                            });
                        await AuditLogService.write(
                          page: 'Notifications',
                          action: 'Sent Message',
                          description:
                              'Sent message "${title.text.trim().isEmpty ? 'Admin message' : title.text.trim()}" to all employees.',
                          targetType: 'Message',
                          targetName: title.text.trim().isEmpty
                              ? 'Admin message'
                              : title.text.trim(),
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Message sent to employees'),
                            backgroundColor: _accent,
                          ),
                        );
                      },
                icon: const Icon(Icons.send_rounded, size: 16),
                label: Text(saving ? 'Sending...' : 'Send'),
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

  void _showNotifications(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    _markRead(docs);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Notifications',
                      style: TextStyle(
                        color: _textMain,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (_isAdmin)
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _sendMessage(context);
                      },
                      icon: const Icon(Icons.campaign_outlined, size: 16),
                      label: const Text('Send'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (docs.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No notifications yet.',
                    style: TextStyle(color: _textMuted),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: docs.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: _border),
                    itemBuilder: (_, i) {
                      final data = docs[i].data();
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (data['title'] ?? 'Message').toString(),
                              style: const TextStyle(
                                color: _textMain,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              (data['message'] ?? '').toString(),
                              style: const TextStyle(
                                color: _textMuted,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _fmt(data['createdAt']),
                              style: const TextStyle(
                                color: _textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('messages').snapshots(),
      builder: (context, snap) {
        final docs =
            (snap.data?.docs ?? [])
                .where((doc) => _visibleToUser(doc.data()))
                .toList()
              ..sort((a, b) {
                final ad = _date(a.data()['createdAt']) ?? DateTime(1900);
                final bd = _date(b.data()['createdAt']) ?? DateTime(1900);
                return bd.compareTo(ad);
              });
        final latest = docs.take(20).toList();
        final unreadCount = docs.where((doc) => !_isRead(doc.data())).length;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              tooltip: 'Notifications',
              icon: const Icon(
                Icons.notifications_none_rounded,
                color: Colors.white70,
                size: 20,
              ),
              splashRadius: 18,
              onPressed: () => _showNotifications(context, latest),
            ),
            if (unreadCount > 0)
              Positioned(
                right: 7,
                top: 7,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 16),
                  height: 16,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: _red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    unreadCount > 9 ? '9+' : '$unreadCount',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CategoryNavBar extends StatefulWidget {
  final List<_Category> categories;
  final bool Function(_PageItem) canAccess;
  final String? activePageLabel;
  final VoidCallback onHomeSelected;
  final ValueChanged<String> onPageSelected;

  const _CategoryNavBar({
    required this.categories,
    required this.canAccess,
    required this.activePageLabel,
    required this.onHomeSelected,
    required this.onPageSelected,
  });

  @override
  State<_CategoryNavBar> createState() => _CategoryNavBarState();
}

class _CategoryNavBarState extends State<_CategoryNavBar> {
  int? _openIndex;
  OverlayEntry? _overlayEntry;
  late final List<GlobalKey> _keys;

  @override
  void initState() {
    super.initState();
    _keys = List.generate(widget.categories.length, (_) => GlobalKey());
  }

  int? _activeCategoryIndex() {
    if (widget.activePageLabel == null) return null;
    for (int i = 0; i < widget.categories.length; i++) {
      if (widget.categories[i].pages.any(
        (p) => p.label == widget.activePageLabel,
      )) {
        return i;
      }
    }
    return null;
  }

  void _openDropdown(int index) {
    _closeDropdown();
    final keyContext = _keys[index].currentContext;
    if (keyContext == null) return;
    final box = keyContext.findRenderObject() as RenderBox;
    final offset = box.localToGlobal(Offset.zero);
    final size = box.size;
    _openIndex = index;
    _overlayEntry = OverlayEntry(
      builder: (_) => Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: offset.dy + size.height,
            bottom: 0,
            child: GestureDetector(
              onTap: _closeDropdown,
              behavior: HitTestBehavior.translucent,
              child: const ColoredBox(color: Colors.transparent),
            ),
          ),
          Positioned(
            left: offset.dx,
            top: offset.dy + size.height,
            child: _DropdownCard(
              category: widget.categories[index],
              canAccess: widget.canAccess,
              activePageLabel: widget.activePageLabel,
              onPageSelected: (label) {
                _closeDropdown();
                widget.onPageSelected(label);
              },
            ),
          ),
        ],
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
    setState(() {});
  }

  void _closeDropdown() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) setState(() => _openIndex = null);
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeCatIdx = _activeCategoryIndex();
    return Material(
      color: _surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const SizedBox(width: 16),
            _HomeNavItem(
              isActive: widget.activePageLabel == null,
              onHover: _closeDropdown,
              onTap: () {
                _closeDropdown();
                widget.onHomeSelected();
              },
            ),
            ...List.generate(widget.categories.length, (i) {
              final cat = widget.categories[i];
              final pages = cat.pages.where(widget.canAccess).toList();
              if (pages.isEmpty) return const SizedBox.shrink();
              return _NavItem(
                key: _keys[i],
                category: cat,
                isActive: activeCatIdx == i,
                isOpen: _openIndex == i,
                onHover: () {
                  if (pages.length == 1) {
                    _closeDropdown();
                  } else if (_openIndex != i) {
                    _openDropdown(i);
                  }
                },
                onTap: () {
                  if (pages.length == 1) {
                    _closeDropdown();
                    widget.onPageSelected(pages.first.label);
                  } else if (_openIndex == i) {
                    _closeDropdown();
                  } else {
                    _openDropdown(i);
                  }
                },
              );
            }),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }
}

class _HomeNavItem extends StatelessWidget {
  final bool isActive;
  final VoidCallback onHover;
  final VoidCallback onTap;

  const _HomeNavItem({
    required this.isActive,
    required this.onHover,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => onHover(),
      child: Semantics(
        button: true,
        selected: isActive,
        label: 'Home dashboard',
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isActive ? _accent : Colors.transparent,
                  width: 2.5,
                ),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.home_outlined,
                  size: 16,
                  color: isActive ? _accent : _textMuted,
                ),
                const SizedBox(width: 7),
                Text(
                  'Home',
                  style: TextStyle(
                    color: isActive ? _accent : _textMuted,
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final _Category category;
  final bool isActive;
  final bool isOpen;
  final VoidCallback onHover;
  final VoidCallback onTap;

  const _NavItem({
    super.key,
    required this.category,
    required this.isActive,
    required this.isOpen,
    required this.onHover,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final on = isActive || isOpen;
    return MouseRegion(
      onEnter: (_) => onHover(),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: on ? _accent : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(category.icon, size: 15, color: on ? _accent : _textMuted),
              const SizedBox(width: 7),
              Text(
                category.title,
                style: TextStyle(
                  color: on ? _accent : _textMuted,
                  fontSize: 13,
                  fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                isOpen
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: on ? _accent : _textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DropdownCard extends StatelessWidget {
  final _Category category;
  final bool Function(_PageItem) canAccess;
  final String? activePageLabel;
  final ValueChanged<String> onPageSelected;

  const _DropdownCard({
    required this.category,
    required this.canAccess,
    required this.activePageLabel,
    required this.onPageSelected,
  });

  @override
  Widget build(BuildContext context) {
    final pages = category.pages.where(canAccess).toList();
    return Material(
      elevation: 12,
      borderRadius: BorderRadius.circular(12),
      shadowColor: Colors.black.withOpacity(0.15),
      child: Container(
        width: 230,
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 6),
            ...pages.map((page) {
              final isActive = activePageLabel == page.label;
              return InkWell(
                onTap: () => onPageSelected(page.label),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? _accent.withOpacity(0.06)
                        : Colors.transparent,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        page.icon,
                        size: 15,
                        color: isActive ? _accent : _textMuted,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          page.label,
                          style: TextStyle(
                            color: isActive ? _accent : _textMain,
                            fontSize: 13,
                            fontWeight: isActive
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (isActive)
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: _accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

class _SimpleHomeDashboard extends StatelessWidget {
  final Map<String, dynamic> userData;

  const _SimpleHomeDashboard({required this.userData});

  String get _name =>
      (userData['name'] ?? userData['username'] ?? userData['email'] ?? 'there')
          .toString()
          .trim();

  String get _employeeId =>
      (userData['_profileDocId'] ?? userData['uid'] ?? '').toString().trim();

  String get _role => (userData['role'] ?? '').toString().toLowerCase();

  bool get _isAdmin => _role == 'admin' || _role == 'super_admin';

  bool get _showTaskList => _role != 'telecaller' && _role != 'executive';

  Stream<QuerySnapshot<Map<String, dynamic>>> _tasks() {
    final tasks = FirebaseFirestore.instance.collection('employee_tasks');
    if (_isAdmin) return tasks.snapshots();
    if (_employeeId.isNotEmpty) {
      return tasks.where('employeeId', isEqualTo: _employeeId).snapshots();
    }
    return tasks.where('employeeName', isEqualTo: _name).snapshots();
  }

  DateTime? _taskDate(Map<String, dynamic> data) {
    final value = data['taskDateTime'] ?? data['taskDate'];
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse((value ?? '').toString());
  }

  bool _isOpen(Map<String, dynamic> data) {
    final status = (data['status'] ?? 'Pending').toString().toLowerCase();
    return status != 'completed' &&
        status != 'done' &&
        status != 'cancelled' &&
        status != 'canceled';
  }

  String _dateLabel(DateTime? date) {
    if (date == null) return 'No date';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final difference = day.difference(today).inDays;
    final prefix = difference == 0
        ? 'Today'
        : difference == 1
        ? 'Tomorrow'
        : '${date.day}/${date.month}/${date.year}';
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final suffix = date.hour >= 12 ? 'PM' : 'AM';
    return '$prefix · $hour:$minute $suffix';
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 700;
    if (!_showTaskList) {
      return ColoredBox(
        color: _bg,
        child: ListView(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 16 : 32,
            vertical: compact ? 20 : 30,
          ),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1040),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: EdgeInsets.all(compact ? 22 : 32),
                      decoration: BoxDecoration(
                        color: _primary,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: compact
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: _welcomeContent(compact),
                            )
                          : Row(
                              children: [
                                Container(
                                  width: 190,
                                  height: 76,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Image.asset(
                                    'assets/images/Makk-Finsol-logo.png',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                const SizedBox(width: 28),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: _welcomeText(),
                                  ),
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 20),
                    _assignmentNewsCard(),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ColoredBox(
      color: _bg,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _tasks(),
        builder: (context, snapshot) {
          final tasks =
              (snapshot.data?.docs ?? [])
                  .where((doc) => _isOpen(doc.data()))
                  .toList()
                ..sort((a, b) {
                  final aDate = _taskDate(a.data());
                  final bDate = _taskDate(b.data());
                  if (aDate == null && bDate == null) return 0;
                  if (aDate == null) return 1;
                  if (bDate == null) return -1;
                  return aDate.compareTo(bDate);
                });

          return ListView(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 16 : 32,
              vertical: compact ? 20 : 30,
            ),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1040),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: EdgeInsets.all(compact ? 22 : 32),
                        decoration: BoxDecoration(
                          color: _primary,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: compact
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: _welcomeContent(compact),
                              )
                            : Row(
                                children: [
                                  Container(
                                    width: 190,
                                    height: 76,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Image.asset(
                                      'assets/images/Makk-Finsol-logo.png',
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                  const SizedBox(width: 28),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: _welcomeText(),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: _border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Padding(
                              padding: EdgeInsets.fromLTRB(22, 20, 22, 16),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.task_alt_rounded,
                                    size: 21,
                                    color: _accent,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'Tasks',
                                    style: TextStyle(
                                      color: _textMain,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1, color: _border),
                            if (snapshot.connectionState ==
                                ConnectionState.waiting)
                              const Padding(
                                padding: EdgeInsets.all(28),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: _accent,
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            else if (snapshot.hasError)
                              const Padding(
                                padding: EdgeInsets.all(24),
                                child: Text(
                                  'Tasks could not be loaded.',
                                  style: TextStyle(color: _textMuted),
                                ),
                              )
                            else if (tasks.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(28),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.check_circle_outline_rounded,
                                      color: _green,
                                      size: 30,
                                    ),
                                    SizedBox(height: 10),
                                    Text(
                                      'You are all caught up.',
                                      style: TextStyle(
                                        color: _textMain,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              ...tasks.map((doc) => _taskRow(doc.data())),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _welcomeContent(bool compact) => [
    Container(
      width: 170,
      height: 68,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Image.asset(
        'assets/images/Makk-Finsol-logo.png',
        fit: BoxFit.contain,
      ),
    ),
    const SizedBox(height: 22),
    ..._welcomeText(),
  ];

  List<Widget> _welcomeText() => [
    Text(
      'Hello, ${_name.isEmpty ? 'there' : _name}',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 27,
        fontWeight: FontWeight.w900,
      ),
    ),
    const SizedBox(height: 8),
    const Text(
      'Makk Finsol brings insurance service, policy coordination, claims, renewals, and team follow-ups into one organized workspace.',
      style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.55),
    ),
  ];

  Widget _assignmentNewsCard() {
    final label = _role == 'telecaller' ? 'Leads' : 'Green Leads';
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.notifications_active_outlined,
              color: _accent,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'New leads may be assigned to you',
                  style: TextStyle(
                    color: _textMain,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Open $label to view assigned leads and continue your work.',
                  style: const TextStyle(color: _textMuted, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _taskRow(Map<String, dynamic> data) {
    final date = _taskDate(data);
    final note = (data['note'] ?? data['title'] ?? 'Task').toString();
    final employee = (data['employeeName'] ?? '').toString().trim();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 5),
            decoration: const BoxDecoration(
              color: _accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note,
                  style: const TextStyle(
                    color: _textMain,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _isAdmin && employee.isNotEmpty
                      ? '${_dateLabel(date)} · $employee'
                      : _dateLabel(date),
                  style: const TextStyle(color: _textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  final String name;
  const _WelcomePage({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bg,
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.07),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.dashboard_outlined,
              color: _primary,
              size: 30,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Welcome back, $name 👋',
            style: const TextStyle(
              color: _textMain,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Select a category from the navigation bar above\nto get started.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _textMuted, fontSize: 14, height: 1.6),
          ),
        ],
      ),
    );
  }
}

class _EmployeeDashboardOverview extends StatelessWidget {
  final Map<String, dynamic> userData;
  const _EmployeeDashboardOverview({required this.userData});

  String get _employeeId =>
      (userData['_profileDocId'] ?? userData['uid'] ?? '').toString();

  String get _employeeName =>
      (userData['name'] ??
              userData['username'] ??
              userData['email'] ??
              'Employee')
          .toString();

  bool _ownedByUser(Map<String, dynamic> data) {
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

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse((value ?? '').toString());
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('customers').snapshots(),
      builder: (context, customerSnap) {
        final customers = (customerSnap.data?.docs ?? [])
            .where((doc) => _ownedByUser(doc.data()))
            .toList();
        final customerIds = customers.map((doc) => doc.id).toSet();
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('customer_policies')
              .snapshots(),
          builder: (context, policySnap) {
            final policies = (policySnap.data?.docs ?? []).where((doc) {
              final customerId = (doc.data()['customerId'] ?? '').toString();
              return customerIds.contains(customerId);
            }).toList();
            final healthPolicies = policies
                .where(
                  (doc) =>
                      (doc.data()['category'] ?? '').toString().toLowerCase() ==
                      'health',
                )
                .length;
            final lifePolicies = policies
                .where(
                  (doc) =>
                      (doc.data()['category'] ?? '').toString().toLowerCase() ==
                      'life',
                )
                .length;
            final generalPolicies = policies
                .where(
                  (doc) =>
                      (doc.data()['category'] ?? '').toString().toLowerCase() ==
                      'general',
                )
                .length;
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('employee_tasks')
                  .where('employeeId', isEqualTo: _employeeId)
                  .snapshots(),
              builder: (context, taskSnap) {
                final todayKey = _dateKey(DateTime.now());
                final todayTasks = (taskSnap.data?.docs ?? []).where((doc) {
                  final data = doc.data();
                  final key = (data['dateKey'] ?? '').toString();
                  if (key.isNotEmpty) return key == todayKey;
                  final date = _date(data['taskDateTime']);
                  return date != null && _dateKey(date) == todayKey;
                }).toList();

                return Container(
                  color: _bg,
                  width: double.infinity,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text(
                        'Welcome back, $_employeeName',
                        style: const TextStyle(
                          color: _textMain,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Your customers, policies, and tasks for today.',
                        style: TextStyle(color: _textMuted, fontSize: 13),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _OverviewMetricCard(
                            'My customers',
                            '${customers.length}',
                            Icons.people_outline_rounded,
                            _primary,
                          ),
                          _OverviewMetricCard(
                            'Health policies',
                            '$healthPolicies',
                            Icons.health_and_safety_outlined,
                            _green,
                          ),
                          _OverviewMetricCard(
                            'Life policies',
                            '$lifePolicies',
                            Icons.shield_outlined,
                            _accent,
                          ),
                          _OverviewMetricCard(
                            'General policies',
                            '$generalPolicies',
                            Icons.home_work_outlined,
                            _amber,
                          ),
                          _OverviewMetricCard(
                            'Today tasks',
                            '${todayTasks.length}',
                            Icons.task_alt_rounded,
                            _red,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'Today tasks',
                                style: TextStyle(
                                  color: _textMain,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const Divider(height: 1, color: _border),
                            if (todayTasks.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(16),
                                child: Text(
                                  'No tasks scheduled for today.',
                                  style: TextStyle(color: _textMuted),
                                ),
                              )
                            else
                              ...todayTasks.map((doc) {
                                final data = doc.data();
                                final date = _date(data['taskDateTime']);
                                final time = date == null
                                    ? ''
                                    : '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 70,
                                        child: Text(
                                          time,
                                          style: const TextStyle(
                                            color: _accent,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          (data['note'] ?? '').toString(),
                                          style: const TextStyle(
                                            color: _textMain,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
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

class _DashboardOverview extends StatefulWidget {
  final String name;
  const _DashboardOverview({required this.name});

  @override
  State<_DashboardOverview> createState() => _DashboardOverviewState();
}

class _DashboardOverviewState extends State<_DashboardOverview> {
  Future<_DashboardMetrics> _loadMetrics() async {
    final db = FirebaseFirestore.instance;
    final results = await Future.wait([
      db.collection('customers').get(),
      db.collection('customer_policies').get(),
      db.collection('claims').get(),
      db.collection('agents').get(),
      db.collection('insurance_companies').get(),
      db.collection('employee_tasks').get(),
    ]);

    final customers = results[0].docs;
    final customerPolicies = results[1].docs;
    final claims = results[2].docs;
    final agents = results[3].docs;
    final companies = results[4].docs;
    final tasks = results[5].docs;
    final now = DateTime.now();
    final dueLimit = now.add(const Duration(days: 60));
    final activeCustomerIds = customers.map((doc) => doc.id).toSet();
    final validCustomerPolicies = customerPolicies.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final customerId = (data['customerId'] ?? '').toString().trim();
      return customerId.isNotEmpty && activeCustomerIds.contains(customerId);
    }).toList();
    final linkedPolicyIds = <String>{};
    for (final doc in validCustomerPolicies) {
      linkedPolicyIds.add(doc.id);
    }
    final visibleClaims = claims.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final customerId = (data['customerId'] ?? '').toString().trim();
      if (customerId.isEmpty || !activeCustomerIds.contains(customerId)) {
        return false;
      }
      final policyDocId = (data['policyDocId'] ?? '').toString().trim();
      return policyDocId.isNotEmpty && linkedPolicyIds.contains(policyDocId);
    }).toList();

    final todayKey = _dateKey(now);
    final todayTasks = tasks.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final key = (data['dateKey'] ?? '').toString();
      if (key.isNotEmpty) return key == todayKey;
      final date = _date(data['taskDateTime']);
      return date != null && _dateKey(date) == todayKey;
    }).length;

    final pendingTasks = tasks.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final status = (data['status'] ?? 'Pending').toString().toLowerCase();
      return status != 'completed' && status != 'done' && status != 'cancelled';
    }).length;

    final dueRenewals = validCustomerPolicies.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final end = _date(data['policyEndDate']);
      if (end == null) return false;
      final status = (data['renewalStatus'] ?? '').toString().toLowerCase();
      return status != 'renewed' &&
          end.isAfter(now.subtract(const Duration(days: 1))) &&
          end.isBefore(dueLimit);
    }).length;

    final expiredPolicies = validCustomerPolicies.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final end = _date(data['policyEndDate']);
      if (end == null) return false;
      return end.isBefore(now) &&
          (data['renewalStatus'] ?? '').toString().toLowerCase() != 'renewed';
    }).length;

    final openClaims = visibleClaims.where((doc) {
      final status = (doc.data() as Map<String, dynamic>)['claimStatus'] ?? '';
      return status.toString().toLowerCase() != 'approved' &&
          status.toString().toLowerCase() != 'rejected';
    }).length;

    final activeAgents = agents.where((doc) {
      return ((doc.data() as Map<String, dynamic>)['status'] ?? 'Active')
              .toString()
              .toLowerCase() ==
          'active';
    }).length;

    final policyHolderIds = validCustomerPolicies
        .map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return (data['customerId'] ?? '').toString().trim();
        })
        .where((id) => id.isNotEmpty)
        .toSet();
    final leadCount = customers
        .where((doc) => !policyHolderIds.contains(doc.id))
        .length;

    return _DashboardMetrics(
      customerCount: leadCount,
      policyHolderCount: policyHolderIds.length,
      policyCount: validCustomerPolicies.length,
      claimCount: visibleClaims.length,
      openClaimCount: openClaims,
      agentCount: agents.length,
      activeAgentCount: activeAgents,
      companyCount: companies.length,
      todayTaskCount: todayTasks,
      pendingTaskCount: pendingTasks,
      dueRenewalCount: dueRenewals,
      expiredPolicyCount: expiredPolicies,
    );
  }

  static DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse((value ?? '').toString());
  }

  static String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DashboardMetrics>(
      future: _loadMetrics(),
      builder: (context, snap) {
        final metrics = snap.data;
        return Container(
          color: _bg,
          width: double.infinity,
          child: RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back, ${widget.name}',
                            style: const TextStyle(
                              color: _textMain,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Today\'s insurance operations, tasks, renewals, and claims in one view.',
                            style: TextStyle(color: _textMuted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Refresh dashboard',
                      onPressed: () => setState(() {}),
                      icon: const Icon(Icons.refresh_rounded, color: _primary),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (snap.connectionState == ConnectionState.waiting)
                  const LinearProgressIndicator(color: _accent, minHeight: 2),
                if (snap.hasError)
                  _OverviewAlertCard(
                    color: _red,
                    icon: Icons.warning_amber_rounded,
                    title: 'Dashboard data could not be loaded',
                    body: snap.error.toString(),
                  ),
                if (metrics != null) ...[
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _OverviewMetricCard(
                        'Leads',
                        metrics.customerCount.toString(),
                        Icons.people_outline_rounded,
                        _primary,
                      ),
                      _OverviewMetricCard(
                        'Policy holders',
                        metrics.policyHolderCount.toString(),
                        Icons.how_to_reg_outlined,
                        _green,
                      ),
                      _OverviewMetricCard(
                        'Linked policies',
                        metrics.policyCount.toString(),
                        Icons.policy_outlined,
                        _accent,
                      ),
                      _OverviewMetricCard(
                        'Today tasks',
                        metrics.todayTaskCount.toString(),
                        Icons.task_alt_rounded,
                        _amber,
                      ),
                      _OverviewMetricCard(
                        'Pending tasks',
                        metrics.pendingTaskCount.toString(),
                        Icons.pending_actions_rounded,
                        _green,
                      ),
                      _OverviewMetricCard(
                        'Open claims',
                        metrics.openClaimCount.toString(),
                        Icons.health_and_safety_outlined,
                        _red,
                      ),
                      _OverviewMetricCard(
                        'Active employees',
                        '${metrics.activeAgentCount}/${metrics.agentCount}',
                        Icons.support_agent_rounded,
                        _primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _OverviewAlertGrid(metrics: metrics),
                  const SizedBox(height: 16),
                  _OverviewNextActions(metrics: metrics),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DashboardMetrics {
  final int customerCount;
  final int policyHolderCount;
  final int policyCount;
  final int claimCount;
  final int openClaimCount;
  final int agentCount;
  final int activeAgentCount;
  final int companyCount;
  final int todayTaskCount;
  final int pendingTaskCount;
  final int dueRenewalCount;
  final int expiredPolicyCount;

  const _DashboardMetrics({
    required this.customerCount,
    required this.policyHolderCount,
    required this.policyCount,
    required this.claimCount,
    required this.openClaimCount,
    required this.agentCount,
    required this.activeAgentCount,
    required this.companyCount,
    required this.todayTaskCount,
    required this.pendingTaskCount,
    required this.dueRenewalCount,
    required this.expiredPolicyCount,
  });
}

class _OverviewMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _OverviewMetricCard(this.title, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.09),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
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
                    color: _textMain,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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

class _OverviewAlertGrid extends StatelessWidget {
  final _DashboardMetrics metrics;
  const _OverviewAlertGrid({required this.metrics});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _OverviewAlertCard(
          color: _amber,
          icon: Icons.autorenew_rounded,
          title: '${metrics.dueRenewalCount} renewals due in 60 days',
          body:
              'Use Renewals to record follow-ups and mark policies renewed after payment.',
        ),
        _OverviewAlertCard(
          color: _red,
          icon: Icons.event_busy_rounded,
          title: '${metrics.expiredPolicyCount} expired policies',
          body: 'These need immediate customer contact or status closure.',
        ),
        _OverviewAlertCard(
          color: _green,
          icon: Icons.business_rounded,
          title: '${metrics.companyCount} insurer partners',
          body:
              'Keep company commission rules updated before linking new customer policies.',
        ),
      ],
    );
  }
}

class _OverviewAlertCard extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String body;

  const _OverviewAlertCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _textMain,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    color: _textMuted,
                    fontSize: 12,
                    height: 1.4,
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

class _OverviewNextActions extends StatelessWidget {
  final _DashboardMetrics metrics;
  const _OverviewNextActions({required this.metrics});

  @override
  Widget build(BuildContext context) {
    final actions = [
      if (metrics.dueRenewalCount > 0)
        'Call customers with policies expiring within 60 days.',
      if (metrics.openClaimCount > 0)
        'Review pending claims and update claim progress.',
      if (metrics.pendingTaskCount > 0)
        'Review pending employee tasks and close completed follow-ups.',
      if (metrics.customerCount == 0)
        'Add customers, then link policies from the customer detail screen.',
      'Review Sales and Targets weekly to compare current conversions against goals.',
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recommended actions',
            style: TextStyle(
              color: _textMain,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          ...actions.map(
            (action) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    color: _accent,
                    size: 17,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      action,
                      style: const TextStyle(
                        color: _textMuted,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Category {
  final String title;
  final IconData icon;
  final List<_PageItem> pages;
  const _Category({
    required this.title,
    required this.icon,
    required this.pages,
  });
}

class _PageItem {
  final String label;
  final IconData icon;
  final List<String>? allowedRoles;
  const _PageItem(this.label, this.icon, {this.allowedRoles});
}
