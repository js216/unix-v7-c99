#include "../h/param.h"
#include "../h/dir.h"
#include "../h/ino.h"
#include "../h/inode.h"
#include "../h/filsys.h"
#include "../h/buf.h"
#include "../h/file.h"
#include "../h/mount.h"
#include "../h/proc.h"
#include "../h/user.h"
#include "arm.h"
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
#define	NADDR			13
#define	IFMT			0170000
#define	IFDIR			0040000
#define	IFCHR			0020000
#define	IFBLK			0060000
#define	IFREG			0100000
#define	NFD			16
#define	NPIPES			16
#define	PIPESIZ			65536
#define	KENOEXEC		8
#define	B9600			13
#define	ECHO			010
#define	CRMOD			020
#define	ODDP			0100
#define	EVENP			0200
#define	XTABS			06000
struct kfile {
	ino_t	ino;
	unsigned short mode;
	unsigned int size, off;
	daddr_t	addr[NADDR];
	char	*mem;		/* tmpfd: backing buffer */
	int	pipe;		/* 0 = not a pipe, else pipe_id+1 */
	int	wpipe;		/* pipe write-end flag */
	int	eof;		/* /dev/console one-shot EOF */
	int	kmem;		/* 1 = /dev/{mem,kmem}, 2 = /dev/null, 3 = /dev/root */
};
struct pipe {
	char	buf[PIPESIZ];
	unsigned int rpos, wpos;
	int	used, writer;
};
struct ustat {
	int	st_dev;
	ino_t	st_ino;
	unsigned short st_mode;
	short	st_nlink, st_uid, st_gid;
	int	st_rdev;
	long	st_size, st_atime, st_mtime, st_ctime;
};
struct sgttyb {
	char	sg_ispeed, sg_ospeed, sg_erase, sg_kill;
	int	sg_flags;
};
static struct sgttyb console_sgtty = {
	B9600, B9600, '#', '@', EVENP|ODDP|ECHO|CRMOD|XTABS
};
static unsigned int l1[4096] __attribute__((aligned(16384)));
static unsigned char blkbuf[BSIZE] __attribute__((aligned(512)));
static char argbuf[UARGLEN], tmpname[64], tmpbuf[8192];
static struct pipe pipes[NPIPES];
static struct kfile files[NFD];
static int closed[NFD];
static ino_t cwdino = ROOTINO;
/* v7 syscall bridge routines are below in this file.  Keep the
 * declarations at this use site, as the original tree did. */
extern int *trap_frame;	/* mirrored at trap() entry for v7-side reads */
extern void v7_proc_init(void), v7_proc_exit(int curpid, int code);
extern void v7_proc_reap(int pid), v7_proc_set_current(int pid);
extern int v7_proc_fork(int parent_pid, int child_pid);
extern int v7_wait_check(int parent_pid, int *status);
extern int v7_get_ppid(int pid), v7_proc_alive(int pid);
extern int v7_proc_set_stat(int pid, int stat);
extern void v7_reparent_children(int dying_pid, int new_ppid);
extern void v7_signal_pgrp(int sig, int curpid);
extern int v7_umask_call(int *args, int kumask);
extern int v7_getuid_call(int kuid), v7_getgid_call(int kgid);
extern int v7_getpid_call(int curpid, int ppid);
extern int v7_getppid_call(int curpid);
extern int v7_setuid_call(int kuid, int *args);
extern int v7_setgid_call(int kgid, int *args);
extern int v7_sync_call(void), v7_nice_call(int *args, int curpid);
extern long v7_gtime_call(void), v7_stime_call(int *args);
extern int v7_alarm_call(int *args, int curpid);
extern int v7_pause_call(volatile unsigned int *pending_ptr);
extern int v7_ftime_call(int *args), v7_times_call(int *args);
extern int v7_profil_call(int *args), v7_lock_call(int *args, int curpid);
extern int v7_kill_call(int *args, int kuid, int curpid);
extern int v7_signal_call(int signo, int func, int curpid);
extern int v7_u_error_get(void), v7_save_qsav(void);
extern void v7_inode_drop(void *p);
extern void v7_u_times_save(long *ut, long *st, long *cut, long *cst);
extern void v7_u_times_restore(long ut, long st, long cut, long cst);
extern void v7_u_times_snapshot(long *utp, long *stp);
extern void v7_u_times_add_child(long ut, long st);
extern void v7_u_signal_save(long *sig), v7_u_signal_restore(const long *sig);
extern void v7_u_qsav_save(int *dst), v7_u_qsav_restore(const int *src);
extern void *v7_cdir_save(void), *v7_rdir_save(void);
extern void v7_cdir_restore(void *p), v7_rdir_restore(void *p);
extern ino_t v7_chdir_call(char *path), v7_namei_inum(char *path);
extern int v7_chroot_call(char *path), v7_chmod_call(char *path, int mode);
extern int v7_sysacct_call(char *path);
extern int v7_chown_call(char *path, int uid, int gid);
extern int v7_utime_call(char *path, void *tptr);
extern int v7_stat_call(char *path, void *ubuf);
extern int v7_access_call(char *path, int mode);
extern int v7_unlink_call(char *path), v7_link_call(char *from, char *to);
extern int v7_mknod_call(char *path, int mode, int dev);
extern int v7_mount_call(char *special, char *dir, int ro);
extern int v7_umount_call(char *special), v7_exec_call(char *path, char **argv, char **envp);
extern int v7_sigreturn_call(int *r), v7_mount_init(void);
extern void v7_ofile_set(int fd, ino_t ino, int flag);
extern void v7_ofile_clear(int fd), v7_ofile_dup(int from, int to);
extern void v7_ofile_save(void *buf), v7_ofile_restore(void *buf);
extern void v7_pofile_save(void *buf), v7_pofile_restore(void *buf);
extern void v7_pofile_excl_set(int fd), v7_pofile_excl_clear(int fd);
extern void v7_ofile_fork_bump(void), v7_ofile_drop_all(void);
extern int v7_ofile_isset(int fd), v7_fstat_call(int fd, void *ubuf);
extern int v7_close_call(int fd), v7_dup_call(int from, int to);
extern int v7_lseek_call(int fd, int off, int whence);
extern int v7_read_call(int fd, char *buf, unsigned int n);
extern long v7_get_offset(int fd);
extern void v7_set_offset(int fd, long off);
extern void v7_inode_refresh(int fd, unsigned int size, unsigned int *addrs);
extern void v7_inode_mark_dirty(int fd);
extern void v7_inode_writeback(int fd, unsigned int *size_out, unsigned int *addrs_out);
extern void v7_inode_refresh_ino(ino_t ino, unsigned int size, unsigned int *addrs);
extern void v7_inode_mark_dirty_ino(ino_t ino);
extern int v7_inode_snapshot_ino(ino_t ino, unsigned int *size_out, unsigned int *addrs_out);
/* Routed-syscall bridges return >=0 ok, -1 err, -2 (r/w) = fall back to k*. */
extern void acct(void);
extern int getchar_ready(void);
extern void pause_spin_barrier(void);
extern time_t time;
extern struct inode *rootdir;
void do_exit(int code, int *r);
/* PDP-11 SPL primitives -- ARM masks IRQs in exception entry here, so
 * the v7 kernel's priority-level calls are no-ops. */
int spl0(void) { return 0; }
int spl1(void) { return 0; }
int spl6(void) { return 0; }
int spl7(void) { return 0; }
void splx(int s) { (void)s; }
/* USERBASE is identity-mapped in this port; user/kernel copies are plain
 * byte copies. */
int fubyte(caddr_t addr) { return *(unsigned char *)addr; }
int subyte(caddr_t addr, char c) { *(unsigned char *)addr = c; return 0; }
void bcopy(char *f, char *t, unsigned int n) { while(n--) *t++ = *f++; }
int copyin(caddr_t f, caddr_t t, unsigned int n) { while(n--) *t++ = *f++; return 0; }
int copyout(caddr_t f, caddr_t t, unsigned int n) { while(n--) *t++ = *f++; return 0; }
void copyseg(int from, int to) { (void)from; (void)to; }
void clearseg(int a) { (void)a; }
void prele(struct inode *ip) { if(ip) ip->i_flag &= ~(ILOCK|IWANT); }
void plock(struct inode *ip) { if(ip) { ip->i_flag &= ~IWANT; ip->i_flag |= ILOCK; } }
char regloc[9];
caddr_t waitloc;
void addupc(caddr_t pc, void *prof, int inc) { (void)pc; (void)prof; (void)inc; }
void pause_spin_barrier(void)
{
	putchar('\b');
	__asm__ volatile("dmb ish" ::: "memory");
}
#define V7_FREAD	01	/* h/file.h flags */
#define V7_FWRITE	02
static unsigned int tmpused;
static ino_t nextino;
static daddr_t nextblk;
/* console_seen: one-shot EOF for init's sh; console_ino stamped on fds 0-2. */
static int console_seen;
static ino_t console_ino = 1;
/* Zombie log (v7 xproc-on-swap repl); folds utime/stime to c-times on reap. */
static struct childent {
	int pid, ppid, exitval;
	long utime, stime;
} childdone[NFD];
static int ndone, curpid = 1, nextpid = 2;
/* Per-proc-slot command name, indexed by proc[] slot.  Populated at
 * exec() time with the basename of the loaded path; ps(1) reads it
 * via nlist("_pcomm") + lseek(/dev/mem) when the running proc's
 * UARGV window is not the parked slot's window. */
char pcomm[NPROC][16];
/* Per-proc save pool repl. v7 swap; armproc[] mirrors u-area (USERBASE+
 * files+handlers+sigs+times).  NPROCSAVE=32->~34 MB BSS on 128 MiB qemu.
 * Raised from 16 -- pipelines like `loop | grep` with backquotes inside
 * the loop, or `for ... in & wait` with >12 children, can park 15-30
 * sleeping procs concurrently and the old limit caused fork() retry
 * loops to spin forever.  wait_for for SLEEP: -1 wait, -2 pause,
 * >=0 wait(pid), -(100+p) pipeR, -(200+p) pipeW. */
#define	NPROCSAVE	32
#define	KSTACK_SIZE	4096
#define	PSTATE_FREE	0
#define	PSTATE_RUN	2	/* runnable, not currently live */
#define	PSTATE_SLEEP	3	/* blocked, will be woken by wait/sig/clock */
#define	PSTATE_ZOMBIE	4	/* exited; parent has not reaped yet */
static struct armproc {
	unsigned char user[USERSIZE];
	int frame[17];
	struct kfile files[NFD];
	int closed[NFD];
	void *ofile[20];
	char pofile[20];	/* u_pofile[] -- per-fd close-on-exec flags */
	ino_t cwdino;
	void *cdir, *rdir;
	long handlers[NSIG+1];
	unsigned int pending;
	int uid, gid, pid, inuse;
	long utime, stime, cutime, cstime, usignal[NSIG+1];
	int umask;
	unsigned char kstack[KSTACK_SIZE] __attribute__((aligned(16)))
	    __attribute__((unused));
	int rsav[10], qsav[10];
	int state, ppid, exitcode, wait_for;
} armproc[NPROCSAVE];
/* Find slot by pid (for RUN/SLEEP/ZOMBIE entries). */
static int slot_by_pid(int pid)
{
	for(int i = 0; i < NPROCSAVE; i++)
		if(armproc[i].inuse && armproc[i].state != PSTATE_FREE &&
		   armproc[i].pid == pid)
			return i;
	return -1;
}
/* Claim the first free save-pool slot.  Returns -1 if the pool is full. */
static int mt_alloc_slot(int pid, int ppid, int state)
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
/* Release slot back to the pool (called from sys_wait after parent reaps). */
static void proc_free_slot(int slot)
{
	struct armproc *a;
	if(slot < 0 || slot >= NPROCSAVE) return;
	a = &armproc[slot];
	a->inuse = a->pid = a->ppid = a->exitcode = 0;
	a->state = PSTATE_FREE;
	a->wait_for = -1;
}
/* Forward decls (definitions live later in this TU). */
void bcopy(char *, char *, unsigned int);
static void restore_v7_regular_files(void);
static long handlers[NSIG+1];
static unsigned int pending;
static int kuid, kgid, kumask, mt_switched;
/* Return non-zero if `mask` contains at least one bit whose handler is
 * not SIG_IGN -- mirrors v7 issig() which skips SIG_IGN bits.  Used by
 * interruptible blocking syscalls (pause/wait/pipe-rw/tty-read) so
 * they only break out on a deliverable signal. */
static int sig_deliverable(unsigned int mask)
{
	for(int s = 1; s <= NSIG; s++)
		if((mask & (1U << s)) && handlers[s] != 1L /* SIG_IGN */)
			return 1;
	return 0;
}
/* v7_u_times_save/restore, v7_u_signal_save/restore, v7_u_qsav_save/
 * restore, v7_proc_set_stat all come from local extern declarations. */
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
	bcopy((char *)USERBASE, (char *)a->user,   USERSIZE);
	bcopy((char *)r,        (char *)a->frame,  sizeof(a->frame));
	bcopy((char *)files,    (char *)a->files,  sizeof(a->files));
	bcopy((char *)closed,   (char *)a->closed, sizeof(a->closed));
	bcopy((char *)handlers, (char *)a->handlers, sizeof(handlers));
	v7_ofile_save(a->ofile);
	v7_pofile_save(a->pofile);
	a->cwdino = cwdino;
	a->cdir = v7_cdir_save();
	a->rdir = v7_rdir_save();
	a->pending = pending;
	a->uid = kuid;
	a->gid = kgid;
	a->pid = curpid;
	a->state = state;
	a->umask = kumask;
	/* Mirror state -> proc[].p_stat so v7 sys/slp.c sees SRUN/SSLEEP. */
	pstat = pstate_to_pstat(state);
	if(pstat) (void)v7_proc_set_stat(curpid, pstat);
	/* v7_u_times_save also zeros u_times so the next-to-run proc
	 * starts CPU-time accounting from zero. */
	v7_u_times_save(&a->utime, &a->stime, &a->cutime, &a->cstime);
	v7_u_signal_save(a->usignal);
	v7_u_qsav_save(a->qsav);
}
/* mt_load_slot: restore state from slot into live globals, free slot. */
static void mt_load_slot(int slot, int *r)
{
	struct armproc *a = &armproc[slot];
	bcopy((char *)a->user,     (char *)USERBASE, USERSIZE);
	bcopy((char *)a->frame,    (char *)r,        sizeof(a->frame));
	bcopy((char *)a->files,    (char *)files,    sizeof(a->files));
	bcopy((char *)a->closed,   (char *)closed,   sizeof(a->closed));
	bcopy((char *)a->handlers, (char *)handlers, sizeof(handlers));
	v7_ofile_restore(a->ofile);
	v7_pofile_restore(a->pofile);
	restore_v7_regular_files();
	cwdino = a->cwdino;
	pending = a->pending;
	kuid = a->uid;
	kgid = a->gid;
	curpid = a->pid;
	kumask = a->umask;
	v7_cdir_restore(a->cdir);
	v7_rdir_restore(a->rdir);
	v7_proc_set_current(curpid);
	(void)v7_proc_set_stat(curpid, SRUN);
	v7_u_times_restore(a->utime, a->stime, a->cutime, a->cstime);
	v7_u_signal_restore(a->usignal);
	v7_u_qsav_restore(a->qsav);
	proc_free_slot(slot);
}
/* LIFO RUN slot wins; p_nice tiebreaker (NZERO=20 dominates).  Matches sh's `cmd & cmd; wait`. */
static int mt_pick_runnable(void)
{
	int best = -1, best_key = 0;
	for(int i = 0; i < NPROCSAVE; i++) {
		int nice_val = NZERO, key;
		if(!armproc[i].inuse || armproc[i].state != PSTATE_RUN) continue;
		for(int k = 0; k < NPROC; k++)
			if(proc[k].p_stat != 0 &&
			   proc[k].p_pid == (short)armproc[i].pid) {
				nice_val = proc[k].p_nice;
				break;
			}
		key = i * NZERO - (nice_val - NZERO);
		if(best < 0 || key > best_key) { best = i; best_key = key; }
	}
	return best;
}
/* Wake wait()'ing parent (SLEEP -> RUN) when child dies.  Returns slot or -1. */
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
/* v7 setrun bridge: flip matching armproc slot SLEEP->RUN.  Idempotent. */
void armboot_setrun(int pid)
{
	for(int i = 0; i < NPROCSAVE; i++)
		if(armproc[i].inuse && armproc[i].state == PSTATE_SLEEP &&
		   armproc[i].pid == pid) {
			armproc[i].state    = PSTATE_RUN;
			armproc[i].wait_for = -1;
			return;
		}
}
/* Wake SLEEP slots on a pipe.  role=1 wake readers, role=2 wake writers. */
static void mt_wake_pipe(int pipe_id, int role)
{
	int key = (role == 1) ? -(100 + pipe_id) : -(200 + pipe_id);
	for(int i = 0; i < NPROCSAVE; i++)
		if(armproc[i].inuse && armproc[i].state == PSTATE_SLEEP &&
		   armproc[i].wait_for == key) {
			armproc[i].state    = PSTATE_RUN;
			armproc[i].wait_for = -1;
		}
}
/* mt_pipe_count: any live/parked fd holding pipe end?  want_wpipe=1 writers, 0 readers. */
static int mt_pipe_count(int pipe_id, int want_wpipe)
{
	for(int j = 0; j < NFD; j++)
		if(files[j].pipe == pipe_id &&
		   (files[j].wpipe != 0) == (want_wpipe != 0) && !closed[j])
			return 1;
	for(int i = 0; i < NPROCSAVE; i++) {
		if(!armproc[i].inuse || armproc[i].state == PSTATE_FREE) continue;
		for(int j = 0; j < NFD; j++)
			if(armproc[i].files[j].pipe == pipe_id &&
			   (armproc[i].files[j].wpipe != 0) == (want_wpipe != 0) &&
			   !armproc[i].closed[j])
				return 1;
	}
	return 0;
}
#define	mt_pipe_has_writer(p)	mt_pipe_count((p), 1)
#define	mt_pipe_has_reader(p)	mt_pipe_count((p), 0)
/* clock_irq_handler tail: mirror p_sig into parked pending, wake SLEEP, bump preempt counter.
 * proc[] comes from h/proc.h. */
