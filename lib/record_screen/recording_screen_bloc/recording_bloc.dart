import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:crypto/crypto.dart';
import 'package:xml/xml.dart' as xml;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screen_recording/flutter_screen_recording.dart';
import 'recording_event.dart';
import 'recording_state.dart';

class RecordingBloc extends Bloc<RecordingEvent, RecordingState> {
  bool _isRecording = false;
  bool _permissionsGranted = false;
  String? _recordingPath;
  String? _uploadId;
  List<String> _partETags = [];
  int _partNumber = 1;
  String? _sessionId;
  Timer? _uploadTimer;
  final Dio _dio = Dio();
  final Uuid _uuid = Uuid();

  RecordingBloc() : super(RecordingInitial()) {
    on<StartRecordingEvent>(_onStartRecording);
    on<StopRecordingEvent>(_onStopRecording);
    on<UploadChunkEvent>(_onUploadChunk);
    on<CompleteUploadEvent>(_onCompleteUpload);
    on<UploadErrorEvent>((event, emit) async {
      emit(UploadFailure(event.error));
    });
  }

  Future<void> _onStartRecording(StartRecordingEvent event, Emitter<RecordingState> emit) async {
    emit(RecordingInitial());
    await _checkPermissions();
    if (_permissionsGranted) {
      _sessionId = _uuid.v4();
      try {
        bool started = await FlutterScreenRecording.startRecordScreen(
          "Screen Recording",
          titleNotification: "Screen Recording",
          messageNotification: "Recording in progress",
        );
        if (started) {
          await Future.delayed(Duration(seconds: 1));
          _isRecording = true;
          emit(RecordingInProgress());
          await _initiateMultipartUpload();
          _uploadTimer = Timer.periodic(Duration(seconds: 10), (timer) {
            if (_isRecording && _recordingPath != null) {
              add(UploadChunkEvent());
            }
          });
        } else {
          emit(UploadFailure('Failed to start recording.'));
        }
      } catch (e) {
        emit(UploadFailure('Error starting recording: $e'));
      }
    } else {
      emit(UploadFailure('Permissions not granted.'));
    }
  }

  Future<void> _onStopRecording(StopRecordingEvent event, Emitter<RecordingState> emit) async {
    if (_isRecording) {
      try {
        String? resultPath = await FlutterScreenRecording.stopRecordScreen;
        if (resultPath != null && await File(resultPath).exists()) {
          _recordingPath = resultPath;
          emit(RecordingStopped());
          await _uploadFinalChunk(emit);
          await _completeMultipartUpload();
        } else {
          emit(UploadFailure('Recording file does not exist at: ' + (resultPath ?? 'null')));
        }
        _isRecording = false;
        _uploadTimer?.cancel();
      } catch (e) {
        emit(UploadFailure('Error stopping recording: $e'));
      }
    }
  }

  Future<void> _completeMultipartUpload() async {
    if (_uploadId == null || _partETags.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final fileName =
          prefs.getString('fileName') ??
          'recording_${DateTime.now().millisecondsSinceEpoch}.mp4';

      // Build XML body for CompleteMultipartUpload
      final partsXml = _partETags.asMap().entries.map((entry) {
        final partNumber = entry.key + 1;
        final eTag = entry.value;
        return '<Part><PartNumber>$partNumber</PartNumber><ETag>$eTag</ETag></Part>';
      }).join();
      final completeXml = '<CompleteMultipartUpload>$partsXml</CompleteMultipartUpload>';

      // Generate presigned URL with uploadId as query param
      final completeUrl = _generatePresignedUrl(
        accessKey: dotenv.env['accessKey']!,
        secretKey: dotenv.env['secretKey']!,
        region: dotenv.env['region']!,
        bucket: dotenv.env['bucketname']!,
        objectKey: fileName,
        method: 'POST',
        extraQueryParams: {'uploadId': _uploadId!},
      );

      await _dio.post(
        completeUrl,
        data: completeXml,
        options: Options(headers: {'Content-Type': 'application/xml'}),
      );

      await _cleanupAfterUpload();
    } catch (e) {
      print('Error completing multipart upload: $e');
    }
  }

