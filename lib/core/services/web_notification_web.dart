// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:js' as js;

class WebNotificationServiceImpl {
  static Future<void> show({
    required String title,
    String? body,
    Map<String, String>? data,
    void Function()? onClick,
  }) async {
    final permission = html.Notification.permission;
    if (permission == 'denied') {
      return;
    }

    if (permission != 'granted') {
      final requested = await html.Notification.requestPermission();
      if (requested != 'granted') {
        return;
      }
    }

    final notification = html.Notification(
      title,
      body: body ?? '',
      icon: '/icons/Icon-192.png',
    );

    notification.onClick.listen((_) {
      js.context.callMethod('focus');
      if (onClick != null) {
        onClick();
      }
      notification.close();
    });
  }
}
