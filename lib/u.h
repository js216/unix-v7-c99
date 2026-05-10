#ifndef U_H
#define U_H

#include <stdarg.h>
#include <sys/types.h>
#include <time.h>
#include <sys/timeb.h>
#include <sys/times.h>
#include <pwd.h>
#include <grp.h>

static inline char *sprintf(char *buf, char *fmt, ...);

#define	O_RDONLY	0
#define	DIRSIZ		14
#define	BUFSIZ		512
#define	EOF		(-1)
#define	NULL		0
#define	S_IFMT		0170000
#define	S_IFDIR		0040000
#define	S_IFCHR		0020000
#define	S_IFBLK		0060000
#define	S_IFREG		0100000
#define	S_IREAD		0000400
#define	S_IWRITE	0000200
#define	S_IEXEC		0000100
#define	S_ISUID		0004000
#define	S_ISGID		0002000
#define	S_ISVTX		0001000

#define	S_EXIT		1
#define	S_FORK		2
#define	S_READ		3
#define	S_WRITE		4
#define	S_OPEN		5
#define	S_CLOSE		6
#define	S_WAIT		7
#define	S_CREAT		8
#define	S_LINK		9
#define	S_UNLINK	10
#define	S_EXEC		11
#define	S_CHDIR		12
#define	S_MKNOD		14
#define	S_CHMOD		15
#define	S_CHOWN		16
#define	S_STAT		18
#define	S_LSEEK		19
#define	S_FSTAT		28
#define	S_UTIME		30
#define	S_ACCESS	33
#define	S_SYNC		36
#define	S_DUP		41
#define	S_PIPE		42
#define	S_MOUNT		21
#define	S_UMOUNT	22
#define	S_KILL		37
#define	S_SIGNAL	48
#define	S_GETUID	24
#define	S_SETUID	23
#define	S_UMASK		60
#define	S_SIGRETURN	139
#define	S_GETDENTS	141
#define	S_SPAWN		200

#define	UARGV		0x0000f000
#define	UARGLEN		512

typedef struct {
	int fd;
} FILE;

#ifndef SYS_STAT_H
#define SYS_STAT_H
struct stat {
	int	st_dev;
	unsigned short st_ino;
	unsigned short st_mode;
	short	st_nlink;
	short	st_uid;
	short	st_gid;
	int	st_rdev;
	long	st_size;
	long	st_atime;
	long	st_mtime;
	long	st_ctime;
};
#endif

static FILE _iob[3] = {{0}, {1}, {2}};
#define	stdin		(&_iob[0])
#define	stdout		(&_iob[1])
#define	stderr		(&_iob[2])

#ifndef SYS_DIR_H
#define SYS_DIR_H
struct direct {
	unsigned short d_ino;
	char d_name[DIRSIZ];
};
#endif

int syscall3(int n, int a, int b, int c);

static inline int
read(int fd, char *buf, int n)
{

	return(syscall3(S_READ, fd, (int)buf, n));
}

static inline int
write(int fd, char *buf, int n)
{

	return(syscall3(S_WRITE, fd, (int)buf, n));
}

static inline int
open(char *path, int mode)
{

	return(syscall3(S_OPEN, (int)path, mode, 0));
}

static inline int
close(int fd)
{

	return(syscall3(S_CLOSE, fd, 0, 0));
}

static inline int
creat(char *path, int mode)
{

	return(syscall3(S_CREAT, (int)path, mode, 0));
}

static inline int
unlink(char *path)
{

	return(syscall3(S_UNLINK, (int)path, 0, 0));
}

static inline int
fork(void)
{

	return(syscall3(S_FORK, 0, 0, 0));
}

static inline int
wait(int *status)
{
	int w;

	w = 0;
	return(syscall3(S_WAIT, status ? (int)status : (int)&w, 0, 0));
}

static inline int
link(char *from, char *to)
{

	return(syscall3(S_LINK, (int)from, (int)to, 0));
}

static inline int
mknod(char *path, int mode, int dev)
{

	return(syscall3(S_MKNOD, (int)path, mode, dev));
}

static inline int
chmod(char *path, int mode)
{

	return(syscall3(S_CHMOD, (int)path, mode, 0));
}

