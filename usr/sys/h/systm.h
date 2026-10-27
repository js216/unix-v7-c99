/*
 * Random set of variables
 * used by more than one
 * routine.
 */
extern	char	canonb[CANBSIZ];	/* buffer for erase and kill */
extern	struct inode *rootdir;		/* inode of root directory */
extern	struct proc *runq;		/* list of running processes */
extern	int	lbolt;			/* ticks not yet in time */
extern	time_t	time;			/* time in sec from 1970 */

/*
 * Nblkdev is the number of entries
 * (rows) in the block switch. It is
 * set in binit/bio.c by making
 * a pass over the switch.
 * Used in bounds checking on major
 * device numbers.
 */
extern	int	nblkdev;

/*
 * Number of character switch entries.
 * Set by cinit/tty.c
 */
extern	int	nchrdev;

extern	int	mpid;			/* last process id given out */
extern	char	runin;			/* scheduling flag */
extern	char	runout;			/* scheduling flag */
extern	char	runrun;			/* scheduling flag */
extern	char	curpri;			/* more scheduling */
extern	unsigned	maxmem;			/* max memory per process */
extern	daddr_t	swplo;			/* block number of swap space */
extern	int	nswap;			/* size of swap space */
extern	int	npgfree;		/* free pages of core */
extern	int	*pgstk;			/* their numbers */
extern	int	physpg;			/* the page of physio */
extern	int	updlock;		/* lock for sync */
extern	daddr_t	rablock;		/* block to be read ahead */
extern	char	regloc[];	/* locs. of saved user registers (trap.c) */
extern	char	msgbuf[MSGBUFS];	/* saved "printf" characters */
extern	char	*msgbufp;	/* next place in msgbuf */
extern	dev_t	rootdev;		/* device of the root */
extern	dev_t	swapdev;		/* swapping device */
extern	dev_t	pipedev;		/* pipe device */
extern	int	icode[];	/* user init code */
extern	int	szicode;	/* its size */
extern	unsigned long long clkcval;	/* when the clock is next due */
extern	unsigned clkreload;		/* counts per tick */
extern	unsigned clkrem, clkfrac;	/* remainder, and its sum */
extern	unsigned long long *l1tab;	/* user first-level tables */
extern	unsigned l1pa;		/* their physical address */

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
struct clist; struct map; struct text; struct tty; struct uprof;
void	acct(void);
void	addupc(caddr_t pc, struct uprof *p, int t);
void	alarm(void);
void	arm_sync_icache(caddr_t a, unsigned n);
void	bawrite(struct buf *bp);
void	bcopy(caddr_t from, caddr_t to, int count);
void	bdinit(void);
void	bdwrite(struct buf *bp);
void	bflush(dev_t dev);
void	brelse(struct buf *bp);
void	bwrite(struct buf *bp);
void	chdir(void);
void	chmod(void);
void	chown(void);
void	chroot(void);
void	cinit(void);
void	clearseg(int a);
void	clkstart(void);
void	clock(caddr_t pc, int ps);
void	clock_ddr_init(void);
void	nsinit(void);
void	etzpcinit(void);
void	nsenter(void);
void	close(void);
void	closef(struct file *fp);
void	clrbuf(struct buf *bp);
void	cninit(void);
void	cntv_ctl_set(int c);
void	cntv_cval_set(unsigned long long c);
void	copyseg(int from, int to);
void	creat(void);
void	dcflush(caddr_t a, unsigned n);
void	dcinval(caddr_t a, unsigned n);
void	ddrinit(void);
void	ddrpower(void);
void	deverror(struct buf *bp, int o1, int o2);
void	dmbsy(void);
void	dup(void);
void	exec(void);
void	exece(void);
void	exit(int rv);
void	fork(void);
void	free(dev_t dev, daddr_t bno);
void	fstat(void);
void	ftime(void);
void	getgid(void);
void	getpid(void);
void	getuid(void);
void	gtime(void);
void	gtty(void);
void	idle(void);
void	ifree(dev_t dev, ino_t ino);
void	intr_enable(void);
void	intr_restore(int s);
void	intrstart(void);
void	ioctl(void);
void	iodone(struct buf *bp);
void	iomove(caddr_t cp, int n, int flag);
void	iput(struct inode *ip);
void	irq(int *r);
void	itrunc(struct inode *ip);
void	iupdat(struct inode *ip, time_t *ta, time_t *tm);
void	iwdgstart(void);
void	kill(void);
void	klclose(dev_t dev, int flag);
void	klinit(void);
void	klintr(caddr_t pc, int ps);
void	klioctl(dev_t dev, int cmd, caddr_t addr, int flag);
void	klopen(dev_t dev, int flag);
void	klread(dev_t dev);
void	klwrite(dev_t dev);
void	link(void);
void	mapfree(int *mp, int n0, int n1);
void	maprot(int map, int a, int b, int c);
void	mapswap(int blkno, int map, int n, int rdflg);
void	mfree(struct map *mp, int size, int a);
void	mknod(void);
void	mmread(int dev);
void	mmwrite(int dev);
void	ndflush(struct clist *q, int cc);
void	nice(void);
void	nodev(dev_t dev, int flag);
void	noioctl(dev_t dev, int cmd, caddr_t addr, int flag);
void	nolioctl(int cmd, struct tty *tp, caddr_t addr);
void	nordwr(dev_t dev);
void	nostrat(struct buf *bp);
void	nosys(void);
void	nulldev(dev_t dev, int flag);
void	nullsys(void);
void	nulltty(struct tty *tp);
void	open(void);
void	openi(struct inode *ip, int rw);
void	panic(char *s);
void	panictrap(void);
void	pause(void);
void	pgfree(int pg);
void	physio(void (*strat)(struct buf *bp), struct buf *bp,
	    int dev, int rw);
