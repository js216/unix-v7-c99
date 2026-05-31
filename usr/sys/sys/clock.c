#include "../h/param.h"
#include "../h/systm.h"
#include "../h/callo.h"
#include "../h/dir.h"
#include "../h/user.h"
#include "../h/proc.h"
#include "../h/seg.h"		/* GIC_DIST_BASE/GIC_CPU_BASE (board memmap.h) */
extern void addupc(caddr_t pc, void *prof, int inc);
int intr_disable(void);
void intr_restore(int s);
void wakeup(caddr_t chan);
void panic(char *s);

#define	SCHMAG	8/10

/*
 * clock is called straight from
 * the real time clock interrupt.
 *
 * Functions:
 *	reprime clock
 *	copy *switches to display
 *	implement callouts
 *	maintain user/system times
 *	maintain date
 *	profile
 *	lightning bolt wakeup (every second)
 *	alarm clock signals
 *	jab the scheduler
 */

void
clock(dev_t dev, int sp, int r1, int nps, int r0, caddr_t pc, int ps)
{
	register struct callo *p1, *p2;
	register struct proc *pp;
	int a;
	extern caddr_t waitloc;
	(void)dev; (void)sp; (void)r1; (void)nps; (void)r0;

	/*
	 * restart clock
	 */


	/*
	 * display register
	 */

	/*
	 * callouts
	 * if none, just continue
	 * else update first non-zero time
	 */

	if(callout[0].c_func == NULL)
		goto out;
	p2 = &callout[0];
	while(p2->c_time<=0 && p2->c_func!=NULL)
		p2++;
	p2->c_time--;

	/*
	 * if ps is high, just return
	 */
	if (BASEPRI(ps))
		goto out;

	/*
	 * callout
	 */

	intr_disable();
	if(callout[0].c_time <= 0) {
		p1 = &callout[0];
		while(p1->c_func != 0 && p1->c_time <= 0) {
			(*p1->c_func)(p1->c_arg);
			p1++;
		}
		p2 = &callout[0];
		while((p2->c_func = p1->c_func) != 0) {
			p2->c_time = p1->c_time;
			p2->c_arg = p1->c_arg;
			p1++;
			p2++;
		}
	}

	/*
	 * lightning bolt time-out
	 * and time of day
	 */
out:
	a = dk_busy&07;
	if (USERMODE(ps)) {
		u.u_utime++;
		if(u.u_prof.pr_scale)
			addupc(pc, &u.u_prof, 1);
		if(u.u_procp->p_nice > NZERO)
			a += 8;
	} else {
		a += 16;
		if (pc == waitloc)
			a += 8;
		u.u_stime++;
	}
	dk_time[a] += 1;
	pp = u.u_procp;
	if(++pp->p_cpu == 0)
		pp->p_cpu--;
	if(++lbolt >= HZ) {
		if (BASEPRI(ps))
			return;
		lbolt -= HZ;
		++time;
		intr_disable();
		runrun++;
		wakeup((caddr_t)&lbolt);
		for(pp = &proc[0]; pp < &proc[NPROC]; pp++)
		if (pp->p_stat && pp->p_stat<SZOMB) {
			if(pp->p_time != 127)
				pp->p_time++;
			if(pp->p_clktim)
				if(--pp->p_clktim == 0)
					psignal(pp, SIGCLK);
			a = (pp->p_cpu & 0377)*SCHMAG + pp->p_nice - NZERO;
			if(a < 0)
				a = 0;
			if(a > 255)
				a = 255;
			pp->p_cpu = a;
			if(pp->p_pri >= PUSER)
				setpri(pp);
		}
		if(runin!=0) {
			runin = 0;
			wakeup((caddr_t)&runin);
		}
	}
}

/*
 * timeout is called to arrange that
 * fun(arg) is called in tim/HZ seconds.
 * An entry is sorted into the callout
 * structure. The time in each structure
 * entry is the number of HZ's more
 * than the previous entry.
 * In this way, decrementing the
 * first entry has the effect of
 * updating all entries.
 *
 * The panic is there because there is nothing
 * intelligent to be done if an entry won't fit.
 */
