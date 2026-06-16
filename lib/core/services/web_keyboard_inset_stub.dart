typedef WebKeyboardInsetHandler = void Function(double inset);

abstract final class WebKeyboardInsetServiceImpl {
  static void listen(WebKeyboardInsetHandler handler) {}

  static void cancel() {}
}
