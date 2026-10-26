import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/ddt_theme.dart';
import '../theme/ddt_typography.dart';

Future<Uint8List?> showAvatarCropDialog(
  BuildContext context,
  Uint8List image,
) {
  return showDialog<Uint8List>(
    context: context,
    barrierDismissible: false,
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
    final width = 480.w.clamp(320.0, 520.0);

    return Dialog(
      backgroundColor: isDark ? DdtTheme.darkSurface : DdtTheme.lightSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: SizedBox(
        width: width,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 16.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Кадрирование',
                style: DdtTheme.style(
                  fontSize: DdtTypography.bodyLargeSize,
                  fontWeight: FontWeight.w600,
                  color: DdtTheme.taskCardTextPrimary(context),
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                'Перемещайте и масштабируйте фото. В профиль попадёт квадрат.',
                style: DdtTheme.style(
                  fontSize: DdtTypography.labelSize,
                  color: DdtTheme.taskCardTextSecondary(context),
                ),
              ),
              SizedBox(height: 14.h),
              ClipRRect(
                borderRadius: BorderRadius.circular(12.r),
                child: SizedBox(
                  height: 340.h.clamp(260.0, 420.0),
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
                SizedBox(height: 8.h),
                Text(
                  _error!,
                  style: DdtTheme.style(
                    fontSize: DdtTypography.labelSmallSize,
                    color: DdtTheme.dangerColor,
                  ),
                ),
              ],
              SizedBox(height: 14.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: Text(
                      'Отмена',
                      style: DdtTheme.style(
                        fontSize: DdtTypography.bodySize,
                        fontWeight: FontWeight.w500,
                        color: DdtTheme.taskCardTextSecondary(context),
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: DdtTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                    onPressed: _saving
                        ? null
                        : () {
                            setState(() {
                              _saving = true;
                              _error = null;
                            });
                            _controller.crop();
                          },
                    child: Text(
                      _saving ? 'Сохранение…' : 'Сохранить',
                      style: DdtTheme.style(
                        fontSize: DdtTypography.bodySize,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