void	pipe(void);
void	plock(struct inode *ip);
void	prdev(char *str, dev_t dev);
void	prele(struct inode *ip);
void	printf(char *fmt, ...);
void	profil(void);
void	psig(void);
void	psignal(struct proc *p, int sig);
void	ptfree(struct proc *p);
void	ptrace(void);
void	putchar(int c);
void	qswtch(void);
void	read(void);
void	readi(struct inode *ip);
void	readp(struct file *fp);
void	restfp(void *fps);
void	resume(int a, label_t lab);
void	rexit(void);
void	rkinit(void);
void	rkintr(caddr_t pc, int ps);
void	rkread(dev_t dev);
void	rkstrategy(struct buf *bp);
void	rkwrite(dev_t dev);
void	saccess(void);
void	savfp(void *fps);
void	sbreak(void);
void	sched(void);
void	seek(void);
void	sendsig(caddr_t p, int signo);
void	setgid(void);
void	setrun(struct proc *p);
void	setuid(void);
void	signal(int pgrp, int sig);
void	sigreturn(void);
void	sleep(caddr_t chan, int pri);
void	smount(void);
void	ssig(void);
void	startup(void);
void	stat(void);
void	stime(void);
void	stty(void);
void	sumount(void);
void	sureg(void);
void	swap(int blkno, int coreaddr, int count, int rdflg);
void	swtch(void);
void	sync(void);
void	syopen(int dev, int flag);
void	syread(int dev);
void	sysacct(void);
void	sysioctl(int dev, int cmd, caddr_t addr, int flag);
void	syslock(void);
void	sywrite(int dev);
void	timeout(void (*fun)(caddr_t arg), caddr_t arg, int tim);
void	times(void);
void	tlbflush(void);
void	trap(int *r);
void	ttbset(unsigned a);
void	ttrstrt(caddr_t arg);
void	ttstart(struct tty *tp);
void	ttychars(struct tty *tp);
void	ttyclose(struct tty *tp);
void	ttyhold(int c, struct tty *tp);
void	ttyinput(int c, struct tty *tp);
void	ttyopen(dev_t dev, struct tty *tp);
void	ttyrend(struct tty *tp, char *pb, char *pe);
void	ttyunhold(struct tty *tp);
void	umask(void);
void	unlink(void);
void	update(void);
void	user_trap_handler(int signo, int *r, unsigned a);
void	utime(void);
void	wait(void);
void	wakeup(caddr_t chan);
void	wdinit(void);
void	wdir(struct inode *ip);
void	write(void);
void	writei(struct inode *ip);
void	writep(struct file *fp);
void	xalloc(struct inode *ip);
void	xfree(void);
void	xlock(struct text *xp);
void	xread(struct text *xp);
void	xrele(struct inode *ip);
void	xumount(int dev);
void	xsync(struct text *xp);
void	xunlock(struct text *xp);
int	access(struct inode *ip, int mode);
int	b_to_q(char *cp, int cc, struct clist *q);
int	cntfrq_get(void);
int	copyin(caddr_t f, caddr_t t, unsigned n);
int	copyout(caddr_t f, caddr_t t, unsigned n);
int	cpass(void);
int	dfar(void);
int	dfsr(void);
int	estabur(unsigned ts, unsigned nt, unsigned ds, unsigned nd,
	    unsigned ns, int xrw);
void	expand(int newsize);
int	roomfor(int newsize, int tn), swapfits(int n);
int	fsig(struct proc *p);
int	fkbyte(char *a);
int	fkword(int *a, int *w);
int	skbyte(char *a, int c);
int	skword(int *a, int w);
int	fubyte(caddr_t a);
int	fumem(int dev, off_t off);
int	fuword(caddr_t a);
int	getc(struct clist *p);
int	getw(struct clist *p);
int	grow(unsigned sp);
int	imgpage(struct proc *p, int i);
int	intr_disable(void);
int	issig(void);
int	malloc(struct map *mp, int size);
int	mapalloc(int *mp, int n0, int n1);
int	*mapent(int map, int i);
int	mapneed(int n0, int n1);
int	max(unsigned a, unsigned b);
int	min(unsigned a, unsigned b);
int	ndqb(struct clist *q, int flag);
int	newproc(void);
int	pgalloc(void);
int	passc(int c);
int	putc(int c, struct clist *p);
int	putw(int c, struct clist *p);
int	q_to_b(struct clist *q, char *cp, int cc);
int	save(label_t lab);
int	schar(void);
int	setpri(struct proc *pp);
int	subyte(caddr_t a, int c);
int	sumem(int dev, off_t off, int c);
int	suser(void);
int	suword(caddr_t a, int v);
int	ttioccomm(int com, struct tty *tp, caddr_t addr, int dev);
int	ttread(struct tty *tp);
int	uchar(void);
int	ufalloc(void);
void	xswap(struct proc *p, int os);
caddr_t	machine_init(void);
caddr_t	ttwrite(struct tty *tp);
char	*devaddr(int dev, off_t off);
unsigned long long cntvct_get(void);
unsigned	vtop(caddr_t va);
#define	fuibyte	fubyte
#define	fuiword	fuword
#define	suibyte	subyte
#define	suiword	suword
#define	copyiin	copyin
#define	copyiout	copyout
/*
 * Instrumentation
 */
extern	int	dk_busy;
extern	long	dk_time[32];
extern	long	dk_numb[3];
extern	long	dk_wds[3];
extern	long	tk_nin;
extern	long	tk_nout;

/*
 * Structure of the system-entry table
 */
extern struct sysent {
	char	sy_narg;		/* total number of arguments */
	char	sy_nrarg;		/* number of args in registers */
	void	(*sy_call)(void);	/* handler */
} sysent[];
