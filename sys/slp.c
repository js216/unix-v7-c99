#include "../h/param.h"
#include "../h/systm.h"
#include "../h/dir.h"
#include "../h/user.h"
#include "../h/proc.h"
#include "../h/text.h"
#include "../h/map.h"
#include "../h/file.h"
#include "../h/inode.h"
#include "../h/proto.h"

/* spl0/spl6/splx/panic/malloc/mfree/copyseg/save/resume come from h/proto.h.
 * issig comes from h/systm.h. */
extern void sureg(void);
extern void xswap(struct proc *, int, int);

void wakeup(register caddr_t chan);
void setrun(register struct proc *p);
void setrq(struct proc *p);
void swtch(void);
void qswtch(void);

#define SQSIZE 0100	/* Must be power of 2 */
#define HASH(x)	(( (int) x >> 5) & (SQSIZE-1))
struct proc *slpque[SQSIZE];

/*
 * Give up the processor till a wakeup occurs
 * on chan, at which time the process
 * enters the scheduling queue at priority pri.
 * The most important effect of pri is that when
 * pri<=PZERO a signal cannot disturb the sleep;
 * if pri>PZERO signals will be processed.
 * Callers of this routine must be prepared for
 * premature return, and check that the reason for
 * sleeping has gone away.
 */
void
sleep(caddr_t chan, int pri)
{
	register struct proc *rp;
	register int s, h;

	rp = u.u_procp;
	s = spl6();
	if (chan==0)
		panic("zero wchan");
	rp->p_stat = SSLEEP;
	rp->p_wchan = chan;
	if (chan==0)
		panic("Sleeping on wchan 0");
	rp->p_pri = pri;
	h = HASH(chan);
	rp->p_link = slpque[h];
	slpque[h] = rp;
	if(pri > PZERO) {
		if(issig()) {
			rp->p_wchan = 0;
			rp->p_stat = SRUN;
			slpque[h] = rp->p_link;
			spl0();
			goto psig;
		}
		spl0();
		if(runin != 0) {
			runin = 0;
			wakeup((caddr_t)&runin);
		}
		swtch();
		if(issig())
			goto psig;
	} else {
		spl0();
		swtch();
	}
	splx(s);
	return;

	/*
	 * If priority was low (>PZERO) and
	 * there has been a signal,
	 * execute non-local goto to
	 * the qsav location.
	 * (see trap1/trap.c)
	 */
psig:
	resume(u.u_procp->p_addr, u.u_qsav);
}

/*
 * Wake up all processes sleeping on chan.
 */
void
wakeup(register caddr_t chan)
{
	register struct proc *p, *q;
	register int i;
	int s;

	s = spl6();
	i = HASH(chan);
	p = slpque[i];
	q = NULL;
	while(p != NULL) {
		if(p->p_wchan==chan && p->p_stat!=SZOMB) {
			struct proc *sp;

			if (q == NULL)
				sp = slpque[i] = p->p_link;
			else
				sp = q->p_link = p->p_link;
			p->p_wchan = 0;
			setrun(p);
			p = sp;
			continue;
		}
		q = p;
		p = p->p_link;
	}
	splx(s);
}

/* PORT: our scheduler doesn't unlink from v7's runq during swtch, so
 * wakeup()->setrun() races re-add procs already linked.  Silently
 * dedupe instead of printing; functionally a no-op. */
void
setrq(struct proc *p)
{
	register struct proc *q;
	register int s;

	s = spl6();
	for(q=runq; q!=NULL; q=q->p_link)
		if(q == p) goto out;
	p->p_link = runq;
	runq = p;
out:
	splx(s);
}

/*
 * Set the process running;
 * arrange for it to be swapped in if necessary.
 *
 * PORT DIVERGENCE: armboot_setrun(p->p_pid) added so the port's
 * scheduler (which keeps its own armproc_state[] table) sees the
 * wakeup.  Without it, v7's wakeup()->setrun() flips p_stat = SRUN
 * but mt_pick_runnable() never picks the slot because its
 * armproc_state stays PSTATE_SLEEP.  No semantic change to v7's
 * state machine; just a cross-side notify.
 */
/* armboot_setrun declared in h/proto.h. */

