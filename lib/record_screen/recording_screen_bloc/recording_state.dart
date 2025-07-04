abstract class RecordingState {
  const RecordingState();
}

class RecordingInitial extends RecordingState {}
class RecordingInProgress extends RecordingState {}
class RecordingStopped extends RecordingState {}
class UploadInProgress extends RecordingState {
  final double progress;
  const UploadInProgress(this.progress);
}
class UploadSuccess extends RecordingState {}
class UploadFailure extends RecordingState {
  final String error;
  const UploadFailure(this.error);
}
