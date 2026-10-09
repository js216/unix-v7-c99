#define	BUFSIZ	512
#define	_NFILE	20
# ifndef FILE
extern	struct	_iobuf {
	char	*_ptr;
	int	_cnt;
	char	*_base;
	char	_flag;
	char	_file;
} _iob[_NFILE];
# endif

#define	_IOREAD	01
#define	_IOWRT	02
#define	_IONBF	04
#define	_IOMYBUF	010
#define	_IOEOF	020
#define	_IOERR	040
#define	_IOSTRG	0100
#define	_IORW	0200

#ifndef NULL
#define	NULL	0
#endif
#define	FILE	struct _iobuf
#define	EOF	(-1)

#define	stdin	(&_iob[0])
#define	stdout	(&_iob[1])
#define	stderr	(&_iob[2])
#define	getc(p)		(--(p)->_cnt>=0? *(p)->_ptr++&0377:_filbuf(p))
#define	getchar()	getc(stdin)
#define putc(x,p) (--(p)->_cnt>=0? ((int)(*(p)->_ptr++=(unsigned)(x))):_flsbuf((unsigned)(x),p))
#define	putchar(x)	putc(x,stdout)
#define	feof(p)		(((p)->_flag&_IOEOF)!=0)
#define	ferror(p)	(((p)->_flag&_IOERR)!=0)
#define	fileno(p)	p->_file

FILE	*fopen(char *file, char *mode);
FILE	*freopen(char *file, char *mode, FILE *iop);
FILE	*fdopen(int fd, char *mode);
long	ftell(FILE *iop);
char	*fgets(char *s, int n, FILE *iop);
FILE	*popen(char *cmd, char *mode), *_findiop(void);
FILE	*_endopen(char *file, char *mode, FILE *iop);
int	read(int fd, char *buf, int n), write(int fd, char *buf, int n);
int	open(char *name, int mode), close(int fd), creat(char *name, int mode);
int	unlink(char *name), link(char *name1, char *name2);
int	access(char *name, int mode), chdir(char *dir), chroot(char *dir);
int	chmod(char *name, int mode), chown(char *name, int owner, int group);
int	mknod(char *name, int mode, int addr), utime(char *file, long *timep);
int	fork(void), wait(int *status), execv(char *name, char **argv);
int	execve(char *name, char **argv, char **envp);
int	execvp(char *name, char **argv), dup(int fd), dup2(int fd, int fd2);
int	pipe(int *fd), getuid(void), geteuid(void), getgid(void), getegid(void);
int	setuid(int uid), setgid(int gid), getpid(void), umask(int mask);
int	sync(void), kill(int pid, int sig), alarm(unsigned sec), pause(void);
int	nice(int incr), ioctl(int fd, int req, void *argp), stime(long *tp);
int	mount(char *spec, char *dir, int ro), umount(char *spec);
int	dysize(int y), fclose(FILE *iop), fseek(FILE *iop, long off, int ptr);
int	fgetc(FILE *iop), fputc(int c, FILE *iop), getw(FILE *iop);
int	putw(int i, FILE *iop), pclose(FILE *iop), getpw(int uid, char *buf);
int	fread(char *ptr, unsigned size, unsigned count, FILE *iop);
int	fwrite(char *ptr, unsigned size, unsigned count, FILE *iop);
int	puts(char *s), fputs(char *s, FILE *iop), ungetc(int c, FILE *iop);
int	fflush(FILE *iop), _filbuf(FILE *iop), _flsbuf(int c, FILE *iop);
int	system(char *s), isatty(int fd), ttyslot(void), strlen(char *s);
int	strcmp(char *s1, char *s2), strncmp(char *s1, char *s2, int n);
int	atoi(char *p), rand(void);
int	printf(char *fmt, ...), fprintf(FILE *iop, char *fmt, ...);
int	scanf(char *fmt, ...), fscanf(FILE *iop, char *fmt, ...);
int	sscanf(char *str, char *fmt, ...);
int	execl(char *name, char *arg0, ...), execlp(char *name, char *arg0, ...);
char	*sprintf(char *str, char *fmt, ...);
void	exit(int status), _exit(int status), abort(void), _cleanup(void);
long	lseek(int fd, long off, int ptr), time(long *tloc), tell(int fd);
long	atol(char *p);
unsigned	sleep(unsigned n);
double	atof(char *p);
struct	tm *localtime(long *tim), *gmtime(long *tim);
char	*ctime(long *t), *asctime(struct tm *t), *gets(char *s);
char	*mktemp(char *as), *getenv(char *name), *getlogin(void);
char	*getpass(char *prompt), *ttyname(int fd), *crypt(char *pw, char *salt);
char	*strncat(char *s1, char *s2, int n), *strcpy(char *s1, char *s2);
char	*strcat(char *s1, char *s2), *strncpy(char *s1, char *s2, int n);
char	*index(char *sp, char c), *rindex(char *sp, char c);
char	*malloc(unsigned n), *realloc(char *p, unsigned n);
char	*calloc(unsigned num, unsigned size), *sbrk(int incr);
char	*ecvt(double arg, int ndigits, int *decpt, int *sign);
char	*fcvt(double arg, int ndigits, int *decpt, int *sign);
char	*gcvt(double number, int ndigit, char *buf);
char	*timezone(int zone, int dst);
void	rewind(FILE *iop), setbuf(FILE *iop, char *buf), clearerr(FILE *iop);
void	perror(char *s), srand(unsigned x), free(char *p);
void	qsort(char *a, unsigned n, int es, int (*fc)(char *p1, char *p2));
void	swab(char *from, char *to, int n);
void	cfree(char *p, unsigned num, unsigned size);
void	setkey(char *key), encrypt(char *block, int edflag);
void	ltol3(char *cp, long *lp, int n), l3tol(long *lp, char *cp, int n);
void	_strout(char *s, int count, int adjust, FILE *iop, int fillch);
extern char **environ;
