with open('lib/core/providers/match_provider.dart', 'r') as f:
    content = f.read()

unused_func = """  // Hàm format thời lượng cuộc gọi sang dạng phút/giây
  String _formatDuration(int seconds) {
    if (seconds < 60) return '$seconds giây';
    final min = seconds ~/ 60;
    final sec = seconds % 60;
    return sec == 0 ? '$min phút' : '$min:${sec.toString().padLeft(2, '0')} phút';
  }"""

content = content.replace(unused_func, "")

with open('lib/core/providers/match_provider.dart', 'w') as f:
    f.write(content)