static inline int
chown(char *path, int uid, int gid)
{

	return(syscall3(S_CHOWN, (int)path, uid, gid));
}

static inline int
access(char *path, int mode)
{

	return(syscall3(S_ACCESS, (int)path, mode, 0));
}

static inline int
utime(char *path, long *times)
{

	return(syscall3(S_UTIME, (int)path, (int)times, 0));
}

static inline long
lseek(int fd, long off, int whence)
{

	return(syscall3(S_LSEEK, fd, (int)off, whence));
}

static inline void
sync(void)
{

	(void)syscall3(S_SYNC, 0, 0, 0);
}

static inline int
dup(int fd)
{

	return(syscall3(S_DUP, fd, -1, 0));
}

static inline int
pipe(int *fd)
{

	return(syscall3(S_PIPE, (int)fd, 0, 0));
}

static inline int
fileno(FILE *f)
{

	return(f->fd);
}

static inline int
fstat(int fd, struct stat *st)
{

	return(syscall3(S_FSTAT, fd, (int)st, 0));
}

static inline int
stat(char *path, struct stat *st)
{

	return(syscall3(S_STAT, (int)path, (int)st, 0));
}

static inline int
chdir(char *path)
{

	return(syscall3(S_CHDIR, (int)path, 0, 0));
}

static inline FILE *
fopen(char *path, char *mode)
{
	static FILE files[8];
	int fd, i;

	if(*mode == 'w')
		fd = creat(path, 0666);
	else
		fd = open(path, 0);
	if(fd < 0)
		return(NULL);
	for(i=0; i<8; i++)
		if(files[i].fd == 0) {
			files[i].fd = fd;
			return(&files[i]);
		}
	(void)close(fd);
	return(NULL);
}

static inline FILE *
freopen(char *path, char *mode, FILE *f)
{
	int fd;

	if(*mode == 'w')
		fd = creat(path, 0666);
	else
		fd = open(path, 0);
	if(fd < 0)
		return(NULL);
	if(f != stdin && f != stdout && f != stderr)
		(void)close(f->fd);
	f->fd = fd;
	return(f);
}

static inline int
fclose(FILE *f)
{
	int fd;

	if(f == stdin || f == stdout || f == stderr)
		return(0);
	fd = f->fd;
	f->fd = 0;
	return(close(fd));
}

static inline int
getc(FILE *f)
{
	char c;

	if(read(f->fd, &c, 1) != 1)
		return(EOF);
	return(c & 0377);
}

static inline int
fgetc(FILE *f)
{

	return(getc(f));
}

static inline int
getchar(void)
{

	return(getc(stdin));
}

static inline int
fread(char *buf, int size, int n, FILE *f)
{
	int r;

	r = read(f->fd, buf, size*n);
	return(r < 0 ? 0 : r/size);
}

static inline int
fwrite(char *buf, int size, int n, FILE *f)
{
	int r;

	r = write(f->fd, buf, size*n);
	return(r < 0 ? 0 : r/size);
}

static inline char *
fgets(char *buf, int size, FILE *f)
{
	char *p;
	int c;

	if(size <= 0)
		return(NULL);
	p = buf;
	while(--size > 0) {
		c = getc(f);
		if(c == EOF)
			break;
		*p++ = c;
		if(c == '\n')
			break;
	}
	*p = 0;
	return(p == buf ? NULL : buf);
}

static int _feof;

static inline char *
gets(char *buf)
{
	char *p;
	int c;

	p = buf;
	while((c = getchar()) != EOF && c != '\n')
		*p++ = c;
	*p = 0;
	_feof = c == EOF && p == buf;
	return(_feof ? NULL : buf);
}

static inline int
feof(FILE *f)
{

	(void)f;
	return(_feof);
}

static inline int
fseek(FILE *f, long off, int whence)
{

	return((int)lseek(f->fd, off, whence));
}

static inline long
ftell(FILE *f)
{

	return(lseek(f->fd, 0L, 1));
}

static inline void
rewind(FILE *f)
{

	(void)fseek(f, 0L, 0);
}

static inline void
setbuf(FILE *f, char *buf)
{

	(void)f;
	(void)buf;
}

