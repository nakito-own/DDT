import 'dart:math';

class LoginBackgroundConfig {
  LoginBackgroundConfig._();

  static const String assetPath = 'assets/images/login/background.jpg';

  /// Фото для светлой темы. Вставляйте прямые ссылки на изображения сюда.
  static const List<String> lightNetworkUrls = [
    'https://i.pinimg.com/originals/e5/93/6c/e5936cca2f75314777b4f186074f57d6.png',
    'https://i.pinimg.com/originals/ca/ac/86/caac86d50dac6038a7fd42d373110439.jpg',
    'https://www.bruegel.org/sites/default/files/styles/og_image/public/wp_images/-shutterstock_1576413886-1.jpg?itok=hAaNAwSu'
  ];

  /// Фото для тёмной темы. Вставляйте прямые ссылки на изображения сюда.
  static const List<String> darkNetworkUrls = [
    'https://i.pinimg.com/originals/df/b1/fa/dfb1fa9b68635d431726818d451c9434.jpg',
    'https://images.wallpaperscraft.com/image/single/night_city_skyscrapers_panorama_120591_3840x2400.jpg'
  ];

  static String? pickRandomNetworkUrl({
    required bool isDark,
    Random? random,
  }) {
    final urls = isDark ? darkNetworkUrls : lightNetworkUrls;
    if (urls.isEmpty) {
      return null;
    }

    final rng = random ?? Random();
    return urls[rng.nextInt(urls.length)];
  }

  /// Лёгкое затемнение поверх фото в тёмной теме.
  static const double darkOverlayOpacity = 0.10;

  /// Засветка поверх фото в светлой теме.
  static const double lightOverlayOpacity = 0.44;

  /// Лёгкий блюр самого фото.
  static const double backgroundBlurSigma = 4;
}
