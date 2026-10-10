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
	register int i;

	/*
	 * zero and free all of core
	 */

	i = btoc(corebase) + USIZE;
	maxmem = btoc(coretop) - i;
	mfree(coremap, maxmem, i);
	printf("mem = %D\n", ctob((long)maxmem));
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
#define	TIMER	27
extern struct intr intrtab[];
unsigned long long clkcval;
unsigned	clkreload, clkrem, clkfrac;
int	irq_ready;

static void
gicen(int n)
{
	*(volatile unsigned char *)(gicdbase+0x400+n) = 0x80;
	GICD(0x100+(n>>5)*4) = 1U << (n&31);
}

void
clkstart(void)
{
	register struct intr *ip;

	if((clkreload = cntfrq_get()/HZ) == 0)
		panic("no clock");
	clkrem = cntfrq_get()%HZ;
	gicen(TIMER);
	for(ip = intrtab; ip->i_irq; ip++)
		if(*ip->i_irq)
			gicen(*ip->i_irq);
	GICD(0) = 1;
	GICC(4) = 0xff;
	GICC(0) = 1;
	cntv_cval_set(clkcval = cntvct_get() + clkreload);
	cntv_ctl_set(1);
	irq_ready = 1;
	spl0();
}

void
irq(int *r)
{
	register struct intr *ip;
	register unsigned n;

	n = GICC(0xc);
	if((n&0x3ff) == TIMER)
		clock((caddr_t)r[PC], (r[RPS]&0x1f) == 0x10 ? UMODE : 0);
	else
		for(ip = intrtab; ip->i_irq; ip++)
			if(*ip->i_irq == (int)(n&0x3ff))
				(*ip->i_fn)();
	GICC(0x10) = n;
}

/*
 * Let a process handle a signal by simulating an interrupt
 */
