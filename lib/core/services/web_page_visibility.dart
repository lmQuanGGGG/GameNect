import 'web_page_visibility_stub.dart'
    if (dart.library.html) 'web_page_visibility_web.dart';

typedef WebPageVisibilityCallback = void Function();

class WebPageVisibilityService {
  static void start(WebPageVisibilityCallback callback) {
    WebPageVisibilityServiceImpl.start(callback);
  }

  static void stop() {
    WebPageVisibilityServiceImpl.stop();
  }
}
