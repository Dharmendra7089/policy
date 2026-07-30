class CommissionResult {
  final double percent;
  final double amount;
  final String rule;

  const CommissionResult({
    required this.percent,
    required this.amount,
    required this.rule,
  });
}

/// Evaluates the normalized commissionRules stored on imported policy records.
/// Rules are ordered from most specific to least specific. A rule may constrain
/// a numeric metric (premium, sumInsured, monthlyBusiness, policyTermYears or
/// age) and any string field present on the customer policy.
class CommissionEngine {
  static double number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(
          (value ?? '').toString().replaceAll(',', '').trim(),
        ) ??
        0;
  }

  static int _termYears(Map<String, dynamic> row) {
    final direct = number(row['policyTermYears']);
    if (direct > 0) return direct.round();
    final match = RegExp(
      r'\d+',
    ).firstMatch((row['policyTerm'] ?? '').toString());
    return match == null ? 0 : int.parse(match.group(0)!);
  }

  static double _metric(String metric, Map<String, dynamic> row) {
    switch (metric) {
      case 'sumInsured':
        return number(row['sumInsured'] ?? row['policySumInsured']);
      case 'monthlyBusiness':
        return number(row['monthlyBusiness'] ?? row['monthlyGwp']);
      case 'quarterlyBusiness':
        return number(row['quarterlyBusiness']);
      case 'annualBusiness':
        return number(row['annualBusiness']);
      case 'policyTermYears':
      case 'ppt':
        return _termYears(row).toDouble();
      case 'age':
        return number(row['insuredAge'] ?? row['age']);
      case 'premium':
      default:
        return number(row['premiumAmount'] ?? row['premium']);
    }
  }

  static bool _matches(Map<String, dynamic> rule, Map<String, dynamic> row) {
    final metric = (rule['metric'] ?? 'premium').toString();
    if (metric == 'monthlyBusiness' &&
        row['monthlyBusiness'] == null &&
        row['monthlyGwp'] == null) {
      return false;
    }
    if (metric == 'quarterlyBusiness' && row['quarterlyBusiness'] == null) {
      return false;
    }
    if (metric == 'annualBusiness' && row['annualBusiness'] == null) {
      return false;
    }
    if (metric == 'age' && row['insuredAge'] == null && row['age'] == null) {
      return false;
    }
    final value = _metric(metric, row);
    final from = rule['from'];
    final to = rule['to'];
    if (from != null && value < number(from)) return false;
    if (to != null && value > number(to)) return false;

    final conditions = rule['conditions'];
    if (conditions is Map) {
      for (final entry in conditions.entries) {
        final actual = (row[entry.key] ?? '').toString().trim().toLowerCase();
        final expected = entry.value;
        if (expected is List) {
          final allowed = expected
              .map((e) => e.toString().trim().toLowerCase())
              .toList();
          if (!allowed.contains(actual)) return false;
        } else if (actual != expected.toString().trim().toLowerCase()) {
          return false;
        }
      }
    }
    return true;
  }

  static CommissionResult calculate(
    Map<String, dynamic> policy,
    Map<String, dynamic> row,
  ) {
    final premium = _metric('premium', row);
    final manual = number(row['manualSlabPercent']);
    if (manual > 0) {
      return CommissionResult(
        percent: manual,
        amount: premium * manual / 100,
        rule: (row['manualSlabNote'] ?? 'Manual override').toString(),
      );
    }

    final rules = policy['commissionRules'];
    if (rules is List) {
      final matching =
          rules.whereType<Map>().where((raw) {
            return _matches(Map<String, dynamic>.from(raw), row);
          }).toList()..sort((a, b) {
            final ac = a['conditions'] is Map
                ? (a['conditions'] as Map).length
                : 0;
            final bc = b['conditions'] is Map
                ? (b['conditions'] as Map).length
                : 0;
            return bc.compareTo(ac);
      });
      for (final raw in matching) {
        final rule = Map<String, dynamic>.from(raw);
        double percent;
        if (rule['termMultiplier'] != null) {
          percent = _termYears(row) * number(rule['termMultiplier']);
        } else if (rule['baseMultiplier'] != null) {
          final base = number(row['baseCommissionPercent']);
          percent = base * number(rule['baseMultiplier']);
        } else {
          percent = number(rule['percent']);
        }
        if (rule['maxPercent'] != null &&
            percent > number(rule['maxPercent'])) {
          percent = number(rule['maxPercent']);
        }
        return CommissionResult(
          percent: percent,
          amount: premium * percent / 100,
          rule: (rule['label'] ?? 'Commission rule').toString(),
        );
      }
    }

    final fallback = number(
      policy['renewalCommission'] ?? policy['renewalCommissionPercent'],
    );
    return CommissionResult(
      percent: fallback,
      amount: premium * fallback / 100,
      rule: 'Renewal fallback',
    );
  }
}
