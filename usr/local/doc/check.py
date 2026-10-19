#!/usr/bin/env python3
# Every #source file in commentary.typ must be shown by its #lines and
# #lines-to fragments exactly once, contiguously and in order.  Run from
# anywhere.
import re, os
d = os.path.dirname(os.path.abspath(__file__))
root = os.path.abspath(os.path.join(d, '../../..'))
src = open(os.path.join(d, 'commentary.typ')).read()
src = re.sub(r'(?m)^#include "([^"]+\.typ)"', lambda m: open(os.path.join(d, m.group(1))).read(), src)
ok = True; cur = None; nxt = total = 0; text = []
def done():
    global ok
    if cur and nxt <= total:
        print(f'{cur}: lines {nxt}..{total} not shown'); ok = False
pat = (r'#source\("([^"]+)"\)|#lines\((\d+),\s*(\d+)\)|listing\('
       r'|#lines-to\((none|"((?:[^"\\]|\\.)*)"(?:,\s*lead:\s*(true|false))?)\)')
for m in re.finditer(pat, src):
    if m.group(4):
        # lines-to: up to the line before the next one beginning with the
        # needle; with lead, the blank lines before it go to the next fragment
        if m.group(4) == 'none':
            b = total
        else:
            needle = re.sub(r'\\(.)', r'\1', m.group(5))
            hits = [i for i in range(nxt, total + 1) if text[i-1].strip().startswith(needle)]
            if not hits:
                print(f'{cur}: no line after {nxt} begins with {needle!r}'); ok = False
                continue
            b = hits[0] - 1
            if m.group(6) == 'true':
                while b >= nxt and not text[b-1].strip():
                    b -= 1
        if b < nxt - 1: print(f'{cur}: empty fragment before {m.group(4)}'); ok = False
        nxt = b + 1
    elif m.group(1):
        done(); cur = m.group(1); nxt = 1
        text = open(root + cur).read().rstrip('\n').split('\n')
        total = len(text)
    elif m.group(2):
        a, b = int(m.group(2)), int(m.group(3))
        if a != nxt: print(f'{cur}: fragment starts at {a}, expected {nxt}'); ok = False
        if b < a or b > total: print(f'{cur}: bad range {a},{b} (file has {total})'); ok = False
        nxt = b + 1
done()
for m in re.finditer(r'(?<!`)`(?!`)([^`]*?)`(?!`)', src):
    if '\n' in m.group(1):
        print(f'line {src.count(chr(10), 0, m.start()) + 1}: inline code spans a line break'); ok = False
print('OK' if ok else 'FAILED')
