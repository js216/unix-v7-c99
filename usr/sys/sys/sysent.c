#include "../h/param.h"
#include "../h/systm.h"
#include "../h/dir.h"
#include "../h/user.h"
#include "../h/proc.h"
#include "../h/reg.h"
#include "../h/inode.h"
#include "../h/file.h"
#include "../h/tty.h"
#include "../h/seg.h"
void nullsys(void), nosys(void);
void rexit(void), fork(void), read(void), write(void), open(void);
void close(void), wait(void), creat(void), link(void), unlink(void);
void exec(void), exece(void), chdir(void), gtime(void), mknod(void);
void chmod(void), chown(void), sbreak(void), stat(void), seek(void);
void getpid(void), smount(void), sumount(void), setuid(void), getuid(void);
void stime(void), ptrace(void), alarm(void), fstat(void), pause(void);
void utime(void), saccess(void), nice(void), ftime(void), sync(void);
void kill(void), dup(void), pipe(void), times(void), profil(void);
void setgid(void), getgid(void), ssig(void), sysacct(void), syslock(void);
void umask(void), chroot(void), stty(void), gtty(void), ioctl(void);
void sigreturn(void);
int issig(void);
void psig(void);
void psignal(struct proc *p, int sig);
int setpri(struct proc *pp);
void qswtch(void);
void panic(char *s);
void printf(char *fmt, ...);
int save(int *lp) __attribute__((returns_twice));
void bcopy(char *from, char *to, unsigned int n);
struct ttiocb console_sgtty = {
	13, 13, '#', '@', EVENP|ODDP|ECHO|CRMOD|XTABS
};

/*
 * This table is the switch used to transfer
 * to the appropriate routine for processing a system call.
 * Each row contains the number of arguments expected
 * and a pointer to the routine.
 * On Armv7 all arguments arrive in registers, so
 * sy_nrarg == sy_narg for every entry.
 */

struct sysent sysent[64] =
{
	{0, 0, nullsys},		/*  0 = indir */
	{1, 1, rexit},			/*  1 = exit */
	{0, 0, fork},			/*  2 = fork */
	{3, 3, read},			/*  3 = read */
	{3, 3, write},			/*  4 = write */
	{3, 3, open},			/*  5 = open */
	{1, 1, close},			/*  6 = close */
	{0, 0, wait},			/*  7 = wait */
	{2, 2, creat},			/*  8 = creat */
	{2, 2, link},			/*  9 = link */
	{1, 1, unlink},			/* 10 = unlink */
	{2, 2, exec},			/* 11 = exec */
	{1, 1, chdir},			/* 12 = chdir */
	{0, 0, gtime},			/* 13 = time */
	{3, 3, mknod},			/* 14 = mknod */
	{2, 2, chmod},			/* 15 = chmod */
	{3, 3, chown},			/* 16 = chown */
	{1, 1, sbreak},			/* 17 = break */
	{2, 2, stat},			/* 18 = stat */
	{3, 3, seek},			/* 19 = seek */
	{0, 0, getpid},			/* 20 = getpid */
	{3, 3, smount},			/* 21 = mount */
	{1, 1, sumount},		/* 22 = umount */
	{1, 1, setuid},			/* 23 = setuid */
	{0, 0, getuid},			/* 24 = getuid */
	{1, 1, stime},			/* 25 = stime */
	{4, 4, ptrace},			/* 26 = ptrace */
	{1, 1, alarm},			/* 27 = alarm */
	{2, 2, fstat},			/* 28 = fstat */
	{0, 0, pause},			/* 29 = pause */
	{2, 2, utime},			/* 30 = utime */
	{2, 2, stty},			/* 31 = stty */
	{2, 2, gtty},			/* 32 = gtty */
	{2, 2, saccess},		/* 33 = access */
	{1, 1, nice},			/* 34 = nice */
	{1, 1, ftime},			/* 35 = ftime */
	{0, 0, sync},			/* 36 = sync */
	{2, 2, kill},			/* 37 = kill */
	{0, 0, nullsys},		/* 38 = switch; inoperative */
	{0, 0, nullsys},		/* 39 = setpgrp (not in yet) */
	{0, 0, nosys},			/* 40 = tell (obsolete) */
	{2, 2, dup},			/* 41 = dup */
	{0, 0, pipe},			/* 42 = pipe */
	{1, 1, times},			/* 43 = times */
	{4, 4, profil},			/* 44 = prof */
	{0, 0, nosys},			/* 45 = unused */
	{1, 1, setgid},			/* 46 = setgid */
	{0, 0, getgid},			/* 47 = getgid */
	{2, 2, ssig},			/* 48 = sig */
	{0, 0, nosys},			/* 49 = reserved for USG */
	{0, 0, nosys},			/* 50 = reserved for USG */
	{1, 1, sysacct},		/* 51 = turn acct off/on */
	{0, 0, nosys},			/* 52 = set user physical addresses */
	{1, 1, syslock},		/* 53 = lock user in core */
	{3, 3, ioctl},			/* 54 = ioctl */
	{0, 0, nosys},			/* 55 = readwrite (in abeyance) */
	{0, 0, nosys},			/* 56 = creat mpx comm channel */
	{0, 0, nosys},			/* 57 = reserved for USG */
	{0, 0, nosys},			/* 58 = reserved for USG */
	{3, 3, exece},			/* 59 = exece */
	{1, 1, umask},			/* 60 = umask */
	{1, 1, chroot},			/* 61 = chroot */
	{0, 0, nosys},			/* 62 = x */
	{0, 0, sigreturn}		/* 63 = sigreturn (Armv7 signal trampoline) */
};
char	regloc[9] = { R0, R1, R2, R3, R4, R5, R6, R7, RPS };
/*
 * Called from svc_entry (conf/l.s) on a system call.  r is the 17-int
 * trap frame; the syscall number is in r7 (Armv7 ABI), arguments in
 * r0..r5.  Adapted from v7 trap.c case 6+USER plus the out: tail.
 */
