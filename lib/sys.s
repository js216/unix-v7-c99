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
	cmp r0, #0
	bxge lr
	rsb r1, r0, #0
	ldr r2, =errno
	str r1, [r2]
	mvn r0, #0
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
SYS setgid,  46
SYS getgid,  47
SYS fstat,   28
SYS access,  33
SYS nice,    34
SYS sync,    36
SYS kill,    37
SYS pipe,    42
SYS times,   43
SYS profil,  44
SYS ioctl,   54
SYS umask,   60
SYS utime,   30
SYS signal,  48
SYS acct,    51
SYS lock,    53
SYS chroot,  61
SYS ptrace,  26
SYS sigreturn, 139

@ getpid(2) returns pid in r0 *and* ppid in r1 (v7's two-return-value
@ convention).  Standard SYS macro discards r1; provide a wrapper here
@ that issues getpid via syscall 20 and recovers r1 into a global so a
@ getppid() libc shim can pick it up.  Also a getpid alias for symmetry.
.globl getpid
getpid:
	mov ip, r7
	mov r7, #20
	svc #0
	mov r7, ip
	ldr r2, =_last_ppid
	str r1, [r2]
	bx lr
.globl getppid
getppid:
	mov ip, r7
	mov r7, #20
	svc #0
	mov r7, ip
	mov r0, r1
	bx lr

@ v7 getuid(2) returns real uid in r0, effective uid in r1.  Provide
@ geteuid() / getegid() wrappers that fire getuid/getgid and pick r1.
.globl geteuid
geteuid:
	mov ip, r7
	mov r7, #24
	svc #0
	mov r7, ip
	mov r0, r1
	bx lr

.globl getegid
getegid:
	mov ip, r7
	mov r7, #47
	svc #0
	mov r7, ip
	mov r0, r1
	bx lr

.data
.globl _last_ppid
_last_ppid: .word 0
