enum CoffeeType {
  jenfel,
  wet,
  special;

  String get displayName {
    switch (this) {
      case CoffeeType.jenfel:
        return 'Dried';
      case CoffeeType.wet:
        return 'Wet';
      case CoffeeType.special:
        return 'Special';
    }
  }

  String get id {
    return name;
  }
}
