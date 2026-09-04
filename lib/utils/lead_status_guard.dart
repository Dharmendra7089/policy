import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'lead_workflow_rules.dart';

class LeadRedGateResult {
  const LeadRedGateResult({
    required this.purchaseValue,
    required this.routedLeadStatus,
    required this.escalateToTeamLeader,
    required this.leadReference,
    required this.leadUpdates,
  });

  final double purchaseValue;
  final String routedLeadStatus;
  final bool escalateToTeamLeader;
  final DocumentReference<Map<String, dynamic>> leadReference;
  final Map<String, dynamic> leadUpdates;
}

class LeadStatusGuard {
  LeadStatusGuard._();

  static Future<LeadRedGateResult?> requireExecutiveRedGate({
    required BuildContext context,
    required String customerId,
    required Map<String, dynamic>? currentUser,
  }) async {
    final firestore = FirebaseFirestore.instance;
    final linkedLead = await linkedExecutiveLead(
      firestore: firestore,
      customerId: customerId,
    );
    if (!context.mounted) return null;
    if (linkedLead == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Red is locked. This customer is not linked to an executive lead with 5 calls and 5 notes.',
          ),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return null;
    }

    final data = linkedLead.data();
    final calls = (data['executiveCallCount'] as num?)?.toInt() ?? 0;
    final notes = ((data['executiveCallNotes'] as List?) ?? const []).length;
    if (calls < LeadWorkflowRules.executiveCallLimit ||
        notes < LeadWorkflowRules.executiveCallLimit) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Red is locked. Complete 5 calls and 5 call notes first. Current: $calls calls, $notes notes.',
            ),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
      return null;
    }

    final result = await _askCustomerValue(context);
    if (!context.mounted) return null;
    if (result == null) return null;

    final userData = currentUser ?? const <String, dynamic>{};
    final teamLeaderId = (userData['teamLeaderId'] ?? '').toString();
    final escalate = LeadWorkflowRules.shouldEscalateToTeamLeader(result);
    if (escalate && teamLeaderId.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This executive is not assigned to a Team Leader.'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
      }
      return null;
    }

    final routedStatus = LeadWorkflowRules.routedLeadStatus(result);
    final updates = <String, dynamic>{
      'customerPurchaseValue': result,
      'executiveReviewedAt': FieldValue.serverTimestamp(),
      'executiveLeadStatus': LeadWorkflowRules.executiveClosedStatus,
      'executiveClosedAt': FieldValue.serverTimestamp(),
      'leadStatus': routedStatus,
      'executiveEscalatedToTeamLeader': escalate,
      if (escalate) ...{
        'teamLeaderAssignedToId': teamLeaderId,
        'teamLeaderAssignedToUid': (userData['teamLeaderUid'] ?? '').toString(),
        'teamLeaderAssignedToName': (userData['teamLeaderName'] ?? '')
            .toString(),
        'teamLeaderAssignedToEmail': (userData['teamLeaderEmail'] ?? '')
            .toString(),
        'teamLeaderAssignedAt': FieldValue.serverTimestamp(),
        'teamLeaderLeadStatus': LeadWorkflowRules.green,
        'teamLeaderCallCount': 0,
        'teamLeaderCallHistory': const <Map<String, dynamic>>[],
        'executiveEscalatedAt': FieldValue.serverTimestamp(),
      },
    };

    return LeadRedGateResult(
      purchaseValue: result,
      routedLeadStatus: routedStatus,
      escalateToTeamLeader: escalate,
      leadReference: linkedLead.reference,
      leadUpdates: updates,
    );
  }

  static Future<QueryDocumentSnapshot<Map<String, dynamic>>?>
  linkedExecutiveLead({
    required FirebaseFirestore firestore,
    required String customerId,
  }) async {
    final customer = await firestore
        .collection('customers')
        .doc(customerId)
        .get();
    final customerData = customer.data() ?? const <String, dynamic>{};
    final leadIds = <String>{
      for (final key in [
        'telecallerLeadId',
        'executiveLeadId',
        'leadId',
        'linkedLeadId',
      ])
        if ((customerData[key] ?? '').toString().trim().isNotEmpty)
          (customerData[key] ?? '').toString().trim(),
    };

    for (final leadId in leadIds) {
      final lead = await firestore
          .collection('telecaller_leads')
          .doc(leadId)
          .get();
      if (lead.exists && _hasExecutiveLink(lead.data())) {
        final query = await firestore
            .collection('telecaller_leads')
            .where(FieldPath.documentId, isEqualTo: lead.id)
            .limit(1)
            .get();
        if (query.docs.isNotEmpty) return query.docs.first;
      }
    }

    for (final field in [
      'executiveCustomerIds',
      'customerIds',
      'linkedCustomerIds',
    ]) {
      final byCustomerId = await firestore
          .collection('telecaller_leads')
          .where(field, arrayContains: customerId)
          .limit(1)
          .get();
      final lead = _firstExecutiveLead(byCustomerId.docs);
      if (lead != null) return lead;
    }

    for (final key in ['leadUniqueId', 'uniqueLeadId', 'leadSerialNumber']) {
      final value = (customerData[key] ?? '').toString().trim();
      if (value.isEmpty) continue;
      final byUniqueId = await firestore
          .collection('telecaller_leads')
          .where(key, isEqualTo: value)
          .limit(1)
          .get();
      final lead = _firstExecutiveLead(byUniqueId.docs);
      if (lead != null) return lead;
    }

    final mobile = (customerData['mobileNumber'] ?? '').toString().trim();
    if (mobile.isNotEmpty) {
      final byMobile = await firestore
          .collection('telecaller_leads')
          .where('mobileNumber', isEqualTo: mobile)
          .limit(5)
          .get();
      final lead = _firstExecutiveLead(byMobile.docs);
      if (lead != null) return lead;
    }

    return null;
  }

  static QueryDocumentSnapshot<Map<String, dynamic>>? _firstExecutiveLead(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    for (final doc in docs) {
      if (_hasExecutiveLink(doc.data())) return doc;
    }
    return null;
  }

  static bool _hasExecutiveLink(Map<String, dynamic>? data) {
    if (data == null) return false;
    return (data['assignedExecutiveId'] ?? '').toString().trim().isNotEmpty ||
        (data['assignedExecutiveUid'] ?? '').toString().trim().isNotEmpty ||
        (data['assignedExecutiveName'] ?? '').toString().trim().isNotEmpty ||
        (data['executiveAssignedToId'] ?? '').toString().trim().isNotEmpty ||
        (data['executiveAssignedToUid'] ?? '').toString().trim().isNotEmpty ||
        (data['executiveAssignedToName'] ?? '').toString().trim().isNotEmpty;
  }

  static Future<double?> _askCustomerValue(BuildContext context) {
    final controller = TextEditingController();
    String? errorText;
    return showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Customer Purchase Value'),
              content: TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Enter value',
                  prefixText: 'Rs ',
                  errorText: errorText,
                ),
                autofocus: true,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final value = double.tryParse(
                      controller.text.trim().replaceAll(',', ''),
                    );
                    if (value == null || value < 0) {
                      setDialogState(
                        () => errorText = 'Enter a valid customer value.',
                      );
                      return;
                    }
                    Navigator.pop(dialogContext, value);
                  },
                  child: const Text('Continue'),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(controller.dispose);
  }
}
