import 'package:dio/dio.dart';

class OtpService {
  final Dio _dio;
  final String _baseUrl;

  OtpService({Dio? dio, required String baseUrl}) : _dio = dio ?? Dio(), _baseUrl = baseUrl;

  /// POST /sendVerificationOtp
  Future<Response> sendVerificationOtp(String email) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/sendVerificationOtp',
        data: {'email': email},
      );
      return response;
    } catch (e) {
      throw Exception('Failed to send OTP: $e');
    }
  }

  /// POST /verifyOtp
  Future<Response> verifyOtp({
    required String email,
    required String otp,
  }) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/verifyOtp',
        data: {'email': email, 'otp': otp},
      );
      return response;
    } catch (e) {
      throw Exception('Failed to verify OTP: $e');
    }
  }

  /// POST /verifyLoginOtp
  Future<Response> verifyLoginOtp({
    required String email,
    required String otp,
  }) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/verifyLoginOtp',
        data: {'email': email, 'otp': otp},
      );
      return response;
    } catch (e) {
      throw Exception('Failed to verify login OTP: $e');
    }
  }
}
