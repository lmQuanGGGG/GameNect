import 'web_keyboard_inset_stub.dart'
    if (dart.library.html) 'web_keyboard_inset_web.dart';

typedef WebKeyboardInsetHandler = void Function(double inset);

abstract final class WebKeyboardInsetService {
  static void listen(WebKeyboardInsetHandler handler) {
    WebKeyboardInsetServiceImpl.listen(handler);
  }

  static void cancel() {
    WebKeyboardInsetServiceImpl.cancel();
  }
}
