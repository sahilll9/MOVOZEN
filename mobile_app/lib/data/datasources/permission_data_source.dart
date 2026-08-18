import 'package:permission_handler/permission_handler.dart';

import '../../core/error/exceptions.dart';

/// Wraps the permission_handler plugin.
class PermissionDataSource {
  /// Request camera + microphone permissions.
  /// Throws [PermissionException] if denied.
  Future<bool> requestCameraAndMicPermissions() async {
    final cameraStatus = await Permission.camera.request();
    final micStatus = await Permission.microphone.request();

    if (cameraStatus.isGranted && micStatus.isGranted) {
      return true;
    }

    if (cameraStatus.isPermanentlyDenied || micStatus.isPermanentlyDenied) {
      throw const PermissionException(
        'Camera or microphone permission permanently denied. '
        'Please enable it in system settings.',
      );
    }

    throw const PermissionException(
      'Camera and microphone permissions are required for streaming.',
    );
  }

  /// Check if permissions are already granted.
  Future<bool> hasRequiredPermissions() async {
    final camera = await Permission.camera.isGranted;
    final mic = await Permission.microphone.isGranted;
    return camera && mic;
  }
}
