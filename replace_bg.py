import os
import re

def process_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    # Determine import path
    depth = filepath.count('/') - filepath.find('lib/') - 1
    rel_path = '../' * (depth) + 'core/widgets/app_background.dart'
    if 'core/widgets/app_background.dart' not in content:
        import_stmt = f"import '{rel_path}';"
        last_import_idx = content.rfind('import ')
        if last_import_idx != -1:
            end_of_line = content.find('\n', last_import_idx)
            content = content[:end_of_line+1] + import_stmt + '\n' + content[end_of_line+1:]

    # Step 1: find the background orbs and remove them
    # We find "// Background Orbs" and the 3 Positioned widgets.
    # A simple regex matching "// Background Orbs" until "child: Container(color: Colors.transparent),\n                )," or similar.
    pattern = re.compile(r'\s*// Background Orbs.*?(Positioned\.fill\([^)]+\)[^)]+\)[^)]+\),)', re.DOTALL)
    match = pattern.search(content)
    if not match:
        print(f"Skipping {filepath} - no background orbs found")
        return
        
    content = content[:match.start()] + content[match.end():]

    # Step 2: replace body: Stack( with body: AppBackground(child: Stack(
    # But we need to add the closing parenthesis. Let's do a simple parenthesis matcher starting from body: Stack(
    body_idx = content.find('body: Stack(')
    if body_idx == -1:
        # maybe body: SafeArea( ? or maybe it's just Stack( returned from build
        stack_idx = content.find('return Stack(')
        if stack_idx != -1:
            content = content.replace('return Stack(', 'return AppBackground(child: Stack(')
            open_idx = stack_idx + len('return AppBackground(child: Stack') - 1
        else:
            print(f"Could not find body: Stack( or return Stack( in {filepath}")
            return
    else:
        content = content.replace('body: Stack(', 'body: AppBackground(child: Stack(')
        open_idx = body_idx + len('body: AppBackground(child: Stack') - 1

    # find matching parenthesis for Stack(
    count = 1
    idx = open_idx + 1
    while idx < len(content):
        if content[idx] == '(':
            count += 1
        elif content[idx] == ')':
            count -= 1
            if count == 0:
                break
        idx += 1
        
    if count == 0:
        # Insert ) at idx + 1
        content = content[:idx+1] + ')' + content[idx+1:]
        with open(filepath, 'w') as f:
            f.write(content)
        print(f"Successfully processed {filepath}")
    else:
        print(f"Failed to find matching parenthesis for {filepath}")

# Find all dart files
for root, _, files in os.walk('/Users/wang04/Downloads/GAMENECT/gamenect_new/lib'):
    for file in files:
        if file.endswith('.dart'):
            filepath = os.path.join(root, file)
            with open(filepath, 'r') as f:
                if 'bgOrbOpacityMultiplier' in f.read():
                    process_file(filepath)

