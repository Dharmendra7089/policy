import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../utils/audit_log_service.dart';
import '../utils/document_picker.dart';
import '../utils/document_opener.dart';

class CustomerFilesCard extends StatefulWidget {
  final String customerId;
  final String customerName;
  final Map<String, dynamic>? currentUser;

  const CustomerFilesCard({
    super.key,
    required this.customerId,
    required this.customerName,
    required this.currentUser,
  });

  @override
  State<CustomerFilesCard> createState() => _CustomerFilesCardState();
}

class _CustomerFilesCardState extends State<CustomerFilesCard> {
  static const _primary = Color(0xFF0D2D4F);
  static const _accent = Color(0xFF1A6EBD);
  static const _surface = Color(0xFFFFFFFF);
  static const _bg = Color(0xFFF4F6F9);
  static const _border = Color(0xFFE4E7EC);
  static const _textMain = Color(0xFF0D1B2A);
  static const _textMuted = Color(0xFF8A94A6);
  static const _red = Color(0xFFDC2626);

  bool _uploading = false;
  String? _uploadStatus;

  Stream<QuerySnapshot<Map<String, dynamic>>> get _filesStream =>
      FirebaseFirestore.instance
          .collection('customer_files')
          .where('customerId', isEqualTo: widget.customerId)
          .snapshots();

  DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  String _formatDateTime(dynamic value) {
    final date = _date(value);
    if (date == null) return 'Saving...';
    final hour = date.hour == 0
        ? 12
        : (date.hour > 12 ? date.hour - 12 : date.hour);
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} '
        '${hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} $period';
  }

  String? _getContentType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'gif':
        return 'image/gif';
      case 'txt':
        return 'text/plain';
      case 'csv':
        return 'text/csv';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      default:
        return 'application/octet-stream';
    }
  }

  IconData _getFileIcon(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'gif':
        return Icons.image_outlined;
      case 'doc':
      case 'docx':
        return Icons.description_outlined;
      case 'xls':
      case 'xlsx':
      case 'csv':
        return Icons.table_chart_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  Future<void> _pickAndUploadFile() async {
    if (_uploading) return;

    try {
      final file = await pickDocumentBytes();
      if (file == null) return;
      final fileBytes = file.bytes;

      if (fileBytes.isEmpty) {
        throw Exception('Could not read file data. Please try again.');
      }

      // Prompt for document name
      if (!mounted) return;
      final controller = TextEditingController(text: file.name);
      final docName = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: _surface,
          title: const Text(
            'Enter Document Name',
            style: TextStyle(
              color: _primary,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Document Name',
              labelStyle: TextStyle(color: _textMuted),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: _accent),
              ),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancel', style: TextStyle(color: _textMuted)),
            ),
            ElevatedButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  Navigator.pop(ctx, name);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Upload'),
            ),
          ],
        ),
      );

      if (docName == null) return; // User cancelled

      setState(() {
        _uploading = true;
        _uploadStatus = 'Uploading document...';
      });

      String customName = docName.trim();
      final originalExt = file.name.split('.').last;
      if (!customName.toLowerCase().endsWith('.${originalExt.toLowerCase()}')) {
        customName = '$customName.$originalExt';
      }

      final user = FirebaseAuth.instance.currentUser;
      final uid = user?.uid ?? '';
      final email = user?.email ?? '';

      // Create a safe, unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final safeName = customName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final storagePath =
          'customer_files/${widget.customerId}/${timestamp}_$safeName';

      final ref = FirebaseStorage.instance.ref(storagePath);
      await ref.putData(
        fileBytes,
        SettableMetadata(
          contentType: _getContentType(file.name),
          customMetadata: {
            'customerId': widget.customerId,
            'customerName': widget.customerName,
            'uploadedBy': email,
          },
        ),
      );

      final fileUrl = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('customer_files').add({
        'customerId': widget.customerId,
        'fileName': customName,
        'fileUrl': fileUrl,
        'storagePath': storagePath,
        'uploadedAt': FieldValue.serverTimestamp(),
        'uploadedBy': email.isNotEmpty ? email : uid,
        'uploadedByUid': uid,
        'type': 'General Document',
      });

      await AuditLogService.write(
        page: 'Customer Files',
        action: 'Uploaded Document',
        description:
            'Uploaded document "$customName" for customer "${widget.customerName}".',
        targetId: widget.customerId,
        targetType: 'Customer',
        targetName: widget.customerName,
        extra: {'customerName': widget.customerName, 'fileName': customName},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Document "$customName" uploaded successfully'),
            backgroundColor: _accent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: _red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
          _uploadStatus = null;
        });
      }
    }
  }

  Future<void> _openFileUrl(
    BuildContext context, {
    required String fileUrl,
    required String storagePath,
  }) async {
    var url = fileUrl.trim();
    if (url.isEmpty && storagePath.trim().isNotEmpty) {
      try {
        url = await FirebaseStorage.instance
            .ref(storagePath.trim())
            .getDownloadURL();
      } catch (_) {
        url = '';
      }
    }

    if (url.isEmpty || !await openDocumentUrl(url)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to open document. Please try uploading it again.',
          ),
        ),
      );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    String docId,
    String storagePath,
    String fileName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Document'),
        content: Text(
          'Are you sure you want to delete "$fileName"? This action cannot be undone.',
        ),
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

    if (confirmed == true) {
      try {
        await FirebaseStorage.instance.ref(storagePath).delete();
      } catch (e) {
        // Continue even if storage delete fails
      }

      await FirebaseFirestore.instance
          .collection('customer_files')
          .doc(docId)
          .delete();

      await AuditLogService.write(
        page: 'Customer Files',
        action: 'Deleted Document',
        description:
            'Deleted document "$fileName" for customer "${widget.customerName}".',
        targetId: widget.customerId,
        targetType: 'Customer',
        targetName: widget.customerName,
        extra: {'customerName': widget.customerName, 'fileName': fileName},
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Document "$fileName" deleted'),
            backgroundColor: _accent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Customer Documents',
                      style: TextStyle(
                        color: _primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Upload policies, KYC, or support documents.',
                      style: TextStyle(color: _textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: _uploading ? null : _pickAndUploadFile,
                icon: _uploading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _accent,
                        ),
                      )
                    : const Icon(Icons.upload_file_rounded, size: 16),
                label: Text(_uploading ? 'Uploading...' : 'Upload'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _accent,
                  side: const BorderSide(color: _accent),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
            ],
          ),
          if (_uploadStatus != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text(
                  _uploadStatus!,
                  style: const TextStyle(color: _textMuted, fontSize: 11),
                ),
              ],
            ),
          ],
          const Divider(height: 24, color: _border),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _filesStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(color: _accent),
                  ),
                );
              }
              if (snapshot.hasError) {
                return const Text(
                  'Unable to load documents.',
                  style: TextStyle(color: _red, fontSize: 12),
                );
              }

              final files = snapshot.data?.docs.toList() ?? [];
              files.sort((a, b) {
                final aDate = _date(a.data()['uploadedAt']);
                final bDate = _date(b.data()['uploadedAt']);
                return (bDate ?? DateTime(1970)).compareTo(
                  aDate ?? DateTime(1970),
                );
              });

              if (files.isEmpty) {
                return const Text(
                  'No documents uploaded yet.',
                  style: TextStyle(color: _textMuted, fontSize: 12),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'All Documents (${files.length})',
                    style: const TextStyle(
                      color: _primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: files.length,
                    itemBuilder: (context, index) {
                      final doc = files[index];
                      final data = doc.data();
                      final fileName = (data['fileName'] ?? 'Document')
                          .toString();
                      final fileUrl = (data['fileUrl'] ?? '').toString();
                      final storagePath = (data['storagePath'] ?? '')
                          .toString();
                      final uploadedAtStr = _formatDateTime(data['uploadedAt']);
                      final uploadedBy = (data['uploadedBy'] ?? 'Unknown')
                          .toString();
                      final type = (data['type'] ?? 'Document').toString();

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _bg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _border),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _getFileIcon(fileName),
                              color: _accent,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    fileName,
                                    style: const TextStyle(
                                      color: _textMain,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$type • $uploadedAtStr • By $uploadedBy',
                                    style: const TextStyle(
                                      color: _textMuted,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (fileUrl.isNotEmpty || storagePath.isNotEmpty)
                              IconButton(
                                icon: const Icon(
                                  Icons.open_in_new_rounded,
                                  size: 16,
                                  color: _accent,
                                ),
                                onPressed: () => _openFileUrl(
                                  context,
                                  fileUrl: fileUrl,
                                  storagePath: storagePath,
                                ),
                                tooltip: 'Open',
                              ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                size: 16,
                                color: _red,
                              ),
                              onPressed: () => _confirmDelete(
                                context,
                                doc.id,
                                storagePath,
                                fileName,
                              ),
                              tooltip: 'Delete',
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
