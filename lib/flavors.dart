enum Flavor {
  dev,
  prod,
}

class F {
  static late final Flavor appFlavor;

  static String get name => appFlavor.name;

  static bool get isDebugMode => appFlavor == Flavor.dev;

  static String get title {
    switch (appFlavor) {
      case Flavor.dev:
        return 'My Diary Dev';
      case Flavor.prod:
        return 'My Diary';
    }
  }

}
