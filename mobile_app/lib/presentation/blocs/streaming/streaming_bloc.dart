import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/datasources/rtmp_data_source.dart';
import '../../../domain/entities/camera_info.dart';
import '../../../domain/entities/stream_config.dart';
import '../../../domain/entities/stream_status.dart';
import '../../../domain/usecases/get_cameras_usecase.dart';
import '../../../domain/usecases/request_permissions_usecase.dart';
import '../../../domain/usecases/start_stream_usecase.dart';
import '../../../domain/usecases/stop_all_streams_usecase.dart';
import '../../../domain/usecases/stop_stream_usecase.dart';
import 'streaming_event.dart';
import 'streaming_state.dart';

/// BLoC that orchestrates the entire streaming lifecycle.
class StreamingBloc extends Bloc<StreamingEvent, StreamingState> {
  final StartStreamUseCase startStreamUseCase;
  final StopStreamUseCase stopStreamUseCase;
  final StopAllStreamsUseCase stopAllStreamsUseCase;
  final GetCamerasUseCase getCamerasUseCase;
  final RequestPermissionsUseCase requestPermissionsUseCase;
  final RtmpDataSource rtmpDataSource;

  Timer? _durationTimer;
  Timer? _autoCycleTimer;
  DateTime? _streamStartTime;
  StreamStatus _frontStatus = StreamStatus.idle;
  StreamStatus _backStatus = StreamStatus.idle;

  DashcamMode _currentMode = DashcamMode.backOnly;
  CameraFacing _activeFacing = CameraFacing.back;

  StreamSubscription<StreamStatus>? _frontStatusSub;
  StreamSubscription<StreamStatus>? _backStatusSub;

  StreamingBloc({
    required this.startStreamUseCase,
    required this.stopStreamUseCase,
    required this.stopAllStreamsUseCase,
    required this.getCamerasUseCase,
    required this.requestPermissionsUseCase,
    required this.rtmpDataSource,
  }) : super(const StreamingInitial()) {
    on<InitializeStreamingEvent>(_onInitialize);
    on<StartStreamingEvent>(_onStartStreaming);
    on<StopStreamingEvent>(_onStopStreaming);
    on<ChangeDashcamModeEvent>(_onChangeMode);
    on<SwitchCameraFacingEvent>(_onSwitchFacing);
    on<FrontStreamStatusChanged>(_onFrontStatusChanged);
    on<BackStreamStatusChanged>(_onBackStatusChanged);
    on<DurationTickEvent>(_onDurationTick);
    on<AutoCycleTickEvent>(_onAutoCycleTick);
  }

  Future<void> _onInitialize(
    InitializeStreamingEvent event,
    Emitter<StreamingState> emit,
  ) async {
    // Request permissions
    final permResult = await requestPermissionsUseCase();
    final permGranted = permResult.fold((_) => false, (granted) => granted);

    if (!permGranted) {
      emit(const StreamingError(
        message: 'Camera and microphone permissions are required.',
        canRetry: true,
      ));
      return;
    }

    // Enumerate cameras
    final camerasResult = await getCamerasUseCase();
    await camerasResult.fold(
      (failure) async => emit(StreamingError(message: failure.message)),
      (cameras) async {
        final hasFront = cameras.any((c) => c.facing == CameraFacing.front);
        final hasBack = cameras.any((c) => c.facing == CameraFacing.back);

        _activeFacing = hasBack ? CameraFacing.back : CameraFacing.front;
        _currentMode = hasBack ? DashcamMode.backOnly : DashcamMode.frontOnly;

        // Initialize preview for primary camera (Road / Back camera first)
        await rtmpDataSource.initializeCameraPreview(_activeFacing);

        emit(StreamingReady(
          frontCameraAvailable: hasFront,
          backCameraAvailable: hasBack,
          mode: _currentMode,
          activeFacing: _activeFacing,
        ));
      },
    );
  }

  Future<void> _onStartStreaming(
    StartStreamingEvent event,
    Emitter<StreamingState> emit,
  ) async {
    await WakelockPlus.enable();

    _streamStartTime = DateTime.now();
    _currentMode = event.mode;

    _subscribeToStatusStreams();

    if (_currentMode == DashcamMode.backOnly) {
      _activeFacing = CameraFacing.back;
      _backStatus = StreamStatus.initializing;
      _frontStatus = StreamStatus.idle;
    } else if (_currentMode == DashcamMode.frontOnly) {
      _activeFacing = CameraFacing.front;
      _frontStatus = StreamStatus.initializing;
      _backStatus = StreamStatus.idle;
    } else if (_currentMode == DashcamMode.autoCycle) {
      _activeFacing = CameraFacing.back;
      _backStatus = StreamStatus.initializing;
      _frontStatus = StreamStatus.idle;
    } else if (_currentMode == DashcamMode.dual) {
      _frontStatus = StreamStatus.initializing;
      _backStatus = StreamStatus.initializing;
    }

    emit(StreamingInProgress(
      frontStatus: _frontStatus,
      backStatus: _backStatus,
      elapsed: Duration.zero,
      mode: _currentMode,
      activeFacing: _activeFacing,
    ));

    await _startConfiguredStreams();

    // Start duration timer
    _durationTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => add(const DurationTickEvent()),
    );

