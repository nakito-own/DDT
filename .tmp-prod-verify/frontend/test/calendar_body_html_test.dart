import 'package:ddt_frontend/utils/calendar_body_html.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dark theme drops black agenda text and a white plate', () {
    const html = '''
<style>p { color: black; }</style>
<p style="font-family:Calibri;font-size:11pt;color:black;background:#ffffff;font-weight:bold">
  <font color="black">Повестка</font>
</p>
<span style="color:#8ec8ff">ссылка</span>
''';

    final adapted = adaptCalendarBodyHtml(html, isDark: true);

    expect(adapted, isNot(contains('<style')));
    expect(adapted.toLowerCase(), isNot(contains('color:black')));
    expect(adapted.toLowerCase(), isNot(contains('color="black"')));
    expect(adapted.toLowerCase(), isNot(contains('background:#ffffff')));
    expect(adapted, contains('font-weight: bold'));
    expect(adapted, contains('#8ec8ff'));
    expect(adapted, contains('Повестка'));
  });

  test('light theme drops white text and keeps black', () {
    const html =
        '<span style="color:white">скрыто</span><span style="color:#111111">видно</span>';

    final adapted = adaptCalendarBodyHtml(html, isDark: false);

    expect(adapted.toLowerCase(), isNot(contains('color:white')));
    expect(adapted, contains('color:#111111'));
  });
}
