import 'package:flutter/material.dart';

/// Global notifier để các màn hình con thông báo cho MainScreen
/// ẩn/hiện TabBar khi user vuốt.
///
/// Usage trong màn hình con:
/// ```dart
/// NotificationListener<ScrollNotification>(
///   onNotification: (n) {
///     TabBarVisibility.of(context).update(n);
///     return false;
///   },
///   child: ListView(...),
/// )
/// ```
class TabBarVisibility extends InheritedWidget {
  final TabBarVisibilityController controller;

  const TabBarVisibility({
    super.key,
    required this.controller,
    required super.child,
  });

  static TabBarVisibilityController of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<TabBarVisibility>()!
        .controller;
  }

  @override
  bool updateShouldNotify(TabBarVisibility oldWidget) =>
      controller != oldWidget.controller;
}

class TabBarVisibilityController extends ChangeNotifier {
  bool _visible = true;
  double _lastScrollOffset = 0;

  bool get visible => _visible;

  /// Gọi từ ScrollNotification của màn hình con.
  void update(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification) {
      final delta = notification.scrollDelta ?? 0;
      // Vuốt lên (delta > 0) → ẩn TabBar
      // Vuốt xuống (delta < 0) → hiện TabBar
      if (delta > 4 && _visible) {
        _visible = false;
        notifyListeners();
      } else if (delta < -4 && !_visible) {
        _visible = true;
        notifyListeners();
      }
    } else if (notification is ScrollEndNotification) {
      // Nếu gần đầu list → luôn hiện
      if (notification.metrics.pixels <= 0) {
        if (!_visible) {
          _visible = true;
          notifyListeners();
        }
      }
    }
    _lastScrollOffset = notification.metrics.pixels;
  }

  /// Gọi trực tiếp để ép hiện/ẩn.
  void setVisible(bool value) {
    if (_visible != value) {
      _visible = value;
      notifyListeners();
    }
  }
}
