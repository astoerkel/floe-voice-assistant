#!/usr/bin/env python3

with open('VoiceAssistant/Core ML Testing/MLTestingFramework.swift', 'r') as f:
    lines = f.readlines()

brace_count = 0
line_braces = []

for i, line in enumerate(lines, 1):
    line_brace_change = 0
    for char in line:
        if char == '{':
            brace_count += 1
            line_brace_change += 1
        elif char == '}':
            brace_count -= 1
            line_brace_change -= 1
    
    if line_brace_change != 0:
        line_braces.append((i, line_brace_change, brace_count, line.strip()))

print('Lines with brace changes around the problematic area:')
for line_num, change, total, content in line_braces:
    if line_num >= 1200:
        print(f'Line {line_num}: {change:+d} (total: {total}) - {content[:80]}')
    
    if line_num >= 1280:
        break

print(f'Final brace count at line 1280: {brace_count}')