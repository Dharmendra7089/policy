class LeadWorkflowRules {
  LeadWorkflowRules._();

  static const int executiveCallLimit = 5;
  static const int teamLeaderCallLimit = 2;
  static const double teamLeaderEscalationThreshold = 25000;
  static const String green = 'Green';
  static const String red = 'Red';

  static bool shouldEscalateToTeamLeader(double customerPurchaseValue) =>
      customerPurchaseValue > teamLeaderEscalationThreshold;

  static String routedLeadStatus(double customerPurchaseValue) =>
      shouldEscalateToTeamLeader(customerPurchaseValue) ? green : red;

  static String get executiveClosedStatus => red;
}
