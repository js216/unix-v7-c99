#include "../h/param.h"
#include "../h/systm.h"
#include "../h/dir.h"
#include "../h/user.h"
#include "../h/proc.h"
#include "../h/text.h"
#include "../h/map.h"
#include "../h/file.h"
#include "../h/inode.h"
#include "../h/buf.h"
#include "../h/seg.h"
void sleep(caddr_t chan, int pri);
void wakeup(register caddr_t chan);
void setrun(register struct proc *p);
void setrq(struct proc *p);
void sched(void);
int swapin(register struct proc *p);
void swtch(void);
void qswtch(void);
int spl0(void);
int spl6(void);
void splx(int s);
void panic(char *s);
void printf(char *fmt, ...);
int save(int *lp) __attribute__((returns_twice));
void resume(int addr, int *lp);
int malloc(struct map *mp, int size);
void mfree(struct map *mp, int size, int a);
void xswap(register struct proc *p, int ff, int os);
void xlock(register struct text *xp);
void xunlock(register struct text *xp);
void swap(daddr_t blkno, int coreaddr, int count, int rdflg);
void sureg(void);
void copyseg(int from, int to);
void arm_setrun(int pid);
void arm_swtch(void);
void return_frame(int *r);
int mt_alloc_slot(int pid, int ppid, int state);
int slot_by_pid(int pid);
void usermap(int slot);
void arm_sync_icache(void);
void proc_core(register struct proc *p, int slot);
struct proc *proc_by_pid(int pid);
#define	PSTATE_LIVE	1
extern int live_slot;

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

/*
 * when you are sure that it
 * is impossible to get the
 * 'proc on q' diagnostic, the
 * diagnostic loop can be removed.
 */
void
setrq(struct proc *p)
{
	register struct proc *q;
	register int s;

	s = spl6();
	for(q=runq; q!=NULL; q=q->p_link)
		if(q == p)
			goto out;
	p->p_link = runq;
	runq = p;
out:
	splx(s);
}

/*
 * Set the process running;
 * arrange for it to be swapped in if necessary.
 */
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
	arm_setrun((int)p->p_pid);
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

/*
 * The main loop of the scheduling (swapping)
 * process.
 * The basic idea is:
 *  see if anyone wants to be swapped in;
 *  swap out processes until there is room;
 *  swap him in;
 *  repeat.
 * The runout flag is set whenever someone is swapped out.
 * Sched sleeps on it awaiting work.
 *
 * Sched sleeps on runin whenever it cannot find enough
 * core (by swapping out or otherwise) to fit the
 * selected swapped process.  It is awakened when the
 * core situation changes and in any case once per second.
 */
void
sched(void)
{
	register struct proc *rp, *p;
	register int outage, inage;
	int maxsize;

	/*
	 * find user to swap in;
	 * of users ready, select one out longest
	 */

loop:
	spl6();
	outage = -20000;
	for (rp = &proc[0]; rp < &proc[NPROC]; rp++)
	if (rp->p_stat==SRUN && (rp->p_flag&SLOAD)==0 &&
	    rp->p_time - (rp->p_nice-NZERO)*8 > outage) {
		p = rp;
		outage = rp->p_time - (rp->p_nice-NZERO)*8;
	}
	/*
	 * If there is no one there, wait.
	 */
	if (outage == -20000) {
		runout++;
		sleep((caddr_t)&runout, PSWP);
		goto loop;
	}
	spl0();

	/*
	 * See if there is core for that process;
	 * if so, swap it in.
	 */

	if (swapin(p))
		goto loop;

	/*
	 * none found.
	 * look around for core.
	 * Select the largest of those sleeping
	 * at bad priority; if none, select the oldest.
	 */

	spl6();
	p = NULL;
	maxsize = -1;
	inage = -1;
	for (rp = &proc[0]; rp < &proc[NPROC]; rp++) {
		if (rp->p_stat==SZOMB
		 || (rp->p_flag&(SSYS|SLOCK|SULOCK|SLOAD))!=SLOAD)
			continue;
		if (rp->p_textp && (rp->p_textp->x_flag&XLOCK))
			continue;
		if ((rp->p_stat==SSLEEP&&rp->p_pri>=PZERO) || rp->p_stat==SSTOP) {
			if (maxsize < rp->p_size) {
				p = rp;
				maxsize = rp->p_size;
			}
		} else if (maxsize<0 && (rp->p_stat==SRUN||rp->p_stat==SSLEEP)) {
			if (rp->p_time+rp->p_nice-NZERO > inage) {
				p = rp;
				inage = rp->p_time+rp->p_nice-NZERO;
			}
		}
	}
	spl0();
	/*
	 * Swap found user out if sleeping at bad pri,
	 * or if he has spent at least 2 seconds in core and
	 * the swapped-out process has spent at least 3 seconds out.
	 * Otherwise wait a bit and try again.
	 */
	if (maxsize>=0 || (outage>=3 && inage>=2)) {
		p->p_flag &= ~SLOAD;
		xswap(p, 1, 0);
		goto loop;
	}
	spl6();
	runin++;
	sleep((caddr_t)&runin, PSWP);
	goto loop;
}

/*
 * Swap a process in.
 * Allocate data and possible text separately.
 * It would be better to do largest first.
 */
