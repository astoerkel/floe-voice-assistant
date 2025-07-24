#!/usr/bin/env python3

with open('VoiceAssistant/Core ML Testing/MLTestingFramework.swift', 'r') as f:
    lines = f.readlines()

brace_count = 0
expected_class_level = 1  # After class opening brace

print('Tracking brace imbalances:')
for i, line in enumerate(lines, 1):
    prev_count = brace_count
    
    for char in line:
        if char == '{':
            brace_count += 1
        elif char == '}':
            brace_count -= 1
    
    # Print lines where brace count changes
    if prev_count != brace_count:
        change = brace_count - prev_count
        line_content = line.strip()[:80]
        
        # Flag suspicious patterns
        suspicious = ""
        if brace_count > expected_class_level + 1 and 'func ' in line and change > 0:
            suspicious = " [SUSPICIOUS: function starts at wrong level]"
        elif brace_count < expected_class_level and 'func ' not in line:
            suspicious = " [SUSPICIOUS: below class level]"
        
        print(f'Line {i}: {change:+d} (total: {brace_count}) - {line_content}{suspicious}')
        
        # Stop if we go too far
        if i > 1300:
            break

print(f'\nFinal analysis: Expected class level = {expected_class_level}, Current = {brace_count}')