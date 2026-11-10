import 'package:ddt_frontend/utils/ews_login.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('username is the local part of the email', () {
    expect(usernameFromEmail('ivan.petrov@mos.ru'), 'ivan.petrov');
    expect(usernameFromEmail('  user@example.com  '), 'user');
  });

  test('email without a local part is rejected', () {
    expect(usernameFromEmail(''), isNull);
    expect(usernameFromEmail('mos.ru'), isNull);
    expect(usernameFromEmail('@mos.ru'), isNull);
  });
}