void
trap(int *r)
{
	register int i;
	register struct sysent *callp;
	u.u_fpsaved = 0;
	u.u_ar0 = r;
	u.u_error = 0;
	callp = &sysent[r[7] & 077];	/* Armv7 syscall number is in r7 */
	for(i = 0; i < callp->sy_narg && i < 6; i++)
		u.u_arg[i] = r[i];
	u.u_dirp = (caddr_t)u.u_arg[0];
	/*
	 * Default the return registers to 0.  V7 seeded r_val1 from the
	 * incoming r0 and relied on each libc stub to `clr r0` on the
	 * success path; this port's libc returns the raw syscall register
	 * via syscall3, so a call that leaves r_val1 unset (access, chdir,
	 * close, ...) must yield 0 to mean success.
	 */
	u.u_r.r_val1 = 0;
	u.u_r.r_val2 = 0;
	u.u_ap = u.u_arg;
	if (save(u.u_qsav)) {
		if (u.u_error == 0)
			u.u_error = EINTR;
	} else {
		(*callp->sy_call)();
	}
	if (u.u_error)
		r[R0] = -u.u_error;
	else {
		r[R0] = u.u_r.r_val1;
		r[R1] = u.u_r.r_val2;
	}
	/* out: deliver signals and reschedule before returning to user */
	if (issig())
		psig();
	(void)setpri(u.u_procp);
	if (runrun)
		qswtch();
}
/*
 * Called from the undef/abort entry stubs (conf/l.s) for a hardware
 * fault.  signo is the signal it maps to; r is the trap frame.  A fault
 * taken in kernel mode is fatal.
 */
void
user_trap_handler(int signo, int *r)
{
	int mode = r[RPS] & 0x1f;
	if(mode != 0x10 && mode != 0x1f) {
		unsigned int dfar, dfsr;
		__asm__ volatile("mrc p15,0,%0,c6,c0,0":"=r"(dfar));
		__asm__ volatile("mrc p15,0,%0,c5,c0,0":"=r"(dfsr));
		printf("kernel trap sig=%d pc=0x%x cpsr=0x%x dfar=0x%x dfsr=0x%x\n",
		    signo, r[15], r[RPS], dfar, dfsr);
		panic("kernel trap");
	}
	u.u_fpsaved = 0;
	u.u_ar0 = r;
	psignal(u.u_procp, signo);
	if (issig())
		psig();
	(void)setpri(u.u_procp);
	if (runrun)
		qswtch();
}
void nosys(void)   { u.u_error = EINVAL; }
void nullsys(void) { }
/*
 * Console line discipline control (stty/gtty/ioctl).  This port has a
 * single console and no general tty layer, so these operate on the
 * console_sgtty block.
 */
static int
is_tty_fd(int fd)
{
	struct file *fp;
	if(fd < 0 || fd >= NOFILE)
		return(0);
	fp = u.u_ofile[fd];
	if(fp == NULL || fp->f_inode == NULL)
		return(0);
	return((fp->f_inode->i_mode & IFMT) == IFCHR);
}
void
stty(void)
{
	u.u_r.r_val1 = 0;
	if(!is_tty_fd(u.u_arg[0]) || u.u_arg[1] == 0) {
		u.u_error = ENOTTY;
		return;
	}
	bcopy((char *)u.u_arg[1], (char *)&console_sgtty, sizeof(console_sgtty));
}
void
gtty(void)
{
	u.u_r.r_val1 = 0;
	if(!is_tty_fd(u.u_arg[0]) || u.u_arg[1] == 0) {
		u.u_error = ENOTTY;
		return;
	}
	bcopy((char *)&console_sgtty, (char *)u.u_arg[1], sizeof(console_sgtty));
}
void
ioctl(void)
{
	int fd = u.u_arg[0], cmd = u.u_arg[1];
	char *arg = (char *)u.u_arg[2];
	u.u_r.r_val1 = 0;
	if(fd < 0 || fd >= NOFILE || u.u_ofile[fd] == NULL) {
		u.u_error = EBADF;
		return;
	}
	switch(cmd) {
	case FIOCLEX:
		u.u_pofile[fd] |= EXCLOSE;
		return;
	case FIONCLEX:
		u.u_pofile[fd] &= ~EXCLOSE;
		return;
	case TIOCGETP:
	case TIOCSETP:
		if(!is_tty_fd(fd) || arg == 0) {
			u.u_error = ENOTTY;
			return;
		}
		if(cmd == TIOCGETP)
			bcopy((char *)&console_sgtty, arg, sizeof(console_sgtty));
		else
			bcopy(arg, (char *)&console_sgtty, sizeof(console_sgtty));
		return;
	}
	u.u_error = ENOTTY;
}
