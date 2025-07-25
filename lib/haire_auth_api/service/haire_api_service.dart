import 'package:dio/dio.dart';
// import 'package:dio_example/service/firebase_services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:login_package/haire_auth_api/service/firebase_services.dart';

class HaireApiService {
  final Dio _dio = Dio();
  final String _baseUrl = 'https://us-central1-haire-ai-bc06f.cloudfunctions.net';
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

  Future<Response> verifyOtp(String email, int otp) async {
    final String url = '$_baseUrl/verifyOtp';
    try {
      print("@@@ verifyOtp email: $email and otp: $otp");
      final request = {'email': email, 'otp': otp};
      print("@@@ Request : $request");
      final response = await _dio.post(
        url,
        data: request,
        options: Options(
          headers: {'Content-Type': 'application/json'},
          validateStatus: (status) => status != null && status <= 500,
        ),
      );
      if (response.data['message'] == "No user found with this email") {
        await FirebaseServices().registerWithEmailPassword(email, "defaultPassword123");
        final newResponse = await verifyOtp(email, otp); // Await the new response
        print("@@@ New Response : $newResponse");
        return newResponse;
      }
      print("@@@ Response: $response");
      return response;
    } catch (e) {
      print("@@@ $e");
      rethrow;
    }
  }

  /// 3. Send Login OTP
  Future<Response> sendLoginOtp(String email) async {
    final String url = '$_baseUrl/sendLoginOtp';
    try {
      print("@@@ sendLoginOtp");
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
  Future<Response> verifyLoginOtp(String email, int otp) async {
    final String url = '$_baseUrl/verifyLoginOtp';
    try {
      print("@@@ verifyLoginOtp");
      final response = await _dio.post(
        url,
        data: {'email': email, 'otp': otp},
        options: Options(headers: {'Content-Type': 'application/json'}),
      );
      print("@@@ : $response");
      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// 4. Verify Login OTP
  Future<Response> socialLogin(String email, int otp) async {
    final String url = '$_baseUrl/social-login';
    try {
      print("@@@ verifyLoginOtp");
      final response = await _dio.post(
        url,
        data: {'email': email, 'otp': otp},
        options: Options(headers: {'Content-Type': 'application/json'}),
      );
      print("@@@ : $response");
      return response;
    } catch (e) {
      rethrow;
    }
  }
}