  Future<void> _onUploadChunk(UploadChunkEvent event, Emitter<RecordingState> emit) async {
    if (_recordingPath == null || _uploadId == null) {
      emit(UploadFailure('No recording file to upload.'));
      return;
    }
    if (!await File(_recordingPath!).exists()) {
      emit(UploadFailure('Recording file does not exist at: ' + _recordingPath!));
      return;
    }
    try {
      final file = File(_recordingPath!);
      final fileSize = await file.length();
      final prefs = await SharedPreferences.getInstance();
      final lastUploadedSize = prefs.getInt('lastUploadedSize') ?? 0;
      if (fileSize - lastUploadedSize < 5 * 1024 * 1024) return;
      final chunkSize = min(5 * 1024 * 1024, fileSize - lastUploadedSize);
      final chunk = file.openRead(lastUploadedSize, lastUploadedSize + chunkSize);
      final fileName = prefs.getString('fileName') ?? 'recording_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final uploadUrl = _generatePresignedUrl(
        accessKey: dotenv.env['accessKey']!,
        secretKey: dotenv.env['secretKey']!,
        region: dotenv.env['region']!,
        bucket: dotenv.env['bucketname']!,
        objectKey: fileName,
      );
      final response = await _dio.put(
        uploadUrl,
        data: chunk,
        options: Options(
          headers: {
            'Content-Type': 'application/octet-stream',
            'Content-Length': chunkSize.toString(),
          },
        ),
      );
      final eTag = response.headers['etag']?.first;
      if (eTag != null) {
        _partETags.add(eTag);
        prefs.setStringList('partETags', _partETags);
        prefs.setInt('lastUploadedSize', lastUploadedSize + chunkSize);
        prefs.setInt('partNumber', _partNumber + 1);
        _partNumber++;
        emit(UploadInProgress((lastUploadedSize + chunkSize) / fileSize));
      }
    } catch (e) {
      emit(UploadFailure('Error uploading chunk: $e'));
    }
  }

  Future<void> _uploadFinalChunk(Emitter<RecordingState> emit) async {
    if (_recordingPath == null || _uploadId == null) return;
    try {
      final file = File(_recordingPath!);
      final fileSize = await file.length();
      final prefs = await SharedPreferences.getInstance();
      final lastUploadedSize = prefs.getInt('lastUploadedSize') ?? 0;
      if (lastUploadedSize >= fileSize) return;
      final chunkSize = fileSize - lastUploadedSize;
      final chunk = file.openRead(lastUploadedSize, fileSize);
      final fileName = prefs.getString('fileName') ?? 'recording_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final uploadUrl = _generatePresignedUrl(
        accessKey: dotenv.env['accessKey']!,
        secretKey: dotenv.env['secretKey']!,
        region: dotenv.env['region']!,
        bucket: dotenv.env['bucketname']!,
        objectKey: fileName,
      );
      final response = await _dio.put(
        uploadUrl,
        data: chunk,
        options: Options(
          headers: {
            'Content-Type': 'application/octet-stream',
            'Content-Length': chunkSize.toString(),
          },
        ),
      );
      final eTag = response.headers['etag']?.first;
      if (eTag != null) {
        _partETags.add(eTag);
        prefs.setStringList('partETags', _partETags);
        prefs.setInt('lastUploadedSize', fileSize);
        prefs.setInt('partNumber', _partNumber + 1);
        emit(UploadInProgress(1.0));
      }
    } catch (e) {
      emit(UploadFailure('Error uploading final chunk: $e'));
    }
  }

  Future<void> _onCompleteUpload(CompleteUploadEvent event, Emitter<RecordingState> emit) async {
    if (_uploadId == null || _partETags.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final fileName = prefs.getString('fileName') ?? 'recording_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final partsXml = _partETags.asMap().entries.map((entry) {
        final partNumber = entry.key + 1;
        final eTag = entry.value;
        return '<Part><PartNumber>$partNumber</PartNumber><ETag>$eTag</ETag></Part>';
      }).join();
      final completeXml = '<CompleteMultipartUpload>$partsXml</CompleteMultipartUpload>';
      final completeUrl = _generatePresignedUrl(
        accessKey: dotenv.env['accessKey']!,
        secretKey: dotenv.env['secretKey']!,
        region: dotenv.env['region']!,
        bucket: dotenv.env['bucketname']!,
        objectKey: fileName,
        method: 'POST',
        extraQueryParams: {'uploadId': _uploadId!},
      );
      await _dio.post(
        completeUrl,
        data: completeXml,
        options: Options(headers: {'Content-Type': 'application/xml'}),
      );
      await _cleanupAfterUpload();
      emit(UploadSuccess());
    } catch (e) {
      emit(UploadFailure('Error completing multipart upload: $e'));
    }
  }

  Future<void> _checkPermissions() async {
    final micStatus = await Permission.microphone.request();
    _permissionsGranted = micStatus.isGranted;
    // Optionally handle openAppSettings if not granted
  }

  Future<void> _initiateMultipartUpload() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final fileName = 'recording_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final initUrl = _generatePresignedUrl(
        accessKey: dotenv.env['accessKey']!,
        secretKey: dotenv.env['secretKey']!,
        region: dotenv.env['region']!,
        bucket: dotenv.env['bucketname']!,
        objectKey: fileName,
        method: 'POST',
        extraQueryParams: {'uploads': ''},
      );
      final response = await _dio.post(
        initUrl,
        options: Options(headers: {'Content-Type': 'application/octet-stream'}),
      );
      final xmlDoc = xml.XmlDocument.parse(response.data);
      final uploadIdElem = xmlDoc.findAllElements('UploadId').first;
      _uploadId = uploadIdElem.text;
      prefs.setString('uploadId', _uploadId!);
      prefs.setString('fileName', fileName);
      prefs.setString('sessionId', _sessionId!);
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _cleanupAfterUpload() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('uploadId');
    await prefs.remove('fileName');
    await prefs.remove('partETags');
    await prefs.remove('lastUploadedSize');
    await prefs.remove('partNumber');
    await prefs.remove('sessionId');
    if (_recordingPath != null) {
      try {
        await File(_recordingPath!).delete();
      } catch (e) {
        // ignore
      }
    }
    _uploadId = null;
    _partETags = [];
    _partNumber = 1;
    _sessionId = null;
  }

  String _generatePresignedUrl({
    required String accessKey,
    required String secretKey,
    required String region,
    required String bucket,
    required String objectKey,
    String method = 'PUT',
    Map<String, String>? extraQueryParams,
    int expiresInSeconds = 5000,
  }) {
    final service = 's3';
    final now = DateTime.now().toUtc();
    final dateStamp = DateFormat('yyyyMMdd').format(now);
    final amzDate = DateFormat("yyyyMMdd'T'HHmmss'Z'").format(now);
    final credentialScope = '$dateStamp/$region/$service/aws4_request';
    final credential = '$accessKey/$credentialScope';
    final host = '$bucket.s3.$region.amazonaws.com';
    final encodedKey = Uri.encodeComponent(objectKey);
    final queryParams = {
      'X-Amz-Algorithm': 'AWS4-HMAC-SHA256',
      'X-Amz-Credential': credential,
      'X-Amz-Date': amzDate,
      'X-Amz-Expires': '$expiresInSeconds',
      'X-Amz-SignedHeaders': 'host',
      ...?extraQueryParams,
    };
    final sortedQuery = queryParams.entries
        .map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    final canonicalRequest = [
      method,
      '/$encodedKey',
      sortedQuery,
      'host:$host\n',
      'host',
      'UNSIGNED-PAYLOAD',
    ].join('\n');
    final hashedCanonicalRequest = sha256.convert(utf8.encode(canonicalRequest)).toString();
    final stringToSign = [
      'AWS4-HMAC-SHA256',
      amzDate,
      credentialScope,
      hashedCanonicalRequest,
    ].join('\n');
    List<int> _sign(List<int> key, String msg) => Hmac(sha256, key).convert(utf8.encode(msg)).bytes;
    final kSecret = utf8.encode('AWS4$secretKey');
    final kDate = _sign(kSecret, dateStamp);
    final kRegion = _sign(kDate, region);
    final kService = _sign(kRegion, service);
    final kSigning = _sign(kService, 'aws4_request');
    final signature = Hmac(sha256, kSigning).convert(utf8.encode(stringToSign)).toString();
    final finalUrl = Uri.https(host, '/$objectKey', {
      ...queryParams,
      'X-Amz-Signature': signature,
    });
    return finalUrl.toString();
  }
}
