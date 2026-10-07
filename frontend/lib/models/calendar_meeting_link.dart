enum CalendarMeetingService { zoom, telemost, peregovorka, other }

class CalendarMeetingLink {
  const CalendarMeetingLink({required this.url, required this.service});

  final String url;
  final CalendarMeetingService service;

  String get asset {
    return switch (service) {
      CalendarMeetingService.zoom => 'assets/images/иконка_зум.png',
      CalendarMeetingService.telemost => 'assets/images/иконка_телемост.png',
      CalendarMeetingService.peregovorka => 'assets/images/иконка_дит.png',
      CalendarMeetingService.other => '',
    };
  }
}

final _urlPattern = RegExp(
  r'''https?:\/\/[^\s<>"')\]]+''',
  caseSensitive: false,
);

CalendarMeetingLink? meetingLinkFor({String? location, String? html}) {
  CalendarMeetingLink? locationFallback;
  for (final url in _urls(location)) {
    final service = meetingServiceFor(url);
    if (service != CalendarMeetingService.other) {
      return CalendarMeetingLink(url: url, service: service);
    }
    locationFallback ??= CalendarMeetingLink(url: url, service: service);
  }
  for (final url in _urls(html)) {
    final service = meetingServiceFor(url);
    if (service != CalendarMeetingService.other) {
      return CalendarMeetingLink(url: url, service: service);
    }
  }
  return locationFallback;
}

CalendarMeetingService meetingServiceFor(String url) {
  final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
  if (host == 'zoom.us' || host.endsWith('.zoom.us') || host.contains('zoom.us')) {
    return CalendarMeetingService.zoom;
  }
  if (host.contains('telemost.yandex')) return CalendarMeetingService.telemost;
  if (host.contains('peregovorka.mos.ru')) {
    return CalendarMeetingService.peregovorka;
  }
  return CalendarMeetingService.other;
}

String? locationWithoutLinks(String? location) {
  if (location == null) return null;
  final cleaned = location
      .replaceAll(_urlPattern, ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return cleaned.isEmpty ? null : cleaned;
}

Iterable<String> _urls(String? text) sync* {
  if (text == null || text.isEmpty) return;
  for (final match in _urlPattern.allMatches(text)) {
    var url = match.group(0) ?? '';
    while (url.endsWith('.') || url.endsWith(',') || url.endsWith(';')) {
      url = url.substring(0, url.length - 1);
    }
    if (url.isNotEmpty) yield url;
  }
}
