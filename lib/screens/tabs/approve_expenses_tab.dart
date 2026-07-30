import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../utils/audit_log_service.dart';

class ApproveExpensesTab extends StatefulWidget {
  final Map<String, dynamic> userData;
  const ApproveExpensesTab({super.key, required this.userData});

  @override
  State<ApproveExpensesTab> createState() => _ApproveExpensesTabState();
}

class _ApproveExpensesTabState extends State<ApproveExpensesTab> {
  static const _primary = Color(0xFF0D2D4F);
  static const _accent = Color(0xFF1A6EBD);
  static const _bg = Color(0xFFF4F6F9);
  static const _surface = Color(0xFFFFFFFF);
  static const _textMain = Color(0xFF0D1B2A);
  static const _textMuted = Color(0xFF64748B);
  static const _border = Color(0xFFE2E8F0);
  static const _green = Color(0xFF16A34A);
  static const _amber = Color(0xFFF59E0B);
  static const _red = Color(0xFFDC2626);

  bool get _isAdmin =>
      (widget.userData['role'] ?? '').toString().toLowerCase() == 'admin';

  String get _employeeId =>
      (widget.userData['_profileDocId'] ?? widget.userData['uid'] ?? '')
          .toString();

  String get _employeeName =>
      (widget.userData['name'] ??
              widget.userData['username'] ??
              widget.userData['email'] ??
              'Employee')
          .toString();

  Stream<QuerySnapshot<Map<String, dynamic>>> _expenseStream() {
    return FirebaseFirestore.instance
        .collection('expense_requests')
        .snapshots();
  }

  DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse((value ?? '').toString());
  }

  double _num(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse((value ?? '').toString().replaceAll(',', '')) ?? 0;
  }

  String _currency(dynamic value) {
    return 'Rs ${_num(value).toStringAsFixed(0)}';
  }

  String _fmt(dynamic value) {
    final date = _date(value);
    if (date == null) return '-';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  bool _belongsToUser(Map<String, dynamic> data) {
    if (_isAdmin) return true;
    final id = (data['employeeId'] ?? '').toString();
    final name = (data['employeeName'] ?? '').toString().toLowerCase();
    return (_employeeId.isNotEmpty && id == _employeeId) ||
        name == _employeeName.toLowerCase();
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return _accent;
      case 'credited':
        return _green;
      case 'rejected':
        return _red;
      default:
        return _amber;
    }
  }

  Future<void> _updateStatus(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String status,
  ) async {
    final data = doc.data();
    await doc.reference.set({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': widget.userData['email'] ?? '',
      if (status == 'Approved') 'approvedAt': FieldValue.serverTimestamp(),
      if (status == 'Credited') 'creditedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await AuditLogService.write(
      page: 'Expenses',
      action: 'Updated Expense',
      description: 'Marked expense "${data['title'] ?? 'Expense'}" as $status.',
      targetId: doc.id,
      targetType: 'Expense',
      targetName: (data['title'] ?? '').toString(),
      extra: {'expenseStatus': status, 'employeeName': data['employeeName']},
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Expense marked as $status'),
        backgroundColor: _statusColor(status),
      ),
    );
  }

  Future<void> _requestExpense() async {
    final title = TextEditingController();
    final amount = TextEditingController();
    final note = TextEditingController();
    DateTime expenseDate = DateTime.now();
    final messenger = ScaffoldMessenger.of(context);

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        var saving = false;
        return StatefulBuilder(
          builder: (ctx, setS) => AlertDialog(
            title: const Text('Request Expense'),
            content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: title,
                      decoration: _inputDecoration('Expense title'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amount,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration('Amount'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: note,
                      minLines: 3,
                      maxLines: 5,
                      decoration: _inputDecoration('Notes / reason'),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: expenseDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) setS(() => expenseDate = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 13,
                        ),
                        decoration: BoxDecoration(
                          color: _bg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _border),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_outlined,
                              size: 16,
                              color: _textMuted,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Expense Date: ${_fmt(expenseDate)}',
                              style: const TextStyle(color: _textMain),
                            ),
                          ],
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
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: saving
                    ? null
                    : () async {
                        final requestTitle = title.text.trim();
                        final requestAmount = _num(amount.text);
                        if (requestTitle.isEmpty || requestAmount <= 0) return;
                        setS(() => saving = true);
                        final created = await FirebaseFirestore.instance
                            .collection('expense_requests')
                            .add({
                              'title': requestTitle,
                              'amount': requestAmount,
                              'note': note.text.trim(),
                              'expenseDate': Timestamp.fromDate(expenseDate),
                              'status': 'Pending',
                              'employeeId': _employeeId,
                              'employeeName': _employeeName,
                              'employeeEmail': widget.userData['email'] ?? '',
                              'createdAt': FieldValue.serverTimestamp(),
                              'updatedAt': FieldValue.serverTimestamp(),
                            });
                        await AuditLogService.write(
                          page: 'Expenses',
                          action: 'Requested Expense',
                          description:
                              'Expense "$requestTitle" requested for Rs ${requestAmount.toStringAsFixed(0)}.',
                          targetId: created.id,
                          targetType: 'Expense',
                          targetName: requestTitle,
                          extra: {'employeeName': _employeeName},
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Expense request submitted'),
                            backgroundColor: _accent,
                          ),
                        );
                      },
                icon: const Icon(Icons.send_rounded, size: 16),
                label: Text(saving ? 'Submitting...' : 'Submit'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Padding(
        padding: const EdgeInsets.all(20),
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
                        _isAdmin ? 'Approve Expenses' : 'Expenses',
                        style: const TextStyle(
                          color: _textMain,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isAdmin
                            ? 'Approve employee requests and mark paid expenses as credited.'
                            : 'Submit expense requests and track approval status.',
                        style: const TextStyle(color: _textMuted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                if (!_isAdmin)
                  ElevatedButton.icon(
                    onPressed: _requestExpense,
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Request Expense'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _expenseStream(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: _accent),
                    );
                  }
                  final docs =
                      (snap.data?.docs ?? [])
                          .where((doc) => _belongsToUser(doc.data()))
                          .toList()
                        ..sort((a, b) {
                          final ad =
                              _date(a.data()['createdAt']) ?? DateTime(1900);
                          final bd =
                              _date(b.data()['createdAt']) ?? DateTime(1900);
                          return bd.compareTo(ad);
                        });
                  if (docs.isEmpty) return _emptyState();
                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _expenseCard(docs[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _expenseCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final status = (data['status'] ?? 'Pending').toString();
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: color.withValues(alpha: 0.1),
            child: Text(
              (data['employeeName'] ?? 'E').toString().isEmpty
                  ? 'E'
                  : data['employeeName'].toString()[0].toUpperCase(),
              style: TextStyle(color: color, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        (data['title'] ?? 'Expense').toString(),
                        style: const TextStyle(
                          color: _textMain,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    _statusPill(status),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    _meta(
                      Icons.person_outline_rounded,
                      (data['employeeName'] ?? '-').toString(),
                    ),
                    _meta(
                      Icons.currency_rupee_rounded,
                      _currency(data['amount']),
                    ),
                    _meta(Icons.event_outlined, _fmt(data['expenseDate'])),
                    _meta(Icons.schedule_rounded, _fmt(data['createdAt'])),
                  ],
                ),
                if ((data['note'] ?? '').toString().trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    data['note'].toString(),
                    style: const TextStyle(
                      color: _textMuted,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (_isAdmin) _adminActions(doc, status),
        ],
      ),
    );
  }

  Widget _adminActions(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String status,
  ) {
    if (status == 'Pending') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: () => _updateStatus(doc, 'Rejected'),
            child: const Text('Reject', style: TextStyle(color: _red)),
          ),
          ElevatedButton(
            onPressed: () => _updateStatus(doc, 'Approved'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Approve'),
          ),
        ],
      );
    }
    if (status == 'Approved') {
      return ElevatedButton.icon(
        onPressed: () => _updateStatus(doc, 'Credited'),
        icon: const Icon(Icons.payments_outlined, size: 16),
        label: const Text('Mark Credited'),
        style: ElevatedButton.styleFrom(
          backgroundColor: _accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _statusPill(String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _meta(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: _textMuted),
        const SizedBox(width: 5),
        Text(
          value,
          style: const TextStyle(
            color: _textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _emptyState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _border),
        ),
        child: Text(
          _isAdmin
              ? 'No employee expense requests yet.'
              : 'No expense requests yet.',
          style: const TextStyle(color: _textMuted),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: _bg,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _accent, width: 1.4),
      ),
    );
  }
}
