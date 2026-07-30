import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../utils/audit_log_service.dart';
import '../../utils/lead_workflow_rules.dart';

const _pageBg = Color(0xFFF4F6F9);
const _surface = Colors.white;
const _border = Color(0xFFE4E7EC);
const _text = Color(0xFF0D1B2A);
const _muted = Color(0xFF667085);
const _green = Color(0xFF059669);
const _red = Color(0xFFB42318);
const _interests = ['Health', 'Life', 'General', 'ECGC', 'Agricultural'];
const _outcomes = ['Interested', 'Not Interested'];

Widget _categoryFilters({
  required String selected,
  required ValueChanged<String> onSelected,
}) {
  const categories = ['All', 'Health', 'Life', 'ECGC', 'General'];
  return Wrap(
    spacing: 8,
    runSpacing: 8,
    children: categories
        .map(
          (category) => FilterChip(
            label: Text(category),
            selected: selected == category,
            onSelected: (_) => onSelected(category),
            selectedColor: const Color(0xFFDDEBFA),
            checkmarkColor: const Color(0xFF0D2D4F),
          ),
        )
        .toList(),
  );
}

String? _customerCategoryForInterest(String value) {
  switch (value.trim().toLowerCase()) {
    case 'health':
      return 'Health';
    case 'life':
      return 'Life';
    case 'general':
      return 'General';
    case 'ecgc':
      return 'ECGC';
    case 'agriculture':
    case 'agricultural':
      return 'Agricultural';
  }
  return null;
}

String _leadMobileKey(String value, String fallback) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return fallback.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
  return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
}

({List<String> categories, List<String> customerIds})
_queueExecutiveCustomerStreams({
  required WriteBatch batch,
  required FirebaseFirestore firestore,
  required QueryDocumentSnapshot<Map<String, dynamic>> lead,
  required QueryDocumentSnapshot<Map<String, dynamic>> executive,
  required String assignedById,
  required String assignedByName,
}) {
  final leadData = lead.data();
  final executiveData = executive.data();
  final categories =
      ((leadData['interestCategories'] as List?) ?? const [])
          .map((value) => _customerCategoryForInterest(value.toString()))
          .whereType<String>()
          .toSet()
          .toList()
        ..sort();
  final name = (leadData['name'] ?? 'Unnamed').toString().trim();
  final mobile = (leadData['mobileNumber'] ?? '').toString().trim();
  final email = (leadData['email'] ?? '').toString().trim().toLowerCase();
  final executiveName = (executiveData['name'] ?? '').toString();
  final executiveUid = (executiveData['uid'] ?? '').toString();
  final mobileKey = _leadMobileKey(mobile, lead.id);
  final customerIds = <String>[];

  for (final category in categories) {
    final customerId = 'executive_lead_${mobileKey}_${category.toLowerCase()}';
    customerIds.add(customerId);
    batch.set(firestore.collection('customers').doc(customerId), {
      'fullName': name,
      'mobileNumber': mobile,
      'email': email,
      'address': (leadData['address'] ?? '').toString(),
      'city': (leadData['city'] ?? '').toString(),
      'state': (leadData['state'] ?? '').toString(),
      'pincode': (leadData['pincode'] ?? '').toString(),
      'dateOfBirth': (leadData['dateOfBirth'] ?? '').toString(),
      'guardianName': (leadData['guardianName'] ?? '').toString(),
      'aadharNumber': (leadData['aadharNumber'] ?? '').toString(),
      'panNumber': (leadData['panNumber'] ?? '').toString(),
      'gender': (leadData['gender'] ?? '').toString(),
      'customerType': (leadData['customerType'] ?? 'Individual').toString(),
      'maritalStatus': (leadData['maritalStatus'] ?? '').toString(),
      'status': 'Active',
      'leadStatus': 'Green',
      'customerCategory': category,
      'policyLinkedManually': false,
      'employee': executiveName,
      'employeeName': executiveName,
      'employeeId': executive.id,
      'executiveUid': executiveUid,
      'telecallerLeadId': lead.id,
      'telecallerNotes': (leadData['notes'] ?? '').toString(),
      'notes': (leadData['notes'] ?? '').toString(),
      'callOutcome': (leadData['outcome'] ?? 'Interested').toString(),
      'interestCategories': categories,
      'assignedByTeamLeaderId': assignedById,
      'assignedByTeamLeaderName': assignedByName,
      'source': 'Executive Lead Assignment',
      'searchKey': '${name.toLowerCase()} $mobile $email',
      'createdAt':
          leadData['returnedAt'] ??
          leadData['createdAt'] ??
          FieldValue.serverTimestamp(),
      'createdBy': executiveUid,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': FirebaseAuth.instance.currentUser?.uid ?? '',
    }, SetOptions(merge: true));
  }
  return (categories: categories, customerIds: customerIds);
}

DateTime? _date(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.tryParse((value ?? '').toString());
}

bool _inMonth(dynamic value, DateTime month) {
  final date = _date(value);
  return date != null && date.year == month.year && date.month == month.month;
}

String _monthLabel(DateTime month) {
  const names = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${names[month.month - 1]} ${month.year}';
}

String _dateLabel(dynamic value) {
  final date = _date(value);
  if (date == null) return 'Not available';
  return '${date.day}/${date.month}/${date.year}';
}

class TelecallerLeadsDashboard extends StatefulWidget {
  final Map<String, dynamic> userData;

  const TelecallerLeadsDashboard({super.key, required this.userData});

  @override
  State<TelecallerLeadsDashboard> createState() =>
      _TelecallerLeadsDashboardState();
}

