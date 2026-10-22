import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../blocs/tasks/tasks_bloc.dart';
import '../models/app_section.dart';
import '../theme/ddt_icons.dart';
import '../theme/ddt_theme.dart';
import '../theme/ddt_typography.dart';
import 'ddt_icon.dart';
import 'ddt_section_sidebar.dart';
import 'ddt_side_panel_divider.dart';

/// Hides floating controls while a task sheet is open.
class DdtFloatingChromeController extends ChangeNotifier {
  int _depth = 0;
  bool _disposed = false;

  bool get visible => _depth == 0;

  void hold() {
    if (_disposed) return;
    _depth++;
    notifyListeners();
  }

  void release() {
    if (_disposed || _depth == 0) return;
    _depth--;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class DdtFloatingChrome extends InheritedNotifier<DdtFloatingChromeController> {
  const DdtFloatingChrome({
    super.key,
    required DdtFloatingChromeController controller,
    required super.child,
  }) : super(notifier: controller);

  static DdtFloatingChromeController? read(BuildContext context) {
    return context.getInheritedWidgetOfExactType<DdtFloatingChrome>()?.notifier;
  }
}

/// Viewport split between the desktop shell and the phone/tablet shell.
///
/// Wide windows keep the navigation rail and inline sidebars. Narrow windows
/// use a drawer and bottom sheets. The cutoff sits under a typical desktop
/// window so the web layout at laptop sizes stays the same.
abstract final class DdtAdaptive {
  static const double compactBreakpoint = DdtTheme.compactLayoutWidth;

  static bool isCompact(BuildContext context) =>
      DdtTheme.isCompactLayout(context);
}

class _SectionSheetRegistration {
  _SectionSheetRegistration({
    required this.title,
    required this.icon,
    required this.hostContext,
    required this.buildChild,
  });

  String title;
  FaIconData icon;
  BuildContext hostContext;
  WidgetBuilder buildChild;
}

/// Lets a section page hand its sidebar to the compact shell.
class DdtSectionSheetController extends ChangeNotifier {
  _SectionSheetRegistration? _current;
  String _title = '';
  FaIconData _icon = DdtIcons.sliders;
  bool _sheetOpen = false;
  int _sheetToken = 0;
  ModalRoute<void>? _sheetRoute;
  bool _disposed = false;

  bool get hasSheet => _current != null;
  String get title => _title;
  FaIconData get icon => _icon;

  void bind(_SectionSheetRegistration registration) {
    if (_disposed) return;
    final unchanged =
        identical(_current, registration) &&
        _title == registration.title &&
        _icon == registration.icon;
    _current = registration;
    _title = registration.title;
    _icon = registration.icon;
    if (unchanged) return;
    _notifySafely();
  }

  void unbind(_SectionSheetRegistration registration) {
    if (_disposed || !identical(_current, registration)) return;
    _current = null;
    _notifySafely();
    _closeSheet();
  }

  Future<void> open(BuildContext context) async {
    final registration = _current;
    if (_sheetOpen ||
        registration == null ||
        !registration.hostContext.mounted) {
      return;
    }

    final token = ++_sheetToken;
    _sheetOpen = true;

    TasksBloc? tasksBloc;
    try {
      tasksBloc = BlocProvider.of<TasksBloc>(
        registration.hostContext,
        listen: false,
      );
    } on ProviderNotFoundException {
      tasksBloc = null;
    }

    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      builder: (sheetContext) {
        _sheetRoute = ModalRoute.of(sheetContext);
        Widget body = registration.buildChild(sheetContext);
        final tasks = tasksBloc;
        if (tasks != null) {
          body = BlocProvider.value(value: tasks, child: body);
        }
        return _SectionBottomSheet(
          title: registration.title,
          icon: registration.icon,
          child: body,
        );
      },
    );

    if (token == _sheetToken) {
      _sheetOpen = false;
      _sheetRoute = null;
    }
  }

  void _closeSheet() {
    if (!_sheetOpen) return;
    _sheetOpen = false;
    _sheetToken++;
    final route = _sheetRoute;
    _sheetRoute = null;
    if (route == null || !route.isActive) return;
    final navigator = route.navigator;
    if (navigator == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!route.isCurrent || !navigator.mounted) return;
      navigator.pop();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notifySafely() {
    final phase = SchedulerBinding.instance.schedulerPhase;
    final duringBuild =
        phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks;
    if (!duringBuild) {
      notifyListeners();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || !hasListeners) return;
      notifyListeners();
    });
  }
}

