// upload multiple part but not playing video after download

import 'dart:async';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screen_recording/flutter_screen_recording.dart';
import 'package:login_package/record_screen/recording_screen_bloc/recording_event.dart';
import 'package:login_package/record_screen/recording_screen_bloc/recording_state.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:xml/xml.dart' as xml;
import 'package:flutter_dotenv/flutter_dotenv.dart';


class RecordingBloc extends Bloc<RecordingEvent, RecordingState> {
  bool _isRecording = false;
  bool _isStopping = false;
  bool _isCompleting = false;
  String? _recordingPath = "/storage/emulated/0/Android/data/com.example.screen_rec_1/cache/Screen Recording.mp4";
  String? _uploadId;
  List<String> _partETags = [];
  int _partNumber = 1;
  String? _sessionId;
  final Dio _dio = Dio();
  final Uuid _uuid = Uuid();
  Timer? _chunkUploadTimer;
  static const int _chunkSize = 5 * 1024 * 1024; // 5MB

  RecordingBloc() : super(RecordingInitial()) {
    on<StartRecordingEvent>((event, emit) async {
      await _checkPermissions(emit);
      if (state is! PermissionsDenied) {
        _sessionId = _uuid.v4();
        await _startRecording(emit);
      }
    });
    on<StopRecordingEvent>((event, emit) async {
      await _stopRecording(emit);
    });
  }

  @override
  Future<void> close() {
    _chunkUploadTimer?.cancel();
    return super.close();
  }

  Future<void> _checkPermissions(Emitter emit) async {
    print('[BLoC] Checking microphone permission...');
    final micStatus = await Permission.microphone.request();
    if (micStatus.isGranted) {
      print('[BLoC] Microphone permission granted.');
      emit(RecordingInitial());
    } else {
      print('[BLoC] Microphone permission denied.');
      emit(PermissionsDenied());
    }
  }

  Future<void> _startRecording(Emitter emit) async {
    print('[BLoC] Starting screen recording...');
    try {
      bool started = await FlutterScreenRecording.startRecordScreenAndAudio(
        "Screen Recording",
        titleNotification: "Screen Recording",
        messageNotification: "Recording in progress",
      );
      print('[BLoC] startRecordScreen returned: $started');
      if (started) {
        await Future.delayed(Duration(seconds: 1));
        _isRecording = true;
        emit(RecordingInProgress());
        print('[BLoC] Recording started. Initiating multipart upload...');
        await _initiateMultipartUpload();
        // Start periodic chunk upload
        _chunkUploadTimer = Timer.periodic(
          Duration(seconds: 2),
          (_) => _uploadNextChunk(),
        );
      }
    } catch (e) {
      print('[BLoC] Error starting recording: $e');
      emit(RecordingError("Error starting recording: $e"));
    }
  }

  Future<void> _stopRecording(Emitter emit) async {
    if (_isRecording && !_isStopping) {
      print('[BLoC] Stopping screen recording...');
      _isStopping = true;
      _chunkUploadTimer?.cancel();
      try {
        String resultPath = await FlutterScreenRecording.stopRecordScreen;
        print('[BLoC] stopRecordScreen resultPath: $resultPath');
        if (await File(resultPath).exists()) {
          print(
            '[BLoC] Recording file exists. Waiting for file to be fully written...',
          );
          await Future.delayed(Duration(seconds: 1));
          _recordingPath = resultPath;
          print('[BLoC] Uploading final chunk to S3...');
          await _uploadNextChunk(finalChunk: true);
          print('[BLoC] Completing multipart upload...');
          await _completeMultipartUpload();
        } else {
          print('[BLoC] Recording file does not exist at: $resultPath');
        }
        _isRecording = false;
        emit(RecordingStopped());
        print('[BLoC] Recording stopped.');
      } catch (e) {
        print('[BLoC] Error stopping recording: $e');
        emit(RecordingError("Error stopping recording: $e"));
      } finally {
        _isStopping = false;
      }
    }
  }

  bool _isUploadingChunk = false;

