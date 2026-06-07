import re
with open('/Users/wang04/Downloads/GAMENECT/gamenect_new/lib/user/screens/profile/profile_screen.dart', 'r') as f:
    lines = f.readlines()
for i, line in enumerate(lines):
    if 'TextStyle' in line and 'color' in line:
        print(f"Line {i+1}: {line.strip()}")