/// Replaces the compact shell menu button with a back action.
class DdtCompactBarController extends ChangeNotifier {
  Object? _owner;
  String? _title;
  VoidCallback? _onBack;
  bool _disposed = false;

  bool get hasOverride => _owner != null;
  String? get title => _title;
  VoidCallback? get onBack => _onBack;

  void show({
    required Object owner,
    required String? title,
    required VoidCallback onBack,
  }) {
    if (_disposed) return;
    final unchanged = identical(_owner, owner) && _title == title;
    _owner = owner;
    _title = title;
    _onBack = onBack;
    if (unchanged) return;
    _notifySafely();
  }

  void hide(Object owner) {
    if (_disposed || !identical(_owner, owner)) return;
    _owner = null;
    _title = null;
    _onBack = null;
    _notifySafely();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notifySafely() {
    if (_disposed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || !hasListeners) return;
      notifyListeners();
    });
  }
}

class DdtCompactBarScope extends InheritedNotifier<DdtCompactBarController> {
  const DdtCompactBarScope({
    super.key,
    required DdtCompactBarController controller,
    required super.child,
  }) : super(notifier: controller);

  static DdtCompactBarController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<DdtCompactBarScope>()
        ?.notifier;
  }
}

class DdtSectionSheetScope
    extends InheritedNotifier<DdtSectionSheetController> {
  const DdtSectionSheetScope({
    super.key,
    required DdtSectionSheetController controller,
    required super.child,
  }) : super(notifier: controller);

  static DdtSectionSheetController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<DdtSectionSheetScope>()
        ?.notifier;
  }
}

/// Desktop: sidebar column plus [body]. Compact: [body] only, sidebar in a sheet.
class DdtAdaptiveSectionColumns extends StatefulWidget {
  const DdtAdaptiveSectionColumns({
    super.key,
    required this.sidebar,
    required this.body,
    required this.sheetTitle,
    this.sheetIcon = DdtIcons.sliders,
  });

  final Widget sidebar;
  final Widget body;
  final String sheetTitle;
  final FaIconData sheetIcon;

  @override
  State<DdtAdaptiveSectionColumns> createState() =>
      _DdtAdaptiveSectionColumnsState();
}

class _DdtAdaptiveSectionColumnsState extends State<DdtAdaptiveSectionColumns> {
  _SectionSheetRegistration? _registration;
  DdtSectionSheetController? _controller;

  void _publish(DdtSectionSheetController? controller) {
    if (!DdtAdaptive.isCompact(context) || controller == null) {
      final current = _controller;
      final registration = _registration;
      if (current != null && registration != null) {
        current.unbind(registration);
      }
      _controller = null;
      return;
    }

    final registration = _registration ??= _SectionSheetRegistration(
      title: widget.sheetTitle,
      icon: widget.sheetIcon,
      hostContext: context,
      buildChild: _buildSidebar,
    );
    registration
      ..title = widget.sheetTitle
      ..icon = widget.sheetIcon
      ..hostContext = context
      ..buildChild = _buildSidebar;

    if (!identical(_controller, controller)) {
      _controller?.unbind(registration);
      _controller = controller;
    }
    controller.bind(registration);
  }

  Widget _buildSidebar(BuildContext context) => widget.sidebar;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _publish(DdtSectionSheetScope.maybeOf(context));
  }

  @override
  void didUpdateWidget(DdtAdaptiveSectionColumns oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller == null) return;
    _publish(_controller);
  }

  @override
  void dispose() {
    final registration = _registration;
    if (registration != null) {
      _controller?.unbind(registration);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (DdtAdaptive.isCompact(context)) {
      return widget.body;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DdtSectionSidebarFrame(child: widget.sidebar),
        DdtSectionSidebar.afterScrollbarGapBox(),
        const DdtSidePanelDivider(),
        DdtSectionSidebar.dividerGap(),
        Expanded(child: widget.body),
      ],
    );
  }
}

