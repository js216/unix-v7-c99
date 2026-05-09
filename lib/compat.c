#include <stdarg.h>
#include <pwd.h>
#include <grp.h>

#define	S_EXIT		1
#define	S_FORK		2
#define	S_READ		3
#define	S_WRITE		4
#define	S_OPEN		5
#define	S_CLOSE		6
#define	S_WAIT		7
#define	S_CREAT		8
#define	S_UNLINK	10
#define	S_EXEC		11
#define	S_CHDIR		12
#define	S_STAT		18
#define	S_LSEEK		19
#define	S_FSTAT		28
#define	S_SYNC		36
#define	S_DUP		41
#define	S_PIPE		42
#define	S_KILL		37
#define	S_SIGNAL	48
#define	S_GETUID	24
#define	S_SETUID	23
#define	S_UMASK		60

int syscall3(int n, int a, int b, int c);
int strlen(char *s);
int strcmp(char *a, char *b);

/* strlen now lives in lib/strlen.c (real port of v7's libc/gen/strlen.c). */

static void
write1(char *s, int n)
{

	(void)syscall3(S_WRITE, 1, (int)s, n);
}

int
read(int fd, char *buf, int n)
{

	return(syscall3(S_READ, fd, (int)buf, n));
}

int
write(int fd, char *buf, int n)
{

	return(syscall3(S_WRITE, fd, (int)buf, n));
}

int
open(char *path, int mode)
{

	(void)mode;
	return(syscall3(S_OPEN, (int)path, 0, 0));
}

int
close(int fd)
{

	return(syscall3(S_CLOSE, fd, 0, 0));
}

int
stat(char *path, char *st)
{

	return(syscall3(S_STAT, (int)path, (int)st, 0));
}

int
fstat(int fd, char *st)
{

	return(syscall3(S_FSTAT, fd, (int)st, 0));
}

int
chdir(char *path)
{

	return(syscall3(S_CHDIR, (int)path, 0, 0));
}

int
dup(int a, int b)
{

	if(a & 0100)
		return(syscall3(S_DUP, a & ~0100, b, 0));
	return(syscall3(S_DUP, a, -1, 0));
}

int
fork(void)
{

	return(syscall3(S_FORK, 0, 0, 0));
}

int
wait(int *status)
{
	int w;

	w = 0;
	return(syscall3(S_WAIT, status ? (int)status : (int)&w, 0, 0));
}

int
execve(char *path, char **argv, char **envp)
{

	(void)envp;
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
creat(char *path, int mode)
{

	return(syscall3(S_CREAT, (int)path, mode, 0));
}

int
unlink(char *path)
{

	return(syscall3(S_UNLINK, (int)path, 0, 0));
}

int
pipe(int *fd)
{

	return(syscall3(S_PIPE, (int)fd, 0, 0));
}

void
sync(void)
{

	(void)syscall3(S_SYNC, 0, 0, 0);
}

long
lseek(int fd, long off, int whence)
{

	return(syscall3(S_LSEEK, fd, (int)off, whence));
}

int
getpid(void)
{

	return(1);
}

int
getuid(void)
{

	return(syscall3(S_GETUID, 0, 0, 0));
}

int
setuid(int uid)
{

	return(syscall3(S_SETUID, uid, 0, 0));
}

int
gtty(int fd, char *buf)
{

	(void)fd;
	(void)buf;
	return(0);
}

int
ioctl(int fd, int cmd, char *arg)
{

	(void)fd;
	(void)cmd;
	(void)arg;
	return(0);
}

int
signal(int sig, int fun)
{

	return(syscall3(S_SIGNAL, sig, fun, 0));
}

int
kill(int pid, int sig)
{

	return(syscall3(S_KILL, pid, sig, 0));
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

int
umask(int n)
{

	return(syscall3(S_UMASK, n, 0, 0));
}

int
times(long *t)
{
	int i;

	for(i=0; i<4; i++)
		t[i] = 0;
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

void
exit(int n)
{

	(void)syscall3(S_EXIT, n, 0, 0);
	for(;;)
		;
}

/* strcmp / atoi / atol now live in lib/strcmp.c, lib/atoi.c,
 * lib/atol.c (real ports of v7's libc/gen/{strcmp,atoi,atol}.c). */

int
isatty(int fd)
{

	return(fd >= 0 && fd <= 2);
}

char *
ttyname(int fd)
{

	return(fd == 0 ? "/dev/console" : 0);
}

void
putchar(int c)
{
	char b;

	b = (char)c;
	write1(&b, 1);
}

static void
fputs(char *s)
{

	write1(s, strlen(s));
}

static void
printn(long n, int b, int width, int zfill)
{
	long a;
	int c;

	if(n < 0) {
		putchar('-');
		n = -n;
	}
	a = n / b;
	if(a)
		printn(a, b, width ? width-1 : 0, zfill);
	else
		while(--width > 0)
			putchar(zfill ? '0' : ' ');
	c = (int)(n % b);
	putchar(c < 10 ? c + '0' : c - 10 + 'A');
}

int
printf(char *fmt, ...)
{
	va_list ap;
	char *p, *s;
	int width, lflag, zfill, prec;

	va_start(ap, fmt);
	for(p=fmt; *p; p++) {
		if(*p != '%') {
			putchar(*p);
			continue;
		}
		p++;
		width = 0;
		zfill = 0;
		if(*p == '0') {
			zfill++;
			p++;
		}
		while(*p >= '0' && *p <= '9')
			width = width * 10 + *p++ - '0';
		prec = -1;
		if(*p == '.') {
			p++;
			prec = 0;
			while(*p >= '0' && *p <= '9')
				prec = prec * 10 + *p++ - '0';
		}
		lflag = 0;
		if(*p == 'l') {
			lflag++;
			p++;
		}
		if(*p == 's') {
			s = va_arg(ap, char *);
			if(prec >= 0)
				while(*s && prec-- > 0)
					putchar(*s++);
			else
				fputs(s);
		} else if(*p == 'd' || *p == 'u')
			printn(lflag ? va_arg(ap, long) : va_arg(ap, int), 10, width, zfill);
		else if(*p == 'D')
			printn(va_arg(ap, long), 10, width, zfill);
		else if(*p == 'o')
			printn(va_arg(ap, int), 8, width, zfill);
		else
			putchar(*p);
	}
	va_end(ap);
	return(0);
}

/* getpwnam now lives in lib/getpwnam.c (a real port of v7's
 * libc/stdio/getpwnam.c).  Likewise getpwuid in getpwuid.c and
 * setpwent/endpwent/getpwent in getpwent.c. */

struct group *
getgrnam(char *name)
{

	(void)name;
	return(0);
}
