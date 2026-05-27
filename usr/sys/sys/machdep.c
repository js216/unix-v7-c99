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
#include "../h/systm.h"
#include "../h/seg.h"
void putchar(char c);
int getchar(void);
void printf(char *fmt, ...);
void panic(char *s);
int save(int *lp);
void resume(int addr, int *lp);
void mmu_on(unsigned int ttb);
void mmuinit(void);
void brelse(struct buf *bp);
void bwrite(struct buf *bp);
void bdwrite(struct buf *bp);
void run_user(unsigned int pc, unsigned int sp);
void virtio_init(void);
void binit(void);
void clkstart(void);
#define S_EXIT		1
#define S_FORK		2
#define S_READ		3
#define S_WRITE		4
#define S_WAIT		7
#define S_EXEC		11
#define S_EXECE		59
#define S_SIGNAL	48
#define S_SIGRETURN	139
void startup(void)
{
	struct buf *bp;
	unsigned char *raw;
	unsigned int isize, fsize;
	printf("mem = %D\n", (long)(128L * 1024 * 1024));
	maxmem = (int)(USERSIZE >> 6) + USIZE;
	mmuinit();
	virtio_init();
	binit();
	bp = bread((dev_t)rootdev, (daddr_t)SUPERB);
	raw = (unsigned char *)bp->b_un.b_addr;
	isize = (unsigned int)raw[0] | ((unsigned int)raw[1] << 8);
	fsize = (unsigned int)raw[2] | ((unsigned int)raw[3] << 8)
	      | ((unsigned int)raw[4] << 16)
	      | ((unsigned int)raw[5] << 24);
	printf("v7: sb isize=%d fsize=%d\n", (int)isize, (int)fsize);
	brelse(bp);
}
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
	char	*mem;
	int	pipe;
	int	wpipe;
	int	kmem;
	int	dirty;
};
struct pipe {
	char	buf[PIPESIZ];
	unsigned int rpos, wpos;
	int	used, writer;
};
struct ustat {
	dev_t	st_dev;
	ino_t	st_ino;
	unsigned short st_mode;
	short	st_nlink, st_uid, st_gid;
	dev_t	st_rdev;
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
extern int *trap_frame;
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
extern void v7_inode_set_mode_ino(ino_t ino, unsigned short mode);
extern void v7_inode_set_owner_ino(ino_t ino, short uid, short gid);
extern int v7_inode_snapshot_ino(ino_t ino, unsigned int *size_out, unsigned int *addrs_out);
extern void v7_inode_unpack_addr(struct inode *ip, unsigned int *addrs);
extern void acct(void);
extern int getchar_ready(void);
extern void pause_spin_barrier(void);
extern time_t time;
extern char msgbuf[], *msgbufp;
extern struct inode *rootdir;
void do_exit(int code, int *r);
volatile int in_spin_wait;
int fubyte(caddr_t addr) { return *(unsigned char *)addr; }
int subyte(caddr_t addr, char c) { *(unsigned char *)addr = c; return 0; }
int fuword(caddr_t addr) { return *(int *)addr; }
int suword(caddr_t addr, int v) { *(int *)addr = v; return 0; }
int copyin(caddr_t f, caddr_t t, unsigned int n) { while(n--) *t++ = *f++; return 0; }
int copyout(caddr_t f, caddr_t t, unsigned int n) { unsigned int a = (unsigned int)t; if(a + n < a || a + n > USERSIZE) return -1; while(n--) *t++ = *f++; return 0; }
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
#define V7_FREAD	01
#define V7_FWRITE	02
static unsigned int tmpused;
static ino_t nextino;
static daddr_t nextblk;
static ino_t console_ino = 1;
static struct childent {
	int pid, ppid, exitval;
	long utime, stime;
} childdone[NFD];
static int ndone, curpid = 1, nextpid = 2;
#define	NPROCSAVE	32
#define	PROC_CORE_CLICK	1024
#define	PROC_CORE_BYTES	(PROC_CORE_CLICK << 6)
#define	V7_STACK_TOP	0x10000U
#define	KSTACK_SIZE	4096
#define	PSTATE_FREE	0
#define	PSTATE_LIVE	1
#define	PSTATE_RUN	2
#define	PSTATE_SLEEP	3
#define	PSTATE_ZOMBIE	4
static struct armproc {
	int frame[17];
	struct kfile files[NFD];
	int closed[NFD];
	void *ofile[20];
	char pofile[20];
	ino_t cwdino;
	void *cdir, *rdir;
	long handlers[NSIG+1];
	unsigned int pending;
	int uid, gid, pid, inuse;
	long utime, stime, cutime, cstime, usignal[NSIG+1];
	int umask;
	struct user uarea;
	unsigned char kstack[KSTACK_SIZE] __attribute__((aligned(16)))
	    __attribute__((unused));
	int rsav[10], qsav[10];
	int state, ppid, exitcode, wait_for;
} armproc[NPROCSAVE];
static unsigned char usermem[NPROCSAVE][USERSIZE]
    __attribute__((aligned(0x100000)));
static int live_slot = -1;
static int slot_by_pid(int pid)
{
	for(int i = 0; i < NPROCSAVE; i++)
		if(armproc[i].inuse && armproc[i].state != PSTATE_FREE &&
		   armproc[i].pid == pid)
			return i;
	return -1;
}
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
static int mt_save_slot(int pid, int ppid, int state)
{
	if(live_slot >= 0 && armproc[live_slot].pid == pid)
		return live_slot;
	return mt_alloc_slot(pid, ppid, state);
}
static void usermap(int slot)
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
}
static void proc_core(register struct proc *p, int slot)
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
static void restore_v7_regular_files(void);
static struct proc *proc_by_pid(int pid);
static long handlers[NSIG+1];
static unsigned int pending;
static int kuid, kgid, kumask, mt_switched;
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
	bcopy((char *)files,    (char *)a->files,  sizeof(a->files));
	bcopy((char *)closed,   (char *)a->closed, sizeof(a->closed));
	bcopy((char *)handlers, (char *)a->handlers, sizeof(handlers));
	v7_ofile_save(a->ofile);
	v7_pofile_save(a->pofile);
	a->cwdino = u.u_cdir ? u.u_cdir->i_number : cwdino;
	a->cdir = v7_cdir_save();
	a->rdir = v7_rdir_save();
	a->pending = pending;
	a->uid = kuid;
	a->gid = kgid;
	a->pid = curpid;
	a->state = state;
	a->umask = kumask;
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
	bcopy((char *)a->files,    (char *)files,    sizeof(a->files));
	bcopy((char *)a->closed,   (char *)closed,   sizeof(a->closed));
	bcopy((char *)a->handlers, (char *)handlers, sizeof(handlers));
	cwdino = a->cwdino;
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
	restore_v7_regular_files();
	v7_cdir_restore(a->cdir);
	v7_rdir_restore(a->rdir);
	a->cdir = NULL;
	a->rdir = NULL;
	if(u.u_cdir)
		cwdino = u.u_cdir->i_number;
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
static int mt_pipe_count(int pipe_id, int want_wpipe)
{
	for(int j = 0; j < NFD; j++)
		if(files[j].pipe == pipe_id &&
		   (files[j].wpipe != 0) == (want_wpipe != 0) && !closed[j])
			return 1;
	for(int i = 0; i < NPROCSAVE; i++) {
		if(!armproc[i].inuse || armproc[i].state == PSTATE_FREE) continue;
		if(armproc[i].state == PSTATE_LIVE || i == live_slot) continue;
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
void armboot_swtch(void)
{
	int my_slot, next;
	int ppid = v7_get_ppid(curpid);
	if(ppid < 0) ppid = 1;
	if((my_slot = mt_save_slot(curpid, ppid, PSTATE_SLEEP)) < 0)
		return;
	if(save(armproc[my_slot].rsav))
		return;
	mt_save_current(my_slot, trap_r, PSTATE_SLEEP);
	armproc[my_slot].wait_for = -1;
	if((next = mt_pick_runnable()) < 0) {
		if(my_slot == live_slot)
			armproc[my_slot].state = PSTATE_LIVE;
		else
			proc_free_slot(my_slot);
		return;
	}
	mt_load_slot(next, trap_r);
	resume(0, armproc[next].rsav);
	panic("swtch: resume returned");
}
static int mt_block_on_pipe(int *r, int syscall_num, int wait_key)
{
	int my_slot, next, ppid;
	if((next = mt_pick_runnable()) < 0) return -1;
	ppid = v7_get_ppid(curpid);
	if(ppid < 0) ppid = 1;
	if((my_slot = mt_save_slot(curpid, ppid, PSTATE_SLEEP)) < 0)
		return -1;
	mt_save_current(my_slot, r, PSTATE_SLEEP);
	armproc[my_slot].wait_for = wait_key;
	armproc[my_slot].frame[7]  = syscall_num;
	armproc[my_slot].frame[15] -= 4;
	mt_load_slot(next, r);
	return 0;
}
struct kuser {
	int u_arg[6], u_error, u_rval1, u_rval2, u_segflg;
};
static struct kuser ku;
static void sysent_dispatch(int);
#define	SIG_DFL		0L
#define	SIG_IGN		1L
void mmuinit(void)
{
	unsigned int pa;
	for(unsigned int i = 0; i < 4096; i++) l1[i] = 0;
#ifdef EVB
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
static void shim_forget(daddr_t blkno)
{
	struct buf *bp = getblk((dev_t)rootdev, blkno);
	bp->b_flags &= ~(B_DONE | B_ERROR);
	brelse(bp);
}
static struct inode *find_inode(ino_t ino);
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
	if(dp->di_mode == 0) {
		shim_forget(itod(ino));
		shim_bread(itod(ino), blkbuf);
		bcopy((char *)&blkbuf[off], (char *)dp, sizeof(*dp));
	}
	return dp->di_mode == 0 ? -1 : 0;
}
static int loadino(ino_t ino, struct kfile *fp)
{
	struct dinode di;
	struct inode *ip;
	unsigned int addrs[NADDR];
	if(k_iget(ino, &di) < 0) {
		ip = find_inode(ino);
		if(ip == NULL || ip->i_mode == 0)
			return -1;
		fp->ino = ino;
		fp->mode = ip->i_mode;
		fp->size = (unsigned int)ip->i_size;
		v7_inode_unpack_addr(ip, addrs);
		for(int i = 0; i < NADDR; i++)
			fp->addr[i] = (daddr_t)addrs[i];
		return 0;
	}
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
static daddr_t fs_alloc_block(void)
{
	return nextblk++;
}
static void fs_free_block(daddr_t bno)
{
	(void)bno;
}
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
static ino_t knamei(char *path)
{
	struct kfile dp;
	struct direct de;
	ino_t ino;
	char name[DIRSIZ];
	char *p;
	int i, more;

	if(path == 0 || *path == 0)
		return (ino_t)0;
	if(*path == '/') {
		ino = u.u_rdir ? u.u_rdir->i_number : ROOTINO;
		while(*path == '/') path++;
	} else
		ino = u.u_cdir ? u.u_cdir->i_number : cwdino;
	if(*path == 0)
		return ino;
	while(*path) {
		if(loadino(ino, &dp) < 0 || (dp.mode & IFMT) != IFDIR)
			return (ino_t)0;
		for(i = 0; i < DIRSIZ; i++)
			name[i] = 0;
		p = path;
		for(i = 0; i < DIRSIZ && *p && *p != '/'; i++)
			name[i] = *p++;
		while(*p && *p != '/')
			p++;
		while(*p == '/')
			p++;
		more = *p != 0;
		ino = (ino_t)0;
		for(i = 0; i < (int)dp.size; i += sizeof(de)) {
			if(kreadi(&dp, (unsigned int)i, (char *)&de,
			    sizeof(de)) != sizeof(de))
				return (ino_t)0;
			if(de.d_ino == 0)
				continue;
			if(strncmp(de.d_name, name, DIRSIZ) == 0) {
				ino = de.d_ino;
				break;
			}
		}
		if(ino == 0)
			return (ino_t)0;
		path = p;
		if(!more)
			return ino;
	}
	return ino;
}
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
	{
		ino_t ino = v7_namei_inum(buf);
		return ino ? ino : knamei(buf);
	}
}
static int alloc_fd_slot(void)
{
	int fd;
	for(fd = 0; fd < NFD; fd++)
		if((fd >= 3 || closed[fd]) && files[fd].ino == 0) return fd;
	return -1;
}
static int pseudo_fd_open(ino_t ino, int mode, unsigned int size)
{
	int fd = alloc_fd_slot();
	if(fd < 0) return -1;
	v7_ofile_clear(fd);
	bzero((char *)&files[fd], sizeof(files[fd]));
	files[fd].ino = ino;
	files[fd].mode = mode;
	files[fd].size = size;
	closed[fd] = 0;
	v7_pofile_excl_clear(fd);
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
	if(strcmp(path, "/dev/mem") == 0 || strcmp(path, "/dev/kmem") == 0) {
		fd = pseudo_fd_open(1, IFCHR, 0xFFFFFFFFu);
		if(fd >= 0) files[fd].kmem = 1;
		return fd;
	}
	if(strcmp(path, "/dev/console") == 0 ||
	   strcmp(path, "/dev/tty") == 0) {
		fd = pseudo_fd_open(console_ino, IFCHR, 0);
		return fd;
	}
	if(strcmp(path, "/dev/null") == 0) {
		fd = pseudo_fd_open(1, IFCHR, 0);
		if(fd >= 0) files[fd].kmem = 2;
		return fd;
	}
	if(strcmp(path, "/dev/root") == 0) {
		fd = pseudo_fd_open(1, IFBLK, 0xFFFFFFFFu);
		if(fd >= 0) files[fd].kmem = 3;
		return fd;
	}
	ino_t ino = v7_namei_inum(path);
	if(ino == 0)
		ino = knamei(path);
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
			if((files[fd].mode & IFMT) == IFDIR) {
				bzero((char *)&files[fd], sizeof(files[fd]));
				return -2;
			}
			if((files[fd].mode & IFMT) != IFREG) {
				if(strcmp(path, "/dev/console") == 0) {
					bzero((char *)&files[fd], sizeof(files[fd]));
					files[fd].ino = console_ino;
					files[fd].mode = IFCHR;
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
	v7_inode_mark_dirty_ino(pino);
	v7_inode_mark_dirty_ino(files[fd].ino);
	closed[fd] = 0;
	v7_ofile_set(fd, files[fd].ino, V7_FREAD|V7_FWRITE);
	return fd;
}
static int klink(char *from, char *to)
{
	struct kfile dp, fp;
	struct direct de;
	char name[DIRSIZ];
	ino_t ino, pino;
	ino = v7_namei_inum(from);
	if(ino == 0)
		ino = knamei(from);
	if(ino == 0) return -1;
	pino = parenti(to, name);
	if(pino == 0 || loadino(pino, &dp) < 0 || (dp.mode & IFMT) != IFDIR)
		return -1;
	loadino_v7_current(pino, &dp);
	for(int i = 0; i < (int)dp.size; i += sizeof(de)) {
		(void)kreadi(&dp, (unsigned int)i, (char *)&de, sizeof(de));
		if(de.d_ino && strncmp(de.d_name, name, DIRSIZ) == 0)
			return -2;
	}
	bzero((char *)&de, sizeof(de));
	de.d_ino = ino;
	for(int j = 0; j < DIRSIZ; j++) de.d_name[j] = name[j];
	if(kwritei(&dp, dp.size, (char *)&de, sizeof(de)) != sizeof(de))
		return -1;
	(void)putino(pino, &dp);
	v7_inode_refresh_ino(pino, dp.size, (unsigned int *)dp.addr);
	v7_inode_mark_dirty_ino(pino);
	if(loadino(ino, &fp) == 0) {
		shim_bread(itod(ino), blkbuf);
		{
			char *q = (char *)&blkbuf[itoo(ino) * sizeof(struct dinode) + 2];
			unsigned int n = (unsigned int)(unsigned char)q[0] | ((unsigned int)(unsigned char)q[1] << 8);
			put16(q, n + 1);
		}
		shim_bwrite(itod(ino), blkbuf);
	}
	return 0;
}
static int kunlink(char *path)
{
	struct kfile dp, fp;
	struct direct de;
	char name[DIRSIZ];
	ino_t pino, ino;
	int off;
	pino = parenti(path, name);
	if(pino == 0 || loadino(pino, &dp) < 0 || (dp.mode & IFMT) != IFDIR)
		return 2;
	loadino_v7_current(pino, &dp);
	for(off = 0; off < (int)dp.size; off += sizeof(de)) {
		(void)kreadi(&dp, (unsigned int)off, (char *)&de, sizeof(de));
		if(de.d_ino && strncmp(de.d_name, name, DIRSIZ) == 0)
			break;
	}
	if(off >= (int)dp.size) return 2;
	ino = de.d_ino;
	if(loadino(ino, &fp) < 0) return 2;
	de.d_ino = 0;
	if(kwritei(&dp, (unsigned int)off, (char *)&de, sizeof(de)) != sizeof(de))
		return 5;
	(void)putino(pino, &dp);
	v7_inode_refresh_ino(pino, dp.size, (unsigned int *)dp.addr);
	v7_inode_mark_dirty_ino(pino);
	shim_bread(itod(ino), blkbuf);
	{
		char *q = (char *)&blkbuf[itoo(ino) * sizeof(struct dinode) + 2];
		unsigned int n = (unsigned int)(unsigned char)q[0] | ((unsigned int)(unsigned char)q[1] << 8);
		if(n != 0) put16(q, n - 1);
	}
	shim_bwrite(itod(ino), blkbuf);
	return 0;
}
static int kchmod(char *path, int mode)
{
	struct kfile fp;
	ino_t ino = v7_namei_inum(path);
	if(ino == 0)
		ino = knamei(path);
	if(ino == 0 || loadino(ino, &fp) < 0) return 2;
	fp.mode = (fp.mode & ~07777) | (mode & 07777);
	if(putino(ino, &fp) < 0) return 5;
	v7_inode_set_mode_ino(ino, fp.mode);
	return 0;
}
static int kchown(char *path, int uid, int gid)
{
	struct kfile fp;
	ino_t ino = v7_namei_inum(path);
	if(ino == 0)
		ino = knamei(path);
	if(ino == 0 || loadino(ino, &fp) < 0) return 2;
	if(putino(ino, &fp) < 0) return 5;
	shim_bread(itod(ino), blkbuf);
	{
		char *p = (char *)&blkbuf[itoo(ino) * sizeof(struct dinode)];
		put16(p + 4, (unsigned int)uid);
		put16(p + 6, (unsigned int)gid);
	}
	shim_bwrite(itod(ino), blkbuf);
	v7_inode_set_owner_ino(ino, (short)uid, (short)gid);
	return 0;
}
static int kmknod(char *path, int mode, int dev)
{
	struct kfile dp, fp;
	struct direct de;
	char name[DIRSIZ];
	ino_t pino;
	pino = parenti(path, name);
	if(pino == 0 || loadino(pino, &dp) < 0 || (dp.mode & IFMT) != IFDIR)
		return -1;
	loadino_v7_current(pino, &dp);
	for(int i = 0; i < (int)dp.size; i += sizeof(de)) {
		(void)kreadi(&dp, (unsigned int)i, (char *)&de, sizeof(de));
		if(de.d_ino && strncmp(de.d_name, name, DIRSIZ) == 0)
			return -2;
	}
	bzero((char *)&fp, sizeof(fp));
	fp.ino = nextino++;
	fp.mode = mode;
	fp.size = 0;
	if((mode & IFMT) == IFCHR || (mode & IFMT) == IFBLK)
		fp.addr[0] = (daddr_t)dev;
	if(putino(fp.ino, &fp) < 0) return -1;
	bzero((char *)&de, sizeof(de));
	de.d_ino = fp.ino;
	for(int j = 0; j < DIRSIZ; j++) de.d_name[j] = name[j];
	if(kwritei(&dp, dp.size, (char *)&de, sizeof(de)) != sizeof(de))
		return -1;
	(void)putino(pino, &dp);
	v7_inode_refresh_ino(pino, dp.size, (unsigned int *)dp.addr);
	v7_inode_mark_dirty_ino(pino);
	v7_inode_mark_dirty_ino(fp.ino);
	return 0;
}
static char *slot_user_base(int slot)
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
static int kread(int fd, char *buf, unsigned int n)
{
	int c, r;
	if(fd >= 0 && fd < NFD && files[fd].pipe != 0) {
		struct pipe *pp = &pipes[files[fd].pipe-1];
		if(pp->rpos >= pp->wpos) { pp->rpos = pp->wpos = 0; return 0; }
		if(n > pp->wpos - pp->rpos) n = pp->wpos - pp->rpos;
		bcopy(pp->buf + pp->rpos, buf, n);
		pp->rpos += n;
		if(pp->rpos >= pp->wpos) pp->rpos = pp->wpos = 0;
		mt_wake_pipe(files[fd].pipe, 2);
		return n;
	}
	if(fd >= 0 && fd < NFD && files[fd].kmem == 2) return 0;
	if(fd >= 0 && fd < NFD && files[fd].kmem == 3) {
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
		unsigned int done = 0;
		while(done < n) {
			unsigned int off = files[fd].off;
			unsigned int slot = off / PROC_CORE_BYTES;
			unsigned int so = off % PROC_CORE_BYTES;
			unsigned int cnt = n - done;
			if(cnt > PROC_CORE_BYTES - so)
				cnt = PROC_CORE_BYTES - so;
			if(slot < NPROCSAVE && armproc[slot].inuse)
				proc_core_copy(slot, buf + done, so, cnt);
			else
				bcopy((char *)(unsigned long)off, buf + done, cnt);
			done += cnt;
			files[fd].off += cnt;
		}
		return (int)done;
	}
	if(fd == 0 || (fd >= 0 && fd < NFD && files[fd].mode == IFCHR)) {
		if(fd == 0 && files[fd].ino != 0 && files[fd].mode != IFCHR)
			goto file;
		if(n == 0) return 0;
		while(!getchar_ready()) {
			psig_drain(curpid, &pending);
			if(sig_deliverable(pending)) {
				ku.u_error = 4;
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
		if(c == 0x04) { putchar('\n'); return 0; }
		if(c == 0x03 || c == 0x1c) {
			v7_signal_pgrp(c == 0x03 ? 2 : 3, curpid);
			return 0;
		}
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
static int fd_is_v7_reg(int fd)
{
	return fd >= 0 && fd < NFD &&
	       files[fd].ino > 1 && files[fd].pipe == 0 &&
	       (files[fd].mode & IFMT) == IFREG;
}
static int kclose(int fd)
{
	if(fd < 0 || fd >= NFD) return -1;
	if(files[fd].ino == 0 && (fd >= 3 || closed[fd])) return -1;
	int p = files[fd].pipe;
	if(p != 0 && files[fd].wpipe) pipes[p-1].writer = 0;
	if(p != 0) { mt_wake_pipe(p, 1); mt_wake_pipe(p, 2); }
	if(fd_is_v7_reg(fd)) {
		int stale = 0;
		for(int i = 0; i < NFD; i++)
			if(i != fd && fd_is_v7_reg(i) &&
			   files[i].ino == files[fd].ino &&
			   files[i].dirty &&
			   (!files[fd].dirty || files[i].size > files[fd].size)) {
				stale = 1;
				break;
			}
		if(!stale && files[fd].dirty)
			(void)putino(files[fd].ino, &files[fd]);
	}
	v7_ofile_clear(fd);
	bzero((char *)&files[fd], sizeof(files[fd]));
	if(p) {
		int i, j;
		for(i = 0; i < NFD; i++)
			if(files[i].pipe == p) break;
		for(j = 0; i == NFD && j < NPROCSAVE; j++) {
			if(!armproc[j].inuse || armproc[j].state == PSTATE_FREE)
				continue;
			if(armproc[j].state == PSTATE_LIVE || j == live_slot)
				continue;
			for(i = 0; i < NFD; i++)
				if(armproc[j].files[i].pipe == p &&
				   !armproc[j].closed[i]) break;
		}
		if(i == NFD) bzero((char *)&pipes[p-1], sizeof(pipes[p-1]));
	}
	if(fd < 3) closed[fd] = 1;
	return 0;
}
static int kdup(int from, int to)
{
	if(from < 0 || from >= NFD) return -1;
	if(files[from].ino == 0 && from > 2) return -1;
	if(to < 0) {
		int i;
		for(i = 0; i < NFD; i++)
			if(files[i].ino == 0) break;
		if(i == NFD) return -1;
		to = i;
	}
	if(to >= NFD) return -1;
	if(to != from && (files[to].ino != 0 || !closed[to]))
		(void)kclose(to);
	if(files[from].ino != 0)
		bcopy((char *)&files[from], (char *)&files[to], sizeof(files[to]));
	else {
		bzero((char *)&files[to], sizeof(files[to]));
		files[to].ino = 1;
		files[to].mode = IFCHR;
	}
	closed[to] = 0;
	v7_ofile_dup(from, to);
	return to;
}
static int kseek(int fd, int off, int whence)
{
	long n;
	if(fd < 0 || fd >= NFD || files[fd].ino == 0) return -1;
	if(files[fd].pipe != 0) return -2;
	switch(whence) {
	case 0:	n = off;				break;
	case 1:	n = (long)files[fd].off  + off;		break;
	case 2:	n = (long)files[fd].size + off;		break;
	default: return -1;
	}
	if(n < 0) return -1;
	files[fd].off = (unsigned int)n;
	if(v7_ofile_isset(fd))
		v7_set_offset(fd, (long)files[fd].off);
	return (int)files[fd].off;
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
	v7_pofile_excl_clear(f0);
	v7_pofile_excl_clear(f1);
	fdp[0] = f0;
	fdp[1] = f1;
	return 0;
}
static void kdone(int pid, int ppid, int code)
{
	struct childent *c;
	if(ndone >= NFD) return;
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
static void kflush(void)
{
	for(int i = 0; i < NFD; i++)
		if(fd_is_v7_reg(i)) {
			int stale = 0;
			for(int j = 0; j < NFD; j++)
				if(i != j && fd_is_v7_reg(j) &&
				   files[j].ino == files[i].ino &&
				   files[j].dirty &&
				   (!files[i].dirty || files[j].size > files[i].size)) {
					stale = 1;
					break;
				}
			if(stale)
				continue;
			if(files[i].dirty)
				(void)putino(files[i].ino, &files[i]);
		}
}
static void restore_v7_regular_files(void)
{
	for(int i = 0; i < NFD; i++)
		if(fd_is_v7_reg(i) && v7_ofile_isset(i)) {
			files[i].off = (unsigned int)v7_get_offset(i);
		}
}
static int ustat(ino_t ino, struct kfile *fp, struct ustat *st)
{
	st->st_dev = 0;
	st->st_ino = ino;
	st->st_mode = fp->mode;
	{
		struct dinode di;
		st->st_nlink = k_iget(ino, &di) == 0 ? di.di_nlink : 1;
		st->st_uid = k_iget(ino, &di) == 0 ? di.di_uid : 0;
		st->st_gid = k_iget(ino, &di) == 0 ? di.di_gid : 0;
	}
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
static void install_sigtramp(char *base)
{
	volatile unsigned int *t = (volatile unsigned int *)(base + UENTRY_SIGTRAMP);

	t[0] = 0xe3a0708bU;
	t[1] = 0xef000000U;
}
static int kexec(char *path)
{
	struct kfile fp;
	unsigned int insn;
	int slot;
	char *base;
	ino_t ino = v7_namei_inum(path);
	if(ino == 0)
		ino = knamei(path);
	if(ino == 0 || loadino(ino, &fp) < 0) return -2;
	if((fp.mode & IFMT) != IFREG) return -13;
	if((fp.mode & 0111) == 0) return -13;
	if(fp.size >= USERSIZE - UENTRY) return -2;
	if(fp.size < sizeof(insn)) return -KENOEXEC;
	slot = slot_by_pid(curpid);
	base = slot >= 0 ? slot_user_base(slot) : (char *)USERBASE;
	__asm__ volatile("cpsid i" ::: "memory");
	bzero(base, USERSIZE);
	__asm__ volatile("cpsie i\n\tisb" ::: "memory");
	if(kreadi(&fp, 0, base + UENTRY, fp.size) != (int)fp.size) {
		return -5;
	}
	__asm__ volatile("cpsid i" ::: "memory");
	if(slot >= 0 && base != (char *)usermem[slot])
		bcopy(base, (char *)usermem[slot], USERSIZE);
	insn = *(volatile unsigned int *)(base + UENTRY);
	if((insn & 0xff000000U) != 0xeb000000U)
		return -KENOEXEC;
	u.u_tsize = 0;
	u.u_dsize = 0;
	u.u_ssize = SSIZE;
	u.u_sep = 0;
	if(u.u_procp)
		u.u_procp->p_size = USIZE + SSIZE;
	install_sigtramp(base);
	for(int i = 1; i <= NSIG; i++)
		if(handlers[i] != SIG_IGN) handlers[i] = SIG_DFL;
	pending = 0;
	if(slot >= 0) {
		usermap(slot);
		live_slot = slot;
	}
	return 0;
}
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
	argbuf[n++] = 0;
	if(envp != 0)
		for(int i = 0; envp[i] != 0 && n < (int)sizeof(argbuf)-2; i++) {
			for(p = envp[i]; *p && n < (int)sizeof(argbuf)-2; p++)
				argbuf[n++] = *p;
			argbuf[n++] = 0;
		}
	argbuf[n++] = 0;
}
static int argstrlen(char *p)
{
	int n = 0;

	while(p[n])
		n++;
	return n;
}
static void install_v7_user_stack(char *base)
{
	char *p;
	unsigned int ap, strp, nc, stack_bytes, need;
	int argc, envc, len;
	int *wp;

	argc = 0;
	envc = 0;
	nc = 0;
	p = argbuf;
	while(*p) {
		len = argstrlen(p) + 1;
		argc++;
		nc += (unsigned int)len;
		p += len;
	}
	if(*p == 0)
		p++;
	while(*p) {
		len = argstrlen(p) + 1;
		envc++;
		nc += (unsigned int)len;
		p += len;
	}
	nc = (nc + (unsigned int)NBPW - 1U) & ~((unsigned int)NBPW - 1U);
	need = nc + (unsigned int)NBPW +
	    (unsigned int)(argc + envc + 3) * (unsigned int)NBPW;
	stack_bytes = (unsigned int)ctob(u.u_ssize);
	if(need > stack_bytes) {
		u.u_ssize = (need + 63U) >> 6;
		stack_bytes = (unsigned int)ctob(u.u_ssize);
		if(u.u_procp)
			u.u_procp->p_size = (short)(USIZE + u.u_ssize);
	}
	if(stack_bytes > V7_STACK_TOP)
		stack_bytes = V7_STACK_TOP;
	strp = V7_STACK_TOP - nc - (unsigned int)NBPW;
	ap = strp - (unsigned int)(argc + envc + 3) * (unsigned int)NBPW;
	bzero(base + ap, V7_STACK_TOP - ap);
	wp = (int *)(base + ap);
	*wp++ = argc;
	p = argbuf;
	while(*p) {
		len = argstrlen(p) + 1;
		*wp++ = (int)strp;
		bcopy(p, base + strp, (unsigned int)len);
		strp += (unsigned int)len;
		p += len;
	}
	*wp++ = 0;
	if(*p == 0)
		p++;
	while(*p) {
		len = argstrlen(p) + 1;
		*wp++ = (int)strp;
		bcopy(p, base + strp, (unsigned int)len);
		strp += (unsigned int)len;
		p += len;
	}
	*wp++ = 0;
	*(int *)(base + strp) = 0;
}
static int kexec2(char *path, char **argv, char **envp)
{
	int e, i;
	char kpath[128];

	for(i = 0; i < (int)sizeof(kpath)-1 && path[i]; i++)
		kpath[i] = path[i];
	kpath[i] = 0;
	kargs(path, argv, envp);
	e = kexec(kpath);
	if(e == 0) {
		int slot = slot_by_pid(curpid);
		char *ubase = slot >= 0 ? slot_user_base(slot) : (char *)USERBASE;
		bzero((char *)UARGV, UARGLEN);
		bcopy(argbuf, (char *)UARGV, UARGLEN-1);
		install_v7_user_stack(ubase);
		if(slot >= 0 && ubase != (char *)usermem[slot])
			install_v7_user_stack((char *)usermem[slot]);
		install_sigtramp(ubase);
		if(slot >= 0 && ubase != (char *)usermem[slot])
			install_sigtramp((char *)usermem[slot]);
	}
	return e;
}
int v7_load_image(char *path, char **argv, char **envp)
{ return kexec2(path, argv, envp); }
void armboot_post_exec_close(int fd)
{
	if(fd < 0 || fd >= NFD) return;
	if(files[fd].ino == 0) return;
	if(fd_is_v7_reg(fd))
		(void)putino(files[fd].ino, &files[fd]);
	bzero((char *)&files[fd], sizeof(files[fd]));
	if(fd < 3) closed[fd] = 1;
}
static long ksignal(int sig, long fun)
{
	long old;
	if(sig <= 0 || sig >= NSIG || sig == SIGKIL) return -1;
	old = handlers[sig];
	handlers[sig] = fun;
	return old;
}
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
void armboot_ksigreturn(int *r)
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
		h = handlers[sig];
		if(h == SIG_IGN) continue;
			if(h == SIG_DFL) {
				do_exit(0x100 | sig, r);
				return;
			}
			handlers[sig] = SIG_DFL;
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
static void sys_write_v7(void)
{
	char *p;
	int n = ku.u_arg[2], fd = ku.u_arg[0];
	if(fd < 0 || fd >= NFD) { ku.u_error = 9; return; }
	if(files[fd].ino == 0 && fd >= 3) {
		ku.u_error = 9; return;
	}
	if(files[fd].kmem == 2) { ku.u_rval1 = n; return; }
	if(files[fd].pipe != 0) {
		struct pipe *pp = &pipes[files[fd].pipe-1];
		if(files[fd].wpipe && !mt_pipe_has_reader(files[fd].pipe)) {
			ku.u_error = 32;
			kkill(curpid, SIGPIPE);
			ku.u_rval1 = -1;
			return;
		}
		if(files[fd].wpipe && pp->wpos >= PIPESIZ) {
			psig_drain(curpid, &pending);
			if(sig_deliverable(pending)) { ku.u_error = 4; return; }
			if(mt_pipe_has_reader(files[fd].pipe) &&
			   mt_block_on_pipe(trap_r, S_WRITE,
			       -(200 + files[fd].pipe)) == 0) {
				mt_switched = 1; return;
			}
			ku.u_rval1 = 0; return;
		}
		if(pp->wpos + (unsigned int)n > PIPESIZ)
			n = PIPESIZ - pp->wpos;
		bcopy((char *)ku.u_arg[1], pp->buf + pp->wpos, n);
		pp->wpos += n;
		ku.u_rval1 = n;
		mt_wake_pipe(files[fd].pipe, 1);
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
		if(w > 0) {
			files[fd].dirty = 1;
			(void)putino(files[fd].ino, &files[fd]);
		}
		if(w >= 0 && v7_ofile_isset(fd)) {
			v7_inode_refresh(fd, files[fd].size,
			    (unsigned int *)files[fd].addr);
			if(w > 0) v7_inode_mark_dirty(fd);
			v7_set_offset(fd, (long)files[fd].off);
		}
		return;
	}
	if(fd > 2 && (files[fd].ino == 0 || (files[fd].mode & IFMT) != IFCHR)) {
		ku.u_error = 9; return;
	}
	p = (char *)ku.u_arg[1];
	for(int i = 0; i < n; i++) putchar(p[i]);
	ku.u_rval1 = n;
}
static void sys_open_v7(void)
{
	int r = kopen((char *)ku.u_arg[0]);
	if(r < 0) ku.u_error = 2; else ku.u_rval1 = r;
}
static void sys_creat_v7(void)
{
	int r = kcreat((char *)ku.u_arg[0], ku.u_arg[1]);
	if(r == -2) ku.u_error = 21;
	else if(r < 0) ku.u_error = 2;
	else ku.u_rval1 = r;
}
static void sys_fstat_v7(void)
{
	int fd = ku.u_arg[0], r;
	if(fd >= 0 && fd < NFD && files[fd].ino != 0) {
		r = kfstat(fd, (struct ustat *)ku.u_arg[1]);
		if(r < 0) ku.u_error = 9;
		else ku.u_rval1 = r;
		return;
	}
	r = v7_fstat_call(fd, (void *)ku.u_arg[1]);
	if(r == 0) { ku.u_rval1 = 0; return; }
	if(r > 0) { ku.u_error = r; return; }
	r = kfstat(ku.u_arg[0], (struct ustat *)ku.u_arg[1]);
	if(r < 0) ku.u_error = 9;
	else ku.u_rval1 = r;
}
static void sys_close_v7(void)
{
	int fd = ku.u_arg[0], r;
	r = kclose(fd);
	if(r < 0) ku.u_error = 9; else ku.u_rval1 = r;
}
static void sys_dup_v7(void)
{
	int from = ku.u_arg[0], to = ku.u_arg[1], r;
	if(from >= 0 && from < NFD && v7_ofile_isset(from)) {
		if(to < 0 && (to = alloc_fd_slot()) < 0) { ku.u_error = 24; return; }
		if(to < 0 || to >= NFD) { ku.u_error = 9; return; }
		if(to != from) {
			if(files[to].ino != 0 || !closed[to])
				(void)kclose(to);
			bcopy((char *)&files[from], (char *)&files[to], sizeof(files[to]));
		}
		closed[to] = 0;
		v7_ofile_dup(from, to);
		ku.u_rval1 = to;
		return;
	}
	r = kdup(from, to);
	if(r < 0) ku.u_error = 9; else ku.u_rval1 = r;
}
static void sys_lseek_v7(void)
{
	int fd = ku.u_arg[0], off = ku.u_arg[1], whence = ku.u_arg[2], r;
	r = kseek(fd, off, whence);
	if(r == -2) ku.u_error = 29;
	else if(r < 0) ku.u_error = 9;
	else ku.u_rval1 = r;
}
static void sys_read_v7(void)
{
	int fd = ku.u_arg[0], r;
	char *buf = (char *)ku.u_arg[1];
	unsigned int n = (unsigned int)ku.u_arg[2];
	if(fd >= 0 && fd < NFD && files[fd].pipe != 0) {
		struct pipe *pp = &pipes[files[fd].pipe-1];
		if(pp->rpos >= pp->wpos && mt_pipe_has_writer(files[fd].pipe)) {
			int rc;
			psig_drain(curpid, &pending);
			if(sig_deliverable(pending)) { ku.u_error = 4; return; }
			while((rc = mt_block_on_pipe(trap_r, S_READ,
			                    -(100 + files[fd].pipe))) < 0) {
				if(!mt_pipe_has_writer(files[fd].pipe)) break;
				pause_spin_barrier();
			}
			if(rc == 0) {
				mt_switched = 1;
				return;
			}
			}
		}
	r = kread(fd, buf, n);
	if(r < 0) {
		if(!ku.u_error) ku.u_error = 9;
	} else ku.u_rval1 = r;
}
static void sys_pipe(void)
{
	int r = kpipe((int *)ku.u_arg[0]);
	if(r < 0) ku.u_error = 24; else ku.u_rval1 = r;
}
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
	int r, next, my_slot, has_child = 0, ppid, status = 0;
	psig_drain(curpid, &pending);
	r = v7_wait_check(curpid, &status);
	if(r > 0) { ku.u_rval1 = r; ku.u_rval2 = status; kdone_drop(r); return; }
	r = kwait(curpid, &status);
	if(r >= 0) { ku.u_rval1 = r; ku.u_rval2 = status; v7_proc_reap(r); return; }
	if(sig_deliverable(pending)) { ku.u_error = 4; return; }
	for(int i = 0; i < NPROCSAVE && !has_child; i++)
		has_child = armproc[i].inuse && armproc[i].ppid == curpid;
	for(int i = 0; i < ndone && !has_child; i++)
		has_child = childdone[i].ppid == curpid;
	if(!has_child) { ku.u_error = 10; return; }
	next = mt_pick_runnable();
	if(next < 0) {
		__asm__ volatile("cpsie i\n\tisb" ::: "memory");
		while((next = mt_pick_runnable()) < 0)
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
static void sys_umask_v7(void)
{
	ku.u_rval1 = kumask & 0777;
	kumask = ku.u_arg[0] & 0777;
	u.u_cmask = (short)kumask;
}
static void sys_getuid_v7(void)
{ ku.u_rval1 = v7_getuid_call(kuid); ku.u_rval2 = kuid; }
static void sys_getgid_v7(void)
{ ku.u_rval1 = v7_getgid_call(kgid); ku.u_rval2 = kgid; }
static void sys_getpid_v7(void)
{
	int ppid = v7_getppid_call(curpid);
	ku.u_rval1 = curpid;
	ku.u_rval2 = ppid < 0 ? 1 : ppid;
}
static void sys_chdir_v7(void)
{
	struct kfile fp;
	struct inode *ip;
	ino_t ino = v7_namei_inum((char *)ku.u_arg[0]);
	if(ino == 0)
		ino = knamei((char *)ku.u_arg[0]);
	if(ino == 0 || loadino(ino, &fp) < 0) { ku.u_error = 2; return; }
	if((fp.mode & IFMT) != IFDIR) { ku.u_error = 20; return; }
	cwdino = ino;
	ip = iget(rootdev, ino);
	if(ip != NULL) {
		if(u.u_cdir != NULL) iput(u.u_cdir);
		u.u_cdir = ip;
		u.u_cdir->i_flag &= ~ILOCK;
	}
	ku.u_rval1 = 0;
}
static void sys_chroot_v7(void)
{
	int e = v7_chroot_call((char *)ku.u_arg[0]);
	if(e) ku.u_error = e; else ku.u_rval1 = 0;
}
static int is_dev_console(char *p) { return strcmp(p, "/dev/console") == 0; }
static void sys_chmod_v7(void)
{
	int e;
	if(is_dev_console((char *)ku.u_arg[0])) { ku.u_rval1 = 0; return; }
	e = kchmod((char *)ku.u_arg[0], ku.u_arg[1]);
	if(e) ku.u_error = e; else ku.u_rval1 = 0;
}
static void sys_chown_v7(void)
{
	int e;
	if(is_dev_console((char *)ku.u_arg[0])) { ku.u_rval1 = 0; return; }
	e = kchown((char *)ku.u_arg[0], ku.u_arg[1], ku.u_arg[2]);
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
	if(!is_tty_fd(ku.u_arg[0]) || ku.u_arg[1] == 0) { ku.u_error = 25; return; }
	bcopy((char *)ku.u_arg[1], (char *)&console_sgtty, sizeof(console_sgtty));
	ku.u_rval1 = 0;
}
static void sys_gtty(void)
{
	if(!is_tty_fd(ku.u_arg[0]) || ku.u_arg[1] == 0) { ku.u_error = 25; return; }
	bcopy((char *)&console_sgtty, (char *)ku.u_arg[1], sizeof(console_sgtty));
	ku.u_rval1 = 0;
}
static void sys_ioctl_v7(void)
{
	int fd = ku.u_arg[0], cmd = ku.u_arg[1];
	char *arg = (char *)ku.u_arg[2];
	if(fd < 0 || fd >= NFD || files[fd].ino == 0) { ku.u_error = 9; return; }
	switch(cmd) {
	case ('f' << 8) | 1:
		closed[fd] |= 1; v7_pofile_excl_set(fd);
		ku.u_rval1 = 0; return;
	case ('f' << 8) | 2:
		closed[fd] &= ~1; v7_pofile_excl_clear(fd);
		ku.u_rval1 = 0; return;
	case ('t' << 8) | 8:
	case ('t' << 8) | 9:
		if(!is_tty_fd(fd) || arg == 0) { ku.u_error = 25; return; }
		if(cmd == (('t' << 8) | 8))
			bcopy((char *)&console_sgtty, arg, sizeof(console_sgtty));
		else
			bcopy(arg, (char *)&console_sgtty, sizeof(console_sgtty));
		ku.u_rval1 = 0;
		return;
	}
	ku.u_error = 25;
}
static void sys_stat_v7(void)
{
	struct kfile fp;
	ino_t ino;
	ino = v7_namei_inum((char *)ku.u_arg[0]);
	if(ino == 0)
		ino = knamei((char *)ku.u_arg[0]);
	if(ino == 0 || loadino(ino, &fp) < 0) { ku.u_error = 2; return; }
	ustat(ino, &fp, (struct ustat *)ku.u_arg[1]);
	ku.u_rval1 = 0;
}
static void sys_access_v7(void)
{
	int e;
	char *path = (char *)ku.u_arg[0];
	if(strcmp(path, "/dev/console") == 0
	    || strcmp(path, "/dev/mem") == 0
	    || strcmp(path, "/dev/kmem") == 0
	    || strcmp(path, "/dev/root") == 0) { ku.u_rval1 = 0; return; }
	e = v7_access_call(path, ku.u_arg[1]);
	if(e == ENOENT && knamei(path) != 0)
		e = 0;
	if(e) ku.u_error = e; else ku.u_rval1 = 0;
}
static void sys_unlink_v7(void)
{
	int e = kunlink((char *)ku.u_arg[0]);
	if(e) ku.u_error = e; else ku.u_rval1 = 0;
}
static void sys_link_v7(void)
{
	int e = klink((char *)ku.u_arg[0], (char *)ku.u_arg[1]);
	if(e == -2) ku.u_error = 17;
	else if(e < 0) ku.u_error = 2;
	else ku.u_rval1 = 0;
}
static void sys_exec_v7(void)
{
	int err = v7_exec_call((char *)ku.u_arg[0], (char **)ku.u_arg[1],
	    (char **)ku.u_arg[2]);
	if(err) ku.u_error = err < 0 ? -err : err; else ku.u_rval1 = 0;
}
static void sys_mknod_v7(void)
{
	int e = kmknod((char *)ku.u_arg[0], ku.u_arg[1], ku.u_arg[2]);
	if(e == -2) ku.u_error = 17;
	else if(e < 0) ku.u_error = 2;
	else ku.u_rval1 = 0;
}
static void sys_setuid_v7(void)
{
	int new = v7_setuid_call(kuid, ku.u_arg);
	if(!ku.u_error) { kuid = new; ku.u_rval1 = 0; }
}
static void sys_setgid_v7(void)
{
	int new = v7_setgid_call(kgid, ku.u_arg);
	if(!ku.u_error) { kgid = new; ku.u_rval1 = 0; }
}
static void scrub_pseudo_inode_updates(void)
{
	for(struct inode *ip = &inode[0]; ip < &inode[NINODE]; ip++)
		if((ip->i_flag&(IUPD|IACC|ICHG)) != 0 && ip->i_dev != rootdev)
			ip->i_flag &= ~(IUPD|IACC|ICHG);
}
static void sys_sync_v7(void)
{
	scrub_pseudo_inode_updates();
	(void)v7_sync_call();
	ku.u_rval1 = 0;
}
static void sys_nice_v7(void)
{
	(void)v7_nice_call(ku.u_arg, curpid);
	ku.u_rval1 = 0;
}
static void sys_gtime_v7(void)
{
	long t = v7_gtime_call();
	ku.u_rval1 = (int)t;
	ku.u_rval2 = (int)(t >> 16);
}
static void sys_stime_v7(void)
{ (void)v7_stime_call(ku.u_arg); ku.u_rval1 = 0; }
static void sys_alarm_v7(void)
{
	struct proc *p = proc_by_pid(curpid);
	int old = p ? p->p_clktim : 0;
	if(p) p->p_clktim = ku.u_arg[0];
	ku.u_rval1 = old;
}
static void sys_pause_v7(void)
{
	int next, my_slot, ppid;
	psig_drain(curpid, &pending);
	if(sig_deliverable(pending)) { ku.u_error = 4; return; }
	if((next = mt_pick_runnable()) >= 0) {
		ppid = v7_get_ppid(curpid);
		if(ppid < 0) ppid = 1;
		if((my_slot = mt_save_slot(curpid, ppid, PSTATE_SLEEP)) >= 0) {
			mt_save_current(my_slot, trap_r, PSTATE_SLEEP);
			armproc[my_slot].wait_for = -2;
			armproc[my_slot].frame[0]  = -4;
			mt_load_slot(next, trap_r);
			mt_switched = 1;
			return;
		}
	}
	v7_proc_set_current(curpid);
	(void)v7_pause_call(&pending);
	ku.u_error = 4;
}
static void sys_ftime_v7(void)
{ int e = v7_ftime_call(ku.u_arg);  if(e) ku.u_error = e; else ku.u_rval1 = 0; }
static void sys_times_v7(void)
{ int e = v7_times_call(ku.u_arg);  if(e) ku.u_error = e; else ku.u_rval1 = 0; }
static void sys_lock_v7(void)
{ int e = v7_lock_call(ku.u_arg, curpid); if(e) ku.u_error = e; else ku.u_rval1 = 0; }
static void sys_profil_v7(void)
{ int e = v7_profil_call(ku.u_arg); if(e) ku.u_error = e; else ku.u_rval1 = 0; }
static void sys_kill_v7(void)
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
static void sys_nosys(void) { ku.u_error = 22; }
static void sys_nullsys(void) { }
extern void sbreak(void);
static void sys_break_v7(void) { sbreak(); }
extern void ptrace(void);
static void sys_ptrace_v7(void) { ptrace(); }
static struct arm_sysent {
	int	sy_narg;
	void	(*sy_call)(void);
} arm_sysent[64] = {
	{0, sys_nullsys},   {1, sys_nosys},
	{0, sys_nosys},     {3, sys_read_v7},
	{3, sys_write_v7},  {2, sys_open_v7},
	{1, sys_close_v7},  {0, sys_wait},
	{2, sys_creat_v7},  {2, sys_link_v7},
	{1, sys_unlink_v7}, {3, sys_exec_v7},
	{1, sys_chdir_v7},  {0, sys_gtime_v7},
	{3, sys_mknod_v7},  {2, sys_chmod_v7},
	{3, sys_chown_v7},  {1, sys_break_v7},
	{2, sys_stat_v7},   {3, sys_lseek_v7},
	{0, sys_getpid_v7}, {3, sys_mount_v7},
	{1, sys_umount_v7}, {1, sys_setuid_v7},
	{0, sys_getuid_v7}, {1, sys_stime_v7},
	{4, sys_ptrace_v7}, {1, sys_alarm_v7},
	{2, sys_fstat_v7},  {0, sys_pause_v7},
	{2, sys_utime_v7},  {2, sys_stty},
	{2, sys_gtty},      {2, sys_access_v7},
	{1, sys_nice_v7},   {1, sys_ftime_v7},
	{0, sys_sync_v7},   {2, sys_kill_v7},
	{0, sys_nullsys},   {0, sys_nullsys},
	{0, sys_nosys},     {2, sys_dup_v7},
	{1, sys_pipe},      {1, sys_times_v7},
	{4, sys_profil_v7}, {0, sys_nosys},
	{1, sys_setgid_v7}, {0, sys_getgid_v7},
	{2, sys_nosys},     {0, sys_nosys},
	{0, sys_nosys},     {1, sys_sysacct_v7},
	{0, sys_nosys},     {1, sys_lock_v7},
	{3, sys_ioctl_v7},  {0, sys_nosys},
	{0, sys_nosys},     {0, sys_nosys},
	{0, sys_nosys},     {3, sys_exec_v7},
	{1, sys_umask_v7},  {1, sys_chroot_v7},
	{0, sys_nosys},     {0, sys_nosys},
};
static void sysent_dispatch(int n)
{
	ku.u_error = 0;
	ku.u_rval1 = ku.u_rval2 = 0;
	for(int i = 0; i < 6; i++)
		ku.u_arg[i] = 0;
	if(n < 0 || n >= 64) { ku.u_error = 22; return; }
	for(int i = 0; i < arm_sysent[n].sy_narg && i < 6; i++)
		ku.u_arg[i] = trap_r[i];
	if(n != S_EXEC && n != S_EXECE && v7_save_qsav()) return;
	(*arm_sysent[n].sy_call)();
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
	scrub_pseudo_inode_updates();
	kflush();
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
	for(;;);
}
void trap(int *r)
{
	int n = r[7], ret = -1;
	in_trap = 1;
	trap_frame = trap_r = r;
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
		sysent_dispatch(n);
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
void panictrap(void) { panic("trap"); }
void armboot(void)
{
	ino_t cino;
	char initarg[] = "init";
	char *initargv[] = { initarg, 0 };

	startup();
	for(int i = 0; i < 3; i++) {
		files[i].ino = 1;
		files[i].mode = IFCHR;
	}
	shim_bread(SUPERB, blkbuf);
#ifdef EVB
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
	cino = v7_namei_inum("/dev/console");
	if(cino != 0) {
		console_ino = cino;
		for(int i = 0; i < 3; i++) files[i].ino = cino;
	}
	(void)v7_mount_init();
	v7_proc_init();
#ifdef EVB
	{
		ino_t initino = v7_namei_inum("/etc/init");
		printf("evb: init inum=%d\n", (int)initino);
	}
	{
		int rc = kexec2("/etc/init", initargv, 0);
		if (rc < 0) {
			printf("evb: kexec fail rc=%d\n", rc);
			panic("init");
		}
		printf("evb: kexec ok\n");
	}
#else
	if(kexec2("/etc/init", initargv, 0) < 0)
		panic("init");
#endif
	clkstart();
	run_user(UENTRY, USTACK);
}
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
int *trap_frame;
static struct proc * proc_by_pid(int pid)
{
	for(int i = 0; i < NPROC; i++)
		if(proc[i].p_stat != 0 && proc[i].p_pid == (short)pid)
			return &proc[i];
	return NULL;
}
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
int v7_proc_fork(int parent_pid, int child_pid)
{
	struct proc *pp = proc_by_pid(parent_pid);
	short parent_pgrp = pp ? pp->p_pgrp : (short)child_pid;
	short parent_nice = pp ? pp->p_nice : NZERO;
	short parent_uid = pp ? pp->p_uid : 0;
	short parent_size = pp ? pp->p_size : (short)(UARGLEN >> 6);
	int slot = slot_by_pid(child_pid);
	int i;
	for(i = 2; i < NPROC; i++)
		if(proc[i].p_stat == 0) break;
	if(i >= NPROC) return -1;
	pp = &proc[i];
	pp->p_stat = SRUN; pp->p_flag = SLOAD; pp->p_pri = 40;
	pp->p_nice = parent_nice; pp->p_uid = parent_uid;
	pp->p_pgrp = parent_pgrp;
	pp->p_pid = (short)child_pid; pp->p_ppid = (short)parent_pid;
	pp->p_time = pp->p_cpu = pp->p_sig = pp->p_clktim = 0;
	pp->p_size = parent_size;
	pp->p_wchan = 0;
	proc_core(pp, slot);
	pp->p_textp = NULL; pp->p_link = NULL;
	return 0;
}
void v7_proc_exit(int curpid, int code)
{
	struct proc *pp = proc_by_pid(curpid);
	if(pp) {
		pp->p_stat = SZOMB;
		pp->p_clktim = code;
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
			return;
		}
}
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
void v7_proc_set_current(int pid)
{
	struct proc *me = proc_by_pid(pid);
	if(me) {
		proc_core(me, slot_by_pid(pid));
		u.u_procp = me;
	} else
		u.u_procp = &proc[1];
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
int v7_proc_set_stat(int pid, int stat)
{
	struct proc *pp = proc_by_pid(pid);
	if(pp == NULL || pp == &proc[0] || pp->p_stat == SZOMB) return -1;
	pp->p_stat = (char)stat;
	return 0;
}
static void v7_call_prep(int *args)
{
	u.u_ap = args;
	u.u_error = 0;
	u.u_r.r_val1 = u.u_r.r_val2 = 0;
}
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
	u.u_uid = u.u_ruid = 0;
	v7_call_prep(args); setgid(); return u.u_gid;
}
int v7_sync_call(void)
{ v7_call_prep(NULL); sync(); return 0; }
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
	u.u_r.r_time = 0;
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
int v7_ftime_call(int *args)
{ v7_call_prep(args); ftime(); return u.u_error; }
int v7_kill_call(int *args, int kuid, int curpid)
{
	u.u_uid = u.u_ruid = (short)kuid;
	v7_proc_set_current(curpid);
	v7_call_prep(args); kill();
	return u.u_error ? -u.u_error : 0;
}
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
void v7_u_times_snapshot(long *utp, long *stp)
{
	*utp = (long)u.u_utime + (long)u.u_cutime;
	*stp = (long)u.u_stime + (long)u.u_cstime;
}
void v7_u_times_add_child(long ut, long st)
{ u.u_cutime += ut; u.u_cstime += st; }
int v7_profil_call(int *args)
{ v7_call_prep(args); profil(); return u.u_error; }
int v7_lock_call(int *args, int curpid)
{
	v7_proc_set_current(curpid);
	u.u_uid = u.u_procp->p_uid;
	v7_call_prep(args); syslock();
	return u.u_error;
}
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
extern void psignal(struct proc *p, int sig);
void v7_signal_pgrp(int sig, int curpid)
{
	struct proc *me = proc_by_pid(curpid);
	short pgrp;
	if(me == NULL || (pgrp = me->p_pgrp) == 0) return;
	for(int i = 2; i < NPROC; i++)
		if(proc[i].p_stat != 0 && proc[i].p_pgrp == pgrp)
			psignal(&proc[i], sig);
}
extern void bcopy(char *, char *, unsigned int);
int v7_save_qsav(void) { return save((int *)u.u_qsav); }
void v7_u_qsav_save(int *dst)
{ bcopy((char *)u.u_qsav, (char *)dst, sizeof(u.u_qsav)); }
void v7_u_qsav_restore(const int *src)
{ bcopy((char *)src, (char *)u.u_qsav, sizeof(u.u_qsav)); }
void v7_reparent_children(int dying_pid, int new_ppid)
{
	for(int i = 0; i < NPROC; i++)
		if(proc[i].p_stat != 0 && proc[i].p_ppid == (short)dying_pid)
			proc[i].p_ppid = (short)new_ppid;
}
void v7_u_signal_save(long *out_sig)
{
	for(int i = 0; i < NSIG; i++) out_sig[i] = (long)u.u_signal[i];
}
void v7_u_signal_restore(const long *in_sig)
{
	for(int i = 0; i < NSIG; i++) u.u_signal[i] = (int)in_sig[i];
}
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
static void v7_path_prep(char *path, int *args)
{
	u.u_uid = u.u_ruid = 0;
	if(u.u_cdir == NULL && rootdir != NULL) {
		u.u_cdir = iget(rootdir->i_dev, rootdir->i_number);
		if(u.u_cdir != NULL) u.u_cdir->i_flag &= ~ILOCK;
	}
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
extern dev_t rootdev;
void v7_ofile_clear(int fd);
void v7_ofile_set(int fd, ino_t ino, int flag)
{
	struct inode *ip;
	struct file *fp;
	if(fd < 0 || fd >= NOFILE) return;
	if(u.u_ofile[fd]) v7_ofile_clear(fd);
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
	iput(ip);
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
	if(ip) {
		if(ip->i_dev != rootdev) {
			ip->i_flag &= ~(IUPD|IACC|ICHG);
			if(ip->i_count > 0) ip->i_count--;
			return;
		}
		struct mount *mp;
		for(mp = &mount[0]; mp < &mount[NMOUNT]; mp++)
			if(mp->m_bufp != NULL && mp->m_dev == ip->i_dev)
				break;
		if(mp == &mount[NMOUNT])
			ip->i_flag &= ~(IUPD|IACC|ICHG);
		iput(ip);
	}
}
void v7_ofile_dup(int from, int to)
{
	struct file *fp;
	if(from < 0 || from >= NOFILE || to < 0 || to >= NOFILE) return;
	fp = u.u_ofile[from];
	if(fp == NULL) {
		if(u.u_ofile[to]) v7_ofile_clear(to);
		return;
	}
	if(u.u_ofile[to] == fp) return;
	if(u.u_ofile[to]) v7_ofile_clear(to);
	u.u_ofile[to] = fp;
	u.u_pofile[to] = 0;
	fp->f_count++;
}
void v7_ofile_save(void *buf)
{ bcopy((char *)u.u_ofile, (char *)buf, sizeof(u.u_ofile)); }
void v7_ofile_restore(void *buf)
{ bcopy((char *)buf, (char *)u.u_ofile, sizeof(u.u_ofile)); }
void v7_pofile_save(void *buf)
{ bcopy((char *)u.u_pofile, (char *)buf, sizeof(u.u_pofile)); }
void v7_pofile_restore(void *buf)
{ bcopy((char *)buf, (char *)u.u_pofile, sizeof(u.u_pofile)); }
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
static int v7_fd_prep(int fd, int *args)
{
	if(fd < 0 || fd >= NOFILE || u.u_ofile[fd] == NULL) return -1;
	u.u_ap = args;
	u.u_segflg = 1;
	u.u_error = 0;
	u.u_r.r_val1 = u.u_r.r_val2 = 0;
	return 0;
}
int v7_u_error_get(void) { return (int)u.u_error; }
void v7_inode_drop(void *p)
{
	struct inode *ip = (struct inode *)p;
	if(ip) iput(ip);
}
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
	ip->i_flag |= IUPD | ICHG;
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
void v7_inode_mark_dirty_ino(ino_t ino)
{
	struct inode *ip = find_inode(ino);
	if(ip == NULL) return;
	ip->i_flag |= IUPD | ICHG;
}
void v7_inode_set_mode_ino(ino_t ino, unsigned short mode)
{
	struct inode *ip = find_inode(ino);
	if(ip == NULL) return;
	ip->i_mode = mode;
	ip->i_flag |= ICHG;
}
void v7_inode_set_owner_ino(ino_t ino, short uid, short gid)
{
	struct inode *ip = find_inode(ino);
	if(ip == NULL) return;
	ip->i_uid = uid;
	ip->i_gid = gid;
	ip->i_flag |= ICHG;
}
int v7_inode_snapshot_ino(ino_t ino, unsigned int *size_out, unsigned int *addrs_out)
{
	struct inode *ip = find_inode(ino);
	if(ip == NULL) return -1;
	if(size_out) *size_out = (unsigned int)ip->i_size;
	if(addrs_out) v7_inode_unpack_addr(ip, addrs_out);
	return 0;
}
extern int v7_load_image(char *path, char **argv, char **envp);
extern void closef(struct file *fp);
extern void armboot_post_exec_close(int fd);
int v7_exec_call(char *path, char **argv, char **envp)
{
	int rc = v7_load_image(path, argv, envp);
	if(rc != 0) return rc < 0 ? -rc : 1;
	for(int i = 0; i < NOFILE; i++)
		if(u.u_pofile[i] & EXCLOSE) {
			if(u.u_ofile[i]) closef(u.u_ofile[i]);
			u.u_ofile[i] = NULL;
			u.u_pofile[i] &= ~EXCLOSE;
			armboot_post_exec_close(i);
		}
	for(int i = 1; i < NSIG; i++)
		if(u.u_signal[i] != 1) u.u_signal[i] = 0;
	if(trap_frame) {
		trap_frame[13] = (int)USTACK;
		trap_frame[14] = 0;
		trap_frame[15] = (int)UENTRY;
	}
	u.u_ap = NULL;
	return 0;
}
extern void armboot_ksigreturn(int *r);
int v7_sigreturn_call(int *r)
{
	armboot_ksigreturn(r);
	if(u.u_procp == NULL) u.u_procp = &proc[0];
	v7_call_prep(NULL);
	return 0;
}
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
int v7_mount_init(void)
{
	struct buf *bp, *mb;
	struct filsys *fp;
	if(mount[0].m_bufp != NULL) return 0;
	if(rootdir == NULL) return -1;
	bp = bread(rootdev, (daddr_t)SUPERB);
	if(bp->b_flags & B_ERROR) { brelse(bp); return -1; }
	mb = geteblk();
	bcopy((char *)bp->b_un.b_addr, (char *)mb->b_un.b_addr,
	    (unsigned int)BSIZE);
	fp = mb->b_un.b_filsys;
	fp->s_ilock = fp->s_flock = fp->s_ronly = 0;
	time = fp->s_time;
	brelse(bp);
	mount[0].m_dev = rootdev;
	mount[0].m_bufp = mb;
	mount[0].m_inodp = rootdir;
	return 0;
}
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
#define GICD_BASE	0x08000000U
#define GICC_BASE	0x08010000U
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
extern long dk_time[];
extern int lbolt;
extern void clock(int dev, int sp, int r1, int nps, int r0, caddr_t pc, int ps);
static unsigned int timer_reload;
int irq_ready;
volatile int in_clock_irq;
extern volatile int in_trap;
void clock_irq_handler(int *tf)
{
	unsigned int iar = GICC_IAR;
	unsigned int intid = iar & 0x3ff;
	if(intid == 1023) return;
	if(intid == TIMER_IRQ) {
		int mode = tf[16] & 0x1f;
		int usermode = (mode == 0x10) || (mode == 0x1f);
		cntv_tval_set(timer_reload);
		if((usermode || in_spin_wait) && u.u_procp != NULL &&
		   !in_clock_irq) {
			extern void mt_clock_tick(void);
			in_clock_irq = 1;
			clock(0, 0, 0, 0, 0, (caddr_t)0,
			    usermode ? 0xf000 : 0);
			in_clock_irq = 0;
			mt_clock_tick();
		}
	}
	GICC_EOIR = iar;
}
void arm_timer_init(void)
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
	GICD_CTLR = 1;
	GICC_PMR  = 0xff;
	GICC_CTLR = 1;
	cntv_tval_set(timer_reload);
	cntv_ctl_set(1);
	irq_ready = 1;
	irq_enable();
}

void clkstart(void)
{

	arm_timer_init();
}
