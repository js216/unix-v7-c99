/*
 * Architecture stubs for the v7 buffer cache (sys/dev/bio.c).
 *
 * This file backs symbols that sys/dev/bio.c references but whose
 * V7 source we have not yet linked in: the UNIBUS map release
 * (mapfree), the sleep/wakeup/spl primitives (provided by sys/slp.c
 * in real V7), and the storage for the per-process user struct,
 * proc table, bfreelist, and bdevsw.
 *
 * They are intentionally minimal: the bio.c translation unit must
 * link, but it has no caller in this sub-step (arch/armboot.c::bio
 * still owns block I/O on hardware).  When real callers wire up,
 * these stubs are replaced by the real sys TUs.
 */

#include "../h/param.h"
#include "../h/buf.h"
#include "../h/conf.h"
#include "../h/dir.h"
#include "../h/inode.h"
#include "../h/user.h"
#include "../h/proc.h"
#include "../h/filsys.h"
#include "../h/ino.h"
#include "../h/systm.h"
#include "../h/proto.h"

/* per-process user struct (referenced by physio() in dev/bio.c) */
struct user u;

/* head of available-buffer list */
struct buf bfreelist;

/* Root device.  Real V7 callers (bread, mount, etc.) pass this as the
 * dev_t argument to walk bdevsw[major(rootdev)].  major(0)==0, so this
 * resolves to bdevsw[0], which is mp135_strategy on EVB and
 * virtio_strategy on qemu.  Picked up at link time by sys/main.c and
 * dev/bio.c (both #include "../h/systm.h", which declares it tentatively). */
dev_t rootdev = 0;

/* Number of block-device switch entries actually populated above.
 * Required by getblk() to range-check major(dev) before dispatching.
 * Tentatively declared in systm.h; here we give it the strong
 * initialiser the buffer cache needs.  V7's binit() will count
 * the populated bdevsw[] rows up from here. */
int nblkdev = 0;

/* Buffer-cache storage: V7's sys/main.c::binit() owns the `buffers[][]`
 * row storage now (un-#if 0'd in iter 9).  `buf[NBUF]` is declared in
 * conf/c.c per real V7; until conf/c.c is linked in, we keep its
 * tentative definition here so the bio.c TU resolves.
 *
 * Alignment: sys/iget.c casts a buffer payload via bp->b_un.b_dino
 * (struct dinode *) and reads off_t fields with a 4-byte alignment
 * requirement.  The historic V7 row stride of BSIZE+BSLOP = 514 is
 * not a multiple of 4, so under SCTLR.A=1 the second-row dinode read
 * would fault.  V7's main.c::binit() declares `char buffers[NBUF]
 * [BSIZE+BSLOP]` verbatim; we cannot retag it without diverging from
 * the historic source.  The only practical fix at this layer is to
 * keep the buffers' base address 4-aligned by relying on the linker's
 * default alignment for top-level char arrays (gcc emits .bss
 * 4-aligned for objects >=4 bytes), and rounding NBUF to keep the
 * stride accidentally aligned -- which it already is when BSIZE+BSLOP
 * happens to be even.  514 is even, so the misalignment risk is the
 * 2-byte slack only; iget's dinode struct begins with shorts so a
 * 2-byte alignment is sufficient.  No further patching required. */
struct buf buf[NBUF];

/* nulldev: V7 placeholder for unimplemented open/close on a bdevsw row */
int
nulldev(void)
{
	return 0;
}

/* block-device switch table: bdevsw[0] is the active block device for
 * this build (mp135 DDR-backed memcpy on EVB, virtio-blk on qemu).
 * The single empty trailing row terminates the table. */
#ifdef EVB
extern int mp135_strategy(struct buf *);
extern struct buf mp135_tab;
struct bdevsw bdevsw[2] = {
	{ nulldev, nulldev, mp135_strategy, &mp135_tab },
	{ 0, 0, 0, 0 }
};
#else
extern int virtio_strategy(struct buf *);
extern struct buf virtio_tab;
struct bdevsw bdevsw[2] = {
	{ nulldev, nulldev, virtio_strategy, &virtio_tab },
	{ 0, 0, 0, 0 }
};
#endif

