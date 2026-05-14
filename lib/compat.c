/* Userland-only glue that has no v7 counterpart we can port directly:
 *   - open() defaults the mode arg the v7 kernel does not take;
 *   - dup() encodes v7's dup2 protocol (high bit set => second fd);
 *   - execve/execl marshal argv and ignore envp;
 *   - popen/pclose layer pipe+fork+exec on top of the syscalls;
 *   - sbrk/brk are a userland bump allocator until the kernel grows a
 *     real break syscall;
 *   - alarm/pause/ioctl/gtty/stty/nice/getpid stub to harmless values
 *     because the arch/armboot.c trap() handler doesn't service them.
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

int syscall3(int n, int a, int b, int c);

/* exit flushes buffered stdio (via _cleanup) before trapping; the
 * raw kernel trap is exposed as _exit by sys.s. */
extern void _exit(int n);
extern void _cleanup(void);

void
exit(n)
int n;
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
dup(a, b)
int a, b;
{

	if(a & 0100)
		return(syscall3(S_DUP, a & ~0100, b, 0));
	return(syscall3(S_DUP, a, -1, 0));
}

int
execve(char *path, char **argv, char **envp)
{

	(void)envp;
	return(syscall3(S_EXEC, (int)path, (int)argv, 0));
}

int
execv(char *path, char **argv)
{

	return(syscall3(S_EXEC, (int)path, (int)argv, 0));
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
	return(syscall3(S_EXEC, (int)path, (int)argv, 0));
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

int
getpid(void)
{

	return(1);
}

int
gtty(int fd, char *buf)
{

	(void)fd; (void)buf;
	return(0);
}

int
ioctl(int fd, int cmd, char *arg)
{

	(void)fd; (void)cmd; (void)arg;
	return(0);
}

int
stty(int fd, char *buf)
{

	(void)fd; (void)buf;
	return(0);
}

int
alarm(int n)
{

	(void)n;
	return(0);
}

int
pause(void)
{

	return(0);
}

unsigned
sleep(n)
unsigned n;
{

	(void)n;
	return(0);
}

#include <grp.h>
struct group *
getgrnam(name)
char *name;
{
	static char *mem[] = { "root", 0 };
	static struct group gr = { "other", "", 0, mem };

	(void)name;
	return(&gr);
}

int
nice(int incr)
{

	(void)incr;
	return(0);
}

int
setgid(int gid)
{

	(void)gid;
	return(0);
}

int
getgid(void)
{

	return(0);
}

int
times(long *t)
{
	int i;

	for(i=0; i<4; i++)
		t[i] = 0;
	return(0);
}

int
time(long *t)
{

	if(t)
		*t = 0;
	return(0);
}

int
stime(long *t)
{

	(void)t;
	return(-1);
}

#include <sys/timeb.h>
int
ftime(struct timeb *t)
{

	t->time = 0;
	t->millitm = 0;
	t->timezone = 0;
	t->dstflag = 0;
	return(0);
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
