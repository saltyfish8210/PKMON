import '../../data/model/study_models.dart';

typedef LocationSample = LocationSampleDto;

class LocationError {
  const LocationError({required this.code, required this.message});

  /// PERMISSION_DENIED | SERVICE_DISABLED | UNKNOWN | NOT_IMPLEMENTED
  final String code;
  final String message;
}
