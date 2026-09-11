import 'package:flutter_test/flutter_test.dart';
import 'package:cofiz/core/constants/coffee_types.dart';

void main() {
  test('wet exists with Wet display name', () {
    expect(CoffeeType.values.map((t) => t.name), contains('wet'));
    expect(CoffeeType.wet.displayName, 'Wet');
  });

  test('no yetatebe value remains', () {
    expect(CoffeeType.values.map((t) => t.name), isNot(contains('yetatebe')));
  });
}
