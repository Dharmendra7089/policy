import 'package:flutter_test/flutter_test.dart';
import 'package:policy/utils/lead_workflow_rules.dart';

void main() {
  group('LeadWorkflowRules', () {
    test('requires five Executive calls and two Team Leader calls', () {
      expect(LeadWorkflowRules.executiveCallLimit, 5);
      expect(LeadWorkflowRules.teamLeaderCallLimit, 2);
    });

    test('keeps exactly Rs 25,000 Red', () {
      expect(LeadWorkflowRules.routedLeadStatus(25000), LeadWorkflowRules.red);
    });

    test('escalates values above Rs 25,000 as Green', () {
      expect(
        LeadWorkflowRules.routedLeadStatus(25000.01),
        LeadWorkflowRules.green,
      );
      expect(LeadWorkflowRules.shouldEscalateToTeamLeader(50000), isTrue);
      expect(LeadWorkflowRules.executiveClosedStatus, LeadWorkflowRules.red);
    });
  });
}
