#include "../h/param.h"
#include "../h/systm.h"
#include "../h/dir.h"
#include "../h/user.h"
#include "../h/proc.h"
#include "../h/seg.h"
#include "../h/map.h"
#include "../h/reg.h"

extern struct memregion board_map[];
extern char __bss_start[], __bss_end[];

unsigned int l1[4096] __attribute__((aligned(16384), section(KTABLES_SECTION)));
unsigned int user_l2[256] __attribute__((aligned(1024), section(KTABLES_SECTION)));
unsigned int uarea_l2[256] __attribute__((aligned(1024), section(KTABLES_SECTION)));
extern char __ddrbss_start[], __ddrbss_end[];
char	*msgbufp = msgbuf;

#define	UPAGES	((USIZE*64)/PGSIZE)	/* pages in the u-area window */

void machine_init()
{
	struct memregion *m;
	unsigned int pa, i;

	cninit();
	clock_ddr_init();

	{
		char *p;
		for(p = __ddrbss_start; p < __ddrbss_end; p++) *p = 0;
	}
	for(i = 0; i < 256; i++) { user_l2[i] = 0; uarea_l2[i] = 0; }

	for(m = board_map; m->end != 0; m++)
		for(pa = m->start; pa < m->end; pa += 0x100000U)
			l1[pa>>20] = (pa & 0xfff00000U) | m->attr;

	l1[0] = ((unsigned int)user_l2 & 0xfffffc00U) | PTE_PT;
	l1[UBASE>>20] = ((unsigned int)uarea_l2 & 0xfffffc00U) | PTE_PT;

	for(i = 0; i < UPAGES; i++)
		uarea_l2[i] = ((unsigned int)CLKADDR(64) + i*PGSIZE) | 0x12U;

	{
		char *p, *e = (char *)CLKADDR(64 + USIZE);
		for(p = (char *)CLKADDR(64); p < e; p++) *p = 0;
	}

	mmu_on((unsigned int)l1);
}

void arm_sureg(int *uisa, int *uisd, int nseg)
{
	unsigned int base, i, n;

	(void)uisa; (void)uisd; (void)nseg;
	if(u.u_procp == NULL)
		return;
	base = (unsigned int)CLKADDR(u.u_procp->p_addr + USIZE);
	n = (unsigned int)(u.u_procp->p_size - USIZE) >> (PGSHIFT-6);
	for(i = 0; i < 256; i++)
		user_l2[i] = i < n ? ((base + i*PGSIZE) & 0xfffff000U) | PG_USER : 0;
	__asm__ volatile(
	    "dsb ish\n\t"
	    "mcr p15, 0, %0, c8, c7, 0\n\t"	/* TLBIALL */
	    "dsb ish\n\t"
	    "isb" :: "r"(0) : "memory");
	arm_sync_icache();
}

void copyseg(int from, int to)
{
	int *s = (int *)CLKADDR(from), *d = (int *)CLKADDR(to), i;
	for(i = 0; i < 16; i++)
		d[i] = s[i];
}
void clearseg(int a)
{
	int *d = (int *)CLKADDR(a), i;
	for(i = 0; i < 16; i++)
		d[i] = 0;
}

static int user_range(caddr_t a, unsigned int n)
{
	unsigned int x = (unsigned int)a;
	return x < USERSIZE && n <= USERSIZE - x;
}
int fubyte(caddr_t addr)
{
	if(!user_range(addr, 1))
		return(-1);
	return *(unsigned char *)addr;
}
int subyte(caddr_t addr, int c)
{
	if(!user_range(addr, 1))
		return(-1);
	*(unsigned char *)addr = c;
	return(0);
}
int fuword(caddr_t addr)
{
	if(!user_range(addr, sizeof(int)))
		return(-1);
	return *(int *)addr;
}
int suword(caddr_t addr, int v)
{
	if(!user_range(addr, sizeof(int)))
		return(-1);
	*(int *)addr = v;
	return(0);
}
int copyin(caddr_t f, caddr_t t, unsigned int n)
{
	if(!user_range(f, n))
		return(-1);
	while(n--)
		*t++ = *f++;
	return(0);
}
int copyout(caddr_t f, caddr_t t, unsigned int n)
{
	if(!user_range(t, n))
		return(-1);
	while(n--)
		*t++ = *f++;
	return(0);
}

