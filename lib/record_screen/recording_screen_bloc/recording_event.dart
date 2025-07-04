abstract class RecordingEvent {
  const RecordingEvent();
}

class StartRecordingEvent extends RecordingEvent {}
class StopRecordingEvent extends RecordingEvent {}
class UploadChunkEvent extends RecordingEvent {}
class CompleteUploadEvent extends RecordingEvent {}
class UploadProgressEvent extends RecordingEvent {
  final double progress;
  const UploadProgressEvent(this.progress);
}
class UploadErrorEvent extends RecordingEvent {
  final String error;
  const UploadErrorEvent(this.error);
}
