import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:rtmp_broadcaster/camera.dart' hide CameraException;

import '../../core/constants/app_constants.dart';
import '../../core/error/exceptions.dart';
import '../../domain/entities/camera_info.dart';
import '../../domain/entities/stream_status.dart';
import '../models/camera_info_model.dart';

/// Manages camera controllers and RTMP streaming using rtmp_broadcaster.
class RtmpDataSource {
  CameraController? _frontController;
  CameraController? _backController;

  List<CameraDescription> _cameras = [];

  final _frontStatusController = StreamController<StreamStatus>.broadcast();
  final _backStatusController = StreamController<StreamStatus>.broadcast();

  // Reconnect state
  int _frontReconnectAttempts = 0;
  int _backReconnectAttempts = 0;
  Timer? _frontReconnectTimer;
  Timer? _backReconnectTimer;

  /// Discover available cameras on this device.
  Future<List<CameraInfoModel>> getAvailableCameras() async {
    try {
      _cameras = await availableCameras();
      debugPrint(
          '[MoboSafe] Discovered ${_cameras.length} camera sensors: ${_cameras.map((c) => "${c.name} (facing: ${c.lensDirection})").join(", ")}');
      return _cameras.map((c) => CameraInfoModel.fromDescription(c)).toList();
    } catch (e) {
      debugPrint('[MoboSafe] Error enumerating cameras: $e');
      throw CameraException('Failed to enumerate cameras: $e');
    }
  }

  /// Resolve the precise CameraDescription for Front or Back
  CameraDescription _resolveCameraForFacing(CameraFacing facing) {
    if (_cameras.isEmpty) {
      throw CameraException('No cameras found on this device');
    }

    if (facing == CameraFacing.back) {
      // 1. Exact match on back lens direction
      final backCams = _cameras
          .where((c) => c.lensDirection == CameraLensDirection.back)
          .toList();
      if (backCams.isNotEmpty) return backCams.first;

      // 2. Camera ID '0' (standard Android primary rear camera)
      final zeroCams = _cameras.where((c) => c.name == '0').toList();
      if (zeroCams.isNotEmpty) return zeroCams.first;

      // 3. Any camera that is NOT front
      final notFront = _cameras
          .where((c) => c.lensDirection != CameraLensDirection.front)
          .toList();
      if (notFront.isNotEmpty) return notFront.first;

      // 4. Fallback to first camera
      return _cameras.first;
    } else {
      // 1. Exact match on front lens direction
      final frontCams = _cameras
          .where((c) => c.lensDirection == CameraLensDirection.front)
          .toList();
      if (frontCams.isNotEmpty) return frontCams.first;

      // 2. Camera ID '1' (standard Android selfie camera)
      final oneCams = _cameras.where((c) => c.name == '1').toList();
      if (oneCams.isNotEmpty) return oneCams.first;

      // 3. Any camera that is NOT back
      final notBack = _cameras
          .where((c) => c.lensDirection != CameraLensDirection.back)
          .toList();
      if (notBack.isNotEmpty) return notBack.last;

      // 4. If more than 1 camera, pick the second one
      if (_cameras.length > 1) return _cameras[1];

      return _cameras.last;
    }
  }

  /// Initialize a camera controller for the given [facing].
  Future<CameraController> _initController(CameraFacing facing) async {
    if (_cameras.isEmpty) {
      await getAvailableCameras();
    }

    final description = _resolveCameraForFacing(facing);

    debugPrint(
        '[MoboSafe] Initializing controller for ${facing.name.toUpperCase()} camera using sensor: ${description.name} (${description.lensDirection})');

    final controller = CameraController(
      description,
      ResolutionPreset.medium, // 720p 25fps optimal for RTMP
      enableAudio: true, // Audio enabled for both road & cabin
    );

    await controller.initialize();
    return controller;
  }

  /// Get the camera controller for preview widgets.
  CameraController? getController(CameraFacing facing) {
    return facing == CameraFacing.front ? _frontController : _backController;
  }

  /// Initialize camera preview before streaming starts
  Future<void> initializeCameraPreview(CameraFacing facing) async {
    // Release the other idle controller first to prevent hardware sensor collision
    final otherFacing =
        facing == CameraFacing.front ? CameraFacing.back : CameraFacing.front;
    final otherController =
        otherFacing == CameraFacing.front ? _frontController : _backController;

    if (otherController != null &&
        otherController.value.isStreamingVideoRtmp != true) {
      try {
        await otherController.dispose();
      } catch (_) {}
      if (otherFacing == CameraFacing.front) {
        _frontController = null;
      } else {
        _backController = null;
      }
    }

    final existing =
        facing == CameraFacing.front ? _frontController : _backController;
    if (existing != null && existing.value.isInitialized == true) {
      return;
    }

    try {
      final controller = await _initController(facing);
      if (facing == CameraFacing.front) {
        _frontController = controller;
      } else {
        _backController = controller;
      }
    } catch (e) {
      debugPrint(
          '[MoboSafe] Could not initialize preview for ${facing.name}: $e');
    }
  }