void
setrun(register struct proc *p)
{
	register caddr_t w;

	if (p->p_stat==0 || p->p_stat==SZOMB)
		panic("Running a dead proc");
	/*
	 * The assignment to w is necessary because of
	 * race conditions. (Interrupt between test and use)
	 */
	if ((w = p->p_wchan)) {
		wakeup(w);
		return;
	}
	p->p_stat = SRUN;
	setrq(p);
	armboot_setrun((int)p->p_pid);
	if(p->p_pri < curpri)
		runrun++;
	if(runout != 0 && (p->p_flag&SLOAD) == 0) {
		runout = 0;
		wakeup((caddr_t)&runout);
	}
}

/*
 * Set user priority.
 * The rescheduling flag (runrun)
 * is set if the priority is better
 * than the currently running process.
 */
int
setpri(register struct proc *pp)
{
	register int p;

	p = (pp->p_cpu & 0377)/16;
	p += PUSER + pp->p_nice - NZERO;
	if(p > 127)
		p = 127;
	if(p < curpri)
		runrun++;
	pp->p_pri = p;
	return(p);
}

/* v7's sched() main loop (the proc-0 "swapper" task) and its swapin()
 * helper drove the per-process swap-in/swap-out cycle.  This port keeps
 * every proc resident, so neither runs -- the C scheduler is in
 * armboot_swtch() (see swtch() below). */

/*
 * put the current process on
 * the Q of running processes and
 * call the scheduler.
 */
void
qswtch(void)
{

	setrq(u.u_procp);
	swtch();
}

/*
 * This routine is called to reschedule the CPU.
 *
 * PORT DIVERGENCE (documented in logs/unix-on-qemu.md): the original
 * v7 body walked `runq` (a linked list of SRUN procs), picked the
 * lowest p_pri, called save(u.u_rsav) on the current process, and
 * resume()'d into the picked one -- with idle() / proc 0 swapper
 * dance for the no-runnable case.  That model assumes per-proc u-
 * areas swapped in/out of core by an external swapper, which this
 * port does not have.  Instead we keep every proc's u-area + kernel
 * stack permanently in RAM (the save-slot pool in arch/armboot.c),
 * and the equivalent save+pick+resume sequence lives in
 * armboot_swtch().  Routing through it here means v7's
 * sleep()/wakeup()/setrun()/exit()/wait()/pause() in this TU and
 * sys/sys1.c / sys/sys4.c / sys/pipe.c work unchanged.
 */
/* armboot_swtch declared in h/proto.h. */

void
swtch(void)
{
	armboot_swtch();
}

/*
 * Create a new process-- the internal version of
 * sys fork.
 * It returns 1 in the new process, 0 in the old.
 */
/* v7 newproc() (alloc proc[] slot, copy parent's image into child) is
 * gone -- fork(2) routes through arch/armboot.c::mt_alloc_slot, which
 * maintains armproc[NSLOTS] in parallel with proc[NPROC]; the child's
 * register state is duplicated by the trap frame copy, not by save()/
 * resume() over the v7 u_ssav. */

/*
 * Change the size of the data+stack regions of the process.
 * If the size is shrinking, it's easy-- just release the extra core.
 * If it's growing, and there is core, just allocate it
 * and copy the image, taking care to reset registers to account
 * for the fact that the system's stack has moved.
 * If there is no core, arrange for the process to be swapped
 * out after adjusting the size requirement-- when it comes
 * in, enough core will be allocated.
 *
 * After the expansion, the caller will take care of copying
 * the user's stack towards or away from the data area.
 */
void
expand(int newsize)
{
	register int i, n;
	register struct proc *p;
	register int a1, a2;

	p = u.u_procp;
	n = p->p_size;
	p->p_size = newsize;
	a1 = p->p_addr;
	if(n >= newsize) {
		mfree(coremap, n-newsize, a1+newsize);
		return;
	}
	if (save(u.u_ssav)) {
		sureg();
		return;
	}
	a2 = malloc(coremap, newsize);
	if(a2 == NULL) {
		xswap(p, 1, n);
		qswtch();
		/* no return */
	}
	p->p_addr = a2;
	for(i=0; i<n; i++)
		copyseg(a1+i, a2+i);
	mfree(coremap, n, a1);
	resume(a2, u.u_ssav);
}
