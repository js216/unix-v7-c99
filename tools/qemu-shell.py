#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# qemu-shell.py --- one-shot V7-on-qemu shell driver
# Copyright (c) 2026 Jakob Kastelic
#
# Boots a fresh `qemu-system-arm` instance, logs in as root, and pipes
# stdin into V7's shell as if typed at the terminal.  Writes the
# captured serial console (with CRs stripped) to stdout, then quits
# qemu.  Each invocation is a clean V7 boot with -snapshot, so no
# state leaks between calls.
#
# Stdin MUST end with `echo __TEST_DONE__` -- the wrapper waits for
# that sentinel to appear in V7's output twice (once as typed-echo,
# once as program-output) before stopping capture and quitting qemu.

import os
import sys

import pexpect

SENTINEL = '__TEST_DONE__'


def main():
    here = os.path.dirname(os.path.realpath(__file__))
    root = os.path.abspath(os.path.join(here, '..'))
    kernel = os.path.join(root, 'unix')
    rootimg = os.path.join(root, 'root.img')
    qemu = pexpect.spawn(
        'qemu-system-arm',
        ['-machine', 'virt', '-cpu', 'cortex-a7', '-nographic',
         '-no-reboot', '-snapshot', '-kernel', kernel,
         '-drive', f'if=none,file={rootimg},format=raw,id=hd0',
         '-device', 'virtio-blk-device,drive=hd0'],
        timeout=300, encoding=None)
    if os.environ.get('QEMU_LOG'):
        qemu.logfile_read = open(os.environ['QEMU_LOG'], 'wb')

    qemu.expect(b'login:')
    qemu.send(b'root\r')
    qemu.expect_exact(b'# ')

    for line in sys.stdin.read().splitlines():
        qemu.send((line + '\r').encode())

    sent_b = SENTINEL.encode()
    captured = b''
    for _ in range(2):
        qemu.expect_exact(sent_b)
        captured += qemu.before + qemu.after
    qemu.expect_exact(b'# ')
    captured += qemu.before + qemu.after

    qemu.terminate(force=True)
    # Strip backspaces (0x08).  arch/v7stubs.c::pause_spin_barrier writes
    # one \b per spin iteration to advance qemu's virtual-time machinery
    # during sleep()/pause(); kernel time wouldn't advance otherwise.  The
    # hack works (sleep semantics are correct) but emits ~150 KB of \b per
    # sleep(1).  They're invisible on an interactive terminal but pollute
    # captured output for these regression tests, so we drop them here.
    sys.stdout.buffer.write(captured.replace(b'\r', b'').replace(b'\x08', b''))


if __name__ == '__main__':
    main()