static int mt_clock_ticks;
static volatile int mt_need_resched;
#define	MT_PREEMPT_TICKS	10	/* HZ=100 -> preempt every 100ms */
/* Drain proc[pid].p_sig bits (v7 1<<(N-1)) into *dst (armboot 1<<N); clear p_sig. */
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
		psig_drain(a->pid, &a->pending);
		/* SLEEP slot with deliverable signal -> RUN.  Use the slot's
		 * own handlers[] (parked dispositions, not the live ones)
		 * so SIG_IGN bits don't wake the slot just to re-park.  */
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
	if(++mt_clock_ticks >= MT_PREEMPT_TICKS) {
		mt_clock_ticks = 0;
		mt_need_resched = 1;
	}
}
/* Save live proc as RUN and switch to a runnable peer.  Saved PC past SVC (no rewind). */
static int mt_preempt(int *r)
{
	int next, my_slot, ppid;
	if(!mt_need_resched) return 0;
	mt_need_resched = 0;
	if((next = mt_pick_runnable()) < 0) return 0;	/* no peer */
	ppid = v7_get_ppid(curpid);
	if(ppid < 0) ppid = 1;
	if((my_slot = mt_alloc_slot(curpid, ppid, PSTATE_RUN)) < 0)
		return 0;	/* slot pool full, stay live */
	mt_save_current(my_slot, r, PSTATE_RUN);
	mt_load_slot(next, r);
	return 1;
}
/* sys/slp.c::swtch repl: save()->rsav, snapshot, resume() peer; wake -> save() returns 1.
 * save/resume come from local declarations. */
static int *trap_r;	/* forward decl; def near sysent_dispatch */
void armboot_swtch(void)
{
	int my_slot, next;
	int ppid = v7_get_ppid(curpid);
	if(ppid < 0) ppid = 1;
	if((my_slot = mt_alloc_slot(curpid, ppid, PSTATE_SLEEP)) < 0)
		panic("swtch: no slot");
	if(save(armproc[my_slot].rsav))
		return;	/* we got resumed */
	mt_save_current(my_slot, trap_r, PSTATE_SLEEP);
	armproc[my_slot].wait_for = -1;
	if((next = mt_pick_runnable()) < 0)
		panic("swtch: no runnable peer");
	mt_load_slot(next, trap_r);
	resume(0, armproc[next].rsav);
	panic("swtch: resume returned");
}
/* Block on pipe end; switch to peer.  PC-=4 re-executes SVC on resume.  -1 if no peer. */
static int mt_block_on_pipe(int *r, int syscall_num, int wait_key)
{
	int my_slot, next, ppid;
	if((next = mt_pick_runnable()) < 0) return -1;
	ppid = v7_get_ppid(curpid);
	if(ppid < 0) ppid = 1;
	if((my_slot = mt_alloc_slot(curpid, ppid, PSTATE_SLEEP)) < 0)
		return -1;
	mt_save_current(my_slot, r, PSTATE_SLEEP);
	armproc[my_slot].wait_for = wait_key;
	armproc[my_slot].frame[7]  = syscall_num;
	armproc[my_slot].frame[15] -= 4;	/* rewind to re-execute SVC */
	mt_load_slot(next, r);
	return 0;
}
/* Lean `u` shadow for sysent[] dispatch (real v7 u lives in arch/arm.c). */
struct kuser {
	int u_arg[6], u_error, u_rval1, u_rval2, u_segflg;
};
static struct kuser ku;
static void sysent_dispatch(int);
/* Signals: DFL=0, IGN=1, else fn ptr.  handlers[]/pending = LIVE; saved in
 * armproc[].  Delivery: deliver_signal patches r0=sig,lr=SIGTRAMP; ksigreturn restores. */
#define	SIG_DFL		0L
#define	SIG_IGN		1L
void mmuinit(void)
{
	unsigned int pa;
	for(unsigned int i = 0; i < 4096; i++) l1[i] = 0;
#ifdef EVB
	/* STM32MP135: map APB (USART4) + DDR.  user 1MB lives in DDR
	 * above kernel image + rootfs at 0xC8000000. */
	for(pa=0x40000000U; pa<0x50000000U; pa+=0x00100000U)
		l1[pa>>20] = (pa & 0xfff00000U) | 0x00000402U;
	for(pa=0xC0000000U; pa<0xE0000000U; pa+=0x00100000U)
		l1[pa>>20] = (pa & 0xfff00000U) | 0x00000402U;
	l1[0] = 0xC8000000U | 0x00000c02U;
#else
	for(pa=KERNBASE; pa<0x48000000U; pa+=0x00100000U)
		l1[pa>>20] = (pa & 0xfff00000U) | 0x00000402U;
	for(pa=0x08000000U; pa<0x0c000000U; pa+=0x00100000U)
		l1[pa>>20] = (pa & 0xfff00000U) | 0x00000402U;
	l1[0] = USERPHYS | 0x00000c02U;
#endif
	mmu_on((unsigned int)l1);
}
static void bzero(char *p, unsigned int n) { while(n--) *p++ = 0; }
/* bcopy lives in sys/arch/arm.c; declared with the prototype above. */
static int strncmp(char *a, char *b, int n)
{
	while(n-- > 0) {
		if(*a != *b) return *a - *b;
		if(*a == 0) return 0;
		a++; b++;
	}
	return 0;
}
static int strcmp(char *a, char *b)
{
	while(*a == *b) {
		if(*a == 0) return 0;
		a++; b++;
	}
	return *a - *b;
}
static void shim_bread(daddr_t blkno, void *buf)
{
	struct buf *bp = bread((dev_t)rootdev, blkno);
	bcopy((char *)bp->b_un.b_addr, (char *)buf, (unsigned int)BSIZE);
	brelse(bp);
}
static void shim_bwrite(daddr_t blkno, void *buf)
{
	struct buf *bp = getblk((dev_t)rootdev, blkno);
	bcopy((char *)buf, (char *)bp->b_un.b_addr, (unsigned int)BSIZE);
	bwrite(bp);
}
static daddr_t addr(char *p)
{
	return ((daddr_t)(unsigned char)p[0]) |
	       ((daddr_t)(unsigned char)p[1] << 8) |
	       ((daddr_t)(unsigned char)p[2] << 16);
}
static daddr_t addr4(char *p)
{
	return ((daddr_t)(unsigned char)p[0]) |
	       ((daddr_t)(unsigned char)p[1] << 8) |
	       ((daddr_t)(unsigned char)p[2] << 16) |
	       ((daddr_t)(unsigned char)p[3] << 24);
}
static int k_iget(ino_t ino, struct dinode *dp)
{
	int off;
	if(ino < ROOTINO)
		return -1;
	shim_bread(itod(ino), blkbuf);
	off = itoo(ino) * sizeof(struct dinode);
	bcopy((char *)&blkbuf[off], (char *)dp, sizeof(*dp));
	return dp->di_mode == 0 ? -1 : 0;
}
static int loadino(ino_t ino, struct kfile *fp)
{
	struct dinode di;
	if(k_iget(ino, &di) < 0) return -1;
	fp->ino = ino;
	fp->mode = di.di_mode;
	fp->size = (unsigned int)di.di_size;
	fp->off = 0;
	for(int i = 0; i < NADDR; i++)
		fp->addr[i] = addr(&di.di_addr[i*3]);
	return 0;
}
static void loadino_v7_current(ino_t ino, struct kfile *fp)
{
	unsigned int addrs[NADDR], size;
	if(v7_inode_snapshot_ino(ino, &size, addrs) < 0) return;
	fp->size = size;
	for(int i = 0; i < NADDR; i++)
		fp->addr[i] = (daddr_t)addrs[i];
}
static void put16(char *p, unsigned int v)
{ p[0] = v; p[1] = v >> 8; }
static void put24(char *p, daddr_t v)
{ p[0] = (char)v; p[1] = (char)(v >> 8); p[2] = (char)(v >> 16); }
static void put32(char *p, daddr_t v)
{
	p[0] = (char)v; p[1] = (char)(v >> 8);
	p[2] = (char)(v >> 16); p[3] = (char)(v >> 24);
}
static int putino(ino_t ino, struct kfile *fp)
{
	char *p;
	unsigned int oldmode;
	if(ino < ROOTINO) return -1;
	shim_bread(itod(ino), blkbuf);
	int off = itoo(ino) * sizeof(struct dinode);
	p = (char *)&blkbuf[off];
	oldmode = (unsigned int)(unsigned char)p[0] |
	    ((unsigned int)(unsigned char)p[1] << 8);
	if(oldmode == 0) {
		bzero(p, sizeof(struct dinode));
		put16(p+2, 1);
	}
	put16(p+0, fp->mode);
	put32(p+8, (daddr_t)fp->size);
	for(int i = 0; i < NADDR; i++)
		put24(p+12+i*3, fp->addr[i]);
	shim_bwrite(itod(ino), blkbuf);
	return 0;
}
static int kreadi(struct kfile *fp, unsigned int off, char *buf, unsigned int n)
{
	unsigned int tot, m, boff, lbn;
	daddr_t bn;
	daddr_t ib;
	if(off >= fp->size) return 0;
	if(off + n > fp->size) n = fp->size - off;
	tot = 0;
	while(n != 0) {
		lbn = off >> BSHIFT;
		if(lbn < NADDR-3)
			bn = fp->addr[lbn];
		else {
			lbn -= NADDR-3;
			if(lbn < NINDIR) {
				if(fp->addr[NADDR-3] == 0) break;
				shim_bread(fp->addr[NADDR-3], blkbuf);
				bn = addr4((char *)&blkbuf[lbn*4]);
			} else {
				lbn -= NINDIR;
				if(fp->addr[NADDR-2] == 0) break;
				shim_bread(fp->addr[NADDR-2], blkbuf);
				ib = addr4((char *)&blkbuf[(lbn/NINDIR)*4]);
				if(ib == 0) break;
				shim_bread(ib, blkbuf);
				bn = addr4((char *)&blkbuf[(lbn%NINDIR)*4]);
			}
		}
		if(bn == 0) break;
		boff = off & BMASK;
		m = BSIZE - boff;
		if(m > n) m = n;
		shim_bread(bn, blkbuf);
		bcopy((char *)&blkbuf[boff], buf, m);
		buf += m;
		off += m;
		tot += m;
		n -= m;
	}
	return (int)tot;
}
/* Pull a fresh block from v7's free list so we share it with v7's
 * alloc() (mkdir/link/etc.).  Pre-fix used a private nextblk++ counter
 * that collided with v7's free list and let two inodes share a block. */
static daddr_t fs_alloc_block(void)
{
	extern struct buf *alloc(dev_t);
	struct buf *bp = alloc((dev_t)rootdev);
	daddr_t bno;
	if(bp == NULL) return 0;
	bno = bp->b_blkno;
	bdwrite(bp);
	if(bno >= nextblk) nextblk = bno + 1;
	return bno;
}
/* Return a block to v7's free list (mirror of fs_alloc_block).  Used
 * when truncating a regular file -- without this, every `>` overwrite
 * leaks blocks until v7's free list runs dry (~50 iterations). */
static void fs_free_block(daddr_t bno)
{
	extern void free(dev_t, daddr_t);
	if(bno != 0) free((dev_t)rootdev, bno);
}
/* Walk an indirect block, freeing each non-zero pointer.  lev=0 is a
 * single-indirect block; lev>0 recurses through deeper indirect blocks. */
