/* Userland-only glue that has no v7 counterpart we can port directly:
 *   - open() defaults the mode arg the v7 kernel does not take;
 *   - dup() encodes v7's dup2 protocol (high bit set => second fd);
 *   - execve/execl marshal argv and envp for the flat exec bridge;
 *   - popen/pclose layer pipe+fork+exec on top of the syscalls;
 *   - sbrk/brk are a userland bump allocator -- the kernel's break(2)
 *     (sysent[17] = sys_break_v7) only adjusts u.u_dsize bookkeeping
 *     since on this port copyseg/clearseg are no-ops (all procs stay
 *     resident), so there is no benefit to routing through it;
 *   - time/ftime/alarm/pause/sleep route through the real kernel paths
 *     (sysent[13,35,27,29] -> sys/v7_bridge.c -> sys/sys4.c).
 */
#include <stdarg.h>

#define	S_EXIT		1
#define	S_FORK		2
#define	S_CLOSE		6
#define	S_OPEN		5
#define	S_EXEC		11
#define	S_DUP		41
#define	S_PIPE		42
#define	S_WAIT		7
#define	S_TIME		13	/* gtime: returns kernel `time` global */
#define	S_STIME		25	/* stime: write kernel `time` global */
#define	S_ALARM		27	/* alarm: schedule SIGALRM in n sec */
#define	S_PAUSE		29	/* pause: sleep until any signal */
#define	S_STTY		31
#define	S_GTTY		32
#define	S_FTIME		35	/* ftime: copyout struct timeb */

int syscall3(int n, int a, int b, int c);
extern char **environ;

/* exit flushes buffered stdio (via _cleanup) before trapping; the
 * raw kernel trap is exposed as _exit by sys.s. */
extern void _exit(int n);
extern void _cleanup(void);

void
exit(int n)
{

	_cleanup();
	_exit(n);
}

int
open(char *path, int mode)
{

	(void)mode;
	return(syscall3(S_OPEN, (int)path, 0, 0));
}

int
dup(int a, int b)
{

	if(a & 0100)
		return(syscall3(S_DUP, a & ~0100, b, 0));
	return(syscall3(S_DUP, a, -1, 0));
}

int
execve(char *path, char **argv, char **envp)
{

	return(syscall3(S_EXEC, (int)path, (int)argv, (int)envp));
}

int
execv(char *path, char **argv)
{

	return(syscall3(S_EXEC, (int)path, (int)argv, (int)environ));
}

int
execl(char *path, char *arg0, ...)
{
	va_list ap;
	char *argv[16];
	int i;

	argv[0] = arg0;
	va_start(ap, arg0);
	for(i=1; i<15; i++)
		if((argv[i] = va_arg(ap, char *)) == 0)
			break;
	argv[i] = 0;
	va_end(ap);
	return(syscall3(S_EXEC, (int)path, (int)argv, (int)environ));
}

typedef struct {
	int fd;
} FILE;

FILE *
popen(char *cmd, char *mode)
{
	static FILE f;
	int fd[2];
	char *argv[4];

	if(*mode != 'r')
		return(0);
	if(syscall3(S_PIPE, (int)fd, 0, 0) < 0)
		return(0);
	if(syscall3(S_FORK, 0, 0, 0) == 0) {
		(void)syscall3(S_CLOSE, fd[0], 0, 0);
		(void)syscall3(S_DUP, fd[1], 1, 0);
		argv[0] = "sh";
		argv[1] = "-c";
		argv[2] = cmd;
		argv[3] = 0;
		(void)syscall3(S_EXEC, (int)"/bin/sh", (int)argv, 0);
		(void)syscall3(S_EXIT, 1, 0, 0);
	}
	(void)syscall3(S_CLOSE, fd[1], 0, 0);
	f.fd = fd[0];
	return(&f);
}

int
pclose(FILE *f)
{

	(void)syscall3(S_CLOSE, f->fd, 0, 0);
	return(syscall3(S_WAIT, 0, 0, 0));
}

/* getpid(2) and getppid(2): now real syscall stubs in lib/sys.s -- both
 * fire SYS_getpid=20 and the assembler glue picks r0 (pid) or r1 (ppid)
 * off the return.  The libc stub here has been retired. */

int
gtty(int fd, char *buf)
{

	return(syscall3(S_GTTY, fd, (int)buf, 0));
}

