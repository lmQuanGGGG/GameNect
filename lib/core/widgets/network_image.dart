import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/cdn_helper.dart';

class GamenectNetworkImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final Widget Function(BuildContext, String)? placeholder;
  final Widget Function(BuildContext, String, dynamic)? errorWidget;
  final double? width;
  final double? height;

  const GamenectNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = toCdnUrl(imageUrl) ?? imageUrl;
    if (kIsWeb) {
      // Trên Web: Dùng Image.network với ValueKey để tránh bị tạo lại widget và load lại ảnh
      return Image.network(
        resolvedUrl,
        key: ValueKey(resolvedUrl),
        fit: fit,
        width: width,
        height: height,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          if (placeholder != null) {
            return placeholder!(context, resolvedUrl);
          }
          return Container(
            width: width,
            height: height,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.05),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          if (errorWidget != null) {
            return errorWidget!(context, resolvedUrl, error);
          }
          return Container(
            width: width,
            height: height,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.05),
            child: Icon(
              Icons.error_outline,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white70
                  : Colors.black45,
            ),
          );
        },
      );
    } else {
      // Trên Mobile: Dùng CachedNetworkImage với cache của flutter_cache_manager
      return CachedNetworkImage(
        imageUrl: resolvedUrl,
        fit: fit,
        width: width,
        height: height,
        placeholder: placeholder != null
            ? (context, url) => placeholder!(context, url)
            : (context, url) => Container(
                  width: width,
                  height: height,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.05),
                ),
        errorWidget: errorWidget != null
            ? (context, url, error) => errorWidget!(context, url, error)
            : (context, url, error) => Container(
                  width: width,
                  height: height,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.05),
                  child: Icon(
                    Icons.error_outline,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white70
                        : Colors.black45,
                  ),
                ),
      );
    }
  }
}
