import 'package:cloud_firestore/cloud_firestore.dart';

/// The permanent serial allocated to one customer policy.
class PolicySerialReservation {
  const PolicySerialReservation({
    required this.serialNumber,
    required this.sequence,
    required this.year,
    required this.categoryCode,
  });

  final String serialNumber;
  final int sequence;
  final int year;
  final String categoryCode;

  Map<String, dynamic> toFirestoreFields() => <String, dynamic>{
    'serialNumber': serialNumber,
    'policySerialNumber': serialNumber,
    'serialSequence': sequence,
    'serialYear': year,
    'serialCategoryCode': categoryCode,
  };
}

/// Allocates policy serials from one Firebase counter per calendar year.
///
/// A Firestore transaction makes the sequence safe when several employees add
/// policies at the same time. The companion registry provides a direct audit
/// record for every serial that has been issued.
class PolicySerialService {
  PolicySerialService._();

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
          'A policy category is required to generate its serial number.',
        );
    }
  }

  static String formatSerial({
    required String category,
    required int year,
    required int sequence,
  }) {
    if (sequence < 1 || sequence > 999999) {
      throw RangeError.range(sequence, 1, 999999, 'sequence');
    }
    final yearCode = (year % 100).toString().padLeft(2, '0');
    final sequenceCode = sequence.toString().padLeft(6, '0');
    return 'M${categoryCode(category)}$yearCode$sequenceCode';
  }

  static Future<PolicySerialReservation> reserve({
    required String category,
    required String policyId,
    required String customerId,
    required String customerName,
    FirebaseFirestore? firestore,
    DateTime? now,
  }) async {
    final db = firestore ?? FirebaseFirestore.instance;
    final allocatedAt = now ?? DateTime.now();
    final year = allocatedAt.year;
    final code = categoryCode(category);
    final counterRef = db
        .collection('system_counters')
        .doc('policy_serial_$year');

    return db.runTransaction((transaction) async {
      final counter = await transaction.get(counterRef);
      final current = (counter.data()?['lastSequence'] as num?)?.toInt() ?? 0;
      final next = current + 1;
      final serialNumber = formatSerial(
        category: category,
        year: year,
        sequence: next,
      );
      final registryRef = db
          .collection('policy_serial_registry')
          .doc(serialNumber);
      final existingRegistry = await transaction.get(registryRef);
      if (existingRegistry.exists) {
        throw StateError(
          'Policy serial counter is out of sync at $serialNumber. '
          'No duplicate serial was created.',
        );
      }

      transaction.set(counterRef, <String, dynamic>{
        'year': year,
        'lastSequence': next,
        'lastSerialNumber': serialNumber,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      transaction.set(registryRef, <String, dynamic>{
        'serialNumber': serialNumber,
        'sequence': next,
        'year': year,
        'category': category.trim(),
        'categoryCode': code,
        'policyId': policyId,
        'customerId': customerId,
        'customerName': customerName,
        'status': 'Allocated',
        'allocatedAt': FieldValue.serverTimestamp(),
      });

      return PolicySerialReservation(
        serialNumber: serialNumber,
        sequence: next,
        year: year,
        categoryCode: code,
      );
    });
  }
}
