import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuditLogService {
  const AuditLogService._();

  static Future<void> write({
    required String page,
    required String action,
    required String description,
    String? targetId,
    String? targetType,
    String? targetName,
    Map<String, dynamic>? extra,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('logs').add({
        'page': page,
        'action': action,
        'description': description,
        'targetId': targetId ?? '',
        'targetType': targetType ?? '',
        'targetName': targetName ?? '',
        'performedBy': user?.email ?? user?.uid ?? 'Unknown',
        'performedByUid': user?.uid ?? '',
        'timestamp': FieldValue.serverTimestamp(),
        if (extra != null) ...extra,
      });
    } catch (_) {
      // Logging should never block the user's workflow.
    }
  }
}
