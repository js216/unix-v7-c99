#!/bin/sh
# SPDX-License-Identifier: MIT
# qemu-shell.sh --- drive the C99 unix kernel under qemu-system-arm
# Copyright (c) 2026 Jakob Kastelic
#
# Usage:
#   qemu-shell.sh <log-path> <sentinel> [<v7-command>]
#
#   <log-path>     path to capture the qemu serial console into.  The
#                  file is truncated before launch.
#   <sentinel>     boot succeeds once this exact string appears in the
#                  captured log.
#   <v7-command>   optional.  When given, the wrapper drives the
#                  console through `login: -> root -> # -> <v7-command>`
#                  before waiting for the sentinel.  When omitted, the
#                  wrapper just waits for the sentinel (useful for
#                  banner / kernel-boot tests).
#
# A wall-clock timeout protects against a wedged kernel; default 90s,
# override via QEMU_SHELL_TIMEOUT_S.  Exit status is always 0 -- the
# verifier reads the captured log.
set -u

if [ $# -lt 2 ] || [ $# -gt 3 ]; then
	echo "usage: $0 <log-path> <sentinel> [<v7-command>]" >&2
	exit 2
fi

log_path=$1
sentinel=$2
v7_command=${3-}
timeout_s=${QEMU_SHELL_TIMEOUT_S:-90}

here=$(dirname -- "$0")
root=$(cd -- "$here/.." && pwd)

rm -f "$log_path"
: > "$log_path"

KERNEL=$root/unix
ROOT_IMG=$root/root.img
LOG=$log_path
SENTINEL=$sentinel
V7_COMMAND=$v7_command

export KERNEL ROOT_IMG LOG SENTINEL V7_COMMAND

timeout "$timeout_s" expect -c '
	set kernel    $env(KERNEL)
	set root_img  $env(ROOT_IMG)
	set log_path  $env(LOG)
	set sentinel  $env(SENTINEL)
	set v7_cmd    $env(V7_COMMAND)

	log_user 0
	log_file -a $log_path
	set timeout 60

	spawn -noecho qemu-system-arm -machine virt -cpu cortex-a7 -nographic -no-reboot -kernel $kernel -drive if=none,file=$root_img,format=raw,id=hd0 -device virtio-blk-device,drive=hd0

	if {$v7_cmd ne ""} {
		expect "login:"
		send "root\r"
		expect "# "
		send "$v7_cmd\r"
	}

	expect -exact $sentinel

	if {$v7_cmd ne ""} {
		expect "# "
		send "sync\r"
		expect "# "
		send "exit\r"
	}

	# Ctrl-A x: qemu monitor "quit" in -nographic stdio mode.
	sleep 0.5
	send "\x01x"
	expect eof
' >/dev/null 2>&1 || true

exit 0