class _TelecallerLeadsDashboardState extends State<TelecallerLeadsDashboard> {
  String _leadWorkFilter = 'Call';
  DateTime _performanceMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );

  String get _employeeId =>
      (widget.userData['_profileDocId'] ?? widget.userData['uid'] ?? '')
          .toString();

  Stream<QuerySnapshot<Map<String, dynamic>>> _stream() {
    return FirebaseFirestore.instance
        .collection('telecaller_leads')
        .where('assignedToId', isEqualTo: _employeeId)
        .snapshots();
  }

  bool _returned(Map<String, dynamic> data) =>
      (data['status'] ?? 'Assigned').toString().toLowerCase() == 'returned';

  Future<void> _callLead(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    final data = document.data();
    final number = (data['mobileNumber'] ?? '').toString().replaceAll(
      RegExp(r'[^0-9+]'),
      '',
    );
    if (number.isEmpty) return;
    final opened = await launchUrl(Uri(scheme: 'tel', path: number));
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open the phone dialer.')),
      );
      return;
    }
    if (!mounted) return;
    await _openResponse(document, fromCall: true);
  }

  Future<void> _openResponse(
    QueryDocumentSnapshot<Map<String, dynamic>> document, {
    bool fromCall = false,
  }) async {
    final data = document.data();
    if (!fromCall && !_returned(data)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Call the customer first, then enter call info.'),
          backgroundColor: _red,
        ),
      );
      return;
    }
    final selected = <String>{
      ...((data['interestCategories'] as List?) ?? const []).map(
        (value) => value.toString(),
      ),
    };
    var outcome = (data['outcome'] ?? 'Interested').toString();
    if (!_outcomes.contains(outcome)) outcome = 'Interested';
    final notes = TextEditingController(text: (data['notes'] ?? '').toString());
    var saving = false;
    String? error;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) {
          Future<void> submit() async {
            if (outcome == 'Interested' && selected.isEmpty) {
              setLocal(() => error = 'Select at least one interested section.');
              return;
            }
            if (notes.text.trim().isEmpty) {
              setLocal(() => error = 'Enter the telecaller notes.');
              return;
            }
            setLocal(() {
              saving = true;
              error = null;
            });
            try {
              final wasReturned = _returned(data);
              await document.reference.update({
                'status': 'Returned',
                'outcome': outcome,
                'interestCategories': outcome == 'Interested'
                    ? (selected.toList()..sort())
                    : <String>[],
                'notes': notes.text.trim(),
                'returnedAt': FieldValue.serverTimestamp(),
                'returnedByUid': FirebaseAuth.instance.currentUser?.uid ?? '',
                'returnedByEmail':
                    FirebaseAuth.instance.currentUser?.email ?? '',
                if (fromCall && !wasReturned) ...{
                  'telecallerCallCount': FieldValue.increment(1),
                  'telecallerLastCalledAt': FieldValue.serverTimestamp(),
                  'telecallerCallHistory': FieldValue.arrayUnion([
                    {
                      'calledAt': Timestamp.now(),
                      'calledById': _employeeId,
                      'calledByName': (widget.userData['name'] ?? '')
                          .toString(),
                      'note': notes.text.trim(),
                      'outcome': outcome,
                    },
                  ]),
                },
                'updatedAt': FieldValue.serverTimestamp(),
              });
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
            } catch (exception) {
              if (dialogContext.mounted) {
                setLocal(() {
                  error = 'Could not submit the lead: $exception';
                  saving = false;
                });
              }
            }
          }

          return AlertDialog(
            title: Text(
              'Lead response · ${(data['name'] ?? '').toString()}',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mobile: ${(data['mobileNumber'] ?? '').toString()}',
                      style: const TextStyle(color: _muted),
                    ),
                    const SizedBox(height: 18),
                    DropdownButtonFormField<String>(
                      initialValue: outcome,
                      decoration: const InputDecoration(
                        labelText: 'Call outcome',
                        border: OutlineInputBorder(),
                      ),
                      items: _outcomes
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setLocal(() {
                            outcome = value;
                            if (outcome == 'Not Interested') selected.clear();
                          });
                        }
                      },
                    ),
                    if (outcome == 'Interested') ...[
                      const SizedBox(height: 18),
                      const Text(
                        'Interested insurance sections',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _interests.map((interest) {
                          return FilterChip(
                            selected: selected.contains(interest),
                            label: Text(interest),
                            onSelected: (value) {
                              setLocal(() {
                                value
                                    ? selected.add(interest)
                                    : selected.remove(interest);
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 18),
                    TextField(
                      controller: notes,
                      minLines: 4,
                      maxLines: 8,
                      decoration: const InputDecoration(
                        labelText: 'Call notes',
                        hintText:
                            'Enter customer requirements, preferred time, questions, and follow-up details.',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 10),
                      Text(error!, style: const TextStyle(color: _red)),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: saving ? null : submit,
                icon: saving
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(saving ? 'Submitting…' : 'Send Lead Back'),
              ),
            ],
          );
        },
      ),
    );
    notes.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_employeeId.isEmpty) {
      return const Center(child: Text('Employee profile is not available.'));
    }
    return ColoredBox(
      color: _pageBg,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _stream(),
        builder: (context, snapshot) {
          final all = snapshot.data?.docs.toList() ?? [];
          all.sort((a, b) {
            final aDate = _date(a.data()['assignedAt']);
            final bDate = _date(b.data()['assignedAt']);
            return (bDate ?? DateTime(1970)).compareTo(aDate ?? DateTime(1970));
          });
          final assignedInMonth = all
              .where(
                (doc) => _inMonth(doc.data()['assignedAt'], _performanceMonth),
              )
              .length;
          final callsTakenInMonth = all
              .where(
                (doc) => _inMonth(doc.data()['returnedAt'], _performanceMonth),
              )
              .length;
          final interestedInMonth = all.where((doc) {
            final data = doc.data();
            return _inMonth(data['returnedAt'], _performanceMonth) &&
                (data['outcome'] ?? '').toString().toLowerCase() ==
                    'interested';
          }).length;
          final latestBatchId = all.isEmpty
              ? ''
              : (all.first.data()['batchId'] ?? '').toString();
          final latestLeads = all.isEmpty
              ? <QueryDocumentSnapshot<Map<String, dynamic>>>[]
              : latestBatchId.isEmpty
              ? <QueryDocumentSnapshot<Map<String, dynamic>>>[all.first]
              : all
                    .where(
                      (doc) =>
                          (doc.data()['batchId'] ?? '').toString() ==
                          latestBatchId,
                    )
                    .toList();

          return DefaultTabController(
            length: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 22, 24, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'My Telecaller Dashboard',
                        style: TextStyle(
                          color: _text,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Call assigned contacts, record their interests and notes, then send the lead back.',
                        style: TextStyle(color: _muted),
                      ),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border),
                  ),
                  child: const TabBar(
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelColor: Colors.white,
                    unselectedLabelColor: _muted,
                    indicator: BoxDecoration(
                      color: Color(0xFF0D2D4F),
                      borderRadius: BorderRadius.all(Radius.circular(9)),
                    ),
                    tabs: [
                      Tab(
                        icon: Icon(Icons.phone_in_talk_outlined),
                        text: 'Leads',
                      ),
                      Tab(
                        icon: Icon(Icons.insights_rounded),
                        text: 'Performance',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: TabBarView(
                    children: [
                      _leadsWorkspace(snapshot, latestLeads),
                      _performancePanel(
                        assignedInMonth: assignedInMonth,
                        callsTakenInMonth: callsTakenInMonth,
                        interestedInMonth: interestedInMonth,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _leadsWorkspace(
    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> latestLeads,
  ) {
    final visibleLeads = latestLeads.where((document) {
      final alreadyCalled = _returned(document.data());
      return _leadWorkFilter == 'Already Called'
          ? alreadyCalled
          : !alreadyCalled;
    }).toList();
    final callCount = latestLeads
        .where((document) => !_returned(document.data()))
        .length;
    final calledCount = latestLeads.length - callCount;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Latest Received Leads',
                style: TextStyle(
                  color: _text,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              '${latestLeads.length} received',
              style: const TextStyle(color: _muted),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: Text('Call ($callCount)'),
              selected: _leadWorkFilter == 'Call',
              onSelected: (_) => setState(() => _leadWorkFilter = 'Call'),
            ),
            ChoiceChip(
              label: Text('Already Called ($calledCount)'),
              selected: _leadWorkFilter == 'Already Called',
              onSelected: (_) =>
                  setState(() => _leadWorkFilter = 'Already Called'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (snapshot.connectionState == ConnectionState.waiting)
          const Center(child: CircularProgressIndicator())
        else if (snapshot.hasError)
          _message('Could not load assigned data.', error: true)
        else if (visibleLeads.isEmpty)
          _message(
            _leadWorkFilter == 'Call'
                ? 'No new leads are waiting for a call.'
                : 'No leads have been called in this batch.',
          )
        else
          ...visibleLeads.map(_leadCard),
      ],
    );
  }

  Widget _performancePanel({
    required int assignedInMonth,
    required int callsTakenInMonth,
    required int interestedInMonth,
  }) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      children: [
        const Text(
          'Monthly Leads Performance',
          style: TextStyle(
            color: _text,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        _monthSelector(),
        const SizedBox(height: 14),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _metric(
              'Calls taken',
              callsTakenInMonth,
              Icons.phone_in_talk_rounded,
              const Color(0xFF0891B2),
            ),
            _metric(
              'Interested leads',
              interestedInMonth,
              Icons.thumb_up_alt_outlined,
              _green,
            ),
            _metric(
              'Assigned leads',
              assignedInMonth,
              Icons.call_received_rounded,
              const Color(0xFFD97706),
            ),
          ],
        ),
      ],
    );
  }

  Widget _monthSelector() {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    final canGoForward = _performanceMonth.isBefore(currentMonth);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Previous month',
            onPressed: () => setState(() {
              _performanceMonth = DateTime(
                _performanceMonth.year,
                _performanceMonth.month - 1,
              );
            }),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          SizedBox(
            width: 165,
            child: Text(
              'Performance · ${_monthLabel(_performanceMonth)}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _text, fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            tooltip: 'Next month',
            onPressed: canGoForward
                ? () => setState(() {
                    _performanceMonth = DateTime(
                      _performanceMonth.year,
                      _performanceMonth.month + 1,
                    );
                  })
                : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, int value, IconData icon, Color color) {
    return Container(
      width: 245,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.1),
            foregroundColor: color,
            child: Icon(icon),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$value',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(label, style: const TextStyle(color: _muted, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _leadCard(QueryDocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data();
    final returned = _returned(data);
    final interests = ((data['interestCategories'] as List?) ?? const [])
        .map((value) => value.toString())
        .toList();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: returned
                  ? _green.withValues(alpha: 0.1)
                  : const Color(0xFF0891B2).withValues(alpha: 0.1),
              child: Icon(
                returned ? Icons.check_rounded : Icons.phone_in_talk_outlined,
                color: returned ? _green : const Color(0xFF0891B2),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (data['name'] ?? 'Unnamed').toString(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    (data['mobileNumber'] ?? '').toString(),
                    style: const TextStyle(color: _muted),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    returned
                        ? 'Returned ${_dateLabel(data['returnedAt'])} · ${(data['outcome'] ?? '').toString()}'
                        : 'Assigned ${_dateLabel(data['assignedAt'])}',
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                  if (interests.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: interests
                          .map(
                            (item) => Chip(
                              label: Text(item),
                              visualDensity: VisualDensity.compact,
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  if ((data['notes'] ?? '').toString().isNotEmpty) ...[
                    const SizedBox(height: 7),
                    Text((data['notes'] ?? '').toString()),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  onPressed: returned ? null : () => _callLead(document),
                  icon: const Icon(Icons.call_rounded),
                  label: Text(returned ? 'Already Called' : 'Call'),
                ),
                const SizedBox(height: 8),
                if (returned)
                  ElevatedButton.icon(
                    onPressed: () => _openResponse(document),
                    icon: const Icon(Icons.edit_note_rounded),
                    label: const Text('Update Result'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _message(String text, {bool error = false}) => Container(
    padding: const EdgeInsets.all(28),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _border),
    ),
    child: Text(text, style: TextStyle(color: error ? _red : _muted)),
  );
}

class ForwardedLeadsDashboard extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String role;

  const ForwardedLeadsDashboard({
    super.key,
    required this.userData,
    required this.role,
  });

  @override
  State<ForwardedLeadsDashboard> createState() =>
      _ForwardedLeadsDashboardState();
}

class _ForwardedLeadsDashboardState extends State<ForwardedLeadsDashboard> {
  final Set<String> _workingLeadIds = <String>{};
  String? _selectedLeadId;

  bool get _isTeamLeader => widget.role == 'team_leader';

  String get _employeeId =>
      (widget.userData['_profileDocId'] ?? widget.userData['uid'] ?? '')
          .toString();

  String get _prefix => _isTeamLeader ? 'teamLeader' : 'executive';

  int get _callLimit => _isTeamLeader
      ? LeadWorkflowRules.teamLeaderCallLimit
      : LeadWorkflowRules.executiveCallLimit;

  String _status(Map<String, dynamic> data) {
    final value = (data['${_prefix}LeadStatus'] ?? data['leadStatus'] ?? '')
        .toString()
        .toLowerCase();
    return value == 'red' ? 'Red' : 'Green';
  }

  int _callCount(Map<String, dynamic> data) =>
      (data['${_prefix}CallCount'] as num?)?.toInt() ?? 0;

  List<String> _customerIds(Map<String, dynamic> data) =>
      ((data['executiveCustomerIds'] as List?) ?? const <dynamic>[])
          .map((value) => value.toString())
          .where((value) => value.isNotEmpty)
          .toList();

  List<Map<String, dynamic>> _executiveNotes(Map<String, dynamic> data) =>
      ((data['executiveCallNotes'] as List?) ?? const <dynamic>[])
          .whereType<Map>()
          .map((value) => Map<String, dynamic>.from(value))
          .toList();

  Future<String?> _requestExecutiveCallNote(int callNumber) async {
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Every Executive call requires a note. Five calls and five notes are required before Review Lead is enabled.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  maxLines: 4,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Call note',
                    border: const OutlineInputBorder(),
                    errorText: errorText,
                  ),
                ),
              ],
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
    );
  }

  Future<void> _addMissingExecutiveNote(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    final data = document.data();
    final notes = _executiveNotes(data);
    final calls = _callCount(data);
    if (_isTeamLeader || notes.length >= calls) return;
    final note = await _requestExecutiveCallNote(notes.length + 1);
    if (note == null || note.isEmpty) return;
    await document.reference.update({
      'executiveCallNotes': FieldValue.arrayUnion([
        {
          'callNumber': notes.length + 1,
          'note': note,
          'addedAt': Timestamp.now(),
          'addedById': _employeeId,
          'addedByName': (widget.userData['name'] ?? '').toString(),
        },
      ]),
      'executiveLastCallNote': note,
      'executiveNotesUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _callLead(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    final data = document.data();
    final number = (data['mobileNumber'] ?? '').toString().replaceAll(
      RegExp(r'[^0-9+]'),
      '',
    );
    if (number.isEmpty || _workingLeadIds.contains(document.id)) return;
    if (_status(data) == 'Red' ||
        data['executiveEscalatedToTeamLeader'] == true && !_isTeamLeader ||
        _callCount(data) >= _callLimit) {
      return;
    }

    setState(() => _workingLeadIds.add(document.id));
    try {
      final opened = await launchUrl(Uri(scheme: 'tel', path: number));
      if (!opened) throw StateError('Unable to open the phone dialer.');
      String? callNote;
      if (!_isTeamLeader) {
        callNote = await _requestExecutiveCallNote(_callCount(data) + 1);
        if (callNote == null || callNote.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Call not recorded. Add a note after every customer call.',
                ),
              ),
            );
          }
          return;
        }
      }
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final latest = await transaction.get(document.reference);
        final latestData = latest.data() ?? <String, dynamic>{};
        final count = _callCount(latestData);
        if (count >= _callLimit) return;
        transaction.update(document.reference, {
          '${_prefix}CallCount': count + 1,
          '${_prefix}LastCalledAt': FieldValue.serverTimestamp(),
          '${_prefix}CallHistory': FieldValue.arrayUnion([
            {
              'callNumber': count + 1,
              'calledAt': Timestamp.now(),
              'calledById': _employeeId,
              'calledByName': (widget.userData['name'] ?? '').toString(),
              'role': widget.role,
              'note': ?callNote,
            },
          ]),
          if (callNote != null) ...{
            'executiveCallNotes': FieldValue.arrayUnion([
              {
                'callNumber': count + 1,
                'note': callNote,
                'addedAt': Timestamp.now(),
                'addedById': _employeeId,
                'addedByName': (widget.userData['name'] ?? '').toString(),
              },
            ]),
            'executiveLastCallNote': callNote,
          },
        });
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not record the call: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _workingLeadIds.remove(document.id));
    }
  }

  Future<void> _reviewExecutiveLead(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    final data = document.data();
    if (_callCount(data) < LeadWorkflowRules.executiveCallLimit ||
        _executiveNotes(data).length < LeadWorkflowRules.executiveCallLimit) {
      return;
    }
    final purchaseController = TextEditingController();
    final notesController = TextEditingController();
    String? errorText;
    var saving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Complete Executive Review'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enter the customer purchase value. Your Executive stage closes as Red. Above Rs 25,000 also opens a Green lead for your Team Leader; otherwise it remains Red only.',
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: purchaseController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Customer purchase value',
                    prefixText: 'Rs ',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Executive notes',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 10),
                  Text(errorText!, style: const TextStyle(color: _red)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      final purchaseValue = double.tryParse(
                        purchaseController.text.trim().replaceAll(',', ''),
                      );
                      if (purchaseValue == null || purchaseValue < 0) {
                        setDialogState(
                          () => errorText = 'Enter a valid purchase value.',
                        );
                        return;
                      }
                      final escalate =
                          LeadWorkflowRules.shouldEscalateToTeamLeader(
                            purchaseValue,
                          );
                      final teamLeaderId =
                          (widget.userData['teamLeaderId'] ?? '').toString();
                      if (escalate && teamLeaderId.isEmpty) {
                        setDialogState(
                          () => errorText =
                              'This executive is not assigned to a Team Leader.',
                        );
                        return;
                      }
                      setDialogState(() {
                        saving = true;
                        errorText = null;
                      });
                      try {
                        final firestore = FirebaseFirestore.instance;
                        final batch = firestore.batch();
                        final routedStatus = LeadWorkflowRules.routedLeadStatus(
                          purchaseValue,
                        );
                        batch.update(document.reference, {
                          'customerPurchaseValue': purchaseValue,
                          'executiveReviewNotes': notesController.text.trim(),
                          'executiveReviewedAt': FieldValue.serverTimestamp(),
                          'executiveLeadStatus':
                              LeadWorkflowRules.executiveClosedStatus,
                          'executiveClosedAt': FieldValue.serverTimestamp(),
                          'leadStatus': routedStatus,
                          'executiveEscalatedToTeamLeader': escalate,
                          if (escalate) ...{
                            'teamLeaderAssignedToId': teamLeaderId,
                            'teamLeaderAssignedToUid':
                                (widget.userData['teamLeaderUid'] ?? '')
                                    .toString(),
                            'teamLeaderAssignedToName':
                                (widget.userData['teamLeaderName'] ?? '')
                                    .toString(),
                            'teamLeaderAssignedToEmail':
                                (widget.userData['teamLeaderEmail'] ?? '')
                                    .toString(),
                            'teamLeaderAssignedAt':
                                FieldValue.serverTimestamp(),
                            'teamLeaderLeadStatus': 'Green',
                            'teamLeaderCallCount': 0,
                            'teamLeaderCallHistory':
                                const <Map<String, dynamic>>[],
                            'executiveEscalatedAt':
                                FieldValue.serverTimestamp(),
                          },
                        });
                        for (final customerId in _customerIds(data)) {
                          batch.set(
                            firestore.collection('customers').doc(customerId),
                            {
                              'leadStatus': routedStatus,
                              'customerPurchaseValue': purchaseValue,
                              'executiveReviewNotes': notesController.text
                                  .trim(),
                              'executiveReviewedAt':
                                  FieldValue.serverTimestamp(),
                              'executiveEscalatedToTeamLeader': escalate,
                              if (escalate) ...{
                                'teamLeaderId': teamLeaderId,
                                'teamLeaderName':
                                    (widget.userData['teamLeaderName'] ?? '')
                                        .toString(),
                              },
                              'updatedAt': FieldValue.serverTimestamp(),
                            },
                            SetOptions(merge: true),
                          );
                        }
                        await batch.commit();
                        await AuditLogService.write(
                          page: 'Executive Leads',
                          action: escalate
                              ? 'Escalated Lead to Team Leader'
                              : 'Marked Executive Lead Red',
                          description: escalate
                              ? 'Customer purchase value Rs ${purchaseValue.toStringAsFixed(0)} exceeded Rs 25,000 and the lead was sent to the Team Leader as Green.'
                              : 'Customer purchase value Rs ${purchaseValue.toStringAsFixed(0)} did not exceed Rs 25,000 and the lead was marked Red.',
                          targetId: document.id,
                          targetType: 'Lead',
                          targetName: (data['name'] ?? '').toString(),
                        );
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                      } catch (error) {
                        setDialogState(() {
                          saving = false;
                          errorText = 'Could not update the lead: $error';
                        });
                      }
                    },
              child: Text(saving ? 'Saving...' : 'Submit'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markTeamLeaderLeadRed(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    final data = document.data();
    if (_callCount(data) < 2) return;
    final notesController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Mark Lead Red'),
        content: SizedBox(
          width: 400,
          child: TextField(
            controller: notesController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Team Leader notes',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: _red),
            child: const Text('Mark Red'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();
    batch.update(document.reference, {
      'teamLeaderLeadStatus': 'Red',
      'leadStatus': 'Red',
      'teamLeaderReviewNotes': notesController.text.trim(),
      'teamLeaderReviewedAt': FieldValue.serverTimestamp(),
    });
    for (final customerId in _customerIds(data)) {
      batch.set(firestore.collection('customers').doc(customerId), {
        'leadStatus': 'Red',
        'teamLeaderReviewNotes': notesController.text.trim(),
        'teamLeaderReviewedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await batch.commit();
    await AuditLogService.write(
      page: 'Team Leader Leads',
      action: 'Marked Escalated Lead Red',
      description: 'Team Leader marked the lead Red after two calls.',
      targetId: document.id,
      targetType: 'Lead',
      targetName: (data['name'] ?? '').toString(),
    );
  }

  Widget _leadListTile(QueryDocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data();
    final status = _status(data);
    final escalated = data['executiveEscalatedToTeamLeader'] == true;
    final interests = ((data['interestCategories'] as List?) ?? const []).join(
      ', ',
    );
    return Card(
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _selectedLeadId = document.id),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(Icons.person_search_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (data['name'] ?? 'Unnamed').toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text((data['mobileNumber'] ?? '').toString()),
                    if (interests.isNotEmpty) Text('Interest: $interests'),
                    if (escalated && !_isTeamLeader)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          'Sent to Team Leader as Green',
                          style: TextStyle(
                            color: _green,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: (status == 'Green' ? _green : _red).withValues(
                    alpha: 0.1,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: status == 'Green' ? _green : _red,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: _muted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _leadDetail(QueryDocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data();
    final status = _status(data);
    final calls = _callCount(data);
    final executiveNotes = _executiveNotes(data);
    final noteCount = executiveNotes.length;
    final escalated = data['executiveEscalatedToTeamLeader'] == true;
    final interests = ((data['interestCategories'] as List?) ?? const []).join(
      ', ',
    );
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => setState(() => _selectedLeadId = null),
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: 'Back',
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                (data['name'] ?? 'Unnamed').toString(),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: (status == 'Green' ? _green : _red).withValues(
                  alpha: 0.1,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: status == 'Green' ? _green : _red,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text((data['mobileNumber'] ?? '').toString()),
                if (interests.isNotEmpty) Text('Interest: $interests'),
                Text('Notes: ${(data['notes'] ?? '').toString()}'),
                if (data['customerPurchaseValue'] != null)
                  Text(
                    'Customer purchase value: Rs ${data['customerPurchaseValue']}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                if (escalated && !_isTeamLeader)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'Sent to Team Leader as Green',
                      style: TextStyle(
                        color: _green,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                const SizedBox(height: 18),
                LinearProgressIndicator(
                  value: (calls / _callLimit).clamp(0.0, 1.0),
                  minHeight: 7,
                  color: status == 'Green' ? _green : _red,
                  backgroundColor: _border,
                ),
                const SizedBox(height: 8),
                Text(
                  '$calls of $_callLimit calls completed',
                  style: const TextStyle(color: _muted),
                ),
                if (!_isTeamLeader) ...[
                  const SizedBox(height: 4),
                  Text(
                    '$noteCount of ${LeadWorkflowRules.executiveCallLimit} call notes added',
                    style: TextStyle(
                      color: noteCount >= LeadWorkflowRules.executiveCallLimit
                          ? _green
                          : _red,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (calls < LeadWorkflowRules.executiveCallLimit)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        'Complete 5 calls and save a note for every call before turning this lead Red.',
                        style: TextStyle(color: _muted),
                      ),
                    )
                  else if (noteCount < LeadWorkflowRules.executiveCallLimit)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        'Add the missing call notes before reviewing this lead.',
                        style: TextStyle(
                          color: _red,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  if (executiveNotes.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Call Notes',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    ...executiveNotes.map(
                      (note) => Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Text(
                          'Call ${note['callNumber'] ?? '-'}: ${note['note'] ?? ''}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed:
                          status == 'Red' ||
                              calls >= _callLimit ||
                              escalated && !_isTeamLeader ||
                              _workingLeadIds.contains(document.id)
                          ? null
                          : () => _callLead(document),
                      icon: const Icon(Icons.call_rounded),
                      label: Text(
                        calls >= _callLimit
                            ? 'Call limit reached'
                            : 'Call ${calls + 1}',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    if (!_isTeamLeader && noteCount < calls)
                      OutlinedButton.icon(
                        onPressed: () => _addMissingExecutiveNote(document),
                        icon: const Icon(Icons.note_add_outlined),
                        label: const Text('Add Missing Note'),
                      ),
                    if (!_isTeamLeader &&
                        calls >= LeadWorkflowRules.executiveCallLimit &&
                        noteCount >= LeadWorkflowRules.executiveCallLimit &&
                        status != 'Red' &&
                        !escalated)
                      OutlinedButton.icon(
                        onPressed: () => _reviewExecutiveLead(document),
                        icon: const Icon(Icons.rule_rounded),
                        label: const Text('Review Lead'),
                      ),
                    if (_isTeamLeader &&
                        calls >= LeadWorkflowRules.teamLeaderCallLimit &&
                        status != 'Red')
                      ElevatedButton.icon(
                        onPressed: () => _markTeamLeaderLeadRed(document),
                        icon: const Icon(Icons.flag_rounded),
                        label: const Text('Mark Red'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _isTeamLeader ? 'My Team Leader Leads' : 'My Executive Leads';
    return ColoredBox(
      color: _pageBg,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('telecaller_leads')
            .where('${_prefix}AssignedToId', isEqualTo: _employeeId)
            .snapshots(),
        builder: (context, snapshot) {
          final documents = (snapshot.data?.docs.toList() ?? []).where((
            document,
          ) {
            if (!_isTeamLeader) return true;
            return document.data()['executiveEscalatedToTeamLeader'] == true;
          }).toList();
          if (_selectedLeadId != null) {
            final matches = documents
                .where((document) => document.id == _selectedLeadId)
                .toList();
            if (matches.isNotEmpty) return _leadDetail(matches.first);
            _selectedLeadId = null;
          }
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _isTeamLeader
                    ? '${documents.length} Green lead(s) escalated by your executives'
                    : '${documents.length} lead(s) assigned to you',
                style: const TextStyle(color: _muted),
              ),
              const SizedBox(height: 18),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Center(child: CircularProgressIndicator())
              else if (snapshot.hasError)
                const Text('Could not load assigned leads.')
              else if (documents.isEmpty)
                const Text('No leads assigned yet.')
              else
                ...documents.map(_leadListTile),
            ],
          );
        },
      ),
    );
  }
}

class TeamLeaderDataTransferDashboard extends StatefulWidget {
  final Map<String, dynamic> userData;

  const TeamLeaderDataTransferDashboard({super.key, required this.userData});

  @override
  State<TeamLeaderDataTransferDashboard> createState() =>
      _TeamLeaderDataTransferDashboardState();
}

class _TeamLeaderDataTransferDashboardState
    extends State<TeamLeaderDataTransferDashboard> {
  final Set<String> _selectedLeadIds = {};
  final Set<String> _selectedExecutiveIds = {};
  bool _sending = false;
  String _categoryFilter = 'All';

  String get _teamLeaderId =>
      (widget.userData['_profileDocId'] ?? widget.userData['uid'] ?? '')
          .toString();

  bool _active(Map<String, dynamic> data) {
    if (data['is_active'] == false) return false;
    return (data['status'] ?? 'Active').toString().toLowerCase() != 'inactive';
  }

  Future<void> _assign(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> leads,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> executives,
  ) async {
    final selectedLeads = leads
        .where((document) => _selectedLeadIds.contains(document.id))
        .toList();
    final selectedExecutives = executives
        .where((document) => _selectedExecutiveIds.contains(document.id))
        .toList();
    if (selectedLeads.isEmpty || selectedExecutives.isEmpty) return;

    setState(() => _sending = true);
    try {
      final firestore = FirebaseFirestore.instance;
      for (var start = 0; start < selectedLeads.length; start += 70) {
        final end = (start + 70).clamp(0, selectedLeads.length);
        final batch = firestore.batch();
        for (var index = start; index < end; index++) {
          final lead = selectedLeads[index];
          final executive =
              selectedExecutives[index % selectedExecutives.length];
          final executiveData = executive.data();
          final streamResult = _queueExecutiveCustomerStreams(
            batch: batch,
            firestore: firestore,
            lead: lead,
            executive: executive,
            assignedById: _teamLeaderId,
            assignedByName: (widget.userData['name'] ?? '').toString(),
          );
          batch.update(lead.reference, {
            'executiveForwarded': true,
            'executiveBasketStatus': 'Active',
            'executiveAssignedToId': executive.id,
            'executiveAssignedToUid': (executiveData['uid'] ?? '').toString(),
            'executiveAssignedToName': (executiveData['name'] ?? '').toString(),
            'executiveAssignedToEmail': (executiveData['email'] ?? '')
                .toString(),
            'executiveAssignedAt': FieldValue.serverTimestamp(),
            'executiveBasketAddedAt': FieldValue.serverTimestamp(),
            'executiveLeadStatus': 'Green',
            'leadStatus': 'Green',
            'executiveCallCount': 0,
            'executiveCallHistory': const <Map<String, dynamic>>[],
            'executiveCallNotes': const <Map<String, dynamic>>[],
            'executiveEscalatedToTeamLeader': false,
            'executiveAssignedByTeamLeaderId': _teamLeaderId,
            'executiveAssignedByTeamLeaderName': (widget.userData['name'] ?? '')
                .toString(),
            'executiveLeadCategories': streamResult.categories,
            'executiveCustomerIds': streamResult.customerIds,
            'executiveStreamedAt': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
      }
      await AuditLogService.write(
        page: 'Data Transfer',
        action: 'Team Leader Assigned Executive Leads',
        description:
            'Assigned ${selectedLeads.length} interested leads among ${selectedExecutives.length} executives.',
        targetId: _teamLeaderId,
        targetType: 'Team Leader',
        targetName: (widget.userData['name'] ?? '').toString(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${selectedLeads.length} leads sent equally to ${selectedExecutives.length} executive(s).',
          ),
          backgroundColor: _green,
        ),
      );
      setState(() {
        _selectedLeadIds.clear();
        _selectedExecutiveIds.clear();
      });
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not assign leads: $exception'),
            backgroundColor: _red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_teamLeaderId.isEmpty) {
      return const Center(child: Text('Team Leader profile is unavailable.'));
    }
    return ColoredBox(
      color: _pageBg,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('telecaller_leads')
            .where('teamLeaderAssignedToId', isEqualTo: _teamLeaderId)
            .snapshots(),
        builder: (context, leadSnapshot) {
          final allLeads = leadSnapshot.data?.docs.toList() ?? [];
          final pendingLeads = allLeads.where((document) {
            final data = document.data();
            final interested =
                (data['outcome'] ?? '').toString().toLowerCase() ==
                    'interested' &&
                data['executiveForwarded'] != true;
            if (!interested || _categoryFilter == 'All') return interested;
            final categories =
                ((data['interestCategories'] as List?) ?? const []).map(
                  (value) => value.toString().toLowerCase(),
                );
            return categories.contains(_categoryFilter.toLowerCase());
          }).toList();
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('agents')
                .where('role', isEqualTo: 'executive')
                .snapshots(),
            builder: (context, executiveSnapshot) {
              final executives =
                  (executiveSnapshot.data?.docs ?? [])
                      .where(
                        (document) =>
                            _active(document.data()) &&
                            (document.data()['teamLeaderId'] ?? '')
                                    .toString() ==
                                _teamLeaderId,
                      )
                      .toList()
                    ..sort(
                      (a, b) => (a.data()['name'] ?? '').toString().compareTo(
                        (b.data()['name'] ?? '').toString(),
                      ),
                    );
              final selectedLeadCount = pendingLeads
                  .where((document) => _selectedLeadIds.contains(document.id))
                  .length;
              final selectedExecutiveCount = executives
                  .where(
                    (document) => _selectedExecutiveIds.contains(document.id),
                  )
                  .length;
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const Text(
                    'Data Transfer · Assign to Executives',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${allLeads.length} received from Admin/Supervisor · '
                    '${pendingLeads.length} waiting · ${executives.length} executives in your team',
                    style: const TextStyle(color: _muted),
                  ),
                  const SizedBox(height: 14),
                  _categoryFilters(
                    selected: _categoryFilter,
                    onSelected: (category) => setState(() {
                      _categoryFilter = category;
                      _selectedLeadIds.clear();
                    }),
                  ),
                  const SizedBox(height: 20),
                  _sectionHeader(
                    '1. Select interested leads',
                    selectedLeadCount,
                    pendingLeads.length,
                    () => setState(() {
                      if (selectedLeadCount == pendingLeads.length) {
                        _selectedLeadIds.clear();
                      } else {
                        _selectedLeadIds.addAll(
                          pendingLeads.map((document) => document.id),
                        );
                      }
                    }),
                  ),
                  if (leadSnapshot.hasError)
                    _panel('Could not load leads sent to you.', error: true)
                  else if (pendingLeads.isEmpty)
                    _panel('No interested leads are waiting for assignment.')
                  else
                    ...pendingLeads.map(_leadCard),
                  const SizedBox(height: 20),
                  _sectionHeader(
                    '2. Select executives in your team',
                    selectedExecutiveCount,
                    executives.length,
                    () => setState(() {
                      if (selectedExecutiveCount == executives.length) {
                        _selectedExecutiveIds.clear();
                      } else {
                        _selectedExecutiveIds.addAll(
                          executives.map((document) => document.id),
                        );
                      }
                    }),
                  ),
                  if (executiveSnapshot.hasError)
                    _panel('Could not load your executives.', error: true)
                  else if (executives.isEmpty)
                    _panel(
                      'No executives are assigned under you. Ask an admin to assign executives first.',
                    )
                  else
                    ...executives.map(_executiveCard),
                  const SizedBox(height: 18),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed:
                          _sending ||
                              selectedLeadCount == 0 ||
                              selectedExecutiveCount == 0
                          ? null
                          : () => _assign(pendingLeads, executives),
                      icon: _sending
                          ? const SizedBox(
                              width: 17,
                              height: 17,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded),
                      label: Text(
                        _sending
                            ? 'Sending…'
                            : 'Send $selectedLeadCount Leads to Executives',
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _leadCard(QueryDocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data();
    final interests = ((data['interestCategories'] as List?) ?? const []).join(
      ', ',
    );
    return Card(
      elevation: 0,
      child: CheckboxListTile(
        value: _selectedLeadIds.contains(document.id),
        onChanged: (selected) => setState(() {
          selected == true
              ? _selectedLeadIds.add(document.id)
              : _selectedLeadIds.remove(document.id);
        }),
        title: Text((data['name'] ?? 'Unnamed').toString()),
        subtitle: Text(
          '${(data['mobileNumber'] ?? '').toString()} · $interests\n'
          '${(data['notes'] ?? '').toString()}',
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _executiveCard(QueryDocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data();
    return Card(
      elevation: 0,
      child: CheckboxListTile(
        value: _selectedExecutiveIds.contains(document.id),
        onChanged: (selected) => setState(() {
          selected == true
              ? _selectedExecutiveIds.add(document.id)
              : _selectedExecutiveIds.remove(document.id);
        }),
        title: Text((data['name'] ?? 'Unnamed').toString()),
        subtitle: Text((data['email'] ?? '').toString()),
      ),
    );
  }

  Widget _sectionHeader(
    String title,
    int selected,
    int total,
    VoidCallback toggleAll,
  ) => Row(
    children: [
      Expanded(
        child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
      Text('$selected of $total', style: const TextStyle(color: _muted)),
      const SizedBox(width: 8),
      TextButton(
        onPressed: total == 0 ? null : toggleAll,
        child: Text(selected == total && total > 0 ? 'Clear' : 'Select all'),
      ),
    ],
  );

  Widget _panel(String text, {bool error = false}) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _border),
    ),
    child: Text(text, style: TextStyle(color: error ? _red : _muted)),
  );
}

class ReturnedLeadDistributionSection extends StatefulWidget {
  final String targetRole;
  final String targetLabel;

  const ReturnedLeadDistributionSection({
    super.key,
    required this.targetRole,
    required this.targetLabel,
  });

  @override
  State<ReturnedLeadDistributionSection> createState() =>
      _ReturnedLeadDistributionSectionState();
}

class _ReturnedLeadDistributionSectionState
    extends State<ReturnedLeadDistributionSection> {
  final Set<String> _selectedLeadIds = {};
  final Set<String> _selectedRecipientIds = {};
  bool _sending = false;
  String _categoryFilter = 'All';
  String _directoryFilter = 'All Directories';
  String _searchQuery = '';

  String get _prefix =>
      widget.targetRole == 'team_leader' ? 'teamLeader' : 'executive';

  bool _active(Map<String, dynamic> data) {
    if (data['is_active'] == false) return false;
    return (data['status'] ?? 'Active').toString().toLowerCase() != 'inactive';
  }

  Future<void> _send(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> leads,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> recipients,
  ) async {
    final selectedLeads = leads
        .where((doc) => _selectedLeadIds.contains(doc.id))
        .toList();
    final selectedRecipients = recipients
        .where((doc) => _selectedRecipientIds.contains(doc.id))
        .toList();
    if (selectedLeads.isEmpty || selectedRecipients.isEmpty) return;
    setState(() => _sending = true);
    try {
      final firestore = FirebaseFirestore.instance;
      final chunkSize = widget.targetRole == 'executive' ? 70 : 450;
      for (var start = 0; start < selectedLeads.length; start += chunkSize) {
        final end = (start + chunkSize).clamp(0, selectedLeads.length);
        final batch = firestore.batch();
        for (var index = start; index < end; index++) {
          final lead = selectedLeads[index];
          final recipient =
              selectedRecipients[index % selectedRecipients.length];
          final data = recipient.data();
          final streamResult = widget.targetRole == 'executive'
              ? _queueExecutiveCustomerStreams(
                  batch: batch,
                  firestore: firestore,
                  lead: lead,
                  executive: recipient,
                  assignedById: FirebaseAuth.instance.currentUser?.uid ?? '',
                  assignedByName:
                      FirebaseAuth.instance.currentUser?.email ?? '',
                )
              : null;
          batch.update(lead.reference, {
            '${_prefix}Forwarded': true,
            '${_prefix}AssignedToId': recipient.id,
            '${_prefix}AssignedToUid': (data['uid'] ?? '').toString(),
            '${_prefix}AssignedToName': (data['name'] ?? '').toString(),
            '${_prefix}AssignedToEmail': (data['email'] ?? '').toString(),
            '${_prefix}AssignedAt': FieldValue.serverTimestamp(),
            if (streamResult != null) ...{
              'executiveLeadStatus': 'Green',
              'leadStatus': 'Green',
              'executiveCallCount': 0,
              'executiveCallHistory': const <Map<String, dynamic>>[],
              'executiveCallNotes': const <Map<String, dynamic>>[],
              'executiveEscalatedToTeamLeader': false,
              'executiveLeadCategories': streamResult.categories,
              'executiveCustomerIds': streamResult.customerIds,
              'executiveStreamedAt': FieldValue.serverTimestamp(),
            },
          });
        }
        await batch.commit();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${selectedLeads.length} leads sent equally to ${selectedRecipients.length} ${widget.targetLabel.toLowerCase()}(s).',
          ),
          backgroundColor: _green,
        ),
      );
      setState(() {
        _selectedLeadIds.clear();
        _selectedRecipientIds.clear();
      });
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not send leads: $exception'),
            backgroundColor: _red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('data_transfer_directories')
          .snapshots(),
      builder: (context, directorySnapshot) {
        final directoryNames =
            (directorySnapshot.data?.docs ?? [])
                .map((doc) => (doc.data()['name'] ?? 'Unnamed').toString())
                .toSet()
                .toList()
              ..sort();
        if (_directoryFilter != 'All Directories' &&
            !directoryNames.contains(_directoryFilter)) {
          _directoryFilter = 'All Directories';
        }
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('telecaller_leads')
              .snapshots(),
          builder: (context, leadSnapshot) {
            final returnedLeads = (leadSnapshot.data?.docs ?? []).where((doc) {
              final data = doc.data();
              final waiting =
                  (data['status'] ?? '').toString().toLowerCase() ==
                      'returned' &&
                  (data['outcome'] ?? '').toString().toLowerCase() ==
                      'interested' &&
                  data['${_prefix}Forwarded'] != true;
              if (!waiting || _categoryFilter == 'All') return waiting;
              final categories =
                  ((data['interestCategories'] as List?) ?? const []).map(
                    (value) => value.toString().toLowerCase(),
                  );
              return categories.contains(_categoryFilter.toLowerCase());
            }).toList();
            final directoryLeads = returnedLeads
                .where(
                  (doc) =>
                      _directoryFilter == 'All Directories' ||
                      (doc.data()['directoryName'] ?? 'Unfiled').toString() ==
                          _directoryFilter,
                )
                .toList();
            final leads =
                directoryLeads.where((doc) {
                  if (_searchQuery.trim().isEmpty) return true;
                  final data = doc.data();
                  final query = _searchQuery.trim().toLowerCase();
                  return [
                    data['sNo'],
                    data['name'],
                    data['mobileNumber'],
                    data['city'],
                    data['notes'],
                    data['assignedToName'],
                    ...((data['interestCategories'] as List?) ?? const []),
                  ].any(
                    (value) => value.toString().toLowerCase().contains(query),
                  );
                }).toList()..sort(
                  (a, b) => (_date(b.data()['returnedAt']) ?? DateTime(1970))
                      .compareTo(
                        _date(a.data()['returnedAt']) ?? DateTime(1970),
                      ),
                );
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('agents')
                  .where('role', isEqualTo: widget.targetRole)
                  .snapshots(),
              builder: (context, recipientSnapshot) {
                final recipients = (recipientSnapshot.data?.docs ?? [])
                    .where((doc) => _active(doc.data()))
                    .toList();
                final selectedLeads = leads
                    .where((doc) => _selectedLeadIds.contains(doc.id))
                    .toList();
                final selectedRecipients = recipients
                    .where((doc) => _selectedRecipientIds.contains(doc.id))
                    .toList();
                return _webWorkspace(
                  allCategoryLeads: returnedLeads,
                  leads: leads,
                  directories: directoryNames,
                  recipients: recipients,
                  selectedLeads: selectedLeads,
                  selectedRecipients: selectedRecipients,
                  loading:
                      leadSnapshot.connectionState == ConnectionState.waiting,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _webWorkspace({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> allCategoryLeads,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> leads,
    required List<String> directories,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> recipients,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> selectedLeads,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>>
    selectedRecipients,
    required bool loading,
  }) {
    final allVisibleSelected =
        leads.isNotEmpty &&
        leads.every((lead) => _selectedLeadIds.contains(lead.id));
    final allRecipientsSelected =
        recipients.isNotEmpty &&
        recipients.every((agent) => _selectedRecipientIds.contains(agent.id));
    final directoryCounts = <String, int>{};
    for (final lead in allCategoryLeads) {
      final name = (lead.data()['directoryName'] ?? 'Unfiled').toString();
      directoryCounts[name] = (directoryCounts[name] ?? 0) + 1;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 3,
          child: Container(
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                Container(
                  width: 220,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    border: Border(right: BorderSide(color: _border)),
                  ),
                  child: Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Icon(Icons.folder_copy_rounded, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Returned Directories',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          children: [
                            _directoryRow(
                              'All Directories',
                              allCategoryLeads.length,
                              Icons.folder_shared_rounded,
                            ),
                            ...directories.map(
                              (name) => _directoryRow(
                                name,
                                directoryCounts[name] ?? 0,
                                Icons.folder_rounded,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        height: 58,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: _border)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.folder_open_rounded, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _directoryFilter,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            _countBadge('${leads.length} records'),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: _border)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 36,
                                child: TextField(
                                  onChanged: (value) =>
                                      setState(() => _searchQuery = value),
                                  decoration: InputDecoration(
                                    hintText:
                                        'Search name, phone, city, notes...',
                                    prefixIcon: const Icon(
                                      Icons.search,
                                      size: 18,
                                    ),
                                    filled: true,
                                    fillColor: const Color(0xFFF8FAFC),
                                    isDense: true,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            _categoryFilters(
                              selected: _categoryFilter,
                              onSelected: (category) => setState(() {
                                _categoryFilter = category;
                                _directoryFilter = 'All Directories';
                                _selectedLeadIds.clear();
                              }),
                            ),
                          ],
                        ),
                      ),
                      _excelHeader(
                        selected: allVisibleSelected,
                        onSelected: (value) => setState(() {
                          if (value == true) {
                            _selectedLeadIds.addAll(
                              leads.map((lead) => lead.id),
                            );
                          } else {
                            _selectedLeadIds.removeAll(
                              leads.map((lead) => lead.id),
                            );
                          }
                        }),
                      ),
                      Expanded(
                        child: loading
                            ? const Center(child: CircularProgressIndicator())
                            : leads.isEmpty
                            ? _empty('No returned leads match this view.')
                            : ListView.builder(
                                itemCount: leads.length,
                                itemExtent: 46,
                                itemBuilder: (context, index) =>
                                    _excelLeadRow(leads[index], index),
                              ),
                      ),
                      Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF8FAFC),
                          border: Border(top: BorderSide(color: _border)),
                        ),
                        child: Row(
                          children: [
                            Text(
                              '${selectedLeads.length} selected',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${leads.length} visible rows',
                              style: const TextStyle(color: _muted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),
        SizedBox(
          width: 320,
          child: Container(
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(Icons.groups_2_rounded),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Assign ${widget.targetLabel}s',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Checkbox(
                        value: allRecipientsSelected,
                        onChanged: (value) => setState(() {
                          if (value == true) {
                            _selectedRecipientIds.addAll(
                              recipients.map((agent) => agent.id),
                            );
                          } else {
                            _selectedRecipientIds.clear();
                          }
                        }),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: recipients.isEmpty
                      ? _empty('No active recipients found.')
                      : ListView.builder(
                          itemCount: recipients.length,
                          itemBuilder: (context, index) {
                            final agent = recipients[index];
                            return _recipientTile(
                              agent,
                              selectedLeads.length,
                              selectedRecipients.length,
                            );
                          },
                        ),
                ),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: _border)),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed:
                          _sending ||
                              selectedLeads.isEmpty ||
                              selectedRecipients.isEmpty
                          ? null
                          : () => _send(leads, recipients),
                      icon: _sending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.call_split_rounded),
                      label: Text(
                        _sending
                            ? 'Assigning...'
                            : 'Assign ${selectedLeads.length} Leads',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _directoryRow(String name, int count, IconData icon) {
    final selected = _directoryFilter == name;
    return InkWell(
      onTap: () => setState(() {
        _directoryFilter = name;
        _selectedLeadIds.clear();
      }),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFDDEBFA) : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          children: [
            Icon(icon, size: 17, color: const Color(0xFF0D2D4F)),
            const SizedBox(width: 8),
            Expanded(child: Text(name, overflow: TextOverflow.ellipsis)),
            Text('$count', style: const TextStyle(fontSize: 11, color: _muted)),
          ],
        ),
      ),
    );
  }

  Widget _countBadge(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFFDDEBFA),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(
      text,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
    ),
  );

  Widget _excelHeader({
    required bool selected,
    required ValueChanged<bool?> onSelected,
  }) => Container(
    height: 36,
    padding: const EdgeInsets.symmetric(horizontal: 8),
    color: const Color(0xFF0D2D4F),
    child: Row(
      children: [
        SizedBox(
          width: 34,
          child: Checkbox(
            value: selected,
            onChanged: onSelected,
            fillColor: WidgetStateProperty.all(Colors.white),
            checkColor: const Color(0xFF0D2D4F),
          ),
        ),
        _excelCell('S.No', 1, header: true),
        _excelCell('Name', 3, header: true),
        _excelCell('Phone', 2, header: true),
        _excelCell('City', 2, header: true),
        _excelCell('Category', 2, header: true),
        _excelCell('Telecaller', 2, header: true),
        _excelCell('Notes', 3, header: true),
        _excelCell('Returned', 2, header: true),
      ],
    ),
  );

  Widget _excelLeadRow(
    QueryDocumentSnapshot<Map<String, dynamic>> lead,
    int index,
  ) {
    final data = lead.data();
    final selected = _selectedLeadIds.contains(lead.id);
    return InkWell(
      onTap: () => setState(
        () => selected
            ? _selectedLeadIds.remove(lead.id)
            : _selectedLeadIds.add(lead.id),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        color: selected
            ? const Color(0xFFEAF3FC)
            : index.isEven
            ? Colors.white
            : const Color(0xFFFAFBFC),
        child: Row(
          children: [
            SizedBox(
              width: 34,
              child: Checkbox(
                value: selected,
                onChanged: (_) => setState(
                  () => selected
                      ? _selectedLeadIds.remove(lead.id)
                      : _selectedLeadIds.add(lead.id),
                ),
              ),
            ),
            _excelCell((data['sNo'] ?? index + 1).toString(), 1),
            _excelCell((data['name'] ?? '').toString(), 3),
            _excelCell((data['mobileNumber'] ?? '').toString(), 2),
            _excelCell((data['city'] ?? '').toString(), 2),
            _excelCell(
              ((data['interestCategories'] as List?) ?? const []).join(', '),
              2,
            ),
            _excelCell((data['assignedToName'] ?? '').toString(), 2),
            _excelCell((data['notes'] ?? '').toString(), 3),
            _excelCell(_dateLabel(data['returnedAt']), 2),
          ],
        ),
      ),
    );
  }

  Widget _excelCell(String text, int flex, {bool header = false}) => Expanded(
    flex: flex,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          color: header ? Colors.white : _text,
          fontWeight: header ? FontWeight.w800 : FontWeight.w500,
        ),
      ),
    ),
  );

  Widget _recipientTile(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    int leadCount,
    int recipientCount,
  ) {
    final data = doc.data();
    final selected = _selectedRecipientIds.contains(doc.id);
    final position = _selectedRecipientIds.toList().indexOf(doc.id);
    final count = selected && recipientCount > 0
        ? leadCount ~/ recipientCount +
              (position < leadCount % recipientCount ? 1 : 0)
        : 0;
    return Card(
      elevation: 0,
      child: CheckboxListTile(
        value: selected,
        onChanged: (value) => setState(() {
          value == true
              ? _selectedRecipientIds.add(doc.id)
              : _selectedRecipientIds.remove(doc.id);
        }),
        title: Text((data['name'] ?? '').toString()),
        subtitle: Text((data['email'] ?? '').toString()),
        secondary: selected ? Chip(label: Text('$count leads')) : null,
      ),
    );
  }

  Widget _empty(String message) => Container(
    padding: const EdgeInsets.all(28),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _border),
    ),
    child: Text(message, style: const TextStyle(color: _muted)),
  );
}
