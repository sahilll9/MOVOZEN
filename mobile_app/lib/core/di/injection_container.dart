import 'package:get_it/get_it.dart';

import '../../data/datasources/permission_data_source.dart';
import '../../data/datasources/rtmp_data_source.dart';
import '../../data/repositories/camera_repository_impl.dart';
import '../../data/repositories/permission_repository_impl.dart';
import '../../data/repositories/streaming_repository_impl.dart';
import '../../domain/repositories/camera_repository.dart';
import '../../domain/repositories/permission_repository.dart';
import '../../domain/repositories/streaming_repository.dart';
import '../../domain/usecases/get_cameras_usecase.dart';
import '../../domain/usecases/request_permissions_usecase.dart';
import '../../domain/usecases/start_dual_stream_usecase.dart';
import '../../domain/usecases/start_stream_usecase.dart';
import '../../domain/usecases/stop_all_streams_usecase.dart';
import '../../domain/usecases/stop_stream_usecase.dart';
import '../../presentation/blocs/permission/permission_bloc.dart';
import '../../presentation/blocs/streaming/streaming_bloc.dart';

final sl = GetIt.instance;

/// Register all dependencies.
///
/// Call this once from `main()` before `runApp()`.
Future<void> initDependencies() async {
  // ── Data Sources ──────────────────────────────────────
  sl.registerLazySingleton<RtmpDataSource>(() => RtmpDataSource());
  sl.registerLazySingleton<PermissionDataSource>(
      () => PermissionDataSource());

  // ── Repositories ──────────────────────────────────────
  sl.registerLazySingleton<StreamingRepository>(
    () => StreamingRepositoryImpl(rtmpDataSource: sl()),
  );
  sl.registerLazySingleton<CameraRepository>(
    () => CameraRepositoryImpl(rtmpDataSource: sl()),
  );
  sl.registerLazySingleton<PermissionRepository>(
    () => PermissionRepositoryImpl(permissionDataSource: sl()),
  );

  // ── Use Cases ─────────────────────────────────────────
  sl.registerLazySingleton(() => StartStreamUseCase(sl()));
  sl.registerLazySingleton(() => StopStreamUseCase(sl()));
  sl.registerLazySingleton(() => StartDualStreamUseCase(sl()));
  sl.registerLazySingleton(() => StopAllStreamsUseCase(sl()));
  sl.registerLazySingleton(() => GetCamerasUseCase(sl()));
  sl.registerLazySingleton(() => RequestPermissionsUseCase(sl()));

  // ── BLoCs ─────────────────────────────────────────────
  sl.registerFactory(
    () => StreamingBloc(
      startStreamUseCase: sl(),
      stopStreamUseCase: sl(),
      stopAllStreamsUseCase: sl(),
      getCamerasUseCase: sl(),
      requestPermissionsUseCase: sl(),
      rtmpDataSource: sl(),
    ),
  );
  sl.registerFactory(
    () => PermissionBloc(
      requestPermissionsUseCase: sl(),
      permissionRepository: sl(),
    ),
  );
}
