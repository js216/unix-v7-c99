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
STR = r'"((?:[^"\\]|\\.)*)"'
pat = (r'#source\("([^"]+)"\)|#lines\((\d+),\s*(\d+)\)|listing\('
       r'|#lines-to\((none|' + STR + r'((?:,\s*(?:lead:\s*(?:true|false)|exact:\s*(?:true|false)|after:\s*' + STR + r'))*))\)')
def unesc(t):
    return re.sub(r'\\(.)', lambda m: {'t': '\t', 'n': '\n'}.get(m.group(1), m.group(1)), t)
for m in re.finditer(pat, src):
    if m.group(4):
        # lines-to: up to the line before the next one beginning with the
        # needle; with lead, the blank lines before it go to the next fragment
        if m.group(4) == 'none':
            b = total
        else:
            needle = unesc(m.group(5))
            opts = m.group(6) or ''
            start = nxt
            am = re.search(r'after:\s*' + STR, opts)
            if am:
                anchor = unesc(am.group(1))
                ah = [i for i in range(nxt, total + 1) if text[i-1].strip().startswith(anchor)]
                if not ah:
                    print(f'{cur}: no line after {nxt} begins with {anchor!r}'); ok = False
                    continue
                start = ah[0] + 1
            exact = re.search(r'exact:\s*true', opts)
            hits = [i for i in range(start, total + 1)
                    if (text[i-1].strip() == needle if exact else text[i-1].strip().startswith(needle))]
            if not hits:
                print(f'{cur}: no line after {nxt} begins with {needle!r}'); ok = False
                continue
            b = hits[0] - 1
            if re.search(r'lead:\s*true', opts):
                while b >= nxt and not text[b-1].strip():
                    b -= 1
        if b < nxt: print(f'{cur}: empty fragment before {m.group(4)}'); ok = False
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
# the strings given to #l, #at, and #lines-to are source text, not markup
prose = re.sub(r'((?:#l\(|#at\(|#lines-to\(|after:\s*|,\s*)' + STR + ')', lambda m: m.group(0)[:m.group(0).index('"')] + '"' + ' ' * (len(m.group(2))) + '"', src)
for m in re.finditer(r'(?<!`)`(?!`)([^`]*?)`(?!`)', prose):
    if '\n' in m.group(1):
        print(f'line {src.count(chr(10), 0, m.start()) + 1}: inline code spans a line break'); ok = False
print('OK' if ok else 'FAILED')