/*
 * Let a process handle a signal by simulating an interrupt
 */
void
sendsig(p, signo)
caddr_t p;
int	signo;
{
	register unsigned n;

	n = (u.u_ar0[R6] - (RPS+1)*sizeof(int)) & ~7;
	if(copyout((caddr_t)u.u_ar0, (caddr_t)n, (RPS+1)*sizeof(int)) < 0) {
		u.u_signal[SIGSEG] = 0;
		psignal(u.u_procp, SIGSEG);
		return;
	}
	u.u_ar0[R6] = n;
	u.u_ar0[14] = UENTRY_SIGTRAMP;	/* lr */
	u.u_ar0[R7] = (int)p;
	u.u_ar0[R0] = signo;
}

void
sigreturn()
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

void idle()
{
	__asm__ volatile("cpsie i\n\twfi\n\tcpsid i" ::: "memory");
}

void savfp(void *p)
{
	(void)p;
}
void restfp(void *p)
{
	(void)p;
}

#define KMSGBASE	0x7fff0000U

static char *
memaddr(unsigned int off)
{
	static unsigned int msgidx;

	if(off >= KMSGBASE && off < KMSGBASE + sizeof(msgidx) + MSGBUFS) {
		off -= KMSGBASE;
		msgidx = (unsigned int)(msgbufp - msgbuf);
		if(off < sizeof(msgidx))
			return((char *)&msgidx + off);
		return(&msgbuf[off - sizeof(msgidx)]);
	}
	if(off < KERNBASE)
		off += COREBASE;
	if((off >= KERNBASE && off < (unsigned int)__bss_end) ||
	   (off >= (unsigned int)__ddrbss_start && off < (unsigned int)__ddrbss_end) ||
	   (off >= COREBASE && off < CORETOP))
		return((char *)off);
	return(NULL);
}

int fumem(unsigned int off)
{
	char *a = memaddr(off);

	return(a == NULL ? -1 : *a & 0377);
}
int sumem(unsigned int off, int c)
{
	char *a = memaddr(off);

	if(a == NULL)
		return(-1);
	*a = c;
	return(0);
}

struct buf;
void mapfree(struct buf *bp)
{
	(void)bp;
}

/*
 * Icode is the bootstrap
 * program executed in user mode
 * to bring up the system.
 */
int	icode[] =
{
	0xe3a00024,	/* mov r0, #init */
	0xe3a01040,	/* mov r1, #initp */
	0xe3a02000,	/* mov r2, #0 */
	0xe3a0700b,	/* mov r7, #exec */
	0xef000000,	/* svc #0 */
	0xe3a00001,	/* mov r0, #1 */
	0xe3a07001,	/* mov r7, #exit */
	0xef000000,	/* svc #0 */
	0xeafffffe,	/* b . */
	0x6374652f,	/* init: </etc/init\0> */
	0x696e692f,
	0x00000074,
	0x00000000,
	0x00000000,
	0x00000000,
	0x00000000,
	0x00000024,	/* initp: init; 0 */
	0x00000000,
};
int	szicode = sizeof(icode);

void
install_sigtramp()
{
	suword((caddr_t)UENTRY_SIGTRAMP, (int)0xe3a0703fU);	/* mov r7, #63 */
	suword((caddr_t)UENTRY_SIGTRAMP+4, (int)0xef000000U);	/* svc #0 */
}

void
arm_sync_icache()
{
	unsigned int zero = 0;

	dcclean();
	__asm__ volatile(
	    "dsb ish\n\t"
	    "mcr p15, 0, %0, c7, c5, 0\n\t"	/* ICIALLU */
	    "mcr p15, 0, %0, c7, c5, 6\n\t"	/* BPIALL */
	    "dsb ish\n\t"
	    "isb"
	    :
	    : "r"(zero)
	    : "memory");
}

void
panictrap()
{
	panic("trap");
}

/*
 * Machine-dependent startup code
 */
void startup()
{
	register int n;

	n = (int)(NCLICK - (64 + USIZE));
	mfree(coremap, n, 64 + USIZE);
	mfree(swapmap, nswap, 1);
	swplo--;
	printf("mem = %D\n", ctob((long)n));
	maxmem = (int)(USERSIZE >> 6) + USIZE;
	bdinit();
}
