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
#include "../h/buf.h"
#include "../h/conf.h"

#define	GICD(o)	(*(volatile unsigned *)(gicdbase+(o)))
#define	GICC(o)	(*(volatile unsigned *)(giccbase+(o)))
#define	DCTLR	0x000
#define	TYPER	0x004
#define	ISENABLER	0x100
#define	ICENABLER	0x180
#define	IPRIORITYR	0x400
#define	CCTLR	0x00
#define	PMR	0x04
#define	IAR	0x0c
#define	EOIR	0x10

extern char _start[], __bss_end[];
unsigned long long clkcval;
unsigned	clkreload, clkrem, clkfrac;
int	clkirq = 27;

/*
 * Icode is the hex bootstrap
 * program executed in user mode
 * to bring up the system.
 */
int	icode[] =
{
	0xe3a0001c,	/* mov r0, #init */
	0xe3a01014,	/* mov r1, #initp */
	0xe3a0700b,	/* mov r7, #exec */
	0xef000000,	/* svc #0 */
	0xeafffffe,	/* b . */
	0x0000001c,	/* initp: init; 0 */
	0x00000000,
	0x6374652f,	/* init: </etc/init\0> */
	0x696e692f,
	0x00000074,
};
int	szicode = sizeof(icode);
int	sigpage;		/* page of the signal trampoline */

/*
 * Machine-dependent startup code
 */
void
startup(void)
{
	register int i, a;
	unsigned *t;

	/*
	 * free all of core
	 */

	i = btop(corebase) + USIZE;
	l1tab = (unsigned long long *)PGADDR(i);
	l1pa = ptob(i);
	for(a = 0; a < 4*NPROC; a++)
		l1tab[a] = 0;
	i += btop(32*NPROC);
	mfree(ptmap, NPTAB, i);
	i += NPTAB;

	/*
	 * the signal trampoline,
	 * mapped into every process
	 */

	sigpage = i++;
	clearseg(sigpage);
	t = (unsigned *)PGADDR(sigpage);
	t[0] = 0xe3a0703f;	/* mov r7, #63 */
	t[1] = 0xef000000;	/* svc #0 */
	arm_sync_icache((caddr_t)t, 8);

	/*
	 * the buffers of the buffer cache, in core,
	 * where the disk's DMA can reach them
	 */

	buffers = (int (*)[(BSIZE+BSLOP+63)/64*16])PGADDR(i);
	i += btop(NBUF*sizeof(*buffers));
	maxmem = btop(coretop) - i;
	mfree(coremap, maxmem, i);
	printf("mem = %d\n", ptob(maxmem));
	mfree(swapmap, nswap, 1);
	swplo--;
}

static void
gicen(int n)
{
	*(volatile unsigned char *)(gicdbase+IPRIORITYR+n) = 0x80;
	GICD(ISENABLER+(n>>5)*4) = 1U << (n&31);
}

void
clkstart(void)
{

	if((clkreload = cntfrq_get()/HZ) == 0)
		panic("no clock");
	clkrem = cntfrq_get()%HZ;
	cntv_cval_set(clkcval = cntvct_get() + clkreload);
	cntv_ctl_set(1);
}

/*
 * Enable every configured interrupt,
 * turn the interrupt controller on,
 * and unmask the processor.
 */
void
intrstart(void)
{
	register struct intr *ip;
	register int i;

	for(i = 0; i <= (int)(GICD(TYPER)&037); i++)
		GICD(ICENABLER+4*i) = ~0U;
	for(ip = intrtab; ip->i_irq; ip++)
		if(*ip->i_irq)
			gicen(*ip->i_irq);
	GICD(DCTLR) = 1;
	GICC(PMR) = 0xff;
	GICC(CCTLR) = 1;
	intr_enable();
}

void
irq(int *r)
{
	register struct intr *ip;
	register unsigned n;

	n = GICC(IAR);
	for(ip = intrtab; ip->i_irq; ip++)
		if(*ip->i_irq == (int)(n&0x3ff))
			(*ip->i_fn)((caddr_t)r[PC], r[PSR]);
	GICC(EOIR) = n;
}

/*
 * Map the regions of board_map whose attributes are attr in blocks.
 * A region which does not begin on a block, the MP135's SYSRAM, keeps
 * the pages in which _start mapped the kernel.
 */
static void
kmap(unsigned long long attr)
{
	register struct memregion *m;
	register unsigned a;

	for(m = board_map; m->end != 0; m++)
		if(m->attr == attr && (m->start & ((1U<<BLKSHIFT)-1)) == 0)
			for(a = m->start; a < m->end; a += 1U<<BLKSHIFT)
				kl2[((m->va+a-m->start)>>BLKSHIFT) & (NPTE-1)] =
				    a | m->attr;
	tlbflush();
}

