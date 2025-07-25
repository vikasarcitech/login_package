part of 'otp_cubit.dart';

abstract class OtpState extends Equatable {
  @override
  List<Object?> get props => [];
}

class OtpInitial extends OtpState {}
class OtpLoading extends OtpState {}

class OtpSent extends OtpState {
  final String email;
  final bool isLoginOtp;
  OtpSent({required this.email, required this.isLoginOtp});
}


class OtpVerified extends OtpState {
  final String message;
  OtpVerified([this.message = 'OTP verified!']);
  @override
  List<Object?> get props => [message];
}

class OtpLoginVerified extends OtpState {
  final String message;
  OtpLoginVerified(this.message);
}

class OtpError extends OtpState {
  final String error;
  OtpError(this.error);
}


class LoginOtpSent extends OtpState {
  LoginOtpSent();
}