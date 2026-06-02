#include "../h/param.h"
#include "../h/systm.h"
#include "../h/dir.h"
#include "../h/user.h"
#include "../h/proc.h"
#include "../h/seg.h"
#include "../h/map.h"

void printf(char *fmt, ...);
void panic(char *s);
void mmu_on(unsigned int ttb);
void cninit(void);			/* board console early init (cn driver) */
void bdinit(void);
void mfree(struct map *mp, int size, int a);
extern struct memregion board_map[];	/* per-board section map (conf/<board>.c) */
extern void clock_ddr_init(void);	/* per-board clocks + DRAM bring-up */
extern char __bss_start[], __bss_end[];

/*
 * Page tables.  One global L1 (TTBR0) maps the kernel and the physical
 * core window as 1 MB sections, plus two L2 tables:
 *   user_l2  -- user VA 0..1MB, (re)loaded by arm_sureg() per process
 *   uarea_l2 -- the UBASE u-area window, remapped by resume() per process
 * Only these two follow the current process; everything else is fixed.
 */
/* l1 is large (16 KB) and goes to DDR on the MP135 (KTABLES_SECTION=.ddrbss);
 * on QEMU it stays in ordinary .bss.  The two small per-process L2 tables stay
 * in fast SYSRAM as they are rewritten on every context switch. */
unsigned int l1[4096] __attribute__((aligned(16384), section(KTABLES_SECTION)));
/* The page-table walk is non-cacheable, so the two per-process L2 tables must
 * live in the same non-cacheable region as l1 (KTABLES_SECTION = DDR on the
 * MP135): if they were in cached SYSRAM, resume()/sureg() writes would sit in
 * the D-cache and the walk would read stale entries, leaving the u-area/user
 * windows pointing at the previous process's core. */
unsigned int user_l2[256] __attribute__((aligned(1024), section(KTABLES_SECTION)));
unsigned int uarea_l2[256] __attribute__((aligned(1024), section(KTABLES_SECTION)));
extern char __ddrbss_start[], __ddrbss_end[];	/* zeroed in machine_init */

#define	UPAGES	((USIZE*64)/PGSIZE)	/* pages in the u-area window */

/*
 * Board-resolved constant that resume() (mch.s) needs but cannot reach: the
 * assembler is not run through cpp, so it loads COREBASE from memory instead
 * of the seg.h/memmap.h macro.  It resolves here to the current board's value.
 */
unsigned int corebase = COREBASE;	/* physical base of the user core window */

/*
 * Called from _start (conf/low.s) before switching to the u-area stack.
 * Board-independent: bring up the board's clocks + DRAM, then build the L1
 * section table from the board's memory map (board_map[], conf/<board>.c) and
 * the two per-process L2 windows, and enable the MMU + caches.  The same code
 * runs on every board -- only board_map[] and clock_ddr_init() differ -- so a
 * QEMU run exercises the identical machine_init() the MP135 uses.
 */
void machine_init(void)
{
	struct memregion *m;
	unsigned int pa, i;

	cninit();			/* bring up the console (UART4 from HSI) early */
	clock_ddr_init();		/* clocks + DRAM (no-op where RAM is already up) */

	/* DRAM is up now, so zero the DDR-resident table section (holds l1 and
	 * the big system tables); low.s already zeroed the SYSRAM .bss. */
	{
		char *p;
		for(p = __ddrbss_start; p < __ddrbss_end; p++) *p = 0;
	}
	for(i = 0; i < 256; i++) { user_l2[i] = 0; uarea_l2[i] = 0; }

	/* physical core + device sections, from the board's memory map */
	for(m = board_map; m->end != 0; m++)
		for(pa = m->start; pa < m->end; pa += 0x100000U)
			l1[pa>>20] = (pa & 0xfff00000U) | m->attr;

	/* user window (VA 0..1MB) and u-area window via L2 tables */
	l1[0] = ((unsigned int)user_l2 & 0xfffffc00U) | PTE_PT;
	l1[UBASE>>20] = ((unsigned int)uarea_l2 & 0xfffffc00U) | PTE_PT;

	/* point the u-area window at proc[0]'s u-area (clicks 64..64+USIZE).
	 * Map it UNCACHED (0x12), the same attribute resume() uses: the window is
	 * remapped to a different PA on every context switch, and the same physical
	 * u-area is also visible (uncached) through the COREBASE core window, so a
	 * cached alias here would go incoherent the moment resume() switched it. */
	for(i = 0; i < UPAGES; i++)
		uarea_l2[i] = ((unsigned int)CLKADDR(64) + i*PGSIZE) | 0x12U;

	/* proc[0]'s u-area lives in the user core (COREBASE), not in the zeroed
	 * .ddrbss, so clear it here: newproc() copies it to proc[1] and the kernel
	 * reads u_ofile[]/p_textp expecting a clean (zeroed) initial u-area. */
	{
		char *p, *e = (char *)CLKADDR(64 + USIZE);
		for(p = (char *)CLKADDR(64); p < e; p++) *p = 0;
	}

	mmu_on((unsigned int)l1);
}

/*
 * Load the user-region page table (user_l2) for the current process.
 * The Armv7 user layout is flat (1 MB at VA 0; binaries link at UENTRY,
 * stack near USTACK), so the whole user window maps contiguously to the
 * image clicks just above the u-area.  Called from sureg() (ureg.c).
 */
