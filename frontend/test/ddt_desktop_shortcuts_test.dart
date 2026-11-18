import 'package:flutter_test/flutter_test.dart';
import 'package:ddt_frontend/widgets/ddt_desktop_shortcuts.dart';

void main() {
  DdtDesktopKeyEffect effect({
    String key = 'Enter',
    bool shift = false,
    bool meta = false,
    bool control = false,
    bool alt = false,
    bool composing = false,
    bool repeat = false,
    bool flutterHandled = false,
    bool fieldEnterBound = false,
    bool escapeBound = false,
    bool commandEnterBound = false,
  }) {
    return ddtDesktopKeyEffect(
      key: key,
      shift: shift,
      meta: meta,
      control: control,
      alt: alt,
      composing: composing,
      repeat: repeat,
      flutterHandled: flutterHandled,
      fieldEnterBound: fieldEnterBound,
      escapeBound: escapeBound,
      commandEnterBound: commandEnterBound,
    );
  }

  test('Enter submits a bound field and Shift+Enter does not', () {
    expect(effect(fieldEnterBound: true), DdtDesktopKeyEffect.fieldEnter);
    expect(
      effect(key: 'NumpadEnter', fieldEnterBound: true),
      DdtDesktopKeyEffect.fieldEnter,
    );
    expect(
      effect(shift: true, fieldEnterBound: true),
      DdtDesktopKeyEffect.ignore,
    );
    expect(effect(), DdtDesktopKeyEffect.ignore);
  });

  test('Cmd or Ctrl+Enter submits the page', () {
    expect(
      effect(meta: true, commandEnterBound: true, fieldEnterBound: true),
      DdtDesktopKeyEffect.commandEnter,
    );
    expect(
      effect(control: true, commandEnterBound: true),
      DdtDesktopKeyEffect.commandEnter,
    );
    expect(
      effect(meta: true, shift: true, commandEnterBound: true),
      DdtDesktopKeyEffect.ignore,
    );
  });

  test('Escape leaves the page unless Flutter already handled it', () {
    expect(effect(key: 'Escape', escapeBound: true), DdtDesktopKeyEffect.escape);
    expect(
      effect(key: 'Escape', escapeBound: true, flutterHandled: true),
      DdtDesktopKeyEffect.ignore,
    );
    expect(
      effect(key: 'Escape', escapeBound: true, meta: true),
      DdtDesktopKeyEffect.ignore,
    );
    expect(effect(key: 'Escape'), DdtDesktopKeyEffect.ignore);
  });

  test('IME composition and key repeat are ignored', () {
    expect(
      effect(fieldEnterBound: true, composing: true),
      DdtDesktopKeyEffect.ignore,
    );
    expect(
      effect(key: 'Escape', escapeBound: true, repeat: true),
      DdtDesktopKeyEffect.ignore,
    );
  });
}
