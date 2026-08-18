import 'package:flutter/material.dart';

import '../../domain/entities/stream_status.dart';
import '../../core/theme/app_theme.dart';

/// Animated pulsing status indicator for a single stream.
class StreamStatusIndicator extends StatefulWidget {
  final StreamStatus status;
  final String label;

  const StreamStatusIndicator({
    super.key,
    required this.status,
    required this.label,
  });

  @override
  State<StreamStatusIndicator> createState() => _StreamStatusIndicatorState();
}

class _StreamStatusIndicatorState extends State<StreamStatusIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(covariant StreamStatusIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateAnimation();
  }

  void _updateAnimation() {
    if (widget.status == StreamStatus.live) {
      _pulseController.repeat(reverse: true);
    } else if (widget.status == StreamStatus.reconnecting ||
        widget.status == StreamStatus.connecting) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _pulseController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color get _statusColor {
    switch (widget.status) {
      case StreamStatus.live:
        return AppTheme.liveRed;
      case StreamStatus.connecting:
      case StreamStatus.initializing:
        return AppTheme.connectingAmber;
      case StreamStatus.reconnecting:
        return AppTheme.reconnectBlue;
      case StreamStatus.error:
        return AppTheme.errorRed;
      case StreamStatus.stopped:
      case StreamStatus.idle:
        return AppTheme.textSecondary;
    }
  }

  String get _statusText {
    switch (widget.status) {
      case StreamStatus.live:
        return 'LIVE';
      case StreamStatus.connecting:
        return 'CONNECTING';
      case StreamStatus.initializing:
        return 'INITIALIZING';
      case StreamStatus.reconnecting:
        return 'RECONNECTING';
      case StreamStatus.error:
        return 'ERROR';
      case StreamStatus.stopped:
        return 'STOPPED';
      case StreamStatus.idle:
        return 'IDLE';
    }
  }

  @override
  Widget build(BuildContext context) {
    _updateAnimation();

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _statusColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _statusColor.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Opacity(
                opacity: _pulseAnimation.value,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _statusColor,
                    shape: BoxShape.circle,
                    boxShadow: widget.status == StreamStatus.live
                        ? [
                            BoxShadow(
                              color: _statusColor.withValues(alpha: 0.6),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${widget.label} · $_statusText',
                style: TextStyle(
                  color: _statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
