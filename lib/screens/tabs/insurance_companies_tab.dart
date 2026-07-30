import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../widgets/company_logo.dart';
import '../../widgets/list_serial_number.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LOG SERVICE  — shared utility used by all tabs
// ─────────────────────────────────────────────────────────────────────────────
class LogService {
  static Future<void> write({
    required String page,
    required String action,
    required String description,
    String? targetId,
    String? targetType,
    String? targetName,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('logs').add({
        'page': page,
        'action': action, // e.g. 'Added', 'Updated', 'Deleted'
        'description': description,
        'performedBy': user?.email ?? user?.uid ?? 'Unknown',
        'performedByUid': user?.uid ?? '',
        'targetId': targetId ?? '',
        'targetType': targetType ?? '',
        'targetName': targetName ?? '',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Logging must never crash the app
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INSURANCE COMPANIES TAB
// ─────────────────────────────────────────────────────────────────────────────
class InsuranceCompaniesTab extends StatefulWidget {
  const InsuranceCompaniesTab({super.key});

  @override
  State<InsuranceCompaniesTab> createState() => _InsuranceCompaniesTabState();
}

class _InsuranceCompaniesTabState extends State<InsuranceCompaniesTab> {
  static const _primary = Color(0xFF0D2D4F);
  static const _accent = Color(0xFF1A6EBD);
  static const _bg = Color(0xFFF4F6F9);
  static const _surface = Color(0xFFFFFFFF);
  static const _border = Color(0xFFE4E7EC);
  static const _textMain = Color(0xFF0D1B2A);
  static const _textMuted = Color(0xFF8A94A6);
  static const _red = Color(0xFFDC2626);

  String _search = '';
  final _searchCtrl = TextEditingController();

  QueryDocumentSnapshot<Map<String, dynamic>>? _selectedDoc;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> get _stream => FirebaseFirestore
      .instance
      .collection('insurance_companies')
      .orderBy('createdAt', descending: true)
      .snapshots();

  String _clean(TextEditingController controller) => controller.text.trim();

  bool _validEmail(String value) =>
      value.isEmpty || RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);

  bool _validPhone(String value) =>
      value.isEmpty || RegExp(r'^[0-9+\-\s]{7,15}$').hasMatch(value);

  bool _validUrl(String value) {
    if (value.isEmpty) return true;
    final uri = Uri.tryParse(
      value.startsWith('http') ? value : 'https://$value',
    );
    return uri != null && uri.host.contains('.');
  }

  double? _optionalPercent(String value) {
    if (value.trim().isEmpty) return null;
    final parsed = double.tryParse(value.trim());
    if (parsed == null || parsed < 0 || parsed > 100) return null;
    return parsed;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: _red));
  }

  // ── BUILD ──────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_selectedDoc != null) {
      return _CompanyDetailView(
        doc: _selectedDoc!,
        onBack: () => setState(() => _selectedDoc = null),
        onEdit: () => _showCompanyDialog(
          context,
          docId: _selectedDoc!.id,
          existing: _selectedDoc!.data(),
        ),
        onDeleted: () => setState(() => _selectedDoc = null),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          _buildHeader(context),
          const Divider(height: 1, color: _border),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _stream,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: _accent),
                  );
                }
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }
                var docs = snap.data?.docs ?? [];
                if (_search.isNotEmpty) {
                  docs = docs.where((d) {
                    final data = d.data();
                    return (data['companyName'] ?? '')
                            .toString()
                            .toLowerCase()
                            .contains(_search) ||
                        (data['serialNumber'] ??
                                data['serialNo'] ??
                                data['srNo'] ??
                                '')
                            .toString()
                            .toLowerCase()
                            .contains(_search) ||
                        (data['registrationNumber'] ?? '')
                            .toString()
                            .toLowerCase()
                            .contains(_search);
                  }).toList();
                }
                if (docs.isEmpty) return _buildEmpty(context);
                return ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: docs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _CompanyRow(
                    doc: docs[i],
                    serialNumber: i + 1,
                    onTap: () => setState(() => _selectedDoc = docs[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: _surface,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 14),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Insurance Companies',
                      style: TextStyle(
                        color: _textMain,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Tap a company to view full details',
                      style: TextStyle(color: _textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showCompanyDialog(context),
                icon: const Icon(Icons.add_rounded, size: 15),
                label: const Text(
                  'Add Company',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 11,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _search = v.toLowerCase().trim()),
            decoration: InputDecoration(
              hintText: 'Search companies...',
              hintStyle: const TextStyle(color: _textMuted, fontSize: 13),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: _textMuted,
                size: 17,
              ),
              filled: true,
              fillColor: _bg,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
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
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.business_outlined,
              color: _primary,
              size: 26,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'No companies yet',
            style: TextStyle(
              color: _textMain,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Add your first insurance company to get started.',
            style: TextStyle(color: _textMuted, fontSize: 13),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: () => _showCompanyDialog(context),
            icon: const Icon(Icons.add_rounded, size: 15),
            label: const Text('Add Company'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Add / Edit Company Dialog ──────────────────────────
  Future<void> _showCompanyDialog(
    BuildContext context, {
    String? docId,
    Map<String, dynamic>? existing,
  }) async {
    final isEdit = docId != null;

    final companyName = TextEditingController(
      text: existing?['companyName'] ?? '',
    );
    final registrationNo = TextEditingController(
      text: existing?['registrationNumber'] ?? '',
    );
    final serialNo = TextEditingController(
      text:
          existing?['serialNumber'] ??
          existing?['serialNo'] ??
          existing?['srNo'] ??
          '',
    );
    final irdaiCode = TextEditingController(
      text: existing?['irdaiLicenseCode'] ?? '',
    );
    final website = TextEditingController(text: existing?['website'] ?? '');
    final headOffice = TextEditingController(
      text: existing?['headOfficeAddress'] ?? '',
    );
    final claimsRatio = TextEditingController(
      text: existing?['claimsSettlementRatio']?.toString() ?? '',
    );
    final solvencyRatio = TextEditingController(
      text: existing?['solvencyRatio']?.toString() ?? '',
    );
    final email = TextEditingController(text: existing?['email'] ?? '');
    final phone = TextEditingController(text: existing?['phone'] ?? '');

    // ── 'All' added as first option ──
    final types = ['All', 'Health', 'Life', 'General', 'Motor', 'Travel'];
    final statuses = ['Active', 'Inactive'];

    // Guard: if existing type isn't in the list (shouldn't happen), default to 'Health'
    final existingType = existing?['companyType'] ?? 'Health';
    String selectedType = types.contains(existingType)
        ? existingType
        : 'Health';
    String selectedStatus = existing?['status'] ?? 'Active';
    bool isSaving = false;
    Uint8List? selectedLogoBytes;
    String? selectedLogoName;
    String currentLogoUrl = (existing?['logoUrl'] ?? '').toString();
    String currentLogoStoragePath = (existing?['logoStoragePath'] ?? '')
        .toString();
    bool removeLogo = false;

    List<Map<String, TextEditingController>> contacts = [];
    final existingContacts = (existing?['contacts'] as List<dynamic>? ?? []);
    for (final c in existingContacts) {
      contacts.add({
        'name': TextEditingController(text: c['name'] ?? ''),
        'designation': TextEditingController(text: c['designation'] ?? ''),
        'phone': TextEditingController(text: c['phone'] ?? ''),
        'email': TextEditingController(text: c['email'] ?? ''),
      });
    }
    if (contacts.isEmpty) contacts.add(_emptyContact());

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          Future<void> pickLogo() async {
            final result = await FilePicker.platform.pickFiles(
              type: FileType.image,
              allowMultiple: false,
              withData: true,
            );
            final file = result?.files.single;
            if (file == null) return;
            final bytes = file.bytes;
            if (bytes == null || bytes.isEmpty) {
              _showError('Unable to read the selected logo image.');
              return;
            }
            if (bytes.length > 2 * 1024 * 1024) {
              _showError('Logo image must be 2 MB or smaller.');
              return;
            }
            setS(() {
              selectedLogoBytes = bytes;
              selectedLogoName = file.name;
              removeLogo = false;
            });
          }

          String logoExtension(String? fileName) {
            final raw = (fileName ?? '').toLowerCase().trim();
            final ext = raw.contains('.') ? raw.split('.').last : 'png';
            const allowed = {'png', 'jpg', 'jpeg', 'webp'};
            return allowed.contains(ext) ? ext : 'png';
          }

          String logoContentType(String ext) {
            if (ext == 'jpg' || ext == 'jpeg') return 'image/jpeg';
            if (ext == 'webp') return 'image/webp';
            return 'image/png';
          }

          Future<Map<String, dynamic>> uploadLogo(String targetDocId) async {
            final bytes = selectedLogoBytes;
            if (bytes == null) return const {};
            final ext = logoExtension(selectedLogoName);
            final storagePath =
                'company_logos/$targetDocId/logo_${DateTime.now().millisecondsSinceEpoch}.$ext';
            final ref = FirebaseStorage.instance.ref(storagePath);
            final uploadTask = await ref.putData(
              bytes,
              SettableMetadata(
                contentType: logoContentType(ext),
                cacheControl: 'public,max-age=3600',
                customMetadata: {
                  'companyId': targetDocId,
                  'type': 'company_logo',
                  'uploadedBy':
                      FirebaseAuth.instance.currentUser?.email ??
                      FirebaseAuth.instance.currentUser?.uid ??
                      '',
                },
              ),
            );
            if (uploadTask.state != TaskState.success) {
              throw FirebaseException(
                plugin: 'firebase_storage',
                code: 'upload-failed',
                message: 'The company logo upload did not complete.',
              );
            }
            return {
              'logoUrl': await ref.getDownloadURL(),
              'logoStoragePath': storagePath,
              'logoFileName': selectedLogoName ?? 'Company logo',
            };
          }

          Future<void> deleteLogoAtPath(String storagePath) async {
            if (storagePath.isEmpty) return;
            try {
              await FirebaseStorage.instance.ref(storagePath).delete();
            } catch (_) {
              // A missing old/orphaned object must not undo a successful save.
            }
          }

          Future<void> save() async {
            final nameValue = _clean(companyName);
            final registrationValue = _clean(registrationNo).toUpperCase();
            final serialValue = _clean(serialNo).toUpperCase();
            final emailValue = _clean(email).toLowerCase();
            final phoneValue = _clean(phone);
            final websiteValue = _clean(website);
            final claimsValue = _optionalPercent(claimsRatio.text);
            final solvencyValue = double.tryParse(solvencyRatio.text.trim());

            if (nameValue.isEmpty || registrationValue.isEmpty) {
              _showError('Company name and registration number are required.');
              return;
            }
            if (!_validEmail(emailValue)) {
              _showError('Enter a valid company email address.');
              return;
            }
            if (!_validPhone(phoneValue)) {
              _showError('Enter a valid company phone number.');
              return;
            }
            if (!_validUrl(websiteValue)) {
              _showError(
                'Enter a valid website, for example https://company.com.',
              );
              return;
            }
            if (claimsRatio.text.trim().isNotEmpty && claimsValue == null) {
              _showError('Claims settlement ratio must be between 0 and 100.');
              return;
            }
            if (solvencyRatio.text.trim().isNotEmpty &&
                (solvencyValue == null || solvencyValue <= 0)) {
              _showError('Solvency ratio must be a positive number.');
              return;
            }
            setS(() => isSaving = true);
            String uploadedLogoStoragePath = '';
            var companyRecordSaved = false;
            try {
              for (final c in contacts) {
                final contactName = c['name']!.text.trim();
                final contactPhone = c['phone']!.text.trim();
                final contactEmail = c['email']!.text.trim().toLowerCase();
                if (contactName.isEmpty &&
                    (contactPhone.isNotEmpty || contactEmail.isNotEmpty)) {
                  setS(() => isSaving = false);
                  _showError(
                    'Contact person name is required when phone or email is entered.',
                  );
                  return;
                }
                if (!_validPhone(contactPhone)) {
                  setS(() => isSaving = false);
                  _showError(
                    'Enter a valid contact phone number for $contactName.',
                  );
                  return;
                }
                if (!_validEmail(contactEmail)) {
                  setS(() => isSaving = false);
                  _showError(
                    'Enter a valid contact email address for $contactName.',
                  );
                  return;
                }
              }

              final duplicate = await FirebaseFirestore.instance
                  .collection('insurance_companies')
                  .where('registrationNumber', isEqualTo: registrationValue)
                  .limit(1)
                  .get();
              if (duplicate.docs.isNotEmpty &&
                  duplicate.docs.first.id != docId) {
                setS(() => isSaving = false);
                _showError(
                  'A company with this registration number already exists.',
                );
                return;
              }

              final contactsData = contacts
                  .where((c) => c['name']!.text.trim().isNotEmpty)
                  .map(
                    (c) => {
                      'name': c['name']!.text.trim(),
                      'designation': c['designation']!.text.trim(),
                      'phone': c['phone']!.text.trim(),
                      'email': c['email']!.text.trim(),
                    },
                  )
                  .toList();

              final data = <String, dynamic>{
                'companyName': nameValue,
                'serialNumber': serialValue,
                'serialNo': serialValue,
                'registrationNumber': registrationValue,
                'irdaiLicenseCode': _clean(irdaiCode).toUpperCase(),
                'companyType': selectedType,
                'status': selectedStatus,
                'email': emailValue,
                'phone': phoneValue,
                'website': websiteValue,
                'headOfficeAddress': _clean(headOffice),
                'claimsSettlementRatio': claimsValue ?? 0,
                'solvencyRatio': solvencyValue ?? 0,
                'contacts': contactsData,
                'searchKey':
                    '$nameValue $serialValue $registrationValue $selectedType'
                        .toLowerCase(),
                'updatedAt': FieldValue.serverTimestamp(),
              };

              if (isEdit) {
                if (selectedLogoBytes != null) {
                  final logoData = await uploadLogo(docId);
                  uploadedLogoStoragePath = (logoData['logoStoragePath'] ?? '')
                      .toString();
                  data.addAll(logoData);
                } else if (removeLogo) {
                  data.addAll({
                    'logoUrl': FieldValue.delete(),
                    'logoStoragePath': FieldValue.delete(),
                    'logoFileName': FieldValue.delete(),
                  });
                }

                await FirebaseFirestore.instance
                    .collection('insurance_companies')
                    .doc(docId)
                    .update(data);
                companyRecordSaved = true;

                if ((selectedLogoBytes != null || removeLogo) &&
                    currentLogoStoragePath != uploadedLogoStoragePath) {
                  await deleteLogoAtPath(currentLogoStoragePath);
                }

                // ── LOG: Edit ──
                await LogService.write(
                  page: 'Insurance Companies',
                  action: 'Updated Company',
                  description:
                      'Updated company "$nameValue" '
                      '(Type: $selectedType, Status: $selectedStatus)',
                  targetId: docId,
                  targetType: 'Company',
                  targetName: nameValue,
                );
              } else {
                data['createdAt'] = FieldValue.serverTimestamp();
                final ref = FirebaseFirestore.instance
                    .collection('insurance_companies')
                    .doc();
                if (selectedLogoBytes != null) {
                  final logoData = await uploadLogo(ref.id);
                  uploadedLogoStoragePath = (logoData['logoStoragePath'] ?? '')
                      .toString();
                  data.addAll(logoData);
                }
                await ref.set(data);
                companyRecordSaved = true;

                // ── LOG: Add ──
                await LogService.write(
                  page: 'Insurance Companies',
                  action: 'Added Company',
                  description:
                      'Added new company "$nameValue" '
                      '(Type: $selectedType, Status: $selectedStatus)',
                  targetId: ref.id,
                  targetType: 'Company',
                  targetName: nameValue,
                );
              }
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(isEdit ? 'Company updated' : 'Company added'),
                  backgroundColor: _primary,
                ),
              );
            } on FirebaseException catch (e) {
              if (!companyRecordSaved && uploadedLogoStoragePath.isNotEmpty) {
                await deleteLogoAtPath(uploadedLogoStoragePath);
              }
              if (ctx.mounted) setS(() => isSaving = false);
              if (!context.mounted) return;
              final message =
                  e.plugin == 'firebase_storage' &&
                      (e.code == 'unauthorized' ||
                          e.code == 'permission-denied')
                  ? 'Firebase Storage denied the logo upload. Sign in again or update the Storage rules for company_logos/.'
                  : 'Firebase ${e.plugin} error (${e.code}): ${e.message ?? 'Unable to save the company logo.'}';
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(message), backgroundColor: Colors.red),
              );
            } catch (e) {
              if (!companyRecordSaved && uploadedLogoStoragePath.isNotEmpty) {
                await deleteLogoAtPath(uploadedLogoStoragePath);
              }
              if (ctx.mounted) setS(() => isSaving = false);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }

          return AlertDialog(
            backgroundColor: _surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
            contentPadding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
            title: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.business_outlined,
                    color: _primary,
                    size: 17,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  isEdit ? 'Edit Company' : 'Add Insurance Company',
                  style: const TextStyle(
                    color: _textMain,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 600,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),

                    // ── Basic Info ──────────────────────
                    _sectionLabel('Basic Information'),
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _bg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _border),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: 56,
                              height: 56,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _border),
                              ),
                              child: selectedLogoBytes != null
                                  ? Padding(
                                      padding: const EdgeInsets.all(6),
                                      child: Image.memory(
                                        selectedLogoBytes!,
                                        width: 44,
                                        height: 44,
                                        fit: BoxFit.contain,
                                        filterQuality: FilterQuality.medium,
                                      ),
                                    )
                                  : removeLogo
                                  ? const Icon(
                                      Icons.business_outlined,
                                      color: _textMuted,
                                      size: 24,
                                    )
                                  : CompanyLogo(
                                      companyName: companyName.text,
                                      website: website.text,
                                      customLogoUrl: currentLogoUrl,
                                      size: 52,
                                      radius: 12,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Company Logo',
                                  style: TextStyle(
                                    color: _textMain,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  selectedLogoName ??
                                      (currentLogoUrl.isNotEmpty && !removeLogo
                                          ? 'Uploaded logo'
                                          : 'No logo selected'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton.icon(
                            onPressed: isSaving ? null : pickLogo,
                            icon: const Icon(
                              Icons.upload_file_rounded,
                              size: 15,
                            ),
                            label: Text(
                              currentLogoUrl.isNotEmpty ||
                                      selectedLogoBytes != null
                                  ? 'Replace'
                                  : 'Upload',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          if (selectedLogoBytes != null ||
                              (currentLogoUrl.isNotEmpty && !removeLogo))
                            TextButton.icon(
                              onPressed: isSaving
                                  ? null
                                  : () => setS(() {
                                      selectedLogoBytes = null;
                                      selectedLogoName = null;
                                      removeLogo = currentLogoUrl.isNotEmpty;
                                    }),
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                size: 15,
                                color: _red,
                              ),
                              label: const Text(
                                'Remove',
                                style: TextStyle(color: _red, fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                    ),
                    _row2(
                      _tf('Company Name *', companyName),
                      _tf('Serial Number', serialNo),
                    ),
                    _row2(
                      _tf('Registration Number *', registrationNo),
                      _tf('IRDAI License Code', irdaiCode),
                    ),
                    _row2(
                      _drop(
                        'Company Type',
                        types,
                        selectedType,
                        (v) => setS(() => selectedType = v!),
                      ),
                      _drop(
                        'Status',
                        statuses,
                        selectedStatus,
                        (v) => setS(() => selectedStatus = v!),
                      ),
                    ),
                    _row2(_tf('Website', website), const SizedBox.shrink()),
                    _tf('Head Office Address', headOffice, maxLines: 2),
                    const SizedBox(height: 16),

                    // ── General Contact ─────────────────
                    _sectionLabel('General Contact'),
                    _row2(
                      _tf(
                        'Company Email',
                        email,
                        type: TextInputType.emailAddress,
                      ),
                      _tf('Company Phone', phone, type: TextInputType.phone),
                    ),
                    const SizedBox(height: 16),

                    // ── Financial Metrics ───────────────
                    _sectionLabel('Financial Metrics'),
                    _row2(
                      _tf(
                        'Claims Settlement Ratio (%)',
                        claimsRatio,
                        type: TextInputType.number,
                      ),
                      _tf(
                        'Solvency Ratio',
                        solvencyRatio,
                        type: TextInputType.number,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Contact Persons ─────────────────
                    _sectionLabel('Contact Persons'),
                    ...List.generate(contacts.length, (i) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _bg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _border),
                        ),
                        child: Column(
                          children: [
                            _row2(
                              _tf('Name', contacts[i]['name']!),
                              _tf('Designation', contacts[i]['designation']!),
                            ),
                            _row2(
                              _tf(
                                'Phone',
                                contacts[i]['phone']!,
                                type: TextInputType.phone,
                              ),
                              _tf(
                                'Email',
                                contacts[i]['email']!,
                                type: TextInputType.emailAddress,
                              ),
                            ),
                            if (contacts.length > 1)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () =>
                                      setS(() => contacts.removeAt(i)),
                                  icon: const Icon(
                                    Icons.remove_circle_outline,
                                    size: 14,
                                    color: _red,
                                  ),
                                  label: const Text(
                                    'Remove',
                                    style: TextStyle(color: _red, fontSize: 12),
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                    TextButton.icon(
                      onPressed: () =>
                          setS(() => contacts.add(_emptyContact())),
                      icon: const Icon(
                        Icons.add_circle_outline,
                        size: 15,
                        color: _accent,
                      ),
                      label: const Text(
                        'Add Another Person',
                        style: TextStyle(
                          color: _accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: _textMuted),
                ),
              ),
              ElevatedButton.icon(
                onPressed: isSaving ? null : save,
                icon: isSaving
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
                  isSaving
                      ? 'Saving...'
                      : isEdit
                      ? 'Update'
                      : 'Save Company',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Map<String, TextEditingController> _emptyContact() => {
    'name': TextEditingController(),
    'designation': TextEditingController(),
    'phone': TextEditingController(),
    'email': TextEditingController(),
  };

  // ── Helpers ────────────────────────────────────────────
  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        color: _primary,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.4,
      ),
    ),
  );

  Widget _row2(Widget a, Widget b) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Expanded(child: a),
        const SizedBox(width: 10),
        Expanded(child: b),
      ],
    ),
  );

  Widget _tf(
    String label,
    TextEditingController ctrl, {
    TextInputType type = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 13, color: _textMain),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _textMuted, fontSize: 12),
        filled: true,
        fillColor: _surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 11,
        ),
      ),
    );
  }

  Widget _drop(
    String label,
    List<String> items,
    String value,
    ValueChanged<String?> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      onChanged: onChanged,
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      style: const TextStyle(fontSize: 13, color: _textMain),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _textMuted, fontSize: 12),
        filled: true,
        fillColor: _surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 11,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPANY ROW  — slim list tile
// ─────────────────────────────────────────────────────────────────────────────
class _CompanyRow extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final int serialNumber;
  final VoidCallback onTap;

  static const _surface = Color(0xFFFFFFFF);
  static const _border = Color(0xFFE4E7EC);
  static const _textMain = Color(0xFF0D1B2A);
  static const _textMuted = Color(0xFF8A94A6);
  static const _red = Color(0xFFDC2626);

  const _CompanyRow({
    required this.doc,
    required this.serialNumber,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final name = data['companyName'] ?? '';
    final website = data['website'] ?? '';
    final logoUrl = data['logoUrl'] ?? '';
    final serialNo =
        data['serialNumber'] ?? data['serialNo'] ?? data['srNo'] ?? '';
    final type = data['companyType'] ?? '';
    final status = data['status'] ?? 'Active';
    final isActive = status == 'Active';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            ListSerialNumber(number: serialNumber),
            const SizedBox(width: 10),
            CompanyLogo(
              companyName: name.toString(),
              website: website.toString(),
              customLogoUrl: logoUrl.toString(),
              size: 36,
              radius: 10,
            ),
            const SizedBox(width: 14),
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
                  const SizedBox(height: 2),
                  Text(
                    serialNo.toString().isEmpty
                        ? type
                        : '$type • S/N ${serialNo.toString()}',
                    style: const TextStyle(color: _textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: isActive
                    ? Colors.green.withValues(alpha: 0.08)
                    : _red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: isActive ? Colors.green.shade700 : _red,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: Color(0xFF8A94A6),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPANY DETAIL VIEW  — full page shown on tap
// ─────────────────────────────────────────────────────────────────────────────
class _CompanyDetailView extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final VoidCallback onBack;
  final VoidCallback onEdit;
  final VoidCallback onDeleted;

  static const _primary = Color(0xFF0D2D4F);
  static const _accent = Color(0xFF1A6EBD);
  static const _bg = Color(0xFFF4F6F9);
  static const _surface = Color(0xFFFFFFFF);
  static const _border = Color(0xFFE4E7EC);
  static const _textMain = Color(0xFF0D1B2A);
  static const _textMuted = Color(0xFF8A94A6);
  static const _red = Color(0xFFDC2626);

  const _CompanyDetailView({
    required this.doc,
    required this.onBack,
    required this.onEdit,
    required this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('insurance_companies')
          .doc(doc.id)
          .snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() ?? doc.data();
        return _buildContent(context, data);
      },
    );
  }

  Widget _buildContent(BuildContext context, Map<String, dynamic> data) {
    final name = data['companyName'] ?? '';
    final type = data['companyType'] ?? '';
    final status = data['status'] ?? 'Active';
    final serialNo =
        data['serialNumber'] ?? data['serialNo'] ?? data['srNo'] ?? '';
    final regNo = data['registrationNumber'] ?? '';
    final irdai = data['irdaiLicenseCode'] ?? '';
    final website = data['website'] ?? '';
    final logoUrl = data['logoUrl'] ?? '';
    final address = data['headOfficeAddress'] ?? '';
    final email = data['email'] ?? '';
    final phone = data['phone'] ?? '';
    final claims = data['claimsSettlementRatio'];
    final solvency = data['solvencyRatio'];
    final contacts = List<Map<String, dynamic>>.from(
      (data['contacts'] as List<dynamic>? ?? []).map(
        (e) => Map<String, dynamic>.from(e as Map),
      ),
    );
    final isActive = status == 'Active';

    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          // ── Top bar ──────────────────────────────────
          Container(
            color: _surface,
            padding: EdgeInsets.fromLTRB(
              16,
              MediaQuery.of(context).padding.top + 10,
              16,
              12,
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: onBack,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: _primary.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(
                      Icons.arrow_back_rounded,
                      color: _primary,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      color: _textMain,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _headerBtn(Icons.edit_outlined, _accent, 'Edit', onEdit),
                const SizedBox(width: 8),
                _headerBtn(
                  Icons.delete_outline_rounded,
                  _red,
                  'Delete',
                  () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete Company'),
                        content: Text('Remove "$name"? This cannot be undone.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _red,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await FirebaseFirestore.instance
                          .collection('insurance_companies')
                          .doc(doc.id)
                          .delete();

                      // ── LOG: Delete ──
                      await LogService.write(
                        page: 'Insurance Companies',
                        action: 'Deleted Company',
                        description: 'Deleted company "$name" (Type: $type)',
                        targetId: doc.id,
                        targetType: 'Company',
                        targetName: name,
                      );

                      onDeleted();
                    }
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _border),

          // ── Body ─────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hero card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _border),
                    ),
                    child: Row(
                      children: [
                        CompanyLogo(
                          companyName: name.toString(),
                          website: website.toString(),
                          customLogoUrl: logoUrl.toString(),
                          size: 52,
                          radius: 14,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  color: _textMain,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                type,
                                style: const TextStyle(
                                  color: _textMuted,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: isActive
                                ? Colors.green.withValues(alpha: 0.1)
                                : _red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              color: isActive ? Colors.green.shade700 : _red,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  _sectionCard('Identification', [
                    if (serialNo.toString().isNotEmpty)
                      _detailRow(
                        Icons.confirmation_number_outlined,
                        'Serial No.',
                        serialNo.toString(),
                      ),
                    if (regNo.isNotEmpty)
                      _detailRow(
                        Icons.numbers_rounded,
                        'Registration No.',
                        regNo,
                      ),
                    if (irdai.isNotEmpty)
                      _detailRow(
                        Icons.verified_outlined,
                        'IRDAI License Code',
                        irdai,
                      ),
                    if (type.isNotEmpty)
                      _detailRow(Icons.category_outlined, 'Company Type', type),
                  ]),

                  if (email.isNotEmpty ||
                      phone.isNotEmpty ||
                      website.isNotEmpty ||
                      address.isNotEmpty)
                    _sectionCard('Contact Information', [
                      if (email.isNotEmpty)
                        _detailRow(Icons.email_outlined, 'Email', email),
                      if (phone.isNotEmpty)
                        _detailRow(Icons.phone_outlined, 'Phone', phone),
                      if (website.isNotEmpty)
                        _detailRow(Icons.language_outlined, 'Website', website),
                      if (address.isNotEmpty)
                        _detailRow(
                          Icons.location_on_outlined,
                          'Head Office',
                          address,
                        ),
                    ]),

                  if (claims != null || solvency != null)
                    _sectionCard('Financial Metrics', [
                      if (claims != null)
                        _detailRow(
                          Icons.receipt_long_outlined,
                          'Claims Settlement Ratio',
                          '$claims%',
                        ),
                      if (solvency != null)
                        _detailRow(
                          Icons.account_balance_outlined,
                          'Solvency Ratio',
                          '$solvency',
                        ),
                    ]),

                  if (contacts.isNotEmpty) ...[
                    _sectionTitle('Contact Persons'),
                    ...contacts.map((c) => _ContactPersonCard(c)),
                  ],

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerBtn(
    IconData icon,
    Color color,
    String tooltip,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              tooltip,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      title,
      style: const TextStyle(
        color: _textMain,
        fontSize: 13,
        fontWeight: FontWeight.w800,
      ),
    ),
  );

  Widget _sectionCard(String title, List<Widget> rows) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Text(
              title,
              style: const TextStyle(
                color: _primary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const Divider(height: 1, color: _border),
          ...rows,
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 15, color: _textMuted),
          const SizedBox(width: 12),
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(color: _textMuted, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: _textMain,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Contact Person Card ──────────────────────────────────────────────────────
class _ContactPersonCard extends StatelessWidget {
  final Map<String, dynamic> contact;

  static const _primary = Color(0xFF0D2D4F);
  static const _surface = Color(0xFFFFFFFF);
  static const _border = Color(0xFFE4E7EC);
  static const _textMain = Color(0xFF0D1B2A);
  static const _textMuted = Color(0xFF8A94A6);

  const _ContactPersonCard(this.contact);

  @override
  Widget build(BuildContext context) {
    final name = contact['name'] ?? '';
    final designation = contact['designation'] ?? '';
    final phone = contact['phone'] ?? '';
    final email = contact['email'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: _primary.withValues(alpha: 0.08),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                color: _primary,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: _textMain,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (designation.isNotEmpty)
                  Text(
                    designation,
                    style: const TextStyle(color: _textMuted, fontSize: 12),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (phone.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.phone_outlined,
                      size: 12,
                      color: _textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      phone,
                      style: const TextStyle(color: _textMuted, fontSize: 12),
                    ),
                  ],
                ),
              if (email.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.email_outlined,
                      size: 12,
                      color: _textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      email,
                      style: const TextStyle(color: _textMuted, fontSize: 12),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
