import 'web_message_stub.dart'
    if (dart.library.html) 'web_message_web.dart';

typedef WebMessageHandler = void Function(Map<String, dynamic> data);

class WebMessageService {
  static void listen(WebMessageHandler handler) {
    WebMessageServiceImpl.listen(handler);
  }
}
