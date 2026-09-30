import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Font Awesome Classic icon (solid). Uses [FaIcon] for correct FA 7 rendering.
///
/// Unlike Material [Icon], [FaIcon] is not wrapped in a square box, so icons can
/// look off-center inside toolbars, circles, and checkboxes. [DdtIcon] applies a
/// slight global scale and centers glyphs in their layout slot.
class DdtIcon extends StatelessWidget {
  const DdtIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
    this.fitParent = false,
  });

  /// Slightly smaller than legacy Material/Cupertino icons (visual parity).
  static const double visualScale = 0.88;

  final FaIconData icon;
  final double? size;
  final Color? color;
  final String? semanticLabel;

  /// When true, centers the glyph inside the parent (e.g. circular avatars,
  /// toolbar chips). When false, reserves a square box of [layoutSize].
  final bool fitParent;

  double _layoutSize(BuildContext context) {
    return size ?? IconTheme.of(context).size ?? kDefaultFontSize;
  }

  double _glyphSize(BuildContext context) => _layoutSize(context) * visualScale;

  Widget _buildGlyph(BuildContext context) {
    return FaIcon(
      icon,
      size: _glyphSize(context),
      color: color,
      semanticLabel: semanticLabel,
    );
  }

  @override
  Widget build(BuildContext context) {
    final glyph = FittedBox(
      fit: BoxFit.scaleDown,
      child: _buildGlyph(context),
    );

    if (fitParent) {
      return Center(child: glyph);
    }

    final slot = _layoutSize(context);
    return SizedBox(
      width: slot,
      height: slot,
      child: Center(child: glyph),
    );
  }
}
