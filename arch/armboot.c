#include "../h/param.h"
#include "../h/dir.h"
#include "../h/ino.h"
#include "../h/filsys.h"
#include "../h/buf.h"
#include "../h/arm.h"
#include "../h/proto.h"

#define	NADDR			13
#define	IFMT			0170000
#define	IFDIR			0040000
#define	IFCHR			0020000
#define	IFBLK			0060000
#define	IFREG			0100000
#define	NFD			16
#define	NPIPES			4
#define	NFORK			8
#define	PIPESIZ			65536

struct file {
	ino_t	ino;
	unsigned short mode;
	unsigned int size;
	unsigned int off;
	daddr_t	addr[NADDR];
	char	*mem;
	int	pipe;
	int	wpipe;
	int	eof;	/* /dev/console: 1=next read returns EOF then clears */
};

struct pipe {
	char	buf[PIPESIZ];
	unsigned int rpos;
	unsigned int wpos;
	int	used;
	int	writer;
};

struct ustat {
	int	st_dev;
	ino_t	st_ino;
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

static unsigned int l1[4096] __attribute__((aligned(16384)));
static unsigned char blkbuf[BSIZE] __attribute__((aligned(512)));
static unsigned char usave[USERSIZE];
static unsigned char fusave[NFORK][USERSIZE];
static char argbuf[UARGLEN];
static char tmpname[64];
static char tmpbuf[8192];
static struct pipe pipes[NPIPES];
static struct file files[NFD];
static struct file fsave[NFD];
static struct file ffsave[NFORK][NFD];
static int closed[NFD];
static int csave[NFD];
static int cfsave[NFORK][NFD];
static ino_t cwdino = ROOTINO;
static ino_t cwdsave;
static ino_t cfwsave[NFORK];
static unsigned int tmpused;
static ino_t nextino;
static daddr_t nextblk;
static int spawned;
/* V7 init.c::single() opens /dev/console and exec()s the operator's shell;
 * on a real PDP-11 the operator typed ^D to exit single-user mode.  This
 * kernel has no operator -- the qemu-shell.py harness only starts feeding
 * stdin after `login:` appears.  So the very first reader of /dev/console
 * (init's single-user sh) is handed EOF immediately, which makes sh return
 * and lets init advance through runcom() into multiple()'s getty-spawn
 * loop.  All later /dev/console openers (the gettys themselves) see the
 * normal UART.  Tracked here so the EOF-token is consumed exactly once. */
static int console_seen;
static int childmode;
static int childdone[NFD];
static int childppid[NFD];
static int childexitval[NFD];
static int ndone;
static int childpid[NFORK];
static int pidsave[NFORK];
static int curpid = 1;
static int nextpid = 2;
static int sframe[17];
static int cframe[NFORK][17];

/*
 * Signal facility.
 *
 * V7 user-space stores SIG_DFL as 0 and SIG_IGN as 1; anything else is a
 * function pointer in the running image's text segment.  We keep one
 * table per process depth: `handlers[1..NSIG]` holds the disposition for
 * the currently-running process, and `hsave[d]` saves what was in place
 * for the ancestor at depth d when it forked.  `pending` records signals
 * that have been kkill()'d but not yet delivered, with the same depth
 * stacking via `psave[]`.
 *
 * Delivery is synchronous on the next user-mode resume: kkill() targets
 * either curpid (deliver before the syscall returns) or an ancestor
 * (queue, deliver when the S_EXIT pop restores them).  The handler is
 * called with `r0=sig`; its bx-lr lands on the sigreturn trampoline at
 * UENTRY_SIGRETURN, which issues an S_SIGRETURN syscall to pop the
 * saved PC + r0 we stashed on the user stack and resume the
 * interrupted code in place.
 */
#define	SIG_DFL		0L
#define	SIG_IGN		1L

/* h/param.h already defines NSIG (= 17 in this V7 port). */

static long handlers[NSIG+1];
static long hsave[NFORK][NSIG+1];
static unsigned int pending;
static unsigned int psave[NFORK];
static int kumask;
static int kuid;
static int kuidsave[NFORK];

void
mmuinit(void)
{
	unsigned int i, pa;

	for(i=0; i<4096; i++)
		l1[i] = 0;
#ifdef EVB
	/* STM32MP135 DDR window: kernel image and DDR-staged rootfs both
	 * live well above the qemu default KERNBASE.  Map a generous span
	 * from 0xC0000000 covering DDR (0xC0000000..0xE0000000) plus the
	 * APB peripheral block that hosts USART4 (0x40000000..0x50000000)
	 * so putchar() keeps working after MMU is enabled. */
	for(pa=0x40000000U; pa<0x50000000U; pa+=0x00100000U)
		l1[pa>>20] = (pa & 0xfff00000U) | 0x00000402U;
	for(pa=0xC0000000U; pa<0xE0000000U; pa+=0x00100000U)
		l1[pa>>20] = (pa & 0xfff00000U) | 0x00000402U;
	/* USERPHYS as defined in h/arm.h points at 0x41000000, which on the
	 * STM32MP135 is APB peripheral space, not RAM.  Writing the user
	 * image there silently drops bytes (or faults).  Carve a 1 MiB DDR
	 * slot well above the kernel image (0xC2000000) and the DDR-staged
	 * rootfs (0xC4400000 + ~16 MiB) for the user-physical region. */
	l1[0] = 0xC8000000U | 0x00000c02U;
#else
	for(pa=KERNBASE; pa<0x48000000U; pa+=0x00100000U)
		l1[pa>>20] = (pa & 0xfff00000U) | 0x00000402U;
	for(pa=0x08000000U; pa<0x0c000000U; pa+=0x00100000U)
		l1[pa>>20] = (pa & 0xfff00000U) | 0x00000402U;
	l1[0] = USERPHYS | 0x00000c02U;
#endif
	mmu_on((unsigned int)l1);
}

static void
bzero(char *p, unsigned int n)
{

	while(n--)
		*p++ = 0;
}

static void
bcopy(char *f, char *t, unsigned int n)
{

	while(n--)
		*t++ = *f++;
}

static int
strncmp(char *a, char *b, int n)
{

	while(n-- > 0) {
		if(*a != *b)
			return(*a - *b);
		if(*a == 0)
			return(0);
		a++;
		b++;
	}
	return(0);
}

static int
strcmp(char *a, char *b)
{

	while(*a == *b) {
		if(*a == 0)
			return(0);
		a++;
		b++;
	}
	return(*a - *b);
}

static void
shim_bread(daddr_t blkno, void *buf)
{
	struct buf *bp;

	bp = bread((dev_t)rootdev, blkno);
	bcopy((char *)bp->b_un.b_addr, (char *)buf, (unsigned int)BSIZE);
	brelse(bp);
}

static void
shim_bwrite(daddr_t blkno, void *buf)
{
	struct buf *bp;

	bp = getblk((dev_t)rootdev, blkno);
	bcopy((char *)buf, (char *)bp->b_un.b_addr, (unsigned int)BSIZE);
	bwrite(bp);
}

static daddr_t
addr(char *p)
{

	return(((daddr_t)(unsigned char)p[0]) |
	    ((daddr_t)(unsigned char)p[1] << 8) |
	    ((daddr_t)(unsigned char)p[2] << 16));
}

static daddr_t
addr4(char *p)
{

	return(((daddr_t)(unsigned char)p[0]) |
	    ((daddr_t)(unsigned char)p[1] << 8) |
	    ((daddr_t)(unsigned char)p[2] << 16) |
	    ((daddr_t)(unsigned char)p[3] << 24));
}

static int
iget(ino_t ino, struct dinode *dp)
{
	int off;

	if(ino < ROOTINO)
		return(-1);
	shim_bread(itod(ino), blkbuf);
	off = itoo(ino) * sizeof(struct dinode);
	bcopy((char *)&blkbuf[off], (char *)dp, sizeof(*dp));
	if(dp->di_mode == 0)
		return(-1);
	return(0);
}

static int
loadino(ino_t ino, struct file *fp)
{
	struct dinode di;
	int i;

	if(iget(ino, &di) < 0)
		return(-1);
	fp->ino = ino;
	fp->mode = di.di_mode;
	fp->size = (unsigned int)di.di_size;
	fp->off = 0;
	for(i=0; i<NADDR; i++)
		fp->addr[i] = addr(&di.di_addr[i*3]);
	return(0);
}

static void
put16(char *p, unsigned int v)
{

	p[0] = v;
	p[1] = v >> 8;
}

static void
put24(char *p, daddr_t v)
{

	p[0] = (char)v;
	p[1] = (char)(v >> 8);
	p[2] = (char)(v >> 16);
}

static void
put32(char *p, daddr_t v)
{

	p[0] = (char)v;
	p[1] = (char)(v >> 8);
	p[2] = (char)(v >> 16);
	p[3] = (char)(v >> 24);
}

static int
putino(ino_t ino, struct file *fp)
{
	char *p;
	int i, off;

	if(ino < ROOTINO)
		return(-1);
	shim_bread(itod(ino), blkbuf);
	off = itoo(ino) * sizeof(struct dinode);
	p = (char *)&blkbuf[off];
	bzero(p, sizeof(struct dinode));
	put16(p+0, fp->mode);
	put16(p+2, 1);
	put32(p+8, (daddr_t)fp->size);
	for(i=0; i<NADDR; i++)
		put24(p+12+i*3, fp->addr[i]);
	shim_bwrite(itod(ino), blkbuf);
	return(0);
}

static int
readi(struct file *fp, unsigned int off, char *buf, unsigned int n)
{
	unsigned int tot, m, boff, lbn;
	daddr_t bn;
	daddr_t ib;

	if(off >= fp->size)
		return(0);
	if(off + n > fp->size)
		n = fp->size - off;
	tot = 0;
	while(n != 0) {
		lbn = off >> BSHIFT;
		if(lbn < NADDR-3)
			bn = fp->addr[lbn];
		else {
			lbn -= NADDR-3;
			if(lbn < NINDIR) {
				if(fp->addr[NADDR-3] == 0)
					break;
				shim_bread(fp->addr[NADDR-3], blkbuf);
				bn = addr4((char *)&blkbuf[lbn*4]);
			} else {
				lbn -= NINDIR;
				if(fp->addr[NADDR-2] == 0)
					break;
				shim_bread(fp->addr[NADDR-2], blkbuf);
				ib = addr4((char *)&blkbuf[(lbn/NINDIR)*4]);
				if(ib == 0)
					break;
				shim_bread(ib, blkbuf);
				bn = addr4((char *)&blkbuf[(lbn%NINDIR)*4]);
			}
		}
		if(bn == 0)
			break;
		boff = off & BMASK;
		m = BSIZE - boff;
		if(m > n)
			m = n;
		shim_bread(bn, blkbuf);
		bcopy((char *)&blkbuf[boff], buf, m);
		buf += m;
		off += m;
		tot += m;
		n -= m;
	}
	return((int)tot);
}

static int
writei(struct file *fp, unsigned int off, char *buf, unsigned int n)
{
	unsigned int tot, m, boff, lbn;
	daddr_t bn;

	tot = 0;
	while(n != 0) {
		lbn = off >> BSHIFT;
		if(lbn >= NADDR-3)
			break;
		bn = fp->addr[lbn];
		if(bn == 0) {
			bn = nextblk++;
			fp->addr[lbn] = bn;
			bzero((char *)blkbuf, BSIZE);
		} else
			shim_bread(bn, blkbuf);
		boff = off & BMASK;
		m = BSIZE - boff;
		if(m > n)
			m = n;
		bcopy(buf, (char *)&blkbuf[boff], m);
		shim_bwrite(bn, blkbuf);
		buf += m;
		off += m;
		tot += m;
		n -= m;
	}
	if(off > fp->size)
		fp->size = off;
	return((int)tot);
}

static void
scanind(daddr_t bn, int lev)
{
	unsigned char ibuf[BSIZE];
	daddr_t ib;
	unsigned int i;

	if(bn == 0)
		return;
	if(bn >= nextblk)
		nextblk = bn + 1;
	shim_bread(bn, ibuf);
	for(i=0; i<NINDIR; i++) {
		ib = addr4((char *)&ibuf[i*4]);
		if(ib == 0)
			continue;
		if(ib >= nextblk)
			nextblk = ib + 1;
		if(lev)
			scanind(ib, lev-1);
	}
}

static void
scanfs(void)
{
	struct dinode di;
	struct file fp;
	ino_t ino, maxino;
	int i;

	maxino = ((struct filsys *)blkbuf)->s_isize * INOPB;
	nextino = ROOTINO;
	nextblk = 2 + ((struct filsys *)blkbuf)->s_isize;
	for(ino=ROOTINO; ino<maxino; ino++)
		if(iget(ino, &di) == 0) {
			nextino = ino + 1;
			if(loadino(ino, &fp) == 0) {
				for(i=0; i<NADDR-1; i++)
					if(fp.addr[i] >= nextblk)
						nextblk = fp.addr[i] + 1;
				scanind(fp.addr[NADDR-3], 0);
				scanind(fp.addr[NADDR-2], 1);
			}
		}
}

/*
 * Path-to-inum lookup goes straight to V7 sys/nami.c::namei() via the
 * v7_namei_inum() bridge in arch/v7stubs.c.  That bridge holds the
 * includes for h/inode.h/h/user.h and turns V7's
 * `struct inode *namei(int (*)(void), int)` (u.u_dirp in, locked inode
 * out) into the `ino_t v7_namei_inum(char *path)` signature the shim's
 * remaining file-system call sites (kchdir, kopen, kcreat, klink, ...)
 * still consume.  The previous `static ino_t shim_namei(...)` wrapper
 * in this file is retired: all call sites call v7_namei_inum() directly.
 */
extern ino_t v7_namei_inum(char *path);

static ino_t
parenti(char *path, char *name)
{
	char buf[128];
	char *p, *s;
	int i;

	s = path;
	p = buf;
	while(*s && p < &buf[sizeof(buf)-1])
		*p++ = *s++;
	*p = 0;
	p = buf;
	while(*p)
		p++;
	while(p > buf && p[-1] != '/')
		p--;
	for(i=0; i<DIRSIZ; i++)
		name[i] = 0;
	s = p;
	for(i=0; i<DIRSIZ && *s; i++)
		name[i] = *s++;
	if(p == buf)
		return(cwdino);
	if(p == buf+1) {
		buf[1] = 0;
		return(ROOTINO);
	}
	p[-1] = 0;
	return(v7_namei_inum(buf));
}

static int
kchdir(char *path)
{
	struct file fp;
	ino_t ino;

	ino = v7_namei_inum(path);
	if(ino == 0 || loadino(ino, &fp) < 0 || (fp.mode & IFMT) != IFDIR)
		return(-1);
	cwdino = ino;
	return(0);
}

static int
kopen(char *path)
{
	ino_t ino;
	int fd;

	if(tmpname[0] && strcmp(path, tmpname) == 0) {
		for(fd=0; fd<NFD; fd++)
			if((fd >= 3 || closed[fd]) && files[fd].ino == 0) {
				bzero((char *)&files[fd], sizeof(files[fd]));
				files[fd].ino = 1;
				files[fd].mode = IFREG;
				files[fd].size = tmpused;
				files[fd].mem = tmpbuf;
				closed[fd] = 0;
				return(fd);
			}
		return(-1);
	}
	/* /dev/console is the console operator's typewriter in V7.  V7's
	 * init.c::single() open()s it as the controlling tty for the
	 * single-user shell, and dfork() opens it again as 0/1/2 before
	 * exec'ing getty.  Mark such fds IFCHR so kread()/kwrite() route
	 * through the UART fast-path.  The very first opener (init's
	 * single-user sh) also gets a one-shot EOF token so its initial
	 * read returns 0 and the shell exits, letting init advance into
	 * the multi-user getty loop. */
	if(strcmp(path, "/dev/console") == 0) {
		for(fd=0; fd<NFD; fd++)
			if((fd >= 3 || closed[fd]) && files[fd].ino == 0) {
				bzero((char *)&files[fd], sizeof(files[fd]));
				files[fd].ino = 1;
				files[fd].mode = IFCHR;
				files[fd].size = 0;
				files[fd].eof = console_seen ? 0 : 1;
				console_seen = 1;
				closed[fd] = 0;
				return(fd);
			}
		return(-1);
	}
	ino = v7_namei_inum(path);
	if(ino == 0)
		return(-1);
	for(fd=0; fd<NFD; fd++)
		if((fd >= 3 || closed[fd]) && files[fd].ino == 0) {
			bzero((char *)&files[fd], sizeof(files[fd]));
			if(loadino(ino, &files[fd]) < 0)
				return(-1);
			closed[fd] = 0;
			return(fd);
		}
	return(-1);
}

static int
kcreat(char *path, int mode)
{
	struct file dp, fp;
	struct direct de;
	char name[DIRSIZ];
	ino_t pino;
	int fd, i;

	pino = parenti(path, name);
	if(pino == 0 || loadino(pino, &dp) < 0 || (dp.mode & IFMT) != IFDIR)
		return(-1);
	for(i=0; i<(int)dp.size; i += sizeof(de)) {
		(void)readi(&dp, (unsigned int)i, (char *)&de, sizeof(de));
		if(de.d_ino && strncmp(de.d_name, name, DIRSIZ) == 0) {
			for(fd=0; fd<NFD; fd++)
				if((fd >= 3 || closed[fd]) && files[fd].ino == 0) {
					if(loadino(de.d_ino, &files[fd]) < 0)
						return(-1);
					if((files[fd].mode & IFMT) != IFREG)
						return(-1);
					files[fd].mode = IFREG | ((mode & 07777) & ~kumask);
					files[fd].size = 0;
					bzero((char *)files[fd].addr, sizeof(files[fd].addr));
					closed[fd] = 0;
					return(fd);
				}
			return(-1);
		}
	}
	for(fd=0; fd<NFD; fd++)
		if((fd >= 3 || closed[fd]) && files[fd].ino == 0) {
			bzero((char *)&files[fd], sizeof(files[fd]));
			files[fd].ino = nextino++;
			files[fd].mode = IFREG | ((mode & 07777) & ~kumask);
			files[fd].size = 0;
			if(putino(files[fd].ino, &files[fd]) < 0)
				return(-1);
			bzero((char *)&de, sizeof(de));
			de.d_ino = files[fd].ino;
			for(i=0; i<DIRSIZ; i++)
				de.d_name[i] = name[i];
			bcopy((char *)&dp, (char *)&fp, sizeof(fp));
			if(writei(&fp, fp.size, (char *)&de, sizeof(de)) != sizeof(de))
				return(-1);
			(void)putino(pino, &fp);
			closed[fd] = 0;
			return(fd);
		}
	return(-1);
}

static int
klink(char *from, char *to)
{
	struct file dp, fp;
	struct direct de;
	char name[DIRSIZ];
	ino_t ino, pino;
	int i;

	ino = v7_namei_inum(from);
	if(ino == 0 || loadino(ino, &fp) < 0)
		return(-1);
	if(v7_namei_inum(to) != 0)
		return(-1);
	pino = parenti(to, name);
	if(pino == 0 || loadino(pino, &dp) < 0 || (dp.mode & IFMT) != IFDIR)
		return(-1);
	bzero((char *)&de, sizeof(de));
	de.d_ino = ino;
	for(i=0; i<DIRSIZ; i++)
		de.d_name[i] = name[i];
	if(writei(&dp, dp.size, (char *)&de, sizeof(de)) != sizeof(de))
		return(-1);
	(void)putino(pino, &dp);
	return(0);
}

static int
kmknod(char *path, int mode, int dev)
{
	struct file dp, fp;
	struct direct de;
	char name[DIRSIZ];
	ino_t pino;
	int i;

	if(v7_namei_inum(path) != 0)
		return(-1);
	pino = parenti(path, name);
	if(pino == 0 || loadino(pino, &dp) < 0 || (dp.mode & IFMT) != IFDIR)
		return(-1);
	bzero((char *)&fp, sizeof(fp));
	fp.ino = nextino++;
	fp.mode = (mode & IFMT) | ((mode & 07777) & ~kumask);
	/* For block/character special files, V7 stores the device number
	 * in i_addr[0]. We piggyback on the first block-pointer slot
	 * (which is unused for non-data inodes) so kstat/kfstat can hand
	 * it back as st_rdev for ls -l. */
	if((mode & IFMT) == IFCHR || (mode & IFMT) == IFBLK)
		fp.addr[0] = (daddr_t)dev;
	if(putino(fp.ino, &fp) < 0)
		return(-1);
	bzero((char *)&de, sizeof(de));
	de.d_ino = fp.ino;
	for(i=0; i<DIRSIZ; i++)
		de.d_name[i] = name[i];
	if(writei(&dp, dp.size, (char *)&de, sizeof(de)) != sizeof(de))
		return(-1);
	(void)putino(pino, &dp);
	return(0);
}

static int
kunlink(char *path)
{
	struct file dp, fp;
	struct direct de;
	char name[DIRSIZ];
	ino_t pino;
	int i;

	pino = parenti(path, name);
	if(pino == 0 || loadino(pino, &dp) < 0 || (dp.mode & IFMT) != IFDIR)
		return(-1);
	for(i=0; i<(int)dp.size; i += sizeof(de)) {
		(void)readi(&dp, (unsigned int)i, (char *)&de, sizeof(de));
		if(de.d_ino && strncmp(de.d_name, name, DIRSIZ) == 0) {
			if(loadino(de.d_ino, &fp) < 0)
				return(-1);
			de.d_ino = 0;
			(void)writei(&dp, (unsigned int)i, (char *)&de, sizeof(de));
			(void)putino(pino, &dp);
			return(0);
		}
	}
	return(-1);
}

static int
kchmod(char *path, int mode)
{
	struct file fp;
	ino_t ino;

	/* /dev/console is kernel-resident (no inode); init.c::dfork()
	 * chmod()s it to 0622 before fork-execing getty -- silently accept. */
	if(strcmp(path, "/dev/console") == 0)
		return(0);
	ino = v7_namei_inum(path);
	if(ino == 0 || loadino(ino, &fp) < 0)
		return(-1);
	fp.mode = (fp.mode & IFMT) | (mode & 07777);
	return(putino(ino, &fp));
}

static int
kread(int fd, char *buf, unsigned int n)
{
	int c, r;

	if(fd >= 0 && fd < NFD && files[fd].pipe != 0) {
		struct pipe *pp;

		pp = &pipes[files[fd].pipe-1];
		if(pp->rpos >= pp->wpos)
			return(0);
		if(n > pp->wpos - pp->rpos)
			n = pp->wpos - pp->rpos;
		bcopy(pp->buf + pp->rpos, buf, n);
		pp->rpos += n;
		return(n);
	}
	if(fd == 0 || (fd >= 0 && fd < NFD && files[fd].mode == IFCHR)) {
		if(fd == 0 && files[fd].ino != 0 && files[fd].mode != IFCHR)
			goto file;
		if(n == 0)
			return(0);
		/* One-shot EOF for init's single-user sh (see console_seen
		 * above); after the first read the fd reverts to normal UART
		 * semantics so dfork()'s gettys read keystrokes normally. */
		if(fd >= 0 && fd < NFD && files[fd].eof) {
			files[fd].eof = 0;
			return(0);
		}
		c = getchar();
		if(c == '\r')
			c = '\n';
		putchar(c);
		*buf = (char)c;
		return(1);
	}
file:
	if(fd < 0 || fd >= NFD || files[fd].ino == 0)
		return(-1);
	if(files[fd].mem != 0) {
		if(files[fd].off >= files[fd].size)
			return(0);
		if(n > files[fd].size - files[fd].off)
			n = files[fd].size - files[fd].off;
		bcopy(files[fd].mem + files[fd].off, buf, n);
		files[fd].off += n;
		return(n);
	}
	r = readi(&files[fd], files[fd].off, buf, n);
	if(r > 0)
		files[fd].off += (unsigned int)r;
	return(r);
}

static int
kgetdents(int fd, char *buf, unsigned int n)
{

	if(fd < 0 || fd >= NFD || files[fd].ino == 0)
		return(-1);
	if((files[fd].mode & IFMT) != IFDIR)
		return(-1);
	return(kread(fd, buf, n));
}

static int
kclose(int fd)
{
	int i, j, p;

		if(fd >= 0 && fd < NFD) {
			p = files[fd].pipe;
			if(files[fd].pipe != 0 && files[fd].wpipe)
				pipes[files[fd].pipe-1].writer = 0;
		if(files[fd].ino > 1 && files[fd].mem == 0 && files[fd].pipe == 0)
			(void)putino(files[fd].ino, &files[fd]);
		bzero((char *)&files[fd], sizeof(files[fd]));
			if(p) {
				for(i=0; i<NFD; i++)
					if(files[i].pipe == p)
						break;
				if(i == NFD && (childmode || spawned))
					for(i=0; i<NFD; i++)
						if(fsave[i].pipe == p)
							break;
				for(j=0; i == NFD && j<childmode; j++)
					for(i=0; i<NFD; i++)
						if(ffsave[j][i].pipe == p)
							break;
				if(i == NFD)
					bzero((char *)&pipes[p-1], sizeof(pipes[p-1]));
			}
		if(fd < 3)
			closed[fd] = 1;
	}
	return(0);
}

static int
kdup(int from, int to)
{
	int i;

	if(from < 0 || from >= NFD)
		return(-1);
	if(to < 0) {
		for(i=0; i<NFD; i++)
			if(files[i].ino == 0)
				break;
		if(i == NFD)
			return(-1);
		to = i;
	}
	if(to >= NFD)
		return(-1);
	if(files[from].ino != 0)
		bcopy((char *)&files[from], (char *)&files[to], sizeof(files[to]));
	else {
		bzero((char *)&files[to], sizeof(files[to]));
		files[to].ino = 1;
		files[to].mode = IFCHR;
	}
	closed[to] = 0;
	return(to);
}

static int
kseek(int fd, int off, int whence)
{
	unsigned int n;

	if(fd < 0 || fd >= NFD || files[fd].ino == 0)
		return(-1);
	if(whence == 0)
		n = (unsigned int)off;
	else if(whence == 1)
		n = files[fd].off + (unsigned int)off;
	else if(whence == 2)
		n = files[fd].size + (unsigned int)off;
	else
		return(-1);
	files[fd].off = n;
	return((int)n);
}

static int
kpipe(int *fdp)
{
	int f0, f1, i, p;

	f0 = -1;
	f1 = -1;
	for(i=0; i<NFD; i++)
		if((i >= 3 || closed[i]) && files[i].ino == 0) {
			if(f0 < 0)
				f0 = i;
			else {
				f1 = i;
				break;
			}
		}
	if(f1 < 0)
		return(-1);
	for(p=0; p<NPIPES; p++)
		if(!pipes[p].used)
			break;
	if(p == NPIPES)
		return(-1);
	bzero((char *)&pipes[p], sizeof(pipes[p]));
	pipes[p].used = 1;
	pipes[p].writer = 1;
	bzero((char *)&files[f0], sizeof(files[f0]));
	bzero((char *)&files[f1], sizeof(files[f1]));
	files[f0].ino = 010000 + p;
	files[f0].mode = IFCHR;
	files[f0].pipe = p+1;
	files[f1].ino = 010000 + p;
	files[f1].mode = IFCHR;
	files[f1].pipe = p+1;
	files[f1].wpipe = 1;
	closed[f0] = 0;
	closed[f1] = 0;
	fdp[0] = f0;
	fdp[1] = f1;
	return(0);
}

static void
kdone(int pid, int ppid, int code)
{

	if(ndone < NFD) {
		childdone[ndone] = pid;
		childppid[ndone] = ppid;
		childexitval[ndone] = code;
		ndone++;
	}
}

/*
 * V7 wait(2) returns the child's PID and stores a packed status word
 * in *statp: the high byte is the exit code, the low 7 bits the
 * terminating signal (always 0 here -- only normal exit is implemented).
 * sh's await() pulls $? out of (status >> 8) & 0xff.
 */
static int
kwait(int ppid, int *statp)
{
	int i, pid, code;

	for(i=0; i<ndone; i++)
		if(childppid[i] == ppid)
			break;
	if(i == ndone)
		return(-1);
	pid  = childdone[i];
	code = childexitval[i];
	for(i++; i<ndone; i++) {
		childdone[i-1]    = childdone[i];
		childppid[i-1]    = childppid[i];
		childexitval[i-1] = childexitval[i];
	}
	ndone--;
	if(statp != 0)
		*statp = (code & 0xff) << 8;
	return(pid);
}

static void
kflush(void)
{
	int i;

	for(i=0; i<NFD; i++)
		if(files[i].ino > 1 && files[i].mem == 0 &&
		    files[i].pipe == 0 && (files[i].mode & IFMT) == IFREG)
			(void)putino(files[i].ino, &files[i]);
}

static int
ustat(ino_t ino, struct file *fp, struct ustat *st)
{

	st->st_dev = 0;
	st->st_ino = ino;
	st->st_mode = fp->mode;
	st->st_nlink = 1;
	st->st_uid = 0;
	st->st_gid = 0;
	st->st_rdev = ((fp->mode & IFMT) == IFCHR ||
	    (fp->mode & IFMT) == IFBLK) ? (int)fp->addr[0] : 0;
	st->st_size = fp->size;
	st->st_atime = 0;
	st->st_mtime = 0;
	st->st_ctime = 0;
	return(0);
}

static int
kstat(char *path, struct ustat *st)
{
	struct file fp;
	ino_t ino;

	ino = v7_namei_inum(path);
	if(ino == 0 || loadino(ino, &fp) < 0)
		return(-1);
	return(ustat(ino, &fp, st));
}

static int
kfstat(int fd, struct ustat *st)
{

	if(fd >= 0 && fd <= 2 && files[fd].ino == 0) {
		st->st_dev = 0;
		st->st_ino = fd;
		st->st_mode = IFCHR;
		st->st_size = 0;
		return(0);
	}
	if(fd < 0 || fd >= NFD || files[fd].ino == 0)
		return(-1);
	return(ustat(files[fd].ino, &files[fd], st));
}

static int
kexec(char *path)
{
	struct file fp;
	ino_t ino;

	ino = v7_namei_inum(path);
	if(ino == 0 || loadino(ino, &fp) < 0)
		return(-1);
	if(fp.size >= USERSIZE - UENTRY)
		return(-1);
	bzero((char *)USERBASE, USERSIZE);
	if(readi(&fp, 0, (char *)UENTRY, fp.size) != (int)fp.size)
		return(-1);
	/* Drop a sigreturn trampoline at UENTRY_SIGTRAMP and reset every
	 * non-IGN handler to SIG_DFL: V7 exec semantics. */
	{
		volatile unsigned int *t;
		int i;
		t = (volatile unsigned int *)UENTRY_SIGTRAMP;
		t[0] = 0xe3a0708bU;	/* mov r7, #139 (S_SIGRETURN)  */
		t[1] = 0xef000000U;	/* svc #0                       */
		for(i=1; i<=NSIG; i++)
			if(handlers[i] != SIG_IGN)
				handlers[i] = SIG_DFL;
		pending = 0;
	}
	return(0);
}

static void
kargs(char *path, char **argv)
{
	char *p;
	int i, n;

	bzero(argbuf, sizeof(argbuf));
	n = 0;
	if(argv != 0 && argv[0] != 0) {
		for(i=0; argv[i] != 0 && n < (int)sizeof(argbuf)-1; i++) {
			if(i)
				argbuf[n++] = ' ';
			for(p=argv[i]; *p && n < (int)sizeof(argbuf)-1; p++)
				argbuf[n++] = *p;
		}
	} else {
		p = path;
		while(*p)
			p++;
		while(p > path && p[-1] != '/')
			p--;
		while(*p && n < (int)sizeof(argbuf)-1)
			argbuf[n++] = *p++;
	}
}

static int
kexec2(char *path, char **argv)
{
	int e;

	kargs(path, argv);
	e = kexec(path);
	if(e == 0) {
		bzero((char *)UARGV, UARGLEN);
		bcopy(argbuf, (char *)UARGV, UARGLEN-1);
	}
	return(e);
}

static int
kspawn(char *path, char *args, int *r)
{
	char *p;
	int n;

	if(spawned)
		return(-1);
	bcopy((char *)USERBASE, (char *)usave, USERSIZE);
	bcopy((char *)r, (char *)sframe, sizeof(sframe));
	bcopy((char *)files, (char *)fsave, sizeof(files));
	bcopy((char *)closed, (char *)csave, sizeof(closed));
	cwdsave = cwdino;
	bzero(argbuf, sizeof(argbuf));
	p = path;
	while(*p)
		p++;
	while(p > path && p[-1] != '/')
		p--;
	n = 0;
	while(*p && n < (int)sizeof(argbuf)-1)
		argbuf[n++] = *p++;
	if(args != NULL && *args && n < (int)sizeof(argbuf)-1) {
		argbuf[n++] = ' ';
		while(*args && n < (int)sizeof(argbuf)-1)
			argbuf[n++] = *args++;
	}
	if(kexec(path) < 0) {
		bcopy((char *)usave, (char *)USERBASE, USERSIZE);
		bcopy((char *)fsave, (char *)files, sizeof(files));
		bcopy((char *)csave, (char *)closed, sizeof(closed));
		cwdino = cwdsave;
		return(-1);
	}
	bzero((char *)UARGV, UARGLEN);
	bcopy(argbuf, (char *)UARGV, UARGLEN-1);
	spawned = 1;
	r[13] = USTACK;
	r[14] = 0;
	r[15] = UENTRY;
	return(0);
}

/*
 * Set the handler for `sig` to `fun` and return the previous value.
 * Caller is responsible for valid signal numbers.
 */
static long
ksignal(int sig, long fun)
{
	long old;

	if(sig <= 0 || sig > NSIG)
		return(-1);
	old = handlers[sig];
	handlers[sig] = fun;
	return(old);
}

/*
 * Queue signal `sig` for delivery to `pid`.  Self-kill marks the
 * current frame's pending bits; killing an ancestor reaches into the
 * matching psave[] slot so the signal lands when the S_EXIT pop
 * restores that frame.  Targeting a sibling pid (i.e. one already
 * exited under our sequential fork model) is a no-op success: V7
 * code expects `kill` to succeed against any reachable pid.
 */
static int
kkill(int pid, int sig)
{
	int d;

	if(sig < 0 || sig > NSIG)
		return(-1);
	if(sig == 0)
		return(0);
	if(pid == curpid) {
		pending |= 1U << sig;
		return(0);
	}
	for(d = 0; d < childmode; d++) {
		if(pidsave[d] == pid) {
			psave[d] |= 1U << sig;
			return(0);
		}
	}
	for(d = 0; d < childmode; d++) {
		if(childpid[d] == pid)
			return(0);
	}
	return(-1);
}

/*
 * Sigreturn: pop the saved-PC + saved-r0 pair the kernel pushed onto
 * the user stack when the signal was delivered, and restore them in
 * the trap frame so the trap-return path resumes the interrupted
 * code with its original r0 value.
 */
static void
ksigreturn(int *r)
{
	unsigned int sp;
	unsigned int saved_pc, saved_r0;

	sp = (unsigned int)r[13];
	saved_pc = *(volatile unsigned int *)sp;
	saved_r0 = *(volatile unsigned int *)(sp + 4);
	r[13] = (int)(sp + 8);
	r[15] = (int)saved_pc;
	r[0]  = (int)saved_r0;
}

/*
 * If a deliverable signal is pending for the current process, redirect
 * the trap frame so user-mode resumes in the handler with `r0=sig` and
 * `lr=UENTRY_SIGTRAMP`.  The original PC and r0 are pushed onto the
 * user stack so ksigreturn() can put them back when the handler
 * finishes.  Only one signal is delivered per trap return; remaining
 * pending bits ride along into the next exit-to-user.
 */
static void
deliver_signal(int *r)
{
	int sig;
	long h;
	unsigned int sp;

	if(pending == 0)
		return;
	for(sig = 1; sig <= NSIG; sig++) {
		if((pending & (1U << sig)) == 0)
			continue;
		pending &= ~(1U << sig);
		h = handlers[sig];
		if(h == SIG_IGN)
			continue;
		if(h == SIG_DFL) {
			/* No fancy default actions yet -- the V7 default
			 * for most catchable signals is process death;
			 * absent a real exit/wait flow here, drop the
			 * signal so we do not panic the test harness. */
			continue;
		}
		sp = (unsigned int)r[13] - 8U;
		*(volatile unsigned int *)sp       = (unsigned int)r[15];
		*(volatile unsigned int *)(sp + 4) = (unsigned int)r[0];
		r[13] = (int)sp;
		r[14] = (int)UENTRY_SIGTRAMP;
		r[15] = (int)h;
		r[0]  = sig;
		return;
	}
}

void
trap(int *r)
{
	int n, ret;

	n = r[7];
	ret = -1;
		if(n == S_EXIT) {
			if(childmode) {
				int pid, ppid, s, code;

				code = r[0];
				childmode--;
				pid = curpid;
				ppid = pidsave[childmode];
				kflush();
				bcopy((char *)fusave[childmode], (char *)USERBASE, USERSIZE);
				bcopy((char *)cframe[childmode], (char *)r,
				    sizeof(cframe[childmode]));
				bcopy((char *)ffsave[childmode], (char *)files,
				    sizeof(ffsave[childmode]));
				bcopy((char *)cfsave[childmode], (char *)closed,
				    sizeof(cfsave[childmode]));
				cwdino = cfwsave[childmode];
				/* Restore the parent's handler set + any
				 * signals queued against it during the
				 * child's run, then let deliver_signal()
				 * fold those into the resume frame. */
				for(s = 0; s <= NSIG; s++)
					handlers[s] = hsave[childmode][s];
				pending = psave[childmode];
				kuid = kuidsave[childmode];
				curpid = ppid;
				r[0] = pid;
				kdone(pid, ppid, code);
				deliver_signal(r);
				return;
			}
			if(spawned) {
				kflush();
			bcopy((char *)usave, (char *)USERBASE, USERSIZE);
			bcopy((char *)sframe, (char *)r, sizeof(sframe));
			bcopy((char *)fsave, (char *)files, sizeof(files));
			bcopy((char *)csave, (char *)closed, sizeof(closed));
			cwdino = cwdsave;
			r[0] = 0;
			spawned = 0;
			return;
		}
		for(;;)
			;
		}
		else if(n == S_FORK) {
			if(childmode >= NFORK || spawned) {
				ret = -1;
			} else {
				int s;
				bcopy((char *)USERBASE, (char *)fusave[childmode],
				    USERSIZE);
				bcopy((char *)r, (char *)cframe[childmode],
				    sizeof(cframe[childmode]));
				bcopy((char *)files, (char *)ffsave[childmode],
				    sizeof(ffsave[childmode]));
				bcopy((char *)closed, (char *)cfsave[childmode],
				    sizeof(cfsave[childmode]));
				cfwsave[childmode] = cwdino;
				/* V7 fork inherits handlers but the parent
				 * keeps the originals: save them away under
				 * the child's depth and let the parent's
				 * pending-signal mask resume with it. */
				for(s = 0; s <= NSIG; s++)
					hsave[childmode][s] = handlers[s];
				psave[childmode] = pending;
				pending = 0;
				kuidsave[childmode] = kuid;
				childpid[childmode] = nextpid++;
				pidsave[childmode] = curpid;
				curpid = childpid[childmode];
				childmode++;
				r[0] = 0;
				return;
		}
		}
		else if(n == S_WAIT) {
			ret = kwait(curpid, (int *)r[0]);
		}
	else if(n == S_READ)
		ret = kread(r[0], (char *)r[1], (unsigned int)r[2]);
	else if(n == S_WRITE) {
		char *p;
		int i;

			if(r[0] >= 0 && r[0] < NFD && files[r[0]].pipe != 0) {
				struct pipe *pp;

				pp = &pipes[files[r[0]].pipe-1];
				if(pp->wpos + (unsigned int)r[2] > PIPESIZ)
				r[2] = PIPESIZ - pp->wpos;
			bcopy((char *)r[1], pp->buf + pp->wpos, r[2]);
			pp->wpos += r[2];
			ret = r[2];
			goto out;
		}
		if(r[0] >= 0 && r[0] < NFD && files[r[0]].mem != 0) {
			if(files[r[0]].off + (unsigned int)r[2] > sizeof(tmpbuf))
				r[2] = sizeof(tmpbuf) - files[r[0]].off;
			bcopy((char *)r[1], files[r[0]].mem + files[r[0]].off, r[2]);
			files[r[0]].off += r[2];
			if(files[r[0]].off > tmpused)
				tmpused = files[r[0]].off;
			ret = r[2];
			goto out;
		}
		if(r[0] >= 0 && r[0] < NFD &&
		    files[r[0]].ino != 0 && (files[r[0]].mode & IFMT) == IFREG) {
			ret = writei(&files[r[0]], files[r[0]].off, (char *)r[1], r[2]);
			if(ret > 0)
				files[r[0]].off += ret;
			goto out;
		}
		p = (char *)r[1];
		for(i=0; i<r[2]; i++)
			putchar(p[i]);
		ret = r[2];
	} else if(n == S_OPEN)
		ret = kopen((char *)r[0]);
	else if(n == S_CREAT)
		ret = kcreat((char *)r[0], r[1]);
	else if(n == S_LINK)
		ret = klink((char *)r[0], (char *)r[1]);
	else if(n == S_UNLINK)
		ret = kunlink((char *)r[0]);
	else if(n == S_MKNOD)
		ret = kmknod((char *)r[0], r[1], r[2]);
	else if(n == S_CHMOD)
		ret = kchmod((char *)r[0], r[1]);
	else if(n == S_CHOWN)
		ret = 0;
		else if(n == S_CLOSE)
			ret = kclose(r[0]);
	else if(n == S_DUP)
		ret = kdup(r[0], r[1]);
	else if(n == S_PIPE)
		ret = kpipe((int *)r[0]);
	else if(n == S_CHDIR)
		ret = kchdir((char *)r[0]);
	else if(n == S_STAT)
		ret = kstat((char *)r[0], (struct ustat *)r[1]);
	else if(n == S_ACCESS) {
		/* /dev/console is the kernel-resident UART pseudo-inode (see
		 * kopen), not a real on-disk entry; init.c::rline() probes
		 * it with access(tty, 06) before forking getty, so accept
		 * it here even though v7_namei_inum cannot find it. */
		if(strcmp((char *)r[0], "/dev/console") == 0)
			ret = 0;
		else
			ret = v7_namei_inum((char *)r[0]) == 0 ? -1 : 0;
	}
	else if(n == S_UTIME)
		ret = v7_namei_inum((char *)r[0]) == 0 ? -1 : 0;
	else if(n == S_LSEEK)
		ret = kseek(r[0], r[1], r[2]);
	else if(n == S_FSTAT)
		ret = kfstat(r[0], (struct ustat *)r[1]);
	else if(n == S_SYNC)
		ret = 0;
	else if(n == S_GETDENTS)
		ret = kgetdents(r[0], (char *)r[1], (unsigned int)r[2]);
		else if(n == S_EXEC) {
			ret = kexec2((char *)r[0], (char **)r[1]);
		if(ret == 0) {
			r[13] = USTACK;
			r[14] = 0;
			r[15] = UENTRY;
		}
	} else if(n == S_SPAWN)
		ret = kspawn((char *)r[0], (char *)r[1], r);
	else if(n == S_MOUNT)
		ret = 0;	/* tmpfs-backed -- nothing to do here */
	else if(n == S_UMOUNT)
		ret = 0;
	else if(n == S_UMASK) {
		ret = kumask;
		kumask = r[0] & 07777;
	}
	else if(n == S_GETUID)
		ret = kuid;
	else if(n == S_SETUID) {
		kuid = r[0];
		ret = 0;
	}
	else if(n == S_KILL)
		ret = kkill(r[0], r[1]);
	else if(n == S_SIGNAL) {
		long old;
		old = ksignal(r[0], (long)(unsigned int)r[1]);
		r[0] = (int)(unsigned int)old;
		deliver_signal(r);
		return;
	}
	else if(n == S_SIGRETURN) {
		ksigreturn(r);
		deliver_signal(r);
		return;
	}
out:
	r[0] = ret;
	deliver_signal(r);
}

void
panictrap(void)
{

	panic("trap");
}

void
armboot(void)
{

	files[0].ino = 1;
	files[0].mode = IFCHR;
	files[1].ino = 1;
	files[1].mode = IFCHR;
	files[2].ino = 1;
	files[2].mode = IFCHR;
	shim_bread(SUPERB, blkbuf);
#ifdef EVB
	/* Sentinel: prove the DDR-backed bio() path returned a real V7
	 * superblock before we touch anything that might panic.  The
	 * on-disk superblock layout (matched by tools/mkfs) packs
	 * s_isize as a u16 at offset 0 and s_fsize as a u32 at offset 2,
	 * with no padding between them.  The host C struct gets 2 bytes
	 * of alignment padding, so reading s_fsize through the struct
	 * yields garbage; decode the raw bytes directly here. */
	{
		unsigned int isize, fsize;
		isize = (unsigned int)blkbuf[0]
		      | ((unsigned int)blkbuf[1] << 8);
		fsize = (unsigned int)blkbuf[2]
		      | ((unsigned int)blkbuf[3] << 8)
		      | ((unsigned int)blkbuf[4] << 16)
		      | ((unsigned int)blkbuf[5] << 24);
		printf("evb: rootfs isize=%d fsize=%d\n",
		    (int)isize, (int)fsize);
	}
#endif
	if(((struct filsys *)blkbuf)->s_isize == 0)
		panic("fs");
	scanfs();
#ifdef EVB
	/* Sentinel: prove namei() can walk the V7 directory tree off the
	 * DDR-backed bio() path and resolve /etc/init to a real inum.  A
	 * zero return would mean the directory walk failed (broken
	 * directory-block reads or wrong rootfs); a positive integer
	 * means /'s data blocks read OK, the `etc` entry was found, the
	 * descent worked, and `init` was found.  Printed before kexec()
	 * so a failure inside the a.out loader shows up as the *next*
	 * missing line, not as silence after this sentinel. */
	{
		ino_t initino = v7_namei_inum("/etc/init");
		printf("evb: init inum=%d\n", (int)initino);
	}
#endif
#ifdef EVB
	{
		int rc = kexec("/etc/init");
		if (rc < 0) {
			printf("evb: kexec fail rc=%d\n", rc);
			panic("init");
		}
		printf("evb: kexec ok\n");
	}
#else
	if(kexec("/etc/init") < 0)
		panic("init");
#endif
	run_user(UENTRY, USTACK);
}
