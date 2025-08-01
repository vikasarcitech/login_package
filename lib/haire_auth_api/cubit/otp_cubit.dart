import 'package:bloc/bloc.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:login_package/haire_auth_api/service/firebase_services.dart';
import '../service/haire_api_service.dart';
import 'package:equatable/equatable.dart';

part 'otp_state.dart';

class OtpCubit extends Cubit<AuthenticationState> {
  final HaireApiService apiService;
  OtpCubit(this.apiService) : super(OtpInitial());

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool isInitialized = false;

  Future<void> initSignin() async {
    if (!isInitialized) {
      await _googleSignIn.initialize(
        clientId:
            '877975338919-e5u0dam2115ql19t3vf8emhnldrm6gum.apps.googleusercontent.com',
        serverClientId:
            '877975338919-e5u0dam2115ql19t3vf8emhnldrm6gum.apps.googleusercontent.com',
      );
      isInitialized = true;
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      initSignin();
      final GoogleSignInAccount account = await _googleSignIn.authenticate();
      if (account == null) {
        throw FirebaseAuthException(
          code: 'SIGN IN ABORTED BY USER',
          message: 'User cancelled sign-in',
        );
      }

      final idToken = account.authentication.idToken;
      final authClient = account.authorizationClient;

      GoogleSignInClientAuthorization? auth = await authClient
          .authorizationForScopes(['email', 'profile']);

      final accessToken = auth?.accessToken;

      if (accessToken == null) {
        final auth2 = await authClient.authorizationForScopes([
          'email',
          'profile',
        ]);
        if (auth2?.accessToken == null) {
          throw FirebaseAuthException(
            code: "No Access Token",
            message: "Failed to get access token from Google Sign-In",
          );
        }
        auth = auth2;
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: idToken,
      );
      emit(GoogleSignInSuccessState());
      return await FirebaseAuth.instance.signInWithCredential(credential);
    } catch (e) {
      emit(GoogleSignInFailureState(errorMessage: "Error : $e"));
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await FirebaseAuth.instance.signOut();
  }

  Future<void> sendVerificationOtp(String email) async {
    emit(OtpLoading());
    try {
      final response = await apiService.sendVerificationOtp(email);
      if (response.statusCode == 200) {
        print("@@@ OTP sent to $email");
        await FirebaseServices().registerWithEmailPassword(
          email,
          "defaultPassword123",
        );
        emit(OtpSent(email: email, isLoginOtp: false));
      } else {
        final errorMessage =
            response.data['error'] ??
            response.data['message'] ??
            'Unknown error occurred';
        print("@@@ Error: $errorMessage");
        emit(OtpError(errorMessage));
      }
    } on DioException catch (e) {
      final errorMessage =
          e.response?.data['error'] ?? e.message ?? 'Network error';
      print("@@@ Dio Error: $errorMessage");
      emit(OtpError(errorMessage));
    } catch (e) {
      print("@@@ Error: $e");
      emit(OtpError(e.toString()));
    }
  }

  Future<void> verifyOtp(String email, int otp) async {
    emit(OtpLoading());
    try {
      final response = await apiService.verifyOtp(email, otp);
      if (response.statusCode == 200 && (response.data['verified'] == true)) {
        print("@@@ OTP verified");
        emit(OtpVerified(response.data['message'] ?? 'OTP verified!'));
      } else {
        final errorMessage =
            response.data['error'] ??
            response.data['message'] ??
            'Invalid or expired OTP';
        print("@@@ Error: $errorMessage");
        emit(OtpError(errorMessage));
      }
    } on DioException catch (e) {
      final errorMessage =
          e.response?.data['error'] ?? e.message ?? 'Network error';
      print("@@@ Dio Error: $errorMessage");
      emit(OtpError(errorMessage));
    } catch (e) {
      emit(OtpError(e.toString()));
    }
  }

  Future<void> sendLoginOtp(String email) async {
    emit(OtpLoading());
    if (!isValidEmail(email)) {
      print("@@@ Error: Invalid email");
      emit(OtpError("Invalid email"));
      return;
    }
    try {
      final response = await apiService.sendLoginOtp(email);
      print("@@@ Response: $response : \\${response.statusMessage}");
      if (response.statusCode == 200 && (response.data['error'] == null)) {
        print("@@@ Login OTP sent to $email");
        emit(OtpSent(email: email, isLoginOtp: true));
      } else if (response.data['error'] == "No user found with this email") {
        print("@@@ Error: No user found with this email");
        await sendVerificationOtp(email);
      } else {
        final errorMessage =
            response.data['error'] ??
            response.data['message'] ??
            'Unknown error occurred';
        print("@@@ Error: $errorMessage");
        emit(OtpError(errorMessage));
      }
    } on DioException catch (e) {
      final errorMessage =
          e.response?.data['error'] ?? e.message ?? 'Network error';
      print("@@@ Dio Error: $errorMessage");
      emit(OtpError(errorMessage));
    } catch (e) {
      emit(OtpError(e.toString()));
    }
  }

  Future<void> verifyLoginOtp(String email, int otp) async {
    emit(OtpLoading());
    try {
      final response = await apiService.verifyLoginOtp(email, otp);
      if (response.statusCode == 200 && (response.data['verified'] == true)) {
        print("@@@ Login OTP verified");
        emit(OtpVerified(response.data['message'] ?? 'Login OTP verified!'));
      } else {
        final errorMessage =
            response.data['error'] ??
            response.data['message'] ??
            'Invalid or expired OTP';
        print("@@@ Error: $errorMessage");
        emit(OtpError(errorMessage));
      }
    } on DioException catch (e) {
      final errorMessage =
          e.response?.data['error'] ?? e.message ?? 'Network error';
      print("@@@ Dio Error: $errorMessage");
      emit(OtpError(errorMessage));
    } catch (e) {
      emit(OtpError(e.toString()));
    }
  }

  bool isValidEmail(String email) {
    // Regular expression for email validation
    String pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
    RegExp regExp = RegExp(pattern);
    return regExp.hasMatch(email);
  }
}
