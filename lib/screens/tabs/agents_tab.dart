import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../utils/audit_log_service.dart';
import '../../widgets/list_serial_number.dart';

class AgentsTab extends StatefulWidget {
  const AgentsTab({super.key});

  @override
  State<AgentsTab> createState() => _AgentsTabState();
}

class _AgentsTabState extends State<AgentsTab>
    with SingleTickerProviderStateMixin {
  static const _primary = Color(0xFF0D2D4F);
  static const _accent = Color(0xFF1A6EBD);
  static const _bg = Color(0xFFF4F6F9);
  static const _surface = Colors.white;
  static const _border = Color(0xFFE4E7EC);
  static const _text = Color(0xFF0D1B2A);
  static const _muted = Color(0xFF8A94A6);
  static const _red = Color(0xFFDC2626);

  static const _roles = [
    _Role(
      'Telecallers',
      'Telecaller',
      'telecaller',
      'agents',
      Icons.headset_mic_outlined,
      Color(0xFF0891B2),
    ),
    _Role(
      'Executives',
      'Executive',
      'executive',
      'agents',
      Icons.badge_outlined,
      Color(0xFF059669),
    ),
    _Role(
      'Team Leaders',
      'Team Leader',
      'team_leader',
      'agents',
      Icons.groups_2_outlined,
      Color(0xFFD97706),
    ),
    _Role(
      'Managers',
      'Manager',
      'manager',
      'agents',
      Icons.manage_accounts_outlined,
      Color(0xFF7C3AED),
    ),
    _Role(
      'Admins',
      'Admin',
      'admin',
      'admins',
      Icons.admin_panel_settings_outlined,
      Color(0xFF2563EB),
    ),
    _Role(
      'Super Admins',
      'Super Admin',
      'super_admin',
      'admins',
      Icons.security_outlined,
      Color(0xFFB91C1C),
    ),
  ];

  late final TabController _tabs;
  final _searchController = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _roles.length, vsync: this);
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            _tabsBar(),
            const Divider(height: 1, color: _border),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                physics: const NeverScrollableScrollPhysics(),
                children: _roles.map(_roleList).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      color: _surface,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 680;
          final heading = const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Employees',
                style: TextStyle(
                  color: _text,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'People, roles, and employee login access in one place',
                style: TextStyle(color: _muted, fontSize: 12),
              ),
            ],
          );
          final search = SizedBox(
            width: compact ? double.infinity : 280,
            height: 40,
            child: TextField(
              controller: _searchController,
              onChanged: (value) =>
                  setState(() => _search = value.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search name or email',
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                filled: true,
                fillColor: _bg,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _border),
                ),
              ),
            ),
          );
          final add = ElevatedButton.icon(
            onPressed: () => _personDialog(_roles[_tabs.index]),
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 17),
            label: const Text('Add Person'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                heading,
                const SizedBox(height: 14),
                search,
                const SizedBox(height: 10),
                add,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: heading),
              search,
              const SizedBox(width: 10),
              add,
            ],
          );
        },
      ),
    );
  }

  Widget _tabsBar() {
    return Container(
      color: _surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: TabBar(
        controller: _tabs,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color: _primary,
          borderRadius: BorderRadius.circular(10),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: _muted,
        labelPadding: EdgeInsets.zero,
        tabs: _roles
            .map(
              (role) => Tab(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  child: Row(
                    children: [
                      Icon(role.icon, size: 16),
                      const SizedBox(width: 7),
                      Text(role.label),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _roleList(_Role role) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(role.collection)
          .where('role', isEqualTo: role.value)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _accent));
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Could not load ' + role.label + '.',
              style: const TextStyle(color: _red),
            ),
          );
        }
        final docs =
            (snapshot.data?.docs ?? []).where((doc) {
              if (_search.isEmpty) return true;
              final data = doc.data();
              final haystack =
                  ((data['name'] ?? '').toString() +
                          ' ' +
                          (data['email'] ?? '').toString() +
                          ' ' +
                          (data['teamLeaderName'] ?? '').toString() +
                          ' ' +
                          (data['phone'] ?? '').toString())
                      .toLowerCase();
              return haystack.contains(_search);
            }).toList()..sort(
              (a, b) => (a.data()['name'] ?? '')
                  .toString()
                  .toLowerCase()
                  .compareTo((b.data()['name'] ?? '').toString().toLowerCase()),
            );

        if (docs.isEmpty) return _empty(role);
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: docs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 9),
          itemBuilder: (_, index) => _personRow(role, docs[index], index + 1),
        );
      },
    );
  }

  Widget _empty(_Role role) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: role.color.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(role.icon, color: role.color, size: 27),
          ),
          const SizedBox(height: 14),
          Text(
            'No ' + role.label.toLowerCase() + ' yet',
            style: const TextStyle(
              color: _text,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: () => _personDialog(role),
            icon: const Icon(Icons.add_rounded),
            label: Text('Add ' + role.singular),
          ),
        ],
      ),
    );
  }

  Widget _personRow(
    _Role role,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    int number,
  ) {
    final data = doc.data();
    final name = (data['name'] ?? 'Unnamed').toString();
    final email = (data['email'] ?? '').toString();
    final phone = (data['phone'] ?? '').toString();
    final teamLeaderName = (data['teamLeaderName'] ?? '').toString();
    final active =
        data['is_active'] == true ||
        (data['status'] ?? 'Active').toString().toLowerCase() == 'active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          ListSerialNumber(number: number),
          const SizedBox(width: 10),
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: role.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(
              name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase(),
              style: TextStyle(color: role.color, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _text,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  phone.isEmpty ? email : email + ' · ' + phone,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
                if (role.value == 'executive' && teamLeaderName.isNotEmpty)
                  Text(
                    'Team Leader: $teamLeaderName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _muted, fontSize: 11),
                  ),
              ],
            ),
          ),
          if (MediaQuery.sizeOf(context).width > 720) ...[
            _pill(role.singular, role.color),
            const SizedBox(width: 9),
          ],
          _pill(
            active ? 'Active' : 'Inactive',
            active ? Colors.green.shade700 : _red,
          ),
          PopupMenuButton<String>(
            tooltip: 'Person actions',
            onSelected: (action) {
              if (action == 'edit') {
                _personDialog(role, existing: doc);
              } else {
                _remove(role, doc);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit profile')),
              PopupMenuItem(value: 'delete', child: Text('Remove profile')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
    ),
  );

  Future<void> _personDialog(
    _Role role, {
    QueryDocumentSnapshot<Map<String, dynamic>>? existing,
  }) async {
    final editing = existing != null;
    final old = existing?.data() ?? <String, dynamic>{};
    final teamLeaders = role.value == 'executive'
        ? (await FirebaseFirestore.instance
                  .collection('agents')
                  .where('role', isEqualTo: 'team_leader')
                  .get())
              .docs
              .where((document) {
                final data = document.data();
                return data['is_active'] != false &&
                    (data['status'] ?? 'Active').toString().toLowerCase() !=
                        'inactive';
              })
              .toList()
        : <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    teamLeaders.sort(
      (a, b) => (a.data()['name'] ?? '').toString().compareTo(
        (b.data()['name'] ?? '').toString(),
      ),
    );
    String? selectedTeamLeaderId = (old['teamLeaderId'] ?? '').toString();
    if (!teamLeaders.any((document) => document.id == selectedTeamLeaderId)) {
      selectedTeamLeaderId = null;
    }
    if (!mounted) return;
    final name = TextEditingController(text: old['name']?.toString() ?? '');
    final email = TextEditingController(text: old['email']?.toString() ?? '');
    final password = TextEditingController();
    final phone = TextEditingController(text: old['phone']?.toString() ?? '');
    var active =
        old.isEmpty ||
        old['is_active'] == true ||
        (old['status'] ?? 'Active').toString().toLowerCase() == 'active';
    var saving = false;
    final key = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) {
          Future<void> save() async {
            if (!key.currentState!.validate()) return;
            setLocal(() => saving = true);
            try {
              final normalizedEmail = email.text.trim().toLowerCase();
              final passwordValue = password.text.trim();
              for (final collection in const ['agents', 'admins']) {
                for (final field in const ['email', 'loginEmail']) {
                  final matches = await FirebaseFirestore.instance
                      .collection(collection)
                      .where(field, isEqualTo: normalizedEmail)
                      .get();
                  final duplicate = matches.docs.any(
                    (doc) =>
                        !editing ||
                        collection != role.collection ||
                        doc.id != existing.id,
                  );
                  if (duplicate) {
                    _error('This email is already registered in Employees.');
                    setLocal(() => saving = false);
                    return;
                  }
                }
              }
              final selectedTeamLeader = role.value == 'executive'
                  ? teamLeaders.firstWhere(
                      (document) => document.id == selectedTeamLeaderId,
                    )
                  : null;
              final teamLeaderData = selectedTeamLeader?.data();
              String? authUid = (old['uid'] ?? '').toString().trim();
              if (!editing || passwordValue.isNotEmpty || authUid.isEmpty) {
                if (passwordValue.isEmpty) {
                  _error('Enter a login password for this employee.');
                  setLocal(() => saving = false);
                  return;
                }
                final createdUid = await _createEmployeeAuthUser(
                  email: normalizedEmail,
                  password: passwordValue,
                );
                authUid = createdUid;
              }
              if (editing) {
                final oldEmail = (old['email'] ?? '').toString().toLowerCase();
                final hasLogin = (old['uid'] ?? '').toString().isNotEmpty;
                await existing.reference.update({
                  'name': name.text.trim(),
                  'email': normalizedEmail,
                  'uid': authUid,
                  'hasPasswordLogin': true,
                  if (hasLogin && old['loginEmail'] == null)
                    'loginEmail': oldEmail,
                  'phone': phone.text.trim(),
                  'is_active': active,
                  'status': active ? 'Active' : 'Inactive',
                  if (role.value == 'executive') ...{
                    'teamLeaderId': selectedTeamLeader!.id,
                    'teamLeaderUid': (teamLeaderData?['uid'] ?? '').toString(),
                    'teamLeaderName': (teamLeaderData?['name'] ?? '')
                        .toString(),
                    'teamLeaderEmail': (teamLeaderData?['email'] ?? '')
                        .toString(),
                  },
                  'updatedAt': FieldValue.serverTimestamp(),
                  'updatedBy': FirebaseAuth.instance.currentUser?.uid ?? '',
                });
              } else {
                await FirebaseFirestore.instance
                    .collection(role.collection)
                    .add({
                      'uid': authUid,
                      'name': name.text.trim(),
                      'email': normalizedEmail,
                      'username': email.text.trim().split('@').first,
                      'hasPasswordLogin': true,
                      'phone': phone.text.trim(),
                      'role': role.value,
                      'roleLabel': role.singular,
                      'is_active': true,
                      'status': 'Active',
                      if (role.value == 'executive') ...{
                        'teamLeaderId': selectedTeamLeader!.id,
                        'teamLeaderUid': (teamLeaderData?['uid'] ?? '')
                            .toString(),
                        'teamLeaderName': (teamLeaderData?['name'] ?? '')
                            .toString(),
                        'teamLeaderEmail': (teamLeaderData?['email'] ?? '')
                            .toString(),
                      },
                      'last_login': null,
                      'createdAt': FieldValue.serverTimestamp(),
                      'createdBy': FirebaseAuth.instance.currentUser?.uid ?? '',
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
              }
              await AuditLogService.write(
                page: 'Employees',
                action: editing ? 'Updated Person' : 'Added Person',
                description:
                    (editing ? 'Updated ' : 'Added ') +
                    role.singular.toLowerCase() +
                    ' ' +
                    name.text.trim() +
                    '.',
                targetId: existing?.id ?? email.text.trim(),
                targetType: role.singular,
                targetName: name.text.trim(),
              );
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
            } catch (error) {
              if (dialogContext.mounted) {
                setLocal(() => saving = false);
                _error('Could not save person: ' + error.toString());
              }
            }
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              (editing ? 'Edit ' : 'Add ') + role.singular,
              style: const TextStyle(
                color: _text,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            content: SizedBox(
              width: 480,
              child: Form(
                key: key,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _input(
                        name,
                        'Full name',
                        Icons.person_outline_rounded,
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Enter the person\'s name.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      _input(
                        email,
                        'Email address',
                        Icons.alternate_email_rounded,
                        keyboard: TextInputType.emailAddress,
                        validator: _emailValidator,
                      ),
                      const SizedBox(height: 12),
                      _input(
                        password,
                        editing
                            ? 'New password (leave blank to keep existing)'
                            : 'Login password',
                        Icons.lock_outline_rounded,
                        validator: (value) =>
                            _passwordValidator(value, required: !editing),
                        obscure: true,
                      ),
                      if (role.value == 'executive') ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: selectedTeamLeaderId,
                          decoration: _decoration(
                            'Team Leader',
                            Icons.groups_2_outlined,
                          ),
                          items: teamLeaders
                              .map(
                                (document) => DropdownMenuItem(
                                  value: document.id,
                                  child: Text(
                                    (document.data()['name'] ?? '').toString(),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setLocal(() => selectedTeamLeaderId = value),
                          validator: (value) => value == null
                              ? 'Select the Executive\'s Team Leader.'
                              : null,
                        ),
                      ],
                      const SizedBox(height: 12),
                      _input(
                        phone,
                        'Phone number (optional)',
                        Icons.phone_outlined,
                        keyboard: TextInputType.phone,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        editing
                            ? 'Leave password blank to keep the existing login. Enter a new password only for profiles without login access.'
                            : 'This email and password will be used on the login screen.',
                        style: TextStyle(color: _muted, fontSize: 11),
                      ),
                      if (editing) ...[
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Active login profile'),
                          value: active,
                          onChanged: (value) => setLocal(() => active = value),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: saving ? null : save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                ),
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(editing ? 'Save Changes' : 'Create Login'),
              ),
            ],
          );
        },
      ),
    );
    name.dispose();
    email.dispose();
    password.dispose();
    phone.dispose();
  }

  Future<String> _createEmployeeAuthUser({
    required String email,
    required String password,
  }) async {
    final apiKey = Firebase.app().options.apiKey;
    final response = await http.post(
      Uri.parse(
        'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$apiKey',
      ),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'returnSecureToken': false,
      }),
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return (body['localId'] ?? '').toString();
    }
    final error = (body['error'] as Map?)?['message']?.toString() ?? '';
    if (error == 'EMAIL_EXISTS') {
      throw Exception(
        'This email already has a Firebase login. Leave password blank while editing, or use another email.',
      );
    }
    if (error == 'WEAK_PASSWORD : Password should be at least 6 characters') {
      throw Exception('Password should be at least 6 characters.');
    }
    throw Exception(error.isEmpty ? 'Could not create employee login.' : error);
  }

  Widget _input(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool enabled = true,
    TextInputType? keyboard,
    String? Function(String?)? validator,
    bool obscure = false,
  }) => TextFormField(
    controller: controller,
    enabled: enabled,
    keyboardType: keyboard,
    obscureText: obscure,
    validator: validator,
    decoration: _decoration(label, icon),
  );

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, size: 19),
    filled: true,
    fillColor: _bg,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: _border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: _border),
    ),
  );

  String? _emailValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'Enter an email address.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  String? _passwordValidator(String? value, {required bool required}) {
    final password = value?.trim() ?? '';
    if (!required && password.isEmpty) return null;
    if (password.isEmpty) return 'Enter a login password.';
    if (password.length < 6) return 'Password must be at least 6 characters.';
    return null;
  }

  Future<void> _remove(
    _Role role,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final name = (doc.data()['name'] ?? 'this person').toString();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove profile?'),
        content: Text(
          'Remove ' +
              name +
              ' from ' +
              role.label +
              '? Their login will no longer be authorized by this app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await doc.reference.delete();
    await AuditLogService.write(
      page: 'Employees',
      action: 'Removed Person',
      description: 'Removed ' + role.singular.toLowerCase() + ' ' + name + '.',
      targetId: doc.id,
      targetType: role.singular,
      targetName: name,
    );
  }

  void _error(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: _red));
  }
}

class _Role {
  final String label;
  final String singular;
  final String value;
  final String collection;
  final IconData icon;
  final Color color;

  const _Role(
    this.label,
    this.singular,
    this.value,
    this.collection,
    this.icon,
    this.color,
  );
}
