#include "../h/param.h"
#include "../h/systm.h"
#include "../h/dir.h"
#include "../h/user.h"
#include "../h/proc.h"
#include "../h/proto.h"

extern void addupc(caddr_t pc, void *prof, int inc);	/* arch/v7stubs.c stub */
/* wakeup/spl1 come from h/proto.h.  psignal/setpri come from h/systm.h. */

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
	register struct proc *pp;
	int a;
	extern caddr_t waitloc;
	(void)dev; (void)sp; (void)r1; (void)nps; (void)r0;

	/* v7 rearmed the KW11-L by writing 0115 to lks->r[0] and snapshotted
	 * the front-panel switch register via display(); on this port the
	 * timer is rearmed by clock_irq_handler's cntv_tval_set and there is
	 * no front panel, so both calls are gone. */
	/* v7's per-tick callout[] dispatch is gone on this port -- nothing
	 * registers via timeout() so the callout table is permanently empty. */

	/*
	 * if ps is high, just return
	 */
	if (BASEPRI(ps))
		goto out;

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

/* v7's timeout() registered fun(arg) for deferred call after tim/HZ
 * seconds via the callout[] table.  No driver on this port registers
 * timeouts (the v7 callers were in dh.c / kl.c / etc., none of which
 * exist here), so the function and the table are removed. */
