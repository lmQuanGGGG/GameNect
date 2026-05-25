import 'package:flutter/foundation.dart';
import 'web_notification_stub.dart'
  if (dart.library.html) 'web_notification_web.dart';

class WebNotificationService {
  static Future<void> show({
    required String title,
    String? body,
    Map<String, String>? data,
    VoidCallback? onClick,
  }) {
    return WebNotificationServiceImpl.show(
      title: title,
      body: body,
      data: data,
      onClick: onClick,
    );
  }
}
