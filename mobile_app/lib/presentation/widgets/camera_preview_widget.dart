import 'package:flutter/material.dart';
import 'package:rtmp_broadcaster/camera.dart';

import '../../core/theme/app_theme.dart';

/// Displays a live camera preview in a styled card.
class CameraPreviewWidget extends StatelessWidget {
  final CameraController? controller;
  final String label;
  final bool isActive;

  const CameraPreviewWidget({
    super.key,
    required this.controller,
    required this.label,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive
              ? AppTheme.primary
              : AppTheme.surfaceVariant,
          width: isActive ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Camera preview or placeholder
          if (controller != null && controller!.value.isInitialized == true)
            LayoutBuilder(
              builder: (context, constraints) {
                final previewSize = controller!.value.previewSize;
                final isLandscape =
                    MediaQuery.of(context).orientation == Orientation.landscape;
                final double w = previewSize != null
                    ? (isLandscape ? previewSize.width : previewSize.height)
                    : 1280;
                final double h = previewSize != null
                    ? (isLandscape ? previewSize.height : previewSize.width)
                    : 720;

                return SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: w,
                      height: h,
                      child: CameraPreview(controller!),
                    ),
                  ),
                );
              },
            )
          else
            Container(
              color: AppTheme.surfaceVariant,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.videocam_off_outlined,
                      color: AppTheme.textSecondary.withValues(alpha: 0.5),
                      size: 32,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      label,
                      style: TextStyle(
                        color: AppTheme.textSecondary.withValues(alpha: 0.6),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tap to activate',
                      style: TextStyle(
                        color: AppTheme.textSecondary.withValues(alpha: 0.4),
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Label overlay
          Positioned(
            bottom: 6,
            left: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          // Active indicator
          if (isActive)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppTheme.liveRed,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.liveRed,
                      blurRadius: 6,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