int
swapin(register struct proc *p)
{
	register struct text *xp;
	register int a;
	int x;

	if ((a = malloc(coremap, p->p_size)) == NULL)
		return(0);
	if ((xp = p->p_textp)) {
		xlock(xp);
		if (xp->x_ccount==0) {
			if ((x = malloc(coremap, xp->x_size)) == NULL) {
				xunlock(xp);
				mfree(coremap, p->p_size, a);
				return(0);
			}
			xp->x_caddr = x;
			if ((xp->x_flag&XLOAD)==0)
				swap(xp->x_daddr,x,xp->x_size,B_READ);
		}
		xp->x_ccount++;
		xunlock(xp);
	}
	swap(p->p_addr, a, p->p_size, B_READ);
	mfree(swapmap, ctod(p->p_size), p->p_addr);
	p->p_addr = a;
	p->p_flag |= SLOAD;
	p->p_time = 0;
	return(1);
}

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
 * if the calling process is not in RUN state,
 * arrangements for it to restart must have
 * been made elsewhere, usually by calling via sleep.
 * There is a race here. A process may become
 * ready after it has been examined.
 * In this case, idle() will be called and
 * will return in at most 1HZ time.
 * i.e. its not worth putting an spl() in.
 */
void
swtch(void)
{

	arm_swtch();
}

/*
 * Create a new process-- the internal version of
 * sys fork.
 * It returns 1 in the new process, 0 in the old.
 */