static void fs_free_indir(daddr_t bno, int lev)
{
	unsigned char ibuf[BSIZE];
	daddr_t ib;
	if(bno == 0) return;
	shim_bread(bno, ibuf);
	for(unsigned int i = 0; i < NINDIR; i++) {
		ib = addr4((char *)&ibuf[i*4]);
		if(ib == 0) continue;
		if(lev) fs_free_indir(ib, lev-1);
		else fs_free_block(ib);
	}
	fs_free_block(bno);
}
/* Free every data block (direct + indirect) reachable from fp->addr[]. */
static void fs_free_file_blocks(struct kfile *fp)
{
	for(int i = 0; i < NADDR-3; i++) {
		if(fp->addr[i] != 0) fs_free_block(fp->addr[i]);
		fp->addr[i] = 0;
	}
	fs_free_indir(fp->addr[NADDR-3], 0); fp->addr[NADDR-3] = 0;
	fs_free_indir(fp->addr[NADDR-2], 1); fp->addr[NADDR-2] = 0;
	fs_free_indir(fp->addr[NADDR-1], 2); fp->addr[NADDR-1] = 0;
}
static int kwritei(struct kfile *fp, unsigned int off, char *buf, unsigned int n)
{
	unsigned int tot, m, boff, lbn;
	daddr_t bn, ib;
	tot = 0;
	while(n != 0) {
		lbn = off >> BSHIFT;
		if(lbn < NADDR-3) {
			bn = fp->addr[lbn];
			if(bn == 0) {
				if((bn = fs_alloc_block()) == 0) break;
				fp->addr[lbn] = bn;
				bzero((char *)blkbuf, BSIZE);
			} else
				shim_bread(bn, blkbuf);
		} else {
			lbn -= NADDR-3;
			if(lbn < NINDIR) {
				if(fp->addr[NADDR-3] == 0) {
					if((fp->addr[NADDR-3] = fs_alloc_block()) == 0) break;
					bzero((char *)blkbuf, BSIZE);
					shim_bwrite(fp->addr[NADDR-3], blkbuf);
				}
				shim_bread(fp->addr[NADDR-3], blkbuf);
				bn = addr4((char *)&blkbuf[lbn*4]);
				if(bn == 0) {
					if((bn = fs_alloc_block()) == 0) break;
					put32((char *)&blkbuf[lbn*4], bn);
					shim_bwrite(fp->addr[NADDR-3], blkbuf);
					bzero((char *)blkbuf, BSIZE);
				} else
					shim_bread(bn, blkbuf);
			} else {
				lbn -= NINDIR;
				if(lbn >= NINDIR*NINDIR) break;
				if(fp->addr[NADDR-2] == 0) {
					if((fp->addr[NADDR-2] = fs_alloc_block()) == 0) break;
					bzero((char *)blkbuf, BSIZE);
					shim_bwrite(fp->addr[NADDR-2], blkbuf);
				}
				shim_bread(fp->addr[NADDR-2], blkbuf);
				ib = addr4((char *)&blkbuf[(lbn/NINDIR)*4]);
				if(ib == 0) {
					if((ib = fs_alloc_block()) == 0) break;
					put32((char *)&blkbuf[(lbn/NINDIR)*4], ib);
					shim_bwrite(fp->addr[NADDR-2], blkbuf);
					bzero((char *)blkbuf, BSIZE);
					shim_bwrite(ib, blkbuf);
				}
				shim_bread(ib, blkbuf);
				bn = addr4((char *)&blkbuf[(lbn%NINDIR)*4]);
				if(bn == 0) {
					if((bn = fs_alloc_block()) == 0) break;
					put32((char *)&blkbuf[(lbn%NINDIR)*4], bn);
					shim_bwrite(ib, blkbuf);
					bzero((char *)blkbuf, BSIZE);
				} else
					shim_bread(bn, blkbuf);
			}
		}
		boff = off & BMASK;
		m = BSIZE - boff;
		if(m > n) m = n;
		bcopy(buf, (char *)&blkbuf[boff], m);
		shim_bwrite(bn, blkbuf);
		buf += m;
		off += m;
		tot += m;
		n -= m;
	}
	if(off > fp->size) fp->size = off;
	return (int)tot;
}
static void scanind(daddr_t bn, int lev)
{
	unsigned char ibuf[BSIZE];
	daddr_t ib;
	if(bn == 0) return;
	if(bn >= nextblk) nextblk = bn + 1;
	shim_bread(bn, ibuf);
	for(unsigned int i = 0; i < NINDIR; i++) {
		ib = addr4((char *)&ibuf[i*4]);
		if(ib == 0) continue;
		if(ib >= nextblk) nextblk = ib + 1;
		if(lev) scanind(ib, lev-1);
	}
}
static void scanfs(void)
{
	struct dinode di;
	struct kfile fp;
	ino_t ino, maxino;
	/* Inode blocks occupy 2..(s_isize-1).  v7's `s_isize * INOPB`
	 * over-counts and would have iget read into data blocks. */
	maxino = (((struct filsys *)blkbuf)->s_isize - 2) * INOPB;
	nextino = ROOTINO;
	nextblk = 2 + ((struct filsys *)blkbuf)->s_isize;
	for(ino = ROOTINO; ino < maxino; ino++)
		if(k_iget(ino, &di) == 0) {
			nextino = ino + 1;
			if(loadino(ino, &fp) == 0) {
				for(int i = 0; i < NADDR-1; i++)
					if(fp.addr[i] >= nextblk)
						nextblk = fp.addr[i] + 1;
				scanind(fp.addr[NADDR-3], 0);
				scanind(fp.addr[NADDR-2], 1);
			}
		}
}
/* v7 sys/nami.c::namei via the arch/arm.c bridge. */
/* v7_namei_inum declared in local extern declarations. */
static ino_t parenti(char *path, char *name)
{
	char buf[128], *p = buf, *s = path;
	while(*s && p < &buf[sizeof(buf)-1]) *p++ = *s++;
	*p = 0;
	p = buf;
	while(*p) p++;
	while(p > buf && p[-1] != '/') p--;
	for(int i = 0; i < DIRSIZ; i++) name[i] = 0;
	s = p;
	for(int i = 0; i < DIRSIZ && *s; i++) name[i] = *s++;
	if(p == buf) return cwdino;
	if(p == buf+1) { buf[1] = 0; return ROOTINO; }
	p[-1] = 0;
	return v7_namei_inum(buf);
}
/* Find a free fd slot (skipping 0/1/2 console slots unless closed). */
static int alloc_fd_slot(void)
{
	int fd;
	for(fd = 0; fd < NFD; fd++)
		if((fd >= 3 || closed[fd]) && files[fd].ino == 0) return fd;
	return -1;
}
/* Allocate fd, zero files[fd], set ino/mode/size.  -1 if pool full. */
static int pseudo_fd_open(ino_t ino, int mode, unsigned int size)
{
	int fd = alloc_fd_slot();
	if(fd < 0) return -1;
	bzero((char *)&files[fd], sizeof(files[fd]));
	files[fd].ino = ino;
	files[fd].mode = mode;
	files[fd].size = size;
	closed[fd] = 0;
	v7_pofile_excl_clear(fd);	/* fresh fd: no inherited EXCLOSE */
	return fd;
}
static int kopen(char *path)
{
	int fd;
	if(tmpname[0] && strcmp(path, tmpname) == 0) {
		fd = pseudo_fd_open(1, IFREG, tmpused);
		if(fd >= 0) files[fd].mem = tmpbuf;
		return fd;
	}
	/* /dev/mem and /dev/kmem: dmesg's nlist+lseek+read window. */
	if(strcmp(path, "/dev/mem") == 0 || strcmp(path, "/dev/kmem") == 0) {
		fd = pseudo_fd_open(1, IFCHR, 0xFFFFFFFFu);
		if(fd >= 0) files[fd].kmem = 1;
		return fd;
	}
	/* /dev/console + /dev/tty alias. */
	if(strcmp(path, "/dev/console") == 0 ||
	   strcmp(path, "/dev/tty") == 0) {
		fd = pseudo_fd_open(console_ino, IFCHR, 0);
		if(fd >= 0) {
			files[fd].eof = console_seen ? 0 : 1;
			console_seen = 1;
		}
		return fd;
	}
	/* /dev/null: kmem==2 tag -> read EOF, write sinks. */
	if(strcmp(path, "/dev/null") == 0) {
		fd = pseudo_fd_open(1, IFCHR, 0);
		if(fd >= 0) files[fd].kmem = 2;
		return fd;
	}
	/* /dev/root: raw block-device window on the root filesystem.
	 * kmem==3 -> reads route through bread(rootdev,...) for utilities
	 * like df(1) that walk the on-disk superblock + free list. */
	if(strcmp(path, "/dev/root") == 0) {
		fd = pseudo_fd_open(1, IFBLK, 0xFFFFFFFFu);
		if(fd >= 0) files[fd].kmem = 3;
		return fd;
	}
	ino_t ino = v7_namei_inum(path);
	if(ino == 0) return -1;
	fd = alloc_fd_slot();
	if(fd < 0) return -1;
	bzero((char *)&files[fd], sizeof(files[fd]));
	if(loadino(ino, &files[fd]) < 0) return -1;
	closed[fd] = 0;
	if((files[fd].mode & IFMT) == IFREG)
		v7_ofile_set(fd, ino, V7_FREAD|V7_FWRITE);
	return fd;
}
static int kcreat(char *path, int mode)
{
	struct kfile dp, fp;
	struct direct de;
	char name[DIRSIZ];
	ino_t pino;
	int fd;
	if(strcmp(path, "/dev/null") == 0) return kopen(path);
	pino = parenti(path, name);
	if(pino == 0 || loadino(pino, &dp) < 0 || (dp.mode & IFMT) != IFDIR)
		return -1;
	loadino_v7_current(pino, &dp);
	for(int i = 0; i < (int)dp.size; i += sizeof(de)) {
		(void)kreadi(&dp, (unsigned int)i, (char *)&de, sizeof(de));
		if(de.d_ino && strncmp(de.d_name, name, DIRSIZ) == 0) {
			fd = alloc_fd_slot();
			if(fd < 0) return -1;
			if(loadino(de.d_ino, &files[fd]) < 0) return -1;
			/* creat() on non-regular = open(O_WRONLY); itrunc
			 * is a no-op on specials.  For /dev/console mirror
			 * kopen's synthetic setup so kwrite routes UART.
			 * For a directory: POSIX EISDIR; back out the alloc'd
			 * fd so it can be reused. */
			if((files[fd].mode & IFMT) == IFDIR) {
				bzero((char *)&files[fd], sizeof(files[fd]));
				return -2;	/* EISDIR marker for caller */
			}
			if((files[fd].mode & IFMT) != IFREG) {
				if(strcmp(path, "/dev/console") == 0) {
					/* kcreat allocated fd, reset it to
					 * the synthetic console layout */
					bzero((char *)&files[fd], sizeof(files[fd]));
					files[fd].ino = console_ino;
					files[fd].mode = IFCHR;
					files[fd].eof = console_seen ? 0 : 1;
					console_seen = 1;
				}
				closed[fd] = 0;
				return fd;
			}
			fs_free_file_blocks(&files[fd]);
			files[fd].mode = IFREG | ((mode & 07777) & ~kumask);
			files[fd].size = 0;
			if(putino(files[fd].ino, &files[fd]) < 0) return -1;
			v7_inode_refresh_ino(files[fd].ino, files[fd].size,
			    (unsigned int *)files[fd].addr);
			v7_inode_mark_dirty_ino(files[fd].ino);
			closed[fd] = 0;
			v7_ofile_set(fd, de.d_ino, V7_FREAD|V7_FWRITE);
			v7_inode_refresh(fd, files[fd].size,
			    (unsigned int *)files[fd].addr);
			v7_inode_mark_dirty(fd);
			return fd;
		}
	}
	fd = alloc_fd_slot();
	if(fd < 0) return -1;
	bzero((char *)&files[fd], sizeof(files[fd]));
	files[fd].ino = nextino++;
	files[fd].mode = IFREG | ((mode & 07777) & ~kumask);
	files[fd].size = 0;
	if(putino(files[fd].ino, &files[fd]) < 0) return -1;
	bzero((char *)&de, sizeof(de));
	de.d_ino = files[fd].ino;
	for(int j = 0; j < DIRSIZ; j++) de.d_name[j] = name[j];
	bcopy((char *)&dp, (char *)&fp, sizeof(fp));
	if(kwritei(&fp, fp.size, (char *)&de, sizeof(de)) != sizeof(de))
		return -1;
	(void)putino(pino, &fp);
	v7_inode_refresh_ino(pino, fp.size, (unsigned int *)fp.addr);
	v7_inode_mark_dirty_ino(pino);	/* parent dir grew */
	v7_inode_mark_dirty_ino(files[fd].ino);	/* new file mtime */
	closed[fd] = 0;
	v7_ofile_set(fd, files[fd].ino, V7_FREAD|V7_FWRITE);
	return fd;
}
static int kread(int fd, char *buf, unsigned int n)
{
	int c, r;
	if(fd >= 0 && fd < NFD && files[fd].pipe != 0) {
		struct pipe *pp = &pipes[files[fd].pipe-1];
		if(pp->rpos >= pp->wpos) { pp->rpos = pp->wpos = 0; return 0; }
		if(n > pp->wpos - pp->rpos) n = pp->wpos - pp->rpos;
		bcopy(pp->buf + pp->rpos, buf, n);
		pp->rpos += n;
		/* Drained the pipe -- rewind both cursors so subsequent
		 * writes start at 0 again (otherwise the linear buffer
		 * caps total throughput at PIPESIZ bytes). */
		if(pp->rpos >= pp->wpos) pp->rpos = pp->wpos = 0;
		mt_wake_pipe(files[fd].pipe, 2);	/* wake blocked writers */
		return n;
	}
	if(fd >= 0 && fd < NFD && files[fd].kmem == 2) return 0;	/* /dev/null EOF */
	if(fd >= 0 && fd < NFD && files[fd].kmem == 3) {
		/* /dev/root: read up to n bytes from the root block device,
		 * starting at files[fd].off bytes from block 0. */
		unsigned int total = 0;
		while(total < n) {
			daddr_t blkno = (daddr_t)((files[fd].off + total) >> 9);
			unsigned int boff = (files[fd].off + total) & 511;
			unsigned int avail = 512 - boff;
			struct buf *bp;
			if(avail > n - total) avail = n - total;
			bp = bread((dev_t)rootdev, blkno);
			bcopy((char *)bp->b_un.b_addr + boff, buf + total, avail);
			brelse(bp);
			total += avail;
		}
		files[fd].off += total;
		return (int)total;
	}
	if(fd >= 0 && fd < NFD && files[fd].kmem) {
		bcopy((char *)(unsigned long)files[fd].off, buf, n);
		files[fd].off += n;
		return (int)n;
	}
	if(fd == 0 || (fd >= 0 && fd < NFD && files[fd].mode == IFCHR)) {
		if(fd == 0 && files[fd].ino != 0 && files[fd].mode != IFCHR)
			goto file;
		if(n == 0) return 0;
		/* One-shot EOF for init's single-user sh. */
		if(fd >= 0 && fd < NFD && files[fd].eof) { files[fd].eof = 0; return 0; }
		/* Yield to peers while waiting for tty input; rewind SVC
		 * so we retry the read on resume.  Drain p_sig each
		 * iteration so a non-IGN'd signal (e.g. login's alarm(60)
		 * timeout, or any kill) interrupts the read with EINTR
		 * rather than spinning forever.  SIG_IGN bits are left in
		 * pending so deliver_signal can consume them silently. */
		while(!getchar_ready()) {
			psig_drain(curpid, &pending);
			if(sig_deliverable(pending)) {
				ku.u_error = 4;	/* EINTR */
				return -1;
			}
			if(mt_need_resched) {
				trap_r[15] -= 4;
				if(mt_preempt(trap_r)) { mt_switched = 1; return -1; }
				trap_r[15] += 4;
			}
		}
		c = getchar();
		if(c == '\r') c = '\n';
		if(c == 0x04) { putchar('\n'); return 0; }	/* ^D = EOF */
		/* ^C / ^\ -> signal caller's pgrp; swallow the char. */
		if(c == 0x03 || c == 0x1c) {
			v7_signal_pgrp(c == 0x03 ? 2 : 3, curpid);
			return 0;
		}
		/* Honor the tty ECHO bit so getty (which sets RAW and echoes
		 * each char itself) doesn't display every input character
		 * twice -- one from us + one from getty's putchr. */
		if(console_sgtty.sg_flags & ECHO)
			putchar(c);
		*buf = (char)c;
		return 1;
	}
file:
	if(fd < 0 || fd >= NFD || files[fd].ino == 0) return -1;
	if(files[fd].mem != 0) {
		if(files[fd].off >= files[fd].size) return 0;
		if(n > files[fd].size - files[fd].off)
			n = files[fd].size - files[fd].off;
		bcopy(files[fd].mem + files[fd].off, buf, n);
		files[fd].off += n;
		return n;
	}
	r = kreadi(&files[fd], files[fd].off, buf, n);
	if(r > 0) files[fd].off += (unsigned int)r;
	return r;
}
/* On-disk regular file routable to v7 sys2.c.  Pseudo-fds use ino<=1. */
static int fd_is_v7_reg(int fd)
{
	return fd >= 0 && fd < NFD &&
	       files[fd].ino > 1 && files[fd].pipe == 0 &&
	       (files[fd].mode & IFMT) == IFREG;
}
/* Mirror v7's in-core inode size/addr[] back into armboot's files[fd]. */
static void sync_fd_from_v7(int fd)
{
	/* Initialize to current files[fd] state -- v7_inode_writeback bails
	 * silently when the v7-side inode pointer is NULL (e.g., kcreat hit
	 * NFILE full and back-out'd, leaving ku.u_ofile[fd] NULL), in which
	 * case we want to keep the armboot-side state, not pick up stack
	 * garbage.  Without this, a redirected silent command wrote its
	 * whole binary to the target file. */
	unsigned int size = files[fd].size;
	unsigned int addrs[NADDR];
	for(int j = 0; j < NADDR; j++)
		addrs[j] = (unsigned int)files[fd].addr[j];
	v7_inode_writeback(fd, &size, addrs);
	files[fd].size = size;
	for(int j = 0; j < NADDR; j++)
		files[fd].addr[j] = (daddr_t)addrs[j];
}
static int kclose(int fd)
{
	if(fd < 0 || fd >= NFD) return -1;	/* EBADF: out-of-range */
	/* fd >= 3 with no inode: never opened or already closed.
	 * fd 0/1/2: closed[] tracks "was explicitly closed". */
	if(files[fd].ino == 0 && (fd >= 3 || closed[fd])) return -1;	/* EBADF */
	int p = files[fd].pipe;
	if(p != 0 && files[fd].wpipe) pipes[p-1].writer = 0;
	/* Closing a pipe end: wake the opposite end so it can re-check. */
	if(p != 0) { mt_wake_pipe(p, 1); mt_wake_pipe(p, 2); }
	if(fd_is_v7_reg(fd)) {
		if(v7_ofile_isset(fd)) sync_fd_from_v7(fd);
		(void)putino(files[fd].ino, &files[fd]);
	}
	v7_ofile_clear(fd);
	bzero((char *)&files[fd], sizeof(files[fd]));
	/* Last reference to this pipe gone: free the buffer. */
	if(p) {
		int i, j;
		for(i = 0; i < NFD; i++)
			if(files[i].pipe == p) break;
		for(j = 0; i == NFD && j < NPROCSAVE; j++) {
			if(!armproc[j].inuse) continue;
			for(i = 0; i < NFD; i++)
				if(armproc[j].files[i].pipe == p) break;
		}
		if(i == NFD) bzero((char *)&pipes[p-1], sizeof(pipes[p-1]));
	}
	if(fd < 3) closed[fd] = 1;
	return 0;
}
static int kdup(int from, int to)
{
	if(from < 0 || from >= NFD) return -1;
	/* dup of an unopened fd is EBADF, except for the early-boot console
	 * placeholder case where fds 0/1/2 may not yet have an inode but
	 * still represent the tty. */
	if(files[from].ino == 0 && from > 2) return -1;
	if(to < 0) {
		int i;
		for(i = 0; i < NFD; i++)
			if(files[i].ino == 0) break;
		if(i == NFD) return -1;
		to = i;
	}
	if(to >= NFD) return -1;
	if(files[from].ino != 0)
		bcopy((char *)&files[from], (char *)&files[to], sizeof(files[to]));
	else {
		bzero((char *)&files[to], sizeof(files[to]));
		files[to].ino = 1;
		files[to].mode = IFCHR;
	}
	closed[to] = 0;
	v7_ofile_dup(from, to);	/* bump f_count + sync ku.u_ofile */
	return to;
}
static int kseek(int fd, int off, int whence)
{
	unsigned int n;
	if(fd < 0 || fd >= NFD || files[fd].ino == 0) return -1;
	if(files[fd].pipe != 0) return -2;	/* ESPIPE marker for caller */
	switch(whence) {
	case 0:	n = (unsigned int)off;			break;
	case 1:	n = files[fd].off  + (unsigned int)off;	break;
	case 2:	n = files[fd].size + (unsigned int)off;	break;
	default: return -1;
	}
	files[fd].off = n;
	return (int)n;
}
static int kpipe(int *fdp)
{
	int f0 = -1, f1 = -1, p;
	for(int i = 0; i < NFD; i++)
		if((i >= 3 || closed[i]) && files[i].ino == 0) {
			if(f0 < 0) f0 = i;
			else { f1 = i; break; }
		}
	if(f1 < 0) return -1;
	for(p = 0; p < NPIPES; p++)
		if(!pipes[p].used) break;
	if(p == NPIPES) return -1;
	bzero((char *)&pipes[p], sizeof(pipes[p]));
	pipes[p].used = 1;
	pipes[p].writer = 1;
	bzero((char *)&files[f0], sizeof(files[f0]));
	bzero((char *)&files[f1], sizeof(files[f1]));
	files[f0].ino = files[f1].ino = 010000 + p;
	files[f0].mode = files[f1].mode = IFCHR;
	files[f0].pipe = files[f1].pipe = p+1;
	files[f1].wpipe = 1;
	closed[f0] = closed[f1] = 0;
	v7_pofile_excl_clear(f0);	/* fresh fd: no inherited EXCLOSE */
	v7_pofile_excl_clear(f1);
	fdp[0] = f0;
	fdp[1] = f1;
	return 0;
}
/* u_times bridge accessors (lean u shadow can't reach the h/user.h fields). */
/* v7_u_times_snapshot/add_child declared in local extern declarations. */
static void kdone(int pid, int ppid, int code)
{
	struct childent *c;
	if(ndone >= NFD) return;
	c = &childdone[ndone++];
	c->pid = pid; c->ppid = ppid; c->exitval = code;
	/* Snapshot u_time+u_ctime so kwait can fold on reap. */
	v7_u_times_snapshot(&c->utime, &c->stime);
}
/* Remove childdone[i], fold CPU time into c-times.  *codep = raw exit. */
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
/* Returns pid + packed status: hi byte = exit code, low 7 = signal (if 0x100 set). */
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
static void kflush(void)
{
	for(int i = 0; i < NFD; i++)
		if(fd_is_v7_reg(i)) {
			if(v7_ofile_isset(i)) sync_fd_from_v7(i);
			(void)putino(files[i].ino, &files[i]);
		}
}
/* Refresh IFREG state after mt_load_slot (ku.u_ofile entries shared with v7). */
static void restore_v7_regular_files(void)
{
	for(int i = 0; i < NFD; i++)
		if(fd_is_v7_reg(i) && v7_ofile_isset(i)) {
			sync_fd_from_v7(i);
			files[i].off = (unsigned int)v7_get_offset(i);
		}
}
static int ustat(ino_t ino, struct kfile *fp, struct ustat *st)
{
	st->st_dev = 0;
	st->st_ino = ino;
	st->st_mode = fp->mode;
	st->st_nlink = 1;
	st->st_uid = st->st_gid = 0;
	st->st_rdev = ((fp->mode & IFMT) == IFCHR ||
	    (fp->mode & IFMT) == IFBLK) ? (int)fp->addr[0] : 0;
	st->st_size = fp->size;
	st->st_atime = st->st_mtime = st->st_ctime = 0;
	return 0;
}
static int kfstat(int fd, struct ustat *st)
{
	if(fd >= 0 && fd <= 2 && files[fd].ino == 0) {
		st->st_dev = 0;
		st->st_ino = fd;
		st->st_mode = IFCHR;
		st->st_size = 0;
		return 0;
	}
	if(fd < 0 || fd >= NFD || files[fd].ino == 0)
		return -1;
	return ustat(files[fd].ino, &files[fd], st);
}
static int kexec(char *path)
{
	struct kfile fp;
	unsigned char hdr[4];
	unsigned int insn;
	ino_t ino = v7_namei_inum(path);
	if(ino == 0 || loadino(ino, &fp) < 0) return -2;	/* ENOENT */
	if((fp.mode & IFMT) != IFREG) return -13;	/* EACCES on non-regular */
	if((fp.mode & 0111) == 0) return -13;		/* EACCES: no exec bit */
	if(fp.size >= USERSIZE - UENTRY) return -2;	/* binary too big -> ENOENT-ish */
	if(fp.size < sizeof(hdr)) return -KENOEXEC;
	if(kreadi(&fp, 0, (char *)hdr, sizeof(hdr)) != (int)sizeof(hdr))
		return -5;	/* EIO -- short read from header */
	insn = (unsigned int)hdr[0]
	    | ((unsigned int)hdr[1] << 8)
	    | ((unsigned int)hdr[2] << 16)
	    | ((unsigned int)hdr[3] << 24);
	if((insn & 0xff000000U) != 0xeb000000U) return -KENOEXEC;
	bzero((char *)USERBASE, USERSIZE);
	if(kreadi(&fp, 0, (char *)UENTRY, fp.size) != (int)fp.size)
		return -5;	/* EIO -- short read from on-disk binary */
	/* Plant the sigreturn trampoline and reset non-IGN handlers. */
	volatile unsigned int *t = (volatile unsigned int *)UENTRY_SIGTRAMP;
	t[0] = 0xe3a0708bU;	/* mov r7, #139 (S_SIGRETURN)  */
	t[1] = 0xef000000U;	/* svc #0                       */
	for(int i = 1; i <= NSIG; i++)
		if(handlers[i] != SIG_IGN) handlers[i] = SIG_DFL;
	pending = 0;
	return 0;
}
/* Pack argv/envp into UARGV as NUL-separated strings, with a sentinel
 * empty string between the two sections (and another after envp).
 * crt0.c parses out of this layout.  Previous version joined argv with
 * spaces, which made `sh -c '...'` scripts that contained spaces split
 * apart inside crt0 and leaked into the env array. */
