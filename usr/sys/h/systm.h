/*
 * Random set of variables
 * used by more than one
 * routine.
 */
char	canonb[CANBSIZ];	/* buffer for erase and kill (#@) */
struct inode *rootdir;		/* pointer to inode of root directory */
struct proc *runq;		/* head of linked list of running processes */
int	cputype;		/* type of cpu =40, 45, or 70 */
int	lbolt;			/* time of day in 60th not in time */
time_t	time;			/* time in sec from 1970 */

/*
 * Nblkdev is the number of entries
 * (rows) in the block switch. It is
 * set in binit/bio.c by making
 * a pass over the switch.
 * Used in bounds checking on major
 * device numbers.
 */
int	nblkdev;

/*
 * Number of character switch entries.
 * Set by cinit/tty.c
 */
int	nchrdev;

int	mpid;			/* generic for unique process id's */
char	runin;			/* scheduling flag */
char	runout;			/* scheduling flag */
char	runrun;			/* scheduling flag */
char	curpri;			/* more scheduling */
int	maxmem;			/* actual max memory per process */
physadr	lks;			/* pointer to clock device */
daddr_t	swplo;			/* block number of swap space */
int	nswap;			/* size of swap space */
int	updlock;		/* lock for sync */
daddr_t	rablock;		/* block to be read ahead */
extern	char	regloc[];	/* locs. of saved user registers (trap.c) */
char	msgbuf[MSGBUFS];	/* saved "printf" characters */
dev_t	rootdev;		/* device of the root */
dev_t	swapdev;		/* swapping device */
dev_t	pipedev;		/* pipe device */
extern	int	icode[];	/* user init code */
extern	int	szicode;	/* its size */

dev_t	getmdev(void);
daddr_t	bmap(struct inode *ip, daddr_t bn, int rwflg);
void	setrun(struct proc *p);
int	setpri(struct proc *pp);
int	issig(void);
unsigned min(unsigned a, unsigned b);
int	fubyte(caddr_t addr);
int	subyte(caddr_t addr, char c);
struct inode *ialloc(dev_t dev);
struct inode *iget(dev_t dev, ino_t ino);
struct inode *owner(void);
struct inode *maknode(int mode);
struct inode *namei(int (*func)(void), int flag);
struct buf *alloc(dev_t dev);
struct buf *getblk(dev_t dev, daddr_t blkno);
struct buf *geteblk(void);
struct buf *bread(dev_t dev, daddr_t blkno);
struct buf *breada(dev_t dev, daddr_t blkno, daddr_t rablkno);
struct filsys *getfs(dev_t dev);
struct file *getf(int fdes);
struct file *falloc(void);
int	uchar(void);
void	free(dev_t dev, daddr_t bno);
void	ifree(dev_t dev, ino_t ino);
void	update(void);
int	passc(int c);
int	cpass(void);
void	closef(struct file *fp);
int	access(struct inode *ip, int mode);
void	iput(struct inode *ip);
void	plock(struct inode *ip);
void	prele(struct inode *ip);
void	readi(struct inode *ip);
void	writei(struct inode *ip);
int	iupdat(struct inode *ip, time_t *ta, time_t *tm);
int	suser(void);
int	ufalloc(void);
void	xrele(struct inode *ip);
void	psignal(struct proc *p, int sig);
void	bcopy(char *f, char *t, unsigned int n);
int	copyin(caddr_t f, caddr_t t, unsigned int n);
int	copyout(caddr_t f, caddr_t t, unsigned int n);
/*
 * Instrumentation
 */
int	dk_busy;
long	dk_time[32];
long	dk_numb[3];
long	dk_wds[3];
long	tk_nin;
long	tk_nout;

/*
 * Structure of the system-entry table
 */
extern struct sysent {
	char	sy_narg;		/* total number of arguments */
	char	sy_nrarg;		/* number of args in registers */
	void	(*sy_call)(void);	/* handler (Armv7/C99: void(void)) */
} sysent[];
