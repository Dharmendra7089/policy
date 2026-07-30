import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../utils/audit_log_service.dart';

class MyTasksTab extends StatefulWidget {
  final Map<String, dynamic> userData;
  const MyTasksTab({super.key, required this.userData});

  @override
  State<MyTasksTab> createState() => _MyTasksTabState();
}

class _MyTasksTabState extends State<MyTasksTab> {
  static const _primary = Color(0xFF0D2D4F);
  static const _accent = Color(0xFF1A6EBD);
  static const _bg = Color(0xFFF4F6F9);
  static const _surface = Color(0xFFFFFFFF);
  static const _border = Color(0xFFE4E7EC);
  static const _textMain = Color(0xFF0D1B2A);
  static const _textMuted = Color(0xFF8A94A6);
  static const _green = Color(0xFF16A34A);
  static const _red = Color(0xFFDC2626);

  DateTime _selectedDate = DateTime.now();

  String get _employeeId =>
      (widget.userData['_profileDocId'] ?? widget.userData['uid'] ?? '')
          .toString();

  String get _employeeName =>
      (widget.userData['name'] ??
              widget.userData['username'] ??
              widget.userData['email'] ??
              'Employee')
          .toString();

  bool get _isAdmin => const {
    'admin',
    'super_admin',
  }.contains((widget.userData['role'] ?? '').toString().toLowerCase());

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _dateLabel(DateTime date) {
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
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _timeLabel(DateTime date) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final suffix = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:${date.minute.toString().padLeft(2, '0')} $suffix';
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _taskStream() {
    if (_isAdmin) {
      return FirebaseFirestore.instance
          .collection('employee_tasks')
          .snapshots();
    }
    final id = _employeeId;
    if (id.isEmpty) {
      return FirebaseFirestore.instance
          .collection('employee_tasks')
          .where('employeeName', isEqualTo: _employeeName)
          .snapshots();
    }
    return FirebaseFirestore.instance
        .collection('employee_tasks')
        .where('employeeId', isEqualTo: id)
        .snapshots();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: _selectedDate,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
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
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _showTaskDialog({
    QueryDocumentSnapshot<Map<String, dynamic>>? existing,
  }) async {
    final note = TextEditingController(
      text: existing?.data()['note']?.toString() ?? '',
    );
    final oldDate = _taskDate(existing?.data()) ?? _selectedDate;
    var taskDate = DateTime(
      oldDate.year,
      oldDate.month,
      oldDate.day,
      oldDate.hour == 0 ? 9 : oldDate.hour,
      oldDate.minute,
    );
    var isSaving = false;
    final messenger = ScaffoldMessenger.of(context);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          Future<void> pickTaskDate() async {
            final picked = await showDatePicker(
              context: ctx,
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
              initialDate: taskDate,
            );
            if (picked != null) {
              setS(() {
                taskDate = DateTime(
                  picked.year,
                  picked.month,
                  picked.day,
                  taskDate.hour,
                  taskDate.minute,
                );
              });
            }
          }

          Future<void> pickTaskTime() async {
            final picked = await showTimePicker(
              context: ctx,
              initialTime: TimeOfDay.fromDateTime(taskDate),
            );
            if (picked != null) {
              setS(() {
                taskDate = DateTime(
                  taskDate.year,
                  taskDate.month,
                  taskDate.day,
                  picked.hour,
                  picked.minute,
                );
              });
            }
          }

          Future<void> save() async {
            final text = note.text.trim();
            if (text.isEmpty) {
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Add a task note.'),
                  backgroundColor: _red,
                ),
              );
              return;
            }
            setS(() => isSaving = true);
            final data = {
              'employeeId': _employeeId,
              'employeeName': _employeeName,
              'note': text,
              'taskDateTime': Timestamp.fromDate(taskDate),
              'dateKey': _dateKey(taskDate),
              'status': existing?.data()['status'] ?? 'Pending',
              'updatedAt': FieldValue.serverTimestamp(),
            };
            if (existing == null) {
              final created = await FirebaseFirestore.instance
                  .collection('employee_tasks')
                  .add({...data, 'createdAt': FieldValue.serverTimestamp()});
              await AuditLogService.write(
                page: 'My Tasks',
                action: 'Added Task',
                description: 'Added task for $_employeeName: $text',
                targetId: created.id,
                targetType: 'Task',
                targetName: text,
              );
            } else {
              await existing.reference.update(data);
              await AuditLogService.write(
                page: 'My Tasks',
                action: 'Updated Task',
                description: 'Updated task for $_employeeName: $text',
                targetId: existing.id,
                targetType: 'Task',
                targetName: text,
              );
            }
            if (ctx.mounted) Navigator.pop(ctx);
          }

          return AlertDialog(
            backgroundColor: _surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            title: Text(
              existing == null ? 'Add Task' : 'Edit Task',
              style: const TextStyle(
                color: _textMain,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            content: SizedBox(
              width: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: pickTaskDate,
                          icon: const Icon(Icons.calendar_month_rounded),
                          label: Text(_dateLabel(taskDate)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: pickTaskTime,
                          icon: const Icon(Icons.schedule_rounded),
                          label: Text(_timeLabel(taskDate)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: note,
                    minLines: 3,
                    maxLines: 5,
                    decoration: InputDecoration(
                      labelText: 'Task note',
                      filled: true,
                      fillColor: _bg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: _border),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: isSaving ? null : save,
                icon: const Icon(Icons.save_rounded, size: 15),
                label: Text(isSaving ? 'Saving...' : 'Save Task'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  DateTime? _taskDate(Map<String, dynamic>? data) {
    final value = data?['taskDateTime'];
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  Future<void> _toggleDone(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    final done = (doc.data()['status'] ?? '').toString() == 'Done';
    final nextStatus = done ? 'Pending' : 'Done';
    await doc.reference.update({
      'status': nextStatus,
      'completedAt': nextStatus == 'Done' ? FieldValue.serverTimestamp() : null,
      'isCompleted': nextStatus == 'Done',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await AuditLogService.write(
      page: 'My Tasks',
      action: 'Updated Task Status',
      description: 'Marked task "${data['note'] ?? doc.id}" as $nextStatus.',
      targetId: doc.id,
      targetType: 'Task',
      targetName: (data['note'] ?? '').toString(),
    );
    final noteId = (data['noteId'] ?? '').toString();
    if ((data['source'] ?? '').toString() == 'customer_note' &&
        noteId.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('customer_notes')
          .doc(noteId)
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

  Future<void> _deleteTask(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    await doc.reference.delete();
    await AuditLogService.write(
      page: 'My Tasks',
      action: 'Deleted Task',
      description: 'Deleted task "${data['note'] ?? doc.id}".',
      targetId: doc.id,
      targetType: 'Task',
      targetName: (data['note'] ?? '').toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedKey = _dateKey(_selectedDate);
    return Container(
      color: _bg,
      child: Column(
        children: [
          Container(
            color: _surface,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'My Tasks',
                        style: TextStyle(
                          color: _textMain,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Plan notes against a date and time.',
                        style: TextStyle(color: _textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showTaskDialog(),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Add Task'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _border),
          Container(
            color: _surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Previous day',
                  onPressed: () => setState(
                    () => _selectedDate = _selectedDate.subtract(
                      const Duration(days: 1),
                    ),
                  ),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_month_rounded, size: 16),
                  label: Text(_dateLabel(_selectedDate)),
                ),
                IconButton(
                  tooltip: 'Next day',
                  onPressed: () => setState(
                    () => _selectedDate = _selectedDate.add(
                      const Duration(days: 1),
                    ),
                  ),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () =>
                      setState(() => _selectedDate = DateTime.now()),
                  child: const Text('Today'),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _taskStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: _accent),
                  );
                }
                final tasks =
                    (snapshot.data?.docs ?? []).where((doc) {
                      final data = doc.data();
                      final key = (data['dateKey'] ?? '').toString();
                      if (key.isNotEmpty) return key == selectedKey;
                      final date = _taskDate(data);
                      return date != null && _dateKey(date) == selectedKey;
                    }).toList()..sort((a, b) {
                      final aDate = _taskDate(a.data()) ?? DateTime(1900);
                      final bDate = _taskDate(b.data()) ?? DateTime(1900);
                      return aDate.compareTo(bDate);
                    });

                if (tasks.isEmpty) {
                  return const Center(
                    child: Text(
                      'No tasks for this date.',
                      style: TextStyle(color: _textMuted),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: tasks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final doc = tasks[index];
                    final data = doc.data();
                    final date = _taskDate(data) ?? _selectedDate;
                    final done = (data['status'] ?? '').toString() == 'Done';
                    final customerName = (data['customerName'] ?? '')
                        .toString()
                        .trim();
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _border),
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: done,
                            activeColor: _green,
                            onChanged: (_) => _toggleDone(doc),
                          ),
                          SizedBox(
                            width: 82,
                            child: Text(
                              _timeLabel(date),
                              style: const TextStyle(
                                color: _accent,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_isAdmin)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 3),
                                    child: Text(
                                      (data['employeeName'] ?? 'Unassigned')
                                          .toString(),
                                      style: const TextStyle(
                                        color: _accent,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                Text(
                                  (data['note'] ?? '').toString(),
                                  style: TextStyle(
                                    color: _textMain,
                                    decoration: done
                                        ? TextDecoration.lineThrough
                                        : TextDecoration.none,
                                  ),
                                ),
                                if (customerName.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      'Customer: $customerName',
                                      style: const TextStyle(
                                        color: _textMuted,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Edit',
                            onPressed: () => _showTaskDialog(existing: doc),
                            icon: const Icon(Icons.edit_outlined, size: 18),
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            onPressed: () => _deleteTask(doc),
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: _red,
                              size: 18,
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
      ),
    );
  }
}