static inline int
exec(char *path)
{

	return(syscall3(S_EXEC, (int)path, 0, 0));
}

static inline int
execv(char *path, char **argv)
{

	return(syscall3(S_EXEC, (int)path, (int)argv, 0));
}

static inline int
getdents(int fd, char *buf, int n)
{

	return(syscall3(S_GETDENTS, fd, (int)buf, n));
}

static inline int
spawn(char *path, char *args)
{

	return(syscall3(S_SPAWN, (int)path, (int)args, 0));
}

static inline void
exit(int n)
{

	(void)syscall3(S_EXIT, n, 0, 0);
	for(;;)
		;
}

static inline void
_exit(int n)
{

	exit(n);
}

/* strlen / strcmp now live in lib/strlen.c and lib/strcmp.c
 * (real ports of v7's libc/gen/strlen.c and strcmp.c). */
extern int strlen(char *s);
extern int strcmp(char *a, char *b);

static inline void
qsort(void *vbase, int n, int size, int (*compar)())
{
	int i, j, k;
	char c, *a, *b;
	char *base;

	base = vbase;
	for(i=0; i<n; i++)
		for(j=i+1; j<n; j++) {
			a = base + i*size;
			b = base + j*size;
			if((*compar)(a, b) <= 0)
				continue;
			for(k=0; k<size; k++) {
				c = a[k];
				a[k] = b[k];
				b[k] = c;
			}
		}
}

#ifndef major
static inline int
major(int dev)
{

	return((dev >> 8) & 0377);
}
#endif

#ifndef minor
static inline int
minor(int dev)
{

	return(dev & 0377);
}
#endif

/* atoi/atol now live in lib/atoi.c, lib/atol.c (real ports of
 * v7's libc/gen/atoi.c, atol.c).  abs is on disk as lib/abs.c
 * but not linked because cmd/chmod.c carries its own abs(). */
extern int atoi(char *s);
extern long atol(char *s);

static inline double
atof(char *s)
{
	double a, e;
	int c, neg;

	a = 0;
	neg = 0;
	if(*s == '-') {
		neg++;
		s++;
	}
	while((c = *s++) >= '0' && c <= '9')
		a = a*10 + c - '0';
	if(c == '.') {
		e = 1;
		while((c = *s++) >= '0' && c <= '9') {
			a = a*10 + c - '0';
			e *= 10;
		}
		a /= e;
	}
	return(neg ? -a : a);
}

/* isatty now lives in lib/isatty.c (port of v7's libc/gen/isatty.c). */
extern int isatty(int fd);

static inline int
gtty(int fd, void *buf)
{

	(void)fd;
	(void)buf;
	return(0);
}

static inline int
stty(int fd, void *buf)
{

	(void)fd;
	(void)buf;
	return(0);
}

static inline int
ioctl(int fd, int cmd, char *arg)
{

	(void)fd;
	(void)cmd;
	(void)arg;
	return(0);
}

static inline int
getuid(void)
{

	return(syscall3(S_GETUID, 0, 0, 0));
}

static inline int
getgid(void)
{

	return(0);
}

static inline int
getpid(void)
{

	return(1);
}

static inline char *
malloc(unsigned n)
{
	static char *brk = (char *)0x00060000;
	unsigned *p;

	n = (n + 3) & ~3;
	p = (unsigned *)brk;
	*p++ = n;
	brk += n + sizeof(unsigned);
	return((char *)p);
}

static inline void
free(char *p)
{

	(void)p;
}

static inline char *
realloc(char *p, unsigned n)
{
	char *q;
	unsigned i, old;

	if(p == 0)
		return(malloc(n));
	old = ((unsigned *)p)[-1];
	q = malloc(n);
	if(q == 0)
		return(0);
	if(old > n)
		old = n;
	for(i=0; i<old; i++)
		q[i] = p[i];
	return(q);
}

/* mktemp now lives in lib/mktemp.c (port of v7's libc/gen/mktemp.c). */
extern char *mktemp(char *s);

static inline int
setuid(int uid)
{

	return(syscall3(S_SETUID, uid, 0, 0));
}

static inline int
setgid(int gid)
{

	(void)gid;
	return(0);
}

