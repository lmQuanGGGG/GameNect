// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:async';

import 'web_page_visibility.dart';

class WebPageVisibilityServiceImpl {
  static final List<StreamSubscription> _subscriptions = [];

  static void start(WebPageVisibilityCallback callback) {
    stop();
    _subscriptions.add(
      html.document.onVisibilityChange.listen((_) {
        if (html.document.visibilityState == 'visible') {
          callback();
        }
      }),
    );
    _subscriptions.add(html.window.onFocus.listen((_) => callback()));
  }

  static void stop() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
  }
}
