import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../utils/audit_log_service.dart';
import '../../utils/spreadsheet_picker.dart';
import '../../utils/spreadsheet_reader.dart';
import 'telecaller_leads_tab.dart';

enum DataTransferPage { importData, assignData, transferLeads }

class DataTransferTab extends StatelessWidget {
  final Map<String, dynamic> userData;
  final DataTransferPage page;

  const DataTransferTab({
    super.key,
    required this.userData,
    this.page = DataTransferPage.importData,
  });

  static const _background = Color(0xFFF4F6F9);
  static const _surface = Colors.white;
  static const _border = Color(0xFFE4E7EC);
  static const _text = Color(0xFF0D1B2A);
  static const _muted = Color(0xFF667085);
  static const _primary = Color(0xFF0D2D4F);

  @override
  Widget build(BuildContext context) {
    final role = (userData['role'] ?? 'admin').toString().toLowerCase();
    if (role == 'team_leader') {
      return TeamLeaderDataTransferDashboard(userData: userData);
    }
    if (role == 'executive') {
      return ForwardedLeadsDashboard(userData: userData, role: 'executive');
    }

    if (page == DataTransferPage.transferLeads) {
      return const Scaffold(
        backgroundColor: _background,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: _EmployeeLeadTransferSection(),
          ),
        ),
      );
    }

    if (page == DataTransferPage.assignData) {
      return const Scaffold(
        backgroundColor: _background,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: _AssignDataSection(),
          ),
        ),
      );
    }

    return const Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: _TelecallerDistributionSection(),
        ),
      ),
    );
  }
}

class _TelecallerDistributionSection extends StatefulWidget {
  const _TelecallerDistributionSection();

  @override
  State<_TelecallerDistributionSection> createState() =>
      _TelecallerDistributionSectionState();
}

