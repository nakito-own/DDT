import 'dart:io';

Future<String> openSvgExport(String svg) async {
  final file = File('${Directory.systemTemp.path}/nodeline_export.svg');
  await file.writeAsString(svg);

  if (Platform.isMacOS) {
    await Process.run('open', [file.path]);
  } else if (Platform.isLinux) {
    await Process.run('xdg-open', [file.path]);
  } else if (Platform.isWindows) {
    await Process.run('cmd', ['/c', 'start', '', file.path]);
  }
  return 'SVG opened in viewer';
}