/* ioctl(2): now a real syscall (slot 54).  Handles FIOCLEX, FIONCLEX,
 * TIOCGETP, TIOCSETP in arch/arm.c::sys_ioctl_v7.  Defined in
 * lib/sys.s; the libc stub below has been retired. */

int
stty(int fd, char *buf)
{

	return(syscall3(S_STTY, fd, (int)buf, 0));
}

/* alarm(n): schedule SIGALRM in n seconds; returns the previous
 * timer's remaining value.  syscall3 returns the kernel's u_rval1 which
 * v7 alarm() stuffs with the prior p_clktim. */
int
alarm(int n)
{

	return(syscall3(S_ALARM, n, 0, 0));
}

/* pause(): block until a signal is delivered.  Kernel pause() spins on
 * armboot's `pending` mask via WFI and sets u.u_error so the syscall
 * always returns -1 with errno=EINTR (matching v7 pause(2)). */
int
pause(void)
{

	return(syscall3(S_PAUSE, 0, 0, 0));
}

/* sleep(n): mirror v7 libc/gen/sleep.c.  Installs a SIGALRM handler
 * that longjmps out of pause() so the alarm fires don't terminate the
 * process under SIG_DFL semantics.  Restores prior disposition and
 * any prior alarm() value before returning. */
#include <setjmp.h>
static jmp_buf sleep_jmp;
static void sleepx(int signo)
{
	(void)signo;
	longjmp(sleep_jmp, 1);
}
extern int signal(int sig, void (*fun)(int));
unsigned
sleep(unsigned n)
{
	unsigned altime;
	void (*alsig)(int) = (void (*)(int))0;	/* SIG_DFL */

	if(n == 0)
		return(0);
	altime = (unsigned)alarm(1000);	/* time to maneuver */
	if(setjmp(sleep_jmp)) {
		(void)signal(14 /* SIGALRM */, alsig);
		(void)alarm((int)altime);
		return(0);
	}
	if(altime) {
		if(altime > n)
			altime -= n;
		else {
			n = altime;
			altime = 1;
		}
	}
	alsig = (void (*)(int))(long)signal(14 /* SIGALRM */, sleepx);
	(void)alarm((int)n);
	for(;;)
		(void)pause();
	/*NOTREACHED*/
}


/* nice(2): now a real syscall (slot 34, sys/sys4.c::nice).  Defined in
 * lib/sys.s -- the libc stub used to ignore its argument. */

/* setgid/getgid: now real syscalls (slots 46/47, sys/sys4.c).
 * Defined in lib/sys.s; the compat.c stubs that always returned 0
 * have been retired. */

void
abort(void)
{

	_exit(1);
}

/* times(2): now a real syscall (slot 43, sys/sys4.c::times).  The
 * kernel copies u.u_utime/u_stime/u_cutime/u_cstime out to the
 * 4-time_t buffer pointed at by t.  Defined in lib/sys.s. */

/* time(t): return kernel `time` global (seconds since the 1970 epoch).
 * syscall3 invokes sys/sys4.c::gtime() through v7_bridge.c.  On 32-bit
 * ARM time_t is 32 bits, so r0 already carries the full value. */
int
time(long *t)
{
	long now;

	now = (long)syscall3(S_TIME, 0, 0, 0);
	if(t)
		*t = now;
	return(now);
}

/* stime(t): set the kernel `time` global.  Suser-only in v7; our
 * S_STIME bridge in sys/v7_bridge.c::v7_stime_call pre-seeds
 * u.u_uid=0 so the suser() check passes for the single-user shell. */
int
stime(long *t)
{

	(void)syscall3(S_STIME, t ? (int)*t : 0, 0, 0);
	return(0);
}

/* ftime(t): copy out a struct timeb with the kernel's current time/
 * millitm/timezone/dstflag.  The kernel side (sys/sys4.c::ftime) is
 * wired through sys/v7_bridge.c::v7_ftime_call. */
#include <sys/timeb.h>
int
ftime(struct timeb *t)
{

	return(syscall3(S_FTIME, (int)t, 0, 0));
}

char end[1];
static char *curbrk = (char *)0x00050000;

char *
sbrk(int n)
{
	char *old;

	old = curbrk;
	curbrk += n;
	return(old);
}

int
brk(char *p)
{

	curbrk = p;
	return(0);
}
