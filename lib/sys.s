@ Per-syscall stubs.  Each entry is the ARM-EABI equivalent of v7's
@ libc/sys/<name>.s -- it loads r7 with the v7 syscall number and
@ traps via svc, leaving the args already in r0..r3.  Only syscalls
@ the kernel actually services (see arch/armboot.c trap()) appear
@ here; unimplemented or trivially-stubbed calls stay in compat.c.

.macro SYS name, num
.globl \name
\name:
	mov ip, r7
	mov r7, #\num
	svc #0
	mov r7, ip
	bx lr
.endm

SYS _exit,    1
SYS fork,     2
SYS read,     3
SYS write,    4
SYS close,    6
SYS wait,     7
SYS creat,    8
SYS link,     9
SYS unlink,  10
SYS chdir,   12
SYS mknod,   14
SYS chmod,   15
SYS chown,   16
SYS stat,    18
SYS lseek,   19
SYS mount,   21
SYS umount,  22
SYS setuid,  23
SYS getuid,  24
SYS fstat,   28
SYS access,  33
SYS sync,    36
SYS kill,    37
SYS pipe,    42
SYS umask,   60
SYS utime,   30
SYS signal,  48
SYS getdents, 141
SYS spawn,    200
SYS sigreturn, 139

