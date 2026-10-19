import sys, time, usb.core, usb.util

def find(timeout=0):
    t = time.time()
    while True:
        d = usb.core.find(idVendor=0x0483, idProduct=0xdf11)
        if d or time.time() - t >= timeout:
            return d
        time.sleep(0.05)

def status(d):
    for k in range(50):
        s = bytes(d.ctrl_transfer(0xa1, 3, 0, 0, 6))
        if len(s) == 6:
            return s[0], s[4]
        time.sleep(0.05)
    sys.exit('no status')

def wait(d, what):
    t = time.time()
    while time.time() - t < 3:
        st, state = status(d)
        if st or state in (2, 5):
            return st, state
        time.sleep(0.01)
    sys.exit('%s: stuck in state %d' % (what, state))

def phase(d):
    d.set_interface_altsetting(0, 1)
    ph = bytes(d.ctrl_transfer(0xa1, 2, 0, 0, 512))
    d.set_interface_altsetting(0, 0)
    return ph

def load(img):
    d = find(10)
    if not d:
        sys.exit('no DFU device')
    d.reset()
    time.sleep(0.5)
    d = find(10)
    ph = phase(d)
    if ph[0] != 1:
        sys.exit('phase %s, not FSBL' % ph.hex())
    for n, i in enumerate(range(0, len(img), 1024)):
        d.ctrl_transfer(0x21, 1, n, 0, img[i:i+1024])
        st, state = wait(d, 'block %d' % n)
        if st or state != 5:
            sys.exit('block %d: status %d state %d' % (n, st, state))
    d.ctrl_transfer(0x21, 1, 0, 0, None)
    st, state = wait(d, 'manifest')
    ph = phase(d)
    print('%d bytes, status %d state %d phase %s' %
          (len(img), st, state, ph.hex()))
    if st or ph[0] != 0:
        sys.exit('not accepted')
    d.ctrl_transfer(0x21, 0, 1000, 0, None)
    usb.util.dispose_resources(d)

if __name__ == '__main__':
    load(open(sys.argv[1], 'rb').read())