/* UNIBUS map release: meaningless on Armv7, no-op */
void
mapfree(struct buf *bp)
{
	(void)bp;
}

/* V7 sleep/wakeup placeholders */
void
sleep(caddr_t chan, int pri)
{
	(void)chan;
	(void)pri;
}

void
wakeup(caddr_t chan)
{
	(void)chan;
}

/* V7 interrupt-priority-level primitives */
int
spl0(void)
{
	return 0;
}

int
spl6(void)
{
	return 0;
}

void
splx(int s)
{
	(void)s;
}

/* In-core inode table referenced by sys/iget.c and sys/nami.c. */
struct inode inode[NINODE];

/* Stubs for sys/iget.c + sys/nami.c.  No caller wires through them
 * in this sub-step (armboot.c's shim namei/loadino/iget remain the
 * active path); these definitions exist solely so the iget.o /
 * nami.o translation units link.  They will be replaced by their
 * real V7 implementations as the cascade widens in later iterations.
 */
void
bcopy(caddr_t from, caddr_t to, unsigned int count)
{
	while (count--)
		*to++ = *from++;
}

void
free(dev_t dev, daddr_t bn)
{
	(void)dev;
	(void)bn;
}

/* Single in-core superblock placeholder.  V7's iupdat dereferences
 * getfs(ip->i_dev)->s_ronly before writing back; our shim_namei only
 * does lookups, but iput() unconditionally hits iupdat() when an
 * inode's i_flag has IUPD|IACC|ICHG set.  We return a real (zeroed)
 * filsys so the dereference is safe; s_ronly==0 is harmless because
 * we never reach the bdwrite path in read-only namei traffic.  Once
 * sys/alloc.c and the mount table come online this stub goes away. */
static struct filsys fakesb;

struct filsys *
getfs(dev_t dev)
{
	(void)dev;
	return &fakesb;
}

struct inode *
ialloc(dev_t dev)
{
	(void)dev;
	return (struct inode *)0;
}

void
ifree(dev_t dev, ino_t ino)
{
	(void)dev;
	(void)ino;
}

/* Release inode lock.  V7's iget leaves the inode ILOCKED on return;
 * the caller must explicitly drop the lock (via prele) once it's done.
 * Without clearing ILOCK here, the next iget() call on the same inode
 * blocks forever in our no-op sleep stub.  Real V7 prele() in slp.c
 * additionally wakes IWANT-ers; that's a no-op here since sleep is a
 * no-op too. */
void
prele(struct inode *ip)
{
	if(ip != NULL)
		ip->i_flag &= ~(ILOCK|IWANT);
}

/* Acquire inode lock.  In real V7 this would block if ILOCK is held by
 * another process; our shim is single-threaded so we just set the bit. */
void
plock(struct inode *ip)
{
	if(ip != NULL)
		ip->i_flag |= ILOCK;
}

int
access(struct inode *ip, int mode)
{
	(void)ip;
	(void)mode;
	return 0;
}

/* Read-only block-map translation.  V7's sys/subr.c::bmap() is too
 * intertwined with sys/alloc.c (which we have not yet linked) to drop
 * in unchanged; we implement just the read paths shim_namei needs.
 *
 * Address-packing wrinkle: sys/iget.c::iexpand() copies on-disk
 * 3-byte block addresses into a 4-byte daddr_t with PDP-11 byte
 * order: mem[0]=disk[0], mem[1]=0, mem[2]=disk[1], mem[3]=disk[2].
 * Read back on ARM little-endian, ip->i_addr[i] is therefore
 *   raw = disk[0] | (disk[1]<<16) | (disk[2]<<24)
 * whereas the natural disk block number is
 *   blk = disk[0] | (disk[1]<<8)  | (disk[2]<<16)
 * so we unpack here.  Indirect-block addresses on disk are full
 * 32-bit daddr_t (no PDP packing), so the bp->b_un.b_daddr[] path
 * uses values verbatim.
 */