unsigned
vtop(caddr_t va)
{
	register struct memregion *m;
	register unsigned a;

	a = (unsigned)va;
	for(m = board_map; m->end != 0; m++)
		if(m->attr != BLK_DEV && a - m->va < m->end - m->start)
			return(a - m->va + m->start);
	panic("vtop");
	return(0);
}

caddr_t
machine_init(void)
{
	register struct memregion *m;
	register unsigned a;
	register char *p;

	kmap(BLK_DEV);
	wdinit();
	cninit();
	clock_ddr_init();
	kmap(BLK_KERN);
	a = ptob(btop(vtop(__bss_end)));
	if(a > corebase && a < coretop)
		corebase = a;
	for(m = board_map; m->end != 0; m++)
		if(m->attr == BLK_KERN && corebase - m->start < m->end - m->start)
			coreoff = m->va - m->start;
	for(a = 0; a < USIZE; a++)
		kl3u[a] = (corebase + ptob(a)) | BLK_KERN | PTE_TAB;
	kl2[(UBASE>>BLKSHIFT) & (NPTE-1)] = vtop((caddr_t)kl3u) | PTE_TAB;
	bootl1[vtop(_start)>>L1SHIFT] = 0;
	tlbflush();
	for(p = (char *)UBASE; p < (char *)UBASE + ptob(USIZE); p++)
		*p = 0;
	return((caddr_t)UBASE + ptob(USIZE));
}

void
copyseg(int from, int to)
{
	register int *s, *d, i;

	s = (int *)PGADDR(from);
	d = (int *)PGADDR(to);
	for(i = 0; i < PGSIZE/4; i++)
		d[i] = s[i];
}

void
clearseg(int a)
{
	register int *d, i;

	d = (int *)PGADDR(a);
	for(i = 0; i < PGSIZE/4; i++)
		d[i] = 0;
}

/*
 * The kernel's address for offset off of /dev/mem, a physical
 * address, or of /dev/kmem, a kernel address, in a region of
 * board_map whose attributes are attr
 */
static char *
mapaddr(int dev, off_t off, unsigned long long attr)
{
	register struct memregion *m;
	register unsigned base;

	for(m = board_map; m->end != 0; m++) {
		base = minor(dev) == 0 ? m->start : m->va;
		if(m->attr == attr && (unsigned)off - base < m->end - m->start)
			return((char *)(m->va + ((unsigned)off - base)));
	}
	return(NULL);
}

static char *
memaddr(int dev, off_t off)
{
	if(minor(dev) == 1 && (unsigned)off - UBASE < ptob(USIZE))
		return((char *)off);
	return(mapaddr(dev, off, BLK_KERN));
}

/*
 * A device register, read and written a word at a time
 */
char *
devaddr(int dev, off_t off)
{
	return(mapaddr(dev, off, BLK_DEV));
}

int
fumem(int dev, off_t off)
{
	register char *a;

	if((a = memaddr(dev, off)) == NULL)
		return(-1);
	return(fkbyte(a));
}

int
sumem(int dev, off_t off, int c)
{
	register char *a;

	if((a = memaddr(dev, off)) == NULL)
		return(-1);
	return(skbyte(a, c));
}

/*
 * Let a process handle a signal by simulating an interrupt
 */
void
sendsig(caddr_t p, int signo)
{
	register unsigned n, m;

	m = (PSR+1)*sizeof(int);
	n = (u.u_ar0[SP] - m - sizeof(u.u_fps)) & ~7;
	grow(n);
	if(copyout((caddr_t)u.u_ar0, (caddr_t)n, m) < 0 ||
	    copyout((caddr_t)&u.u_fps, (caddr_t)(n+m),
	    sizeof(u.u_fps)) < 0) {
		u.u_signal[SIGSEG] = 0;
		psignal(u.u_procp, SIGSEG);
		return;
	}
	u.u_ar0[SP] = n;
	u.u_ar0[LR] = SIGTRAMP;
	u.u_ar0[PC] = (int)p;
	u.u_ar0[R0] = signo;
	u.u_ar0[PSR] &= ~TBITS;
}

void
sigreturn(void)
{
	int f[PSR+1];
	register int i;
	register caddr_t a;

	a = (caddr_t)u.u_ar0[SP];
	if(copyin(a, (caddr_t)f, sizeof(f)) < 0 ||
	    copyin(a+sizeof(f), (caddr_t)&u.u_fps,
	    sizeof(u.u_fps)) < 0) {
		u.u_signal[SIGSEG] = 0;
		psignal(u.u_procp, SIGSEG);
		return;
	}
	u.u_fpsaved = 1;
	for(i = 0; i < PSR; i++)
		u.u_ar0[i] = f[i];
	u.u_ar0[PSR] = (f[PSR] & UBITS) | USRMODE;
	u.u_r.r_val1 = f[R0];
	u.u_r.r_val2 = f[R1];
}

void
panictrap(void)
{
	panic("trap");
}
