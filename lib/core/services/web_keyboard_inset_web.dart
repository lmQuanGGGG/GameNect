// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;

typedef WebKeyboardInsetHandler = void Function(double inset);

abstract final class WebKeyboardInsetServiceImpl {
  static StreamSubscription<html.MessageEvent>? _subscription;
  static Timer? _pollTimer;
  static double _lastInset = -1;

  static void listen(WebKeyboardInsetHandler handler) {
    _subscription?.cancel();
    _pollTimer?.cancel();
    _lastInset = -1;

    void publish(dynamic value) {
      if (value is! num) return;
      final inset = value.toDouble();
      if ((_lastInset - inset).abs() < 1) return;
      _lastInset = inset;
      handler(inset);
    }

    _subscription = html.window.onMessage.listen((event) {
      try {
        final data = event.data;
        if (data == null) return;

        if (data is Map) {
          if (data['type'] == 'gamenectKeyboardInset') {
            publish(data['inset']);
          }
          return;
        }

        final message = js.JsObject.fromBrowserObject(data);
        if (message['type'] != 'gamenectKeyboardInset') return;
        publish(message['inset']);
      } catch (_) {
        // Ignore messages from unrelated scripts.
      }
    });

    void readCurrentInset() {
      try {
        publish(js.context['__gamenectKeyboardInset']);
      } catch (_) {
        publish(0);
      }
    }

    readCurrentInset();
    _pollTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => readCurrentInset(),
    );
  }

  static void cancel() {
    _subscription?.cancel();
    _subscription = null;
    _pollTimer?.cancel();
    _pollTimer = null;
    _lastInset = -1;
  }
}