static void kargs(char *path, char **argv, char **envp)
{
	char *p;
	int n = 0;
	bzero(argbuf, sizeof(argbuf));
	if(argv != 0 && argv[0] != 0) {
		for(int i = 0; argv[i] != 0 && n < (int)sizeof(argbuf)-2; i++) {
			for(p = argv[i]; *p && n < (int)sizeof(argbuf)-2; p++)
				argbuf[n++] = *p;
			argbuf[n++] = 0;
		}
	} else {
		p = path;
		while(*p) p++;
		while(p > path && p[-1] != '/') p--;
		while(*p && n < (int)sizeof(argbuf)-2) argbuf[n++] = *p++;
		argbuf[n++] = 0;
	}
	argbuf[n++] = 0;	/* argv terminator: empty string */
	if(envp != 0)
		for(int i = 0; envp[i] != 0 && n < (int)sizeof(argbuf)-2; i++) {
			for(p = envp[i]; *p && n < (int)sizeof(argbuf)-2; p++)
				argbuf[n++] = *p;
			argbuf[n++] = 0;
		}
	argbuf[n++] = 0;	/* envp terminator */
}
/* Stash basename(path) in pcomm[slot] -- ps(1) shows it for parked
 * processes whose UARGV buffer the live USERBASE window doesn't cover. */
/* Write the 16-byte basename `name` into pcomm[] for the proc[] slot
 * currently bound to curpid.  Caller must already have a kernel-side
 * snapshot of the path because kexec() zeros USERBASE. */
static void set_pcomm(char *name)
{
	int slot = -1, n;
	for(int i = 0; i < NPROC; i++)
		if(proc[i].p_stat != 0 && proc[i].p_pid == (short)curpid) {
			slot = i; break;
		}
	if(slot < 0) return;
	for(n = 0; n < 15 && name[n]; n++) pcomm[slot][n] = name[n];
	for(; n < 16; n++) pcomm[slot][n] = 0;
}
static int kexec2(char *path, char **argv, char **envp)
{
	int e, n;
	char pname[16];
	char *p, *base = path;
	for(p = path; *p; p++) if(*p == '/') base = p + 1;
	for(n = 0; n < 15 && base[n]; n++) pname[n] = base[n];
	for(; n < 16; n++) pname[n] = 0;
	kargs(path, argv, envp);
	e = kexec(path);
	if(e == 0) {
		bzero((char *)UARGV, UARGLEN);
		bcopy(argbuf, (char *)UARGV, UARGLEN-1);
		set_pcomm(pname);
	}
	return e;
}
/* Non-static wrapper around kexec2 for v7_exec_call below. */
int v7_load_image(char *path, char **argv, char **envp)
{ return kexec2(path, argv, envp); }
/* Called by v7_exec_call's EXCLOSE sweep right after the v7 close, to
 * finish freeing the armboot-side fd slot.  Without this the slot stays
 * pinned (files[fd].ino != 0) and alloc_fd_slot keeps skipping it until
 * the per-proc fd table fills up. */
void armboot_post_exec_close(int fd)
{
	if(fd < 0 || fd >= NFD) return;
	if(files[fd].ino == 0) return;	/* nothing to free */
	if(fd_is_v7_reg(fd))
		(void)putino(files[fd].ino, &files[fd]);
	bzero((char *)&files[fd], sizeof(files[fd]));
	if(fd < 3) closed[fd] = 1;	/* mark reusable */
}
/* signal() handler install.  SIGKIL is uncatchable. */
static long ksignal(int sig, long fun)
{
	long old;
	if(sig <= 0 || sig >= NSIG || sig == SIGKIL) return -1;
	old = handlers[sig];
	handlers[sig] = fun;
	return old;
}
/* Queue sig for pid (self -> pending; parked -> armproc[].pending; dead -> no-op). */
/* v7_proc_alive declared in local extern declarations. */
static int kkill(int pid, int sig)
{
	if(sig < 0 || sig > NSIG) return -1;
	if(sig == 0) return 0;
	if(pid == curpid) { pending |= 1U << sig; return 0; }
	for(int d = 0; d < NPROCSAVE; d++)
		if(armproc[d].inuse && armproc[d].pid == pid) {
			armproc[d].pending |= 1U << sig;
			return 0;
		}
	return v7_proc_alive(pid) ? 0 : -1;
}
/* Pop saved-PC + saved-r0 + saved-lr (pushed by deliver_signal) back
 * into trap frame.  Restoring lr is critical: deliver_signal stomps
 * r[14] with the sigtramp address so the handler returns there; if we
 * don't restore the caller's lr here, the post-svc continuation's
 * `bx lr` / `bxge lr` would jump BACK to sigtramp, causing a recursive
 * sigreturn that pops garbage from a too-shallow stack -> SIGILL. */
