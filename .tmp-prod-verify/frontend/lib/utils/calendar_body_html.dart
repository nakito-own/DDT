import 'package:flutter/material.dart';

/// Приводит HTML повестки Exchange к цветам текущей темы.
///
/// В теле встречи часто зашиты цвет текста и фона (чёрный Calibri, белые
/// плашки Word). Такие цвета убираются, если они плохо читаются на фоне темы,
/// а шрифт и размер оставляются теме приложения.
String adaptCalendarBodyHtml(String html, {required bool isDark}) {
  var source = html.replaceAll(
    RegExp(r'<style\b[^>]*>[\s\S]*?</style>', caseSensitive: false),
    '',
  );
  source = source.replaceAll(
    RegExp(
      '''\\sbgcolor\\s*=\\s*("[^"]*"|'[^']*'|[^\\s>]+)''',
      caseSensitive: false,
    ),
    '',
  );
  source = source.replaceAll(
    RegExp(
      '''(?<!bg)\\scolor\\s*=\\s*("[^"]*"|'[^']*'|[^\\s>]+)''',
      caseSensitive: false,
    ),
    '',
  );
  return source.replaceAllMapped(
    RegExp('''style\\s*=\\s*("[^"]*"|'[^']*')''', caseSensitive: false),
    (match) {
      final quoted = match.group(1)!;
      final quote = quoted[0];
      final filtered = _filterStyle(
        quoted.substring(1, quoted.length - 1),
        isDark: isDark,
      );
      if (filtered.isEmpty) return '';
      return 'style=$quote$filtered$quote';
    },
  );
}

String _filterStyle(String style, {required bool isDark}) {
  final kept = <String>[];
  for (final part in style.split(';')) {
    final separator = part.indexOf(':');
    if (separator <= 0) continue;
    final property = part.substring(0, separator).trim().toLowerCase();
    final value = part.substring(separator + 1).trim();
    if (value.isEmpty || property.startsWith('mso-')) continue;
    if (property == 'font-family' || property == 'font-size') continue;
    if (property == 'color' ||
        property == 'background' ||
        property == 'background-color') {
      if (_dropsColor(value, isDark: isDark, background: property != 'color')) {
        continue;
      }
    }
    kept.add('$property: $value');
  }
  return kept.join('; ');
}

bool _dropsColor(String raw, {required bool isDark, required bool background}) {
  final color = _parseCssColor(raw);
  if (color == null) return true;
  final luminance = color.computeLuminance();
  if (background) {
    return isDark ? luminance > 0.62 : luminance < 0.18;
  }
  return isDark ? luminance < 0.45 : luminance > 0.82;
}

Color? _parseCssColor(String raw) {
  var value = raw.trim().toLowerCase();
  value = value.replaceAll('!important', '').trim();
  if (value.isEmpty ||
      value == 'transparent' ||
      value == 'inherit' ||
      value == 'initial' ||
      value == 'unset' ||
      value == 'currentcolor') {
    return null;
  }
  const named = <String, Color>{
    'black': Color(0xFF000000),
    'white': Color(0xFFFFFFFF),
    'windowtext': Color(0xFF000000),
    'window': Color(0xFFFFFFFF),
    'canvastext': Color(0xFF000000),
    'canvas': Color(0xFFFFFFFF),
    'gray': Color(0xFF808080),
    'grey': Color(0xFF808080),
    'silver': Color(0xFFC0C0C0),
    'red': Color(0xFFFF0000),
    'blue': Color(0xFF0000FF),
    'green': Color(0xFF008000),
    'yellow': Color(0xFFFFFF00),
    'navy': Color(0xFF000080),
  };
  final known = named[value];
  if (known != null) return known;

  if (value.startsWith('#')) {
    final hex = value.substring(1);
    if (hex.length == 3) {
      final expanded = hex.split('').map((char) => '$char$char').join();
      final parsed = int.tryParse(expanded, radix: 16);
      if (parsed == null) return null;
      return Color(0xFF000000 | parsed);
    }
    if (hex.length == 6 || hex.length == 8) {
      final parsed = int.tryParse(hex, radix: 16);
      if (parsed == null) return null;
      if (hex.length == 6) return Color(0xFF000000 | parsed);
      return Color(parsed);
    }
    return null;
  }

  final channels = RegExp(
    r'rgba?\(\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})',
  ).firstMatch(value);
  if (channels == null) return null;
  final red = int.parse(channels.group(1)!);
  final green = int.parse(channels.group(2)!);
  final blue = int.parse(channels.group(3)!);
  if (red > 255 || green > 255 || blue > 255) return null;
  return Color.fromARGB(255, red, green, blue);
}
