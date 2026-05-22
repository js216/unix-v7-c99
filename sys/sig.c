#include "../h/param.h"
#include "../h/systm.h"
#include "../h/dir.h"
#include "../h/user.h"
#include "../h/proc.h"
#include "../h/proto.h"

/* setrun comes from h/systm.h.  wakeup/sleep come from h/proto.h. */

int fsig(struct proc *p);
void psignal(struct proc *p, int sig);

/*
 * Priority for tracing
 */
#define	IPCPRI	PZERO

/*
 * Tracing variables.
 * Used to pass trace command from
 * parent to child being traced.
 * This data base cannot be
 * shared and is locked
 * per user.
 */
struct
{
	int	ip_lock;
	int	ip_req;
	int	*ip_addr;
	int	ip_data;
} ipc;

/* v7's signal(pgrp, sig) (broadcast sig to every proc in pgrp) is gone
 * -- its only caller was sys/tty.c (the v7 line-discipline interrupt
 * path), which this port doesn't compile.  sys/v7_bridge.c has its own
 * v7_signal_pgrp that walks armproc[] instead of proc[]. */

/*
 * Send the specified signal to
 * the specified process.
 */
void
psignal(register struct proc *p, register int sig)
{

	if((unsigned)sig >= NSIG)
		return;
	if(sig)
		p->p_sig |= 1<<(sig-1);
	if(p->p_pri > PUSER)
		p->p_pri = PUSER;
	if(p->p_stat == SSLEEP && p->p_pri > PZERO)
		setrun(p);
}

/*
 * Returns true if the current
 * process has a signal to process.
 * This is asked at least once
 * each time a process enters the
 * system.
 * A signal does not do anything
 * directly to a process; it sets
 * a flag that asks the process to
 * do something to itself.
 */
int
issig(void)
{
	register int n;
	register struct proc *p;

	p = u.u_procp;
	while(p->p_sig) {
		n = fsig(p);
		if((u.u_signal[n]&1) == 0 || (p->p_flag&STRC))
			return(n);
		p->p_sig &= ~(1<<(n-1));
	}
	return(0);
}

/* v7's stop() (enter SSTOP, signal parent, wait for procxmt cmd) and
 * its co-routine procxmt() (parent ptrace command dispatcher) were
 * driven by psig(); removed alongside it on this port. */

/* The v7 issig()/psig() pair handled signal delivery during trap return.
 * On this port deliver_signal() in arch/arm.c does it inline so
 * psig() is never called from C; the resume(u_qsav) path in slp.c's
 * sleep() loop still uses its own local `psig:` label for the
 * longjmp-back-on-signal idiom. */

/*
 * find the signal in bit-position
 * representation in p_sig.
 */
int
fsig(struct proc *p)
{
	register int n, i;

	n = p->p_sig;
	for(i=1; i<NSIG; i++) {
		if(n & 1)
			return(i);
		n >>= 1;
	}
	return(0);
}

/* v7's core() wrote a process's u-area + data + stack to ./core on a
 * fatal signal.  Called from psig(); removed alongside it. */

/*
 * sys-trace system call.
 *
 * v7's PDP-11 libc/sys/ptrace.s shuffled C args -- it copied req, pid,
 * addr into trailing-word indirect slots and put data in r0 -- so the
 * kernel's struct a came out (data, pid, addr, req).  On this ARM port
 * the SYS macro passes args straight in r0..r3, so u.u_arg[0..3] is
 * (req, pid, addr, data) -- the natural C order.  Match that here.
 */
void
ptrace(void)
{
	register struct proc *p;
	register struct a {
		int	req;
		int	pid;
		int	*addr;
		int	data;
	} *uap;

	uap = (struct a *)u.u_ap;
	if (uap->req <= 0) {
		u.u_procp->p_flag |= STRC;
		return;
	}
	for (p=proc; p < &proc[NPROC]; p++)
		if (p->p_stat==SSTOP
		 && p->p_pid==uap->pid
		 && p->p_ppid==u.u_procp->p_pid)
			goto found;
	u.u_error = ESRCH;
	return;

    found:
	while (ipc.ip_lock)
		sleep((caddr_t)&ipc, IPCPRI);
	ipc.ip_lock = p->p_pid;
	ipc.ip_data = uap->data;
	ipc.ip_addr = uap->addr;
	ipc.ip_req = uap->req;
	p->p_flag &= ~SWTED;
	setrun(p);
	while (ipc.ip_req > 0)
		sleep((caddr_t)&ipc, IPCPRI);
	u.u_r.r_val1 = ipc.ip_data;
	if (ipc.ip_req < 0)
		u.u_error = EIO;
	ipc.ip_lock = 0;
	wakeup((caddr_t)&ipc);
}

/* procxmt() removed -- see comment above. */
