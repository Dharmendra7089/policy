import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../login_screen.dart';

class CustomerDashboard extends StatefulWidget {
  final Map<String, dynamic> customerData;
  const CustomerDashboard({super.key, required this.customerData});

  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  int _selectedIndex = 0;

  static const _primary = Color(0xFFD97706);
  static const _bg = Color(0xFFF0F2F5);
  static const _surface = Color(0xFFFFFFFF);
  static const _textMain = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);
  static const _border = Color(0xFFE5E7EB);

  final _navItems = const [
    _CNavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Home',
    ),
    _CNavItem(
      icon: Icons.policy_outlined,
      activeIcon: Icons.policy_rounded,
      label: 'My Policies',
    ),
    _CNavItem(
      icon: Icons.receipt_long_outlined,
      activeIcon: Icons.receipt_long_rounded,
      label: 'Claims',
    ),
    _CNavItem(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Profile',
    ),
  ];

  Future<void> _logout() async {
    await Future.delayed(const Duration(milliseconds: 100));
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  Widget _getPage() {
    final uid = widget.customerData['uid'] ?? '';
    switch (_selectedIndex) {
      case 0:
        return _CustomerHome(customerData: widget.customerData);
      case 1:
        return _CustomerPolicies(uid: uid);
      case 2:
        return _CustomerClaims(uid: uid);
      case 3:
        return _CustomerProfile(customerData: widget.customerData);
      default:
        return _CustomerHome(customerData: widget.customerData);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.customerData['name'] ?? 'Customer';
    final isWide = MediaQuery.of(context).size.width > 860;

    return Scaffold(
      backgroundColor: _bg,
      body: isWide
          ? Row(
              children: [
                _buildSidebar(name),
                Expanded(
                  child: Column(
                    children: [
                      _buildTopBar(name),
                      Expanded(child: _getPage()),
                    ],
                  ),
                ),
              ],
            )
          : Column(
              children: [
                _buildTopBar(name),
                Expanded(child: _getPage()),
                _buildBottomNav(),
              ],
            ),
    );
  }

  Widget _buildSidebar(String name) {
    return Container(
      width: 230,
      color: _surface,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF92400E), Color(0xFFD97706)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'C',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Text(
                        'Customer',
                        style: TextStyle(
                          color: Color(0xFFFDE68A),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _navItems.length,
              itemBuilder: (_, i) {
                final item = _navItems[i];
                final isSelected = _selectedIndex == i;
                return GestureDetector(
                  onTap: () => setState(() => _selectedIndex = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _primary.withOpacity(0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? item.activeIcon : item.icon,
                          size: 18,
                          color: isSelected ? _primary : _textMuted,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          item.label,
                          style: TextStyle(
                            color: isSelected ? _primary : _textMuted,
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: GestureDetector(
              onTap: _logout,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFDC2626).withOpacity(0.2),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.logout_rounded,
                      size: 18,
                      color: Color(0xFFDC2626),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Logout',
                      style: TextStyle(
                        color: Color(0xFFDC2626),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(String name) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 430;
    return Container(
      color: _surface,
      padding: EdgeInsets.fromLTRB(
        compact ? 12 : 20,
        MediaQuery.of(context).padding.top + (compact ? 7 : 12),
        compact ? 8 : 20,
        compact ? 7 : 12,
      ),
      child: Row(
        children: [
          Container(
            width: compact ? 28 : 32,
            height: compact ? 28 : 32,
            decoration: BoxDecoration(
              color: _primary,
              borderRadius: BorderRadius.circular(7),
            ),
            child: const Center(
              child: Text(
                'MF',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          SizedBox(width: compact ? 8 : 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Makk Finsol',
                style: TextStyle(
                  color: _textMain,
                  fontSize: compact ? 12 : 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (!compact)
                const Text(
                  'Customer Portal',
                  style: TextStyle(color: _textMuted, fontSize: 11),
                ),
            ],
          ),
          const Spacer(),
          Container(
            constraints: BoxConstraints(maxWidth: compact ? 108 : 180),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 7 : 10,
              vertical: compact ? 4 : 5,
            ),
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person_rounded, size: 13, color: _primary),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: compact ? 2 : 8),
          IconButton(
            constraints: BoxConstraints.tightFor(
              width: compact ? 34 : 40,
              height: compact ? 34 : 40,
            ),
            padding: EdgeInsets.zero,
            icon: const Icon(
              Icons.logout_rounded,
              color: Color(0xFFDC2626),
              size: 20,
            ),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(top: BorderSide(color: _border)),
      ),
      child: Row(
        children: List.generate(_navItems.length, (i) {
          final item = _navItems[i];
          final isSelected = _selectedIndex == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedIndex = i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSelected ? item.activeIcon : item.icon,
                      size: 22,
                      color: isSelected ? _primary : _textMuted,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9,
                        color: isSelected ? _primary : _textMuted,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Customer Home ───────────────────────────────────────────────────────────
class _CustomerHome extends StatelessWidget {
  final Map<String, dynamic> customerData;
  const _CustomerHome({required this.customerData});

  static const _primary = Color(0xFFD97706);
  static const _surface = Color(0xFFFFFFFF);
  static const _textMain = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);
  static const _border = Color(0xFFE5E7EB);

  @override
  Widget build(BuildContext context) {
    final name = customerData['name'] ?? 'Customer';
    final uid = customerData['uid'] ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF92400E), Color(0xFFD97706)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, ${name.split(' ').first}! 👋',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Here\'s a summary of your insurance.',
                  style: TextStyle(color: Color(0xFFFDE68A), fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // KPI cards
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('policies')
                .where('customer_uid', isEqualTo: uid)
                .snapshots(),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? [];
              final active = docs
                  .where((d) => (d.data() as Map)['status'] == 'active')
                  .length;
              final expired = docs
                  .where((d) => (d.data() as Map)['status'] == 'expired')
                  .length;
              return GridView.count(
                crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.5,
                children: [
                  _CKpiCard(
                    label: 'Total Policies',
                    value: '${docs.length}',
                    icon: Icons.policy_rounded,
                    color: _primary,
                  ),
                  _CKpiCard(
                    label: 'Active',
                    value: '$active',
                    icon: Icons.check_circle_rounded,
                    color: const Color(0xFF16A34A),
                  ),
                  _CKpiCard(
                    label: 'Expired',
                    value: '$expired',
                    icon: Icons.cancel_rounded,
                    color: const Color(0xFFDC2626),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Recent policies
          const Text(
            'My Policies',
            style: TextStyle(
              color: _textMain,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('policies')
                .where('customer_uid', isEqualTo: uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: _primary,
                    strokeWidth: 2,
                  ),
                );
              }
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _border),
                  ),
                  child: const Center(
                    child: Text(
                      'No policies found.',
                      style: TextStyle(color: _textMuted, fontSize: 13),
                    ),
                  ),
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final data = docs[i].data() as Map<String, dynamic>;
                  return _PolicyCard(data: data);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Customer Policies ───────────────────────────────────────────────────────
class _CustomerPolicies extends StatelessWidget {
  final String uid;
  const _CustomerPolicies({required this.uid});

  static const _primary = Color(0xFFD97706);
  static const _surface = Color(0xFFFFFFFF);
  static const _textMain = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);
  static const _border = Color(0xFFE5E7EB);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          color: _surface,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: const Text(
            'My Policies',
            style: TextStyle(
              color: _textMain,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const Divider(height: 1, color: Color(0xFFE5E7EB)),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('policies')
                .where('customer_uid', isEqualTo: uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: _primary,
                    strokeWidth: 2,
                  ),
                );
              }
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.policy_outlined,
                        size: 48,
                        color: _textMuted.withOpacity(0.3),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No policies found.',
                        style: TextStyle(color: _textMuted, fontSize: 14),
                      ),
                    ],
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final data = docs[i].data() as Map<String, dynamic>;
                  return _PolicyCard(data: data);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Customer Claims ─────────────────────────────────────────────────────────
class _CustomerClaims extends StatelessWidget {
  final String uid;
  const _CustomerClaims({required this.uid});

  static const _primary = Color(0xFFD97706);
  static const _surface = Color(0xFFFFFFFF);
  static const _textMain = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);
  static const _border = Color(0xFFE5E7EB);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          color: _surface,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: const Text(
            'My Claims',
            style: TextStyle(
              color: _textMain,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const Divider(height: 1, color: Color(0xFFE5E7EB)),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('claims')
                .where('customer_uid', isEqualTo: uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: _primary,
                    strokeWidth: 2,
                  ),
                );
              }
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 48,
                        color: _textMuted.withOpacity(0.3),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No claims filed yet.',
                        style: TextStyle(color: _textMuted, fontSize: 14),
                      ),
                    ],
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final data = docs[i].data() as Map<String, dynamic>;
                  final status = data['status'] ?? 'submitted';
                  Color statusColor;
                  Color statusBg;
                  switch (status.toLowerCase()) {
                    case 'approved':
                      statusColor = const Color(0xFF16A34A);
                      statusBg = const Color(0xFFF0FDF4);
                      break;
                    case 'rejected':
                      statusColor = const Color(0xFFDC2626);
                      statusBg = const Color(0xFFFEF2F2);
                      break;
                    case 'settled':
                      statusColor = const Color(0xFF2563EB);
                      statusBg = const Color(0xFFEFF6FF);
                      break;
                    default:
                      statusColor = const Color(0xFFD97706);
                      statusBg = const Color(0xFFFFFBEB);
                  }
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.receipt_long_rounded,
                            color: statusColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data['claim_number'] ?? 'Claim',
                                style: const TextStyle(
                                  color: _textMain,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                data['policy_number'] ?? 'Policy N/A',
                                style: const TextStyle(
                                  color: _textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Customer Profile ────────────────────────────────────────────────────────
class _CustomerProfile extends StatelessWidget {
  final Map<String, dynamic> customerData;
  const _CustomerProfile({required this.customerData});

  static const _primary = Color(0xFFD97706);
  static const _surface = Color(0xFFFFFFFF);
  static const _textMain = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);
  static const _border = Color(0xFFE5E7EB);

  @override
  Widget build(BuildContext context) {
    final name = customerData['name'] ?? 'Customer';
    final email = customerData['email'] ?? 'N/A';
    final phone = customerData['phone'] ?? 'N/A';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF92400E), Color(0xFFD97706)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'C',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Customer',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Profile Details',
                  style: TextStyle(
                    color: _textMain,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                _infoRow(Icons.person_outline_rounded, 'Full Name', name),
                const Divider(height: 24),
                _infoRow(Icons.alternate_email_rounded, 'Email', email),
                const Divider(height: 24),
                _infoRow(Icons.phone_outlined, 'Phone', phone),
                const Divider(height: 24),
                _infoRow(Icons.people_outline_rounded, 'Role', 'Customer'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 16, color: _primary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: _textMuted, fontSize: 11),
              ),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _textMain,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Shared Widgets ──────────────────────────────────────────────────────────
class _PolicyCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _PolicyCard({required this.data});

  static const _surface = Color(0xFFFFFFFF);
  static const _textMain = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);
  static const _border = Color(0xFFE5E7EB);
  static const _primary = Color(0xFFD97706);

  @override
  Widget build(BuildContext context) {
    final status = data['status'] ?? 'active';
    Color statusColor;
    Color statusBg;
    switch (status.toLowerCase()) {
      case 'active':
        statusColor = const Color(0xFF16A34A);
        statusBg = const Color(0xFFF0FDF4);
        break;
      case 'expired':
        statusColor = const Color(0xFFDC2626);
        statusBg = const Color(0xFFFEF2F2);
        break;
      default:
        statusColor = const Color(0xFFD97706);
        statusBg = const Color(0xFFFFFBEB);
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.policy_rounded, color: _primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['policy_number'] ?? 'N/A',
                  style: const TextStyle(
                    color: _textMain,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Type: ${data['policy_type'] ?? 'N/A'}',
                  style: const TextStyle(color: _textMuted, fontSize: 12),
                ),
                const SizedBox(height: 3),
                Text(
                  'Premium: ₹${data['premium_amount'] ?? '--'}',
                  style: const TextStyle(color: _textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: statusColor,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CKpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _CKpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  static const _surface = Color(0xFFFFFFFF);
  static const _textMain = Color(0xFF111827);
  static const _border = Color(0xFFE5E7EB);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: _textMain,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _CNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
