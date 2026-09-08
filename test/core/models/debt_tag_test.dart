import 'package:flutter_test/flutter_test.dart';
import 'package:cofiz/core/models/debt_model.dart';

void main() {
  group('Debt.cleanNotes', () {
    test('strips the debt tag and trims', () {
      expect(
        Debt.cleanNotes('For Geda [Debt: ETB 500]'),
        'For Geda',
      );
    });

    test('leaves plain notes untouched', () {
      expect(Debt.cleanNotes('Just coffee'), 'Just coffee');
    });

    test('tag-only notes clean to empty', () {
      expect(Debt.cleanNotes('[Debt: ETB 500]'), isEmpty);
    });

    test('handles null', () {
      expect(Debt.cleanNotes(null), isEmpty);
    });
  });

  group('Debt.debtTagAmount', () {
    test('parses the tagged amount', () {
      expect(Debt.debtTagAmount('For Geda [Debt: ETB 500]'), 500);
    });

    test('parses comma-grouped amounts', () {
      expect(Debt.debtTagAmount('[Debt: ETB 12,500]'), 12500);
    });

    test('returns null when no tag', () {
      expect(Debt.debtTagAmount('Just coffee'), isNull);
      expect(Debt.debtTagAmount(null), isNull);
    });
  });
}
