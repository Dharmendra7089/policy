import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../utils/audit_log_service.dart';

// ─── Main Tab ────────────────────────────────────────────────────────────────

class TargetsTab extends StatefulWidget {
  final Map<String, dynamic> adminData;
  const TargetsTab({super.key, required this.adminData});

  @override
  State<TargetsTab> createState() => _TargetsTabState();
}

class _TargetsTabState extends State<TargetsTab> {
  static const _primary = Color(0xFF0D2D4F);
  static const _accent = Color(0xFF1A6EBD);
  static const _bg = Color(0xFFF4F6F9);
  static const _surface = Color(0xFFFFFFFF);
  static const _border = Color(0xFFE4E7EC);
  static const _textMain = Color(0xFF0D1B2A);
  static const _textMuted = Color(0xFF8A94A6);
  static const _red = Color(0xFFDC2626);

  List<_TargetConfig> _targets = [];
  bool _loadingTargets = true;
  Map<String, Map<String, dynamic>> _progressMap = {};
  bool _loadingProgress = false;

  @override
  void initState() {
    super.initState();
    _loadTargets();
  }

  Future<void> _loadTargets() async {
    setState(() => _loadingTargets = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('targets')
          .orderBy('createdAt', descending: false)
          .get();
      final targets = snap.docs
          .map((d) => _TargetConfig.fromMap(d.id, d.data()))
          .toList();
      setState(() {
        _targets = targets;
        _loadingTargets = false;
      });
      if (targets.isNotEmpty) await _fetchProgress(targets);
    } catch (_) {
      setState(() => _loadingTargets = false);
    }
  }

  Future<void> _fetchProgress(List<_TargetConfig> targets) async {
    setState(() => _loadingProgress = true);
    final result = <String, Map<String, dynamic>>{};

    for (final t in targets) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('revenue')
            .where(
              'issueDate',
              isGreaterThanOrEqualTo: Timestamp.fromDate(
                DateTime(
                  t.startDate.year,
                  t.startDate.month,
                  t.startDate.day,
                  0,
                  0,
                  0,
                ),
              ),
            )
            .where(
              'issueDate',
              isLessThanOrEqualTo: Timestamp.fromDate(
                DateTime(
                  t.endDate.year,
                  t.endDate.month,
                  t.endDate.day,
                  23,
                  59,
                  59,
                ),
              ),
            )
            .get();

        double totalPremium = 0;
        double totalCommission = 0;
        int count = 0;

        for (final doc in snap.docs) {
          final d = doc.data();
          final hasCompanyFilter =
              t.companyId != null && t.companyId!.trim().isNotEmpty;
          if (hasCompanyFilter) {
            final docCompanyId = (d['companyId'] ?? '').toString().trim();
            if (docCompanyId != t.companyId!.trim()) continue;
          }
          totalPremium += _toDouble(d['premium']);
          totalCommission += _toDouble(
            d['commissionAmount'] ?? d['commission'] ?? d['revenue'],
          );
          count++;
        }

        result[t.id] = {
          'premium': totalPremium,
          'commission': totalCommission,
          'count': count,
        };
      } catch (_) {
        result[t.id] = {'premium': 0.0, 'commission': 0.0, 'count': 0};
      }
    }

    setState(() {
      _progressMap = result;
      _loadingProgress = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            const Divider(height: 1, color: _border),
            Expanded(
              child: _loadingTargets
                  ? const Center(
                      child: CircularProgressIndicator(color: _accent),
                    )
                  : _targets.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                      color: _accent,
                      onRefresh: () => _fetchProgress(_targets),
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _targets.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (_, i) {
                          final t = _targets[i];
                          final prog =
                              _progressMap[t.id] ??
                              {'premium': 0.0, 'commission': 0.0, 'count': 0};
                          return _TargetCard(
                            target: t,
                            achievedPremium: _toDouble(prog['premium']),
                            achievedCommission: _toDouble(prog['commission']),
                            policyCount: (prog['count'] as int?) ?? 0,
                            loadingProgress: _loadingProgress,
                            onEdit: () => _openDialog(existing: t),
                            onDelete: () => _delete(t),
                          );
                        },
                      ),
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
                  'Policy Targets',
                  style: TextStyle(
                    color: _textMain,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Track premium slabs, bonus commissions, and progress by company & period.',
                  style: TextStyle(color: _textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _openDialog(),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text(
              'Add Target',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
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
                Icons.track_changes_rounded,
                color: _primary,
                size: 30,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'No targets set',
              style: TextStyle(
                color: _textMain,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create your first target with premium slabs and bonus percentages.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _textMuted, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _openDialog(),
              icon: const Icon(Icons.add_rounded, size: 15),
              label: const Text('Add Target'),
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
      ),
    );
  }

  Future<void> _openDialog({_TargetConfig? existing}) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _TargetDialog(existing: existing),
    );
    if (saved == true) _loadTargets();
  }

  Future<void> _delete(_TargetConfig t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Delete Target',
          style: TextStyle(color: _textMain, fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Remove "${t.title}"? This cannot be undone.',
          style: const TextStyle(color: _textMuted),
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
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await FirebaseFirestore.instance.collection('targets').doc(t.id).delete();
      await AuditLogService.write(
        page: 'Policy Targets',
        action: 'Deleted Target',
        description: 'Deleted target "${t.title}".',
        targetId: t.id,
        targetType: 'Target',
        targetName: t.title,
      );
      _loadTargets();
    }
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v.toDouble();
    if (v is double) return v;
    return double.tryParse(v.toString()) ?? 0;
  }
}

