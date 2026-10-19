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

/*
 * Machine-dependent startup code
 */
void
startup(void)
{
	register int i, a;

	/*
	 * free all of core
	 */

	i = btop(corebase) + USIZE;
	l1tab = (unsigned long long *)PGADDR(i);
	l1pa = ptob((unsigned)i);
	for(a = 0; a < 4*NPROC; a++)
		l1tab[a] = 0;
	i += btop(32*NPROC);
	mfree(ptmap, NPTAB, i);
	i += NPTAB;
	maxmem = btop(coretop) - i;
	mfree(coremap, maxmem, i);
	printf("mem = %D\n", ptob((long)maxmem));
	if(MAXMEM < maxmem)
		maxmem = MAXMEM;
	mfree(swapmap, nswap, 1);
	swplo--;
	bdinit();
}

/*
 * set up a physical address
 * into users virtual address space.
 */
void
sysphys(void)
{

	if(!suser())
		return;
	u.u_error = EINVAL;
}

/*
 * Determine which clock is attached, and start it.
 * panic: no clock found
 */
#define	GICD(o)	(*(volatile unsigned *)(gicdbase+(o)))
#define	GICC(o)	(*(volatile unsigned *)(giccbase+(o)))
extern struct intr intrtab[];
unsigned long long clkcval;
unsigned	clkreload, clkrem, clkfrac;
int	clkirq = 27;

static void
gicen(int n)
{
	*(volatile unsigned char *)(gicdbase+0x400+n) = 0x80;
	GICD(0x100+(n>>5)*4) = 1U << (n&31);
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

	for(ip = intrtab; ip->i_irq; ip++)
		if(*ip->i_irq)
			gicen(*ip->i_irq);
	GICD(0) = 1;
	GICC(4) = 0xff;
	GICC(0) = 1;
	intr_enable();
}

void
irq(int *r)
{
	register struct intr *ip;
	register unsigned n;

	n = GICC(0xc);
	for(ip = intrtab; ip->i_irq; ip++)
		if(*ip->i_irq == (int)(n&0x3ff))
			(*ip->i_fn)((caddr_t)r[PC], r[PSR]);
	GICC(0x10) = n;
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
	u.u_ar0[14] = UENTRY_SIGTRAMP;
	u.u_ar0[PC] = (int)p;
	u.u_ar0[R0] = signo;
	u.u_ar0[PSR] &= ~0x0600fe20;
}

extern struct memregion board_map[];
extern char _start[], __bss_end[], __ddrbss_start[], __ddrbss_end[];
extern unsigned long long kl2[], kl3u[], bootl1[];
char	*msgbufp = msgbuf;

static void
kmap(int dev)
{
	register struct memregion *m;
	register unsigned a;

	for(m = board_map; m->end != 0; m++)
		if((m->attr == BLK_DEV) == dev)
			for(a = m->start; a < m->end; a += 0x200000)
				kl2[((m->va+a-m->start)>>21) & 0x1ff] =
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
	register unsigned a;
	register char *p;

	kmap(1);
	GICD(0) = 0;
	GICC(0) = 0;
	cninit();
	clock_ddr_init();
	kmap(0);
	for(p = __ddrbss_start; p < __ddrbss_end; p++)
		*p = 0;
	coreoff = (unsigned)__ddrbss_end - vtop(__ddrbss_end);
	corebase = ptob(btop(vtop(__ddrbss_end)));
	for(a = 0; a < USIZE; a++)
		kl3u[a] = (corebase + ptob(a)) | BLK_KERN | PTE_TAB;
	kl2[511] = vtop((caddr_t)kl3u) | PTE_TAB;
	bootl1[vtop(_start)>>30] = 0;
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
	u.u_ar0[PSR] = (f[PSR] & 0xfe0ffe20) | 0x10;
	u.u_r.r_val1 = f[R0];
	u.u_r.r_val2 = f[R1];
}

static char *
memaddr(int dev, off_t off)
{
	register unsigned a, b, e;
	register int i;

	if(minor(dev) == 1 && (unsigned)off - UBASE < ptob(USIZE))
		return((char *)off);
	for(i = 0; i < 2; i++) {
		b = (unsigned)(i ? __ddrbss_start : _start);
		e = i ? (unsigned)PGADDR(btop(coretop)) :
		    (unsigned)__bss_end;
		a = off;
		if(minor(dev) == 0)
			a += b - vtop((caddr_t)b);
		if(a - b < e - b)
			return((char *)a);
	}
	return(NULL);
}

/*
 * A device register at physical address off, for /dev/mem
 */
char *
devaddr(off_t off)
{
	register struct memregion *m;

	for(m = board_map; m->end != 0; m++)
		if(m->attr == BLK_DEV &&
		    (unsigned)off - m->start < m->end - m->start)
			return((char *)(m->va +
			    (unsigned)off - m->start));
	return(NULL);
}

int
fumem(int dev, off_t off)
{
	register char *a;

	if((a = memaddr(dev, off)) == NULL)
		return(-1);
	return(*a & 0377);
}

int
sumem(int dev, off_t off, int c)
{
	register char *a;

	if((a = memaddr(dev, off)) == NULL)
		return(-1);
	*a = c;
	return(0);
}

void
install_sigtramp(void)
{
	/* mov r7, #63; svc #0 */
	suword((caddr_t)UENTRY_SIGTRAMP, (int)0xe3a0703fU);
	suword((caddr_t)UENTRY_SIGTRAMP+4, (int)0xef000000U);
}

void
panictrap(void)
{
	panic("trap");
}
