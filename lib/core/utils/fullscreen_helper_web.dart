// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;

void toggleWebFullscreen(bool isFullscreen) {
  if (isFullscreen) {
    html.document.documentElement?.requestFullscreen();
  } else {
    html.document.exitFullscreen();
  }
}

Timer? _containTimer;

void startWebVideoContainTimer() {
  _containTimer?.cancel();
  _containTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
    js.context.callMethod('eval', [
      '''
      (function() {
        function querySelectorAllShadow(selector, root) {
          root = root || document;
          let matches = [];
          if (root.querySelectorAll) {
            const found = root.querySelectorAll(selector);
            if (found) matches = matches.concat(Array.from(found));
          }
          const elements = root.querySelectorAll ? Array.from(root.querySelectorAll('*')) : [];
          for (const el of elements) {
            if (el.shadowRoot) {
              matches = matches.concat(querySelectorAllShadow(selector, el.shadowRoot));
            }
          }
          return matches;
        }
        
        const videos = querySelectorAllShadow('video');
        videos.forEach(video => {
          if (video.style.objectFit !== 'contain') {
            video.style.setProperty('object-fit', 'contain', 'important');
            video.style.setProperty('background-color', '#000000', 'important');
          }
        });
      })()
      '''
    ]);
  });
}