void armboot_ksigreturn(int *r)
{
	unsigned int sp = (unsigned int)r[13];
	r[15] = (int)*(volatile unsigned int *)sp;
	r[0]  = (int)*(volatile unsigned int *)(sp + 4);
	r[14] = (int)*(volatile unsigned int *)(sp + 8);
	r[13] = (int)(sp + 12);
}
/* Redirect trap frame to pending sig's handler; push PC+r0 for ksigreturn. */
static void deliver_signal(int *r)
{
	long h;
	unsigned int sp;
	/* Merge proc[curpid].p_sig into pending (parked slots done by mt_clock_tick). */
	psig_drain(curpid, &pending);
	if(pending == 0) return;
	for(int sig = 1; sig <= NSIG; sig++) {
		if((pending & (1U << sig)) == 0) continue;
		pending &= ~(1U << sig);
		h = handlers[sig];
		if(h == SIG_IGN) continue;
		if(h == SIG_DFL) {
			/* Default = terminate; 0x100|sig flags signal-killed
			 * in the wait status.  This matches v7's signal(2)
			 * man page: SIGALRM under SIG_DFL terminates -- our
			 * libc sleep() installs a sleepx() handler so it
			 * survives, and cmd/login uses alarm(60) deliberately
			 * to time out after 60 s of no login. */
			do_exit(0x100 | sig, r);
			return;
		}
		handlers[sig] = SIG_DFL;	/* v7 one-shot */
		/* Push PC + r0 + lr (so sigreturn can restore all three).
		 * Stomping lr without saving caused the sigreturn-recursion
		 * SIGILL on syscall paths that end with `bx lr`. */
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
/* sysent[] wrappers: read u_arg[], stash u_rval1.  exit/fork/exec/signal/sigreturn inline in trap(). */
static void sys_write_v7(void)
{
	char *p;
	int n = ku.u_arg[2], fd = ku.u_arg[0];
	/* Out-of-range fd is EBADF, not a free pass to write to console. */
	if(fd < 0 || fd >= NFD) { ku.u_error = 9; return; }	/* EBADF */
	if(files[fd].kmem == 2) { ku.u_rval1 = n; return; }	/* /dev/null */
	if(files[fd].pipe != 0) {
		struct pipe *pp = &pipes[files[fd].pipe-1];
		if(files[fd].wpipe && !mt_pipe_has_reader(files[fd].pipe)) {
			ku.u_error = 32;	/* EPIPE */
			kkill(curpid, SIGPIPE);
			ku.u_rval1 = -1;
			return;
		}
		if(files[fd].wpipe && pp->wpos >= PIPESIZ) {
			/* Drain p_sig so a deliverable signal queued before
			 * the block surfaces as EINTR rather than re-block. */
			psig_drain(curpid, &pending);
			if(sig_deliverable(pending)) { ku.u_error = 4; return; }	/* EINTR */
			if(mt_pipe_has_reader(files[fd].pipe) &&
			   mt_block_on_pipe(trap_r, S_WRITE,
			       -(200 + files[fd].pipe)) == 0) {
				mt_switched = 1; return;
			}
			/* No peer -- 0-byte; writer's stdio loop gives up. */
			ku.u_rval1 = 0; return;
		}
		if(pp->wpos + (unsigned int)n > PIPESIZ)
			n = PIPESIZ - pp->wpos;
		bcopy((char *)ku.u_arg[1], pp->buf + pp->wpos, n);
		pp->wpos += n;
		ku.u_rval1 = n;
		mt_wake_pipe(files[fd].pipe, 1);	/* wake readers */
		return;
	}
	if(files[fd].mem != 0) {
		if(files[fd].off + (unsigned int)n > sizeof(tmpbuf))
			n = sizeof(tmpbuf) - files[fd].off;
		bcopy((char *)ku.u_arg[1], files[fd].mem + files[fd].off, n);
		files[fd].off += n;
		if(files[fd].off > tmpused) tmpused = files[fd].off;
		ku.u_rval1 = n;
		return;
	}
	if(files[fd].ino != 0 && (files[fd].mode & IFMT) == IFREG) {
		int w = kwritei(&files[fd], files[fd].off, (char *)ku.u_arg[1], n);
		if(w > 0) files[fd].off += w;
		ku.u_rval1 = w;
		/* Sync v7 shadow for later v7-routed fstat/close/flush. */
		if(w >= 0 && v7_ofile_isset(fd)) {
			v7_inode_refresh(fd, files[fd].size,
			    (unsigned int *)files[fd].addr);
			if(w > 0) v7_inode_mark_dirty(fd);
			v7_set_offset(fd, (long)files[fd].off);
		}
		return;
	}
	/* In-range fd but no matching property: only goes to console when
	 * it's a console fd (fd 0/1/2 with no ino set yet, or any IFCHR
	 * inode -- sh's `Ldup(dup(2), 11)` clones stderr onto a high fd
	 * for prompt output).  Other unopened fds are EBADF. */
	if(fd > 2 && (files[fd].ino == 0 || (files[fd].mode & IFMT) != IFCHR)) {
		ku.u_error = 9; return;	/* EBADF */
	}
	p = (char *)ku.u_arg[1];
	for(int i = 0; i < n; i++) putchar(p[i]);
	ku.u_rval1 = n;
}
/* kopen() drives fd alloc (avoids v7 ufalloc/pseudo-fd conflict); v7_ofile_set pins ku.u_ofile. */
static void sys_open_v7(void)
{
	int r = kopen((char *)ku.u_arg[0]);
	if(r < 0) ku.u_error = 2; else ku.u_rval1 = r;	/* ENOENT */
}
/* Like sys_open_v7; kcreat handles dirent append + fd pick. */
static void sys_creat_v7(void)
{
	int r = kcreat((char *)ku.u_arg[0], ku.u_arg[1]);
	if(r == -2) ku.u_error = 21;		/* EISDIR */
	else if(r < 0) ku.u_error = 2;		/* ENOENT */
	else ku.u_rval1 = r;
}
/* sys_{fstat,close,dup,lseek,read,write}_v7: IFREG -> v7, pseudo -> k*; sync files[fd] post. */
/* v7_fstat_call declared in local extern declarations. */
static void sys_fstat_v7(void)
{
	/* New v7_fstat_call convention: -1 = not v7-routable, 0 = success,
	 * >0 = v7 errno.  Fall back to kfstat only on -1. */
	int r = v7_fstat_call(ku.u_arg[0], (void *)ku.u_arg[1]);
	if(r == 0) { ku.u_rval1 = 0; return; }
	if(r > 0) { ku.u_error = r; return; }	/* v7-side error */
	/* r == -1: not v7-routable -- try armboot's table. */
	r = kfstat(ku.u_arg[0], (struct ustat *)ku.u_arg[1]);
	if(r < 0) ku.u_error = 9;	/* EBADF */
	else ku.u_rval1 = r;
}
static void sys_close_v7(void)
{
	int fd = ku.u_arg[0], r;
	if(fd_is_v7_reg(fd) && v7_ofile_isset(fd)) {
		sync_fd_from_v7(fd);
		r = v7_close_call(fd);
		if(r > 0) { ku.u_error = r; return; }	/* v7-side error */
		if(r < 0) { ku.u_error = 9; return; }	/* not v7-routable: EBADF */
		(void)kclose(fd);
		ku.u_rval1 = 0;
		return;
	}
	/* Pseudo-fd or non-routable: armboot path. */
	r = kclose(fd);
	if(r < 0) ku.u_error = 9; else ku.u_rval1 = r;	/* EBADF */
}
static void sys_dup_v7(void)
{
	int from = ku.u_arg[0], to = ku.u_arg[1], r;
	/* lib/compat.c::dup encoding: <0 in r1 = plain dup (we pick),
	 * >=0 = dup2(a, target). */
	if(from >= 0 && from < NFD && v7_ofile_isset(from)) {
		/* Allocate the slot from armboot's table (avoid v7 ufalloc
		 * conflict with armboot's pseudo-fd slots), then pass it to
		 * v7 as an explicit dup2 target. */
		if(to < 0 && (to = alloc_fd_slot()) < 0) { ku.u_error = 24; return; }	/* EMFILE */
		/* v7 dup() sets ku.u_error (EBADF) on a bad fd; fetch via bridge. */
		if((r = v7_dup_call(from, to)) < 0) {
			int e = v7_u_error_get();
			ku.u_error = e ? e : 9;	/* EBADF fallback */
			return;
		}
		/* Mirror files[from] -> files[r] manually -- NOT via kdup,
		 * which would double-bump f_count via v7_ofile_dup. */
		to = r;
		if(to >= 0 && to < NFD) {
			if(to != from && files[from].ino != 0)
				bcopy((char *)&files[from],
				    (char *)&files[to], sizeof(files[to]));
			closed[to] = 0;
		}
		ku.u_rval1 = r;
		return;
	}
	/* Pseudo-fd source: armboot path. */
	r = kdup(from, to);
	if(r < 0) ku.u_error = 9; else ku.u_rval1 = r;	/* EBADF */
}
static void sys_lseek_v7(void)
{
	int fd = ku.u_arg[0], off = ku.u_arg[1], whence = ku.u_arg[2], r;
	if(fd_is_v7_reg(fd) && v7_ofile_isset(fd)) {
		/* SEEK_END: refresh v7's in-core i_size from files[fd]
		 * (armboot is the authoritative writer post-iget). */
		if(whence == 2)
			v7_inode_refresh(fd, files[fd].size,
			    (unsigned int *)files[fd].addr);
		if((r = v7_lseek_call(fd, off, whence)) < 0) {
			int e = v7_u_error_get();
			ku.u_error = e ? e : 9;	/* EBADF fallback */
			return;
		}
		/* Mirror v7's f_offset back to armboot's files[fd].off. */
		files[fd].off = (unsigned int)r;
		ku.u_rval1 = r;
		return;
	}
	/* Pseudo-fd or non-routable: armboot path. */
	r = kseek(fd, off, whence);
	if(r == -2) ku.u_error = 29;		/* ESPIPE on pipe fd */
	else if(r < 0) ku.u_error = 9;		/* EBADF */
	else ku.u_rval1 = r;
}
static void sys_read_v7(void)
{
	int fd = ku.u_arg[0], r;
	char *buf = (char *)ku.u_arg[1];
	unsigned int n = (unsigned int)ku.u_arg[2];
	/* Pipe read: empty + writer alive -> block.  When the writer
	 * fills (or closes), mt_wake_pipe flips us RUN and re-fires. */
	if(fd >= 0 && fd < NFD && files[fd].pipe != 0) {
		struct pipe *pp = &pipes[files[fd].pipe-1];
		if(pp->rpos >= pp->wpos && mt_pipe_has_writer(files[fd].pipe)) {
			int rc;
			/* Drain p_sig so a deliverable signal queued before
			 * the block surfaces as EINTR rather than re-block. */
			psig_drain(curpid, &pending);
			if(sig_deliverable(pending)) { ku.u_error = 4; return; }	/* EINTR */
			while((rc = mt_block_on_pipe(trap_r, S_READ,
			                    -(100 + files[fd].pipe))) < 0) {
				/* No runnable peer right now -- spin so the clock
				 * IRQ has a chance to wake one (the writer might
				 * be sleeping on its own wait).  pause_spin_barrier
				 * defeats register caching and emits a backspace
				 * to advance qemu's virtual timer. */
				if(!mt_pipe_has_writer(files[fd].pipe)) break;
				pause_spin_barrier();
			}
			if(rc == 0) {
				mt_switched = 1;
				return;
			}
			/* Writer disappeared while spinning -- real EOF. */
		}
	}
	if(fd_is_v7_reg(fd) && v7_ofile_isset(fd)) {
		/* Refresh v7's i_size/i_addr so readi doesn't short-circuit
		 * on the stale on-disk values. */
		v7_inode_refresh(fd, files[fd].size,
		    (unsigned int *)files[fd].addr);
		v7_set_offset(fd, (long)files[fd].off);
		r = v7_read_call(fd, buf, n);
		if(r >= 0) {
			files[fd].off = (unsigned int)v7_get_offset(fd);
			ku.u_rval1 = r;
			return;
		}
		/* r == -1: v7 read() set ku.u_error; fetch via bridge.
		 * r == -2: not routable; fall through to kread. */
		if(r == -1) {
			int e = v7_u_error_get();
			ku.u_error = e ? e : 9;	/* EBADF fallback */
			return;
		}
	}
	/* Pseudo-fd / non-routable: armboot path.  kread may have set
	 * ku.u_error itself (e.g. EINTR on tty-wait); preserve. */
	r = kread(fd, buf, n);
	if(r < 0) {
		if(!ku.u_error) ku.u_error = 9;	/* EBADF fallback */
	} else ku.u_rval1 = r;
}
static void sys_pipe(void)
{
	int r = kpipe((int *)ku.u_arg[0]);
	if(r < 0) ku.u_error = 24; else ku.u_rval1 = r;	/* EMFILE: pipe table full */
}
/* Drop pid from childdone[] after v7_wait_check reaped via proc[]. */
static void kdone_drop(int pid)
{
	for(int i = 0; i < ndone; i++)
		if(childdone[i].pid == pid) {
			(void)childdone_remove(i, NULL);
			return;
		}
}
static void sys_wait(void)
{
	int r, next, my_slot, has_child = 0, ppid;
	/* Drain any signal posted to proc[curpid].p_sig (e.g. via kill) so
	 * a wait() that was parked SLEEP and then woken by a signal (rather
	 * than by do_exit) returns EINTR on retry instead of re-parking. */
	psig_drain(curpid, &pending);
	r = v7_wait_check(curpid, (int *)ku.u_arg[0]);
	if(r > 0) { ku.u_rval1 = r; kdone_drop(r); return; }
	r = kwait(curpid, (int *)ku.u_arg[0]);
	if(r >= 0) { ku.u_rval1 = r; v7_proc_reap(r); return; }
	/* No zombie: deliverable signal pending breaks the wait. */
	if(sig_deliverable(pending)) { ku.u_error = 4; return; }	/* EINTR */
	/* No zombie: park as SLEEP/-1; do_exit wakes us.  ECHILD if no
	 * child (parked, sleeping, or already in childdone[]). */
	for(int i = 0; i < NPROCSAVE && !has_child; i++)
		has_child = armproc[i].inuse && armproc[i].ppid == curpid;
	for(int i = 0; i < ndone && !has_child; i++)
		has_child = childdone[i].ppid == curpid;
	if(!has_child) { ku.u_error = 10; return; }	/* ECHILD */
	next = mt_pick_runnable();
	if(next < 0) {
		/* All children sleeping -- spin (IRQs on) until a clock IRQ
		 * wakes one.  pause_spin_barrier is a cross-TU call that
		 * defeats stale-register caching of mt_pick_runnable. */
		__asm__ volatile("cpsie i\n\tisb" ::: "memory");
		while((next = mt_pick_runnable()) < 0)
			pause_spin_barrier();
		__asm__ volatile("cpsid i" ::: "memory");
	}
	ppid = v7_get_ppid(curpid);
	if(ppid < 0) ppid = 1;
	my_slot = mt_alloc_slot(curpid, ppid, PSTATE_SLEEP);
	if(my_slot < 0) { ku.u_error = 11; return; }	/* EAGAIN: no proc slot */
	mt_save_current(my_slot, trap_r, PSTATE_SLEEP);
	armproc[my_slot].wait_for = -1;
	armproc[my_slot].frame[7]  = S_WAIT;
	armproc[my_slot].frame[15] -= 4;	/* re-execute SVC */
	mt_load_slot(next, trap_r);
	mt_switched = 1;
}
/* v7_mount_call declared in local extern declarations. */
/* v7_umount_call declared in local extern declarations. */
static void sys_mount_v7(void)
{
	int err = v7_mount_call((char *)ku.u_arg[0],
	    (char *)ku.u_arg[1], ku.u_arg[2]);
	if(err) ku.u_error = err; else ku.u_rval1 = 0;
}
static void sys_umount_v7(void)
{
	int err = v7_umount_call((char *)ku.u_arg[0]);
	if(err) ku.u_error = err; else ku.u_rval1 = 0;
}
/* v7_umask_call declared in local extern declarations. */
static void sys_umask_v7(void)
{
	ku.u_rval1 = v7_umask_call(ku.u_arg, kumask) & 0777;
	/* Keep kumask in sync so kcreat/kopen/kmknod see the new mask.
	 * Match v7 sys4.c::umask which masks to 0777 (9 bits), not 07777. */
	kumask = ku.u_arg[0] & 0777;
}
/* v7_getuid_call/getgid_call/getpid_call/getppid_call declared in local extern declarations. */
/* Mirror v7's u_cdir->i_number into cwdino (parenti's resolver agrees). */
/* v7_chdir_call/v7_chroot_call declared in local extern declarations. */
static void sys_getuid_v7(void)
{ ku.u_rval1 = v7_getuid_call(kuid); ku.u_rval2 = kuid; }
static void sys_getgid_v7(void)
{ ku.u_rval1 = v7_getgid_call(kgid); ku.u_rval2 = kgid; }
static void sys_getpid_v7(void)
{
	ku.u_rval1 = v7_getpid_call(curpid, 1);
	ku.u_rval2 = v7_getppid_call(curpid);
}
static void sys_chdir_v7(void)
{
	ino_t ino = v7_chdir_call((char *)ku.u_arg[0]);
	if(ino == 0) {
		/* v7 chdir sets v7-side ku.u_error (ENOENT/ENOTDIR/EACCES);
		 * fetch via bridge.  Pre-boot u_cdir==NULL falls through to
		 * ENOENT since v7 didn't run far enough to set ku.u_error. */
		int e = v7_u_error_get();
		ku.u_error = e ? e : 2;	/* ENOENT */
		return;
	}
	cwdino = ino;
	ku.u_rval1 = 0;
}
/* chroot affects only v7-routed syscalls (armboot's parenti is unaware). */
static void sys_chroot_v7(void)
{
	int e = v7_chroot_call((char *)ku.u_arg[0]);
	if(e) ku.u_error = e; else ku.u_rval1 = 0;
}
/* /dev/console has no on-disk dinode; chmod/chown/utime are no-op success. */
static int is_dev_console(char *p) { return strcmp(p, "/dev/console") == 0; }
/* v7_chmod_call/chown_call/utime_call/sysacct_call declared in local extern declarations.
 *
 * IMPORTANT: arm.c has its own lean `struct kuser u` (static) shadowing
 * arch/arm.c's global v7 ku.  Errors set inside v7 syscall bodies live in
 * the v7-side u and DO NOT auto-propagate to armboot's ku.  The v7_*_call
 * wrappers return v7's ku.u_error -- capture it and copy into armboot's
 * ku.u_error here, otherwise stat/chmod/... silently succeed on failure. */
static void sys_chmod_v7(void)
{
	int e;
	if(is_dev_console((char *)ku.u_arg[0])) { ku.u_rval1 = 0; return; }
	e = v7_chmod_call((char *)ku.u_arg[0], ku.u_arg[1]);
	if(e) ku.u_error = e; else ku.u_rval1 = 0;
}
static void sys_chown_v7(void)
{
	int e;
	if(is_dev_console((char *)ku.u_arg[0])) { ku.u_rval1 = 0; return; }
	e = v7_chown_call((char *)ku.u_arg[0], ku.u_arg[1], ku.u_arg[2]);
	if(e) ku.u_error = e; else ku.u_rval1 = 0;
}
static void sys_utime_v7(void)
{
	int e;
	if(is_dev_console((char *)ku.u_arg[0])) { ku.u_rval1 = 0; return; }
	e = v7_utime_call((char *)ku.u_arg[0], (void *)ku.u_arg[1]);
	if(e) ku.u_error = e; else ku.u_rval1 = 0;
}
static void sys_sysacct_v7(void)
{
	int e = v7_sysacct_call((char *)ku.u_arg[0]);
	if(e) ku.u_error = e; else ku.u_rval1 = 0;
}
static int is_tty_fd(int fd)
{
	if(fd < 0 || fd >= NFD) return 0;
	if(files[fd].ino == 0) return fd <= 2;
	return (files[fd].mode & IFMT) == IFCHR &&
	       files[fd].pipe == 0 && files[fd].kmem == 0 &&
	       (files[fd].ino == console_ino || fd <= 2);
}
static void sys_stty(void)
{
	if(!is_tty_fd(ku.u_arg[0]) || ku.u_arg[1] == 0) { ku.u_error = 25; return; }	/* ENOTTY */
	bcopy((char *)ku.u_arg[1], (char *)&console_sgtty, sizeof(console_sgtty));
	ku.u_rval1 = 0;
}
static void sys_gtty(void)
{
	if(!is_tty_fd(ku.u_arg[0]) || ku.u_arg[1] == 0) { ku.u_error = 25; return; }	/* ENOTTY */
	bcopy((char *)&console_sgtty, (char *)ku.u_arg[1], sizeof(console_sgtty));
	ku.u_rval1 = 0;
}
/* ioctl subset: FIOCLEX/FIONCLEX, TIOCGETP/TIOCSETP.  Else ENOTTY. */
static void sys_ioctl_v7(void)
{
	int fd = ku.u_arg[0], cmd = ku.u_arg[1];
	char *arg = (char *)ku.u_arg[2];
	if(fd < 0 || fd >= NFD || files[fd].ino == 0) { ku.u_error = 9; return; }	/* EBADF */
	switch(cmd) {
	case ('f' << 8) | 1:	/* FIOCLEX -- arm both kernel-side trackings.
				 * armboot's closed[] gates fd reuse; v7's
				 * u_pofile[] is what v7_exec_call sweeps. */
		closed[fd] |= 1; v7_pofile_excl_set(fd);
		ku.u_rval1 = 0; return;
	case ('f' << 8) | 2:	/* FIONCLEX */
		closed[fd] &= ~1; v7_pofile_excl_clear(fd);
		ku.u_rval1 = 0; return;
	case ('t' << 8) | 8:	/* TIOCGETP */
	case ('t' << 8) | 9:	/* TIOCSETP */
		if(!is_tty_fd(fd) || arg == 0) { ku.u_error = 25; return; }	/* ENOTTY */
		if(cmd == (('t' << 8) | 8))
			bcopy((char *)&console_sgtty, arg, sizeof(console_sgtty));
		else
			bcopy(arg, (char *)&console_sgtty, sizeof(console_sgtty));
		ku.u_rval1 = 0;
		return;
	}
	ku.u_error = 25;	/* ENOTTY */
}
/* v7_stat_call declared in local extern declarations. */
static void sys_stat_v7(void)
{
	int e = v7_stat_call((char *)ku.u_arg[0], (void *)ku.u_arg[1]);
	if(e) ku.u_error = e; else ku.u_rval1 = 0;
}
/* v7_access_call/unlink_call/link_call/exec_call declared in local extern declarations.
 * v7_exec_call loads a flat binary, runs close-on-exec, resets non-IGN
 * handlers, and stomps the trap frame. */
/* /dev/{console,mem,kmem} are pseudo-fds; short-circuit v7's namei(). */
static void sys_access_v7(void)
{
	int e;
	char *path = (char *)ku.u_arg[0];
	if(strcmp(path, "/dev/console") == 0
	    || strcmp(path, "/dev/mem") == 0
	    || strcmp(path, "/dev/kmem") == 0
	    || strcmp(path, "/dev/root") == 0) { ku.u_rval1 = 0; return; }
	e = v7_access_call(path, ku.u_arg[1]);
	if(e) ku.u_error = e; else ku.u_rval1 = 0;
}
static void sys_unlink_v7(void)
{
	int e = v7_unlink_call((char *)ku.u_arg[0]);
	if(e) ku.u_error = e; else ku.u_rval1 = 0;
}
static void sys_link_v7(void)
{
	int e = v7_link_call((char *)ku.u_arg[0], (char *)ku.u_arg[1]);
	if(e) ku.u_error = e; else ku.u_rval1 = 0;
}
static void sys_exec_v7(void)
{
	int err = v7_exec_call((char *)ku.u_arg[0], (char **)ku.u_arg[1],
	    (char **)ku.u_arg[2]);
	if(err) ku.u_error = err; else ku.u_rval1 = 0;
}
/* v7_mknod_call/sync_call/setuid_call/setgid_call declared in local extern declarations. */
static void sys_mknod_v7(void)
{
	int e = v7_mknod_call((char *)ku.u_arg[0], ku.u_arg[1], ku.u_arg[2]);
	if(e) ku.u_error = e; else ku.u_rval1 = 0;
}
static void sys_setuid_v7(void)
{
	/* v7 setuid() sets ku.u_error = EPERM for unprivileged uid mismatch. */
	int new = v7_setuid_call(kuid, ku.u_arg);
	if(!ku.u_error) { kuid = new; ku.u_rval1 = 0; }
}
static void sys_setgid_v7(void)
{
	int new = v7_setgid_call(kgid, ku.u_arg);
	if(!ku.u_error) { kgid = new; ku.u_rval1 = 0; }
}
static void sys_sync_v7(void)
{ (void)v7_sync_call(); ku.u_rval1 = 0; }
/* v7_nice_call/alarm_call/gtime_call/stime_call declared in local extern declarations. */
static void sys_nice_v7(void)
{
	(void)v7_nice_call(ku.u_arg, curpid);
	/* v7 nice() can only fail via suser() which sets EPERM -- v7_nice_call
	 * returns ku.u_error, propagate. */
	ku.u_rval1 = 0;
}
/* time(2) splits time_t low/high 16 across u_rval1/u_rval2. */
static void sys_gtime_v7(void)
{
	long t = v7_gtime_call();
	ku.u_rval1 = (int)t;
	ku.u_rval2 = (int)(t >> 16);
}
static void sys_stime_v7(void)
{ (void)v7_stime_call(ku.u_arg); ku.u_rval1 = 0; }
static void sys_alarm_v7(void)
{ ku.u_rval1 = v7_alarm_call(ku.u_arg, curpid); }
/* v7_pause_call declared in local extern declarations. */
/* pause(2): park SLEEP/-2; pre-bake r[0]=-EINTR for mt_switched resume. */
static void sys_pause_v7(void)
{
	int next, my_slot, ppid;
	/* Drain any signal sitting in proc[curpid].p_sig (e.g. SIGCLK posted
	 * between alarm(n) and pause()) so the deliverable-signal check
	 * below sees it without waiting for the next clock tick. */
	psig_drain(curpid, &pending);
	if(sig_deliverable(pending)) { ku.u_error = 4; return; }	/* EINTR */
	if((next = mt_pick_runnable()) >= 0) {
		ppid = v7_get_ppid(curpid);
		if(ppid < 0) ppid = 1;
		if((my_slot = mt_alloc_slot(curpid, ppid, PSTATE_SLEEP)) >= 0) {
			mt_save_current(my_slot, trap_r, PSTATE_SLEEP);
			armproc[my_slot].wait_for = -2;
			armproc[my_slot].frame[0]  = -4;	/* EINTR */
			mt_load_slot(next, trap_r);
			mt_switched = 1;
			return;
		}
	}
	/* No runnable peer -- fall through to the busy-spin fallback. */
	(void)v7_pause_call(&pending);
	ku.u_error = 4;	/* EINTR */
}
/* v7_ftime_call/times_call/profil_call/lock_call declared in local extern declarations.
 * Each returns v7-side ku.u_error -- capture and copy into armboot's u
 * (separate shadow struct; see sys_chmod_v7 comment). */
static void sys_ftime_v7(void)
{ int e = v7_ftime_call(ku.u_arg);  if(e) ku.u_error = e; else ku.u_rval1 = 0; }
static void sys_times_v7(void)
{ int e = v7_times_call(ku.u_arg);  if(e) ku.u_error = e; else ku.u_rval1 = 0; }
static void sys_lock_v7(void)
{ int e = v7_lock_call(ku.u_arg, curpid); if(e) ku.u_error = e; else ku.u_rval1 = 0; }
static void sys_profil_v7(void)
{ int e = v7_profil_call(ku.u_arg); if(e) ku.u_error = e; else ku.u_rval1 = 0; }
/* v7 kill -> psignal->setrun (armboot_setrun); we also poke armproc[].pending.
 * v7_kill_call declared in local extern declarations. */
static void sys_kill_v7(void)
{
	int tgt = ku.u_arg[0], sig = ku.u_arg[1];
	int r;
	/* v7 psignal silently drops sig >= NSIG; POSIX EINVAL. */
	if(sig < 0 || sig >= NSIG) { ku.u_error = 22; return; }	/* EINVAL */
	r = v7_kill_call(ku.u_arg, kuid, curpid);
	if(r < 0) { ku.u_error = -r; return; }	/* ESRCH/EPERM */
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
/* v7 trap.c::nosys -- "invalid syscall number" returns EINVAL. */
static void sys_nosys(void) { ku.u_error = 22; }
/* v7 trap.c::nullsys -- "syscall slot reserved but does nothing"
 * silently succeeds.  Used by slots 0 (indir), 38 (switch), 39
 * (setpgrp not in yet) -- matching v7/usr/sys/sys/sysent.c. */
static void sys_nullsys(void) { }
/* break(2): v7 sys1.c::sbreak() adjusts ku.u_dsize via expand().  On this
 * port copyseg/clearseg are no-ops (everything stays resident), so sbreak
 * just records the new data-segment size into the v7 u struct. */
extern void sbreak(void);
static void sys_break_v7(void) { sbreak(); }
/* ptrace(2): v7 sys/sig.c::ptrace() coordinates parent/child via ipc
 * struct + setrun/sleep on (caddr_t)&ipc.  The ARM port's setrun/sleep
 * stubs are eager (sys/arch/arm.c), so ptrace will return ESRCH unless
 * the child is also using the v7 sleep loop -- sufficient for adb(1)
 * compile-and-link, exercised behaviour is out of scope. */
extern void ptrace(void);
static void sys_ptrace_v7(void) { ptrace(); }
/* sysent[N] = (narg, handler); pairs of slots per line.  Slots that v7
 * mapped to `nullsys` (silent success) use sys_nullsys here; slots that
 * v7 mapped to `nosys` (EINVAL) use sys_nosys.  Slots 1 (exit), 2
 * (fork), 48 (signal) and 139 (sigreturn) are handled inline in trap()
 * so their entries are never actually dispatched. */
static struct sysent {
	int	sy_narg;
	void	(*sy_call)(void);
} sysent[64] = {
	/* 0 indir, 1 exit */		{0, sys_nullsys},   {1, sys_nosys},
	/* 2 fork, 3 read */		{0, sys_nosys},     {3, sys_read_v7},
	/* 4 write, 5 open */		{3, sys_write_v7},  {2, sys_open_v7},
	/* 6 close, 7 wait */		{1, sys_close_v7},  {1, sys_wait},
	/* 8 creat, 9 link */		{2, sys_creat_v7},  {2, sys_link_v7},
	/* 10 unlink, 11 exec */	{1, sys_unlink_v7}, {3, sys_exec_v7},
	/* 12 chdir, 13 time */		{1, sys_chdir_v7},  {0, sys_gtime_v7},
	/* 14 mknod, 15 chmod */	{3, sys_mknod_v7},  {2, sys_chmod_v7},
	/* 16 chown, 17 break */	{3, sys_chown_v7},  {1, sys_break_v7},
	/* 18 stat, 19 lseek */		{2, sys_stat_v7},   {3, sys_lseek_v7},
	/* 20 getpid, 21 mount */	{0, sys_getpid_v7}, {3, sys_mount_v7},
	/* 22 umount, 23 setuid */	{1, sys_umount_v7}, {1, sys_setuid_v7},
	/* 24 getuid, 25 stime */	{0, sys_getuid_v7}, {1, sys_stime_v7},
	/* 26 ptrace, 27 alarm */	{4, sys_ptrace_v7}, {1, sys_alarm_v7},
	/* 28 fstat, 29 pause */	{2, sys_fstat_v7},  {0, sys_pause_v7},
	/* 30 utime, 31 stty */		{2, sys_utime_v7},  {2, sys_stty},
	/* 32 gtty, 33 access */	{2, sys_gtty},      {2, sys_access_v7},
	/* 34 nice, 35 ftime */		{1, sys_nice_v7},   {1, sys_ftime_v7},
	/* 36 sync, 37 kill */		{0, sys_sync_v7},   {2, sys_kill_v7},
	/* 38 switch, 39 setpgrp */	{0, sys_nullsys},   {0, sys_nullsys},
	/* 40 tell, 41 dup */		{0, sys_nosys},     {2, sys_dup_v7},
	/* 42 pipe, 43 times */		{1, sys_pipe},      {1, sys_times_v7},
	/* 44 prof, 45 */		{4, sys_profil_v7}, {0, sys_nosys},
	/* 46 setgid, 47 getgid */	{1, sys_setgid_v7}, {0, sys_getgid_v7},
	/* 48 signal, 49 */		{2, sys_nosys},     {0, sys_nosys},
	/* 50, 51 acct */		{0, sys_nosys},     {1, sys_sysacct_v7},
	/* 52, 53 lock */		{0, sys_nosys},     {1, sys_lock_v7},
	/* 54 ioctl, 55 */		{3, sys_ioctl_v7},  {0, sys_nosys},
	/* 56, 57 */			{0, sys_nosys},     {0, sys_nosys},
	/* 58, 59 exece */		{0, sys_nosys},     {3, sys_exec_v7},
	/* 60 umask, 61 chroot */	{1, sys_umask_v7},  {1, sys_chroot_v7},
	/* 62, 63 */			{0, sys_nosys},     {0, sys_nosys},
};
/* v7_save_qsav declared in local extern declarations. */
static void sysent_dispatch(int n)
{
	ku.u_error = 0;
	ku.u_rval1 = ku.u_rval2 = 0;
	if(n < 0 || n >= 64) { ku.u_error = 22; return; }	/* EINVAL */
	for(int i = 0; i < sysent[n].sy_narg && i < 6; i++)
		ku.u_arg[i] = trap_r[i];
	/* Seed u_qsav; sleep() in the handler longjmps back here on a
	 * caught signal, returning 1 and skipping the syscall (already
	 * EINTR'd by sig.c::psig). */
	if(v7_save_qsav()) return;
	(*sysent[n].sy_call)();
}
/* clock_irq_handler skips v7 clock() when set (avoid trap() re-entry). */
volatile int in_trap;
/* From S_EXIT / deliver_signal SIG_DFL: reparent->init, flush fds, record code, wake, switch peer. */
void do_exit(int code, int *r)
{
	int my_pid = curpid, next, ppid = v7_get_ppid(my_pid);
	/* Orphans go to init (pid 1), not 0 -- matches v7's exit() and
	 * keeps childdone[] entries reachable from a real wait()er. */
	if(ppid < 0) ppid = 1;
	v7_reparent_children(my_pid, 1);
	for(int i = 0; i < NPROCSAVE; i++)
		if(armproc[i].inuse && armproc[i].ppid == my_pid)
			armproc[i].ppid = 1;
	for(int i = 0; i < ndone; i++)
		if(childdone[i].ppid == my_pid)
			childdone[i].ppid = 1;
	v7_proc_exit(my_pid, code);
	kflush();
	/* Drop pipe FDs so pipes[] entry frees when last ref leaves; otherwise
	 * NPIPES=4 fills up after a handful of `cmd | nonexistent` runs. */
	for(int i = 0; i < NFD; i++)
		if(files[i].pipe != 0) (void)kclose(i);
	v7_ofile_drop_all();
	acct();
	kdone(my_pid, ppid, code);
	(void)mt_wake_waiters(my_pid, ppid);
	if((next = mt_pick_runnable()) >= 0) {
		mt_load_slot(next, r);
		deliver_signal(r); in_trap = 0; return;
	}
	for(;;);	/* last proc exited (init shouldn't reach here) */
}
void trap(int *r)
{
	int n = r[7], ret = -1;
	in_trap = 1;
	trap_frame = trap_r = r;	/* mirror into v7-visible global */
	/* v7 _exit only honors the low 8 bits; mask to keep our internal
	 * 0x100 signal-killed flag bit out of user-supplied codes. */
	if(n == S_EXIT) { do_exit(r[0] & 0xff, r); return; }
	if(n == S_FORK) {
		int new_pid = nextpid, parent_pid = curpid;
		int slot = mt_alloc_slot(new_pid, parent_pid, PSTATE_RUN);
		if(slot >= 0) {
			struct armproc *a = &armproc[slot];
			v7_ofile_fork_bump();
			mt_save_current(slot, r, PSTATE_RUN);
			/* Parent stays live -- restore u_times that
			 * mt_save_current zeroed; the child slot keeps the
			 * snapshot only as a placeholder before we zero it. */
			v7_u_times_restore(a->utime, a->stime, a->cutime, a->cstime);
			/* Per POSIX/v7 newproc: child starts with all CPU
			 * times = 0 so the eventual wait()-time fold doesn't
			 * double-count the parent's pre-fork u_utime. */
			a->utime = a->stime = a->cutime = a->cstime = 0;
			a->pid = new_pid;
			a->ppid = parent_pid;
			a->pending = 0;
			a->frame[0] = 0;	/* child fork ret */
			if(v7_proc_fork(parent_pid, new_pid) < 0) {
				/* proc[] full (rare: NPROC=150 vs NPROCSAVE=32):
				 * back out the armproc slot so we don't leave the
				 * child with no proc[] entry to anchor curpid.
				 * Drop the cdir/rdir refs mt_save_current iget'd
				 * so they don't leak. */
				v7_inode_drop(a->cdir);
				v7_inode_drop(a->rdir);
				proc_free_slot(slot);
				v7_proc_set_current(parent_pid);
				ret = -11;	/* EAGAIN */
				goto fork_fail;
			}
			nextpid++;
			v7_proc_set_current(parent_pid);
			r[0] = new_pid;
			in_trap = 0; return;
		}
		/* slot pool full -- v7 fork(2) returns EAGAIN here. */
		ret = -11;	/* EAGAIN */
fork_fail:	;
	}
	else if(n == S_SIGNAL) {
		long old;
		(void)v7_signal_call(r[0], r[1], curpid);
		old = ksignal(r[0], (long)(unsigned int)r[1]);
		/* ksignal returns -1 for invalid signo (out of range or
		 * SIGKIL).  v7 signal(2) returns EINVAL for that case; map
		 * to -EINVAL so userspace's SYS macro picks the right
		 * errno.  Non-negative returns are previous handler. */
		r[0] = (old == -1) ? -22 : (int)old;
		deliver_signal(r); in_trap = 0; return;
	}
	else if(n == S_SIGRETURN) {
		(void)v7_sigreturn_call(r);
		deliver_signal(r); in_trap = 0; return;
	}
	else {
		sysent_dispatch(n);
		ret = ku.u_error ? -ku.u_error : ku.u_rval1;
	}
	if(mt_switched) {
		/* mid-syscall context switch -- r now points at the
		 * resumed proc's frame whose r[0] is already correct. */
		mt_switched = 0;
		deliver_signal(r); in_trap = 0; return;
	}
	r[0] = ret;
	if(ret >= 0) r[1] = ku.u_rval2;	/* getpid/pipe pdp11 two-return */
	(void)mt_preempt(r);	/* timeslice preemption (falls through) */
	deliver_signal(r);
	in_trap = 0;
}
/* From arm.s::user_trap_common (user undef/abort): post signo, deliver. */
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
void panictrap(void) { panic("trap"); }
void armboot(void)
{
	ino_t cino;
	for(int i = 0; i < 3; i++) {
		files[i].ino = 1;
		files[i].mode = IFCHR;
	}
	shim_bread(SUPERB, blkbuf);
#ifdef EVB
	/* Sanity-print: prove bio() returned a real V7 superblock.  Decode
	 * isize/fsize raw -- struct padding makes field access unsafe. */
	{
		unsigned int isize = (unsigned int)blkbuf[0]
		    | ((unsigned int)blkbuf[1] << 8);
		unsigned int fsize = (unsigned int)blkbuf[2]
		    | ((unsigned int)blkbuf[3] << 8)
		    | ((unsigned int)blkbuf[4] << 16)
		    | ((unsigned int)blkbuf[5] << 24);
		printf("evb: rootfs isize=%d fsize=%d\n",
		    (int)isize, (int)fsize);
	}
#endif
	if(((struct filsys *)blkbuf)->s_isize == 0) panic("fs");
	scanfs();
	/* Bind console pseudo-fds 0/1/2 to /dev/console's real inum so
	 * fstat agrees with ttyname/ttyslot for login + utmp/wtmp. */
	cino = v7_namei_inum("/dev/console");
	if(cino != 0) {
		console_ino = cino;
		for(int i = 0; i < 3; i++) files[i].ino = cino;
	}
	(void)v7_mount_init();
	v7_proc_init();
	{ char *s; s = "swapper"; for(int i = 0; i < 8; i++) pcomm[0][i] = s[i];
	  s = "init"; for(int i = 0; i < 5; i++) pcomm[1][i] = s[i]; }
#ifdef EVB
	/* EVB bring-up sentinels: verify namei() and kexec() before
	 * run_user, so a failure inside the loader shows up next. */
	{
		ino_t initino = v7_namei_inum("/etc/init");
		printf("evb: init inum=%d\n", (int)initino);
	}
	{
		int rc = kexec("/etc/init");
		if (rc < 0) {
			printf("evb: kexec fail rc=%d\n", rc);
			panic("init");
		}
		printf("evb: kexec ok\n");
	}
#else
	if(kexec("/etc/init") < 0)
		panic("init");
#endif
	{ extern void arm_timer_init(void); arm_timer_init(); }
	run_user(UENTRY, USTACK);
}
/* v7 syscall bridge: hands v7 syscalls to K&R impls in sys/sys{2,3,4}.c using
 * arch/arm.c's `struct user u`; arm.c has its own static shadow. */
/* v7 syscall entry points (in sys/sys{2,3,4}.c, sig.c). */
extern void umask(void), getuid(void), getgid(void), getpid(void);
extern void setuid(void), setgid(void), sync(void), nice(void);
extern void gtime(void), stime(void), alarm(void), ftime(void), times(void);
extern void kill(void), ssig(void), chdir(void), chmod(void), chown(void);
extern void sysacct(void), utime(void), profil(void), syslock(void);
extern void stat(void), fstat(void), saccess(void), unlink(void), link(void);
extern void mknod(void), smount(void), sumount(void);
extern void close(void), dup(void), seek(void), read(void);
extern void iput(struct inode *ip);
extern struct file file[];
extern void pause_spin_barrier(void);
extern struct inode *namei(int (*func)(void), int flag);
extern struct inode *iget(dev_t dev, ino_t ino);
extern int uchar(void);
extern struct proc proc[];
/* Cross-TU handle on active trap-frame regs (set by trap(); v7 TUs read/stomp). */
int *trap_frame;
/* Look up the live proc[] slot for `pid`, or NULL if not present. */
static struct proc * proc_by_pid(int pid)
{
	for(int i = 0; i < NPROC; i++)
		if(proc[i].p_stat != 0 && proc[i].p_pid == (short)pid)
			return &proc[i];
	return NULL;
}
/* Init proc[i] as minimal SRUN anchor (sys4.c kill guard reserves proc[0]/[1]). */
static void proc_anchor(int i, short pid, short pgrp, char pri)
{
	struct proc *p = &proc[i];
	p->p_stat = SRUN; p->p_flag = SLOAD;
	p->p_pid = pid; p->p_ppid = 0; p->p_uid = 0;
	p->p_pgrp = pgrp; p->p_pri = pri; p->p_nice = NZERO;
	p->p_sig = p->p_time = p->p_cpu = p->p_clktim = 0;
}
void v7_proc_init(void)
{
	proc_anchor(0, 0, 0, 0);	/* swapper placeholder */
	proc_anchor(1, 1, 1, 40);	/* init */
	/* p_addr/p_size = descriptor of the live USERBASE window so ps
	 * recovers argv via /dev/mem. */
	proc[1].p_addr = (short)(UARGV >> 6);
	proc[1].p_size = (short)(UARGLEN >> 6);
	u.u_procp = &proc[1];
}
/* proc[] bookkeeping mirroring armboot's save-pool: fork finds slot
 * >=2 (proc[0]/[1] are anchors); exit SZOMB; reap frees. */
extern char pcomm[NPROC][16];
int v7_proc_fork(int parent_pid, int child_pid)
{
	struct proc *pp = proc_by_pid(parent_pid);
	short parent_pgrp = pp ? pp->p_pgrp : (short)child_pid;
	short parent_nice = pp ? pp->p_nice : NZERO;
	short parent_uid = pp ? pp->p_uid : 0;
	int parent_slot = pp ? (int)(pp - proc) : -1;
	int i;
	/* Skip proc[0]/proc[1] (kill 0/pgrp guard reserves them). */
	for(i = 2; i < NPROC; i++)
		if(proc[i].p_stat == 0) break;
	if(i >= NPROC) return -1;
	pp = &proc[i];
	pp->p_stat = SRUN; pp->p_flag = SLOAD; pp->p_pri = 40;
	pp->p_nice = parent_nice; pp->p_uid = parent_uid;
	pp->p_pgrp = parent_pgrp;
	pp->p_pid = (short)child_pid; pp->p_ppid = (short)parent_pid;
	pp->p_time = pp->p_cpu = pp->p_sig = pp->p_clktim = 0;
	pp->p_wchan = 0; pp->p_addr = 0; pp->p_size = 0;
	pp->p_textp = NULL; pp->p_link = NULL;
	if(parent_slot >= 0 && parent_slot < NPROC)
		for(int k = 0; k < 16; k++) pcomm[i][k] = pcomm[parent_slot][k];
	return 0;
}
void v7_proc_exit(int curpid, int code)
{
	struct proc *pp = proc_by_pid(curpid);
	if(pp) {
		pp->p_stat = SZOMB;
		pp->p_clktim = code;	/* hijacked: holds exit code */
		pp->p_sig = 0;
	}
}
void v7_proc_reap(int pid)
{
	for(int i = 0; i < NPROC; i++)
		if(proc[i].p_stat == SZOMB && proc[i].p_pid == (short)pid) {
			struct proc *p = &proc[i];
			p->p_stat = p->p_flag = 0;
			p->p_pid = p->p_ppid = p->p_pgrp = 0;
			p->p_uid = p->p_sig = p->p_clktim = 0;
			for(int k = 0; k < 16; k++) pcomm[i][k] = 0;
			return;
		}
}
/* Reap a SZOMB child of parent_pid; -1 if none (caller falls back to childdone[]). */
int v7_wait_check(int parent_pid, int *status)
{
	for(int i = 1; i < NPROC; i++)
		if(proc[i].p_stat == SZOMB &&
		   proc[i].p_ppid == (short)parent_pid) {
			int code = proc[i].p_clktim, pid = proc[i].p_pid;
			if(status)
				*status = (code & 0x100) ? (code & 0x7f)
				                         : ((code & 0xff) << 8);
			v7_proc_reap(pid);
			return pid;
		}
	return -1;
}
/* p_addr/p_size: ps reads argv at p_addr*64+p_size*64-512 (UARGV/0 for others). */
void v7_proc_set_current(int pid)
{
	struct proc *me = proc_by_pid(pid);
	for(int i = 0; i < NPROC; i++)
		if(proc[i].p_stat != 0)
			proc[i].p_addr = proc[i].p_size = 0;
	if(me) {
		me->p_addr = (short)(UARGV >> 6);
		me->p_size = (short)(UARGLEN >> 6);
		u.u_procp = me;
	} else
		u.u_procp = &proc[1];	/* fall back to init */
}
int v7_get_ppid(int pid)
{
	struct proc *pp = proc_by_pid(pid);
	return pp ? (int)pp->p_ppid : -1;
}
int v7_proc_alive(int pid)
{
	struct proc *pp = proc_by_pid(pid);
	return pp && pp->p_stat != SZOMB;
}
/* Set p_stat for pid's slot.  Skips proc[0] (anchor) and SZOMB. */
int v7_proc_set_stat(int pid, int stat)
{
	struct proc *pp = proc_by_pid(pid);
	if(pp == NULL || pp == &proc[0] || pp->p_stat == SZOMB) return -1;
	pp->p_stat = (char)stat;
	return 0;
}
/* Common syscall prologue: stash args, clear error+rvals. */
static void v7_call_prep(int *args)
{
	u.u_ap = args;
	u.u_error = 0;
	u.u_r.r_val1 = u.u_r.r_val2 = 0;
}
/* Sync u_cmask before umask() so sh's `umask(i=umask(0))` sees right mask. */
int v7_umask_call(int *args, int kumask)
{
	u.u_cmask = (short)kumask;
	v7_call_prep(args); umask(); return u.u_r.r_val1;
}
int v7_getuid_call(int kuid)
{
	u.u_uid = u.u_ruid = (short)kuid;
	v7_call_prep(NULL); getuid(); return u.u_r.r_val1;
}
int v7_getgid_call(int kgid)
{
	u.u_gid = u.u_rgid = (short)kgid;
	v7_call_prep(NULL); getgid(); return u.u_r.r_val1;
}
int v7_getpid_call(int curpid, int ppid)
{
	(void)ppid;
	v7_proc_set_current(curpid);
	if(u.u_procp == NULL || u.u_procp == &proc[0]) u.u_procp = &proc[1];
	v7_call_prep(NULL); getpid();
	return u.u_r.r_val1;
}
int v7_getppid_call(int curpid)
{
	v7_proc_set_current(curpid);
	if(u.u_procp == NULL || u.u_procp == &proc[0]) u.u_procp = &proc[1];
	return (int)u.u_procp->p_ppid;
}
int v7_setuid_call(int kuid, int *args)
{
	u.u_uid = u.u_ruid = proc[0].p_uid = (short)kuid;
	u.u_procp = &proc[0];
	v7_call_prep(args); setuid(); return u.u_uid;
}
int v7_setgid_call(int kgid, int *args)
{
	u.u_gid = u.u_rgid = (short)kgid;
	u.u_uid = u.u_ruid = 0;	/* root-only -- bypass suser() */
	v7_call_prep(args); setgid(); return u.u_gid;
}
int v7_sync_call(void)
{ v7_call_prep(NULL); sync(); return 0; }
/* Anchor u.u_procp on caller so nice's p_nice delta hits the right slot. */
int v7_nice_call(int *args, int curpid)
{
	struct proc *me = proc_by_pid(curpid);
	if(me == NULL) me = &proc[0];
	u.u_procp = me;
	u.u_uid = u.u_ruid = me->p_uid;
	v7_call_prep(args); nice();
	return me->p_nice;
}
long v7_gtime_call(void)
{
	u.u_error = 0;
	u.u_r.r_time = 0;	/* clear other half of the union too */
	gtime(); return u.u_r.r_time;
}
long v7_stime_call(int *args)
{
	u.u_uid = u.u_ruid = 0;
	v7_call_prep(args); stime();
	return time;
}
int v7_alarm_call(int *args, int curpid)
{
	v7_proc_set_current(curpid);
	v7_call_prep(args); alarm();
	return u.u_r.r_val1;
}
/* sys_pause_v7 fallback (no runnable peer): spin IRQs-on watching pending/p_sig. */
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
		/* Cross-TU call: forces pp spill+reload + dmb each iter
		 * so the optimizer can't cache p_sig stale. */
		pause_spin_barrier();
	}
	__asm__ volatile("cpsid i" ::: "memory");
	u.u_error = u.u_r.r_val1 = 0;
	return 0;
}
int v7_ftime_call(int *args)
{ v7_call_prep(args); ftime(); return u.u_error; }
/* v7 kill() walks proc[] and psignal()s matches.  0 ok, -errno fail. */
int v7_kill_call(int *args, int kuid, int curpid)
{
	u.u_uid = u.u_ruid = (short)kuid;
	v7_proc_set_current(curpid);
	v7_call_prep(args); kill();
	return u.u_error ? -u.u_error : 0;
}
/* Mirror disposition into v7 u.u_signal[]; handlers[] synced by ksignal(). */
int v7_signal_call(int signo, int func, int curpid)
{
	int args[2] = { signo, func };
	v7_proc_set_current(curpid);
	u.u_uid = u.u_ruid = 0;
	v7_call_prep(args); ssig();
	return u.u_error ? -1 : u.u_r.r_val1;
}
int v7_times_call(int *args)
{ v7_call_prep(args); times(); return u.u_error; }
/* snapshot: child runtime + reaped grandchildren.  add_child: fold into c-times. */
void v7_u_times_snapshot(long *utp, long *stp)
{
	*utp = (long)u.u_utime + (long)u.u_cutime;
	*stp = (long)u.u_stime + (long)u.u_cstime;
}
void v7_u_times_add_child(long ut, long st)
{ u.u_cutime += ut; u.u_cstime += st; }
/* u.u_prof is global, not per-proc -- last profil() caller wins. */
int v7_profil_call(int *args)
{ v7_call_prep(args); profil(); return u.u_error; }
/* Swapless port: SULOCK has no effect but the surface still succeeds. */
int v7_lock_call(int *args, int curpid)
{
	v7_proc_set_current(curpid);
	u.u_uid = u.u_procp->p_uid;
	v7_call_prep(args); syslock();
	return u.u_error;
}
/* Save/restore u_times around ctx switch (save zeros live for next proc). */
void v7_u_times_save(long *out_utime, long *out_stime,
                     long *out_cutime, long *out_cstime)
{
	*out_utime  = (long)u.u_utime;
	*out_stime  = (long)u.u_stime;
	*out_cutime = (long)u.u_cutime;
	*out_cstime = (long)u.u_cstime;
	u.u_utime = u.u_stime = u.u_cutime = u.u_cstime = 0;
}
void v7_u_times_restore(long in_utime, long in_stime,
                        long in_cutime, long in_cstime)
{
	u.u_utime  = (time_t)in_utime;
	u.u_stime  = (time_t)in_stime;
	u.u_cutime = (time_t)in_cutime;
	u.u_cstime = (time_t)in_cstime;
}
/* psignal every proc in caller's pgrp (mirrors v7 tty.c intrc/quitc). */
extern void psignal(struct proc *p, int sig);
void v7_signal_pgrp(int sig, int curpid)
{
	struct proc *me = proc_by_pid(curpid);
	short pgrp;
	if(me == NULL || (pgrp = me->p_pgrp) == 0) return;
	for(int i = 2; i < NPROC; i++)	/* skip swapper + init */
		if(proc[i].p_stat != 0 && proc[i].p_pgrp == pgrp)
			psignal(&proc[i], sig);
}
/* v7 sleep() longjmps via u.u_qsav.  0=save (proceed), 1=longjmp (EINTR). */
/* save() declared in local declarations. */
extern void bcopy(char *, char *, unsigned int);
int v7_save_qsav(void) { return save((int *)u.u_qsav); }
/* Per-proc u_qsav save/restore (label_t = 10 ints). */
void v7_u_qsav_save(int *dst)
{ bcopy((char *)u.u_qsav, (char *)dst, sizeof(u.u_qsav)); }
void v7_u_qsav_restore(const int *src)
{ bcopy((char *)src, (char *)u.u_qsav, sizeof(u.u_qsav)); }
/* Hand children of a dying proc to init=1 (mirrors sys/sys1.c::exit). */
void v7_reparent_children(int dying_pid, int new_ppid)
{
	for(int i = 0; i < NPROC; i++)
		if(proc[i].p_stat != 0 && proc[i].p_ppid == (short)dying_pid)
			proc[i].p_ppid = (short)new_ppid;
}
/* Per-slot save/restore of u.u_signal[0..NSIG-1] disposition. */
void v7_u_signal_save(long *out_sig)
{
	for(int i = 0; i < NSIG; i++) out_sig[i] = (long)u.u_signal[i];
}
void v7_u_signal_restore(const long *in_sig)
{
	for(int i = 0; i < NSIG; i++) u.u_signal[i] = (int)in_sig[i];
}
/* Preserve u.u_cdir across ctx via held iget ref.  Restore iputs the
 * outgoing live ref so the count balances across save/restore pairs;
 * earlier "leaks 1/save" version drained NINODE after ~80 cycles and
 * eventually wiped the rootdir slot. */
void *v7_cdir_save(void)
{
	struct inode *ip = u.u_cdir, *held;
	if(ip == NULL) return NULL;
	held = iget(ip->i_dev, ip->i_number);
	if(held) held->i_flag &= ~ILOCK;
	return (void *)held;
}
void v7_cdir_restore(void *p)
{
	struct inode *old = u.u_cdir;
	u.u_cdir = (struct inode *)p;
	if(old) iput(old);
}
/* u.u_rdir tracks chroot(2)'s root for name lookups.  v7 stored it in
 * the per-proc u area which was swapped in/out -- on this port struct
 * user is global, so chroot from one process would leak into siblings
 * if we didn't checkpoint it across context switches.  Mirror the cdir
 * dance: iget a held ref into the armproc slot, iput the live one on
 * restore.  NULL is the legitimate "no chroot" state and must round-
 * trip as NULL, not as rootdir, so unchrooted procs see the full tree. */
void *v7_rdir_save(void)
{
	struct inode *ip = u.u_rdir, *held;
	if(ip == NULL) return NULL;
	held = iget(ip->i_dev, ip->i_number);
	if(held) held->i_flag &= ~ILOCK;
	return (void *)held;
}
void v7_rdir_restore(void *p)
{
	struct inode *old = u.u_rdir;
	u.u_rdir = (struct inode *)p;
	if(old) iput(old);
}
/* Common path-syscall prologue: seed uid=0, set u_dirp/segflg/u_ap, clear err/rvals. */
static void v7_path_prep(char *path, int *args)
{
	u.u_uid = u.u_ruid = 0;
	u.u_dirp = (caddr_t)path;
	u.u_segflg = 1;
	u.u_ap = args;
	u.u_error = 0;
	u.u_r.r_val1 = u.u_r.r_val2 = 0;
}
ino_t v7_chdir_call(char *path)
{
	v7_path_prep(path, NULL); chdir();
	return (u.u_error || u.u_cdir == NULL) ? (ino_t)0 : u.u_cdir->i_number;
}
extern void chroot(void);
int v7_chroot_call(char *path)
{
	v7_path_prep(path, NULL); chroot();
	return u.u_error;
}
int v7_chmod_call(char *path, int mode)
{
	int args[2] = { (int)(long)path, mode };
	v7_path_prep(path, args); chmod(); return u.u_error;
}
int v7_sysacct_call(char *path)
{
	int args[1] = { (int)(long)path };
	v7_path_prep(path, args); sysacct(); return u.u_error;
}
int v7_chown_call(char *path, int uid, int gid)
{
	int args[3] = { (int)(long)path, uid, gid };
	v7_path_prep(path, args); chown(); return u.u_error;
}
int v7_utime_call(char *path, void *tptr)
{
	int args[2] = { (int)(long)path, (int)(long)tptr };
	v7_path_prep(path, args); utime(); return u.u_error;
}
int v7_stat_call(char *path, void *ubuf)
{
	int args[2] = { (int)(long)path, (int)(long)ubuf };
	v7_path_prep(path, args); stat(); return u.u_error;
}
int v7_access_call(char *path, int mode)
{
	int args[2] = { (int)(long)path, mode };
	v7_path_prep(path, args);
	u.u_gid = u.u_rgid = 0;
	saccess(); return u.u_error;
}
int v7_unlink_call(char *path)
{
	int args[1] = { (int)(long)path };
	v7_path_prep(path, args); unlink(); return u.u_error;
}
/* u_dirp = from for first namei; link() resets to linkname for second. */
int v7_link_call(char *from, char *to)
{
	int args[2] = { (int)(long)from, (int)(long)to };
	v7_path_prep(from, args); link(); return u.u_error;
}
int v7_mknod_call(char *path, int mode, int dev)
{
	int args[3] = { (int)(long)path, mode, dev };
	v7_path_prep(path, args);
	u.u_gid = u.u_rgid = 0;
	mknod(); return u.u_error;
}
int v7_mount_call(char *special, char *dir, int ro)
{
	int args[3] = { (int)(long)special, (int)(long)dir, ro };
	v7_path_prep(special, args); smount(); return u.u_error;
}
int v7_umount_call(char *special)
{
	int args[1] = { (int)(long)special };
	v7_path_prep(special, args); sumount(); return u.u_error;
}
/* v7_ofile_*: pin v7 file-table slot per IFREG fd (struct file + iget
 * + u.u_ofile).  Pseudo-fds skip; v7_ofile_clear avoids closef stub. */
extern dev_t rootdev;
void v7_ofile_clear(int fd);
void v7_ofile_set(int fd, ino_t ino, int flag)
{
	struct inode *ip;
	struct file *fp;
	if(fd < 0 || fd >= NOFILE) return;
	if(u.u_ofile[fd]) v7_ofile_clear(fd);	/* drop stale entry */
	if((ip = iget(rootdev, ino)) == NULL) return;
	ip->i_flag &= ~ILOCK;
	for(fp = &file[0]; fp < &file[NFILE]; fp++)
		if(fp->f_count == 0) {
			fp->f_count = 1;
			fp->f_flag = (char)flag;
			fp->f_inode = ip;
			fp->f_un.f_offset = 0;
			u.u_ofile[fd] = fp;
			u.u_pofile[fd] = 0;
			return;
		}
	iput(ip);	/* file[] full -- back out */
}
void v7_ofile_clear(int fd)
{
	struct file *fp;
	struct inode *ip;
	if(fd < 0 || fd >= NOFILE) return;
	if((fp = u.u_ofile[fd]) == NULL) return;
	u.u_ofile[fd] = NULL;
	u.u_pofile[fd] = 0;
	if(fp->f_count > 1) { fp->f_count--; return; }
	ip = fp->f_inode;
	fp->f_count = 0;
	fp->f_inode = NULL;
	fp->f_flag = 0;
	fp->f_un.f_offset = 0;
	if(ip) iput(ip);
}
void v7_ofile_dup(int from, int to)
{
	struct file *fp;
	if(from < 0 || from >= NOFILE || to < 0 || to >= NOFILE) return;
	fp = u.u_ofile[from];
	if(fp == NULL) {
		/* pseudo-fd source: just clear destination. */
		if(u.u_ofile[to]) v7_ofile_clear(to);
		return;
	}
	if(u.u_ofile[to] == fp) return;	/* idempotent */
	if(u.u_ofile[to]) v7_ofile_clear(to);
	u.u_ofile[to] = fp;
	u.u_pofile[to] = 0;
	fp->f_count++;
}
/* Fork helpers: save/restore u_ofile[], fork_bump f_count, drop_all iputs. */
void v7_ofile_save(void *buf)
{ bcopy((char *)u.u_ofile, (char *)buf, sizeof(u.u_ofile)); }
void v7_ofile_restore(void *buf)
{ bcopy((char *)buf, (char *)u.u_ofile, sizeof(u.u_ofile)); }
/* u.u_pofile[] holds per-fd EXCLOSE flags (sh sets one on its script
 * buffer fd via ioctl FIOCLEX).  Shared u struct means another proc's
 * exec would otherwise sweep stale EXCLOSE bits and shut its own fds. */
void v7_pofile_save(void *buf)
{ bcopy((char *)u.u_pofile, (char *)buf, sizeof(u.u_pofile)); }
void v7_pofile_restore(void *buf)
{ bcopy((char *)buf, (char *)u.u_pofile, sizeof(u.u_pofile)); }
/* FIOCLEX/FIONCLEX bridge: armboot's struct user is a lean shadow and
 * can't reach u_pofile -- route through here so v7_exec_call's EXCLOSE
 * sweep sees the bit. */
void v7_pofile_excl_set(int fd)
{ if(fd >= 0 && fd < NOFILE) u.u_pofile[fd] |= EXCLOSE; }
void v7_pofile_excl_clear(int fd)
{ if(fd >= 0 && fd < NOFILE) u.u_pofile[fd] &= (char)~EXCLOSE; }
void v7_ofile_fork_bump(void)
{
	for(int i = 0; i < NOFILE; i++)
		if(u.u_ofile[i]) u.u_ofile[i]->f_count++;
}
void v7_ofile_drop_all(void)
{
	for(int i = 0; i < NOFILE; i++)
		if(u.u_ofile[i]) v7_ofile_clear(i);
}
/* fd-state syscall prologue: validate v7 file, set u_ap, clear err/rvals.  -1 = pseudo-fd. */
static int v7_fd_prep(int fd, int *args)
{
	if(fd < 0 || fd >= NOFILE || u.u_ofile[fd] == NULL) return -1;
	u.u_ap = args;
	u.u_segflg = 1;
	u.u_error = 0;
	u.u_r.r_val1 = u.u_r.r_val2 = 0;
	return 0;
}
/* Read v7-side u.u_error.  arm.c has its own lean `struct user u`
 * shadow that doesn't see v7's u_error; for bridges whose return value
 * encodes a v7 result (fd, offset) and can't simultaneously carry the
 * errno, the caller fetches it via this helper. */
int v7_u_error_get(void) { return (int)u.u_error; }
/* Drop a held inode ref (e.g. one that mt_save_current iget'd into the
 * slot's cdir/rdir field).  Used to back out a half-allocated armproc
 * slot when v7_proc_fork fails after mt_save_current. */
void v7_inode_drop(void *p)
{
	struct inode *ip = (struct inode *)p;
	if(ip) iput(ip);
}
/* fd-bridge convention now matches path bridges: returns positive v7 errno
 * on failure, 0 on success.  -1 reserved for "fd not v7-routable" so the
 * caller can fall back to its armboot-side path. */
int v7_fstat_call(int fd, void *ubuf)
{
	int args[2] = { fd, (int)(long)ubuf };
	if(v7_fd_prep(fd, args) < 0) return -1;
	fstat();
	return (int)u.u_error;
}
int v7_close_call(int fd)
{
	int args[1] = { fd };
	if(v7_fd_prep(fd, args) < 0) return -1;
	close();
	return (int)u.u_error;
}
/* v7 dup: "explicit target" = fdes|0100, target in fdes2 (caller mirrors files[]). */
int v7_dup_call(int from, int to)
{
	int args[2] = {
		(from & 077) | (to < 0 ? 0 : 0100),
		to < 0 ? 0 : to
	};
	if(v7_fd_prep(from, args) < 0) return -1;
	dup();
	return u.u_error ? -1 : u.u_r.r_val1;
}
int v7_lseek_call(int fd, int off, int whence)
{
	int args[3] = { fd, off, whence };
	struct file *fp;
	if(v7_fd_prep(fd, args) < 0) return -1;
	seek();
	if(u.u_error) return -1;
	fp = u.u_ofile[fd];
	return fp ? (int)fp->f_un.f_offset : -1;
}
static struct file * fd_file(int fd)
{
	return (fd < 0 || fd >= NOFILE) ? NULL : u.u_ofile[fd];
}
long v7_get_offset(int fd)
{
	struct file *fp = fd_file(fd);
	return fp ? (long)fp->f_un.f_offset : 0;
}
int v7_ofile_isset(int fd) { return fd_file(fd) != NULL; }
void v7_set_offset(int fd, long off)
{
	struct file *fp = fd_file(fd);
	if(fp) fp->f_un.f_offset = (off_t)off;
}
/* IFREG-fd r/w prep.  -2 = fall back to k*.  Caller refreshes i_size/i_addr first. */
static int v7_rdwr_prep(int fd, char *buf, unsigned int n, int want_flag, int *args)
{
	struct file *fp;
	struct inode *ip;
	if(fd < 0 || fd >= NOFILE) return -2;
	if((fp = u.u_ofile[fd]) == NULL) return -2;
	ip = fp->f_inode;
	if(ip == NULL || (ip->i_mode & IFMT) != IFREG) return -2;
	if((fp->f_flag & want_flag) == 0) return -2;
	args[0] = fd;
	args[1] = (int)(long)buf;
	args[2] = (int)n;
	u.u_ap = args;
	u.u_base = (caddr_t)buf;
	u.u_count = n;
	u.u_segflg = 1;
	u.u_error = 0;
	u.u_r.r_val1 = u.u_r.r_val2 = 0;
	return 0;
}
static int v7_rdwr_call(int fd, char *buf, unsigned int n, int want_flag,
                        void (*entry)(void))
{
	int args[3];
	if(v7_rdwr_prep(fd, buf, n, want_flag, args) < 0) return -2;
	entry();
	return u.u_error ? -1 : u.u_r.r_val1;
}
int v7_read_call(int fd, char *buf, unsigned int n)
{ return v7_rdwr_call(fd, buf, n, FREAD, read); }
/* No v7_write_call wrapper: sys_write_v7 in arm.c implements the
 * write(2) syscall directly (pipe/console fast paths plus IFREG via the
 * v7 file/inode chain), so the v7_rdwr_call indirection isn't needed
 * on the write side. */
/* Sync files[fd] <-> v7 in-core inode (i_addr is 39B of 3-byte addrs; loop-copy). */
extern void v7_inode_pack_addr(struct inode *ip, unsigned int *addrs);
extern void v7_inode_unpack_addr(struct inode *ip, unsigned int *addrs);
static struct inode *fd_inode(int fd)
{
	struct file *fp;
	if(fd < 0 || fd >= NOFILE) return NULL;
	fp = u.u_ofile[fd];
	return fp ? fp->f_inode : NULL;
}
void v7_inode_refresh(int fd, unsigned int size, unsigned int *addrs)
{
	struct inode *ip = fd_inode(fd);
	if(ip == NULL) return;
	ip->i_size = (off_t)size;
	v7_inode_pack_addr(ip, addrs);
}
/* Mark fd's inode dirty so iput->iupdat writes current time to mtime/
 * ctime.  v7's writei sets IUPD|ICHG; armboot's writei bypasses that
 * path so the dirty flags must be armed explicitly post-write. */
void v7_inode_mark_dirty(int fd)
{
	struct inode *ip = fd_inode(fd);
	if(ip == NULL) return;
	ip->i_flag |= IUPD | ICHG;
}
void v7_inode_writeback(int fd, unsigned int *size_out, unsigned int *addrs_out)
{
	struct inode *ip = fd_inode(fd);
	if(ip == NULL) return;
	*size_out = (unsigned int)ip->i_size;
	v7_inode_unpack_addr(ip, addrs_out);
	ip->i_flag |= IUPD | ICHG;	/* mark dirty for iupdat */
}
static struct inode *find_inode(ino_t ino)
{
	for(struct inode *ip = &inode[0]; ip < &inode[NINODE]; ip++)
		if(ip->i_count != 0 && ip->i_dev == rootdev &&
		   ip->i_number == ino)
			return ip;
	return NULL;
}
void v7_inode_refresh_ino(ino_t ino, unsigned int size, unsigned int *addrs)
{
	struct inode *ip = find_inode(ino);
	if(ip == NULL) return;
	ip->i_size = (off_t)size;
	v7_inode_pack_addr(ip, addrs);
}
/* Same as v7_inode_mark_dirty but by ino, for kcreat which doesn't have
 * an fd yet (the new inode is being installed into v7's table). */
void v7_inode_mark_dirty_ino(ino_t ino)
{
	struct inode *ip = find_inode(ino);
	if(ip == NULL) return;
	ip->i_flag |= IUPD | ICHG;
}
int v7_inode_snapshot_ino(ino_t ino, unsigned int *size_out, unsigned int *addrs_out)
{
	struct inode *ip = find_inode(ino);
	if(ip == NULL) return -1;
	if(size_out) *size_out = (unsigned int)ip->i_size;
	if(addrs_out) v7_inode_unpack_addr(ip, addrs_out);
	return 0;
}
/* Post-exec over armboot's loader: close-on-exec, sig reset, frame stomp. */
extern int v7_load_image(char *path, char **argv, char **envp);
extern void closef(struct file *fp);
extern void armboot_post_exec_close(int fd);
int v7_exec_call(char *path, char **argv, char **envp)
{
	int rc = v7_load_image(path, argv, envp);
	if(rc != 0) return rc < 0 ? -rc : 1;
	/* Close-on-exec sweep (EXCLOSE=01 in h/user.h).  Both sides: v7's
	 * closef drops f_count + iputs the inode; armboot_post_exec_close
	 * zeroes files[fd]+closed[fd] so the slot is reusable. */
	for(int i = 0; i < NOFILE; i++)
		if(u.u_pofile[i] & EXCLOSE) {
			if(u.u_ofile[i]) closef(u.u_ofile[i]);
			u.u_ofile[i] = NULL;
			u.u_pofile[i] &= ~EXCLOSE;
			armboot_post_exec_close(i);
		}
	/* Non-IGN signal handlers reset to SIG_DFL (slot 0 unused). */
	for(int i = 1; i < NSIG; i++)
		if(u.u_signal[i] != 1) u.u_signal[i] = 0;
	/* Stomp trap frame: sp=USTACK, lr=0, pc=UENTRY. */
	if(trap_frame) {
		trap_frame[13] = (int)USTACK;
		trap_frame[14] = 0;
		trap_frame[15] = (int)UENTRY;
	}
	u.u_ap = NULL;
	return 0;
}
/* sigreturn (4.xBSD ext, no v7 source): wrap armboot_ksigreturn, reset u_{error,ap,r}. */
extern void armboot_ksigreturn(int *r);
int v7_sigreturn_call(int *r)
{
	armboot_ksigreturn(r);
	if(u.u_procp == NULL) u.u_procp = &proc[0];
	v7_call_prep(NULL);
	return 0;
}
/* Path -> inum bridge over v7's namei.  First call iget's rootdir +
 * u.u_cdir as separate refs (sys/main.c) so child chdir-iput doesn't
 * drop rootdir to 0 and break later absolute-path walks. */
ino_t v7_namei_inum(char *path)
{
	struct inode *ip;
	ino_t inum;
	if(rootdir == NULL) {
		rootdir = iget(rootdev, (ino_t)ROOTINO);
		if(rootdir == NULL) return (ino_t)0;
		rootdir->i_flag &= ~ILOCK;
		u.u_cdir = iget(rootdev, (ino_t)ROOTINO);
		if(u.u_cdir == NULL) return (ino_t)0;
		u.u_cdir->i_flag &= ~ILOCK;
	}
	u.u_dirp = (caddr_t)path;
	u.u_error = 0;
	u.u_segflg = 1;
	if((ip = namei(uchar, 0)) == NULL) return (ino_t)0;
	inum = ip->i_number;
	iput(ip);
	return inum;
}
/* Populate mount[0] for rootdev (idempotent; mirrors sys3.c::smount). */
int v7_mount_init(void)
{
	struct buf *bp, *mb;
	struct filsys *fp;
	if(mount[0].m_bufp != NULL) return 0;
	if(rootdir == NULL) return -1;	/* caller must seed rootdir first */
	bp = bread(rootdev, (daddr_t)SUPERB);
	if(bp->b_flags & B_ERROR) { brelse(bp); return -1; }
	mb = geteblk();
	bcopy((char *)bp->b_un.b_addr, (char *)mb->b_un.b_addr,
	    (unsigned int)BSIZE);
	fp = mb->b_un.b_filsys;
	fp->s_ilock = fp->s_flock = fp->s_ronly = 0;
	/* Seed kernel `time` from the superblock's last-modified stamp,
	 * matching v7 iinit().  stime(2) can override later. */
	time = fp->s_time;
	brelse(bp);
	mount[0].m_dev = rootdev;
	mount[0].m_bufp = mb;
	mount[0].m_inodp = rootdir;
	return 0;
}
/* Bridge armboot's addr[NADDR] <-> v7's i_un.i_addr[] (loop-copy,
 * layout-agnostic). */
void v7_inode_pack_addr(struct inode *ip, unsigned int *addrs)
{
	if(ip && addrs)
		for(int i = 0; i < NADDR; i++)
			ip->i_un.i_addr[i] = (daddr_t)addrs[i];
}
void v7_inode_unpack_addr(struct inode *ip, unsigned int *addrs)
{
	if(ip && addrs)
		for(int i = 0; i < NADDR; i++)
			addrs[i] = (unsigned int)ip->i_un.i_addr[i];
}
/* ARM Generic Timer + GICv2 (cortex-a7): GICD 0x08000000, GICC 0x08010000, CNTV PPI 27. */
#define GICD_BASE	0x08000000U
#define GICC_BASE	0x08010000U
#define GICD_CTLR	(*(volatile unsigned int *)(GICD_BASE + 0x000))
#define GICD_ISENABLER(n) (*(volatile unsigned int *)(GICD_BASE + 0x100 + 4*(n)))
#define GICD_IPRIORITYR(n) (*(volatile unsigned int *)(GICD_BASE + 0x400 + 4*(n)))
#define GICC_CTLR	(*(volatile unsigned int *)(GICC_BASE + 0x000))
#define GICC_PMR	(*(volatile unsigned int *)(GICC_BASE + 0x004))
#define GICC_IAR	(*(volatile unsigned int *)(GICC_BASE + 0x00c))
#define GICC_EOIR	(*(volatile unsigned int *)(GICC_BASE + 0x010))
#define TIMER_IRQ	27	/* CNTV PPI */
/* TIMER_HZ==HZ so sys/clock.c's `++lbolt >= HZ` bumps `time` per second. */
#define TIMER_HZ	HZ
extern unsigned int cntfrq_get(void);
extern void cntv_tval_set(unsigned int v), cntv_ctl_set(unsigned int v);
extern void irq_enable(void);
/* v7 clock(): ps=UMODE if trap-time CPSR=user. */
extern long dk_time[];
extern int lbolt;
extern void clock(int dev, int sp, int r1, int nps, int r0, caddr_t pc, int ps);
static unsigned int timer_reload;	/* CNTFRQ / HZ */
/* Re-entrancy guard: skip the v7 clock() body when trap() is mid-update. */
volatile int in_clock_irq;
extern volatile int in_trap;
void clock_irq_handler(int *tf)
{
	unsigned int iar = GICC_IAR;
	unsigned int intid = iar & 0x3ff;
	if(intid == 1023) return;	/* spurious */
	if(intid == TIMER_IRQ) {
		int mode = tf[16] & 0x1f;
		int usermode = (mode == 0x10) || (mode == 0x1f);
		cntv_tval_set(timer_reload);
		if(u.u_procp != NULL && !in_clock_irq) {
			extern void mt_clock_tick(void);
			in_clock_irq = 1;
			clock(0, 0, 0, 0, 0, (caddr_t)(unsigned)tf[15],
			    usermode ? 0xf000 : 0);
			in_clock_irq = 0;
			mt_clock_tick();
		}
	}
	GICC_EOIR = iar;	/* EOI: drop priority */
}
/* Enable CNTV at HZ + route PPI 27 through GICv2 (called from armboot()). */
void arm_timer_init(void)
{
	unsigned int freq, prio_reg, prio_off, prio_val;
	freq = cntfrq_get();
	if(freq == 0) freq = 62500000U;	/* fallback (qemu virt typical) */
	timer_reload = freq / TIMER_HZ;
	/* GICD priority for INTID 27 (one byte per intid). */
	prio_reg = TIMER_IRQ / 4;
	prio_off = (TIMER_IRQ % 4) * 8;
	prio_val = GICD_IPRIORITYR(prio_reg);
	prio_val &= ~(0xffU << prio_off);
	prio_val |=  (0x80U << prio_off);
	GICD_IPRIORITYR(prio_reg) = prio_val;
	GICD_ISENABLER(TIMER_IRQ / 32) = 1U << (TIMER_IRQ % 32);
	GICD_CTLR = 1;
	GICC_PMR  = 0xff;
	GICC_CTLR = 1;
	cntv_tval_set(timer_reload);
	cntv_ctl_set(1);	/* ENABLE=1, IMASK=0 */
	irq_enable();
}