  Future<void> _uploadNextChunk({bool finalChunk = false}) async {
    if (_isUploadingChunk) {
      print('[BLoC] Skipping: chunk upload already in progress.');
      return;
    }
    _isUploadingChunk = true;
    if (_recordingPath == null || _uploadId == null) {
      print('[BLoC] _uploadNextChunk: _recordingPath or _uploadId is null');
      _isUploadingChunk = false;
      return;
    }
    try {
      final file = File(_recordingPath!);
      final fileSize = await file.length();
      final prefs = await SharedPreferences.getInstance();
      int lastUploadedSize = prefs.getInt('lastUploadedSize') ?? 0;
      final fileName = prefs.getString('fileName') ??
          'recording_${DateTime.now().millisecondsSinceEpoch}.mp4';
      int partNumber = _partETags.length + 1;
      // Only upload if enough data for a new chunk and not already uploaded
      final remainingSize = fileSize - lastUploadedSize;
      if (remainingSize < _chunkSize && !finalChunk) {
        print('[BLoC] Skipping: Not enough data for next chunk.');
        _isUploadingChunk = false;
        return;
      }
      if (_partETags.length >= partNumber) {
        print('[BLoC] Skipping: Part $partNumber already uploaded.');
        _isUploadingChunk = false;
        return;
      }
      final end = (lastUploadedSize + _chunkSize > fileSize)
          ? fileSize
          : lastUploadedSize + _chunkSize;
      final chunkSize = end - lastUploadedSize;
      final chunk = file.openRead(lastUploadedSize, end);
      final uploadUrl = _generatePresignedUrl(
        accessKey: dotenv.env['accessKey']!,
        secretKey: dotenv.env['secretKey']!,
        region: dotenv.env['region']!,
        bucket: dotenv.env['bucketname']!,
        objectKey: fileName,
        method: 'PUT',
        extraQueryParams: {
          'partNumber': partNumber.toString(),
          'uploadId': _uploadId!,
        },
      );
      print('[BLoC] --- Uploading Chunk ---');
      print('[BLoC] Part Number: $partNumber');
      print('[BLoC] Chunk Size: ${chunkSize ~/ 1024} KB : $chunkSize bytes');
      print('[BLoC] Byte Range: $lastUploadedSize - $end');
      print('[BLoC] Upload URL: $uploadUrl');
      final response = await _dio.put(
        uploadUrl,
        data: chunk,
        options: Options(
          headers: {
            'Content-Type': 'video/mp4',
            'Content-Length': chunkSize.toString(),
          },
        ),
      );
      print('[BLoC] S3 Response Status: ${response.statusCode}');
      final eTag = response.headers['etag']?.first;
      print('[BLoC] Received ETag: $eTag');
      if (eTag != null) {
        final cleanETag = eTag.replaceAll('"', '');
        if (_partETags.length < partNumber) {
          _partETags.add(cleanETag);
        } else {
          _partETags[partNumber - 1] = cleanETag;
        }
        prefs.setStringList('partETags', _partETags);
        lastUploadedSize = end;
        prefs.setInt('lastUploadedSize', lastUploadedSize);
        prefs.setInt('partNumber', partNumber + 1);
        print('[BLoC] ✅ Chunk $partNumber uploaded successfully.');
      } else {
        print('[BLoC] ❌ ERROR: No ETag returned. Aborting upload.');
      }
    } catch (e, st) {
      print('[BLoC] ❌ Exception while uploading chunk: $e\n$st');
    } finally {
      _isUploadingChunk = false;
    }
  }

