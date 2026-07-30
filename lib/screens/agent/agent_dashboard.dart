import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../login_screen.dart';

class AgentDashboard extends StatefulWidget {
  final Map<String, dynamic> agentData;
  const AgentDashboard({super.key, required this.agentData});

  @override
  State<AgentDashboard> createState() => _AgentDashboardState();
}

class _AgentDashboardState extends State<AgentDashboard> {
  int _selectedIndex = 0;

  static const _primary = Color(0xFF2563EB);
  static const _bg = Color(0xFFF0F2F5);
  static const _surface = Color(0xFFFFFFFF);
  static const _textMain = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);
  static const _border = Color(0xFFE5E7EB);

  final _pages = const [
    _AgentOverview(),
    _AgentPolicies(),
    _AgentCustomers(),
    _AgentProfile(),
  ];

  final _navItems = const [
    _NavItem(
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard_rounded,
      label: 'Overview',
    ),
    _NavItem(
      icon: Icons.policy_outlined,
      activeIcon: Icons.policy_rounded,
      label: 'My Policies',
    ),
    _NavItem(
      icon: Icons.people_outline_rounded,
      activeIcon: Icons.people_rounded,
      label: 'Customers',
    ),
    _NavItem(
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

  @override
  Widget build(BuildContext context) {
    final name = widget.agentData['name'] ?? 'Employee';
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
                      Expanded(child: _pages[_selectedIndex]),
                    ],
                  ),
                ),
              ],
            )
          : Column(
              children: [
                _buildTopBar(name),
                Expanded(child: _pages[_selectedIndex]),
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
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1E40AF), Color(0xFF2563EB)],
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'A',
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
                        'Employee',
                        style: TextStyle(
                          color: Color(0xFFBFD7FE),
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
    return Container(
      color: _surface,
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 12,
        20,
        12,
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _primary,
              borderRadius: BorderRadius.circular(8),
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
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Makk Finsol',
                style: TextStyle(
                  color: _textMain,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Text(
                'Employee Portal',
                style: TextStyle(color: _textMuted, fontSize: 11),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.support_agent_rounded,
                  size: 13,
                  color: _primary,
                ),
                const SizedBox(width: 5),
                Text(
                  name,
                  style: const TextStyle(
                    color: _primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
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
      decoration: BoxDecoration(
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
                padding: const EdgeInsets.symmetric(vertical: 12),
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
                      style: TextStyle(
                        fontSize: 10,
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

// ── Agent Overview ──────────────────────────────────────────────────────────
class _AgentOverview extends StatelessWidget {
  const _AgentOverview();

  static const _primary = Color(0xFF2563EB);
  static const _surface = Color(0xFFFFFFFF);
  static const _textMain = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);
  static const _border = Color(0xFFE5E7EB);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Overview',
            style: TextStyle(
              color: _textMain,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Your performance summary',
            style: TextStyle(color: _textMuted, fontSize: 13),
          ),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: const [
              _KpiCard(
                label: 'My Policies',
                value: '--',
                icon: Icons.policy_rounded,
                color: Color(0xFF2563EB),
              ),
              _KpiCard(
                label: 'Active',
                value: '--',
                icon: Icons.check_circle_rounded,
                color: Color(0xFF16A34A),
              ),
              _KpiCard(
                label: 'Renewals Due',
                value: '--',
                icon: Icons.autorenew_rounded,
                color: Color(0xFFD97706),
              ),
              _KpiCard(
                label: 'Pending Claims',
                value: '--',
                icon: Icons.pending_actions_rounded,
                color: Color(0xFFDC2626),
              ),
            ],
          ),
          const SizedBox(height: 24),
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
                  'Recent Activity',
                  style: TextStyle(
                    color: _textMain,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('policies')
                      .orderBy('created_at', descending: true)
                      .limit(5)
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
                      return const Center(
                        child: Text(
                          'No recent policies found.',
                          style: TextStyle(color: _textMuted, fontSize: 13),
                        ),
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const Divider(height: 20),
                      itemBuilder: (_, i) {
                        final data = docs[i].data() as Map<String, dynamic>;
                        return Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: _primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.policy_outlined,
                                size: 18,
                                color: _primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data['policy_number'] ?? 'Policy',
                                    style: const TextStyle(
                                      color: _textMain,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    data['customer_name'] ?? '',
                                    style: const TextStyle(
                                      color: _textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _statusChip(data['status'] ?? 'active'),
                          ],
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    Color color;
    Color bg;
    switch (status.toLowerCase()) {
      case 'active':
        color = const Color(0xFF16A34A);
        bg = const Color(0xFFF0FDF4);
        break;
      case 'expired':
        color = const Color(0xFFDC2626);
        bg = const Color(0xFFFEF2F2);
        break;
      default:
        color = const Color(0xFFD97706);
        bg = const Color(0xFFFFFBEB);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ── Agent Policies ──────────────────────────────────────────────────────────
class _AgentPolicies extends StatelessWidget {
  const _AgentPolicies();

  static const _primary = Color(0xFF2563EB);
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
          child: const Row(
            children: [
              Text(
                'My Policies',
                style: TextStyle(
                  color: _textMain,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFE5E7EB)),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('policies')
                .orderBy('created_at', descending: true)
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
                        'No policies assigned yet.',
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
                          child: const Icon(
                            Icons.policy_rounded,
                            color: _primary,
                            size: 20,
                          ),
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
                                data['customer_name'] ?? 'Unknown Customer',
                                style: const TextStyle(
                                  color: _textMuted,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Type: ${data['policy_type'] ?? 'N/A'}',
                                style: const TextStyle(
                                  color: _textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _chip(data['status'] ?? 'N/A'),
                            const SizedBox(height: 6),
                            Text(
                              '₹${data['premium_amount'] ?? '--'}',
                              style: const TextStyle(
                                color: _primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
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
          ),
        ),
      ],
    );
  }

  Widget _chip(String status) {
    Color color;
    Color bg;
    switch (status.toLowerCase()) {
      case 'active':
        color = const Color(0xFF16A34A);
        bg = const Color(0xFFF0FDF4);
        break;
      case 'expired':
        color = const Color(0xFFDC2626);
        bg = const Color(0xFFFEF2F2);
        break;
      default:
        color = const Color(0xFFD97706);
        bg = const Color(0xFFFFFBEB);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ── Agent Customers ─────────────────────────────────────────────────────────
class _AgentCustomers extends StatelessWidget {
  const _AgentCustomers();

  static const _primary = Color(0xFF2563EB);
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
            'My Customers',
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
                .collection('customers')
                .orderBy('created_at', descending: true)
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
                  child: Text(
                    'No customers found.',
                    style: TextStyle(color: _textMuted, fontSize: 14),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final data = docs[i].data() as Map<String, dynamic>;
                  final name = data['name'] ?? 'Unknown';
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _border),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: _primary.withOpacity(0.1),
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(
                              color: _primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  color: _textMain,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                data['email'] ?? 'N/A',
                                style: const TextStyle(
                                  color: _textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: _textMuted),
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

// ── Agent Profile ───────────────────────────────────────────────────────────
class _AgentProfile extends StatelessWidget {
  const _AgentProfile();

  static const _primary = Color(0xFF2563EB);
  static const _surface = Color(0xFFFFFFFF);
  static const _textMain = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);
  static const _border = Color(0xFFE5E7EB);
  static const _bg = Color(0xFFF0F2F5);

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('admins')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        final data = (snapshot.data?.data() as Map<String, dynamic>?) ?? {};
        final name = data['name'] ?? 'Employee';
        final email = data['email'] ?? 'N/A';
        final username = data['username'] ?? 'N/A';
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E40AF), Color(0xFF2563EB)],
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
                        name.isNotEmpty ? name[0].toUpperCase() : 'A',
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
                        'Employee',
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
                    _infoRow(Icons.badge_outlined, 'Username', username),
                    const Divider(height: 24),
                    _infoRow(Icons.support_agent_rounded, 'Role', 'Employee'),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: _textMuted, fontSize: 11),
            ),
            Text(
              value,
              style: const TextStyle(
                color: _textMain,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Shared Widgets ──────────────────────────────────────────────────────────
class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiCard({
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

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
