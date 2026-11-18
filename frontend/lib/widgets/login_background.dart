import 'dart:ui';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../config/login_background_config.dart';
import '../theme/ddt_theme.dart';
import 'login_background_host.dart';

class LoginBackground extends StatefulWidget {
  const LoginBackground({super.key, this.appBackdrop = false});

  /// Сильно размытый и затонированный фон всего приложения.
  /// На экране входа остаётся лёгкая обработка того же кадра.
  final bool appBackdrop;

  @override
  State<LoginBackground> createState() => _LoginBackgroundState();
}

class _LoginBackgroundState extends State<LoginBackground> {
  static String? _sharedLightNetworkUrl;
  static String? _sharedDarkNetworkUrl;
  static bool _sharedUrlsReady = false;

  late final String? _lightNetworkUrl;
  late final String? _darkNetworkUrl;

  @override
  void initState() {
    super.initState();
    _ensureSharedUrls();
    _lightNetworkUrl = _sharedLightNetworkUrl;
    _darkNetworkUrl = _sharedDarkNetworkUrl;
  }

  static void _ensureSharedUrls() {
    if (_sharedUrlsReady) return;
    _sharedUrlsReady = true;
    _sharedLightNetworkUrl = LoginBackgroundConfig.pickRandomNetworkUrl(
      isDark: false,
    );
    _sharedDarkNetworkUrl = LoginBackgroundConfig.pickRandomNetworkUrl(
      isDark: true,
    );
    final light = _sharedLightNetworkUrl;
    final dark = _sharedDarkNetworkUrl;
    if (light != null) LoginBackgroundHost.preload(light);
    if (dark != null) LoginBackgroundHost.preload(dark);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LoginBackgroundHost.failedUrl,
      builder: (context, _) => _buildBackground(context),
    );
  }

  Widget _buildBackground(BuildContext context) {
    final assetPath = LoginBackgroundConfig.assetPath;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final networkUrl = isDark ? _darkNetworkUrl : _lightNetworkUrl;
    final failed = LoginBackgroundHost.failedUrl.value == networkUrl;
    final sigma = widget.appBackdrop
        ? (isDark
              ? LoginBackgroundConfig.appBackdropBlurSigma
              : LoginBackgroundConfig.appBackdropLightBlurSigma)
        : LoginBackgroundConfig.backgroundBlurSigma;
    final scale = widget.appBackdrop ? 1.22 : 1.06;

    LoginBackgroundHost.sync(
      url: failed ? null : networkUrl,
      blurSigma: sigma,
      scale: scale,
    );

    final showWebPhoto = kIsWeb && networkUrl != null && !failed;
    final showFlutterPhoto = !showWebPhoto;
    final photo = !showFlutterPhoto
        ? const SizedBox.expand()
        : networkUrl != null && !failed
        ? _NetworkBackgroundImage(url: networkUrl)
        : assetPath.isNotEmpty
        ? _AssetBackgroundImage(path: assetPath)
        : _GradientFallback(isDark: isDark);

    final overlay = widget.appBackdrop
        ? (isDark ? DdtTheme.darkBackground : DdtTheme.lightBackground)
              .withValues(
                alpha: isDark
                    ? LoginBackgroundConfig.appBackdropDarkOverlayOpacity
                    : LoginBackgroundConfig.appBackdropLightOverlayOpacity,
              )
        : (isDark ? Colors.black : Colors.white).withValues(
            alpha: isDark
                ? LoginBackgroundConfig.darkOverlayOpacity
                : LoginBackgroundConfig.lightOverlayOpacity,
          );

    return Stack(
      fit: StackFit.expand,
      children: [
        if (showWebPhoto) const WebBackgroundSurface(),
        if (showFlutterPhoto)
          _BlurredBackground(sigma: sigma, scale: scale, child: photo),
        ColoredBox(color: overlay),
      ],
    );
  }
}

class _BlurredBackground extends StatelessWidget {
  const _BlurredBackground({
    required this.child,
    required this.sigma,
    required this.scale,
  });

  final Widget child;
  final double sigma;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Transform.scale(
        scale: scale,
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(
            sigmaX: sigma,
            sigmaY: sigma,
            tileMode: TileMode.clamp,
          ),
          child: child,
        ),
      ),
    );
  }
}

class _NetworkBackgroundImage extends StatelessWidget {
  const _NetworkBackgroundImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return _GradientFallback(isDark: isDark);
      },
    );
  }
}

class _AssetBackgroundImage extends StatelessWidget {
  const _AssetBackgroundImage({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Image(
      image: AssetImage(path),
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return _GradientFallback(isDark: isDark);
      },
    );
  }
}

class _GradientFallback extends StatelessWidget {
  const _GradientFallback({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF05070C), Color(0xFF0C1018), Color(0xFF070910)]
              : const [Color(0xFFE6ECF7), Color(0xFFEEF2F7), Color(0xFFE3EBF6)],
        ),
      ),
    );
  }
}