void
sendsig(caddr_t p, int signo)
{
	register unsigned n;

	n = (u.u_ar0[R6] - (RPS+1)*sizeof(int)) & ~7;
	if(copyout((caddr_t)u.u_ar0, (caddr_t)n, (RPS+1)*sizeof(int)) < 0) {
		u.u_signal[SIGSEG] = 0;
		psignal(u.u_procp, SIGSEG);
		return;
	}
	u.u_ar0[R6] = n;
	u.u_ar0[14] = UENTRY_SIGTRAMP;
	u.u_ar0[R7] = (int)p;
	u.u_ar0[R0] = signo;
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

void
mapalloc(register struct buf *bp)
{
	register int i, a;

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

void
mapfree(struct buf *bp)
{

	bp->b_flags &= ~B_MAP;
	if(maplock&B_WANTED)
		wakeup((caddr_t)&maplock);
	maplock = 0;
}

extern struct memregion board_map[];
extern char __bss_end[], __ddrbss_start[], __ddrbss_end[];
extern unsigned l1[], user_l2[], uarea_l2[];
char	*msgbufp = msgbuf;

caddr_t
machine_init(void)
{
	register struct memregion *m;
	register unsigned a;
	register char *p;

	cninit();
	clock_ddr_init();
	for(p = __ddrbss_start; p < __ddrbss_end; p++)
		*p = 0;
	for(m = board_map; m->end != 0; m++)
		for(a = m->start; a < m->end; a += 0x100000)
			l1[a>>20] = (a&0xfff00000) | m->attr;
	l1[0] = (unsigned)user_l2 | PTE_PT;
	l1[UBASE>>20] = (unsigned)uarea_l2 | PTE_PT;
	corebase = ctob(btoc(__ddrbss_end));
	for(a = 0; a < USIZE; a++)
		uarea_l2[a] = (corebase + ctob(a)) | 0x45e;
	for(p = (char *)corebase; p < (char *)corebase + ctob(USIZE); p++)
		*p = 0;
	mmu_on(l1);
	return((caddr_t)UBASE + ctob(USIZE));
}

void
arm_sureg(void)
{
	register unsigned i, n, base;

	if(u.u_procp == NULL)
		return;
	base = (unsigned)CLKADDR(u.u_procp->p_addr + USIZE);
	n = u.u_procp->p_size - USIZE;
	for(i = 0; i < 256; i++)
		user_l2[i] = i < n ? (base + i*PGSIZE) | pguser : 0;
	arm_sync_icache();
}

void
copyseg(int from, int to)
{
	register int *s, *d, i;

	s = (int *)CLKADDR(from);
	d = (int *)CLKADDR(to);
	for(i = 0; i < PGSIZE/4; i++)
		d[i] = s[i];
}

void
clearseg(int a)
{
	register int *d, i;

	d = (int *)CLKADDR(a);
	for(i = 0; i < PGSIZE/4; i++)
		d[i] = 0;
}

static int
uaddr(caddr_t a, unsigned n)
{
	return((unsigned)a < USERSIZE && n <= USERSIZE - (unsigned)a);
}

int
fubyte(caddr_t a)
{
	if(!uaddr(a, 1))
		return(-1);
	return(*a & 0377);
}

int
subyte(caddr_t a, int c)
{
	if(!uaddr(a, 1))
		return(-1);
	*a = c;
	return(0);
}

int
fuword(caddr_t a)
{
	if(!uaddr(a, sizeof(int)))
		return(-1);
	return(*(int *)a);
}

int
suword(caddr_t a, int v)
{
	if(!uaddr(a, sizeof(int)))
		return(-1);
	*(int *)a = v;
	return(0);
}

static void
ucopy(caddr_t f, caddr_t t, unsigned n)
{
	register int *fp, *tp;

	if((((unsigned)f|(unsigned)t|n) & (NBPW-1)) != 0) {
		if(n)
			bcopy(f, t, n);
		return;
	}
	fp = (int *)f;
	tp = (int *)t;
	for(n /= NBPW; n; n--)
		*tp++ = *fp++;
}

int
copyin(caddr_t f, caddr_t t, unsigned n)
{
	if(!uaddr(f, n))
		return(-1);
	ucopy(f, t, n);
	return(0);
}

int
copyout(caddr_t f, caddr_t t, unsigned n)
{
	if(!uaddr(t, n))
		return(-1);
	ucopy(f, t, n);
	return(0);
}

void
sigreturn(void)
{
	int f[RPS+1];
	register int i;

	if(copyin((caddr_t)u.u_ar0[R6], (caddr_t)f, sizeof(f)) < 0) {
		u.u_signal[SIGSEG] = 0;
		psignal(u.u_procp, SIGSEG);
		return;
	}
	for(i = 0; i < RPS; i++)
		u.u_ar0[i] = f[i];
	u.u_ar0[RPS] = (u.u_ar0[RPS] & ~0xf80f0000) | (f[RPS] & 0xf80f0000);
	u.u_r.r_val1 = f[R0];
	u.u_r.r_val2 = f[R1];
}

static char *
memaddr(off_t off)
{
	register unsigned a;

	a = off;
	if(a < kernbase)
		a += corebase;
	if((a >= kernbase && a < (unsigned)__bss_end) ||
	   (a >= (unsigned)__ddrbss_start && a < (unsigned)__ddrbss_end) ||
	   (a >= corebase && a < coretop))
		return((char *)a);
	return(NULL);
}

int
fumem(off_t off)
{
	register char *a;

	if((a = memaddr(off)) == NULL)
		return(-1);
	return(*a & 0377);
}

int
sumem(off_t off, int c)
{
	register char *a;

	if((a = memaddr(off)) == NULL)
		return(-1);
	*a = c;
	return(0);
}

void
install_sigtramp(void)
{
	suword((caddr_t)UENTRY_SIGTRAMP, (int)0xe3a0703fU);	/* mov r7, #63 */
	suword((caddr_t)UENTRY_SIGTRAMP+4, (int)0xef000000U);	/* svc #0 */
}

void
panictrap(void)
{
	panic("trap");
}