void
timeout(int (*fun)(), caddr_t arg, int tim)
{
	register struct callo *p1, *p2;
	register int t;
	int s;

	t = tim;
	p1 = &callout[0];
	s = intr_disable();
	while(p1->c_func != 0 && p1->c_time <= t) {
		t -= p1->c_time;
		p1++;
	}
	if (p1 >= &callout[NCALL-1])
		panic("Timeout table overflow");
	p1->c_time -= t;
	p2 = p1;
	while(p2->c_func != 0)
		p2++;
	while(p2 >= p1) {
		(p2+1)->c_time = p2->c_time;
		(p2+1)->c_func = p2->c_func;
		(p2+1)->c_arg = p2->c_arg;
		p2--;
	}
	p1->c_time = t;
	p1->c_func = fun;
	p1->c_arg = arg;
	intr_restore(s);
}
#define GICD_BASE	GIC_DIST_BASE	/* board-specific (conf/<board>/memmap.h) */
#define GICC_BASE	GIC_CPU_BASE
#define GICD_CTLR	(*(volatile unsigned int *)(GICD_BASE + 0x000))
#define GICD_ISENABLER(n) (*(volatile unsigned int *)(GICD_BASE + 0x100 + 4*(n)))
#define GICD_IPRIORITYR(n) (*(volatile unsigned int *)(GICD_BASE + 0x400 + 4*(n)))
#define GICC_CTLR	(*(volatile unsigned int *)(GICC_BASE + 0x000))
#define GICC_PMR	(*(volatile unsigned int *)(GICC_BASE + 0x004))
#define GICC_IAR	(*(volatile unsigned int *)(GICC_BASE + 0x00c))
#define GICC_EOIR	(*(volatile unsigned int *)(GICC_BASE + 0x010))
#define TIMER_IRQ	27
#define TIMER_HZ	HZ
extern unsigned int cntfrq_get(void);
extern void cntv_tval_set(unsigned int v), cntv_ctl_set(unsigned int v);
extern void irq_enable(void);
extern int cnintr(void);	/* console interrupt (board console driver) */
extern int cn_irq;		/* console GIC INTID, set by the console driver */
extern int bdintr(void);	/* block-device interrupt (board block driver) */
extern int bd_irq;		/* block-device GIC INTID, set by the driver */
static unsigned int timer_reload;
int irq_ready;
caddr_t waitloc;	/* pc of the idle wait, for cpu-time accounting */
void addupc(caddr_t pc, void *prof, int inc) { (void)pc; (void)prof; (void)inc; }
/*
 * Real-time clock interrupt: acknowledge the GIC, reprime the timer, and
 * call the v7 clock() with the trapped pc/ps.  clock() runs with IRQs
 * masked (we are in the IRQ handler) and never lowers priority, so it is
 * not re-entrant; preemption happens on return to user via trap()'s tail.
 */
void
clock_irq_handler(int *tf)
{
	unsigned int iar = GICC_IAR;
	unsigned int intid = iar & 0x3ff;
	if(intid == 1023) return;
	if(intid == TIMER_IRQ) {
		int mode = tf[16] & 0x1f;
		int usermode = (mode == 0x10) || (mode == 0x1f);
		cntv_tval_set(timer_reload);
		if(u.u_procp != NULL)
			clock(0, 0, 0, 0, 0, (caddr_t)tf[15],
			    usermode ? 0xf000 : 0);
	} else if(cn_irq && intid == (unsigned int)cn_irq)
		cnintr();
	else if(bd_irq && intid == (unsigned int)bd_irq)
		bdintr();
	GICC_EOIR = iar;
}
void
clkstart(void)
{
	unsigned int freq, prio_reg, prio_off, prio_val;
	freq = cntfrq_get();
	if(freq == 0) freq = 62500000U;
	timer_reload = freq / TIMER_HZ;
	prio_reg = TIMER_IRQ / 4;
	prio_off = (TIMER_IRQ % 4) * 8;
	prio_val = GICD_IPRIORITYR(prio_reg);
	prio_val &= ~(0xffU << prio_off);
	prio_val |=  (0x80U << prio_off);
	GICD_IPRIORITYR(prio_reg) = prio_val;
	GICD_ISENABLER(TIMER_IRQ / 32) = 1U << (TIMER_IRQ % 32);
	if(cn_irq) {
		prio_reg = cn_irq / 4;
		prio_off = (cn_irq % 4) * 8;
		prio_val = GICD_IPRIORITYR(prio_reg);
		prio_val &= ~(0xffU << prio_off);
		prio_val |=  (0x80U << prio_off);
		GICD_IPRIORITYR(prio_reg) = prio_val;
		GICD_ISENABLER(cn_irq / 32) = 1U << (cn_irq % 32);
	}
	if(bd_irq) {
		prio_reg = bd_irq / 4;
		prio_off = (bd_irq % 4) * 8;
		prio_val = GICD_IPRIORITYR(prio_reg);
		prio_val &= ~(0xffU << prio_off);
		prio_val |=  (0x80U << prio_off);
		GICD_IPRIORITYR(prio_reg) = prio_val;
		GICD_ISENABLER(bd_irq / 32) = 1U << (bd_irq % 32);
	}
	GICD_CTLR = 1;
	GICC_PMR  = 0xff;
	GICC_CTLR = 1;
	cntv_tval_set(timer_reload);
	cntv_ctl_set(1);
	irq_ready = 1;
	irq_enable();
}
