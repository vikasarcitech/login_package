
abstract class RecordingState {}

class RecordingInitial extends RecordingState {}

class RecordingInProgress extends RecordingState {}

class RecordingStopped extends RecordingState {}
class RecordingError extends RecordingState {
  final String message;

  RecordingError(this.message);
}
class PermissionsDenied extends RecordingState {}