import 'dart:math';

class LoginBackgroundConfig {
  LoginBackgroundConfig._();

  static const String assetPath = 'assets/images/login/background.jpg';

  static const List<String> networkUrls = [
    'https://i.pinimg.com/originals/ca/ac/86/caac86d50dac6038a7fd42d373110439.jpg',
    'https://i.pinimg.com/originals/df/b1/fa/dfb1fa9b68635d431726818d451c9434.jpg',
  ];

  static String? pickRandomNetworkUrl([Random? random]) {
    if (networkUrls.isEmpty) {
      return null;
    }

    final rng = random ?? Random();
    return networkUrls[rng.nextInt(networkUrls.length)];
  }

  static const double darkOverlayOpacity = 0.58;

  static const double lightOverlayOpacity = 0.42;
}
