import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Large start/stop button with animated state transitions.
class ControlPanelWidget extends StatelessWidget {
  final bool isStreaming;
  final bool isLoading;
  final VoidCallback onStart;
  final VoidCallback onStop;

  const ControlPanelWidget({
    super.key,
    required this.isStreaming,
    required this.isLoading,
    required this.onStart,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : (isStreaming ? onStop : onStart),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isStreaming
              ? AppTheme.liveRed.withValues(alpha: 0.2)
              : AppTheme.primary.withValues(alpha: 0.2),
          border: Border.all(
            color: isStreaming ? AppTheme.liveRed : AppTheme.primary,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: (isStreaming ? AppTheme.liveRed : AppTheme.primary)
                  .withValues(alpha: 0.3),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Center(
          child: isLoading
              ? SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color:
                        isStreaming ? AppTheme.liveRed : AppTheme.primary,
                  ),
                )
              : AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: isStreaming
                      ? Container(
                          key: const ValueKey('stop'),
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: AppTheme.liveRed,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        )
                      : Icon(
                          Icons.play_arrow_rounded,
                          key: const ValueKey('play'),
                          color: AppTheme.primary,
                          size: 40,
                        ),
                ),
        ),
      ),
    );
  }
}
