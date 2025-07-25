import 'package:bloc/bloc.dart';
import 'package:dio/dio.dart';
// import 'package:dio_example/service/firebase_services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../service/haire_api_service.dart';
import 'package:equatable/equatable.dart';

part 'otp_state.dart';

class OtpCubit extends Cubit<OtpState> {
  final HaireApiService apiService;
  OtpCubit(this.apiService) : super(OtpInitial());

  Future<void> sendVerificationOtp(String email) async {
    emit(OtpLoading());
    try {
      final response = await apiService.sendVerificationOtp(email);
      emit(OtpSent(email: email, isLoginOtp: false));
    } catch (e) {
      print("@@@ ${DateTime.now} $e");
      emit(OtpError(e.toString()));
    }
  }

  Future<void> verifyOtp(String email, int otp) async {
    emit(OtpLoading());
    try {
      final response = await apiService.verifyOtp(email, otp);
      emit(OtpVerified(response.data['message'] ?? 'OTP verified!'));
    } catch (e) {
      emit(OtpError(e.toString()));
    }
  }

  Future<void> sendLoginOtp(String email) async {
    emit(OtpLoading());
    try {
      final response = await apiService.sendLoginOtp(email);
      emit(OtpSent(email: email, isLoginOtp: true));
    } on DioException catch (e) {
      if (e.response != null && e.response?.data is Map<String, dynamic>) {
        final errorMessage = e.response?.data['error'];
        if (errorMessage == "No user found with this email") {
          sendVerificationOtp(email);
        }
      }
    }
  }

  Future<void> verifyLoginOtp(String email, int otp) async {
    emit(OtpLoading());
    try {
      final response = await apiService.verifyLoginOtp(email, otp);
      emit(OtpLoginVerified(response.data['message'] ?? 'Login OTP verified!'));
    } catch (e) {
      emit(OtpError(e.toString()));
    }
  }
}