void arm_sureg(int *uisa, int *uisd, int nseg)
{
	unsigned int base;
	int i;

	(void)uisa; (void)uisd; (void)nseg;
	if(u.u_procp == NULL)
		return;
	base = (unsigned int)CLKADDR(u.u_procp->p_addr + USIZE);
	for(i = 0; i < 256; i++)
		user_l2[i] = ((base + i*PGSIZE) & 0xfffff000U) | PG_USER;
	__asm__ volatile(
	    "dsb ish\n\t"
	    "mcr p15, 0, %0, c8, c7, 0\n\t"	/* TLBIALL */
	    "dsb ish\n\t"
	    "isb" :: "r"(0) : "memory");
}

/*
 * Copy / clear one 64-byte click of physical core.  Core is directly
 * addressable through the PA==VA kernel window, so these are plain
 * memory operations (the v7 m40.s copyseg/clearseg role).
 */
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

/*
 * User-space access primitives (the v7 fubyte/subyte/... role).  User VAs
 * live in [0, USERSIZE); a bounds check keeps a bad user pointer from
 * faulting the kernel (Armv7 has no fault-recovery path here).
 */
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
int subyte(caddr_t addr, char c)
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

/* Idle: allow interrupts, wait, then re-mask (the v7 idle() in swtch). */
void idle(void)
{
	__asm__ volatile("cpsie i\n\twfi\n\tcpsid i" ::: "memory");
}

/* No VFP context is carried for user programs (soft-float ABI). */
void savfp(void *p)
{
	(void)p;
}
void restfp(void *p)
{
	(void)p;
}

/*
 * /dev/mem,/dev/kmem core read.  ps(1) and friends address two kinds of
 * thing through /dev/mem: kernel symbols resolved from the namelist (true
 * kernel virtual addresses, KERNBASE and up) and per-process u-areas as a
 * bare click offset `p_addr<<6` (V7 assumed core began at physical 0).
 * The kernel image and physical core window are identity-mapped, so a VA
 * at or above KERNBASE is read directly; a smaller value is a core-relative
 * click offset and is biased by COREBASE to reach the real backing page.
 */
#define KMSGBASE	0x7fff0000U

static int mem_range_ok(unsigned int off, unsigned int n)
{
	unsigned int end;

	if(n == 0)
		return(1);
	end = off + n;
	if(end < off)
		return(0);
	if(off >= KERNBASE && end <= (unsigned int)__bss_end)
		return(1);
	if(off >= (unsigned int)__ddrbss_start && end <= (unsigned int)__ddrbss_end)
		return(1);
	if(off >= COREBASE && end <= CORETOP)
		return(1);
	return(0);
}

int arm_mem_read(unsigned int off, char *buf, unsigned int n)
{
	char *s;
	unsigned int i;
	unsigned int msgoff, msgidx;

	if(off >= KMSGBASE && off < KMSGBASE + sizeof(unsigned int) + MSGBUFS) {
		msgoff = off - KMSGBASE;
		msgidx = (unsigned int)(msgbufp - msgbuf);
		for(i = 0; i < n; i++, msgoff++) {
			if(msgoff < sizeof(unsigned int))
				buf[i] = ((char *)&msgidx)[msgoff];
			else if(msgoff < sizeof(unsigned int) + MSGBUFS)
				buf[i] = msgbuf[msgoff - sizeof(unsigned int)];
			else
				buf[i] = 0;
		}
		return((int)n);
	}
	if(off < KERNBASE)
		off += COREBASE;
	if(!mem_range_ok(off, n))
		return(-1);
	s = (char *)off;
	for(i = 0; i < n; i++)
		buf[i] = s[i];
	return((int)n);
}

/* No UNIBUS/buffer map on Armv7. */
struct buf;
void mapfree(struct buf *bp)
{
	(void)bp;
}

/*
 * Icode is the bootstrap program executed in user mode to bring up the
 * system; it execs /etc/init.  Position-independent Armv7, runs at VA 0.
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
install_sigtramp(char *base)
{
	volatile unsigned int *t = (volatile unsigned int *)(base + UENTRY_SIGTRAMP);

	t[0] = 0xe3a0703fU;	/* mov r7, #63 (sigreturn) */
	t[1] = 0xef000000U;	/* svc #0 */
}

void
arm_sync_icache(void)
{
	unsigned int zero = 0;

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
panictrap(void)
{
	panic("trap");
}

/*
 * Machine-dependent startup, called from main() (on the u-area stack,
 * MMU already enabled by machine_init).  Free all user core to the
 * coremap and report it.  proc[0]'s u-area occupies clicks 64..64+USIZE;
 * click 0 is reserved.
 */
void startup(void)
{
	register int n;

	n = (int)(NCLICK - (64 + USIZE));
	mfree(coremap, n, 64 + USIZE);
	mfree(swapmap, 8192, 1);
	printf("mem = %D\n", ctob((long)n));
	/*
	 * A process image is bounded by the 1 MB user MMU window, not by
	 * total core, so maxmem is the window size (estabur enforces it).
	 */
	maxmem = (int)(USERSIZE >> 6) + USIZE;
	bdinit();
}