  String _generatePresignedUrl({
    required String accessKey,
    required String secretKey,
    required String region,
    required String bucket,
    required String objectKey,
    String method = 'PUT',
    Map<String, String>? extraQueryParams,
    int expiresInSeconds = 2000,
  }) {
    print('[BLoC] Generating presigned S3 URL...');
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
        .map(
          (e) =>
              '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}',
        )
        .join('&');
    final canonicalRequest = [
      method,
      '/$encodedKey',
      sortedQuery,
      'host:$host\n',
      'host',
      'UNSIGNED-PAYLOAD',
    ].join('\n');
    final hashedCanonicalRequest = sha256
        .convert(utf8.encode(canonicalRequest))
        .toString();
    final stringToSign = [
      'AWS4-HMAC-SHA256',
      amzDate,
      credentialScope,
      hashedCanonicalRequest,
    ].join('\n');
    List<int> _sign(List<int> key, String msg) =>
        Hmac(sha256, key).convert(utf8.encode(msg)).bytes;
    final kSecret = utf8.encode('AWS4$secretKey');
    final kDate = _sign(kSecret, dateStamp);
    final kRegion = _sign(kDate, region);
    final kService = _sign(kRegion, service);
    final kSigning = _sign(kService, 'aws4_request');
    final signature = Hmac(
      sha256,
      kSigning,
    ).convert(utf8.encode(stringToSign)).toString();
    final finalUrl = Uri.https(host, '/$objectKey', {
      ...queryParams,
      'X-Amz-Signature': signature,
    });
    print('[BLoC] Presigned URL generated: ' + finalUrl.toString());
    return finalUrl.toString();
  }

