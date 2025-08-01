import 'dart:io';
import 'package:dio/dio.dart';

/// Upload a PDF file to a presigned S3 URL (PUT request, minimal headers)
Future<Response> uploadPdfToPresignedUrl({
  required String presignedUrl,
  required String filePath,
}) async {
  final file = File(filePath);
  print('Uploading PDF: $filePath, size: \\${await file.length()}');
  try {
    final response = await Dio().put(
      presignedUrl,
      data: file.openRead(),
      options: Options(
        headers: {'Content-Type': 'application/pdf'},
        followRedirects: false,
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    print('Upload response: \\${response.statusCode}');
    return response;
  } catch (e) {
    if (e is DioException && e.response != null) {
      print('Upload error: \\${e.response?.statusCode} \\${e.response?.data}');
    } else {
      print('Upload error: $e');
    }
    rethrow;
  }
}

// import 'package:login_package/haire_auth_api/service/firebase_services.dart';

class HaireApiService {
  final Dio _dio = Dio();
  final String _baseUrl =
      'https://us-central1-haire-ai-bc06f.cloudfunctions.net';
  // final String _baseUrl = 'https://us-central1-haire-ai-production.cloudfunctions.net';

  /// 1. Send Verification OTP
  Future<Response> sendVerificationOtp(String email) async {
    final String url = '$_baseUrl/sendVerificationOtp';
    try {
      print("@@@ sendVerificationOtp");
      final response = await _dio.post(
        url,
        data: {'email': email},
        options: Options(headers: {'Content-Type': 'application/json'}),
      );
      print("@@@ : $response");
      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// 4. Verify Login OTP
  Future<Response> verifyOtp(String email, int otp) async {
    final String url = '$_baseUrl/verifyOtp';
    try {
      final response = await _dio.post(
        url,
        data: {'email': email, 'otp': otp},
        options: Options(
          headers: {'Content-Type': 'application/json'},
          validateStatus: (status) => status != null && status <= 500,
        ),
      );
      print("@@@ : $response");
      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// 3. Send Login OTP
  Future<Response> sendLoginOtp(String email) async {
    final String url = '$_baseUrl/sendLoginOtp';
    try {
      print("@@@s sendLoginOtp");
      final response = await _dio.post(
        url,
        data: {'email': email},
        options: Options(
          headers: {'Content-Type': 'application/json'},
          validateStatus: (status) => status != null && status <= 500,
        ),
      );
      print("@@@ : $response");
      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// 4. Verify Login OTP
  Future<Response> verifyLoginOtp(String email, int otp) async {
    final String url = '$_baseUrl/verifyLoginOtp';
    try {
      print("@@@ verifyLoginOtp");
      final response = await _dio.post(
        url,
        data: {'email': email, 'otp': otp},
        options: Options(
          headers: {'Content-Type': 'application/json'},
          validateStatus: (status) => status != null && status <= 500,
        ),
      );
      print("@@@ : $response");
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<Response> generatePresignedUrl(String fileName) async {
    final String url = "https://haire.ai/api/ai/generate-presigned-url/";
    try {
      print("@@@ generatePresignedUrl");
      final response = await _dio.post(
        url,
        data: {'file_name': fileName},
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            "Authorization": "Token 7729840bbec752e54dc85edf279f11b09933c6a8",
          },
        ),
      );
      print("@@@ : $response");
      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Upload a file to the presigned URL (PUT request)
  Future<Response> uploadFileToPresignedUrl(
    String presignedUrl,
    String filePath,
  ) async {
    final file = File(filePath);
    print('Uploading file: $filePath, size: ${await file.length()}');
    try {
      // Try with Content-Type
      Response response = await Dio().put(
        presignedUrl,
        data: file.openRead(),
        options: Options(
          headers: {'Content-Type': 'application/pdf'},
          followRedirects: false,
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      print('Upload response (with Content-Type): ${response.statusCode}');
      if (response.statusCode == 200) return response;

      // If failed, try without Content-Type
      response = await Dio().put(
        presignedUrl,
        data: file.openRead(),
        options: Options(
          headers: {},
          followRedirects: false,
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      print('Upload response (no Content-Type): ${response.statusCode}');
      return response;
    } catch (e) {
      if (e is DioException && e.response != null) {
        print('Upload error: ${e.response?.statusCode} ${e.response?.data}');
      } else {
        print('Upload error: $e');
      }
      rethrow;
    }
  }
}