  /// Start streaming the given camera to the RTMP URL.
  Future<void> startStream(CameraFacing facing, String rtmpUrl) async {
    final statusController = facing == CameraFacing.front
        ? _frontStatusController
        : _backStatusController;

    try {
      statusController.add(StreamStatus.initializing);

      // Release other camera if not already streaming concurrently
      final otherFacing =
          facing == CameraFacing.front ? CameraFacing.back : CameraFacing.front;
      final otherController =
          otherFacing == CameraFacing.front ? _frontController : _backController;

      if (otherController != null &&
          otherController.value.isStreamingVideoRtmp != true) {
        try {
          await otherController.dispose();
        } catch (_) {}
        if (otherFacing == CameraFacing.front) {
          _frontController = null;
        } else {
          _backController = null;
        }
      }

      var controller =
          facing == CameraFacing.front ? _frontController : _backController;

      if (controller == null || controller.value.isInitialized != true) {
        controller = await _initController(facing);
        if (facing == CameraFacing.front) {
          _frontController = controller;
        } else {
          _backController = controller;
        }
      }

      statusController.add(StreamStatus.connecting);

      // Start RTMP streaming
      await controller.startVideoStreaming(
        rtmpUrl,
        bitrate: AppConstants.videoBitrateKbps * 1000,
      );

      // Reset reconnect state on success
      if (facing == CameraFacing.front) {
        _frontReconnectAttempts = 0;
      } else {
        _backReconnectAttempts = 0;
      }

      statusController.add(StreamStatus.live);
      debugPrint('[MoboSafe] ${facing.name.toUpperCase()} camera is now LIVE streaming to $rtmpUrl');
    } catch (e) {
      statusController.add(StreamStatus.error);
      debugPrint('[MoboSafe] Error starting ${facing.name} stream: $e');
      throw StreamException('Failed to start ${facing.name} stream: $e');
    }
  }

  /// Stop streaming for the given camera.
  Future<void> stopStream(CameraFacing facing) async {
    final statusController = facing == CameraFacing.front
        ? _frontStatusController
        : _backStatusController;

    try {
      final controller =
          facing == CameraFacing.front ? _frontController : _backController;

      if (controller != null) {
        try {
          if (controller.value.isStreamingVideoRtmp == true) {
            await controller.stopVideoStreaming();
          }
        } catch (_) {}
        await controller.dispose();
      }

      if (facing == CameraFacing.front) {
        _frontController = null;
        _frontReconnectTimer?.cancel();
        _frontReconnectAttempts = 0;
      } else {
        _backController = null;
        _backReconnectTimer?.cancel();
        _backReconnectAttempts = 0;
      }

      statusController.add(StreamStatus.stopped);
    } catch (e) {
      statusController.add(StreamStatus.error);
      throw StreamException('Failed to stop ${facing.name} stream: $e');
    }
  }

  /// Stop all streams.
  Future<void> stopAllStreams() async {
    await stopStream(CameraFacing.front);
    await stopStream(CameraFacing.back);
  }

  /// Attempt to reconnect with exponential backoff.
  void attemptReconnect(CameraFacing facing, String rtmpUrl) {
    final statusController = facing == CameraFacing.front
        ? _frontStatusController
        : _backStatusController;

    int attempts = facing == CameraFacing.front
        ? _frontReconnectAttempts
        : _backReconnectAttempts;

    if (attempts >= AppConstants.maxReconnectAttempts) {
      statusController.add(StreamStatus.error);
      debugPrint(
          '[MoboSafe] Max reconnect attempts reached for ${facing.name}');
      return;
    }

    statusController.add(StreamStatus.reconnecting);

    final delay = Duration(
      milliseconds: (AppConstants.initialReconnectDelay.inMilliseconds *
              (1 << attempts))
          .clamp(0, AppConstants.maxReconnectDelay.inMilliseconds),
    );

    debugPrint(
        '[MoboSafe] Reconnecting ${facing.name} in ${delay.inSeconds}s '
        '(attempt ${attempts + 1}/${AppConstants.maxReconnectAttempts})');

    final timer = Timer(delay, () async {
      try {
        final oldController =
            facing == CameraFacing.front ? _frontController : _backController;
        try {
          await oldController?.dispose();
        } catch (_) {}

        await startStream(facing, rtmpUrl);
      } catch (e) {
        if (facing == CameraFacing.front) {
          _frontReconnectAttempts++;
        } else {
          _backReconnectAttempts++;
        }
        attemptReconnect(facing, rtmpUrl);
      }
    });

    if (facing == CameraFacing.front) {
      _frontReconnectTimer = timer;
      _frontReconnectAttempts = attempts + 1;
    } else {
      _backReconnectTimer = timer;
      _backReconnectAttempts = attempts + 1;
    }
  }

  /// Stream of status updates for the given camera.
  Stream<StreamStatus> streamStatus(CameraFacing facing) {
    return facing == CameraFacing.front
        ? _frontStatusController.stream
        : _backStatusController.stream;
  }

  /// Clean up all resources.
  Future<void> dispose() async {
    _frontReconnectTimer?.cancel();
    _backReconnectTimer?.cancel();
    await _frontController?.dispose();
    await _backController?.dispose();
    await _frontStatusController.close();
    await _backStatusController.close();
  }
}
