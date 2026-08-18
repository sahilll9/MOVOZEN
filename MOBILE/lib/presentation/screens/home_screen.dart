import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/constants/app_constants.dart';
import '../../core/di/injection_container.dart';
import '../../core/theme/app_theme.dart';
import '../../data/datasources/rtmp_data_source.dart';
import '../../domain/entities/camera_info.dart';
import '../../domain/entities/stream_status.dart';
import '../blocs/streaming/streaming_bloc.dart';
import '../blocs/streaming/streaming_event.dart';
import '../blocs/streaming/streaming_state.dart';
import '../widgets/camera_preview_widget.dart';
import '../widgets/control_panel_widget.dart';
import '../widgets/stream_stats_widget.dart';
import '../widgets/stream_status_indicator.dart';

/// Main dashcam screen.
/// Responsive layout supporting both landscape and portrait dashcam modes.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize streaming and camera previews on first load
    context.read<StreamingBloc>().add(const InitializeStreamingEvent());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Keep streaming alive in background via foreground service
    super.didChangeAppLifecycleState(state);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: BlocConsumer<StreamingBloc, StreamingState>(
          listener: (context, state) {
            if (state is StreamingError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: AppTheme.errorRed,
                  behavior: SnackBarBehavior.floating,
                  action: state.canRetry
                      ? SnackBarAction(
                          label: 'RETRY',
                          textColor: Colors.white,
                          onPressed: () {
                            context
                                .read<StreamingBloc>()
                                .add(const InitializeStreamingEvent());
                          },
                        )
                      : null,
                ),
              );
            }
          },
          builder: (context, state) {
            return OrientationBuilder(
              builder: (context, orientation) {
                if (orientation == Orientation.landscape) {
                  return _buildLandscapeLayout(state);
                } else {
                  return _buildPortraitLayout(state);
                }
              },
            );
          },
        ),
      ),
    );
  }

  /// Landscape layout: Previews take majority of screen, control panel on the right
  Widget _buildLandscapeLayout(StreamingState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          // ── Left: Mode selector + Camera Previews + Status Row ────────
          Expanded(
            flex: 7,
            child: Column(
              children: [
                _buildModeSelector(state),
                const SizedBox(height: 4),
                Expanded(
                  child: _buildCameraPreviews(state),
                ),
                const SizedBox(height: 4),
                _buildStatusRow(state),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // ── Right: Sidebar HUD & Controls ─────────────
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.surfaceVariant,
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildHeader(state, compact: true),
                  
                  // Stats timer
                  if (state is StreamingInProgress)
                    StreamStatsWidget(elapsed: state.elapsed)
                  else if (state is StreamingStopped)
                    StreamStatsWidget(elapsed: state.totalDuration)
                  else
                    const StreamStatsWidget(elapsed: Duration.zero),

                  // Start/Stop control button
                  _buildControlButton(state),

                  // Roll info
                  _buildRollInfo(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Portrait layout: Previews at top, controls at bottom
  Widget _buildPortraitLayout(StreamingState state) {
    return Column(
      children: [
        _buildHeader(state, compact: false),
        _buildModeSelector(state),
        const SizedBox(height: 6),
        Expanded(
          flex: 5,
          child: _buildCameraPreviews(state),
        ),
        const SizedBox(height: 6),
        _buildStatusRow(state),
        const SizedBox(height: 6),
        Expanded(
          flex: 4,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (state is StreamingInProgress)
                StreamStatsWidget(elapsed: state.elapsed)
              else if (state is StreamingStopped)
                StreamStatsWidget(elapsed: state.totalDuration)
              else
                const StreamStatsWidget(elapsed: Duration.zero),
              _buildControlButton(state),
              _buildRollInfo(),
            ],
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _buildModeSelector(StreamingState state) {
    DashcamMode currentMode = DashcamMode.backOnly;
    if (state is StreamingReady) {
      currentMode = state.mode;
    } else if (state is StreamingInProgress) {
      currentMode = state.mode;
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildModeChip(
            icon: Icons.directions_car,
            label: 'ROAD (BACK)',
            isSelected: currentMode == DashcamMode.backOnly,
            onTap: () {
              context
                  .read<StreamingBloc>()
                  .add(const ChangeDashcamModeEvent(DashcamMode.backOnly));
            },
          ),
          const SizedBox(width: 6),
          _buildModeChip(
            icon: Icons.person,
            label: 'CABIN (FRONT)',
            isSelected: currentMode == DashcamMode.frontOnly,
            onTap: () {
              context
                  .read<StreamingBloc>()
                  .add(const ChangeDashcamModeEvent(DashcamMode.frontOnly));
            },
          ),
          const SizedBox(width: 6),
          _buildModeChip(
            icon: Icons.sync,
            label: 'AUTO-CYCLE',
            isSelected: currentMode == DashcamMode.autoCycle,
            onTap: () {
              context
                  .read<StreamingBloc>()
                  .add(const ChangeDashcamModeEvent(DashcamMode.autoCycle));
            },
          ),
          const SizedBox(width: 6),
          _buildModeChip(
            icon: Icons.burst_mode,
            label: 'DUAL',
            isSelected: currentMode == DashcamMode.dual,
            onTap: () {
              context
                  .read<StreamingBloc>()
                  .add(const ChangeDashcamModeEvent(DashcamMode.dual));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildModeChip({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withValues(alpha: 0.25)
              : AppTheme.surfaceVariant.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : AppTheme.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(StreamingState state, {required bool compact}) {
    final bool isLive = state is StreamingInProgress && state.isAnyLive;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 4 : 16,
        vertical: compact ? 2 : 6,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // REC indicator
          if (isLive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.liveRed.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.liveRed.withValues(alpha: 0.5),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.fiber_manual_record,
                      color: AppTheme.liveRed, size: 8),
                  SizedBox(width: 4),
                  Text(
                    'REC',
                    style: TextStyle(
                      color: AppTheme.liveRed,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            )
          else
            const SizedBox(width: 40),

          // Title
          const Text(
            'MOBOSAFE',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),

          // Audio badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isLive ? Icons.mic : Icons.mic_off_outlined,
                  color: isLive
                      ? AppTheme.successGreen
                      : AppTheme.textSecondary,
                  size: 12,
                ),
                const SizedBox(width: 4),
                Text(
                  'MIC',
                  style: TextStyle(
                    color: isLive
                        ? AppTheme.successGreen
                        : AppTheme.textSecondary,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPreviews(StreamingState state) {
    final rtmpDataSource = sl<RtmpDataSource>();
    final frontController = rtmpDataSource.getController(CameraFacing.front);
    final backController = rtmpDataSource.getController(CameraFacing.back);

    final bool isFrontLive = state is StreamingInProgress &&
        state.frontStatus == StreamStatus.live;
    final bool isBackLive = state is StreamingInProgress &&
        state.backStatus == StreamStatus.live;

    CameraFacing activeFacing = CameraFacing.back;
    if (state is StreamingReady) {
      activeFacing = state.activeFacing;
    } else if (state is StreamingInProgress) {
      activeFacing = state.activeFacing;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          // ── Road (Back) Camera ─────────────────
          Expanded(
            child: GestureDetector(
              onTap: () {
                context
                    .read<StreamingBloc>()
                    .add(const SwitchCameraFacingEvent(CameraFacing.back));
              },
              child: Stack(
                children: [
                  CameraPreviewWidget(
                    controller: backController,
                    label: '🚗 ROAD · BACK',
                    isActive: isBackLive || (activeFacing == CameraFacing.back && backController != null),
                  ),
                  if (activeFacing == CameraFacing.back)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'ACTIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          // ── Cabin (Front) Camera ─────────────────
          Expanded(
            child: GestureDetector(
              onTap: () {
                context
                    .read<StreamingBloc>()
                    .add(const SwitchCameraFacingEvent(CameraFacing.front));
              },
              child: Stack(
                children: [
                  CameraPreviewWidget(
                    controller: frontController,
                    label: '👤 CABIN · FRONT',
                    isActive: isFrontLive || (activeFacing == CameraFacing.front && frontController != null),
                  ),
                  if (activeFacing == CameraFacing.front)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'ACTIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(StreamingState state) {
    StreamStatus frontStatus = StreamStatus.idle;
    StreamStatus backStatus = StreamStatus.idle;

    if (state is StreamingInProgress) {
      frontStatus = state.frontStatus;
      backStatus = state.backStatus;
    } else if (state is StreamingStopped) {
      frontStatus = StreamStatus.stopped;
      backStatus = StreamStatus.stopped;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        StreamStatusIndicator(
          status: backStatus,
          label: 'ROAD',
        ),
        const SizedBox(width: 8),
        StreamStatusIndicator(
          status: frontStatus,
          label: 'CABIN',
        ),
      ],
    );
  }

  Widget _buildControlButton(StreamingState state) {
    final bool isStreaming = state is StreamingInProgress;
    final bool isLoading = state is StreamingInProgress &&
        (state.frontStatus == StreamStatus.initializing ||
            state.frontStatus == StreamStatus.connecting ||
            state.backStatus == StreamStatus.initializing ||
            state.backStatus == StreamStatus.connecting);

    DashcamMode currentMode = DashcamMode.backOnly;
    if (state is StreamingReady) {
      currentMode = state.mode;
    } else if (state is StreamingInProgress) {
      currentMode = state.mode;
    }

    return ControlPanelWidget(
      isStreaming: isStreaming,
      isLoading: isLoading,
      onStart: () {
        context
            .read<StreamingBloc>()
            .add(StartStreamingEvent(mode: currentMode));
      },
      onStop: () {
        context.read<StreamingBloc>().add(const StopStreamingEvent());
      },
    );
  }

  Widget _buildRollInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'ROLL: ${AppConstants.rollNumber.toUpperCase()}',
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 9,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