// ─── Target Card ─────────────────────────────────────────────────────────────

class _TargetCard extends StatelessWidget {
  final _TargetConfig target;
  final double achievedPremium;
  final double achievedCommission;
  final int policyCount;
  final bool loadingProgress;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  static const _primary = Color(0xFF0D2D4F);
  static const _accent = Color(0xFF1A6EBD);
  static const _surface = Color(0xFFFFFFFF);
  static const _border = Color(0xFFE4E7EC);
  static const _bg = Color(0xFFF4F6F9);
  static const _textMain = Color(0xFF0D1B2A);
  static const _textMuted = Color(0xFF8A94A6);
  static const _green = Color(0xFF16A34A);
  static const _amber = Color(0xFFF59E0B);
  static const _red = Color(0xFFDC2626);

  const _TargetCard({
    required this.target,
    required this.achievedPremium,
    required this.achievedCommission,
    required this.policyCount,
    required this.loadingProgress,
    required this.onEdit,
    required this.onDelete,
  });

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _currency(double v) {
    final s = v.toStringAsFixed(0);
    final chars = s.split('').reversed.toList();
    final out = <String>[];
    for (int i = 0; i < chars.length; i++) {
      if (i == 3 || (i > 3 && (i - 1) % 2 == 0)) out.add(',');
      out.add(chars[i]);
    }
    return '₹${out.reversed.join()}';
  }

  _CommissionSlab? _activeSlab() {
    _CommissionSlab? active;
    for (final s in target.slabs) {
      if (achievedPremium >= s.fromAmount) active = s;
    }
    return active;
  }

  String get _companyDisplay {
    final id = target.companyId ?? '';
    final name = target.companyName.trim();
    if (name.isNotEmpty) return name;
    if (id.isNotEmpty) {
      return 'ID: ...${id.substring(id.length > 6 ? id.length - 6 : 0)}';
    }
    return 'All Companies';
  }