    // If auto cycle mode, start cycle timer (switch every 8 seconds)
    if (_currentMode == DashcamMode.autoCycle) {
      _autoCycleTimer = Timer.periodic(
        const Duration(seconds: 8),
        (_) => add(const AutoCycleTickEvent()),
      );
    }
  }

  void _subscribeToStatusStreams() {
    _frontStatusSub?.cancel();
    _backStatusSub?.cancel();

    _frontStatusSub = rtmpDataSource.streamStatus(CameraFacing.front).listen(
      (status) {
        _frontStatus = status;
        add(FrontStreamStatusChanged(status.name));
      },
    );

    _backStatusSub = rtmpDataSource.streamStatus(CameraFacing.back).listen(
      (status) {
        _backStatus = status;
        add(BackStreamStatusChanged(status.name));
      },
    );
  }

  Future<void> _startConfiguredStreams() async {
    if (_currentMode == DashcamMode.backOnly ||
        (_currentMode == DashcamMode.autoCycle && _activeFacing == CameraFacing.back)) {
      final backConfig = StreamConfig(
        rtmpUrl: AppConstants.rtmpBackUrl,
        videoWidth: AppConstants.videoWidth,
        videoHeight: AppConstants.videoHeight,
        fps: AppConstants.videoFps,
        bitrateKbps: AppConstants.videoBitrateKbps,
        enableAudio: true,
      );
      await startStreamUseCase(backConfig);
    } else if (_currentMode == DashcamMode.frontOnly ||
        (_currentMode == DashcamMode.autoCycle && _activeFacing == CameraFacing.front)) {
      final frontConfig = StreamConfig(
        rtmpUrl: AppConstants.rtmpFrontUrl,
        videoWidth: AppConstants.videoWidth,
        videoHeight: AppConstants.videoHeight,
        fps: AppConstants.videoFps,
        bitrateKbps: AppConstants.videoBitrateKbps,
        enableAudio: true,
      );
      await startStreamUseCase(frontConfig);
    } else if (_currentMode == DashcamMode.dual) {
      // Try starting back camera (road) first
      final backConfig = StreamConfig(
        rtmpUrl: AppConstants.rtmpBackUrl,
        videoWidth: AppConstants.videoWidth,
        videoHeight: AppConstants.videoHeight,
        fps: AppConstants.videoFps,
        bitrateKbps: AppConstants.videoBitrateKbps,
        enableAudio: true,
      );
      final backResult = await startStreamUseCase(backConfig);

      // Try starting front camera concurrently
      final frontConfig = StreamConfig(
        rtmpUrl: AppConstants.rtmpFrontUrl,
        videoWidth: AppConstants.videoWidth,
        videoHeight: AppConstants.videoHeight,
        fps: AppConstants.videoFps,
        bitrateKbps: AppConstants.videoBitrateKbps,
        enableAudio: false,
      );
      final frontResult = await startStreamUseCase(frontConfig);

      // If front failed due to hardware lock, fallback smoothly to backOnly
      if (frontResult.isLeft() && backResult.isRight()) {
        _currentMode = DashcamMode.backOnly;
      }
    }
  }

  Future<void> _onChangeMode(
    ChangeDashcamModeEvent event,
    Emitter<StreamingState> emit,
  ) async {
    _currentMode = event.mode;
    _autoCycleTimer?.cancel();

    if (state is StreamingInProgress) {
      // If currently streaming, stop old streams and start in new mode
      await stopAllStreamsUseCase();
      
      if (_currentMode == DashcamMode.backOnly) {
        _activeFacing = CameraFacing.back;
      } else if (_currentMode == DashcamMode.frontOnly) {
        _activeFacing = CameraFacing.front;
      }

      await _startConfiguredStreams();

      if (_currentMode == DashcamMode.autoCycle) {
        _autoCycleTimer = Timer.periodic(
          const Duration(seconds: 8),
          (_) => add(const AutoCycleTickEvent()),
        );
      }

      emit((state as StreamingInProgress).copyWith(
        mode: _currentMode,
        activeFacing: _activeFacing,
        frontStatus: _frontStatus,
        backStatus: _backStatus,
      ));
    } else if (state is StreamingReady) {
      if (_currentMode == DashcamMode.backOnly) {
        _activeFacing = CameraFacing.back;
      } else if (_currentMode == DashcamMode.frontOnly) {
        _activeFacing = CameraFacing.front;
      }
      await rtmpDataSource.initializeCameraPreview(_activeFacing);

      emit((state as StreamingReady).copyWith(
        mode: _currentMode,
        activeFacing: _activeFacing,
      ));
    }
  }

  Future<void> _onSwitchFacing(
    SwitchCameraFacingEvent event,
    Emitter<StreamingState> emit,
  ) async {
    _activeFacing = event.targetFacing;
    _currentMode = _activeFacing == CameraFacing.back
        ? DashcamMode.backOnly
        : DashcamMode.frontOnly;
    _autoCycleTimer?.cancel();

    if (state is StreamingInProgress) {
      await stopAllStreamsUseCase();
      await _startConfiguredStreams();
      emit((state as StreamingInProgress).copyWith(
        mode: _currentMode,
        activeFacing: _activeFacing,
        frontStatus: _frontStatus,
        backStatus: _backStatus,
      ));
    } else if (state is StreamingReady) {
      await rtmpDataSource.initializeCameraPreview(_activeFacing);
      emit((state as StreamingReady).copyWith(
        mode: _currentMode,
        activeFacing: _activeFacing,
      ));
    }
  }

  Future<void> _onAutoCycleTick(
    AutoCycleTickEvent event,
    Emitter<StreamingState> emit,
  ) async {
    if (state is StreamingInProgress && _currentMode == DashcamMode.autoCycle) {
      // Toggle between back and front
      _activeFacing = _activeFacing == CameraFacing.back
          ? CameraFacing.front
          : CameraFacing.back;

      await stopAllStreamsUseCase();
      await _startConfiguredStreams();

      emit((state as StreamingInProgress).copyWith(
        activeFacing: _activeFacing,
        frontStatus: _frontStatus,
        backStatus: _backStatus,
      ));
    }
  }

  Future<void> _onStopStreaming(
    StopStreamingEvent event,
    Emitter<StreamingState> emit,
  ) async {
    _durationTimer?.cancel();
    _autoCycleTimer?.cancel();
    _frontStatusSub?.cancel();
    _backStatusSub?.cancel();

    final totalDuration = _streamStartTime != null
        ? DateTime.now().difference(_streamStartTime!)
        : Duration.zero;

    await stopAllStreamsUseCase();
    await WakelockPlus.disable();

    _frontStatus = StreamStatus.stopped;
    _backStatus = StreamStatus.stopped;

    emit(StreamingStopped(
      totalDuration: totalDuration,
      mode: _currentMode,
      activeFacing: _activeFacing,
    ));
  }

  void _onFrontStatusChanged(
    FrontStreamStatusChanged event,
    Emitter<StreamingState> emit,
  ) {
    if (state is StreamingInProgress) {
      final elapsed = _streamStartTime != null
          ? DateTime.now().difference(_streamStartTime!)
          : Duration.zero;

      emit((state as StreamingInProgress).copyWith(
        frontStatus: _frontStatus,
        backStatus: _backStatus,
        elapsed: elapsed,
      ));
    }
  }

  void _onBackStatusChanged(
    BackStreamStatusChanged event,
    Emitter<StreamingState> emit,
  ) {
    if (state is StreamingInProgress) {
      final elapsed = _streamStartTime != null
          ? DateTime.now().difference(_streamStartTime!)
          : Duration.zero;

      emit((state as StreamingInProgress).copyWith(
        frontStatus: _frontStatus,
        backStatus: _backStatus,
        elapsed: elapsed,
      ));
    }
  }

  void _onDurationTick(
    DurationTickEvent event,
    Emitter<StreamingState> emit,
  ) {
    if (state is StreamingInProgress) {
      final elapsed = _streamStartTime != null
          ? DateTime.now().difference(_streamStartTime!)
          : Duration.zero;

      emit((state as StreamingInProgress).copyWith(
        elapsed: elapsed,
      ));
    }
  }

  @override
  Future<void> close() {
    _durationTimer?.cancel();
    _autoCycleTimer?.cancel();
    _frontStatusSub?.cancel();
    _backStatusSub?.cancel();
    return super.close();
  }
}
