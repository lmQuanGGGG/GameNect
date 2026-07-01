import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cached_network_image/cached_network_image.dart';

class GamenectNetworkImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final Widget Function(BuildContext, String)? placeholder;
  final Widget Function(BuildContext, String, dynamic)? errorWidget;
  final double? width;
  final double? height;
  final int? memCacheWidth;
  final int? memCacheHeight;

  const GamenectNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.width,
    this.height,
    this.memCacheWidth,
    this.memCacheHeight,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = imageUrl;

    int? cacheWidth = memCacheWidth;
    int? cacheHeight = memCacheHeight;

    if (cacheWidth == null && cacheHeight == null) {
      final pixelRatio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 3.0;
      const maxCacheDimen = 1080;

      if (width != null &&
          height != null &&
          width != double.infinity &&
          height != double.infinity) {
        final maxDimen = width! > height! ? width! : height!;
        if (maxDimen <= 100) {
          cacheWidth = 200;
        } else {
          final calculatedWidth = (maxDimen * pixelRatio).round();
          cacheWidth = calculatedWidth > maxCacheDimen
              ? maxCacheDimen
              : calculatedWidth;
        }
      } else if (width != null && width != double.infinity) {
        if (width! <= 100) {
          cacheWidth = 200;
        } else {
          final calculatedWidth = (width! * pixelRatio).round();
          cacheWidth = calculatedWidth > maxCacheDimen
              ? maxCacheDimen
              : calculatedWidth;
        }
      } else if (height != null && height != double.infinity) {
        if (height! <= 100) {
          cacheHeight = 200;
        } else {
          final calculatedHeight = (height! * pixelRatio).round();
          cacheHeight = calculatedHeight > maxCacheDimen
              ? maxCacheDimen
              : calculatedHeight;
        }
      } else {
        cacheWidth = maxCacheDimen;
      }
    }

    return CachedNetworkImage(
      key: ValueKey(resolvedUrl),
      imageUrl: resolvedUrl,
      fit: fit,
      width: width,
      height: height,
      memCacheWidth: cacheWidth,
      memCacheHeight: cacheHeight,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
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