class _SectionBottomSheet extends StatelessWidget {
  const _SectionBottomSheet({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final FaIconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxHeight = MediaQuery.sizeOf(context).height;
    final height = maxHeight * 0.88;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final surface = isDark ? DdtTheme.darkSurface : DdtTheme.lightSurface;

    final sheet = Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ClipRRect(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
          child: Material(
            color: surface,
            child: SizedBox(
              height: height,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: 8.h),
                  Center(
                    child: Container(
                      width: 36.w,
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: DdtTheme.borderStrong(context),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(16.w, 12.h, 8.w, 8.h),
                    child: Row(
                      children: [
                        DdtIcon(
                          icon,
                          size: 14.sp,
                          color: isDark
                              ? DdtTheme.accentColor
                              : DdtTheme.primaryColor,
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            title,
                            style: DdtTheme.style(
                              fontSize: DdtTypography.sectionTitleSize,
                              fontWeight: FontWeight.w700,
                              color: DdtTheme.textPrimary(context),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Закрыть',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: DdtIcon(
                            DdtIcons.close,
                            size: 16.sp,
                            color: DdtTheme.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: DdtTheme.borderSubtle(context)),
                  Expanded(child: child),
                  SizedBox(height: MediaQuery.paddingOf(context).bottom),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (!kIsWeb) return sheet;
    return PointerInterceptor(child: sheet);
  }
}

class DdtAppDrawer extends StatelessWidget {
  const DdtAppDrawer({
    super.key,
    required this.selectedSection,
    required this.onSectionSelected,
    required this.onDismiss,
  });

  final AppSection selectedSection;
  final ValueChanged<AppSection> onSectionSelected;

  static final List<AppSection> _primarySections = AppSection.values
      .where((section) => section != AppSection.settings)
      .toList();

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 12.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(8.w, 6.h, 8.w, 12.h),
                child: Text(
                  'Разделы',
                  style: DdtTheme.style(
                    fontSize: DdtTypography.panelTitleSize,
                    fontWeight: FontWeight.w700,
                    color: DdtTheme.textPrimary(context),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    for (final section in _primarySections) ...[
                      _DrawerDestination(
                        section: section,
                        isSelected: section == selectedSection,
                        onTap: () => _select(section),
                      ),
                      SizedBox(height: 8.h),
                    ],
                  ],
                ),
              ),
              _DrawerDestination(
                section: AppSection.settings,
                isSelected: selectedSection == AppSection.settings,
                onTap: () => _select(AppSection.settings),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _select(AppSection section) {
    onDismiss();
    onSectionSelected(section);
  }
}

/// Darkens and blurs the shell, then slides the transparent drawer in.
class DdtMobileDrawerLayer extends StatelessWidget {
  const DdtMobileDrawerLayer({
    super.key,
    required this.progress,
    required this.selectedSection,
    required this.onSectionSelected,
    required this.onDismiss,
  });

  final Animation<double> progress;
  final AppSection selectedSection;
  final ValueChanged<AppSection> onSectionSelected;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final width = math.min(MediaQuery.sizeOf(context).width * 0.82, 320.0);

    return AnimatedBuilder(
      animation: progress,
      builder: (context, child) {
        final t = progress.value;
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: onDismiss,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14 * t, sigmaY: 14 * t),
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.32 * t),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: width,
              child: Transform.translate(
                offset: Offset(-width * (1 - t), 0),
                child: child,
              ),
            ),
          ],
        );
      },
      child: DdtAppDrawer(
        selectedSection: selectedSection,
        onSectionSelected: onSectionSelected,
        onDismiss: onDismiss,
      ),
    );
  }
}

class _DrawerDestination extends StatelessWidget {
  const _DrawerDestination({
    required this.section,
    required this.isSelected,
    required this.onTap,
  });

  final AppSection section;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = isSelected
        ? (isDark ? DdtTheme.accentColor : DdtTheme.primaryColor)
        : DdtTheme.textPrimary(context);

    return DdtTheme.shellAppBarGlass(
      context: context,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Row(
          children: [
            DdtIcon(section.icon, size: 16.sp, color: foreground),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                section.label,
                style: DdtTheme.style(
                  fontSize: DdtTypography.bodySize,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: foreground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
