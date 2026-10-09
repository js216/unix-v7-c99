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
extern	char	regloc[];	/* locs. of saved user registers (sysent.c) */
char	msgbuf[MSGBUFS];	/* saved "printf" characters */
extern	char	*msgbufp;	/* next saved printf character */
dev_t	rootdev;		/* device of the root */
dev_t	swapdev;		/* swapping device */
dev_t	pipedev;		/* pipe device */
extern	int	icode[];	/* user init code */
extern	int	szicode;	/* its size */

dev_t getmdev(void);
daddr_t	bmap(struct inode *ip, daddr_t bn, int rwflg);
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
struct file *getf(int f);
struct file *falloc(void);
int	uchar(void);
struct clist; struct map; struct text; struct tty; struct uprof;
void	acct(void), addupc(caddr_t pc, struct uprof *p, int t),
	alarm(void), arm_sureg(void), arm_sync_icache(void),
	bawrite(struct buf *bp), bcopy(caddr_t from, caddr_t to, int count),
	bdinit(void), bdwrite(struct buf *bp), bflush(dev_t dev),
	brelse(struct buf *bp), bwrite(struct buf *bp), chdir(void),
	chmod(void), chown(void), chroot(void), cinit(void), clearseg(int a),
	clkstart(void),
	clock(caddr_t pc, int ps),
	clock_ddr_init(void), close(void), closef(struct file *fp),
	clrbuf(struct buf *bp), cninit(void), cntv_ctl_set(int c),
	cntv_tval_set(unsigned t), copyseg(int from, int to), creat(void),
	dcflush(caddr_t a, unsigned n), ddrinit(void),
	deverror(struct buf *bp, int o1, int o2), dmbsy(void), dup(void),
	exec(void), exece(void), exit(int rv), expand(int newsize), fork(void),
	free(dev_t dev, daddr_t bno), fstat(void), ftime(void), getgid(void),
	getpid(void), getuid(void), gtime(void), gtty(void), idle(void),
	ifree(dev_t dev, ino_t ino), install_sigtramp(void),
	iodone(struct buf *bp), ioctl(void), iput(struct inode *ip),
	irq(int *r), itrunc(struct inode *ip),
	iupdat(struct inode *ip, time_t *ta, time_t *tm), kill(void),
	klclose(dev_t dev, int flag), klinit(void), klintr(void),
	klioctl(dev_t dev, int cmd, caddr_t addr, int flag),
	klopen(dev_t dev, int flag), klputchar(char c), klread(dev_t dev),
	klwrite(dev_t dev), link(void), machine_init(void),
	mapalloc(struct buf *bp), mapfree(struct buf *bp),
	mfree(struct map *mp, int size, int a), mknod(void), mmread(int dev),
	mmu_on(unsigned *l1), mmwrite(int dev),
	ndflush(struct clist *q, int cc), nice(void),
	nodev(dev_t dev, int flag),
	nolioctl(int cmd, struct tty *tp, caddr_t addr),
	noioctl(dev_t dev, int cmd, caddr_t addr, int flag), nordwr(dev_t dev),
	nostrat(struct buf *bp), nulldev(dev_t dev, int flag),
	nulltty(struct tty *tp), open(void), openi(struct inode *ip, int rw),
	panic(char *s), panictrap(void), pause(void),
	physio(void (*strat)(struct buf *bp), struct buf *bp, int dev, int rw),
	pipe(void), plock(struct inode *ip), prdev(char *str, dev_t dev),
	prele(struct inode *ip), profil(void), psig(void),
	psignal(struct proc *p, int sig), ptrace(void), putchar(int c),
	qswtch(void), read(void), readi(struct inode *ip),
	readp(struct file *fp), resume(int a, label_t lab), rexit(void),
	rkinit(void), rkintr(void), rkread(dev_t dev),
	rkstrategy(struct buf *bp), rkwrite(dev_t dev), saccess(void),
	savfp(void *fps), sbreak(void), sched(void), sdinit(void),
	sdintr(void), sdread(dev_t dev), sdstrategy(struct buf *bp),
	sdwrite(dev_t dev), seek(void), sendsig(caddr_t p, int signo),
	setgid(void), setrun(struct proc *p), setuid(void), sigreturn(void),
	signal(int pgrp, int sig), sleep(caddr_t chan, int pri), smount(void),
	spl0(void), spl1(void), splx(int s), ssig(void), startup(void),
	stat(void), stime(void), stty(void), sumount(void), sureg(void),
	swap(int blkno, int coreaddr, int count, int rdflg), swtch(void),
	sync(void), syopen(int dev, int flag), syread(int dev), sysacct(void),
	sysioctl(int dev, int cmd, caddr_t addr, int flag), syslock(void),
	sysphys(void), sywrite(int dev),
	timeout(void (*fun)(caddr_t arg), caddr_t arg, int tim), times(void),
	trap(int *r), ttrstrt(caddr_t arg), ttstart(struct tty *tp),
	ttychars(struct tty *tp), ttyclose(struct tty *tp),
	ttyinput(int c, struct tty *tp), ttyopen(dev_t dev, struct tty *tp),
	ttyrend(struct tty *tp, char *pb, char *pe), umask(void), unlink(void),
	update(void), usclose(dev_t dev, int flag), usinit(void), usintr(void),
	usioctl(dev_t dev, int cmd, caddr_t addr, int flag),
	usopen(dev_t dev, int flag), usputchar(char c), usread(dev_t dev),
	user_trap_handler(int signo, int *r), uswrite(dev_t dev), utime(void),
	wait(void), wakeup(caddr_t chan), wdir(struct inode *ip), write(void),
	writei(struct inode *ip), writep(struct file *fp),
	xalloc(struct inode *ip), xfree(void), xlock(struct text *xp),
	xrele(struct inode *ip), xswap(struct proc *p, int ff, int os),
	xumount(int dev), xunlock(struct text *xp);
int	access(struct inode *ip, int mode),
	b_to_q(char *cp, int cc, struct clist *q), cntfrq_get(void),
	copyin(caddr_t f, caddr_t t, unsigned n),
	copyout(caddr_t f, caddr_t t, unsigned n), cpass(void), dfar(void),
	dfsr(void),
	estabur(unsigned nt, unsigned nd, unsigned ns, int sep, int xrw),
	fsig(struct proc *p), fubyte(caddr_t a), fumem(off_t off),
	fuword(caddr_t a), getc(struct clist *p), getw(struct clist *p),
	grow(unsigned sp), issig(void), malloc(struct map *mp, int size),
	max(unsigned a, unsigned b), min(unsigned a, unsigned b),
	ndqb(struct clist *q, int flag), newproc(void), passc(int c),
	putc(int c, struct clist *p), putw(int c, struct clist *p),
	q_to_b(struct clist *q, char *cp, int cc), save(label_t lab),
	schar(void), setpri(struct proc *pp), spl5(void), spl6(void),
	spl7(void), subyte(caddr_t a, int c), sumem(off_t off, int c),
	suser(void), suword(caddr_t a, int v),
	ttioccomm(int com, struct tty *tp, caddr_t addr, int dev),
	ttread(struct tty *tp), ufalloc(void);
caddr_t	ttwrite(struct tty *tp);
void	printf(char *fmt, ...);
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
	void	(*sy_call)(void);	/* handler */
} sysent[];
