#!/bin/sh
# SPDX-License-Identifier: MIT
# qemu-shell.sh --- drive the C99 unix kernel under qemu-system-arm
# Copyright (c) 2026 Jakob Kastelic
#
# Usage: tools/qemu-shell.sh <log-path> [<script-name>]
#
#   <log-path>     path to capture the qemu serial console into. The
#                  file is truncated before launch so verifiers never
#                  see stale content from a prior section.
#   <script-name>  optional, default "shell". Selects the driver
#                  fixture at tools/qemu/<script-name>.expect, which
#                  waits for login:, sends root\r, waits for # , runs
#                  the per-fixture command set, then sends sync\r and
#                  exit\r.
#
# A hard wall-clock timeout protects against a wedged kernel; default
# 90s, override via QEMU_SHELL_TIMEOUT_S. The wrapper's exit status
# is intentionally not propagated -- the verifier reads the captured
# log instead, since "expect timed out" is itself a useful failure
# mode worth recording.
set -u

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
	echo "usage: $0 <log-path> [<script-name>]" >&2
	exit 2
fi

log_path=$1
script_name=${2:-shell}
timeout_s=${QEMU_SHELL_TIMEOUT_S:-90}

here=$(dirname -- "$0")
root=$(cd -- "$here/.." && pwd)
fixture=$here/qemu/$script_name.expect

if [ ! -f "$fixture" ]; then
	echo "$0: no fixture at $fixture" >&2
	exit 2
fi

: > "$log_path"

KERNEL=$root/unix
ROOT_IMG=$root/root.img
LOG=$log_path

export KERNEL ROOT_IMG LOG

timeout "$timeout_s" expect -f "$fixture" >/dev/null 2>&1 || true
exit 0
