class MailHtmlDocument {
  MailHtmlDocument._();

  static const injectMarker = '<!-- ddt-email-viewer -->';

  static const headInjection = '''
<!-- ddt-email-viewer -->
<base target="_blank">
<meta name="referrer" content="no-referrer-when-downgrade">
<style id="ddt-email-safe-styles">
  html, body {
    margin: 0;
    padding: 0;
    background: #ffffff;
    height: 100%;
    overflow-y: auto;
    overflow-x: hidden;
    word-wrap: break-word;
    overflow-wrap: break-word;
    -webkit-overflow-scrolling: touch;
  }
  img {
    max-width: 100% !important;
    height: auto !important;
  }
  table {
    max-width: 100%;
  }
  pre {
    overflow-x: auto;
    max-width: 100%;
  }
  a[href] {
    cursor: pointer;
  }
</style>
<script id="ddt-email-link-handler">
(function () {
  function openLink(href) {
    if (!href || href.charAt(0) === '#') return;
    if (href.indexOf('mailto:') === 0) {
      window.location.href = href;
      return;
    }
    window.open(href, '_blank', 'noopener,noreferrer');
  }

  document.addEventListener('click', function (event) {
    var node = event.target;
    while (node && node.tagName !== 'A') node = node.parentElement;
    if (!node || !node.getAttribute('href')) return;
    event.preventDefault();
    event.stopPropagation();
    openLink(node.href);
  }, true);

  document.querySelectorAll('a[href]').forEach(function (anchor) {
    anchor.setAttribute('target', '_blank');
    anchor.setAttribute('rel', 'noopener noreferrer');
  });
})();
</script>
''';

  static String prepare(String rawHtml) {
    final trimmed = rawHtml.trim();
    if (trimmed.isEmpty) return trimmed;

    final lower = trimmed.toLowerCase();
    if (lower.startsWith('<!doctype') || lower.startsWith('<html')) {
      return _injectIntoDocument(trimmed);
    }
    return _wrapFragment(trimmed);
  }

  static String _injectIntoDocument(String html) {
    if (html.contains(injectMarker)) return html;

    final headOpen = RegExp(r'<head[^>]*>', caseSensitive: false);
    final headMatch = headOpen.firstMatch(html);
    if (headMatch != null) {
      return html.replaceRange(headMatch.end, headMatch.end, headInjection);
    }

    final headClose = RegExp(r'</head>', caseSensitive: false);
    if (headClose.hasMatch(html)) {
      return html.replaceFirst(headClose, '$headInjection</head>');
    }

    final bodyOpen = RegExp(r'<body[^>]*>', caseSensitive: false);
    if (bodyOpen.hasMatch(html)) {
      return html.replaceFirst(
        bodyOpen,
        '${bodyOpen.firstMatch(html)!.group(0)}$headInjection',
      );
    }

    return _wrapFragment(html);
  }

  static String _wrapFragment(String fragment) {
    return '''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
$headInjection
</head>
<body>$fragment</body>
</html>
''';
  }
}
