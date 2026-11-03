import '../models/colleague_calendar.dart';
import '../models/mail_message.dart';

/// Prefill for the fullscreen compose screen, including a reply.
class MailComposeDraft {
  const MailComposeDraft({
    this.to = const [],
    this.subject = '',
    this.body = '',
    this.recipientHint,
  });

  final List<CalendarPerson> to;
  final String subject;
  final String body;

  /// Sender name when the address is not known yet. The To field searches it.
  final String? recipientHint;

  factory MailComposeDraft.replyTo(MailMessage message) {
    final person = mailReplyRecipient(message);
    final hint = person == null ? message.sender?.trim() : null;
    return MailComposeDraft(
      to: [?person],
      subject: mailReplySubject(message.subject),
      body: mailReplyBody(message),
      recipientHint: hint == null || hint.isEmpty ? null : hint,
    );
  }
}

String mailReplySubject(String subject) {
  final trimmed = subject.trim();
  if (trimmed.isEmpty || trimmed == '(без темы)') return 'Re:';
  if (RegExp(
    r'^(re|fw|fwd|ответ)\s*:',
    caseSensitive: false,
  ).hasMatch(trimmed)) {
    return trimmed;
  }
  return 'Re: $trimmed';
}

/// Short quoted excerpt placed under the cursor in the reply body.
String mailReplyBody(MailMessage message) {
  final snippet = mailPlainSnippet(message);
  if (snippet.isEmpty) return '';
  final who = (message.sender ?? message.senderEmail ?? '').trim();
  final quoted = snippet.split('\n').map((line) => '> $line').join('\n');
  final header = who.isEmpty ? '' : '$who:\n';
  return '\n\n$header$quoted\n';
}

String mailPlainSnippet(MailMessage message, {int maxLength = 280}) {
  var text = message.preview.trim();
  if (text.isEmpty) {
    text = message.body?.trim() ?? '';
    if (message.bodyType == 'html') {
      text = text
          .replaceAll(
            RegExp(r'<style[\s\S]*?</style>', caseSensitive: false),
            ' ',
          )
          .replaceAll(
            RegExp(r'<script[\s\S]*?</script>', caseSensitive: false),
            ' ',
          )
          .replaceAll(RegExp(r'<[^>]+>'), ' ')
          .replaceAll('&nbsp;', ' ')
          .replaceAll('&amp;', '&')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>');
    }
  }
  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (text.length <= maxLength) return text;
  return '${text.substring(0, maxLength).trim()}…';
}

CalendarPerson? mailReplyRecipient(MailMessage message) {
  final email = _emailOf(message.senderEmail) ?? _emailOf(message.sender);
  if (email == null) return null;
  final name = (message.sender ?? '').trim();
  final display = name.isEmpty || _emailOf(name) != null ? email : name;
  return CalendarPerson(email: email, displayName: display);
}

final _emailPattern = RegExp(
  r'[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}',
  caseSensitive: false,
);

String? _emailOf(String? value) {
  if (value == null) return null;
  final match = _emailPattern.firstMatch(value.trim());
  final email = match?.group(0)?.toLowerCase();
  if (email == null || email.isEmpty) return null;
  return email;
}
