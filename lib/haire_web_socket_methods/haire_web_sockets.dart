import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

class HaireApi1 {
  Future<void> jobSeekerFullProfileEnhance() async {
    final String url =
        "wss://haire.ai/ws/jobseeker_full_profile_enhance/967537468565/";
    try {
      final channel = WebSocketChannel.connect(Uri.parse(url));
      final List<Map<String, dynamic>> message = [
        {
          "heading": "Summary",
          "content":
              "A highly motivated Flutter App Developer with 1 years of experience in building user-friendly and high-performance Flutter applications. Proficient in dart language, with strong skills in mobile app development, user interface design, and integration of third-party services. Seeking to contribute expertise in mobile app development and problem-solving in a dynamic team environment.",
          "order_id": 1,
        },
        {
          "heading": "Experience",
          "content":
              "Fino Payments Bank Ltd (Navi Mumbai) FINO Payment Bank is a leading digital banking institution that provides secure, fast, and innovative financial solutions. Specializing in payments gateway, digital wallets, and seamless banking experiences. I have worked closely with backend developers and UI/UX designers to make the user experience smoother and more enjoyable. Integrated third-party libraries Retrofit, Firebase services, etc.) and ensured smooth communication between app and server via RESTful APIs. Wrote clean, maintainable code.",
          "order_id": 2,
        },
      ];
      channel.sink.add(jsonEncode(message));
      channel.stream.listen(
        (data) {
          print("received: $data");
        },
        onDone: () {
          print("WebSocket closed");
        },
        onError: (error) {
          print("WebSocket error: $error");
        },
      );
    } catch (error) {
      print("Error: $error");
    }
  }

  Future<void> jobseekerProfilenhance() async {
    final String url =
        "wss://haire.ai/ws/jobseeker_profile_enhance/975880394889/";
    try {
      final channel = WebSocketChannel.connect(Uri.parse(url));
      final List<Map<String, dynamic>> message = [
        {
          "heading": "Summary",
          "content":
              "A highly motivated Flutter App Developer with 1 years of experience in building user-friendly and high-performance Flutter applications. Proficient in dart language, with strong skills in mobile app development, user interface design, and integration of third-party services. Seeking to contribute expertise in mobile app development and problem-solving in a dynamic team environment.",
          "order_id": 1,
        },
        {
          "heading": "Experience",
          "content":
              "Fino Payments Bank Ltd (Navi Mumbai) FINO Payment Bank is a leading digital banking institution that provides secure, fast, and innovative financial solutions. Specializing in payments gateway, digital wallets, and seamless banking experiences. I have worked closely with backend developers and UI/UX designers to make the user experience smoother and more enjoyable. Integrated third-party libraries Retrofit, Firebase services, etc.) and ensured smooth communication between app and server via RESTful APIs. Wrote clean, maintainable code.",
          "order_id": 2,
        },
      ];
      channel.sink.add(jsonEncode(message));
      channel.stream.listen(
        (data) {
          print("received: $data");
        },
        onDone: () {
          print("WebSocket closed");
        },
        onError: (error) {
          print("WebSocket error: $error");
        },
      );
    } catch (error) {
      print("Error: $error");
    }
  }
}
