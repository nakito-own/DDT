import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';

import '../theme/ddt_theme.dart';
import '../theme/ddt_typography.dart';
import 'ddt_dialog.dart';

Future<Uint8List?> showAvatarCropDialog(
  BuildContext context,
  Uint8List image,
) {
  return showDdtDialog<Uint8List>(
    context: context,
    barrierDismissible: false,
    width: DdtDialog.wideWidth,
    height: DdtDialog.tallHeight,
    builder: (context) => _AvatarCropDialog(image: image),
  );
}

class _AvatarCropDialog extends StatefulWidget {
  const _AvatarCropDialog({required this.image});

  final Uint8List image;

  @override
  State<_AvatarCropDialog> createState() => _AvatarCropDialogState();
}

class _AvatarCropDialogState extends State<_AvatarCropDialog> {
  final _controller = CropController();
  bool _saving = false;
  String? _error;

  void _onCropped(CropResult result) {
    if (!mounted) return;
    switch (result) {
      case CropSuccess(:final croppedImage):
        Navigator.of(context).pop(croppedImage);
      case CropFailure():
        setState(() {
          _saving = false;
          _error = 'Не удалось обрезать фотографию';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DdtDialog(
      title: 'Кадрирование',
      message: 'Перемещайте и масштабируйте фото. В профиль попадёт квадрат.',
      expandBody: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(DdtTheme.borderRadius),
              child: Crop(
                image: widget.image,
                controller: _controller,
                aspectRatio: 1,
                interactive: true,
                fixCropRect: true,
                baseColor: isDark
                    ? const Color(0xFF12141A)
                    : const Color(0xFFE8EEF4),
                maskColor: Colors.black.withValues(alpha: 0.45),
                onCropped: _onCropped,
                progressIndicator: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: DdtTheme.style(
                fontSize: DdtTypography.labelSmallSize,
                color: DdtTheme.dangerColor,
              ),
            ),
          ],
        ],
      ),
      actions: [
        DdtDialogAction(
          label: 'Отмена',
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
        ),
        DdtDialogAction(
          label: _saving ? 'Сохранение…' : 'Сохранить',
          kind: DdtDialogActionKind.primary,
          onPressed: _saving
              ? null
              : () {
                  setState(() {
                    _saving = true;
                    _error = null;
                  });
                  _controller.crop();
                },
        ),
      ],
    );
  }
}
