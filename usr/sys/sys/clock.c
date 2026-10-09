#include "../h/param.h"
#include "../h/systm.h"
#include "../h/callo.h"
#include "../h/dir.h"
#include "../h/user.h"
#include "../h/proc.h"
#include "../h/seg.h"
#include "../h/conf.h"

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
clock(dev, sp, r1, nps, r0, pc, ps)
dev_t dev;
caddr_t pc;
int	sp, r1, nps, r0, ps;
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

	spl5();
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
		spl1();
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
timeout(fun, arg, tim)
int (*fun)();
caddr_t arg;
int	tim;
{
	register struct callo *p1, *p2;
	register int t;
	int s;

	t = tim;
	p1 = &callout[0];
	s = spl7();
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
	splx(s);
}
#define GICD_BASE	GIC_DIST_BASE
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
extern struct intr intrtab[];
static unsigned int timer_reload;
int irq_ready;
caddr_t waitloc;	/* pc of the idle wait, for cpu-time accounting */
void addupc(caddr_t pc, void *prof, int inc) { (void)pc; (void)prof; (void)inc; }
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
	} else {
		register struct intr *ip;
		for(ip = intrtab; ip->i_irq; ip++)
			if(*ip->i_irq && intid == (unsigned int)*ip->i_irq)
				(*ip->i_fn)();
	}
	GICC_EOIR = iar;
}
static void
gicen(int irq)
{
	unsigned int r = irq / 4, o = (irq % 4) * 8;
	GICD_IPRIORITYR(r) = (GICD_IPRIORITYR(r) & ~(0xffU << o)) | (0x80U << o);
	GICD_ISENABLER(irq / 32) = 1U << (irq % 32);
}
void
clkstart()
{
	register struct intr *ip;
	if((timer_reload = cntfrq_get() / TIMER_HZ) == 0)
		panic("no clock");
	gicen(TIMER_IRQ);
	for(ip = intrtab; ip->i_irq; ip++)
		if(*ip->i_irq)
			gicen(*ip->i_irq);
	GICD_CTLR = 1;
	GICC_PMR  = 0xff;
	GICC_CTLR = 1;
	cntv_tval_set(timer_reload);
	cntv_ctl_set(1);
	irq_ready = 1;
	spl0();
}
