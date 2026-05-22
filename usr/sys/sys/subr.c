#include "../h/param.h"
#include "../h/systm.h"
#include "../h/inode.h"
#include "../h/dir.h"
#include "../h/user.h"
#include "../h/buf.h"
struct map;
struct buf;
extern int malloc(struct map *mp, int size);
extern void mfree(struct map *mp, int size, int a);
extern void printf(char *fmt, ...);
extern void panic(char *s);
extern void prdev(char *str, dev_t dev);
extern void putchar(char c);
extern int getchar(void);
extern void trap(int *frame);
extern void panictrap(void);
extern void run_user(unsigned int pc, unsigned int sp);
extern void mmu_on(unsigned int ttb);
extern void dmbsy(void);
extern void mmuinit(void);
extern void startup(void);
extern void armboot(void);
extern void armboot_setrun(int pid);
extern void armboot_swtch(void);
extern int save(int *lp);
extern void resume(int addr, int *lp);
extern struct buf *bread(dev_t dev, daddr_t blkno);
extern struct buf *breada(dev_t dev, daddr_t blkno, daddr_t rablkno);
extern void bwrite(struct buf *bp);
extern void bdwrite(struct buf *bp);
extern void brelse(struct buf *bp);
extern int incore(dev_t dev, daddr_t blkno);
extern struct buf *getblk(dev_t dev, daddr_t blkno);
extern struct buf *geteblk(void);
extern void iowait(struct buf *bp);
extern void notavail(struct buf *bp);
extern void iodone(struct buf *bp);
extern void clrbuf(struct buf *bp);
extern void swap(daddr_t blkno, int coreaddr, int count, int rdflg);
extern void bflush(dev_t dev);
extern void geterror(struct buf *bp);
extern void wakeup(caddr_t chan);
extern void sleep(caddr_t chan, int pri);
extern int spl0(void);
extern int spl1(void);
extern int spl6(void);
extern int spl7(void);
extern void splx(int s);
extern void binit(void);
extern void copyseg(int from, int to);
extern void clearseg(int a);
extern dev_t rootdev;
extern int virtio_strategy(struct buf *bp);
extern void virtio_init(void);

/* bread/bdwrite/brelse come from local declarations.
 * alloc/subyte/fubyte come from h/systm.h. */

/*
 * Bmap defines the structure of file system storage
 * by returning the physical block number on a device given the
 * inode and the logical block number in a file.
 * When convenient, it also leaves the physical
 * block number of the next block of the file in rablock
 * for use in read-ahead.
 */
daddr_t
bmap(register struct inode *ip, daddr_t bn, int rwflg)
{
	register int i;
	struct buf *bp, *nbp;
	int j, sh;
	daddr_t nb, *bap;
	dev_t dev;

	if(bn < 0) {
		u.u_error = EFBIG;
		return((daddr_t)0);
	}
	dev = ip->i_dev;
	rablock = 0;

	/*
	 * blocks 0..NADDR-4 are direct blocks
	 */
	if(bn < NADDR-3) {
		i = bn;
		nb = ip->i_un.i_addr[i];
		if(nb == 0) {
			if(rwflg==B_READ || (bp = alloc(dev))==NULL)
				return((daddr_t)-1);
			nb = bp->b_blkno;
			bdwrite(bp);
			ip->i_un.i_addr[i] = nb;
			ip->i_flag |= IUPD|ICHG;
		}
		if(i < NADDR-4)
			rablock = ip->i_un.i_addr[i+1];
		return(nb);
	}

	/*
	 * addresses NADDR-3, NADDR-2, and NADDR-1
	 * have single, double, triple indirect blocks.
	 * the first step is to determine
	 * how many levels of indirection.
	 */
	sh = 0;
	nb = 1;
	bn -= NADDR-3;
	for(j=3; j>0; j--) {
		sh += NSHIFT;
		nb <<= NSHIFT;
		if(bn < nb)
			break;
		bn -= nb;
	}
	if(j == 0) {
		u.u_error = EFBIG;
		return((daddr_t)0);
	}

	/*
	 * fetch the address from the inode
	 */
	nb = ip->i_un.i_addr[NADDR-j];
	if(nb == 0) {
		if(rwflg==B_READ || (bp = alloc(dev))==NULL)
			return((daddr_t)-1);
		nb = bp->b_blkno;
		bdwrite(bp);
		ip->i_un.i_addr[NADDR-j] = nb;
		ip->i_flag |= IUPD|ICHG;
	}

	/*
	 * fetch through the indirect blocks
	 */
	for(; j<=3; j++) {
		bp = bread(dev, nb);
		if(bp->b_flags & B_ERROR) {
			brelse(bp);
			return((daddr_t)0);
		}
		bap = bp->b_un.b_daddr;
		sh -= NSHIFT;
		i = (bn>>sh) & NMASK;
		nb = bap[i];
		if(nb == 0) {
			if(rwflg==B_READ || (nbp = alloc(dev))==NULL) {
				brelse(bp);
				return((daddr_t)-1);
			}
			nb = nbp->b_blkno;
			bdwrite(nbp);
			bap[i] = nb;
			bdwrite(bp);
		} else
			brelse(bp);
	}

	/*
	 * calculate read-ahead.
	 */
	if((unsigned)i < NINDIR-1)
		rablock = bap[i+1];
	return(nb);
}

/*
 * Pass back  c  to the user at his location u_base;
 * update u_base, u_count, and u_offset.  Return -1
 * on the last character of the user's read.
 * u_base is in the user address space unless u_segflg is set.
 */
int
passc(register int c)
{
	/* v7 had a u_segflg==2 (user I-space) branch dispatching to
	 * suibyte; this port never sets u_segflg to 2. */
	if(u.u_segflg == 1)
		*u.u_base = c;
	else if(subyte(u.u_base, c) < 0) {
		u.u_error = EFAULT;
		return(-1);
	}
	u.u_count--;
	u.u_offset++;
	u.u_base++;
	return(u.u_count == 0? -1: 0);
}

/*
 * Pick up and return the next character from the user's
 * write call at location u_base;
 * update u_base, u_count, and u_offset.  Return -1
 * when u_count is exhausted.  u_base is in the user's
 * address space unless u_segflg is set.
 */
int
cpass(void)
{
	register int c;

	if(u.u_count == 0)
		return(-1);
	if(u.u_segflg == 1)
		c = *u.u_base;
	else if((c = fubyte(u.u_base)) < 0) {
		u.u_error = EFAULT;
		return(-1);
	}
	u.u_count--;
	u.u_offset++;
	u.u_base++;
	return(c&0377);
}

/* v7 bcopy lives in sys/arch/arm.c -- byte-loop tuned for AAPCS softfloat
 * rather than the PDP-11 mov2/movb instruction layout the original
 * carried over from v7/usr/sys/sys/subr.c. */
