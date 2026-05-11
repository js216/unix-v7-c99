#if 0
#include "../h/param.h"
#include "../h/systm.h"
#include "../h/acct.h"
#include "../h/dir.h"
#include "../h/user.h"
#include "../h/inode.h"
#include "../h/proc.h"
#include "../h/seg.h"
#include "../h/map.h"
#include "../h/reg.h"
#endif
#include "../h/param.h"
#include "../h/buf.h"
#include "../h/proto.h"

/*
 * Icode is the octal bootstrap
 * program executed in user mode
 * to bring up the system.
 */
int	icode[] =
{
	0104413,	/* sys exec; init; initp */
	0000014,
	0000010,
	0000777,	/* br . */
	0000014,	/* initp: init; 0 */
	0000000,
	0062457,	/* init: </etc/init\0> */
	0061564,
	0064457,
	0064556,
	0000164,
};
int	szicode = sizeof(icode);

/*
 * Machine-dependent startup code
 */
void
startup(void)
{
	/* Qemu virt cortex-a7 default RAM is 128 MiB at 0x40000000. The
	 * V7 banner shape is preserved so userspace tooling that scrapes
	 * "mem = " from the console keeps working; on Armv7 we report
	 * bytes directly rather than PDP-11 click-converted sizes. */
	printf("mem = %D\n", (long)(128L * 1024 * 1024));

	/*
	 * First real V7-style caller of bread().  Walks
	 *   bread -> getblk -> bdevsw[major(rootdev)].d_strategy
	 *         -> iowait -> iodone
	 * end-to-end and prints the V7 superblock geometry as a
	 * sentinel.  Proves the buffer cache linked in the prior
	 * iteration and the strategy routine wired in iter 2 actually
	 * return real bytes from the DDR-staged (EVB) / virtio (qemu)
	 * rootfs.  arch/armboot.c::bio() and its shim_bread callers are
	 * unaffected and remain the active block-I/O path elsewhere.
	 */
	{
		struct buf *bp;
		unsigned char *raw;
		unsigned int isize, fsize;

		binit_stub();
		bp = bread((dev_t)rootdev, (daddr_t)SUPERB);
		/*
		 * The on-disk V7 superblock packs s_isize as a u16 at
		 * offset 0 and s_fsize as a u32 at offset 2 (tools/mkfs
		 * writes this layout, and arch/armboot.c's sentinel
		 * decodes it identically).  The host C struct in
		 * h/filsys.h aligns s_fsize on a 4-byte boundary, so
		 * reading sb->s_fsize through the struct yields garbage
		 * (offset 4, not 2).  Decode the raw bytes directly here
		 * to verify the bread() data path end-to-end.
		 */
		raw = (unsigned char *)bp->b_un.b_addr;
		isize = (unsigned int)raw[0] | ((unsigned int)raw[1] << 8);
		fsize = (unsigned int)raw[2] | ((unsigned int)raw[3] << 8)
		      | ((unsigned int)raw[4] << 16)
		      | ((unsigned int)raw[5] << 24);
		printf("v7: sb isize=%d fsize=%d\n", (int)isize, (int)fsize);
		brelse(bp);
	}
#if 0
	register i;

	/*
	 * zero and free all of core
	 */

	i = ka6->r[0] + USIZE;
	UISD->r[0] = 077406;
	for(;;) {
		UISA->r[0] = i;
		if(fuibyte((caddr_t)0) < 0)
			break;
		clearseg(i);
		maxmem++;
		mfree(coremap, 1, i);
		i++;
	}
	if(cputype == 70)
	for(i=0; i<62; i+=2) {
		UBMAP->r[i] = i<<12;
		UBMAP->r[i+1] = 0;
	}
	printf("mem = %D\n", ctob((long)maxmem));
	if(MAXMEM < maxmem)
		maxmem = MAXMEM;
	mfree(swapmap, nswap, 1);
	swplo--;

	/*
	 * determine clock
	 */

	UISA->r[7] = ka6->r[1]; /* io segment */
	UISD->r[7] = 077406;
#endif
}

#if 0
/*
 * set up a physical address
 * into users virtual address space.
 */
sysphys()
{
	register i, s, d;
	register struct a {
		int	segno;
		int	size;
		int	phys;
	} *uap;

	if(!suser())
		return;
	uap = (struct a *)u.u_ap;
	i = uap->segno;
	if(i < 0 || i >= 8)
		goto bad;
	s = uap->size;
	if(s < 0 || s > 128)
		goto bad;
	d = u.u_uisd[i+8];
	if(d != 0 && (d&ABS) == 0)
		goto bad;
	u.u_uisd[i+8] = 0;
	u.u_uisa[i+8] = 0;
	if(!u.u_sep) {
		u.u_uisd[i] = 0;
		u.u_uisa[i] = 0;
	}
	if(s) {
		u.u_uisd[i+8] = ((s-1)<<8) | RW|ABS;
		u.u_uisa[i+8] = uap->phys;
		if(!u.u_sep) {
			u.u_uisa[i] = u.u_uisa[i+8];
			u.u_uisd[i] = u.u_uisd[i+8];
		}
	}
	sureg();
	return;

bad:
	u.u_error = EINVAL;
}

/*
 * Determine which clock is attached, and start it.
 * panic: no clock found
 */
#define	CLOCK1	((physadr)0177546)
#define	CLOCK2	((physadr)0172540)
clkstart()
{
	lks = CLOCK1;
	if(fuiword((caddr_t)lks) == -1) {
		lks = CLOCK2;
		if(fuiword((caddr_t)lks) == -1)
			panic("no clock");
	}
	lks->r[0] = 0115;
}

/*
 * Let a process handle a signal by simulating an interrupt
 */
sendsig(p, signo)
caddr_t p;
{
	register unsigned n;

	n = u.u_ar0[R6] - 4;
	grow(n);
	suword((caddr_t)n+2, u.u_ar0[RPS]);
	suword((caddr_t)n, u.u_ar0[R7]);
	u.u_ar0[R6] = n;
	u.u_ar0[RPS] &= ~TBIT;
	u.u_ar0[R7] = (int)p;
}

/*
 * 11/70 routine to allocate the
 * UNIBUS map and initialize for
 * a unibus device.
 * The code here and in
 * rhstart assumes that an rh on an 11/70
 * is an rh70 and contains 22 bit addressing.
 */
int	maplock;

mapalloc(bp)
register struct buf *bp;
{
	register i, a;

	if(cputype != 70)
		return;
	spl6();
	while(maplock&B_BUSY) {
		maplock |= B_WANTED;
		sleep((caddr_t)&maplock, PSWP+1);
	}
	maplock |= B_BUSY;
	spl0();
	bp->b_flags |= B_MAP;
	a = bp->b_xmem;
	for(i=16; i<32; i+=2)
		UBMAP->r[i+1] = a;
	for(a++; i<48; i+=2)
		UBMAP->r[i+1] = a;
	bp->b_xmem = 1;
}

mapfree(bp)
struct buf *bp;
{

	bp->b_flags &= ~B_MAP;
	if(maplock&B_WANTED)
		wakeup((caddr_t)&maplock);
	maplock = 0;
}
#endif