  Future<void> _initiateMultipartUpload() async {
    print('[BLoC] Initiating multipart upload with S3...');
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
      print('[BLoC] Multipart upload initUrl: $initUrl');
      final response = await _dio.post(
        initUrl,
        options: Options(headers: {'Content-Type': 'video/mp4'}),
      );
      print('[BLoC] S3 multipart upload response: ${response.data}');
      final xmlDoc = xml.XmlDocument.parse(response.data);
      final uploadIdElem = xmlDoc.findAllElements('UploadId').first;
      _uploadId = uploadIdElem.text;
      print('[BLoC] S3 multipart upload UploadId: $_uploadId');
      prefs.setString('uploadId', _uploadId!);
      prefs.setString('fileName', fileName);
      prefs.setString('sessionId', _sessionId!);
    } catch (e, st) {
      print('[BLoC] Error initiating multipart upload: $e\n$st');
    }
    _partETags.clear();
    _partNumber = 1;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lastUploadedSize', 0);
    await prefs.setInt('partNumber', 1);
    await prefs.setStringList('partETags', []);
  }

  Future<void> _uploadFinalChunk() async {
    print('[BLoC] Uploading final chunk...');
    if (_recordingPath == null || _uploadId == null) {
      print('[BLoC] _recordingPath or _uploadId is null');
      return;
    }
    try {
      final file = File(_recordingPath!);
      final fileSize = await file.length();
      print('[BLoC] Final chunk fileSize: $fileSize, path: $_recordingPath');
      final prefs = await SharedPreferences.getInstance();
      final lastUploadedSize = prefs.getInt('lastUploadedSize') ?? 0;
      print('[BLoC] Final chunk lastUploadedSize: $lastUploadedSize');
      if (lastUploadedSize >= fileSize) {
        print('[BLoC] Nothing left to upload.');
        return;
      }
      final chunkSize = fileSize - lastUploadedSize;
      print('[BLoC] Final chunk chunkSize: $chunkSize');
      final chunk = file.openRead(lastUploadedSize, fileSize);
      final fileName =
          prefs.getString('fileName') ??
          'recording_${DateTime.now().millisecondsSinceEpoch}.mp4';
      print('[BLoC] Final chunk fileName: $fileName, partNumber: $_partNumber');
      final uploadUrl = _generatePresignedUrl(
        accessKey: dotenv.env['accessKey']!,
        secretKey: dotenv.env['secretKey']!,
        region: dotenv.env['region']!,
        bucket: dotenv.env['bucketname']!,
        objectKey: fileName,
        method: 'PUT',
        extraQueryParams: {
          'partNumber': _partNumber.toString(),
          'uploadId': _uploadId!,
        },
      );
      print('[BLoC] Chunk uploadUrl: $uploadUrl');
      final response = await _dio.put(
        uploadUrl,
        data: chunk,
        options: Options(
          headers: {
            'Content-Type': 'video/mp4',
            'Content-Length': chunkSize.toString(),
          },
        ),
      );
      print('[BLoC] Final chunk S3 response status: ${response.statusCode}');
      print('[BLoC] Final chunk S3 response headers: ${response.headers}');
      print('[BLoC] Final chunk S3 response data: ${response.data}');
      final eTag = response.headers['etag']?.first;
      print('[BLoC] Final chunk eTag: $eTag');
      if (eTag != null) {
        final cleanETag = eTag.replaceAll('"', ''); // Remove quotes
        if (_partETags.length < _partNumber) {
          _partETags.add(cleanETag);
        } else {
          _partETags[_partNumber - 1] = cleanETag;
        }
        prefs.setStringList('partETags', _partETags);
        prefs.setInt('lastUploadedSize', fileSize);
        prefs.setInt('partNumber', _partNumber + 1);
        _partNumber++;
      } else {
        print('[BLoC] ERROR: No ETag returned for part upload!');
      }
    } catch (e, st) {
      print('[BLoC] Error uploading final chunk: $e\n$st');
    }
  }

  Future<void> _completeMultipartUpload() async {
    if (_isCompleting) {
      print('[BLoC] Skipping duplicate _completeMultipartUpload() call');
      return;
    }
    _isCompleting = true;

    print('[BLoC] Starting _completeMultipartUpload...');

    if (_uploadId == null || _partETags.isEmpty) {
      print('[BLoC] Cannot complete upload: _uploadId or _partETags is empty');
      _isCompleting = false;
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final fileName = prefs.getString('fileName') ??
          'recording_${DateTime.now().millisecondsSinceEpoch}.mp4';

      print('[BLoC] fileName: $fileName');
      print('[BLoC] uploadId: $_uploadId');
      print('[BLoC] partETags: $_partETags');

      // Construct XML body for multipart completion
      final partsXml = _partETags.asMap().entries.map((entry) {
        final partNumber = entry.key + 1;
        final eTag = entry.value;
        return '<Part><PartNumber>$partNumber</PartNumber><ETag>"$eTag"</ETag></Part>';
      }).join();
      final completeXml = '<CompleteMultipartUpload>$partsXml</CompleteMultipartUpload>';

      print('[BLoC] completeXml: $completeXml');

      // Generate presigned URL for completing multipart upload
      print('[BLoC] Generating presigned S3 URL...');
      final completeUrl = _generatePresignedUrl(
        accessKey: dotenv.env['accessKey']!,
        secretKey: dotenv.env['secretKey']!,
        region: dotenv.env['region']!,
        bucket: dotenv.env['bucketname']!,
        objectKey: fileName,
        method: 'POST',
        extraQueryParams: {'uploadId': _uploadId!},
      );

      print('[BLoC] completeMultipartUpload URL: $completeUrl');

      // Send the request to complete the upload
      final response = await _dio.post(
        completeUrl,
        data: completeXml,
        options: Options(
          headers: {'Content-Type': 'application/xml'},
          validateStatus: (status) => status != null && status < 500, // Allow 4xx logs
        ),
      );

      print('[BLoC] Response Status: ${response.statusCode}');
      print('[BLoC] Response Headers: ${response.headers}');
      print('[BLoC] Response Data: ${response.data}');

      if (response.statusCode == 200) {
        print('[BLoC] ✅ Multipart upload completed successfully');
      } else {
        print('[BLoC] ❌ ERROR: Failed to complete multipart upload. Status: ${response.statusCode}');
      }
    } catch (e, st) {
      print('[BLoC] ❌ Exception during multipart complete: $e\n$st');
    } finally {
      await _cleanupAfterUpload();
      _isCompleting = false;
    }
  }

  Future<void> _cleanupAfterUpload() async {
    print('[BLoC] Cleaning up local state and preferences after upload...');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('uploadId');
    await prefs.remove('fileName');
    await prefs.remove('partETags');
    await prefs.remove('lastUploadedSize');
    await prefs.remove('partNumber');
    await prefs.remove('sessionId');
    if (_recordingPath != null) {
      try {
        print('[BLoC] Deleting local recording file: $_recordingPath');
        await File(_recordingPath!).delete();
      } catch (e, st) {
        print('[BLoC] Error deleting local file: $e\n$st');
      }
    }
    _uploadId = null;
    _partETags = [];
    _partNumber = 1;
    _sessionId = null;
    _partETags.clear();
    _partNumber = 1;
    print('[BLoC] Cleanup complete.');
  }
}