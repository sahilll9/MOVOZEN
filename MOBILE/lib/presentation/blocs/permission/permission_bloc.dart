import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/usecases/request_permissions_usecase.dart';
import '../../../domain/repositories/permission_repository.dart';
import 'permission_event.dart';
import 'permission_state.dart';

class PermissionBloc extends Bloc<PermissionEvent, PermissionState> {
  final RequestPermissionsUseCase requestPermissionsUseCase;
  final PermissionRepository permissionRepository;

  PermissionBloc({
    required this.requestPermissionsUseCase,
    required this.permissionRepository,
  }) : super(const PermissionInitial()) {
    on<RequestPermissionsEvent>(_onRequest);
    on<CheckPermissionsEvent>(_onCheck);
  }

  Future<void> _onRequest(
    RequestPermissionsEvent event,
    Emitter<PermissionState> emit,
  ) async {
    emit(const PermissionRequesting());
    final result = await requestPermissionsUseCase();
    result.fold(
      (failure) => emit(PermissionDenied(failure.message)),
      (granted) => granted
          ? emit(const PermissionGranted())
          : emit(const PermissionDenied('Permissions not granted')),
    );
  }

  Future<void> _onCheck(
    CheckPermissionsEvent event,
    Emitter<PermissionState> emit,
  ) async {
    final has = await permissionRepository.hasRequiredPermissions();
    if (has) {
      emit(const PermissionGranted());
    } else {
      emit(const PermissionDenied('Permissions not yet granted'));
    }
  }
}