class _AssignDataSection extends StatelessWidget {
  const _AssignDataSection();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Container(
        decoration: BoxDecoration(
          color: DataTransferTab._surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: DataTransferTab._border),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                border: Border(
                  bottom: BorderSide(color: DataTransferTab._border),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.swap_horiz_rounded,
                    color: DataTransferTab._primary,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Leads and send data to the team',
                      style: TextStyle(
                        color: DataTransferTab._text,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 430,
                    child: TabBar(
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelColor: Colors.white,
                      unselectedLabelColor: DataTransferTab._muted,
                      indicator: BoxDecoration(
                        color: DataTransferTab._primary,
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                      ),
                      tabs: [
                        Tab(text: 'Send returned leads'),
                        Tab(text: 'Transfer the leads employee to employee'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  Padding(
                    padding: EdgeInsets.all(12),
                    child: ReturnedLeadDistributionSection(
                      targetRole: 'team_leader',
                      targetLabel: 'Team Leader',
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(12),
                    child: _EmployeeLeadTransferSection(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmployeeLeadTransferSection extends StatefulWidget {
  const _EmployeeLeadTransferSection();

  @override
  State<_EmployeeLeadTransferSection> createState() =>
      _EmployeeLeadTransferSectionState();
}

class _EmployeeLeadTransferSectionState
    extends State<_EmployeeLeadTransferSection> {
  final Set<String> _selectedLeadIds = {};
  String? _sourceEmployeeId;
  String? _targetEmployeeId;
  String _search = '';
  bool _transferring = false;

  bool _isActive(Map<String, dynamic> data) {
    if (data['is_active'] == false) return false;
    final status = (data['status'] ?? 'Active').toString().toLowerCase();
    return status != 'inactive' && status != 'disabled';
  }

  String _employeeName(Map<String, dynamic> data) =>
      (data['name'] ?? data['email'] ?? 'Employee').toString();

  String _employeeRole(Map<String, dynamic> data) =>
      (data['roleLabel'] ?? data['role'] ?? '').toString();

  bool _ownedBy(Map<String, dynamic> data, String employeeId) =>
      (data['assignedToId'] ?? '').toString() == employeeId ||
      (data['teamLeaderAssignedToId'] ?? '').toString() == employeeId ||
      (data['executiveAssignedToId'] ?? '').toString() == employeeId;

  String _ownerStage(Map<String, dynamic> data, String employeeId) {
    if ((data['assignedToId'] ?? '').toString() == employeeId) {
      return 'Telecaller';
    }
    if ((data['teamLeaderAssignedToId'] ?? '').toString() == employeeId) {
      return 'Team Leader';
    }
    if ((data['executiveAssignedToId'] ?? '').toString() == employeeId) {
      return 'Executive';
    }
    return 'Assigned';
  }

  String _leadId(Map<String, dynamic> data) {
    for (final key in const [
      'leadUniqueId',
      'uniqueLeadId',
      'leadSerialNumber',
      'makkLeadId',
    ]) {
      final value = (data[key] ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }
    return '-';
  }

  String _leadName(Map<String, dynamic> data) =>
      (data['name'] ?? data['fullName'] ?? data['customerName'] ?? '-')
          .toString();

  String _leadPhone(Map<String, dynamic> data) =>
      (data['mobileNumber'] ?? data['phone'] ?? data['customerMobile'] ?? '-')
          .toString();

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filterLeads(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> leads,
  ) {
    final sourceId = _sourceEmployeeId;
    if (sourceId == null || sourceId.isEmpty) return [];
    final q = _search.trim().toLowerCase();
    final rows = leads.where((lead) {
      final data = lead.data();
      if (!_ownedBy(data, sourceId)) return false;
      if (q.isEmpty) return true;
      final haystack = [
        _leadId(data),
        _leadName(data),
        _leadPhone(data),
        data['city'],
        data['category'],
        data['outcome'],
        data['leadStatus'],
        data['directoryName'],
      ].map((value) => (value ?? '').toString().toLowerCase()).join(' ');
      return haystack.contains(q);
    }).toList();
    rows.sort((a, b) {
      final aDate = a.data()['assignedAt'];
      final bDate = b.data()['assignedAt'];
      final aMs = aDate is Timestamp ? aDate.millisecondsSinceEpoch : 0;
      final bMs = bDate is Timestamp ? bDate.millisecondsSinceEpoch : 0;
      return bMs.compareTo(aMs);
    });
    return rows;
  }

  QueryDocumentSnapshot<Map<String, dynamic>>? _employeeById(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> employees,
    String? id,
  ) {
    if (id == null || id.isEmpty) return null;
    for (final employee in employees) {
      if (employee.id == id) return employee;
    }
    return null;
  }

  Future<void> _transfer(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> leads,
    QueryDocumentSnapshot<Map<String, dynamic>> target,
  ) async {
    final sourceId = _sourceEmployeeId;
    if (sourceId == null || sourceId.isEmpty || _selectedLeadIds.isEmpty) {
      return;
    }
    final selected = leads
        .where((lead) => _selectedLeadIds.contains(lead.id))
        .toList();
    if (selected.isEmpty) return;

    setState(() => _transferring = true);
    try {
      final targetData = target.data();
      final batch = FirebaseFirestore.instance.batch();
      for (final lead in selected) {
        final data = lead.data();
        final update = <String, dynamic>{
          'transferredAt': FieldValue.serverTimestamp(),
          'transferredFromId': sourceId,
          'transferredToId': target.id,
          'transferredToName': _employeeName(targetData),
        };
        if ((data['assignedToId'] ?? '').toString() == sourceId) {
          update.addAll({
            'assignedToId': target.id,
            'assignedToUid': (targetData['uid'] ?? '').toString(),
            'assignedToName': _employeeName(targetData),
            'assignedToEmail': (targetData['email'] ?? '').toString(),
            'assignedAt': FieldValue.serverTimestamp(),
          });
        }
        if ((data['teamLeaderAssignedToId'] ?? '').toString() == sourceId) {
          update.addAll({
            'teamLeaderAssignedToId': target.id,
            'teamLeaderAssignedToUid': (targetData['uid'] ?? '').toString(),
            'teamLeaderAssignedToName': _employeeName(targetData),
            'teamLeaderAssignedAt': FieldValue.serverTimestamp(),
          });
        }
        if ((data['executiveAssignedToId'] ?? '').toString() == sourceId) {
          update.addAll({
            'executiveAssignedToId': target.id,
            'executiveAssignedToUid': (targetData['uid'] ?? '').toString(),
            'executiveAssignedToName': _employeeName(targetData),
            'executiveAssignedAt': FieldValue.serverTimestamp(),
          });
        }
        batch.update(lead.reference, update);
      }
      await batch.commit();
      await AuditLogService.write(
        page: 'Data Transfer',
        action: 'Transferred Leads',
        description:
            'Transferred ${selected.length} lead(s) to ${_employeeName(targetData)}.',
        targetId: target.id,
        targetType: 'Employee',
        targetName: _employeeName(targetData),
      );
      if (!mounted) return;
      setState(() => _selectedLeadIds.clear());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${selected.length} lead(s) transferred.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not transfer leads: $error')),
      );
    } finally {
      if (mounted) setState(() => _transferring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('agents').snapshots(),
      builder: (context, employeeSnapshot) {
        final employees =
            (employeeSnapshot.data?.docs ?? [])
                .where((doc) => _isActive(doc.data()))
                .where(
                  (doc) => (doc.data()['role'] ?? '').toString() != 'admin',
                )
                .toList()
              ..sort(
                (a, b) => _employeeName(a.data()).toLowerCase().compareTo(
                  _employeeName(b.data()).toLowerCase(),
                ),
              );
        final source = _employeeById(employees, _sourceEmployeeId);
        final target = _employeeById(employees, _targetEmployeeId);

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('telecaller_leads')
              .snapshots(),
          builder: (context, leadSnapshot) {
            final leads = _filterLeads(leadSnapshot.data?.docs ?? []);
            _selectedLeadIds.removeWhere(
              (id) => !leads.any((lead) => lead.id == id),
            );
            final allSelected =
                leads.isNotEmpty &&
                leads.every((lead) => _selectedLeadIds.contains(lead.id));
            final canTransfer =
                !_transferring &&
                source != null &&
                target != null &&
                source.id != target.id &&
                _selectedLeadIds.isNotEmpty;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _employeeDropdown(
                        label: 'From employee',
                        value: _sourceEmployeeId,
                        employees: employees,
                        onChanged: (value) {
                          setState(() {
                            _sourceEmployeeId = value;
                            _selectedLeadIds.clear();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _employeeDropdown(
                        label: 'To employee',
                        value: _targetEmployeeId,
                        employees: employees
                            .where(
                              (employee) => employee.id != _sourceEmployeeId,
                            )
                            .toList(),
                        onChanged: (value) => setState(() {
                          _targetEmployeeId = value;
                        }),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        onChanged: (value) => setState(() => _search = value),
                        decoration: InputDecoration(
                          labelText: 'Search selected employee leads',
                          prefixIcon: const Icon(Icons.search_rounded),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: canTransfer
                          ? () => _transfer(leads, target)
                          : null,
                      icon: _transferring
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.swap_horiz_rounded),
                      label: Text(
                        _transferring
                            ? 'Transferring...'
                            : 'Transfer ${_selectedLeadIds.length}',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DataTransferTab._primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: DataTransferTab._border),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(10),
                            ),
                            border: Border(
                              bottom: BorderSide(
                                color: DataTransferTab._border,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Checkbox(
                                value: allSelected,
                                onChanged: leads.isEmpty
                                    ? null
                                    : (_) => setState(() {
                                        if (allSelected) {
                                          _selectedLeadIds.clear();
                                        } else {
                                          _selectedLeadIds.addAll(
                                            leads.map((lead) => lead.id),
                                          );
                                        }
                                      }),
                              ),
                              Text(
                                source == null
                                    ? 'Select an employee to view leads'
                                    : '${leads.length} lead(s) assigned to ${_employeeName(source.data())}',
                                style: const TextStyle(
                                  color: DataTransferTab._text,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${_selectedLeadIds.length} selected',
                                style: const TextStyle(
                                  color: DataTransferTab._muted,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: leads.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No leads found for this employee.',
                                    style: TextStyle(
                                      color: DataTransferTab._muted,
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: leads.length,
                                  separatorBuilder: (context, index) =>
                                      const Divider(
                                        height: 1,
                                        color: DataTransferTab._border,
                                      ),
                                  itemBuilder: (context, index) {
                                    final lead = leads[index];
                                    final data = lead.data();
                                    final selected = _selectedLeadIds.contains(
                                      lead.id,
                                    );
                                    return CheckboxListTile(
                                      value: selected,
                                      onChanged: (_) => setState(() {
                                        selected
                                            ? _selectedLeadIds.remove(lead.id)
                                            : _selectedLeadIds.add(lead.id);
                                      }),
                                      controlAffinity:
                                          ListTileControlAffinity.leading,
                                      title: Text(
                                        '${_leadName(data)}  |  ${_leadPhone(data)}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      subtitle: Text(
                                        'Lead ID: ${_leadId(data)}  |  ${_ownerStage(data, _sourceEmployeeId ?? '')}  |  ${(data['category'] ?? data['outcome'] ?? '').toString()}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      secondary: Text(
                                        (data['directoryName'] ?? '')
                                            .toString(),
                                        style: const TextStyle(
                                          color: DataTransferTab._muted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
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

  Widget _employeeDropdown({
    required String label,
    required String? value,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> employees,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: employees.any((employee) => employee.id == value)
          ? value
          : null,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        isDense: true,
      ),
      items: employees.map((employee) {
        final data = employee.data();
        return DropdownMenuItem(
          value: employee.id,
          child: Text(
            '${_employeeName(data)} (${_employeeRole(data)})',
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}

class _TelecallerDistributionSectionState
    extends State<_TelecallerDistributionSection> {
  // Directory State
  String _selectedDirectoryId = 'ALL';
  String _selectedDirectoryName = 'All Directories';
  String _directorySearchQuery = '';
  final TextEditingController _directorySearchController =
      TextEditingController();

  // Grid & Search State
  String _gridSearchQuery = '';
  final TextEditingController _gridSearchController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();

  // Selection & Telecaller State
  final Set<String> _selectedContactIds = {};
  final Set<String> _selectedTelecallerIds = {};
  String _telecallerSearchQuery = '';
  final TextEditingController _telecallerSearchController =
      TextEditingController();

  // Operation State
  String? _fileName;
  String? _pendingBatchId;
  String? _error;
  String _poolFilter = 'All'; // 'All', 'Unassigned', 'Assigned'
  int _duplicatesInCurrentFile = 0;
  bool _readingFile = false;
  bool _distributing = false;

  @override
  void initState() {
    super.initState();
    _ensureDemoDirectoryAndMigrateData();
  }

  Future<void> _ensureDemoDirectoryAndMigrateData() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final dirQuery = await firestore
          .collection('data_transfer_directories')
          .where('nameKey', isEqualTo: 'demo')
          .get();

      String demoId;
      if (dirQuery.docs.isEmpty) {
        final user = FirebaseAuth.instance.currentUser;
        final docRef = await firestore
            .collection('data_transfer_directories')
            .add({
              'name': 'Demo',
              'nameKey': 'demo',
              'createdAt': FieldValue.serverTimestamp(),
              'createdBy': user?.uid ?? '',
              'createdByEmail': user?.email ?? '',
            });
        demoId = docRef.id;
      } else {
        demoId = dirQuery.docs.first.id;
      }

      if (_selectedDirectoryId == 'ALL' || _selectedDirectoryId.isEmpty) {
        if (mounted) {
          setState(() {
            _selectedDirectoryId = demoId;
            _selectedDirectoryName = 'Demo';
          });
        }
      }

      final contactsDocs = await firestore
          .collection('data_transfer_contacts')
          .get();

      final batch = firestore.batch();
      var needCommit = false;
      for (final doc in contactsDocs.docs) {
        final data = doc.data();
        final currentDirId = data['directoryId'];
        if (currentDirId == null ||
            currentDirId == '' ||
            currentDirId == 'ALL') {
          batch.update(doc.reference, {
            'directoryId': demoId,
            'directoryName': 'Demo',
          });
          needCommit = true;
        }
      }
      if (needCommit) {
        await batch.commit();
      }
    } catch (e) {
      debugPrint('Error ensuring demo directory: $e');
    }
  }

  @override
  void dispose() {
    _directorySearchController.dispose();
    _gridSearchController.dispose();
    _quantityController.dispose();
    _telecallerSearchController.dispose();
    super.dispose();
  }

  // --- DIRECTORY CREATION & MANAGEMENT ---
  Future<void> _showCreateDirectoryDialog() async {
    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final created = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.create_new_folder_rounded, color: Color(0xFF0D2D4F)),
            SizedBox(width: 8),
            Text(
              'Create New Directory',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Directory / Folder Name',
              hintText: 'e.g. Health Leads Q3, Delhi Region',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a directory name.';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, nameController.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D2D4F),
              foregroundColor: Colors.white,
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (created == null || created.isEmpty || !mounted) return;

    try {
      final firestore = FirebaseFirestore.instance;
      final existing = await firestore
          .collection('data_transfer_directories')
          .where('nameKey', isEqualTo: created.toLowerCase())
          .get();

      if (existing.docs.isNotEmpty) {
        setState(() => _error = 'A directory named "$created" already exists.');
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      final docRef = await firestore
          .collection('data_transfer_directories')
          .add({
            'name': created,
            'nameKey': created.toLowerCase(),
            'createdAt': FieldValue.serverTimestamp(),
            'createdBy': user?.uid ?? '',
            'createdByEmail': user?.email ?? '',
          });

      setState(() {
        _selectedDirectoryId = docRef.id;
        _selectedDirectoryName = created;
        _error = null;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Directory "$created" created successfully.'),
          backgroundColor: const Color(0xFF059669),
        ),
      );
    } catch (e) {
      setState(() => _error = 'Failed to create directory: $e');
    }
  }

  // --- EXCEL FILE UPLOAD & PARSING ---
  Future<bool> _confirmExcelFormat() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Dump Excel Data Format'),
        content: const SizedBox(
          width: 460,
          child: Text(
            'Make the Excel sheet with these exact columns:\n\n'
            'S.No | Name | Phone Number | City | Already Policy\n\n'
            'Mandatory fields: Name and Phone Number only.\n'
            'S.No, City, and Already Policy are optional.\n'
            'You can add extra columns also; they will be saved and searchable, but the table will show the standard columns above.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.upload_file_rounded, size: 16),
            label: const Text('Select Excel File'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _pickExcelFile() async {
    final proceed = await _confirmExcelFormat();
    if (!proceed || !mounted) return;
    setState(() {
      _readingFile = true;
      _error = null;
    });
    try {
      final file = await pickSpreadsheetBytes();
      if (file == null) return;
      final bytes = file.bytes;
      if (bytes.isEmpty) {
        throw const FormatException('Could not read the selected Excel file.');
      }
      final extension = file.name.split('.').last.toLowerCase();
      final contacts = _parseWorkbook(bytes, extension);
      final stored = await _storeContacts(contacts, file.name);
      final duplicateCount = stored.duplicateCount + _duplicatesInCurrentFile;

      if (!mounted) return;
      setState(() {
        _fileName = file.name;
        _pendingBatchId = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${stored.added.length} contact(s) imported into "$_selectedDirectoryName". '
            '$duplicateCount duplicate(s) skipped.',
          ),
          backgroundColor: const Color(0xFF059669),
        ),
      );
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not read the Excel file: $error');
      }
    } finally {
      if (mounted) setState(() => _readingFile = false);
    }
  }

  Future<_StoredImportResult> _storeContacts(
    List<_ImportedContact> contacts,
    String sourceFileName,
  ) async {
    final firestore = FirebaseFirestore.instance;
    final collection = firestore.collection('data_transfer_contacts');
    final keys = contacts
        .map((contact) => _mobileKey(contact.mobileNumber))
        .toList();
    final poolKeys = <String>{};

    for (var start = 0; start < keys.length; start += 30) {
      final end = (start + 30).clamp(0, keys.length);
      final snapshot = await collection
          .where('directoryId', isEqualTo: _selectedDirectoryId)
          .where('mobileNumberKey', whereIn: keys.sublist(start, end))
          .get();
      poolKeys.addAll(
        snapshot.docs.map(
          (document) => (document.data()['mobileNumberKey'] ?? '').toString(),
        ),
      );
    }

    final added = contacts
        .where(
          (contact) => !poolKeys.contains(_mobileKey(contact.mobileNumber)),
        )
        .toList();

    final user = FirebaseAuth.instance.currentUser;
    for (var start = 0; start < added.length; start += 450) {
      final end = (start + 450).clamp(0, added.length);
      final batch = firestore.batch();
      for (var index = start; index < end; index++) {
        final contact = added[index];
        final key = _mobileKey(contact.mobileNumber);
        final docId = '${_selectedDirectoryId}_mobile_$key';
        batch.set(collection.doc(docId), {
          'sNo': contact.sNo,
          'name': contact.name,
          'mobileNumber': contact.mobileNumber,
          'mobileNumberKey': key,
          'city': contact.city,
          'alreadyPolicy': contact.alreadyPolicy,
          'extraFields': contact.extraFields,
          'extraSearchText': contact.extraSearchText,
          'importHeaders': contact.importHeaders,
          'directoryId': _selectedDirectoryId,
          'directoryName': _selectedDirectoryName,
          'status': 'Unassigned',
          'sourceFileName': sourceFileName,
          'sourceRow': contact.sourceRow,
          'uploadedAt': FieldValue.serverTimestamp(),
          'uploadedBy': user?.uid ?? '',
          'uploadedByEmail': user?.email ?? '',
        });
      }
      await batch.commit();
    }

    return _StoredImportResult(
      added: added,
      duplicateCount: contacts.length - added.length,
    );
  }

  List<_ImportedContact> _parseWorkbook(Uint8List bytes, String extension) {
    final rows = readSpreadsheetRows(bytes, extension);
    if (rows.isEmpty) {
      throw const FormatException('The Excel sheet is empty.');
    }

    final headerRowIndex = rows.indexWhere(
      (row) => row.any((cell) => _cellText(cell).isNotEmpty),
    );
    if (headerRowIndex < 0) {
      throw const FormatException('The Excel sheet is empty.');
    }

    final header = rows[headerRowIndex].map((cell) => _cellText(cell)).toList();
    final normalizedHeader = header.map(_normalizeHeader).toList();

    int nameIndex = -1;
    int mobileIndex = -1;
    int sNoIndex = -1;
    int cityIndex = -1;
    int policyIndex = -1;

    for (var i = 0; i < header.length; i++) {
      final val = normalizedHeader[i];
      if (const {
        'name',
        'customername',
        'clientname',
        'fullname',
        'personname',
      }.contains(val)) {
        nameIndex = i;
      } else if (const {
        'mobilenumber',
        'mobile',
        'mobileno',
        'phonenumber',
        'phone',
        'contact',
        'contactno',
        'tel',
      }.contains(val)) {
        mobileIndex = i;
      } else if (const {
        'sno',
        's.no',
        's no',
        'slno',
        'sl.no',
        'serial',
        'serialno',
        'id',
        'no',
      }.contains(val)) {
        sNoIndex = i;
      } else if (const {
        'city',
        'location',
        'district',
        'address',
        'town',
        'place',
      }.contains(val)) {
        cityIndex = i;
      } else if (const {
        'alreadypolicy',
        'policy',
        'existingpolicy',
        'policyno',
        'policynumber',
        'haspolicy',
        'status',
        'policydetails',
      }.contains(val)) {
        policyIndex = i;
      }
    }

    if (nameIndex < 0 || mobileIndex < 0) {
      throw const FormatException(
        'The header row must contain at least "Name" and "Phone Number" columns.',
      );
    }

    final contacts = <_ImportedContact>[];
    final errors = <String>[];
    final seenMobiles = <String>{};
    var duplicateRows = 0;

    for (
      var rowIndex = headerRowIndex + 1;
      rowIndex < rows.length;
      rowIndex++
    ) {
      final row = rows[rowIndex];
      final populated = row
          .asMap()
          .entries
          .where((entry) => _cellText(entry.value).isNotEmpty)
          .toList();
      if (populated.isEmpty) continue;

      final name = nameIndex < row.length ? _cellText(row[nameIndex]) : '';
      final rawMobile = mobileIndex < row.length
          ? _cellText(row[mobileIndex])
          : '';
      final sNo = sNoIndex >= 0 && sNoIndex < row.length
          ? _cellText(row[sNoIndex])
          : (contacts.length + 1).toString();
      final city = cityIndex >= 0 && cityIndex < row.length
          ? _cellText(row[cityIndex])
          : '';
      final alreadyPolicy = policyIndex >= 0 && policyIndex < row.length
          ? _cellText(row[policyIndex])
          : '';
      final reservedIndexes = {
        nameIndex,
        mobileIndex,
        sNoIndex,
        cityIndex,
        policyIndex,
      }.where((index) => index >= 0).toSet();
      final extraFields = <String, String>{};
      for (var columnIndex = 0; columnIndex < header.length; columnIndex++) {
        if (reservedIndexes.contains(columnIndex)) continue;
        final label = header[columnIndex].trim().isNotEmpty
            ? header[columnIndex].trim()
            : 'Column ${columnIndex + 1}';
        final value = columnIndex < row.length
            ? _cellText(row[columnIndex])
            : '';
        if (value.isNotEmpty) extraFields[label] = value;
      }

      final mobile = _normalizeMobile(rawMobile);

      if (name.isEmpty) {
        errors.add('Row ${rowIndex + 1}: Name is missing.');
      } else if (!RegExp(r'^\+?\d{10,15}$').hasMatch(mobile)) {
        errors.add(
          'Row ${rowIndex + 1}: Phone number is invalid ($rawMobile).',
        );
      } else if (!seenMobiles.add(mobile)) {
        duplicateRows++;
      } else {
        contacts.add(
          _ImportedContact(
            sourceRow: rowIndex + 1,
            sNo: sNo,
            name: name,
            mobileNumber: mobile,
            city: city,
            alreadyPolicy: alreadyPolicy,
            extraFields: extraFields,
            importHeaders: header,
          ),
        );
      }
    }

    if (errors.isNotEmpty) {
      final shown = errors.take(5).join('\n');
      final remaining = errors.length - 5;
      throw FormatException(
        '$shown${remaining > 0 ? '\n…and $remaining more error(s).' : ''}',
      );
    }
    if (contacts.isEmpty) {
      throw const FormatException('No valid contact rows were found.');
    }

    _duplicatesInCurrentFile = duplicateRows;
    return contacts;
  }

  String _cellText(dynamic cell) {
    var value = cell?.toString().trim() ?? '';
    if (value.endsWith('.0') && RegExp(r'^\d+\.0$').hasMatch(value)) {
      value = value.substring(0, value.length - 2);
    }
    return value;
  }

  String _normalizeHeader(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9.]'), '')
      .replaceAll('.', '');

  String _normalizeMobile(String value) {
    final trimmed = value.trim().replaceFirst(RegExp(r"^'"), '');
    final hasPlus = trimmed.startsWith('+');
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    return hasPlus ? '+$digits' : digits;
  }

  String _mobileKey(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
  }

  String _extraFieldsText(Map<String, dynamic> data) {
    final fields = data['extraFields'];
    if (fields is! Map || fields.isEmpty) return '';
    return fields.entries
        .map((entry) {
          final key = entry.key.toString().trim();
          final value = entry.value?.toString().trim() ?? '';
          if (value.isEmpty) return '';
          return key.isEmpty ? value : '$key: $value';
        })
        .where((value) => value.isNotEmpty)
        .join(' | ');
  }

  bool _isActive(Map<String, dynamic> data) {
    if (data['is_active'] == false) return false;
    final status = (data['status'] ?? 'Active').toString().toLowerCase();
    return status != 'inactive' && status != 'disabled';
  }

  Map<String, int> _distributionCounts(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> selected,
    int contactCount,
  ) {
    if (selected.isEmpty) return const {};
    final base = contactCount ~/ selected.length;
    final remainder = contactCount % selected.length;
    return {
      for (var index = 0; index < selected.length; index++)
        selected[index].id: base + (index < remainder ? 1 : 0),
    };
  }

  // --- EQUAL DISTRIBUTION ACTION ---
  Future<void> _distribute(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> poolContacts,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> telecallers,
  ) async {
    final selectedTelecallers = telecallers
        .where((doc) => _selectedTelecallerIds.contains(doc.id))
        .toList();
    final selectedContacts = poolContacts
        .where((doc) => _selectedContactIds.contains(doc.id))
        .toList();

    if (selectedContacts.isEmpty || selectedTelecallers.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Data Distribution'),
        content: Text(
          'Send ${selectedContacts.length} selected lead(s) to '
          '${selectedTelecallers.length} selected telecaller(s)?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D2D4F),
              foregroundColor: Colors.white,
            ),
            child: const Text('Send Lead to Team'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _distributing = true;
      _error = null;
    });

    final firestore = FirebaseFirestore.instance;
    final batchCollection = firestore.collection('data_transfer_batches');
    final batchReference = _pendingBatchId == null
        ? batchCollection.doc()
        : batchCollection.doc(_pendingBatchId);
    _pendingBatchId ??= batchReference.id;
    final currentUser = FirebaseAuth.instance.currentUser;
    final counts = _distributionCounts(
      selectedTelecallers,
      selectedContacts.length,
    );

    try {
      await batchReference.set({
        'type': 'telecaller_data',
        'directoryId': _selectedDirectoryId,
        'directoryName': _selectedDirectoryName,
        'sourceFileName': _fileName ?? 'Directory Import',
        'totalRecords': selectedContacts.length,
        'telecallerCount': selectedTelecallers.length,
        'status': 'Processing',
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': currentUser?.uid ?? '',
        'createdByEmail': currentUser?.email ?? '',
        'telecallers': selectedTelecallers.map((doc) {
          final data = doc.data();
          return {
            'documentId': doc.id,
            'uid': (data['uid'] ?? '').toString(),
            'name': (data['name'] ?? '').toString(),
            'email': (data['email'] ?? '').toString(),
            'assignedCount': counts[doc.id] ?? 0,
          };
        }).toList(),
      });

      for (var start = 0; start < selectedContacts.length; start += 225) {
        final end = (start + 225).clamp(0, selectedContacts.length);
        final writeBatch = firestore.batch();

        for (var index = start; index < end; index++) {
          final contactDocument = selectedContacts[index];
          final contact = contactDocument.data();
          final telecaller =
              selectedTelecallers[index % selectedTelecallers.length];
          final telecallerData = telecaller.data();

          final leadReference = firestore
              .collection('telecaller_leads')
              .doc(contactDocument.id);

          writeBatch.set(leadReference, {
            'sNo': (contact['sNo'] ?? '').toString(),
            'name': (contact['name'] ?? '').toString(),
            'mobileNumber': (contact['mobileNumber'] ?? '').toString(),
            'city': (contact['city'] ?? '').toString(),
            'alreadyPolicy': (contact['alreadyPolicy'] ?? '').toString(),
            'extraFields': Map<String, dynamic>.from(
              contact['extraFields'] as Map? ?? {},
            ),
            'extraSearchText': (contact['extraSearchText'] ?? '').toString(),
            'importHeaders': List<dynamic>.from(
              contact['importHeaders'] as List? ?? [],
            ),
            'directoryId': (contact['directoryId'] ?? _selectedDirectoryId)
                .toString(),
            'directoryName':
                (contact['directoryName'] ?? _selectedDirectoryName).toString(),
            'status': 'Assigned',
            'batchId': batchReference.id,
            'poolContactId': contactDocument.id,
            'sourceFileName': (contact['sourceFileName'] ?? '').toString(),
            'sourceRow': contact['sourceRow'] ?? 0,
            'assignedToId': telecaller.id,
            'assignedToUid': (telecallerData['uid'] ?? '').toString(),
            'assignedToName': (telecallerData['name'] ?? '').toString(),
            'assignedToEmail': (telecallerData['email'] ?? '').toString(),
            'assignedAt': FieldValue.serverTimestamp(),
            'createdAt': FieldValue.serverTimestamp(),
            'createdBy': currentUser?.uid ?? '',
          });

          writeBatch.update(contactDocument.reference, {
            'status': 'Assigned',
            'batchId': batchReference.id,
            'assignedToId': telecaller.id,
            'assignedToUid': (telecallerData['uid'] ?? '').toString(),
            'assignedToName': (telecallerData['name'] ?? '').toString(),
            'assignedToEmail': (telecallerData['email'] ?? '').toString(),
            'assignedAt': FieldValue.serverTimestamp(),
          });
        }
        await writeBatch.commit();
      }

      await batchReference.update({
        'status': 'Completed',
        'completedAt': FieldValue.serverTimestamp(),
      });

      await AuditLogService.write(
        page: 'Data Transfer',
        action: 'Distributed Telecaller Data',
        description:
            'Sent ${selectedContacts.length} leads to ${selectedTelecallers.length} telecallers in "$_selectedDirectoryName".',
        targetId: batchReference.id,
        targetType: 'Data Transfer Batch',
        targetName: _selectedDirectoryName,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${selectedContacts.length} lead(s) sent to '
            '${selectedTelecallers.length} telecaller(s).',
          ),
          backgroundColor: const Color(0xFF059669),
        ),
      );

      setState(() {
        _pendingBatchId = null;
        _selectedContactIds.clear();
        _quantityController.clear();
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not send data: ${error.toString()}');
      }
    } finally {
      if (mounted) setState(() => _distributing = false);
    }
  }

  // --- AUTO SELECT QUANTITY ---
  void _updateQuantitySelection(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> availableContacts,
  ) {
    final input = _quantityController.text.trim();
    if (input.isEmpty) {
      setState(() => _selectedContactIds.clear());
      return;
    }
    final requested = int.tryParse(input);
    if (requested == null || requested <= 0) return;

    final targetCount = requested.clamp(0, availableContacts.length);
    setState(() {
      _selectedContactIds
        ..clear()
        ..addAll(availableContacts.take(targetCount).map((doc) => doc.id));
    });
  }

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: firestore.collection('data_transfer_directories').snapshots(),
      builder: (context, dirSnapshot) {
        final directories = dirSnapshot.data?.docs.toList() ?? [];
        directories.sort((a, b) {
          final aName = (a.data()['name'] ?? '').toString().toLowerCase();
          final bName = (b.data()['name'] ?? '').toString().toLowerCase();
          return aName.compareTo(bName);
        });

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: firestore
              .collection('agents')
              .where('role', isEqualTo: 'telecaller')
              .snapshots(),
          builder: (context, telecallerSnapshot) {
            final telecallers =
                (telecallerSnapshot.data?.docs ?? [])
                    .where((doc) => _isActive(doc.data()))
                    .toList()
                  ..sort(
                    (a, b) => (a.data()['name'] ?? '').toString().compareTo(
                      (b.data()['name'] ?? '').toString(),
                    ),
                  );

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: firestore
                  .collection('data_transfer_contacts')
                  .snapshots(),
              builder: (context, poolSnapshot) {
                final rawContacts = poolSnapshot.data?.docs.toList() ?? [];

                // Filter contacts by selected Directory
                final directoryContacts = _selectedDirectoryId == 'ALL'
                    ? rawContacts
                    : rawContacts.where((doc) {
                        final dId = doc.data()['directoryId'];
                        return dId == _selectedDirectoryId;
                      }).toList();

                // Sort: UNASSIGNED FIRST (ON TOP), ASSIGNED LAST (ON BOTTOM)
                directoryContacts.sort((a, b) {
                  final aStatus = (a.data()['status'] ?? 'Unassigned')
                      .toString()
                      .toLowerCase();
                  final bStatus = (b.data()['status'] ?? 'Unassigned')
                      .toString()
                      .toLowerCase();

                  final aIsAssigned = aStatus == 'assigned' ? 1 : 0;
                  final bIsAssigned = bStatus == 'assigned' ? 1 : 0;

                  if (aIsAssigned != bIsAssigned) {
                    return aIsAssigned.compareTo(
                      bIsAssigned,
                    ); // 0 (Unassigned) before 1 (Assigned)
                  }

                  final aSourceRow =
                      (a.data()['sourceRow'] as num?)?.toInt() ?? 0;
                  final bSourceRow =
                      (b.data()['sourceRow'] as num?)?.toInt() ?? 0;
                  if (aSourceRow != bSourceRow) {
                    return aSourceRow.compareTo(bSourceRow);
                  }

                  final aTime = a.data()['uploadedAt'];
                  final bTime = b.data()['uploadedAt'];
                  final aMs = aTime is Timestamp
                      ? aTime.millisecondsSinceEpoch
                      : 0;
                  final bMs = bTime is Timestamp
                      ? bTime.millisecondsSinceEpoch
                      : 0;
                  return aMs.compareTo(bMs);
                });

                // Apply in-directory search query and status filter
                final filteredContacts = directoryContacts.where((doc) {
                  final data = doc.data();
                  final status = (data['status'] ?? 'Unassigned').toString();

                  if (_poolFilter == 'Unassigned' &&
                      status.toLowerCase() == 'assigned') {
                    return false;
                  }
                  if (_poolFilter == 'Assigned' &&
                      status.toLowerCase() != 'assigned') {
                    return false;
                  }

                  if (_gridSearchQuery.isNotEmpty) {
                    final query = _gridSearchQuery.toLowerCase();
                    final name = (data['name'] ?? '').toString().toLowerCase();
                    final mobile = (data['mobileNumber'] ?? '')
                        .toString()
                        .toLowerCase();
                    final city = (data['city'] ?? '').toString().toLowerCase();
                    final policy = (data['alreadyPolicy'] ?? '')
                        .toString()
                        .toLowerCase();
                    final sNo = (data['sNo'] ?? '').toString().toLowerCase();
                    final assignedTo = (data['assignedToName'] ?? '')
                        .toString()
                        .toLowerCase();
                    final extra = [
                      data['extraSearchText'],
                      _extraFieldsText(data),
                      ...(((data['importHeaders'] as List?) ?? const []).map(
                        (value) => value.toString(),
                      )),
                    ].join(' ').toLowerCase();

                    return name.contains(query) ||
                        mobile.contains(query) ||
                        city.contains(query) ||
                        policy.contains(query) ||
                        sNo.contains(query) ||
                        assignedTo.contains(query) ||
                        extra.contains(query);
                  }
                  return true;
                }).toList();

                final selectedTelecallers = telecallers
                    .where((doc) => _selectedTelecallerIds.contains(doc.id))
                    .toList();
                final selectedContactCount = directoryContacts
                    .where((doc) => _selectedContactIds.contains(doc.id))
                    .length;
                final counts = _distributionCounts(
                  selectedTelecallers,
                  selectedContactCount,
                );

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    children: [
                      if (_error != null) ...[
                        _errorPanel(_error!),
                        const SizedBox(height: 10),
                      ],
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // -------------------------------------------------------------
                            // 1. LEFT PANEL (BIG PANEL - 75% width / flex: 3): DIRECTORY & EXCEL DATA GRID
                            // -------------------------------------------------------------
                            Expanded(
                              flex: 3,
                              child: _buildBigDirectoryAndDataPanel(
                                directories: directories,
                                rawContacts: rawContacts,
                                filteredContacts: filteredContacts,
                                unassignedContacts: directoryContacts,
                                totalCount: directoryContacts.length,
                                isLoading:
                                    poolSnapshot.connectionState ==
                                    ConnectionState.waiting,
                              ),
                            ),
                            const SizedBox(width: 14),

                            // -------------------------------------------------------------
                            // 2. RIGHT PANEL (SMALL PANEL - 25% width / flex: 1): TELECALLER ACCESS
                            // -------------------------------------------------------------
                            Expanded(
                              flex: 1,
                              child: _buildTelecallerPanel(
                                telecallers: telecallers,
                                selectedCount: selectedContactCount,
                                counts: counts,
                                unassignedContacts: directoryContacts,
                              ),
                            ),
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

  // ===========================================================================
  // WIDGET: LARGE LEFT PANEL — DIRECTORY SELECTION + EXCEL DATA SPREADSHEET GRID
  // ===========================================================================
  Widget _buildBigDirectoryAndDataPanel({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> directories,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> rawContacts,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> filteredContacts,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>>
    unassignedContacts,
    required int totalCount,
    required bool isLoading,
  }) {
    final filteredDirs = directories.where((doc) {
      final name = (doc.data()['name'] ?? '').toString().toLowerCase();
      return name.contains(_directorySearchQuery.toLowerCase());
    }).toList();

    final selectedInDirectory = unassignedContacts
        .where((doc) => _selectedContactIds.contains(doc.id))
        .length;

    final isAllSelected =
        unassignedContacts.isNotEmpty &&
        unassignedContacts.every((doc) => _selectedContactIds.contains(doc.id));

    return Container(
      decoration: BoxDecoration(
        color: DataTransferTab._surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DataTransferTab._border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // -----------------------------------------------------------------
          // 1. LEFT DIRECTORY SIDEBAR PANEL (Width: 230)
          // -----------------------------------------------------------------
          Container(
            width: 230,
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.horizontal(left: Radius.circular(11)),
              border: Border(right: BorderSide(color: DataTransferTab._border)),
            ),
            child: Column(
              children: [
                // Directory Sidebar Header
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: DataTransferTab._border),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.folder_copy_rounded,
                                size: 18,
                                color: DataTransferTab._primary,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Directories',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: DataTransferTab._text,
                                ),
                              ),
                            ],
                          ),
                          ElevatedButton.icon(
                            onPressed: _showCreateDirectoryDialog,
                            icon: const Icon(Icons.add, size: 14),
                            label: const Text(
                              'New',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: DataTransferTab._primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _directorySearchController,
                        onChanged: (val) =>
                            setState(() => _directorySearchQuery = val),
                        style: const TextStyle(fontSize: 12),
                        decoration: InputDecoration(
                          hintText: 'Search directory...',
                          hintStyle: const TextStyle(
                            fontSize: 11,
                            color: DataTransferTab._muted,
                          ),
                          prefixIcon: const Icon(
                            Icons.search,
                            size: 16,
                            color: DataTransferTab._muted,
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 6,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(
                              color: DataTransferTab._border,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Directory Navigation Item List
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    children: [
                      _directoryTileItem(
                        id: 'ALL',
                        name: 'All Directories',
                        count: rawContacts.length,
                        icon: Icons.folder_shared_rounded,
                      ),
                      const Divider(height: 1, indent: 8, endIndent: 8),
                      ...filteredDirs.map((doc) {
                        final dName = (doc.data()['name'] ?? 'Unnamed')
                            .toString();
                        final count = rawContacts
                            .where((c) => c.data()['directoryId'] == doc.id)
                            .length;
                        return _directoryTileItem(
                          id: doc.id,
                          name: dName,
                          count: count,
                          icon: Icons.folder_rounded,
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // -----------------------------------------------------------------
          // 2. MAIN DATA SECTION FOR ACTIVE DIRECTORY (Expanded)
          // -----------------------------------------------------------------
          Expanded(
            child: Column(
              children: [
                // Directory Active Header & Dump Excel Button
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(11),
                    ),
                    border: Border(
                      bottom: BorderSide(color: DataTransferTab._border),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.folder_open_rounded,
                            size: 20,
                            color: DataTransferTab._primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _selectedDirectoryName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: DataTransferTab._text,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: DataTransferTab._primary.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$totalCount leads',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: DataTransferTab._primary,
                              ),
                            ),
                          ),
                        ],
                      ),

                      ElevatedButton.icon(
                        onPressed: _readingFile ? null : _pickExcelFile,
                        icon: _readingFile
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.upload_file_rounded, size: 16),
                        label: Text(
                          _readingFile ? 'Importing...' : 'Dump Excel Data',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0891B2),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Search Bar, Filter Chips (All/Unassigned/Assigned), Auto-Check Quantity
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: DataTransferTab._border),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _gridSearchController,
                          onChanged: (val) =>
                              setState(() => _gridSearchQuery = val),
                          style: const TextStyle(fontSize: 12),
                          decoration: InputDecoration(
                            hintText:
                                'Search inside $_selectedDirectoryName (Name, Phone, City, Policy, Status...)...',
                            hintStyle: const TextStyle(
                              fontSize: 11,
                              color: DataTransferTab._muted,
                            ),
                            prefixIcon: const Icon(
                              Icons.search,
                              size: 16,
                              color: DataTransferTab._muted,
                            ),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 8,
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: DataTransferTab._border,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        height: 34,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: ['All', 'Unassigned', 'Assigned'].map((
                            filter,
                          ) {
                            final isSel = _poolFilter == filter;
                            return GestureDetector(
                              onTap: () => setState(() => _poolFilter = filter),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isSel
                                      ? Colors.white
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: isSel
                                      ? [
                                          const BoxShadow(
                                            color: Colors.black12,
                                            blurRadius: 2,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Text(
                                  filter,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSel
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    color: isSel
                                        ? DataTransferTab._primary
                                        : DataTransferTab._muted,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 180,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: DataTransferTab._border),
                        ),
                        child: TextField(
                          controller: _quantityController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                          onChanged: (_) =>
                              _updateQuantitySelection(filteredContacts),
                          decoration: const InputDecoration(
                            hintText: 'Auto-Check (e.g. 50)',
                            hintStyle: TextStyle(
                              fontSize: 11,
                              color: DataTransferTab._muted,
                            ),
                            prefixIcon: Icon(
                              Icons.playlist_add_check_rounded,
                              size: 16,
                              color: DataTransferTab._primary,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Excel Spreadsheet Grid Header
                Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: const BoxDecoration(color: Color(0xFF0D2D4F)),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 32,
                        child: Checkbox(
                          value: isAllSelected,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedContactIds
                                  ..clear()
                                  ..addAll(filteredContacts.map((c) => c.id));
                              } else {
                                _selectedContactIds.clear();
                                _quantityController.clear();
                              }
                            });
                          },
                          fillColor: WidgetStateProperty.all(Colors.white),
                          checkColor: const Color(0xFF0D2D4F),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      _gridHeaderCell('S.No', flex: 1),
                      _gridHeaderCell('Name', flex: 3),
                      _gridHeaderCell('Phone Number', flex: 2),
                      _gridHeaderCell('City', flex: 2),
                      _gridHeaderCell('Already Policy', flex: 2),
                      _gridHeaderCell('Status', flex: 2),
                      _gridHeaderCell('Assigned To', flex: 2),
                    ],
                  ),
                ),

                // Excel Spreadsheet Grid Rows
                Expanded(
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : filteredContacts.isEmpty
                      ? const Center(
                          child: Text(
                            'No leads found in this directory view.',
                            style: TextStyle(
                              fontSize: 12,
                              color: DataTransferTab._muted,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: filteredContacts.length,
                          itemBuilder: (context, index) {
                            final doc = filteredContacts[index];
                            final data = doc.data();
                            final isAssigned =
                                (data['status'] ?? 'Unassigned')
                                    .toString()
                                    .toLowerCase() ==
                                'assigned';
                            final isChecked = _selectedContactIds.contains(
                              doc.id,
                            );

                            return Container(
                              height: 36,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: isAssigned
                                    ? const Color(0xFFF1F5F9)
                                    : isChecked
                                    ? const Color(
                                        0xFF0891B2,
                                      ).withValues(alpha: 0.06)
                                    : index % 2 == 0
                                    ? Colors.white
                                    : const Color(0xFFFAFAFA),
                                border: const Border(
                                  bottom: BorderSide(
                                    color: Color(0xFFE2E8F0),
                                    width: 0.5,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 32,
                                    child: Checkbox(
                                      value: isChecked,
                                      activeColor: const Color(0xFF0D2D4F),
                                      checkColor: Colors.white,
                                      side: const BorderSide(
                                        color: Color(0xFF64748B),
                                        width: 1.5,
                                      ),
                                      onChanged: (val) {
                                        setState(() {
                                          if (val == true) {
                                            _selectedContactIds.add(doc.id);
                                          } else {
                                            _selectedContactIds.remove(doc.id);
                                          }
                                        });
                                      },
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                  _gridDataCell(
                                    '${index + 1}',
                                    flex: 1,
                                    isBold: true,
                                  ),
                                  _gridDataCell(
                                    (data['name'] ?? 'Unnamed').toString(),
                                    flex: 3,
                                    isBold: true,
                                  ),
                                  _gridDataCell(
                                    (data['mobileNumber'] ?? '').toString(),
                                    flex: 2,
                                  ),
                                  _gridDataCell(
                                    (data['city'] ?? '-').toString(),
                                    flex: 2,
                                  ),
                                  _gridDataCell(
                                    (data['alreadyPolicy'] ?? '-').toString(),
                                    flex: 2,
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isAssigned
                                              ? const Color(0xFFD1FAE5)
                                              : const Color(0xFFFEF3C7),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          isAssigned
                                              ? 'Assigned'
                                              : 'Unassigned',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: isAssigned
                                                ? const Color(0xFF065F46)
                                                : const Color(0xFF92400E),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  _gridDataCell(
                                    isAssigned
                                        ? (data['assignedToName'] ??
                                                  'Telecaller')
                                              .toString()
                                        : '-',
                                    flex: 2,
                                    color: isAssigned
                                        ? const Color(0xFF0D2D4F)
                                        : DataTransferTab._muted,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),

                // Footer Summary Bar
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.only(
                      bottomRight: Radius.circular(11),
                    ),
                    border: Border(
                      top: BorderSide(color: DataTransferTab._border),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$selectedInDirectory lead(s) checked out of $totalCount in $_selectedDirectoryName',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: DataTransferTab._primary,
                        ),
                      ),
                      if (selectedInDirectory > 0)
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _selectedContactIds.clear();
                              _quantityController.clear();
                            });
                          },
                          icon: const Icon(Icons.clear_all, size: 14),
                          label: const Text(
                            'Clear Selection',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _directoryTileItem({
    required String id,
    required String name,
    required int count,
    required IconData icon,
  }) {
    final isSelected = _selectedDirectoryId == id;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? DataTransferTab._primary : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
        onTap: () {
          setState(() {
            _selectedDirectoryId = id;
            _selectedDirectoryName = name;
            _selectedContactIds.clear();
            _quantityController.clear();
          });
        },
        leading: Icon(
          icon,
          size: 18,
          color: isSelected ? Colors.white : DataTransferTab._primary,
        ),
        title: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : DataTransferTab._text,
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.white.withValues(alpha: 0.2)
                : DataTransferTab._border,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: isSelected ? Colors.white : DataTransferTab._muted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _gridHeaderCell(String title, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _gridDataCell(
    String text, {
    required int flex,
    bool isBold = false,
    Color? color,
  }) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
          color: color ?? DataTransferTab._text,
        ),
      ),
    );
  }

  // ===========================================================================
  // WIDGET: RIGHT PANEL — TELECALLER ACCESS & EQUAL DISTRIBUTION
  // ===========================================================================
  Widget _buildTelecallerPanel({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> telecallers,
    required int selectedCount,
    required Map<String, int> counts,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>>
    unassignedContacts,
  }) {
    final filteredTelecallers = telecallers.where((doc) {
      final name = (doc.data()['name'] ?? '').toString().toLowerCase();
      final email = (doc.data()['email'] ?? '').toString().toLowerCase();
      final q = _telecallerSearchQuery.toLowerCase();
      return name.contains(q) || email.contains(q);
    }).toList();

    final isAllTelecallersSelected =
        filteredTelecallers.isNotEmpty &&
        filteredTelecallers.every(
          (doc) => _selectedTelecallerIds.contains(doc.id),
        );

    return Container(
      decoration: BoxDecoration(
        color: DataTransferTab._surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DataTransferTab._border),
      ),
      child: Column(
        children: [
          // Header & Search
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
              border: Border(
                bottom: BorderSide(color: DataTransferTab._border),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.headset_mic_rounded,
                          size: 18,
                          color: DataTransferTab._primary,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Telecallers',
                          style: TextStyle(
                            color: DataTransferTab._text,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${_selectedTelecallerIds.length} selected',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: DataTransferTab._primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _telecallerSearchController,
                  onChanged: (val) =>
                      setState(() => _telecallerSearchQuery = val),
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Search telecaller...',
                    hintStyle: const TextStyle(
                      fontSize: 11,
                      color: DataTransferTab._muted,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      size: 16,
                      color: DataTransferTab._muted,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: DataTransferTab._border,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Select All Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: const Color(0xFFF1F5F9),
            child: Row(
              children: [
                Checkbox(
                  value: isAllTelecallersSelected,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedTelecallerIds
                          ..clear()
                          ..addAll(filteredTelecallers.map((t) => t.id));
                      } else {
                        _selectedTelecallerIds.clear();
                      }
                    });
                  },
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const Text(
                  'Select All Telecallers',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: DataTransferTab._text,
                  ),
                ),
              ],
            ),
          ),

          // Telecaller Checkbox List
          Expanded(
            child: filteredTelecallers.isEmpty
                ? const Center(
                    child: Text(
                      'No telecallers available.',
                      style: TextStyle(
                        fontSize: 11,
                        color: DataTransferTab._muted,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 4,
                    ),
                    itemCount: filteredTelecallers.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final doc = filteredTelecallers[index];
                      final data = doc.data();
                      final isSelected = _selectedTelecallerIds.contains(
                        doc.id,
                      );
                      final allocated = counts[doc.id] ?? 0;

                      return CheckboxListTile(
                        value: isSelected,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedTelecallerIds.add(doc.id);
                            } else {
                              _selectedTelecallerIds.remove(doc.id);
                            }
                          });
                        },
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 0,
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(
                          (data['name'] ?? 'Unnamed').toString(),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: Text(
                          (data['email'] ?? '').toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            color: DataTransferTab._muted,
                          ),
                        ),
                        secondary: isSelected && selectedCount > 0
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF059669),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '$allocated leads',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              )
                            : null,
                      );
                    },
                  ),
          ),

          // Bottom Send Action Button
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(11)),
              border: Border(top: BorderSide(color: DataTransferTab._border)),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed:
                    (_distributing ||
                        selectedCount == 0 ||
                        _selectedTelecallerIds.isEmpty)
                    ? null
                    : () => _distribute(unassignedContacts, telecallers),
                icon: _distributing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 16),
                label: Text(
                  _distributing
                      ? 'Distributing...'
                      : selectedCount == 0
                      ? 'Select Leads First'
                      : _selectedTelecallerIds.isEmpty
                      ? 'Select Telecallers'
                      : 'Send $selectedCount Leads to Team',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D2D4F),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFCBD5E1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorPanel(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F0),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFB42318),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFFB42318),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImportedContact {
  final int sourceRow;
  final String sNo;
  final String name;
  final String mobileNumber;
  final String city;
  final String alreadyPolicy;
  final Map<String, String> extraFields;
  final List<String> importHeaders;

  const _ImportedContact({
    required this.sourceRow,
    required this.sNo,
    required this.name,
    required this.mobileNumber,
    this.city = '',
    this.alreadyPolicy = '',
    this.extraFields = const {},
    this.importHeaders = const [],
  });

  String get extraSearchText =>
      [...extraFields.keys, ...extraFields.values].join(' ').toLowerCase();
}

class _StoredImportResult {
  final List<_ImportedContact> added;
  final int duplicateCount;

  const _StoredImportResult({
    required this.added,
    required this.duplicateCount,
  });
}
