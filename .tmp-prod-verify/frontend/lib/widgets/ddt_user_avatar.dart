import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/auth/auth_bloc.dart';
import '../services/avatar_cache.dart';
import '../services/directory_users.dart';
import '../theme/ddt_icons.dart';
import '../theme/ddt_theme.dart';
import 'ddt_icon.dart';

/// User photo, or the person icon when the user has no avatar.
///
/// Small widgets request the 64px file, larger ones the 256px file.
/// Bytes stay in [AvatarImageCache] for the session.
class DdtUserAvatar extends StatefulWidget {
  const DdtUserAvatar({
    super.key,
    required this.size,
    this.userId,
    this.email,
    this.name,
    this.avatarVersion,
    this.versionIsKnown = false,
    this.borderRadius,
    this.showBorder = false,
  });

  final double size;
  final int? userId;
  final String? email;
  final String? name;

  /// Used when [versionIsKnown] is true, including `null` for "no photo".
  final int? avatarVersion;
  final bool versionIsKnown;
  final BorderRadius? borderRadius;
  final bool showBorder;

  @override
  State<DdtUserAvatar> createState() => _DdtUserAvatarState();
}

class _DdtUserAvatarState extends State<DdtUserAvatar> {
  Uint8List? _bytes;
  int? _shownVersion;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    directoryUsersRevision.addListener(_onDirectory);
    _sync();
  }

  @override
  void didUpdateWidget(DdtUserAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId ||
        oldWidget.email != widget.email ||
        oldWidget.name != widget.name ||
        oldWidget.avatarVersion != widget.avatarVersion ||
        oldWidget.versionIsKnown != widget.versionIsKnown) {
      _sync();
    }
  }

  @override
  void dispose() {
    directoryUsersRevision.removeListener(_onDirectory);
    super.dispose();
  }

  void _onDirectory() {
    if (!widget.versionIsKnown) _sync();
  }

  Future<void> _sync() async {
    final request = ++_request;
    final resolved = await _resolve();
    if (!mounted || request != _request) return;
    if (resolved == null || resolved.version == null) {
      setState(() {
        _bytes = null;
        _shownVersion = null;
      });
      return;
    }
    if (_shownVersion == resolved.version && _bytes != null) return;

    final pixelSize = _pixelSize(context, widget.size);
    final bytes = await AvatarImageCache.instance.load(
      userId: resolved.id,
      version: resolved.version!,
      pixelSize: pixelSize,
    );
    if (!mounted || request != _request) return;
    setState(() {
      _bytes = bytes;
      _shownVersion = bytes == null ? null : resolved.version;
    });
  }

  Future<({int id, int? version})?> _resolve() async {
    if (widget.versionIsKnown) {
      final id = widget.userId;
      if (id == null) return null;
      return (id: id, version: widget.avatarVersion);
    }

    final email = widget.email?.trim();
    final name = widget.name?.trim();
    if (widget.userId == null &&
        (email == null || email.isEmpty) &&
        (name == null || name.isEmpty || name == '—')) {
      return null;
    }

    await loadDirectoryUsers();
    if (!mounted) return null;
    final user = directoryUserMatching(
      id: widget.userId,
      email: widget.email,
      name: widget.name,
    );
    if (user == null) return null;

    final auth = context.read<AuthBloc>().state;
    if (auth is AuthAuthenticated &&
        auth.user.id == user.id &&
        auth.user.avatarVersion != null) {
      return (id: user.id, version: auth.user.avatarVersion);
    }
    return (id: user.id, version: user.avatarVersion);
  }

  int _pixelSize(BuildContext context, double size) {
    final pixels = size * MediaQuery.devicePixelRatioOf(context);
    return pixels <= 80 ? 64 : 256;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = widget.borderRadius;
    final shape = radius == null ? BoxShape.circle : BoxShape.rectangle;
    final accent = isDark ? DdtTheme.accentColor : DdtTheme.primaryColor;

    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) {
        final previousVersion = previous is AuthAuthenticated
            ? previous.user.avatarVersion
            : null;
        final currentVersion = current is AuthAuthenticated
            ? current.user.avatarVersion
            : null;
        final previousId = previous is AuthAuthenticated
            ? previous.user.id
            : null;
        final currentId = current is AuthAuthenticated ? current.user.id : null;
        return previousVersion != currentVersion || previousId != currentId;
      },
      listener: (context, state) {
        if (!widget.versionIsKnown) _sync();
      },
      child: Container(
        width: widget.size,
        height: widget.size,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          shape: shape,
          borderRadius: radius,
          color: DdtTheme.primaryColor.withValues(alpha: isDark ? 0.22 : 0.12),
          border: widget.showBorder
              ? Border.all(
                  color: DdtTheme.primaryColor.withValues(
                    alpha: isDark ? 0.36 : 0.24,
                  ),
                )
              : null,
        ),
        child: _bytes == null
            ? Center(
                child: DdtIcon(
                  DdtIcons.user,
                  size: widget.size * 0.46,
                  color: accent,
                  fitParent: true,
                ),
              )
            : Image.memory(
                _bytes!,
                width: widget.size,
                height: widget.size,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                filterQuality: FilterQuality.medium,
              ),
      ),
    );
  }
}
