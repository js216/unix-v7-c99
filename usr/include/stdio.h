#ifndef STDIO_H
#define STDIO_H
struct stat;
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

FILE	*fopen(char *name, char *mode);
FILE	*freopen(char *name, char *mode, FILE *f);
FILE	*fdopen(int fd, char *mode);
long	ftell(FILE *f);
char	*fgets(char *s, int n, FILE *f);
#define	O_RDONLY	0
int syscall3(int n, int a, int b, int c);
int read(int fd, char *buf, int n);
int write(int fd, char *buf, int n);
int open(char *path, int mode);
int close(int fd);
int creat(char *path, int mode);
int unlink(char *path);
int link(char *from, char *to);
int access(char *path, int mode);
int chdir(char *path);
int chmod(char *path, int mode);
int chown(char *path, int uid, int gid);
int mknod(char *path, int mode, int dev);
int utime(char *path, long *times);
long lseek(int fd, long off, int whence);
int stat(char *path, struct stat *st);
int fstat(int fd, struct stat *st);
int fork(void);
int wait(int *status);
int execve(char *path, char **argv, char **envp);
int execv(char *path, char **argv);
int execl(char *path, char *arg0, ...);
int execvp(char *name, char **argv);
int execlp(char *name, char *arg0, ...);
void exit(int n) __attribute__((__noreturn__));
void _exit(int n) __attribute__((__noreturn__));
void abort(void) __attribute__((__noreturn__));
int dup();
int pipe(int *fd);
int getuid(void);
int setuid(int uid);
int getgid(void);
int setgid(int gid);
int getpid(void);
int umask(int n);
int sync(void);
int kill(int pid, int sig);
int signal();
int alarm(int n);
int pause(void);
int nice(int incr);
int gtty(int fd, void *buf);
int stty(int fd, void *buf);
int ioctl(int fd, int cmd, char *arg);
int mount(char *special, char *dir, int ro);
int umount(char *special);
struct tm;
struct timeb;
int time(long *t);
int stime(long *t);
int times();
int ftime(struct timeb *t);
struct tm *gmtime(long *t);
struct tm *localtime(long *t);
char *asctime(struct tm *t);
char *ctime(long *t);
int dysize(int y);
int fclose(FILE *f);
int fseek(FILE *f, long off, int whence);
void rewind(FILE *f);
void setbuf(FILE *f, char *buf);
int fgetc(FILE *f);
int fputc(int c, FILE *f);
int fread(char *buf, unsigned size, unsigned n, FILE *f);
int fwrite(char *buf, unsigned size, unsigned n, FILE *f);
char *gets(char *buf);
int puts();
int fputs(char *s, FILE *f);
int ungetc(int c, FILE *f);
int fflush(FILE *f);
int _filbuf(FILE *f);
int _flsbuf(int c, FILE *f);
int printf(char *fmt, ...);
int fprintf(FILE *f, char *fmt, ...);
char *sprintf(char *buf, char *fmt, ...);
int fscanf(FILE *f, char *fmt, ...);
int sscanf(char *str, char *fmt, ...);
int system(char *s);
void perror(char *s);
int isatty(int fd);
unsigned int sleep(unsigned n);
char *mktemp(char *s);
char *getenv(char *name);
extern char **environ;
char *getlogin(void);
char *getpass(char *prompt);
char *ttyname(int fd);
char *crypt(char *key, char *salt);
char *strncat(char *s1, char *s2, int n);
int ttyslot(void);
int strlen(char *s);
int strcmp(char *a, char *b);
char *strcpy(char *a, char *b);
char *strcat(char *a, char *b);
char *strncpy(char *a, char *b, int n);
int strncmp(char *a, char *b, int n);
char *index(char *s, int c);
char *rindex(char *s, int c);
int atoi(char *s);
long atol(char *s);
double atof(char *s);
void srand(unsigned int x);
int rand(void);
void qsort(void *base, unsigned n, int size, int (*compar)());
char *malloc(unsigned n);
void free(char *p);
char *realloc(char *p, unsigned n);
char *calloc(unsigned num, unsigned size);
void swab(char *from, char *to, int n);
int getargs(char **argv, int maxarg);
long tell(int f);
char *timezone(int zone, int dst);
#endif
