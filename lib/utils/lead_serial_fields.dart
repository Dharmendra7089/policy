import 'package:cloud_firestore/cloud_firestore.dart';

import 'lead_serial_service.dart';

String leadUniqueIdFromData(Map<String, dynamic> data) {
  for (final key in ['leadUniqueId', 'uniqueLeadId', 'leadSerialNumber']) {
    final value = data[key]?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return '';
}

Future<Map<String, dynamic>> reserveCustomerLeadUniqueIdFields({
  required String category,
  required String customerId,
  required String customerName,
  FirebaseFirestore? firestore,
}) async {
  final reservation = await LeadSerialService.reserve(
    category: category,
    leadId: customerId,
    leadName: customerName,
    firestore: firestore,
  );
  return reservation.toFirestoreFields();
}

Map<String, dynamic> leadUniqueIdCopyFields(Map<String, dynamic> data) {
  final value = leadUniqueIdFromData(data);
  if (value.isEmpty) return const <String, dynamic>{};
  return <String, dynamic>{
    'leadUniqueId': value,
    'uniqueLeadId': value,
    'leadSerialNumber': value,
  };
}
