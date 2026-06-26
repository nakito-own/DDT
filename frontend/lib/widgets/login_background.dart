import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../config/login_background_config.dart';
import '../services/api_client.dart';

class LoginBackground extends StatefulWidget {
  const LoginBackground({super.key});

  @override
  State<LoginBackground> createState() => _LoginBackgroundState();
}

class _LoginBackgroundState extends State<LoginBackground> {
  late final String? _networkUrl;

  @override
  void initState() {
    super.initState();
    _networkUrl = _resolveNetworkUrl(
      LoginBackgroundConfig.pickRandomNetworkUrl(),
    );
  }

  static String? _resolveNetworkUrl(String? url) {
    if (url == null || url.isEmpty) {
      return null;
    }

    if (kIsWeb) {
      return _imageProxyUrl(url);
    }

    return url;
  }

  static String _imageProxyUrl(String originalUrl) {
    final encoded = Uri.encodeComponent(originalUrl);
    final path = '/api/static/image-proxy?url=$encoded';
    final port = Uri.base.port;

    if (port == 80 || port == 8080 || port == 443) {
      return '${Uri.base.origin}$path';
    }

    return '$apiUrl$path';
  }

  @override
  Widget build(BuildContext context) {
    final assetPath = LoginBackgroundConfig.assetPath;
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (_networkUrl != null)
          _NetworkBackgroundImage(url: _networkUrl)
        else if (assetPath.isNotEmpty)
          _AssetBackgroundImage(path: assetPath)
        else
          _GradientFallback(isDark: isDark),
        ColoredBox(
          color: isDark
              ? Colors.black.withValues(
                  alpha: LoginBackgroundConfig.darkOverlayOpacity,
                )
              : Colors.white.withValues(
                  alpha: LoginBackgroundConfig.lightOverlayOpacity,
                ),
        ),
      ],
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
              ? [
                  const Color(0xFF0D1B2A),
                  AppColors.primary.withValues(alpha: 0.85),
                  const Color(0xFF1B263B),
                ]
              : [
                  AppColors.primary.withValues(alpha: 0.18),
                  const Color(0xFFE3F2FD),
                  AppColors.accent.withValues(alpha: 0.35),
                ],
        ),
      ),
    );
  }
}
