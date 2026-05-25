// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js' as js;

typedef WebMessageHandler = void Function(Map<String, dynamic> data);

class WebMessageServiceImpl {
  static void listen(WebMessageHandler handler) {
    // Lắng nghe message từ window (JS retry loop sẽ gửi vào đây)
    html.window.onMessage.listen((event) {
      try {
        final data = event.data;
        if (data == null) return;

        final jsObject = js.JsObject.fromBrowserObject(data);
        if (jsObject.hasProperty('type') && jsObject['type'] == 'notification') {
          final jsPayload = jsObject['data'];
          if (jsPayload != null) {
            final String jsonString = js.context['JSON'].callMethod('stringify', [jsPayload]);
            final Map<String, dynamic> payload = Map<String, dynamic>.from(jsonDecode(jsonString));
            // Báo cho index.html dừng retry loop
            try {
              js.context.callMethod('__markSwNotificationDelivered');
            } catch (_) {}
            handler(payload);
          }
        }
      } catch (e) {
        // Safe fallback: ignore any parsing errors
      }
    });

    // Flutter chủ động pull pending notification ngay khi sẵn sàng.
    // Tránh race condition: SW có thể gửi message trước khi Flutter đăng ký listener.
    // Dù JS retry loop có miss, Flutter vẫn lấy được qua window.__pendingSwNotification.
    try {
      final pending = js.context['__pendingSwNotification'];
      if (pending != null) {
        final jsPayload = js.JsObject.fromBrowserObject(pending)['data'];
        if (jsPayload != null) {
          final String jsonString = js.context['JSON'].callMethod('stringify', [jsPayload]);
          final Map<String, dynamic> payload = Map<String, dynamic>.from(jsonDecode(jsonString));
          js.context.callMethod('__markSwNotificationDelivered');
          handler(payload);
        }
      }
    } catch (_) {
      // Không có pending notification hoặc lỗi parse, bỏ qua
    }
  }
}
