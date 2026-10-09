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

FILE	*fopen();
FILE	*freopen();
FILE	*fdopen();
long	ftell();
char	*fgets();
int	read(), write(), open(), close(), creat(), unlink(), link(), access();
int	chdir(), chmod(), chown(), mknod(), utime(), stat(), fstat(), fork();
int	wait(), execv(), execvp(), dup(), pipe(), getuid(), setuid(), getgid();
int	setgid(), getpid(), umask(), sync(), kill(), (*signal())(), alarm(), pause();
int	nice(), gtty(), stty(), ioctl(), mount(), umount(), time(), stime();
int	times(), ftime(), dysize(), fclose(), fseek(), fgetc(), fread(), fwrite();
int	puts(), fputs(), ungetc(), fflush(), _filbuf(), _flsbuf(), system();
int	isatty(), ttyslot(), strlen(), strcmp(), strncmp(), atoi(), rand();
int	printf(char *, ...), fprintf(FILE *, char *, ...);
int	fscanf(FILE *, char *, ...), sscanf(char *, char *, ...);
int	execl(char *, char *, ...), execlp(char *, char *, ...);
char	*sprintf(char *, char *, ...);
void	exit() __attribute__((__noreturn__));
void	_exit() __attribute__((__noreturn__));
void	abort() __attribute__((__noreturn__));
long	lseek();
unsigned	sleep();
double	atof();
struct	tm *localtime();
char	*ctime(), *gets(), *mktemp(), *getenv(), *getlogin(), *getpass();
char	*ttyname(), *crypt(), *strncat(), *strcpy(), *strcat(), *strncpy();
char	*index(), *rindex(), *malloc(), *realloc();
void	rewind(), setbuf(), perror(), srand(), qsort(), free(), swab();
extern char **environ;
