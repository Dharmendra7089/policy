import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class LogsTab extends StatefulWidget {
  const LogsTab({super.key});

  @override
  State<LogsTab> createState() => _LogsTabState();
}

class _LogsTabState extends State<LogsTab> {
  static const _primary = Color(0xFF880E4F);
  static const _bg = Color(0xFFF0F4F8);
  static const _surface = Color(0xFFFFFFFF);
  static const _textMain = Color(0xFF0D1B2A);
  static const _textMuted = Color(0xFF6B7280);
  static const _border = Color(0xFFE5E7EB);

  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedFilter = 'All';

  Stream<QuerySnapshot<Map<String, dynamic>>> get _logsStream =>
      FirebaseFirestore.instance
          .collection('logs')
          .orderBy('timestamp', descending: true)
          .snapshots();

  static String _fmtDate(dynamic value) {
    if (value == null) return '-';
    DateTime d;
    if (value is Timestamp) {
      d = value.toDate();
    } else if (value is DateTime) {
      d = value;
    } else {
      return value.toString();
    }
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
    final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}, $hour:${d.minute.toString().padLeft(2, '0')} $ampm';
  }

  static String _typeOf(Map<String, dynamic> log) {
    final action = (log['action'] ?? '').toString().toLowerCase();
    final targetType = (log['targetType'] ?? '').toString().toLowerCase();
    final page = (log['page'] ?? '').toString().toLowerCase();
    if (targetType.contains('company') || page.contains('compan')) {
      return 'Company';
    }
    if (targetType.contains('customer') ||
        targetType.contains('lead') ||
        targetType.contains('policy holder')) {
      return 'Customer';
    }
    if (targetType.contains('policy')) {
      return 'Policy';
    }
    if (targetType.contains('employee') || targetType.contains('agent')) {
      return 'Employee';
    }
    if (action.contains('expense')) {
      return 'Expense';
    }
    if (action.contains('customer') || action.contains('added policy')) {
      return 'Customer';
    }
    if (action.contains('lead') || action.contains('policy holder')) {
      return 'Customer';
    }
    if (action.contains('company') || action.contains('insurer')) {
      return 'Company';
    }
    if (action.contains('policy')) {
      return 'Policy';
    }
    if (action.contains('claim')) {
      return 'Claim';
    }
    if (action.contains('agent')) {
      return 'Employee';
    }
    if (action.contains('renewal')) {
      return 'Renewal';
    }
    if (action.contains('override') || action.contains('slab')) {
      return 'Override';
    }
    return 'General';
  }

  static IconData _iconFor(String type) {
    switch (type) {
      case 'Expense':
        return Icons.payments_rounded;
      case 'Customer':
        return Icons.person_add_alt_1_rounded;
      case 'Policy':
        return Icons.policy_rounded;
      case 'Claim':
        return Icons.receipt_long_rounded;
      case 'Employee':
        return Icons.badge_rounded;
      case 'Company':
        return Icons.business_rounded;
      case 'Renewal':
        return Icons.autorenew_rounded;
      case 'Override':
        return Icons.edit_note_rounded;
      default:
        return Icons.history_rounded;
    }
  }

  static Color _colorFor(String type) {
    switch (type) {
      case 'Expense':
        return Colors.orange;
      case 'Customer':
        return Colors.blue;
      case 'Policy':
        return Colors.purple;
      case 'Claim':
        return Colors.red;
      case 'Employee':
        return Colors.teal;
      case 'Company':
        return Colors.indigo;
      case 'Renewal':
        return Colors.green;
      case 'Override':
        return Colors.deepOrange;
      default:
        return Colors.grey;
    }
  }

  void _showOverrideDetail(BuildContext context, Map<String, dynamic> log) {
    final color = _colorFor('Override');
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 480,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.edit_note_rounded,
                      color: color,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (log['action'] ?? 'Override').toString(),
                          style: const TextStyle(
                            color: _textMain,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          _fmtDate(log['timestamp']),
                          style: const TextStyle(
                            color: _textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: _textMuted),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 16),

              // Change summary box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.deepOrange.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.deepOrange.withOpacity(0.18),
                  ),
                ),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Previous %',
                          style: TextStyle(
                            color: _textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${log['previousPercent'] ?? '-'}%',
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 24),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: _textMuted,
                      size: 22,
                    ),
                    const SizedBox(width: 24),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'New %',
                          style: TextStyle(
                            color: _textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${log['newPercent'] ?? '-'}%',
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Reason box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Reason / Note',
                      style: TextStyle(
                        color: _textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      (log['reason'] ?? '-').toString(),
                      style: const TextStyle(
                        color: _textMain,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Details grid
              _detailGrid([
                _DetailItem(
                  'Customer',
                  (log['customerName'] ?? '-').toString(),
                ),
                _DetailItem('Policy', (log['policyName'] ?? '-').toString()),
                _DetailItem('Page', (log['page'] ?? '-').toString()),
                _DetailItem('Changed By', (log['changedBy'] ?? '-').toString()),
                _DetailItem('Policy ID', (log['policyId'] ?? '-').toString()),
                _DetailItem(
                  'Customer Policy ID',
                  (log['customerPolicyId'] ?? '-').toString(),
                ),
              ]),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGenericDetail(BuildContext context, Map<String, dynamic> log) {
    final type = _typeOf(log);
    final color = _colorFor(type);
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 460,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_iconFor(type), color: color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (log['action'] ?? '-').toString(),
                          style: const TextStyle(
                            color: _textMain,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          _fmtDate(log['timestamp']),
                          style: const TextStyle(
                            color: _textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: _textMuted),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              if ((log['description'] ?? log['reason'] ?? '')
                  .toString()
                  .isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _border),
                  ),
                  child: Text(
                    (log['description'] ?? log['reason'] ?? '').toString(),
                    style: const TextStyle(
                      color: _textMain,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              _detailGrid([
                _DetailItem(
                  'Performed By',
                  (log['performedBy'] ?? log['changedBy'] ?? '-').toString(),
                ),
                _DetailItem('Page', (log['page'] ?? '-').toString()),
                if ((log['targetType'] ?? '').toString().isNotEmpty)
                  _DetailItem('Record Type', log['targetType'].toString()),
                if ((log['targetName'] ?? '').toString().isNotEmpty)
                  _DetailItem('Record Name', log['targetName'].toString()),
                if ((log['targetId'] ?? '').toString().isNotEmpty)
                  _DetailItem('Target ID', log['targetId'].toString()),
                if ((log['policyName'] ?? '').toString().isNotEmpty)
                  _DetailItem('Policy', log['policyName'].toString()),
                if ((log['customerName'] ?? '').toString().isNotEmpty)
                  _DetailItem('Customer', log['customerName'].toString()),
              ]),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailGrid(List<_DetailItem> items) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: items.map((item) {
        return SizedBox(
          width: 200,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.label,
                style: const TextStyle(
                  color: _textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                item.value.isEmpty ? '-' : item.value,
                style: const TextStyle(
                  color: _textMain,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              const Text(
                'Activity Logs',
                style: TextStyle(
                  color: _textMain,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Complete audit trail of all system actions.',
                style: TextStyle(color: _textMuted, fontSize: 13),
              ),
              const SizedBox(height: 16),

              // Search + Filter row
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search action, user, policy or customer…',
                        hintStyle: const TextStyle(fontSize: 13),
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        filled: true,
                        fillColor: _surface,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
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
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedFilter,
                        style: const TextStyle(
                          color: _textMain,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'All',
                            child: Text('All Types'),
                          ),
                          DropdownMenuItem(
                            value: 'Expense',
                            child: Text('Expense'),
                          ),
                          DropdownMenuItem(
                            value: 'Customer',
                            child: Text('Customer'),
                          ),
                          DropdownMenuItem(
                            value: 'Policy',
                            child: Text('Policy'),
                          ),
                          DropdownMenuItem(
                            value: 'Claim',
                            child: Text('Claim'),
                          ),
                          DropdownMenuItem(
                            value: 'Employee',
                            child: Text('Employee'),
                          ),
                          DropdownMenuItem(
                            value: 'Company',
                            child: Text('Company'),
                          ),
                          DropdownMenuItem(
                            value: 'Renewal',
                            child: Text('Renewal'),
                          ),
                          DropdownMenuItem(
                            value: 'Override',
                            child: Text('Override'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _selectedFilter = v);
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Log list
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _border),
                  ),
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _logsStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }

                      final q = _searchCtrl.text.trim().toLowerCase();
                      final allLogs = snapshot.data?.docs ?? [];

                      final logs = allLogs
                          .map((d) => {'id': d.id, ...d.data()})
                          .where((log) {
                            final action = (log['action'] ?? '')
                                .toString()
                                .toLowerCase();
                            final page = (log['page'] ?? '')
                                .toString()
                                .toLowerCase();
                            final by =
                                (log['performedBy'] ?? log['changedBy'] ?? '')
                                    .toString()
                                    .toLowerCase();
                            final reason =
                                (log['reason'] ?? log['description'] ?? '')
                                    .toString()
                                    .toLowerCase();
                            final customer = (log['customerName'] ?? '')
                                .toString()
                                .toLowerCase();
                            final policy = (log['policyName'] ?? '')
                                .toString()
                                .toLowerCase();
                            final targetName = (log['targetName'] ?? '')
                                .toString()
                                .toLowerCase();
                            final targetType = (log['targetType'] ?? '')
                                .toString()
                                .toLowerCase();
                            final type = _typeOf(log);

                            final matchSearch =
                                q.isEmpty ||
                                action.contains(q) ||
                                page.contains(q) ||
                                by.contains(q) ||
                                reason.contains(q) ||
                                customer.contains(q) ||
                                policy.contains(q) ||
                                targetName.contains(q) ||
                                targetType.contains(q);

                            final matchFilter =
                                _selectedFilter == 'All' ||
                                type == _selectedFilter;

                            return matchSearch && matchFilter;
                          })
                          .toList();

                      if (logs.isEmpty) {
                        return const Center(
                          child: Text(
                            'No logs found.',
                            style: TextStyle(color: _textMuted),
                          ),
                        );
                      }

                      return ListView.separated(
                        itemCount: logs.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, color: _border),
                        itemBuilder: (_, i) {
                          final log = logs[i];
                          final type = _typeOf(log);
                          final color = _colorFor(type);
                          final action = (log['action'] ?? '-').toString();
                          final user =
                              (log['performedBy'] ??
                                      log['changedBy'] ??
                                      'Unknown')
                                  .toString();
                          final time = _fmtDate(log['timestamp']);
                          final isOverride = type == 'Override';

                          return InkWell(
                            borderRadius: BorderRadius.circular(0),
                            onTap: () {
                              if (isOverride) {
                                _showOverrideDetail(context, log);
                              } else {
                                _showGenericDetail(context, log);
                              }
                            },
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  _iconFor(type),
                                  color: color,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                action,
                                style: const TextStyle(
                                  color: _textMain,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Text(
                                  '$user  •  $time',
                                  style: const TextStyle(
                                    color: _textMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.10),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      type,
                                      style: TextStyle(
                                        color: color,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: Color(0xFFD1D5DB),
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailItem {
  final String label;
  final String value;
  const _DetailItem(this.label, this.value);
}
