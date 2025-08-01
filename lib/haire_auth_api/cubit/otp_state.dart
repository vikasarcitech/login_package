part of 'otp_cubit.dart';

abstract class AuthenticationState extends Equatable {
  @override
  List<Object?> get props => [];
}

class OtpInitial extends AuthenticationState {}
class OtpLoading extends AuthenticationState {}

class OtpSent extends AuthenticationState {
  final String email;
  final bool isLoginOtp;
  OtpSent({required this.email, required this.isLoginOtp});
}


class OtpVerified extends AuthenticationState {
  final String message;
  OtpVerified([this.message = 'OTP verified!']);
  @override
  List<Object?> get props => [message];
}

class OtpLoginVerified extends AuthenticationState {
  final String message;
  OtpLoginVerified(this.message);
}

class OtpError extends AuthenticationState {
  final String error;
  OtpError(this.error);
}


class LoginOtpSent extends AuthenticationState {
  LoginOtpSent();
}

class GoogleSignInSuccessState extends AuthenticationState {}

class GoogleSignInFailureState extends AuthenticationState {
  String errorMessage;
  GoogleSignInFailureState({required this.errorMessage});
}