int
newproc(void)
{

	if(u.u_procp == &proc[0])
		return(1);

	u.u_error = EAGAIN;



	return(0);
}

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
static void
proc_anchor(int i, short pid, short pgrp, char pri)
{
	struct proc *p;
	p = &proc[i];
	p->p_stat = SRUN;
	p->p_flag = SLOAD;
	p->p_pid = pid;
	p->p_ppid = 0;
	p->p_uid = 0;
	p->p_pgrp = pgrp;
	p->p_pri = pri;
	p->p_nice = NZERO;
	p->p_sig = p->p_time = p->p_cpu = p->p_clktim = 0;
}
void
v7_proc_init(void)
{
	int slot;
	proc_anchor(0, 0, 0, 0);
	proc_anchor(1, 1, 1, 40);
	slot = mt_alloc_slot(1, 0, PSTATE_LIVE);
	if(slot < 0)
		panic("procinit");
	live_slot = slot;
	usermap(slot);
	proc_core(&proc[1], slot);
	proc[1].p_size = (short)(UARGLEN >> 6);
	u.u_procp = &proc[1];
}
int
v7_proc_fork(int parent_pid, int child_pid)
{
	struct proc *pp;
	short parent_pgrp, parent_nice, parent_uid, parent_size;
	int slot, i;
	pp = proc_by_pid(parent_pid);
	parent_pgrp = pp ? pp->p_pgrp : (short)child_pid;
	parent_nice = pp ? pp->p_nice : NZERO;
	parent_uid = pp ? pp->p_uid : 0;
	parent_size = pp ? pp->p_size : (short)(UARGLEN >> 6);
	slot = slot_by_pid(child_pid);
	for(i = 2; i < NPROC; i++)
		if(proc[i].p_stat == 0)
			break;
	if(i >= NPROC)
		return(-1);
	pp = &proc[i];
	pp->p_stat = SRUN;
	pp->p_flag = SLOAD;
	pp->p_pri = 40;
	pp->p_nice = parent_nice;
	pp->p_uid = parent_uid;
	pp->p_pgrp = parent_pgrp;
	pp->p_pid = (short)child_pid;
	pp->p_ppid = (short)parent_pid;
	pp->p_time = pp->p_cpu = pp->p_sig = pp->p_clktim = 0;
	pp->p_size = parent_size;
	pp->p_wchan = 0;
	proc_core(pp, slot);
	pp->p_textp = NULL;
	pp->p_link = NULL;
	return(0);
}
void
v7_proc_exit(int curpid, int code)
{
	struct proc *pp;
	pp = proc_by_pid(curpid);
	if(pp) {
		pp->p_stat = SZOMB;
		pp->p_clktim = code;
		pp->p_sig = 0;
	}
}
void
v7_proc_reap(int pid)
{
	struct proc *p;
	int i;
	for(i = 0; i < NPROC; i++)
		if(proc[i].p_stat == SZOMB && proc[i].p_pid == (short)pid) {
			p = &proc[i];
			p->p_stat = p->p_flag = 0;
			p->p_pid = p->p_ppid = p->p_pgrp = 0;
			p->p_uid = p->p_sig = p->p_clktim = 0;
			return;
		}
}
int
v7_wait_check(int parent_pid, int *status)
{
	int i, code, pid;
	for(i = 1; i < NPROC; i++)
		if(proc[i].p_stat == SZOMB &&
		   proc[i].p_ppid == (short)parent_pid) {
			code = proc[i].p_clktim;
			pid = proc[i].p_pid;
			if(status)
				*status = (code & 0x100) ? (code & 0x7f)
				    : ((code & 0xff) << 8);
			v7_proc_reap(pid);
			return(pid);
		}
	return(-1);
}
void
v7_proc_set_current(int pid)
{
	struct proc *me;
	me = proc_by_pid(pid);
	if(me) {
		proc_core(me, slot_by_pid(pid));
		u.u_procp = me;
	} else
		u.u_procp = &proc[1];
}
int
v7_get_ppid(int pid)
{
	struct proc *pp;
	pp = proc_by_pid(pid);
	return(pp ? (int)pp->p_ppid : -1);
}
int
v7_proc_alive(int pid)
{
	struct proc *pp;
	pp = proc_by_pid(pid);
	return(pp && pp->p_stat != SZOMB);
}
int
v7_proc_set_stat(int pid, int stat)
{
	struct proc *pp;
	pp = proc_by_pid(pid);
	if(pp == NULL || pp == &proc[0] || pp->p_stat == SZOMB)
		return(-1);
	pp->p_stat = (char)stat;
	return(0);
}
void
v7_reparent_children(int dying_pid, int new_ppid)
{
	int i;
	for(i = 0; i < NPROC; i++)
		if(proc[i].p_stat != 0 && proc[i].p_ppid == (short)dying_pid)
			proc[i].p_ppid = (short)new_ppid;
}
extern unsigned int l1[4096];
void sysent_dispatch(int n, int *r);
void run_user(unsigned int pc, unsigned int sp);
void v7_call_prep(int *args);
void putchar(char c);
void v7_proc_reap(int pid);
void v7_reparent_children(int dying_pid, int new_ppid);
int v7_wait_check(int parent_pid, int *status);
int v7_get_ppid(int pid);
int v7_proc_alive(int pid);
int v7_proc_set_stat(int pid, int stat);
int v7_proc_fork(int parent_pid, int child_pid);
void v7_proc_exit(int curpid, int code);
int v7_kill_call(int *args, int kuid, int curpid);
int v7_signal_call(int signo, int func, int curpid);
int v7_sigreturn_call(int *r);
void v7_inode_drop(void *p);
void v7_u_times_save(long *ut, long *st, long *cut, long *cst);
void v7_u_times_restore(long ut, long st, long cut, long cst);
void v7_u_times_snapshot(long *utp, long *stp);
void v7_u_times_add_child(long ut, long st);
void v7_u_signal_save(long *sig);
void v7_u_signal_restore(const long *sig);
void v7_u_qsav_save(int *dst);
void v7_u_qsav_restore(const int *src);
void install_sigtramp(char *base);
void *v7_cdir_save(void);
void *v7_rdir_save(void);
void v7_cdir_restore(void *p);
void v7_rdir_restore(void *p);
void v7_ofile_save(void *buf);
void v7_ofile_restore(void *buf);
void v7_pofile_save(void *buf);
void v7_pofile_restore(void *buf);
void v7_ofile_fork_bump(void);
void v7_ofile_drop_all(void);
void acct(void);
struct kuser {
	int u_arg[6], u_error, u_rval1, u_rval2, u_segflg;
};
extern struct kuser ku;
extern int *trap_frame;
#define S_EXIT		1
#define S_FORK		2
#define S_WAIT		7
#define S_SIGNAL	48
#define S_SIGRETURN	139
#define	SIG_DFL		0L
#define	SIG_IGN		1L
static void kdone(int pid, int ppid, int code);
static int childdone_remove(int i, int *codep);
static int kwait(int ppid, int *statp);
int v7_pause_call(volatile unsigned int *pending_ptr);
void do_exit(int code, int *r);
volatile int in_spin_wait;
static int
user_range(caddr_t a, unsigned int n)
{
	unsigned int p;

	p = (unsigned int)a;
	return(p + n >= p && p + n <= USERSIZE);
}
int fubyte(caddr_t addr) { if(!user_range(addr, 1)) return(-1); return *(unsigned char *)addr; }
int subyte(caddr_t addr, char c) { if(!user_range(addr, 1)) return(-1); *(unsigned char *)addr = c; return 0; }
int fuword(caddr_t addr) { if(!user_range(addr, sizeof(int))) return(-1); return *(int *)addr; }
int suword(caddr_t addr, int v) { if(!user_range(addr, sizeof(int))) return(-1); *(int *)addr = v; return 0; }
int copyin(caddr_t f, caddr_t t, unsigned int n) { if(!user_range(f, n)) return(-1); while(n--) *t++ = *f++; return 0; }
int copyout(caddr_t f, caddr_t t, unsigned int n) { if(!user_range(t, n)) return(-1); while(n--) *t++ = *f++; return 0; }
void mapfree(struct buf *bp) { bp->b_flags &= ~B_MAP; }
char regloc[9];
caddr_t waitloc;
void addupc(caddr_t pc, void *prof, int inc) { (void)pc; (void)prof; (void)inc; }
void pause_spin_barrier(void)
{
	putchar('\b');
	__asm__ volatile("dmb ish" ::: "memory");
}
static void clocked_spin_barrier(void)
{
	in_spin_wait = 1;
	__asm__ volatile("cpsie i\n\twfi\n\tcpsid i" ::: "memory");
	in_spin_wait = 0;
}
static struct childent {
	int pid, ppid, exitval;
	long utime, stime;
} childdone[NOFILE];
static int ndone, nextpid = 2;
int curpid = 1;
#define	NPROCSAVE	32
#define	PROC_CORE_CLICK	1024
#define	PROC_CORE_BYTES	(PROC_CORE_CLICK << 6)
#define	PROC_SLOT_BYTES	0x100000
#define	V7_STACK_TOP	0x10000U
#define	KSTACK_SIZE	8192
#define	PSTATE_FREE	0
#define	PSTATE_LIVE	1
#define	PSTATE_RUN	2
#define	PSTATE_SLEEP	3
#define	PSTATE_ZOMBIE	4
static struct armproc {
	int frame[17];
	void *ofile[20];
	char pofile[20];
	void *cdir, *rdir;
	long handlers[NSIG+1];
	unsigned int pending;
	int uid, gid, pid, inuse;
	long utime, stime, cutime, cstime, usignal[NSIG+1];
	int umask;
	struct user uarea;
	unsigned char kstack[KSTACK_SIZE] __attribute__((aligned(16)))
	    __attribute__((unused));
	unsigned int ksp, kstackn;
	int rsav[10], qsav[10];
	int state, ppid, exitcode, wait_for;
} armproc[NPROCSAVE];
unsigned char usermem[NPROCSAVE][PROC_SLOT_BYTES]
    __attribute__((aligned(0x100000)));