  bool get _isCompanyFiltered =>
      target.companyId != null && target.companyId!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final activeSlab = _activeSlab();
    final now = DateTime.now();
    final isActive =
        now.isAfter(target.startDate) &&
        now.isBefore(target.endDate.add(const Duration(days: 1)));
    final isExpired = now.isAfter(target.endDate);
    final statusLabel = isExpired
        ? 'Expired'
        : isActive
        ? 'Active'
        : 'Upcoming';
    final statusColor = isExpired
        ? _red
        : isActive
        ? _green
        : _amber;

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header
          Container(
            padding: const EdgeInsets.fromLTRB(18, 15, 12, 13),
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.02),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              border: const Border(bottom: BorderSide(color: _border)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _primary.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.track_changes_rounded,
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
                        target.title,
                        style: const TextStyle(
                          color: _textMain,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _isCompanyFiltered
                                  ? _accent.withValues(alpha: 0.08)
                                  : _textMuted.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _isCompanyFiltered
                                    ? _accent.withValues(alpha: 0.25)
                                    : _border,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _isCompanyFiltered
                                      ? Icons.business_rounded
                                      : Icons.public_rounded,
                                  size: 11,
                                  color: _isCompanyFiltered
                                      ? _accent
                                      : _textMuted,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _companyDisplay,
                                  style: TextStyle(
                                    color: _isCompanyFiltered
                                        ? _accent
                                        : _textMuted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.date_range_outlined,
                            size: 12,
                            color: _textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${_fmt(target.startDate)} – ${_fmt(target.endDate)}',
                            style: const TextStyle(
                              color: _textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 17,
                    color: _accent,
                  ),
                  onPressed: onEdit,
                  splashRadius: 18,
                  tooltip: 'Edit',
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 17,
                    color: _red,
                  ),
                  onPressed: onDelete,
                  splashRadius: 18,
                  tooltip: 'Delete',
                ),
              ],
            ),
          ),

          // ── KPI Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _border)),
            ),
            child: Row(
              children: [
                _kpi(
                  'Premium Achieved',
                  loadingProgress ? '...' : _currency(achievedPremium),
                  _accent,
                ),
                _vDivider(),
                _kpi(
                  'Commission Earned',
                  loadingProgress ? '...' : _currency(achievedCommission),
                  _green,
                ),
                _vDivider(),
                _kpi(
                  'Policies Sold',
                  loadingProgress ? '...' : '$policyCount',
                  _primary,
                ),
                if (activeSlab != null) ...[
                  _vDivider(),
                  _kpi(
                    'Active Bonus',
                    '+${activeSlab.bonusPercent.toStringAsFixed(0)}%',
                    _amber,
                  ),
                ],
              ],
            ),
          ),

          // ── Active slab banner
          if (activeSlab != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: _green.withValues(alpha: 0.05),
                border: const Border(bottom: BorderSide(color: _border)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bolt_rounded, size: 14, color: _green),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'You\'re in "${activeSlab.label}" — earning +${activeSlab.bonusPercent.toStringAsFixed(0)}% bonus on base commission',
                      style: const TextStyle(
                        color: _green,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // ── Slabs
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: target.slabs.asMap().entries.map((e) {
                final idx = e.key;
                final slab = e.value;
                final isThisSlab = activeSlab == slab;
                final slabMax = slab.toAmount;
                final isCompleted =
                    slabMax != null && achievedPremium >= slabMax;

                double pct = 0;
                if (achievedPremium >= slab.fromAmount) {
                  if (slabMax == null) {
                    pct = 1.0;
                  } else {
                    final range = slabMax - slab.fromAmount;
                    pct = range <= 0
                        ? 1.0
                        : ((achievedPremium - slab.fromAmount) / range).clamp(
                            0.0,
                            1.0,
                          );
                  }
                }

                final Color barColor = isCompleted
                    ? _green
                    : isThisSlab
                    ? _accent
                    : achievedPremium < slab.fromAmount
                    ? _border
                    : _accent;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isThisSlab
                        ? _accent.withValues(alpha: 0.04)
                        : isCompleted
                        ? _green.withValues(alpha: 0.04)
                        : _bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isThisSlab
                          ? _accent.withValues(alpha: 0.35)
                          : isCompleted
                          ? _green.withValues(alpha: 0.35)
                          : _border,
                      width: (isThisSlab || isCompleted) ? 1.4 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color:
                                  (barColor == _border ? _textMuted : barColor)
                                      .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Center(
                              child: Text(
                                isCompleted ? '✓' : '${idx + 1}',
                                style: TextStyle(
                                  color: barColor == _border
                                      ? _textMuted
                                      : barColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              slab.label,
                              style: const TextStyle(
                                color: _textMain,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _amber.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '+${slab.bonusPercent.toStringAsFixed(0)}% bonus',
                              style: const TextStyle(
                                color: _amber,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${_currency(slab.fromAmount)} → ${slabMax == null ? '∞' : _currency(slabMax)}',
                            style: const TextStyle(
                              color: _textMuted,
                              fontSize: 12,
                            ),
                          ),
                          if (!loadingProgress)
                            Text(
                              isCompleted
                                  ? 'Completed ✓'
                                  : achievedPremium < slab.fromAmount
                                  ? 'Not reached yet'
                                  : '${(pct * 100).toStringAsFixed(1)}% through this slab',
                              style: TextStyle(
                                color: isCompleted
                                    ? _green
                                    : achievedPremium < slab.fromAmount
                                    ? _textMuted
                                    : _accent,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: loadingProgress ? null : pct,
                          backgroundColor: barColor == _border
                              ? const Color(0xFFE4E7EC)
                              : barColor.withValues(alpha: 0.12),
                          valueColor: AlwaysStoppedAnimation(
                            barColor == _border ? _textMuted : barColor,
                          ),
                          minHeight: 10,
                        ),
                      ),
                      if (!loadingProgress &&
                          achievedPremium >= slab.fromAmount) ...[
                        const SizedBox(height: 6),
                        Text(
                          '${_currency(achievedPremium.clamp(slab.fromAmount, slabMax ?? achievedPremium))} of ${slabMax == null ? '∞' : _currency(slabMax)} in this slab',
                          style: TextStyle(
                            color: barColor == _border ? _textMuted : barColor,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpi(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              color: _textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _vDivider() => Container(width: 1, height: 32, color: _border);
}

// ─── Create / Edit Dialog ────────────────────────────────────────────────────

class _TargetDialog extends StatefulWidget {
  final _TargetConfig? existing;
  const _TargetDialog({this.existing});

  @override
  State<_TargetDialog> createState() => _TargetDialogState();
}

class _TargetDialogState extends State<_TargetDialog> {
  static const _primary = Color(0xFF0D2D4F);
  static const _accent = Color(0xFF1A6EBD);
  static const _bg = Color(0xFFF4F6F9);
  static const _surface = Color(0xFFFFFFFF);
  static const _border = Color(0xFFE4E7EC);
  static const _textMain = Color(0xFF0D1B2A);
  static const _textMuted = Color(0xFF8A94A6);
  static const _red = Color(0xFFDC2626);
  static const _green = Color(0xFF16A34A);

  final _titleCtrl = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;

  Map<String, dynamic>? _selectedCompany;
  List<Map<String, dynamic>> _companies = [];
  bool _loadingCompanies = true;
  bool _saving = false;

  final List<_SlabRow> _slabRows = [];

  @override
  void initState() {
    super.initState();
    _loadCompanies();
    if (widget.existing != null) {
      final e = widget.existing!;
      _titleCtrl.text = e.title;
      _startDate = e.startDate;
      _endDate = e.endDate;
      for (final s in e.slabs) {
        _slabRows.add(
          _SlabRow(
            label: TextEditingController(text: s.label),
            from: TextEditingController(text: s.fromAmount.toStringAsFixed(0)),
            to: TextEditingController(
              text: s.toAmount?.toStringAsFixed(0) ?? '',
            ),
            bonus: TextEditingController(
              text: s.bonusPercent.toStringAsFixed(0),
            ),
          ),
        );
      }
    }
    if (_slabRows.isEmpty) _addSlab();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    for (final r in _slabRows) r.disposeAll();
    super.dispose();
  }

  Future<void> _loadCompanies() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('insurance_companies')
          .orderBy('companyName')
          .get();

      final list = snap.docs
          .map(
            (d) => <String, dynamic>{
              'id': d.id,
              'name': (d.data()['companyName'] ?? '').toString().trim(),
            },
          )
          .where((c) => (c['name'] as String).isNotEmpty)
          .toList();

      setState(() {
        _companies = list;
        _loadingCompanies = false;

        // Restore selected company when editing — fixed orElse type error
        if (widget.existing?.companyId != null &&
            widget.existing!.companyId!.isNotEmpty) {
          final match = list
              .where((c) => c['id'] == widget.existing!.companyId)
              .toList();
          _selectedCompany = match.isNotEmpty ? match.first : null;
        }
      });
    } catch (_) {
      setState(() => _loadingCompanies = false);
    }
  }

  void _addSlab() => setState(() => _slabRows.add(_SlabRow.empty()));

  void _removeSlab(int i) {
    if (_slabRows.length <= 1) return;
    setState(() {
      _slabRows[i].disposeAll();
      _slabRows.removeAt(i);
    });
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: isStart
          ? (_startDate ?? DateTime.now())
          : (_endDate ?? DateTime.now().add(const Duration(days: 30))),
      helpText: isStart ? 'Select Start Date' : 'Select End Date',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
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
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(picked)) {
            _endDate = picked.add(const Duration(days: 30));
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_titleCtrl.text.trim().isEmpty) {
      _snack(messenger, 'Target title is required');
      return;
    }
    if (_startDate == null || _endDate == null) {
      _snack(messenger, 'Start and end dates are required');
      return;
    }
    if (_endDate!.isBefore(_startDate!)) {
      _snack(messenger, 'End date must be after start date');
      return;
    }

    final slabs = <Map<String, dynamic>>[];
    for (int i = 0; i < _slabRows.length; i++) {
      final r = _slabRows[i];
      final label = r.label.text.trim();
      final from = double.tryParse(r.from.text.trim());
      final to = r.to.text.trim().isEmpty
          ? null
          : double.tryParse(r.to.text.trim());
      final bonus = double.tryParse(r.bonus.text.trim());
      if (label.isEmpty || from == null || bonus == null) {
        _snack(
          messenger,
          'Slab ${i + 1}: Label, From amount and Bonus % are required',
        );
        return;
      }
      slabs.add({
        'label': label,
        'fromAmount': from,
        'toAmount': to,
        'bonusPercent': bonus,
      });
    }

    setState(() => _saving = true);

    final companyId = (_selectedCompany?['id'] as String?) ?? '';
    final companyName = (_selectedCompany?['name'] as String?) ?? '';

    try {
      final data = <String, dynamic>{
        'title': _titleCtrl.text.trim(),
        'companyId': companyId,
        'companyName': companyName,
        'startDate': Timestamp.fromDate(_startDate!),
        'endDate': Timestamp.fromDate(_endDate!),
        'slabs': slabs,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.existing != null) {
        await FirebaseFirestore.instance
            .collection('targets')
            .doc(widget.existing!.id)
            .update(data);
        await AuditLogService.write(
          page: 'Policy Targets',
          action: 'Updated Target',
          description: 'Updated target "${_titleCtrl.text.trim()}".',
          targetId: widget.existing!.id,
          targetType: 'Target',
          targetName: _titleCtrl.text.trim(),
        );
      } else {
        data['createdAt'] = FieldValue.serverTimestamp();
        final created = await FirebaseFirestore.instance
            .collection('targets')
            .add(data);
        await AuditLogService.write(
          page: 'Policy Targets',
          action: 'Added Target',
          description: 'Added target "${_titleCtrl.text.trim()}".',
          targetId: created.id,
          targetType: 'Target',
          targetName: _titleCtrl.text.trim(),
        );
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _saving = false);
      _snack(messenger, 'Error: $e');
    }
  }

  void _snack(ScaffoldMessengerState m, String msg) {
    m.showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return 'Pick date';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return AlertDialog(
      backgroundColor: _surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
      title: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.track_changes_rounded,
              color: _primary,
              size: 19,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            isEdit ? 'Edit Target' : 'Create Target',
            style: const TextStyle(
              color: _textMain,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 14),

              _label('Target Title'),
              _tf('e.g. SBI Month Target', _titleCtrl),
              const SizedBox(height: 16),

              _label('Company (leave blank to track all companies)'),
              _loadingCompanies
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: LinearProgressIndicator(),
                    )
                  : DropdownButtonFormField<String>(
                      value: _selectedCompany?['id'] as String?,
                      isExpanded: true,
                      hint: const Text(
                        'All Companies',
                        style: TextStyle(color: _textMuted, fontSize: 13),
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('All Companies'),
                        ),
                        ..._companies.map(
                          (c) => DropdownMenuItem<String>(
                            value: c['id'] as String,
                            child: Text(
                              c['name'] as String,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (selectedId) {
                        setState(() {
                          if (selectedId == null) {
                            _selectedCompany = null;
                          } else {
                            final match = _companies
                                .where((c) => c['id'] == selectedId)
                                .toList();
                            _selectedCompany = match.isNotEmpty
                                ? match.first
                                : null;
                          }
                        });
                      },
                      style: const TextStyle(fontSize: 13, color: _textMain),
                      decoration: _dec(''),
                    ),

              if (_selectedCompany != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _accent.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 14,
                        color: _green,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Filtering by: ${_selectedCompany!['name']}',
                        style: const TextStyle(
                          color: _accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '(ID: ${(_selectedCompany!['id'] as String).substring(0, 8)}...)',
                        style: const TextStyle(color: _textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              _label('Target Period'),
              Row(
                children: [
                  Expanded(
                    child: _dateButton(
                      Icons.calendar_today_outlined,
                      'Start: ${_fmtDate(_startDate)}',
                      _startDate != null ? _accent : _textMuted,
                      () => _pickDate(true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _dateButton(
                      Icons.event_available_outlined,
                      'End: ${_fmtDate(_endDate)}',
                      _endDate != null ? _green : _textMuted,
                      () => _pickDate(false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Premium Slabs',
                          style: TextStyle(
                            color: _primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Progress is counted from revenue using issueDate in the target period.',
                          style: TextStyle(
                            color: _textMuted,
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _addSlab,
                    icon: const Icon(
                      Icons.add_rounded,
                      size: 14,
                      color: _accent,
                    ),
                    label: const Text(
                      'Add Slab',
                      style: TextStyle(
                        color: _accent,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              ..._slabRows.asMap().entries.map((e) {
                final i = e.key;
                final r = e.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: _primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                'S${i + 1}',
                                style: const TextStyle(
                                  color: _primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Slab ${i + 1}',
                            style: const TextStyle(
                              color: _textMain,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          if (_slabRows.length > 1)
                            GestureDetector(
                              onTap: () => _removeSlab(i),
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: _red.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                child: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 14,
                                  color: _red,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _tf('Label (e.g. "Tier 1 — 0 to ₹10,000")', r.label),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _tf(
                              'From ₹ (e.g. 0)',
                              r.from,
                              type: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _tf(
                              'To ₹ (blank = unlimited)',
                              r.to,
                              type: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _tf(
                              'Bonus % (e.g. 25)',
                              r.bonus,
                              type: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel', style: TextStyle(color: _textMuted)),
        ),
        ElevatedButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
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
            _saving
                ? 'Saving...'
                : isEdit
                ? 'Update'
                : 'Create Target',
          ),
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
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      t,
      style: const TextStyle(
        color: _primary,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.4,
      ),
    ),
  );

  Widget _tf(
    String hint,
    TextEditingController ctrl, {
    TextInputType type = TextInputType.text,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      style: const TextStyle(fontSize: 13, color: _textMain),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _textMuted, fontSize: 12),
        filled: true,
        fillColor: _surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 11,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: _accent, width: 1.5),
        ),
      ),
    );
  }

  Widget _dateButton(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _dec(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: _textMuted, fontSize: 13),
    filled: true,
    fillColor: _surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(9),
      borderSide: const BorderSide(color: _border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(9),
      borderSide: const BorderSide(color: _border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(9),
      borderSide: const BorderSide(color: _accent, width: 1.5),
    ),
  );
}

// ─── Models ──────────────────────────────────────────────────────────────────

class _SlabRow {
  final TextEditingController label;
  final TextEditingController from;
  final TextEditingController to;
  final TextEditingController bonus;

  _SlabRow({
    required this.label,
    required this.from,
    required this.to,
    required this.bonus,
  });

  factory _SlabRow.empty() => _SlabRow(
    label: TextEditingController(),
    from: TextEditingController(),
    to: TextEditingController(),
    bonus: TextEditingController(),
  );

  void disposeAll() {
    label.dispose();
    from.dispose();
    to.dispose();
    bonus.dispose();
  }
}

class _CommissionSlab {
  final String label;
  final double fromAmount;
  final double? toAmount;
  final double bonusPercent;

  const _CommissionSlab({
    required this.label,
    required this.fromAmount,
    this.toAmount,
    required this.bonusPercent,
  });

  factory _CommissionSlab.fromMap(Map<String, dynamic> m) => _CommissionSlab(
    label: m['label']?.toString() ?? '',
    fromAmount: _d(m['fromAmount']),
    toAmount: m['toAmount'] != null ? _d(m['toAmount']) : null,
    bonusPercent: _d(m['bonusPercent']),
  );

  static double _d(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v.toDouble();
    if (v is double) return v;
    return double.tryParse(v.toString()) ?? 0;
  }
}

class _TargetConfig {
  final String id;
  final String title;
  final String? companyId;
  final String companyName;
  final DateTime startDate;
  final DateTime endDate;
  final List<_CommissionSlab> slabs;

  const _TargetConfig({
    required this.id,
    required this.title,
    this.companyId,
    required this.companyName,
    required this.startDate,
    required this.endDate,
    required this.slabs,
  });

  factory _TargetConfig.fromMap(String id, Map<String, dynamic> m) {
    DateTime pd(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return DateTime.now();
    }

    final rawSlabs = m['slabs'];
    final slabs = rawSlabs is List
        ? rawSlabs
              .map((s) => _CommissionSlab.fromMap(s as Map<String, dynamic>))
              .toList()
        : <_CommissionSlab>[];

    return _TargetConfig(
      id: id,
      title: m['title']?.toString() ?? '',
      companyId: m['companyId']?.toString(),
      companyName: m['companyName']?.toString() ?? '',
      startDate: pd(m['startDate']),
      endDate: pd(m['endDate']),
      slabs: slabs,
    );
  }
}