static inline int
_umask_unused(int n)
{
	static int mask;
	int old;

	old = mask;
	mask = n;
	return(old);
}

static inline int
umask(int n)
{

	return(syscall3(S_UMASK, n, 0, 0));
}

static inline int
sleep(int n)
{

	(void)n;
	return(0);
}

static inline int
alarm(int n)
{

	(void)n;
	return(0);
}

/* rand / srand now live in lib/rand.c (port of v7's libc/gen/rand.c). */
extern void srand(unsigned int x);
extern int rand(void);

static inline int
signal(int sig, int fun)
{

	return(syscall3(S_SIGNAL, sig, fun, 0));
}

static inline void
puts(char *s, ...)
{
	char nl;

	(void)write(1, s, strlen(s));
	nl = '\n';
	(void)write(1, &nl, 1);
}

static inline void
putchar(int c)
{
	char b;

	b = (char)c;
	(void)write(1, &b, 1);
}

static inline void
putc(int c, FILE *f)
{
	char b;

	b = (char)c;
	(void)write(f->fd, &b, 1);
}

static inline void
fputs(char *s, FILE *f)
{

	(void)write(f->fd, s, strlen(s));
}

/* String routines now live in lib/str*.c, lib/index.c, lib/rindex.c
 * (real ports of v7's libc/gen/{strcat,strcpy,strncat,strncpy,
 * strncmp,index,rindex}.c). */
extern char *strcpy(char *a, char *b);
extern char *strcat(char *a, char *b);
extern char *strncpy(char *a, char *b, int n);
extern int strncmp(char *a, char *b, int n);
extern char *rindex(char *s, int c);
extern char *index(char *s, int c);

static inline int
time(long *t)
{

	if(t)
		*t = 0;
	return(0);
}

static inline int
ftime(struct timeb *t)
{

	t->time = 0;
	t->millitm = 0;
	t->timezone = 0;
	t->dstflag = 0;
	return(0);
}

static inline int
stime(long *t)
{

	(void)t;
	return(-1);
}

static inline int
dysize(int y)
{

	if(y%4 == 0 && (y%100 != 0 || y%400 == 0))
		return(366);
	return(365);
}

static inline struct tm *
gmtime(long *t)
{
	static struct tm tm;
	long d, s;
	int y, m;
	static int mdays[] = {
		31, 28, 31, 30, 31, 30,
		31, 31, 30, 31, 30, 31
	};

	s = t ? *t : 0;
	d = s / 86400;
	s %= 86400;
	tm.tm_hour = s / 3600;
	s %= 3600;
	tm.tm_min = s / 60;
	tm.tm_sec = s % 60;
	tm.tm_wday = (d + 4) % 7;
	for(y=1970; d >= dysize(y); y++)
		d -= dysize(y);
	tm.tm_year = y - 1900;
	tm.tm_yday = d;
	mdays[1] = dysize(y) == 366 ? 29 : 28;
	for(m=0; d >= mdays[m]; m++)
		d -= mdays[m];
	tm.tm_mon = m;
	tm.tm_mday = d + 1;
	tm.tm_isdst = 0;
	return(&tm);
}

static inline struct tm *
localtime(long *t)
{

	return(gmtime(t));
}

static inline char *
asctime(struct tm *t)
{
	static char buf[32];
	static char *day[] = {
		"Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"
	};
	static char *mon[] = {
		"Jan", "Feb", "Mar", "Apr", "May", "Jun",
		"Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
	};

	sprintf(buf, "%.3s %.3s %2d %02d:%02d:%02d 19%02d\n",
	    day[t->tm_wday], mon[t->tm_mon], t->tm_mday,
	    t->tm_hour, t->tm_min, t->tm_sec, t->tm_year);
	return(buf);
}

static inline char *
ctime(long *t)
{

	return(asctime(localtime(t)));
}

static inline char *
timezone(int zone, int dst)
{

	(void)zone;
	(void)dst;
	return("GMT");
}

static inline int
times(struct tms *t)
{
	long *p;
	int i;

	p = (long *)t;
	for(i=0; i<4; i++)
		p[i] = 0;
	return(0);
}

