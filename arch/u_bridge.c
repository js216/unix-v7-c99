/* u_bridge.c: hands v7 syscalls to K&R impls in sys/sys{2,3,4}.c using
 * v7stubs.c's `struct user u`; armboot.c has its own static shadow. */
#include "../h/param.h"
#include "../h/dir.h"
#include "../h/file.h"
#include "../h/user.h"
#include "../h/proc.h"
#include "../h/systm.h"
#include "../h/inode.h"
#include "arm.h"
/* v7 syscall entry points (in sys/sys{2,3,4}.c, sig.c, prim.c). */
extern void umask(void), getuid(void), getgid(void), getpid(void);
extern void setuid(void), setgid(void), sync(void), nice(void);
extern void gtime(void), stime(void), alarm(void), ftime(void), times(void);
extern void kill(void), ssig(void), chdir(void), chmod(void), chown(void);
extern void sysacct(void), utime(void), profil(void), syslock(void);
extern void stat(void), fstat(void), saccess(void), unlink(void), link(void);
extern void mknod(void), smount(void), sumount(void);
extern void close(void), dup(void), seek(void), read(void), write(void);
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
	int parent_slot = pp ? (int)(pp - proc) : -1;
	int i;
	/* Skip proc[0]/proc[1] (kill 0/pgrp guard reserves them). */
	for(i = 2; i < NPROC; i++)
		if(proc[i].p_stat == 0) break;
	if(i >= NPROC) return -1;
	pp = &proc[i];
	pp->p_stat = SRUN; pp->p_flag = SLOAD; pp->p_pri = 40;
	pp->p_nice = parent_nice; pp->p_uid = u.u_uid;
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
	return u.u_error ? -1 : 0;
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
extern int save(int *);
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
	if(p) u.u_cdir = (struct inode *)p;
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
	return u.u_error ? -1 : 0;
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
int v7_fstat_call(int fd, void *ubuf)
{
	int args[2] = { fd, (int)(long)ubuf };
	if(v7_fd_prep(fd, args) < 0) return -1;
	fstat();
	return u.u_error ? -1 : 0;
}
int v7_close_call(int fd)
{
	int args[1] = { fd };
	if(v7_fd_prep(fd, args) < 0) return -1;
	close();
	return u.u_error ? -1 : 0;
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
int v7_write_call(int fd, char *buf, unsigned int n)
{ return v7_rdwr_call(fd, buf, n, FWRITE, write); }
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
int v7_exec_call(char *path, char **argv, char **envp)
{
	int rc = v7_load_image(path, argv, envp);
	if(rc != 0) return rc < 0 ? -rc : 1;
	/* Close-on-exec sweep (EXCLOSE=01 in h/user.h). */
	for(int i = 0; i < NOFILE; i++)
		if(u.u_pofile[i] & EXCLOSE) {
			if(u.u_ofile[i]) closef(u.u_ofile[i]);
			u.u_ofile[i] = NULL;
			u.u_pofile[i] &= ~EXCLOSE;
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
extern unsigned int cntfrq_get(void), cntv_ctl_get(void);
extern void cntv_tval_set(unsigned int v), cntv_ctl_set(unsigned int v);
extern void irq_enable(void);
/* v7 clock(): ps=UMODE if trap-time CPSR=user; lks steered at scratch word. */
extern long dk_time[];
extern int lbolt;
extern void clock(int dev, int sp, int r1, int nps, int r0, caddr_t pc, int ps);
extern physadr lks;
static unsigned int timer_reload;	/* CNTFRQ / HZ */
static int lks_scratch_word;
#define LKS_SCRATCH	((physadr)&lks_scratch_word)
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
	lks = LKS_SCRATCH;	/* satisfy clock()'s `lks->r[0]=0115` */
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
