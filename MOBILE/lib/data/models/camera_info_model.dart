import 'package:rtmp_broadcaster/camera.dart';

import '../../domain/entities/camera_info.dart';

/// Data-layer model that maps the plugin's [CameraDescription]
/// to the domain [CameraInfo] entity.
class CameraInfoModel extends CameraInfo {
  final CameraDescription cameraDescription;

  const CameraInfoModel({
    required this.cameraDescription,
    required super.facing,
    required super.isAvailable,
  });

  factory CameraInfoModel.fromDescription(CameraDescription desc) {
    return CameraInfoModel(
      cameraDescription: desc,
      facing: desc.lensDirection == CameraLensDirection.front
          ? CameraFacing.front
          : CameraFacing.back,
      isAvailable: true,
    );
  }
}