static inline int
fscanf(FILE *f, char *fmt, ...)
{
	va_list ap;
	char *p, *s;
	int c, n;

	va_start(ap, fmt);
	n = 0;
	for(p=fmt; *p; p++) {
		if(*p != '%')
			continue;
		p++;
		if(*p != 's')
			continue;
		s = va_arg(ap, char *);
		do {
			c = getc(f);
			if(c == EOF) {
				va_end(ap);
				return(n ? n : EOF);
			}
		} while(c == ' ' || c == '\t' || c == '\n');
		do {
			*s++ = c;
			c = getc(f);
		} while(c != EOF && c != ' ' && c != '\t' && c != '\n');
		*s = 0;
		n++;
	}
	va_end(ap);
	return(n);
}

static inline int
kill(int pid, int sig)
{

	return(syscall3(S_KILL, pid, sig, 0));
}

static inline int
nice(int incr)
{

	(void)incr;
	return(0);
}

/* execvp/execlp now ride on the v7-faithful PATH-walk port at
 * lib/execvp.c.  strncat/ttyslot are likewise real ports of v7
 * libc sources rather than ad-hoc inlines. */
extern int execvp(char *name, char **argv);
extern int execlp(char *name, char *arg0, ...);
static inline int
mount(char *special, char *dir, int ro)
{
	(void)ro;
	return(syscall3(S_MOUNT, (int)special, (int)dir, 0));
}
static inline int
umount(char *special)
{

	return(syscall3(S_UMOUNT, (int)special, 0, 0));
}
extern char *strncat(char *s1, char *s2, int n);
extern int ttyslot(void);
extern char *crypt(char *key, char *salt);
extern char *getenv(char *name);
extern char **environ;

/* ttyname now lives in lib/ttyname.c (port of v7's libc/gen/ttyname.c).
 * Returns NULL until /dev is populated -- the rootfs has no /dev yet. */
extern char *ttyname(int fd);

/* getpwuid/getpwnam/setpwent/endpwent/getpwent are now real -- they
 * walk /etc/passwd via the v7-style getpwent() machinery in
 * lib/getpwent.c rather than returning a hard-coded "root"
 * placeholder. */
extern struct passwd *getpwuid(int uid);
extern struct passwd *getpwnam(char *name);
extern struct passwd *getpwent(void);
extern void setpwent(void);
extern void endpwent(void);

static inline struct group *
getgrnam(char *name)
{
	static char *mem[] = { "root", 0 };
	static struct group gr = { "other", "", 0, mem };

	(void)name;
	return(&gr);
}

static inline char *
getpass(char *prompt)
{
	static char buf[16];

	(void)prompt;
	buf[0] = 0;
	return(buf);
}

static inline int
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

static inline void
fputn(FILE *f, long n, int b, int width, int zfill)
{
	long a;
	int c;

	if(n < 0) {
		putc('-', f);
		n = -n;
	}
	a = n / b;
	if(a)
		fputn(f, a, b, width ? width-1 : 0, zfill);
	else
		while(--width > 0)
			putc(zfill ? '0' : ' ', f);
	c = (int)(n % b);
	putc(c < 10 ? c + '0' : c - 10 + 'A', f);
}

static inline void
fprintf(FILE *f, char *fmt, ...)
{
	va_list ap;
	char *p;
	char *s;
	int c, width, lflag, zfill, prec, left, len;

	va_start(ap, fmt);
	for(p=fmt; *p; p++) {
		if(*p != '%') {
			(void)write(f->fd, p, 1);
			continue;
		}
		p++;
		width = 0;
		zfill = 0;
		left = 0;
		if(*p == '-') {
			left++;
			p++;
		}
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
			len = strlen(s);
			if(prec >= 0 && len > prec)
				len = prec;
			if(!left)
				while(width-- > len)
					putc(' ', f);
			if(prec >= 0)
				while(*s && prec-- > 0)
					putc(*s++, f);
			else
				fputs(s, f);
			if(left)
				while(width-- > len)
					putc(' ', f);
		} else if(*p == 'c') {
			c = va_arg(ap, int);
			if(c)
				putc(c, f);
		}
		else if(*p == 'd' || *p == 'u')
			fputn(f, lflag ? va_arg(ap, long) : va_arg(ap, int), 10, width, zfill);
		else if(*p == 'D')
			fputn(f, va_arg(ap, long), 10, width, zfill);
		else if(*p == 'o')
			fputn(f, va_arg(ap, int), 8, width, zfill);
		else
			putc(*p, f);
	}
	va_end(ap);
}

