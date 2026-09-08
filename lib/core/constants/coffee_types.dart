enum CoffeeType {
  jenfel,
  yetatebe,
  special;

  String get displayName {
    switch (this) {
      case CoffeeType.jenfel:
        return 'Dried';
      case CoffeeType.yetatebe:
        return 'Washed';
      case CoffeeType.special:
        return 'Special';
    }
  }

  String get id {
    return name;
  }
}