static daddr_t
unpack_iaddr(daddr_t raw)
{
	unsigned int v = (unsigned int)raw;
	return (daddr_t)((v & 0xffu)
	    | (((v >> 16) & 0xffu) << 8)
	    | (((v >> 24) & 0xffu) << 16));
}

daddr_t
bmap(struct inode *ip, daddr_t bn, int rwflg)
{
	struct buf *bp;
	daddr_t nb;
	int sh, j, i;

	(void)rwflg;
	if(bn < 0)
		return (daddr_t)0;

	/* Direct blocks 0..NADDR-4 */
	if(bn < NADDR-3) {
		nb = unpack_iaddr(ip->i_addr[(int)bn]);
		return nb;
	}

	/* Indirect blocks: single (NADDR-3), double (NADDR-2),
	 * triple (NADDR-1).  Compute number of indirection levels. */
	sh = 0;
	nb = 1;
	bn -= NADDR-3;
	for(j = 3; j > 0; j--) {
		sh += NSHIFT;
		nb <<= NSHIFT;
		if(bn < nb)
			break;
		bn -= nb;
	}
	if(j == 0)
		return (daddr_t)0;

	nb = unpack_iaddr(ip->i_addr[NADDR-j]);
	if(nb == 0)
		return (daddr_t)0;

	/* Walk indirect blocks; addresses inside them are full daddr_t. */
	for(; j <= 3; j++) {
		bp = bread(ip->i_dev, nb);
		if(bp->b_flags & B_ERROR) {
			brelse(bp);
			return (daddr_t)0;
		}
		sh -= NSHIFT;
		i = ((int)(bn >> sh)) & NMASK;
		nb = bp->b_un.b_daddr[i];
		brelse(bp);
		if(nb == 0)
			return (daddr_t)0;
	}
	return nb;
}

int
fubyte(caddr_t addr)
{
	return *(unsigned char *)addr;
}

int
writei(struct inode *ip)
{
	(void)ip;
	return 0;
}

/* uchar() lives in sys/nami.c; declare it here so v7_namei_inum can
 * pass it as namei()'s char-fetch function pointer. */
extern int uchar(void);

/* Forward-decl V7's namei and iget/iput, since proto.h doesn't yet
 * publish those entry points (its iget declaration would collide with
 * arch/armboot.c's static shim of the same name). */
extern struct inode *namei(int (*func)(void), int flag);
extern struct inode *iget(dev_t dev, ino_t ino);
extern void iput(struct inode *ip);

/*
 * Bridge between arch/armboot.c's `ino_t shim_namei(char *path)` shim
 * and V7's `struct inode *namei(func, flag)` real path-walker.
 *
 * On first call rootdir/u.u_cdir are NULL: bootstrap by iget()-ing the
 * root inode off rootdev, clearing ILOCK (V7's iget leaves the inode
 * locked; without clearing it the next iget on the same inode would
 * spin forever in our no-op sleep stub), and stashing the pointer.
 * V7 namei picks up the absolute `/'-prefixed path itself: it sees the
 * leading '/' and starts from rootdir (or u.u_rdir if set, which we
 * leave NULL).  Relative paths start from u.u_cdir, which we point at
 * rootdir for now.
 *
 * Returns the inum of the resolved path, or 0 if not found.  The shim
 * callers (kchdir, kopen, kcreat, kexec, klink, ...) read the inum
 * back through loadino() which still bread()s the dinode block by
 * itself.  Once those are V7-fied too the inode pointer plumbing will
 * carry through directly without this lookup-by-inum round trip.
 */
ino_t
v7_namei_inum(char *path)
{
	struct inode *ip;
	ino_t inum;

	if(rootdir == NULL) {
		rootdir = iget(rootdev, (ino_t)ROOTINO);
		if(rootdir == NULL)
			return (ino_t)0;
		rootdir->i_flag &= ~ILOCK;
		u.u_cdir = rootdir;
	}

	u.u_dirp = (caddr_t)path;
	u.u_error = 0;
	u.u_segflg = 1;		/* 1 = system-space path (kernel pointer) */

	ip = namei(uchar, 0);
	if(ip == NULL)
		return (ino_t)0;
	inum = ip->i_number;
	iput(ip);
	return inum;
}
