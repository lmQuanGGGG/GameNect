import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

String? toCdnUrl(String? url) {
  return url; // Bỏ qua proxy do Firebase Hosting không hỗ trợ rewrite sang Storage bucket trực tiếp
}

/// Trả về NetworkImage đã được phân giải CDN trên Web.
ImageProvider cdnImageProvider(String? url, {String fallback = 'https://via.placeholder.com/150'}) {
  if (url == null || url.isEmpty) return NetworkImage(fallback);
  return NetworkImage(toCdnUrl(url) ?? url);
}
