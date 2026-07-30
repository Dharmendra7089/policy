import 'package:flutter_test/flutter_test.dart';
import 'package:policy/utils/policy_serial_service.dart';

void main() {
  group('PolicySerialService', () {
    test('uses one six-digit sequence across policy categories', () {
      expect(
        PolicySerialService.formatSerial(
          category: 'Health',
          year: 2026,
          sequence: 1,
        ),
        'MH26000001',
      );
      expect(
        PolicySerialService.formatSerial(
          category: 'Life',
          year: 2026,
          sequence: 2,
        ),
        'ML26000002',
      );
      expect(
        PolicySerialService.formatSerial(
          category: 'General',
          year: 2026,
          sequence: 3,
        ),
        'MG26000003',
      );
    });

    test('supports Agriculture and ECGC category letters', () {
      expect(PolicySerialService.categoryCode('Agricultural'), 'A');
      expect(PolicySerialService.categoryCode('ECGC'), 'E');
    });

    test('rejects a sequence outside the six-digit range', () {
      expect(
        () => PolicySerialService.formatSerial(
          category: 'Health',
          year: 2026,
          sequence: 1000000,
        ),
        throwsRangeError,
      );
    });
  });
}
