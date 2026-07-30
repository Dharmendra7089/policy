import 'package:flutter/material.dart';

class PerformanceTab extends StatelessWidget {
  final Map<String, dynamic> adminData;
  const PerformanceTab({super.key, required this.adminData});

  static const _primary = Color(0xFF01696F);
  static const _bg = Color(0xFFF0F2F5);
  static const _surface = Color(0xFFFFFFFF);
  static const _textMain = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);
  static const _border = Color(0xFFE5E7EB);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Overview', 'Key performance metrics at a glance'),
          const SizedBox(height: 16),
          _kpiRow(),
          const SizedBox(height: 28),
          _sectionHeader('Recent Activity', 'Latest actions in the system'),
          const SizedBox(height: 16),
          _recentActivityList(),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _textMain,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(subtitle, style: const TextStyle(color: _textMuted, fontSize: 13)),
      ],
    );
  }

  Widget _kpiRow() {
    final kpis = [
      _KPI(
        'Total Policies',
        '1,240',
        Icons.policy_outlined,
        Color(0xFF01696F),
        Color(0xFFE6F4F4),
      ),
      _KPI(
        'Active Customers',
        '860',
        Icons.people_outline_rounded,
        Color(0xFF2563EB),
        Color(0xFFEFF6FF),
      ),
      _KPI(
        'Claims Pending',
        '34',
        Icons.hourglass_empty_rounded,
        Color(0xFFD97706),
        Color(0xFFFFFBEB),
      ),
      _KPI(
        'Revenue (₹)',
        '4.2Cr',
        Icons.currency_rupee_rounded,
        Color(0xFF16A34A),
        Color(0xFFF0FDF4),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth > 700 ? 4 : 2;
        return GridView.count(
          crossAxisCount: crossCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 1.7,
          children: kpis.map((k) => _kpiCard(k)).toList(),
        );
      },
    );
  }

  Widget _kpiCard(_KPI k) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: k.bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(k.icon, color: k.color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  k.value,
                  style: TextStyle(
                    color: k.color,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  k.label,
                  style: const TextStyle(
                    color: _textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _recentActivityList() {
    final items = [
      _Activity(
        'New policy created',
        'Policy #MF-2045 by Employee Ravi',
        '2 min ago',
        Icons.add_circle_outline_rounded,
        Color(0xFF01696F),
      ),
      _Activity(
        'Customer registered',
        'Priya Sharma onboarded',
        '15 min ago',
        Icons.person_add_outlined,
        Color(0xFF2563EB),
      ),
      _Activity(
        'Claim submitted',
        'Claim #CL-0412 under review',
        '1 hr ago',
        Icons.assignment_outlined,
        Color(0xFFD97706),
      ),
      _Activity(
        'Payment received',
        '₹18,500 from Arjun Reddy',
        '3 hr ago',
        Icons.payment_outlined,
        Color(0xFF16A34A),
      ),
      _Activity(
        'Policy renewed',
        'Policy #MF-1987 renewed',
        'Yesterday',
        Icons.autorenew_rounded,
        Color(0xFF7C3AED),
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: List.generate(items.length, (i) {
          final item = items[i];
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: item.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(item.icon, color: item.color, size: 18),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(
                              color: _textMain,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.subtitle,
                            style: const TextStyle(
                              color: _textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      item.time,
                      style: const TextStyle(color: _textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (i < items.length - 1)
                const Divider(height: 1, indent: 68, color: Color(0xFFF3F4F6)),
            ],
          );
        }),
      ),
    );
  }
}

class _KPI {
  final String label, value;
  final IconData icon;
  final Color color, bgColor;
  const _KPI(this.label, this.value, this.icon, this.color, this.bgColor);
}

class _Activity {
  final String title, subtitle, time;
  final IconData icon;
  final Color color;
  const _Activity(this.title, this.subtitle, this.time, this.icon, this.color);
}