int live_slot = -1;
int slot_by_pid(int pid)
{
	for(int i = 0; i < NPROCSAVE; i++)
		if(armproc[i].inuse && armproc[i].state != PSTATE_FREE &&
		   armproc[i].pid == pid)
			return i;
	return -1;
}
int mt_alloc_slot(int pid, int ppid, int state)
{
	for(int i = 0; i < NPROCSAVE; i++)
		if(!armproc[i].inuse) {
			struct armproc *a = &armproc[i];
			a->inuse = 1; a->pid = pid; a->ppid = ppid;
			a->state = state; a->exitcode = 0; a->wait_for = -1;
			return i;
		}
	return -1;
}
static int mt_save_slot(int pid, int ppid, int state)
{
	if(live_slot >= 0 && armproc[live_slot].pid == pid)
		return live_slot;
	return mt_alloc_slot(pid, ppid, state);
}
void usermap(int slot)
{
	unsigned int pa;
	if(slot < 0 || slot >= NPROCSAVE)
		return;
	pa = (unsigned int)usermem[slot];
	l1[0] = (pa & 0xfff00000U) | 0x00000c02U;
	__asm__ volatile(
	    "dsb ishst\n\t"
	    "mcr p15, 0, %0, c8, c7, 0\n\t"
	    "dsb ish\n\t"
	    "isb"
	    :
	    : "r"(0)
	    : "memory");
	arm_sync_icache();
}
void proc_core(register struct proc *p, int slot)
{
	if(p == NULL || slot < 0 || slot >= NPROCSAVE)
		return;
	p->p_addr = (short)(slot * PROC_CORE_CLICK);
}
void arm_sureg(int *uisa, int *uisd, int nseg)
{
	int slot, i;
	slot = -1;
	for(i = 0; i < nseg; i++) {
		if(uisd[i] == 0 || (uisd[i] & TX) || (uisd[i] & ABS))
			continue;
		slot = uisa[i] / PROC_CORE_CLICK;
		break;
	}
	if(slot < 0)
		for(i = 0; i < nseg; i++) {
			if(uisd[i] == 0 || (uisd[i] & ABS))
				continue;
			slot = uisa[i] / PROC_CORE_CLICK;
			break;
		}
	if(slot < 0 && u.u_procp != NULL)
		slot = u.u_procp->p_addr / PROC_CORE_CLICK;
	if(slot < 0)
		slot = slot_by_pid(curpid);
	if(slot < 0 || slot >= NPROCSAVE || !armproc[slot].inuse)
		return;
	usermap(slot);
	live_slot = slot;
	proc_core(u.u_procp, slot);
}
static void bzero(char *, unsigned int);
static void proc_drop_slot_refs(struct armproc *a)
{
	if(a->cdir != NULL) {
		v7_inode_drop(a->cdir);
		a->cdir = NULL;
	}
	if(a->rdir != NULL) {
		v7_inode_drop(a->rdir);
		a->rdir = NULL;
	}
}
static void proc_free_slot(int slot)
{
	struct armproc *a;
	if(slot < 0 || slot >= NPROCSAVE) return;
	a = &armproc[slot];
	proc_drop_slot_refs(a);
	bzero((char *)a, sizeof(*a));
	a->state = PSTATE_FREE;
	a->wait_for = -1;
}
void bcopy(char *, char *, unsigned int);
struct proc *proc_by_pid(int pid);
long handlers[NSIG+1];
unsigned int pending;
int kuid, kgid, kumask;
static int mt_switched;
void
arm_exec_reset_signals(void)
{
	int i, slot;

	for(i = 1; i <= NSIG; i++)
		if(handlers[i] != SIG_IGN)
			handlers[i] = SIG_DFL;
	slot = live_slot >= 0 ? live_slot : slot_by_pid(curpid);
	if(slot >= 0)
		bcopy((char *)handlers, (char *)armproc[slot].handlers,
		    sizeof(handlers));
}
static int sig_deliverable(unsigned int mask)
{
	for(int s = 1; s <= NSIG; s++)
		if((mask & (1U << s)) && handlers[s] != 1L)
			return 1;
	return 0;
}
static int pstate_to_pstat(int pstate)
{
	switch(pstate) {
	case PSTATE_RUN:	return SRUN;
	case PSTATE_SLEEP:	return SSLEEP;
	case PSTATE_ZOMBIE:	return SZOMB;
	default:		return 0;
	}
}
static void mt_save_current(int slot, int *r, int state)
{
	struct armproc *a = &armproc[slot];
	int pstat;
	proc_drop_slot_refs(a);
	bcopy((char *)USERBASE, (char *)usermem[slot], USERSIZE);
	bcopy((char *)r,        (char *)a->frame,  sizeof(a->frame));
	bcopy((char *)handlers, (char *)a->handlers, sizeof(handlers));
	v7_ofile_save(a->ofile);
	v7_pofile_save(a->pofile);
	a->cdir = v7_cdir_save();
	a->rdir = v7_rdir_save();
	a->pending = pending;
	a->uid = kuid;
	a->gid = kgid;
	a->pid = curpid;
	a->state = state;
	a->umask = kumask;
	a->ksp = 0;
	a->kstackn = 0;
	bcopy((char *)&u, (char *)&a->uarea, sizeof(u));
	pstat = pstate_to_pstat(state);
	if(pstat) (void)v7_proc_set_stat(curpid, pstat);
	proc_core(proc_by_pid(curpid), slot);
	v7_u_times_save(&a->utime, &a->stime, &a->cutime, &a->cstime);
	v7_u_signal_save(a->usignal);
	v7_u_qsav_save(a->qsav);
}
static void mt_load_slot(int slot, int *r)
{
	struct armproc *a = &armproc[slot];
	void *oldcdir, *oldrdir;
	usermap(slot);
	live_slot = slot;
	bcopy((char *)a->frame,    (char *)r,        sizeof(a->frame));
	bcopy((char *)a->handlers, (char *)handlers, sizeof(handlers));
	pending = a->pending;
	kuid = a->uid;
	kgid = a->gid;
	curpid = a->pid;
	kumask = a->umask;
	oldcdir = u.u_cdir;
	oldrdir = u.u_rdir;
	bcopy((char *)&a->uarea, (char *)&u, sizeof(u));
	u.u_cdir = oldcdir;
	u.u_rdir = oldrdir;
	v7_ofile_restore(a->ofile);
	v7_pofile_restore(a->pofile);
	v7_cdir_restore(a->cdir);
	v7_rdir_restore(a->rdir);
	a->cdir = NULL;
	a->rdir = NULL;
	v7_proc_set_current(curpid);
	(void)v7_proc_set_stat(curpid, SRUN);
	v7_proc_set_current(curpid);
	v7_u_times_restore(a->utime, a->stime, a->cutime, a->cstime);
	v7_u_signal_restore(a->usignal);
	v7_u_qsav_restore(a->qsav);
	a->state = PSTATE_LIVE;
}
static int mt_pick_runnable(void)
{
	int best = -1, best_pri = 128;
	for(int i = 0; i < NPROCSAVE; i++) {
		int nice_val = NZERO;
		if(!armproc[i].inuse || armproc[i].state != PSTATE_RUN) continue;
		for(int k = 0; k < NPROC; k++)
			if(proc[k].p_stat != 0 &&
			   proc[k].p_pid == (short)armproc[i].pid) {
				nice_val = proc[k].p_nice;
				break;
			}
		if(best < 0 || nice_val < best_pri) {
			best = i;
			best_pri = nice_val;
		}
	}
	return best;
}
static int mt_pick_child(int ppid)
{
	for(int i = 0; i < NPROCSAVE; i++)
		if(armproc[i].inuse && armproc[i].state == PSTATE_RUN &&
		   armproc[i].ppid == ppid)
			return i;
	return -1;
}
static int mt_wake_waiters(int child_pid, int ppid)
{
	for(int i = 0; i < NPROCSAVE; i++) {
		if(!armproc[i].inuse || armproc[i].state != PSTATE_SLEEP) continue;
		if(armproc[i].pid != ppid) continue;
		if(armproc[i].wait_for != -1 && armproc[i].wait_for != child_pid)
			continue;
		armproc[i].state    = PSTATE_RUN;
		armproc[i].wait_for = -1;
		return i;
	}
	return -1;
}
void arm_setrun(int pid)
{
	for(int i = 0; i < NPROCSAVE; i++)
		if(armproc[i].inuse &&
		   (armproc[i].state == PSTATE_SLEEP ||
		    (armproc[i].state == PSTATE_LIVE && i != live_slot)) &&
		   armproc[i].pid == pid) {
			armproc[i].state    = PSTATE_RUN;
			armproc[i].wait_for = -1;
			return;
		}
}
static int mt_clock_ticks;
static volatile int mt_need_resched;
#define	MT_PREEMPT_TICKS	10
static void psig_drain(int pid, unsigned int *dst)
{
	for(int k = 0; k < NPROC; k++) {
		struct proc *pp = &proc[k];
		if(pp->p_stat == 0 || pp->p_pid != (short)pid) continue;
		if(pp->p_sig != 0) {
			unsigned int psig = (unsigned int)pp->p_sig;
			for(int s = 1; s <= NSIG; s++)
				if(psig & (1U << (s - 1))) *dst |= 1U << s;
			pp->p_sig = 0;
		}
		return;
	}
}
void mt_clock_tick(void)
{
	for(int i = 0; i < NPROCSAVE; i++) {
		struct armproc *a = &armproc[i];
		if(!a->inuse || a->state == PSTATE_FREE) continue;
		if(a->state == PSTATE_LIVE || i == live_slot) {
			psig_drain(a->pid, &pending);
			continue;
		}
		psig_drain(a->pid, &a->pending);
		if(a->state == PSTATE_SLEEP && a->pending != 0) {
			int wake = 0;
			for(int s = 1; s <= NSIG; s++)
				if((a->pending & (1U << s)) && a->handlers[s] != 1L) {
					wake = 1; break;
				}
			if(wake) {
				a->state    = PSTATE_RUN;
				a->wait_for = -1;
			}
		}
	}
	if(++mt_clock_ticks >= MT_PREEMPT_TICKS)
		mt_clock_ticks = 0;
}
static int mt_preempt(int *r)
{
	int next, my_slot, ppid;
	if(!mt_need_resched) return 0;
	mt_need_resched = 0;
	if((next = mt_pick_runnable()) < 0) return 0;
	ppid = v7_get_ppid(curpid);
	if(ppid < 0) ppid = 1;
	if((my_slot = mt_save_slot(curpid, ppid, PSTATE_RUN)) < 0)
		return 0;
	mt_save_current(my_slot, r, PSTATE_RUN);
	mt_load_slot(next, r);
	return 1;
}
static int *trap_r;
extern char stack_top[];
static unsigned int
arm_sp(void)
{
	unsigned int sp;
	__asm__ volatile("mov %0, sp" : "=r"(sp));
	return(sp);
}
static void
kstack_save(struct armproc *a)
{
	unsigned int sp, top, n;
	sp = arm_sp();
	top = (unsigned int)stack_top;
	if(sp > top)
		panic("kstack");
	n = top - sp;
	if(n > KSTACK_SIZE)
		panic("kstack");
	a->ksp = sp;
	a->kstackn = n;
	if(n != 0)
		bcopy((char *)sp, (char *)a->kstack + KSTACK_SIZE - n, n);
}
static void
kstack_restore(struct armproc *a)
{
	if(a->kstackn != 0)
		bcopy((char *)a->kstack + KSTACK_SIZE - a->kstackn,
		    (char *)a->ksp, a->kstackn);
}
void arm_swtch(void)
{
	int my_slot, next;
	int ppid = v7_get_ppid(curpid);
	if(ppid < 0) ppid = 1;
	if((my_slot = mt_save_slot(curpid, ppid, PSTATE_SLEEP)) < 0)
		return;
	if(save(armproc[my_slot].rsav))
		return;
	mt_save_current(my_slot, trap_r, PSTATE_SLEEP);
	kstack_save(&armproc[my_slot]);
	armproc[my_slot].wait_for = -1;
	if((next = mt_pick_runnable()) < 0) {
		if(my_slot == live_slot)
			armproc[my_slot].state = PSTATE_LIVE;
		else
			proc_free_slot(my_slot);
		return;
	}
	mt_load_slot(next, trap_r);
	if(armproc[next].ksp == 0)
		return_frame(trap_r);
	kstack_restore(&armproc[next]);
	armproc[next].ksp = 0;
	armproc[next].kstackn = 0;
	resume(0, armproc[next].rsav);
	panic("swtch: resume returned");
}
static long ksignal(int sig, long fun)
{
	long old;
	if(sig <= 0 || sig >= NSIG || sig == SIGKIL) return -1;
	old = handlers[sig];
	handlers[sig] = fun;
	return old;
}
void arm_sigreturn(int *r)
{
	unsigned int sp = (unsigned int)r[13];
	r[15] = (int)*(volatile unsigned int *)sp;
	r[0]  = (int)*(volatile unsigned int *)(sp + 4);
	r[14] = (int)*(volatile unsigned int *)(sp + 8);
	r[13] = (int)(sp + 12);
}
static void deliver_signal(int *r)
{
	long h;
	unsigned int sp;
	psig_drain(curpid, &pending);
	if(pending == 0) return;
	for(int sig = 1; sig <= NSIG; sig++) {
		if((pending & (1U << sig)) == 0) continue;
		pending &= ~(1U << sig);
		if(u.u_signal[sig] == SIG_DFL)
			h = SIG_DFL;
		else if(u.u_signal[sig] == SIG_IGN)
			h = SIG_IGN;
		else
			h = handlers[sig];
		if(h == SIG_IGN) continue;
			if(h == SIG_DFL) {
				do_exit(0x100 | sig, r);
				return;
			}
			handlers[sig] = SIG_DFL;
		install_sigtramp((char *)USERBASE);
		arm_sync_icache();
		sp = (unsigned int)r[13] - 12U;
		*(volatile unsigned int *)sp       = (unsigned int)r[15];
		*(volatile unsigned int *)(sp + 4) = (unsigned int)r[0];
		*(volatile unsigned int *)(sp + 8) = (unsigned int)r[14];
		r[13] = (int)sp;
		r[14] = (int)UENTRY_SIGTRAMP;
		r[15] = (int)h;
		r[0]  = sig;
		return;
	}
}
static void kdone_drop(int pid)
{
	for(int i = 0; i < ndone; i++)
		if(childdone[i].pid == pid) {
			(void)childdone_remove(i, NULL);
			return;
		}
}
void sys_wait(void)
{
	int r, next, my_slot, has_child = 0, ppid, status = 0;
	psig_drain(curpid, &pending);
	r = v7_wait_check(curpid, &status);
	if(r > 0) { ku.u_rval1 = r; ku.u_rval2 = status; kdone_drop(r); return; }
	r = kwait(curpid, &status);
	if(r > 0) { ku.u_rval1 = r; ku.u_rval2 = status; v7_proc_reap(r); return; }
	if(sig_deliverable(pending)) { ku.u_error = 4; return; }
	for(int i = 0; i < NPROCSAVE && !has_child; i++)
		has_child = armproc[i].inuse && armproc[i].ppid == curpid;
	for(int i = 0; i < ndone && !has_child; i++)
		has_child = childdone[i].ppid == curpid;
	if(!has_child) { ku.u_error = 10; return; }
	next = mt_pick_child(curpid);
	if(next < 0)
		next = mt_pick_runnable();
	if(next < 0) {
		__asm__ volatile("cpsie i\n\tisb" ::: "memory");
		while((next = mt_pick_child(curpid)) < 0 &&
		    (next = mt_pick_runnable()) < 0)
			clocked_spin_barrier();
		__asm__ volatile("cpsid i" ::: "memory");
	}
	ppid = v7_get_ppid(curpid);
	if(ppid < 0) ppid = 1;
	my_slot = mt_save_slot(curpid, ppid, PSTATE_SLEEP);
	if(my_slot < 0) { ku.u_error = 11; return; }
	mt_save_current(my_slot, trap_r, PSTATE_SLEEP);
	armproc[my_slot].wait_for = -1;
	armproc[my_slot].frame[7]  = S_WAIT;
	armproc[my_slot].frame[15] -= 4;
	mt_load_slot(next, trap_r);
	mt_switched = 1;
}
void sys_pause_v7(void)
{
	int next, my_slot, ppid;
	psig_drain(curpid, &pending);
	if(sig_deliverable(pending)) { ku.u_error = 4; return; }
	ppid = v7_get_ppid(curpid);
	if(ppid < 0) ppid = 1;
	if((next = mt_pick_runnable()) >= 0) {
		if((my_slot = mt_save_slot(curpid, ppid, PSTATE_SLEEP)) >= 0) {
			mt_save_current(my_slot, trap_r, PSTATE_SLEEP);
			armproc[my_slot].wait_for = -2;
			armproc[my_slot].frame[0]  = -4;
			mt_load_slot(next, trap_r);
			mt_switched = 1;
			return;
		}
	}
	if((my_slot = mt_save_slot(curpid, ppid, PSTATE_SLEEP)) < 0) {
		ku.u_error = 4;
		return;
	}
	mt_save_current(my_slot, trap_r, PSTATE_SLEEP);
	armproc[my_slot].wait_for = -2;
	armproc[my_slot].frame[0]  = -4;
	__asm__ volatile("cpsie i\n\tisb" ::: "memory");
	while((next = mt_pick_runnable()) < 0)
		clocked_spin_barrier();
	__asm__ volatile("cpsid i" ::: "memory");
	mt_load_slot(next, trap_r);
	mt_switched = 1;
}
void sys_kill_v7(void)
{
	int tgt = ku.u_arg[0], sig = ku.u_arg[1];
	int r;
	if(sig < 0 || sig >= NSIG) { ku.u_error = 22; return; }
	if(tgt > 0 && tgt != curpid && slot_by_pid(tgt) < 0 && !v7_proc_alive(tgt)) {
		ku.u_error = 3;
		return;
	}
	r = v7_kill_call(ku.u_arg, kuid, curpid);
	if(r < 0) { ku.u_error = -r; return; }
	if(sig > 0 && sig < NSIG) {
		if(tgt == curpid)
			pending |= 1U << sig;
		else {
			int sl = slot_by_pid(tgt);
			if(sl >= 0) {
				armproc[sl].pending |= 1U << sig;
				if(armproc[sl].state == PSTATE_SLEEP) {
					armproc[sl].state    = PSTATE_RUN;
					armproc[sl].wait_for = -1;
				}
			}
		}
	}
	ku.u_rval1 = 0;
}
volatile int in_trap;
void do_exit(int code, int *r)
{
	int my_pid = curpid, next, ppid = v7_get_ppid(my_pid);
	if(ppid < 0) ppid = 1;
	v7_reparent_children(my_pid, 1);
	for(int i = 0; i < NPROCSAVE; i++)
		if(armproc[i].inuse && armproc[i].ppid == my_pid)
			armproc[i].ppid = 1;
	for(int i = 0; i < ndone; i++)
		if(childdone[i].ppid == my_pid)
			childdone[i].ppid = 1;
	v7_proc_exit(my_pid, code);
	if(live_slot >= 0 && armproc[live_slot].pid == my_pid) {
		proc_free_slot(live_slot);
		live_slot = -1;
	}
	v7_ofile_drop_all();
	acct();
	kdone(my_pid, ppid, code);
	(void)mt_wake_waiters(my_pid, ppid);
		if((next = mt_pick_runnable()) >= 0) {
			mt_load_slot(next, r);
			if(armproc[next].ksp != 0) {
				kstack_restore(&armproc[next]);
				armproc[next].ksp = 0;
				armproc[next].kstackn = 0;
				in_trap = 0;
				resume(0, armproc[next].rsav);
				panic("exit: resume returned");
			}
			deliver_signal(r); in_trap = 0; return;
		}
	__asm__ volatile("cpsie i\n\tisb" ::: "memory");
	while((next = mt_pick_runnable()) < 0)
		clocked_spin_barrier();
	__asm__ volatile("cpsid i" ::: "memory");
	mt_load_slot(next, r);
	if(armproc[next].ksp != 0) {
		kstack_restore(&armproc[next]);
		armproc[next].ksp = 0;
		armproc[next].kstackn = 0;
		in_trap = 0;
		resume(0, armproc[next].rsav);
		panic("exit: resume returned");
	}
	deliver_signal(r); in_trap = 0;
}
void trap(int *r)
{
	int n = r[7], ret = -1;
	in_trap = 1;
	trap_frame = trap_r = r;
	u.u_ar0 = r;
	if(n == S_EXIT) { do_exit(r[0] & 0xff, r); return; }
	if(n == S_FORK) {
		int new_pid = nextpid, parent_pid = curpid;
		int slot = mt_alloc_slot(new_pid, parent_pid, PSTATE_RUN);
		if(slot >= 0) {
			struct armproc *a = &armproc[slot];
			v7_ofile_fork_bump();
			mt_save_current(slot, r, PSTATE_RUN);
			proc_core(proc_by_pid(parent_pid), live_slot);
				v7_u_times_restore(a->utime, a->stime, a->cutime, a->cstime);
				a->utime = a->stime = a->cutime = a->cstime = 0;
				a->pid = new_pid;
				a->ppid = parent_pid;
				a->pending = 0;
				bzero((char *)a->uarea.u_qsav, sizeof(a->uarea.u_qsav));
				bzero((char *)a->qsav, sizeof(a->qsav));
				a->frame[0] = 0;
				if(v7_proc_fork(parent_pid, new_pid) < 0) {
					proc_free_slot(slot);
					v7_proc_set_current(parent_pid);
					ret = -11;
				goto fork_fail;
			}
				proc_core(proc_by_pid(new_pid), slot);
				nextpid++;
				v7_proc_set_current(parent_pid);
				r[0] = new_pid;
				in_trap = 0; return;
			}
		ret = -11;
fork_fail:	;
	}
	else if(n == S_SIGNAL) {
		long old;
		(void)v7_signal_call(r[0], r[1], curpid);
		old = ksignal(r[0], (long)(unsigned int)r[1]);
		r[0] = (old == -1) ? -22 : (int)old;
		deliver_signal(r); in_trap = 0; return;
	}
	else if(n == S_SIGRETURN) {
		(void)v7_sigreturn_call(r);
		deliver_signal(r); in_trap = 0; return;
	}
	else {
		sysent_dispatch(n, r);
		ret = ku.u_error ? -ku.u_error : ku.u_rval1;
	}
	if(mt_switched) {
		mt_switched = 0;
		deliver_signal(r); in_trap = 0; return;
	}
	r[0] = ret;
	if(ret >= 0) r[1] = ku.u_rval2;
	(void)mt_preempt(r);
	deliver_signal(r);
	in_trap = 0;
}
void user_trap_handler(int signo, int *r)
{
	int mode = r[16] & 0x1f;
	if(mode != 0x10 && mode != 0x1f) {
		printf("kernel trap sig=%d pc=0x%x cpsr=0x%x\n",
		    signo, r[15], r[16]);
		panic("kernel trap");
	}
	in_trap = 1;
	trap_frame = trap_r = r;
	pending |= 1U << signo;
	deliver_signal(r);
	in_trap = 0;
}
extern void iput(struct inode *ip);
extern struct proc proc[];
int *trap_frame;
struct proc *
proc_by_pid(int pid)
{
	for(int i = 0; i < NPROC; i++)
		if(proc[i].p_stat != 0 && proc[i].p_pid == (short)pid)
			return &proc[i];
	return NULL;
}
extern void v7_call_prep(int *args);
int v7_pause_call(volatile unsigned int *pending_ptr)
{
	struct proc *pp = u.u_procp ? u.u_procp : &proc[0];
	int psig;
	__asm__ volatile("cpsie i\n\tisb" ::: "memory");
	for(;;) {
		if(*pending_ptr != 0) break;
		psig = *((volatile short *)&pp->p_sig) & 0xffff;
		if(psig != 0) {
			for(int sig = 1; sig < 32; sig++) {
				int bit = 1 << (sig-1);
				if(psig & bit) {
					pp->p_sig &= ~bit;
					*pending_ptr |= 1U << sig;
				}
			}
			break;
		}
		clocked_spin_barrier();
	}
	__asm__ volatile("cpsid i" ::: "memory");
	u.u_error = u.u_r.r_val1 = 0;
	return 0;
}
static void bzero(char *p, unsigned int n) { while(n--) *p++ = 0; }
char *
slot_user_base(int slot)
{
	return (int)slot == live_slot ? (char *)USERBASE : (char *)usermem[slot];
}
void copyseg(int from, int to)
{
	(void)from;
	(void)to;
}
void clearseg(int a)
{
	(void)a;
}
static void proc_core_copy(unsigned int slot, char *buf, unsigned int off,
    unsigned int n)
{
	struct user *up;
	struct proc *pp;
	unsigned int ubytes, pbytes, stack_bytes, stack_core, user_addr, cnt;
	char *base;
	if(slot >= NPROCSAVE || !armproc[slot].inuse) {
		bzero(buf, n);
		return;
	}
	up = (int)slot == live_slot ? &u : &armproc[slot].uarea;
	pp = proc_by_pid(armproc[slot].pid);
	base = slot_user_base((int)slot);
	ubytes = (unsigned int)ctob(USIZE);
	pbytes = pp && pp->p_size > 0 ? (unsigned int)ctob(pp->p_size)
	    : ubytes + (unsigned int)ctob(up->u_ssize);
	if(pbytes > PROC_CORE_BYTES)
		pbytes = PROC_CORE_BYTES;
	stack_bytes = (unsigned int)ctob(up->u_ssize);
	if(stack_bytes > V7_STACK_TOP)
		stack_bytes = V7_STACK_TOP;
	stack_core = pbytes > stack_bytes ? pbytes - stack_bytes : ubytes;
	while(n != 0) {
		cnt = n;
		if(off < sizeof(*up)) {
			if(cnt > sizeof(*up) - off)
				cnt = sizeof(*up) - off;
			if((int)slot == live_slot)
				bcopy((char *)&u + off, buf, cnt);
			else
				bcopy((char *)&armproc[slot].uarea + off, buf, cnt);
		} else if(off < ubytes) {
			if(cnt > ubytes - off)
				cnt = ubytes - off;
			bzero(buf, cnt);
		} else if(off >= stack_core && off < pbytes) {
			if(cnt > pbytes - off)
				cnt = pbytes - off;
			user_addr = V7_STACK_TOP - stack_bytes + (off - stack_core);
			bcopy(base + user_addr, buf, cnt);
		} else if(off < stack_core) {
			if(cnt > stack_core - off)
				cnt = stack_core - off;
			user_addr = off - ubytes;
			if(user_addr < USERSIZE) {
				if(cnt > USERSIZE - user_addr)
					cnt = USERSIZE - user_addr;
				bcopy(base + user_addr, buf, cnt);
			} else
				bzero(buf, cnt);
		} else {
			if(cnt > PROC_CORE_BYTES - off)
				cnt = PROC_CORE_BYTES - off;
			bzero(buf, cnt);
		}
		buf += cnt;
		off += cnt;
		n -= cnt;
	}
}
int
arm_mem_read(unsigned int off, char *buf, unsigned int n)
{
	unsigned int slot, so, cnt, done;
	done = 0;
	while(done < n) {
		slot = off / PROC_CORE_BYTES;
		so = off % PROC_CORE_BYTES;
		cnt = n - done;
		if(cnt > PROC_CORE_BYTES - so)
			cnt = PROC_CORE_BYTES - so;
		if(slot < NPROCSAVE && armproc[slot].inuse)
			proc_core_copy(slot, buf + done, so, cnt);
		else
			bcopy((char *)(unsigned long)off, buf + done, cnt);
		done += cnt;
		off += cnt;
	}
	return((int)done);
}
static void kdone(int pid, int ppid, int code)
{
	struct childent *c;
	if(ndone >= NOFILE) return;
	c = &childdone[ndone++];
	c->pid = pid; c->ppid = ppid; c->exitval = code;
	v7_u_times_snapshot(&c->utime, &c->stime);
}
static int childdone_remove(int i, int *codep)
{
	int pid = childdone[i].pid, code = childdone[i].exitval;
	v7_u_times_add_child(childdone[i].utime, childdone[i].stime);
	for(int j = i+1; j < ndone; j++)
		childdone[j-1] = childdone[j];
	ndone--;
	if(codep) *codep = code;
	return pid;
}
static int kwait(int ppid, int *statp)
{
	int i, pid, code;
	for(i = 0; i < ndone; i++)
		if(childdone[i].ppid == ppid) break;
	if(i == ndone) return -1;
	pid = childdone_remove(i, &code);
	if(statp != 0)
		*statp = (code & 0x100) ? (code & 0x7f) : ((code & 0xff) << 8);
	return pid;
}
