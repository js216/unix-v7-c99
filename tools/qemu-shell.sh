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
#                  fixture at tools/qemu/<script-name>.expect.
#                  If no fixture exists with that name, the argument
#                  is treated as a sentinel string: qemu boots,
#                  waits for that string to appear in the serial
#                  log, then terminates immediately.
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

: > "$log_path"

KERNEL=$root/unix
ROOT_IMG=$root/root.img
LOG=$log_path

export KERNEL ROOT_IMG LOG

if [ -f "$fixture" ]; then
	timeout "$timeout_s" expect -f "$fixture" >/dev/null 2>&1 || true
else
	# Treat $script_name as a sentinel string.
	export SENTINEL="$script_name"
	timeout "$timeout_s" expect -c '
		set kernel $env(KERNEL)
		set root_img $env(ROOT_IMG)
		set log_path $env(LOG)
		set sentinel $env(SENTINEL)
		log_user 0
		log_file -a $log_path
		set timeout 60
		spawn -noecho qemu-system-arm \
			-machine virt -cpu cortex-a7 -nographic -no-reboot \
			-kernel $kernel \
			-drive if=none,file=$root_img,format=raw,id=hd0 \
			-device virtio-blk-device,drive=hd0
		expect {
			timeout { exit 1 }
			"$sentinel"
		}
		sleep 0.1
		send "\x01x"
		expect eof
	' >/dev/null 2>&1 || true
fi
exit 0
