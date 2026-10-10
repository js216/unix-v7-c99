#!/usr/bin/env python3
# Every #source file in commentary.typ must be shown by its #lines fragments
# exactly once, contiguously and in order.  Run from anywhere.
import re, os
d = os.path.dirname(os.path.abspath(__file__))
root = os.path.abspath(os.path.join(d, '../../..'))
src = open(os.path.join(d, 'commentary.typ')).read()
ok = True; cur = None; nxt = total = 0
def done():
    global ok
    if cur and nxt <= total:
        print(f'{cur}: lines {nxt}..{total} not shown'); ok = False
for m in re.finditer(r'#source\("([^"]+)"\)|#lines\((\d+),\s*(\d+)\)|listing\(', src):
    if m.group(1):
        done(); cur = m.group(1); nxt = 1
        total = len(open(root + cur).read().rstrip('\n').split('\n'))
    elif m.group(2):
        a, b = int(m.group(2)), int(m.group(3))
        if a != nxt: print(f'{cur}: fragment starts at {a}, expected {nxt}'); ok = False
        if b < a or b > total: print(f'{cur}: bad range {a},{b} (file has {total})'); ok = False
        nxt = b + 1
done()
print('OK' if ok else 'FAILED')
