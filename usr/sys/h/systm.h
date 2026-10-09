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
extern	char	*msgbufp;	/* next saved printf character */
dev_t	rootdev;		/* device of the root */
dev_t	swapdev;		/* swapping device */
dev_t	pipedev;		/* pipe device */
extern	int	icode[];	/* user init code */
extern	int	szicode;	/* its size */

dev_t getmdev();
daddr_t	bmap();
struct inode *ialloc();
struct inode *iget();
struct inode *owner();
struct inode *maknode();
struct inode *namei();
struct buf *alloc();
struct buf *getblk();
struct buf *geteblk();
struct buf *bread();
struct buf *breada();
struct filsys *getfs();
struct file *getf();
struct file *falloc();
int	uchar();
void	acct(), addupc(), arm_sureg(), arm_sync_icache(), bawrite(),
	bcopy(), bdinit(), bdwrite(), bflush(), binit(), brelse(), bwrite(),
	chdirec(), cinit(), clearseg(), clkstart(), clock(), clock_ddr_init(),
	closef(), clrbuf(), cninit(), cntv_ctl_set(), cntv_tval_set(),
	copyseg(), deverror(), exece(), exit(), expand(), flushtty(), free(),
	geterror(), idle(), iexpand(), ifree(), iinit(), install_sigtramp(),
	ioctl(), iodone(), iomove(), iowait(), iput(), itrunc(), iupdat(),
	mapfree(), mfree(), mmu_on(), notavail(), open1(), openi(), panic(),
	physio(), plock(), prdev(), prele(), printn(), psig(), psignal(),
	putchar(), qswtch(), rdwr(), readi(), readp(), resume(), savfp(),
	sched(), sendsig(), setregs(), setrun(), signal(), sleep(), startup(),
	stat1(), sureg(), swap(), swtch(), timeout(), tloop(), ttstart(),
	ttyblock(), ttychars(), ttyclose(), ttyinput(), ttyopen(), ttyoutput(),
	update(), wakeup(), wdir(), wflushtty(), writei(), writep(), xalloc(),
	xccdec(), xexpand(), xfree(), xlock(), xrele(), xswap(), xumount(),
	xunlock(), xuntext();
int	access(), b_to_q(), badblock(), cntfrq_get(), compress(), copyin(),
	copyout(), core(), cpass(), dfar(), dfsr(), estabur(), fsig(),
	fubyte(), fumem(), fuword(), getc(), getxfile(), incore(), issig(),
	malloc(), max(), min(), newproc(), passc(), procxmt(), putc(), save(),
	setpri(), spl0(), spl1(), spl5(), spl6(), spl7(), splx(), subyte(),
	sumem(), suser(), suword(), swapin(), ttioccomm(), ttread(), ttrstrt(),
	ufalloc();
caddr_t	ttwrite();
void	printf(char *, ...);
#define	fuibyte	fubyte
#define	fuiword	fuword
#define	suibyte	subyte
#define	suiword	suword
#define	copyiin	copyin
#define	copyiout	copyout
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
	void	(*sy_call)();		/* handler */
} sysent[];
