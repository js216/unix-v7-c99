#include "../h/param.h"
#include "../h/systm.h"
#include "../h/dir.h"
#include "../h/user.h"
#include "../h/proc.h"
#include "../h/text.h"
#include "../h/inode.h"
#include "../h/buf.h"
#include "../h/seg.h"
#include "../h/map.h"
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

/* malloc/mfree/panic/wakeup/sleep come from local declarations.
 * iput comes from h/systm.h. */
extern void xlock(struct text *);
extern void xunlock(struct text *);
extern void xccdec(struct text *);
extern void xuntext(struct text *);

void xswap(register struct proc *p, int ff, int os);

/*
 * Swap out process p.
 * The ff flag causes its core to be freed--
 * it may be off when called to create an image for a
 * child process in newproc.
 * Os is the old size of the data area of the process,
 * and is supplied during core expansion swaps.
 *
 * panic: out of swap space
 */
void
xswap(register struct proc *p, int ff, int os)
{
	register int a;

	if(os == 0)
		os = p->p_size;
	a = malloc(swapmap, ctod(p->p_size));
	if(a == NULL)
		panic("out of swap space");
	xccdec(p->p_textp);
	swap(a, p->p_addr, os, B_WRITE);
	if(ff)
		mfree(coremap, os, p->p_addr);
	p->p_addr = a;
	p->p_flag &= ~SLOAD;
	p->p_time = 0;
	if(runout) {
		runout = 0;
		wakeup((caddr_t)&runout);
	}
}

/* v7 xfree() (drop process's text reference, free swap+core if last
 * holder), xalloc() (attach to shared text, swap-in if needed) and
 * xexpand() (allocate core for text, swap-out current proc if no core)
 * are gone -- their only callers were sys1.c::exit/getxfile, both of
 * which are also gone.  The remaining text-table operations (xswap,
 * xccdec, xumount, xrele, xuntext) stay because they're still reached
 * via slp.c::expand and umount(2)/closef(). */

/*
 * Lock and unlock a text segment from swapping
 */
void
xlock(register struct text *xp)
{

	while(xp->x_flag&XLOCK) {
		xp->x_flag |= XWANT;
		sleep((caddr_t)xp, PSWP);
	}
	xp->x_flag |= XLOCK;
}

void
xunlock(register struct text *xp)
{

	if (xp->x_flag&XWANT)
		wakeup((caddr_t)xp);
	xp->x_flag &= ~(XLOCK|XWANT);
}

/*
 * Decrement the in-core usage count of a shared text segment.
 * When it drops to zero, free the core space.
 */
void
xccdec(register struct text *xp)
{

	if (xp==NULL || xp->x_ccount==0)
		return;
	xlock(xp);
	if (--xp->x_ccount==0) {
		if (xp->x_flag&XWRIT) {
			xp->x_flag &= ~XWRIT;
			swap(xp->x_daddr,xp->x_caddr,xp->x_size,B_WRITE);
		}
		mfree(coremap, xp->x_size, xp->x_caddr);
	}
	xunlock(xp);
}

/*
 * free the swap image of all unused saved-text text segments
 * which are from device dev (used by umount system call).
 */
void
xumount(register dev_t dev)
{
	register struct text *xp;

	for (xp = &text[0]; xp < &text[NTEXT]; xp++)
		if (xp->x_iptr!=NULL && dev==xp->x_iptr->i_dev)
			xuntext(xp);
}

/*
 * remove a shared text segment from the text table, if possible.
 */
void
xrele(register struct inode *ip)
{
	register struct text *xp;

	if ((ip->i_flag&ITEXT)==0)
		return;
	for (xp = &text[0]; xp < &text[NTEXT]; xp++)
		if (ip==xp->x_iptr)
			xuntext(xp);
}

/*
 * remove text image from the text table.
 * the use count must be zero.
 */
void
xuntext(register struct text *xp)
{
	register struct inode *ip;

	xlock(xp);
	if (xp->x_count) {
		xunlock(xp);
		return;
	}
	ip = xp->x_iptr;
	xp->x_flag &= ~XLOCK;
	xp->x_iptr = NULL;
	mfree(swapmap, ctod(xp->x_size), xp->x_daddr);
	ip->i_flag &= ~ITEXT;
	if (ip->i_flag&ILOCK)
		ip->i_count--;
	else
		iput(ip);
}
