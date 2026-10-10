import os, re, select, subprocess, sys, time

img, kernel, stepsfile = sys.argv[1:4]


def raw(s):
    return s.replace('\\n', '\n').replace('^D', '\x04').replace('^C', '\x7f')


steps = []
term = None
lines = open(stepsfile, encoding='latin1').read().rstrip('\n').split('\n')
for l in lines:
    if l.startswith('@'):
        e, s = l[1:].split('|', 1)
        e = re.sub(r'\\x([0-9a-f]{2})', lambda m: chr(int(m.group(1), 16)), e)
        steps.append((e, raw(s), ''))
        continue
    steps.append(('> ' if term else '# ', l + '\n',
        re.split(r'[^ -~]|@', l)[-1]))
    if term:
        if l == term:
            term = None
    else:
        m = re.search(r"<<\s*\\?'?([A-Za-z0-9_!]+)'?", l)
        if m:
            term = m.group(1)
if not lines[-1].startswith('@'):
    steps += [('# ', 'echo TEST""DONE\n', ''), ('TESTDONE', '', '')]

p = subprocess.Popen(['qemu-system-arm', '-machine', 'virt', '-cpu', 'cortex-a7', '-m', '512M',
    '-nographic', '-kernel', kernel,
    '-drive', 'if=none,file=%s,format=raw,id=hd0' % img,
    '-device', 'virtio-blk-device,drive=hd0'],
    stdin=subprocess.PIPE, stdout=subprocess.PIPE)
buf = b''
out = sys.stdout.buffer


def wait(pat, t):
    global buf
    pat = pat.encode('latin1')
    end = time.time() + t
    while True:
        if pat and pat in buf:
            buf = buf[buf.index(pat) + len(pat):]
            return True
        if time.time() >= end:
            return not pat
        r, _, _ = select.select([p.stdout], [], [], 0.2)
        if r:
            d = os.read(p.stdout.fileno(), 4096)
            if not d:
                return False
            out.write(d.replace(b'\r', b''))
            out.flush()
            buf += d


try:
    for exp, send, echo in steps:
        if exp and not wait(exp, 300):
            out.write(b'\n[timeout waiting for %r]\n' % exp.encode('latin1'))
            sys.exit(1)
        time.sleep(0.3)
        for ch in send.encode('latin1'):
            p.stdin.write(bytes([ch]))
            p.stdin.flush()
            time.sleep(0.005)
        if echo and not wait(echo, 300):
            out.write(b'\n[timeout waiting for echo %r]\n' % echo.encode('latin1'))
            sys.exit(1)
    wait('', 2)
finally:
    p.kill()
    p.wait()
