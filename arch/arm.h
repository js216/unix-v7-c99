#ifndef ARM_H
#define ARM_H

#define KERNBASE	0x40000000U
#define USERBASE	0x00000000U
/* USERPHYS is the physical address backing the user-mode 1 MB window
 * mapped at USERBASE.  Must sit above the kernel image's __bss_end:
 * the kernel is loaded at KERNBASE=0x40000000, has ~5 MB of code+data
 * plus ~20+ MB of per-proc save-pool BSS, so anchor USERPHYS at
 * 0x44000000 to leave room.  At 128 MB total RAM (qemu-virt default)
 * physical extends through 0x48000000, comfortable margin. */
#define USERPHYS	0x44000000U
#define USERSIZE	0x00100000U
#define UENTRY		0x00010000U
#define USTACK		0x000f0000U

/* v7 syscall numbers.  The full set is dispatched via sysent[] in
 * armboot.c by numeric index, so most have no symbolic alias.  Only
 * the ones the trap/scheduler intercepts inline (exit/fork/signal/
 * sigreturn) or that pipe-block uses for resume retry (read/write/
 * wait) need a name here. */
#define S_EXIT		1
#define S_FORK		2
#define S_READ		3
#define S_WRITE		4
#define S_WAIT		7
#define	S_SIGNAL	48
#define	S_SIGRETURN	139

#define	UARGV		0x0000f000U
/* Was 512.  Glob expansion of 100 entries against ~8-byte filenames
 * blew this and sh truncated.  Max usable is UENTRY_SIGTRAMP - UARGV
 * = 0xfe00 - 0xf000 = 3584 bytes.  3072 leaves 512 bytes of headroom. */
#define	UARGLEN		3072

/*
 * Fixed user-VA "vDSO" page used to host the signal-return trampoline.
 * The kernel writes a 2-instruction `mov r7, #139; svc #0` stub here on
 * every successful exec so the per-process handler's `bx lr` lands on
 * code that can ask the kernel to pop the saved trap frame.  The
 * address must sit in the user 1MB section but outside both the loaded
 * binary (>= UENTRY) and the argv buffer (UARGV..UARGV+UARGLEN).
 */
#define	UENTRY_SIGTRAMP	0x0000fe00U

#endif
