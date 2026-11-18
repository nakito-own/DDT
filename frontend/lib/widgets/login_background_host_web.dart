import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:web/web.dart' as web;

/// Картинка фона — обычный `<img>` внутри сцены Flutter.
///
/// Браузер качает файл напрямую с источника, без CORS и без прокси.
/// Слой лежит под интерфейсом, поэтому фото видно и на входе, и в приложении.
class LoginBackgroundHost {
  static final ValueNotifier<String?> failedUrl = ValueNotifier<String?>(null);

  static String viewType = 'ddt-login-background';

  static web.HTMLImageElement? _image;
  static String? _appliedUrl;
  static _BackgroundFrame? _frame;
  static bool _registered = false;

  static void preload(String url) {
    if (url.isEmpty) return;
    web.HTMLImageElement()
      ..referrerPolicy = 'no-referrer'
      ..decoding = 'async'
      ..src = url;
  }

  static void ensureRegistered() {
    if (_registered) return;
    _registered = true;
    final added = ui_web.platformViewRegistry.registerViewFactory(viewType, (
      _,
    ) {
      return _createView();
    });
    if (added) return;
    // Hot restart keeps the previous factory. Register a fresh view type.
    viewType = 'ddt-login-background-${DateTime.now().microsecondsSinceEpoch}';
    ui_web.platformViewRegistry.registerViewFactory(viewType, (_) {
      return _createView();
    });
  }

  static void sync({
    required String? url,
    required double blurSigma,
    required double scale,
  }) {
    _frame = _BackgroundFrame(url: url, blurSigma: blurSigma, scale: scale);
    _apply();
  }

  static web.HTMLElement _createView() {
    final image = web.HTMLImageElement()
      ..alt = ''
      ..referrerPolicy = 'no-referrer'
      ..decoding = 'async'
      ..draggable = false;
    image.style
      ..position = 'absolute'
      ..objectFit = 'cover'
      ..pointerEvents = 'none'
      ..transformOrigin = 'center center';

    final root = web.HTMLDivElement();
    root.style
      ..width = '100%'
      ..height = '100%'
      ..overflow = 'hidden'
      ..pointerEvents = 'none'
      ..position = 'relative';
    root.append(image);

    _image = image;
    _bind(image);
    _apply();
    return root;
  }

  static void _bind(web.HTMLImageElement image) {
    image.addEventListener(
      'load',
      ((web.Event _) {
        if (image.getAttribute('src') != _frame?.url) return;
        if (image.naturalWidth == 0) return;
        image.style.opacity = '1';
        if (failedUrl.value != null) {
          failedUrl.value = null;
        }
      }).toJS,
    );
    image.addEventListener(
      'error',
      ((web.Event _) {
        final url = _frame?.url;
        if (image.getAttribute('src') != url) return;
        image.style.opacity = '0';
        if (failedUrl.value != url) {
          failedUrl.value = url;
        }
      }).toJS,
    );
  }

  static void _apply() {
    final image = _image;
    final frame = _frame;
    if (image == null || frame == null) return;

    final bleed = (frame.scale * 100).toStringAsFixed(2);
    final shift = ((1 - frame.scale) * 50).toStringAsFixed(2);
    image.style
      ..width = '$bleed%'
      ..height = '$bleed%'
      ..left = '$shift%'
      ..top = '$shift%'
      ..filter = 'blur(${frame.blurSigma}px)';

    final url = frame.url;
    if (url == null || url.isEmpty) {
      _appliedUrl = null;
      image.style.opacity = '0';
      image.removeAttribute('src');
      return;
    }

    if (_appliedUrl == url) return;
    _appliedUrl = url;
    image.style.opacity = '0';
    image.src = url;
    if (image.complete && image.naturalWidth > 0) {
      image.style.opacity = '1';
    }
  }
}

class _BackgroundFrame {
  const _BackgroundFrame({
    required this.url,
    required this.blurSigma,
    required this.scale,
  });

  final String? url;
  final double blurSigma;
  final double scale;
}

class WebBackgroundSurface extends StatelessWidget {
  const WebBackgroundSurface({super.key});

  @override
  Widget build(BuildContext context) {
    LoginBackgroundHost.ensureRegistered();
    return IgnorePointer(
      child: HtmlElementView(
        viewType: LoginBackgroundHost.viewType,
        hitTestBehavior: PlatformViewHitTestBehavior.transparent,
      ),
    );
  }
}
