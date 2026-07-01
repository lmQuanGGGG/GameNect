import re

with open('lib/user/screens/moments/mentor_post_preview_card.dart', 'r') as f:
    code = f.read()

# 1. Add showOnlyMedia field
code = code.replace(
    'final bool splitEvenly;',
    'final bool splitEvenly;\n  final bool showOnlyMedia;'
)
code = code.replace(
    'this.splitEvenly = false,',
    'this.splitEvenly = false,\n    this.showOnlyMedia = false,'
)

# 2. Fix mediaWidth
code = code.replace(
    'final mediaWidth = widget.splitEvenly && !isWideLayout',
    'final mediaWidth = widget.showOnlyMedia ? constraints.maxWidth : (widget.splitEvenly'
)
code = code.replace(
    ': gridRatioWidth.clamp(0.0, maxMediaWidth);',
    ': gridRatioWidth.clamp(0.0, maxMediaWidth));'
)

# 3. Add showOnlyMedia check for right content
# The right content starts at `if (isVideo && !widget.autoplayVideo)`
# wait, actually the row children:
old_row = """                          child: Column(
                            children: [
                              Expanded(
                                child: Stack(
                                  fit: StackFit.expand,"""

new_row = """                          child: Column(
                            children: [
                              Expanded(
                                child: Stack(
                                  fit: StackFit.expand,"""
# Actually, let's just replace the Stack and Positioned with Row directly
code = code.replace(
'''          return Stack(
            children: [
              Positioned.fill(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GestureDetector(
                      onTap: isVideo && widget.autoplayVideo
                          ? null
                          : onImageTap,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          bottomLeft: Radius.circular(12),
                        ),''',
'''          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                onTap: isVideo && widget.autoplayVideo
                    ? null
                    : onImageTap,
                child: ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(12),
                    bottomLeft: const Radius.circular(12),
                    topRight: widget.showOnlyMedia ? const Radius.circular(12) : Radius.zero,
                    bottomRight: widget.showOnlyMedia ? const Radius.circular(12) : Radius.zero,
                  ),'''
)

code = code.replace('''                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Container(width: 4, color: borderColor),
                    Expanded(
                      child: LayoutBuilder(''',
'''                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (!widget.showOnlyMedia) ...[
                    Container(width: 4, color: borderColor),
                    Expanded(
                      child: LayoutBuilder(''')

code = code.replace('''                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );''',
'''                            ),
                          );
                        },
                      ),
                    ),
                  ],
            ],
          );''')

# Now fix the UnseenBadge and Tat ca button
old_badge = '''                            if (unseenCount > 0) ...[
                              unseenBadge,
                              SizedBox(height: isWideLayout ? 14 : 10),
                            ],'''
new_badge = '''                            if (unseenCount > 0) ...[
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(child: unseenBadge),
                                  const SizedBox(width: 4),
                                  GestureDetector(
                                    onTap: onButtonTap,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: borderColor, width: 2),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text('Tất cả', style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
                                          Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Colors.black),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: isWideLayout ? 14 : 10),
                            ] else ...[
                              Align(
                                alignment: Alignment.topRight,
                                child: GestureDetector(
                                  onTap: onButtonTap,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: borderColor, width: 2),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('Tất cả', style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
                                        Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Colors.black),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],'''
code = code.replace(old_badge, new_badge)

# Fix UnseenBadge styling
old_unseen_func = '''  Widget _buildUnseenBadge({
    required String unseenLabel,
    required Color borderColor,
    required Future<void> Function() onTap,
    required bool isWideLayout,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(maxWidth: isWideLayout ? 150 : 112),
        padding: EdgeInsets.symmetric(
          horizontal: isWideLayout ? 14 : 10,
          vertical: isWideLayout ? 10 : 7,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFFF2D55),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 3),
          boxShadow: [
            BoxShadow(color: borderColor, offset: const Offset(4, 4)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  unseenLabel,
                  maxLines: 1,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isWideLayout ? 24 : 18,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            SizedBox(width: isWideLayout ? 7 : 5),
            Text(
              'CHƯA XEM',
              style: TextStyle(
                color: Colors.white,
                fontSize: isWideLayout ? 11 : 8,
                height: 1,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }'''

new_unseen_func = '''  Widget _buildUnseenBadge({
    required String unseenLabel,
    required Color borderColor,
    required Future<void> Function() onTap,
    required bool isWideLayout,
  }) {
    return Container(
      constraints: BoxConstraints(maxWidth: isWideLayout ? 150 : 112),
      padding: EdgeInsets.symmetric(
        horizontal: isWideLayout ? 14 : 10,
        vertical: isWideLayout ? 10 : 7,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE082),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 3),
        boxShadow: [
          BoxShadow(color: borderColor, offset: const Offset(4, 4)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                unseenLabel,
                maxLines: 1,
                style: TextStyle(
                  color: Colors.black,
                  fontSize: isWideLayout ? 24 : 18,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          SizedBox(width: isWideLayout ? 7 : 5),
          Text(
            'CHƯA XEM',
            style: TextStyle(
              color: Colors.black,
              fontSize: isWideLayout ? 11 : 6.5,
              height: 1,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }'''
code = code.replace(old_unseen_func, new_unseen_func)

# Remove the bottom "Tat ca" button if any?
# Wait, it's called _buildAllButton? No, it's not even there!
with open('lib/user/screens/moments/mentor_post_preview_card.dart', 'w') as f:
    f.write(code)

print("Done")