/* perror lives in lib/perror.c (port of v7's libc/gen/perror.c). */
extern void perror(char *s);

static inline char *
sputn(char *p, long n, int b)
{
	long a;
	int c;

	if(n < 0) {
		*p++ = '-';
		n = -n;
	}
	a = n / b;
	if(a)
		p = sputn(p, a, b);
	c = (int)(n % b);
	*p++ = c < 10 ? c + '0' : c - 10 + 'A';
	return(p);
}

static inline char *
sprintf(char *buf, char *fmt, ...)
{
	va_list ap;
	char *p, *q, *s, *r;
	char num[32];
	int c, width, lflag, zfill, prec, len, left;

	va_start(ap, fmt);
	q = buf;
	for(p=fmt; *p; p++) {
		if(*p != '%') {
			*q++ = *p;
			continue;
		}
		p++;
		width = 0;
		zfill = 0;
		left = 0;
		if(*p == '-') {
			left++;
			p++;
		}
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
			len = strlen(s);
			if(prec >= 0 && len > prec)
				len = prec;
			if(!left)
				while(width-- > len)
					*q++ = ' ';
			while(*s && prec--)
				*q++ = *s++;
			if(left)
				while(width-- > len)
					*q++ = ' ';
		} else if(*p == 'c') {
			c = va_arg(ap, int);
			if(c)
				*q++ = c;
		}
		else if(*p == 'd' || *p == 'u') {
			r = sputn(num, lflag ? va_arg(ap, long) : va_arg(ap, int), 10);
			*r = 0;
			len = strlen(num);
			while(width-- > len)
				*q++ = zfill ? '0' : ' ';
			for(r=num; *r;)
				*q++ = *r++;
		}
		else if(*p == 'o')
			q = sputn(q, va_arg(ap, int), 8);
		else
			*q++ = *p;
	}
	*q = 0;
	va_end(ap);
	return(buf);
}

static inline int
ferror(FILE *f)
{

	(void)f;
	return(0);
}

static inline int
fflush(FILE *f)
{

	(void)f;
	return(0);
}

static inline void
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

static inline void
printf(char *fmt, ...)
{
	va_list ap;
	char *p, *s;
	int c, width, lflag, zfill, prec, left, len;

	va_start(ap, fmt);
	for(p=fmt; *p; p++) {
		if(*p != '%') {
			putchar(*p);
			continue;
		}
		p++;
		width = 0;
		zfill = 0;
		left = 0;
		if(*p == '-') {
			left++;
			p++;
		}
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
			len = strlen(s);
			if(prec >= 0 && len > prec)
				len = prec;
			if(!left)
				while(width-- > len)
					putchar(' ');
			if(prec >= 0)
				while(*s && prec-- > 0)
					putchar(*s++);
			else
				fputs(s, stdout);
			if(left)
				while(width-- > len)
					putchar(' ');
		} else if(*p == 'c') {
			c = va_arg(ap, int);
			if(c)
				putchar(c);
		}
		else if(*p == 'd' || *p == 'u')
			printn(lflag ? va_arg(ap, long) : va_arg(ap, int), 10, width, zfill);
		else if(*p == 'D')
			printn(va_arg(ap, long), 10, width, zfill);
		else if(*p == 'o')
			printn(va_arg(ap, int), 8, width, zfill);
		else
			putchar(*p);
	}
	va_end(ap);
}

static inline int
getargs(char **argv, int maxarg)
{
	char *p;
	int argc;

	argc = 0;
	p = (char *)UARGV;
	while(*p && argc < maxarg-1) {
		while(*p == ' ' || *p == '\t')
			p++;
		if(*p == 0)
			break;
		argv[argc++] = p;
		while(*p && *p != ' ' && *p != '\t')
			p++;
		if(*p)
			*p++ = 0;
	}
	argv[argc] = 0;
	return(argc);
}

#endif
