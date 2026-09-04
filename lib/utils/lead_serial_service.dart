import 'package:cloud_firestore/cloud_firestore.dart';

class LeadSerialReservation {
  const LeadSerialReservation({
    required this.leadUniqueId,
    required this.sequence,
    required this.year,
    required this.categoryCode,
  });

  final String leadUniqueId;
  final int sequence;
  final int year;
  final String categoryCode;

  Map<String, dynamic> toFirestoreFields() => <String, dynamic>{
    'leadUniqueId': leadUniqueId,
    'uniqueLeadId': leadUniqueId,
    'leadSerialNumber': leadUniqueId,
    'leadSerialSequence': sequence,
    'leadSerialYear': year,
    'leadSerialCategoryCode': categoryCode,
  };
}

class LeadSerialService {
  LeadSerialService._();

  static String categoryCode(String category) {
    switch (category.trim().toLowerCase()) {
      case 'health':
        return 'H';
      case 'life':
        return 'L';
      case 'general':
        return 'G';
      case 'agriculture':
      case 'agricultural':
        return 'A';
      case 'ecgc':
        return 'E';
      default:
        throw ArgumentError.value(
          category,
          'category',
          'A lead category is required to generate its unique ID.',
        );
    }
  }

  static String formatSerial({
    required String category,
    required int year,
    required int sequence,
  }) {
    if (sequence < 1 || sequence > 99999) {
      throw RangeError.range(sequence, 1, 99999, 'sequence');
    }
    final sequenceCode = sequence.toString().padLeft(5, '0');
    return 'M${categoryCode(category)}$year$sequenceCode';
  }

  static Future<LeadSerialReservation> reserve({
    required String category,
    required String leadId,
    required String leadName,
    FirebaseFirestore? firestore,
    DateTime? now,
  }) async {
    final db = firestore ?? FirebaseFirestore.instance;
    final allocatedAt = now ?? DateTime.now();
    final year = allocatedAt.year;
    final code = categoryCode(category);
    final counterRef = db
        .collection('system_counters')
        .doc('lead_serial_$year');

    return db.runTransaction((transaction) async {
      final counter = await transaction.get(counterRef);
      final current = (counter.data()?['lastSequence'] as num?)?.toInt() ?? 0;
      final next = current + 1;
      final leadUniqueId = formatSerial(
        category: category,
        year: year,
        sequence: next,
      );
      final registryRef = db
          .collection('lead_serial_registry')
          .doc(leadUniqueId);
      final existingRegistry = await transaction.get(registryRef);
      if (existingRegistry.exists) {
        throw StateError(
          'Lead serial counter is out of sync at $leadUniqueId. '
          'No duplicate unique ID was created.',
        );
      }

      transaction.set(counterRef, <String, dynamic>{
        'year': year,
        'lastSequence': next,
        'lastLeadUniqueId': leadUniqueId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      transaction.set(registryRef, <String, dynamic>{
        'leadUniqueId': leadUniqueId,
        'sequence': next,
        'year': year,
        'category': category.trim(),
        'categoryCode': code,
        'leadId': leadId,
        'leadName': leadName,
        'status': 'Allocated',
        'allocatedAt': FieldValue.serverTimestamp(),
      });

      return LeadSerialReservation(
        leadUniqueId: leadUniqueId,
        sequence: next,
        year: year,
        categoryCode: code,
      );
    });
  }
}
