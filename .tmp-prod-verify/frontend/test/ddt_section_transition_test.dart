import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ddt_frontend/models/app_section.dart';
import 'package:ddt_frontend/widgets/ddt_section_transition.dart';

void main() {
  testWidgets('section change fades the incoming page only', (tester) async {
    final key = GlobalKey<_HostState>();
    await tester.pumpWidget(_Host(key: key));

    expect(_opacity(tester), 1);
    expect(find.text('Задачи'), findsOneWidget);

    key.currentState!.show(AppSection.mail, 'Почта');
    await tester.pump();

    expect(find.text('Задачи'), findsNothing);
    expect(find.text('Почта'), findsOneWidget);
    expect(_opacity(tester), 0);

    await tester.pump(const Duration(milliseconds: 110));
    final mid = _opacity(tester);
    expect(mid, greaterThan(0));
    expect(mid, lessThan(1));

    await tester.pumpAndSettle();
    expect(_opacity(tester), 1);
  });

  testWidgets('route changes inside one section are not animated', (
    tester,
  ) async {
    final key = GlobalKey<_HostState>();
    await tester.pumpWidget(_Host(key: key));
    await tester.pumpAndSettle();

    key.currentState!.show(AppSection.tasks, 'Список');
    await tester.pump();

    expect(find.text('Список'), findsOneWidget);
    expect(_opacity(tester), 1);
  });

  testWidgets('reduced motion skips the section transition', (tester) async {
    final key = GlobalKey<_HostState>();
    await tester.pumpWidget(_Host(key: key, disableAnimations: true));

    key.currentState!.show(AppSection.calendar, 'Календарь');
    await tester.pump();

    expect(find.text('Календарь'), findsOneWidget);
    expect(_opacity(tester), 1);
  });
}

double _opacity(WidgetTester tester) {
  return tester.widget<Opacity>(find.byType(Opacity)).opacity;
}

class _Host extends StatefulWidget {
  const _Host({super.key, this.disableAnimations = false});

  final bool disableAnimations;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  AppSection _section = AppSection.tasks;
  String _label = 'Задачи';

  void show(AppSection section, String label) {
    setState(() {
      _section = section;
      _label = label;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: widget.disableAnimations),
        child: Scaffold(
          body: DdtSectionTransition(section: _section, child: Text(_label)),
        ),
      ),
    );
  }
}
