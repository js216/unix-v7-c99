#include "../h/param.h"
#include "../h/systm.h"
#include "../h/dir.h"
#include "../h/user.h"
#include "../h/proc.h"
struct map;
struct buf;
extern int malloc(struct map *mp, int size);
extern void mfree(struct map *mp, int size, int a);
extern void printf(char *fmt, ...);
extern void panic(char *s);
extern void prdev(char *str, dev_t dev);
extern void putchar(char c);
extern int getchar(void);
extern void trap(int *frame);
extern void panictrap(void);
extern void run_user(unsigned int pc, unsigned int sp);
extern void mmu_on(unsigned int ttb);
extern void dmbsy(void);
extern void mmuinit(void);
extern void startup(void);
extern void armboot(void);
extern void armboot_setrun(int pid);
extern void armboot_swtch(void);
extern int save(int *lp);
extern void resume(int addr, int *lp);
extern struct buf *bread(dev_t dev, daddr_t blkno);
extern struct buf *breada(dev_t dev, daddr_t blkno, daddr_t rablkno);
extern void bwrite(struct buf *bp);
extern void bdwrite(struct buf *bp);
extern void brelse(struct buf *bp);
extern int incore(dev_t dev, daddr_t blkno);
extern struct buf *getblk(dev_t dev, daddr_t blkno);
extern struct buf *geteblk(void);
extern void iowait(struct buf *bp);
extern void notavail(struct buf *bp);
extern void iodone(struct buf *bp);
extern void clrbuf(struct buf *bp);
extern void swap(daddr_t blkno, int coreaddr, int count, int rdflg);
extern void bflush(dev_t dev);
extern void geterror(struct buf *bp);
extern void wakeup(caddr_t chan);
extern void sleep(caddr_t chan, int pri);
extern int spl0(void);
extern int spl1(void);
extern int spl6(void);
extern int spl7(void);
extern void splx(int s);
extern void binit(void);
extern void copyseg(int from, int to);
extern void clearseg(int a);
extern dev_t rootdev;
extern int virtio_strategy(struct buf *bp);
extern void virtio_init(void);

extern void addupc(caddr_t pc, void *prof, int inc);	/* sys/arch/arm.c stub */
/* wakeup/spl1 come from local declarations.  psignal/setpri come from h/systm.h. */

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
