#include "../h/param.h"
#include "../h/systm.h"
#include "../h/dir.h"
#include "../h/inode.h"
#include "../h/file.h"
#include "../h/proc.h"
#include "../h/user.h"
#include "../h/tty.h"

#define S_EXEC		11
#define S_EXECE		59
struct kuser {
	int u_arg[6], u_error, u_rval1, u_rval2, u_segflg;
};
struct kuser ku;
struct arm_sysent {
	int	sy_narg;
	int	sy_v7;
	void	(*sy_call)(void);
};
void sys_nullsys(void);
void sys_nosys(void);
void sys_wait(void);
void sys_link_v7(void);
void sys_unlink_v7(void);
void sys_exec_v7(void);
void sys_gtime_v7(void);
void sys_mknod_v7(void);
void sys_chmod_v7(void);
void sys_chown_v7(void);
void sys_break_v7(void);
void sys_stat_v7(void);
void sys_getpid_v7(void);
void sys_mount_v7(void);
void sys_umount_v7(void);
void sys_setuid_v7(void);
void sys_getuid_v7(void);
void sys_stime_v7(void);
void sys_ptrace_v7(void);
void sys_alarm_v7(void);
void sys_pause_v7(void);
void sys_utime_v7(void);
void sys_stty(void);
void sys_gtty(void);
void sys_access_v7(void);
void sys_nice_v7(void);
void sys_ftime_v7(void);
void sys_sync_v7(void);
void sys_kill_v7(void);
void sys_times_v7(void);
void sys_profil_v7(void);
void sys_setgid_v7(void);
void sys_getgid_v7(void);
void sys_sysacct_v7(void);
void sys_lock_v7(void);
void sys_ioctl_v7(void);
void sys_umask_v7(void);
void sys_chroot_v7(void);
int v7_save_qsav(void);
extern int kuid, kgid, kumask, curpid;
extern time_t time;
struct proc *proc_by_pid(int pid);
int slot_by_pid(int pid);
int v7_mount_call(char *special, char *dir, int ro);
int v7_umount_call(char *special);
int v7_chroot_call(char *path);
int v7_chmod_call(char *path, int mode);
int v7_sysacct_call(char *path);
int v7_chown_call(char *path, int uid, int gid);
int v7_utime_call(char *path, void *tptr);
int v7_stat_call(char *path, void *ubuf);
int v7_access_call(char *path, int mode);
int v7_unlink_call(char *path);
int v7_link_call(char *from, char *to);
int v7_mknod_call(char *path, int mode, int dev);
int v7_getuid_call(int kuid);
int v7_getgid_call(int kgid);
int v7_getppid_call(int curpid);
int v7_setuid_call(int kuid, int *args);
int v7_setgid_call(int kgid, int *args);
int v7_sync_call(void);
int v7_nice_call(int *args, int curpid);
long v7_gtime_call(void);
long v7_stime_call(int *args);
int v7_ftime_call(int *args);
int v7_times_call(int *args);
int v7_profil_call(int *args);
int v7_lock_call(int *args, int curpid);
int v7_exec_call(char *path, char **argv, char **envp);
void sbreak(void);
void ptrace(void);
void v7_call_prep(int *args);
void v7_pofile_excl_set(int fd), v7_pofile_excl_clear(int fd);
void bcopy(char *from, char *to, unsigned int n);
void read(void), write(void), close(void), dup(void), seek(void), pipe(void);
void open(void), creat(void), fstat(void), chdir(void);
struct ttiocb console_sgtty = {
	13, 13, '#', '@', EVENP|ODDP|ECHO|CRMOD|XTABS
};
/*
 * This table is the switch used to transfer
 * to the appropriate routine for processing a system call.
 * Each row contains the number of arguments expected
 * and a pointer to the routine.
 */

struct arm_sysent arm_sysent[64] =
{
	{0, 0, sys_nullsys},		/*  0 = indir */
	{1, 0, sys_nosys},		/*  1 = exit */
	{0, 0, sys_nosys},		/*  2 = fork */
	{3, 1, read},			/*  3 = read */
	{3, 1, write},			/*  4 = write */
	{2, 1, open},			/*  5 = open */
	{1, 1, close},			/*  6 = close */
	{0, 0, sys_wait},		/*  7 = wait */
	{2, 1, creat},			/*  8 = creat */
	{2, 0, sys_link_v7},		/*  9 = link */
	{1, 0, sys_unlink_v7},		/* 10 = unlink */
	{3, 0, sys_exec_v7},		/* 11 = exec */
	{1, 1, chdir},			/* 12 = chdir */
	{0, 0, sys_gtime_v7},		/* 13 = time */
	{3, 0, sys_mknod_v7},		/* 14 = mknod */
	{2, 0, sys_chmod_v7},		/* 15 = chmod */
	{3, 0, sys_chown_v7},		/* 16 = chown; now 3 args */
	{1, 0, sys_break_v7},		/* 17 = break */
	{2, 0, sys_stat_v7},		/* 18 = stat */
	{3, 1, seek},			/* 19 = seek */
	{0, 0, sys_getpid_v7},		/* 20 = getpid */
	{3, 0, sys_mount_v7},		/* 21 = mount */
	{1, 0, sys_umount_v7},		/* 22 = umount */
	{1, 0, sys_setuid_v7},		/* 23 = setuid */
	{0, 0, sys_getuid_v7},		/* 24 = getuid */
	{1, 0, sys_stime_v7},		/* 25 = stime */
	{4, 0, sys_ptrace_v7},		/* 26 = ptrace */
	{1, 0, sys_alarm_v7},		/* 27 = alarm */
	{2, 1, fstat},			/* 28 = fstat */
	{0, 0, sys_pause_v7},		/* 29 = pause */
	{2, 0, sys_utime_v7},		/* 30 = utime */
	{2, 0, sys_stty},		/* 31 = stty */
	{2, 0, sys_gtty},		/* 32 = gtty */
	{2, 0, sys_access_v7},		/* 33 = access */
	{1, 0, sys_nice_v7},		/* 34 = nice */
	{1, 0, sys_ftime_v7},		/* 35 = ftime; formerly sleep */
	{0, 0, sys_sync_v7},		/* 36 = sync */
	{2, 0, sys_kill_v7},		/* 37 = kill */
	{0, 0, sys_nullsys},		/* 38 = switch; inoperative */
	{0, 0, sys_nullsys},		/* 39 = setpgrp (not in yet) */
	{0, 0, sys_nosys},		/* 40 = tell (obsolete) */
	{2, 1, dup},			/* 41 = dup */
	{1, 1, pipe},			/* 42 = pipe */
	{1, 0, sys_times_v7},		/* 43 = times */
	{4, 0, sys_profil_v7},		/* 44 = prof */
	{0, 0, sys_nosys},		/* 45 = unused */
	{1, 0, sys_setgid_v7},		/* 46 = setgid */
	{0, 0, sys_getgid_v7},		/* 47 = getgid */
	{2, 0, sys_nosys},		/* 48 = sig */
	{0, 0, sys_nosys},		/* 49 = reserved for USG */
	{0, 0, sys_nosys},		/* 50 = reserved for USG */
	{1, 0, sys_sysacct_v7},		/* 51 = turn acct off/on */
	{0, 0, sys_nosys},		/* 52 = set user physical addresses */
	{1, 0, sys_lock_v7},		/* 53 = lock user in core */
	{3, 0, sys_ioctl_v7},		/* 54 = ioctl */
	{0, 0, sys_nosys},		/* 55 = readwrite (in abeyance) */
	{0, 0, sys_nosys},		/* 56 = creat mpx comm channel */
	{0, 0, sys_nosys},		/* 57 = reserved for USG */
	{0, 0, sys_nosys},		/* 58 = reserved for USG */
	{3, 0, sys_exec_v7},		/* 59 = exece */
	{1, 0, sys_umask_v7},		/* 60 = umask */
	{1, 0, sys_chroot_v7},		/* 61 = chroot */
	{0, 0, sys_nosys},		/* 62 = x */
	{0, 0, sys_nosys}		/* 63 = used internally */
};
void
sysent_dispatch(int n, int *r)
{
	ku.u_error = 0;
	ku.u_rval1 = ku.u_rval2 = 0;
	for(int i = 0; i < 6; i++)
		ku.u_arg[i] = 0;
	if(n < 0 || n >= 64) { ku.u_error = 22; return; }
	for(int i = 0; i < arm_sysent[n].sy_narg && i < 6; i++) {
		ku.u_arg[i] = r[i];
		if(i < 5)
			u.u_arg[i] = r[i];
	}
	if(n != S_EXEC && n != S_EXECE && v7_save_qsav()) return;
	if(arm_sysent[n].sy_v7)
		v7_call_prep(u.u_arg);
	(*arm_sysent[n].sy_call)();
	if(arm_sysent[n].sy_v7) {
		ku.u_error = u.u_error;
		ku.u_rval1 = u.u_r.r_val1;
		ku.u_rval2 = u.u_r.r_val2;
	}
}
void
sys_mount_v7(void)
{
	int err = v7_mount_call((char *)ku.u_arg[0],
	    (char *)ku.u_arg[1], ku.u_arg[2]);
	if(err) ku.u_error = err; else ku.u_rval1 = 0;
}
void
sys_umount_v7(void)
{
	int err = v7_umount_call((char *)ku.u_arg[0]);
	if(err) ku.u_error = err; else ku.u_rval1 = 0;
}
void
sys_umask_v7(void)
{
	ku.u_rval1 = kumask & 0777;
	kumask = ku.u_arg[0] & 0777;
	u.u_cmask = (short)kumask;
}
void sys_getuid_v7(void)
{ ku.u_rval1 = v7_getuid_call(kuid); ku.u_rval2 = kuid; }
void sys_getgid_v7(void)
{ ku.u_rval1 = v7_getgid_call(kgid); ku.u_rval2 = kgid; }
void
sys_getpid_v7(void)
{
	int ppid = v7_getppid_call(curpid);
	ku.u_rval1 = curpid;
	ku.u_rval2 = ppid < 0 ? 1 : ppid;
}
void
sys_chroot_v7(void)
{
	int e = v7_chroot_call((char *)ku.u_arg[0]);
	if(e) ku.u_error = e; else ku.u_rval1 = 0;
}
void
sys_chmod_v7(void)
{
	int e;
	e = v7_chmod_call((char *)ku.u_arg[0], ku.u_arg[1]);
	if(e) ku.u_error = e; else ku.u_rval1 = 0;
}
void
sys_chown_v7(void)
{
	int e;
	e = v7_chown_call((char *)ku.u_arg[0], ku.u_arg[1], ku.u_arg[2]);
	if(e) ku.u_error = e; else ku.u_rval1 = 0;
}
void
sys_utime_v7(void)
{
	int e;
	e = v7_utime_call((char *)ku.u_arg[0], (void *)ku.u_arg[1]);
	if(e) ku.u_error = e; else ku.u_rval1 = 0;
}
void
sys_sysacct_v7(void)
{
	int e = v7_sysacct_call((char *)ku.u_arg[0]);
	if(e) ku.u_error = e; else ku.u_rval1 = 0;
}
void
sys_stat_v7(void)
{
	int e = v7_stat_call((char *)ku.u_arg[0], (void *)ku.u_arg[1]);
	if(e) ku.u_error = e; else ku.u_rval1 = 0;
}
void
sys_access_v7(void)
{
	int e;
	char *path = (char *)ku.u_arg[0];
	e = v7_access_call(path, ku.u_arg[1]);
	if(e) ku.u_error = e; else ku.u_rval1 = 0;
}
void
sys_unlink_v7(void)
{
	int e = v7_unlink_call((char *)ku.u_arg[0]);
	if(e) ku.u_error = e; else ku.u_rval1 = 0;
}
void
sys_link_v7(void)
{
	int e = v7_link_call((char *)ku.u_arg[0], (char *)ku.u_arg[1]);
	if(e) ku.u_error = e; else ku.u_rval1 = 0;
}
void
sys_exec_v7(void)
{
	int err = v7_exec_call((char *)ku.u_arg[0], (char **)ku.u_arg[1],
	    (char **)ku.u_arg[2]);
	if(err) ku.u_error = err < 0 ? -err : err; else ku.u_rval1 = 0;
}
void
sys_mknod_v7(void)
{
	int e = v7_mknod_call((char *)ku.u_arg[0], ku.u_arg[1], ku.u_arg[2]);
	if(e) ku.u_error = e; else ku.u_rval1 = 0;
}
void
sys_setuid_v7(void)
{
	int new = v7_setuid_call(kuid, ku.u_arg);
	if(!ku.u_error) { kuid = new; ku.u_rval1 = 0; }
}
void
sys_setgid_v7(void)
{
	int new = v7_setgid_call(kgid, ku.u_arg);
	if(!ku.u_error) { kgid = new; ku.u_rval1 = 0; }
}
void
sys_sync_v7(void)
{
	(void)v7_sync_call();
	ku.u_rval1 = 0;
}
void
sys_nice_v7(void)
{
	(void)v7_nice_call(ku.u_arg, curpid);
	ku.u_rval1 = 0;
}
void
sys_gtime_v7(void)
{
	long t = v7_gtime_call();
	ku.u_rval1 = (int)t;
	ku.u_rval2 = (int)(t >> 16);
}
void sys_stime_v7(void)
{ (void)v7_stime_call(ku.u_arg); ku.u_rval1 = 0; }
void
sys_alarm_v7(void)
{
	struct proc *p = proc_by_pid(curpid);
	int old = p ? p->p_clktim : 0;
	if(p) p->p_clktim = ku.u_arg[0];
	ku.u_rval1 = old;
}
void sys_ftime_v7(void)
{ int e = v7_ftime_call(ku.u_arg);  if(e) ku.u_error = e; else ku.u_rval1 = 0; }
void sys_times_v7(void)
{ int e = v7_times_call(ku.u_arg);  if(e) ku.u_error = e; else ku.u_rval1 = 0; }
void sys_lock_v7(void)
{ int e = v7_lock_call(ku.u_arg, curpid); if(e) ku.u_error = e; else ku.u_rval1 = 0; }
void sys_profil_v7(void)
{ int e = v7_profil_call(ku.u_arg); if(e) ku.u_error = e; else ku.u_rval1 = 0; }
void sys_nosys(void) { ku.u_error = 22; }
void sys_nullsys(void) { }
void sys_break_v7(void) { sbreak(); }
void sys_ptrace_v7(void) { ptrace(); }
static int
is_tty_fd(int fd)
{
	struct file *fp;
	if(fd < 0 || fd >= NOFILE)
		return(0);
	fp = u.u_ofile[fd];
	if(fp == NULL || fp->f_inode == NULL)
		return(0);
	return((fp->f_inode->i_mode & IFMT) == IFCHR);
}
void
sys_stty(void)
{
	if(!is_tty_fd(ku.u_arg[0]) || ku.u_arg[1] == 0) {
		ku.u_error = 25;
		return;
	}
	bcopy((char *)ku.u_arg[1], (char *)&console_sgtty, sizeof(console_sgtty));
	ku.u_rval1 = 0;
}
void
sys_gtty(void)
{
	if(!is_tty_fd(ku.u_arg[0]) || ku.u_arg[1] == 0) {
		ku.u_error = 25;
		return;
	}
	bcopy((char *)&console_sgtty, (char *)ku.u_arg[1], sizeof(console_sgtty));
	ku.u_rval1 = 0;
}
void
sys_ioctl_v7(void)
{
	int fd = ku.u_arg[0], cmd = ku.u_arg[1];
	char *arg = (char *)ku.u_arg[2];
	if(fd < 0 || fd >= NOFILE || u.u_ofile[fd] == NULL) {
		ku.u_error = 9;
		return;
	}
	switch(cmd) {
	case FIOCLEX:
		v7_pofile_excl_set(fd);
		ku.u_rval1 = 0;
		return;
	case FIONCLEX:
		v7_pofile_excl_clear(fd);
		ku.u_rval1 = 0;
		return;
	case TIOCGETP:
	case TIOCSETP:
		if(!is_tty_fd(fd) || arg == 0) {
			ku.u_error = 25;
			return;
		}
		if(cmd == TIOCGETP)
			bcopy((char *)&console_sgtty, arg, sizeof(console_sgtty));
		else
			bcopy(arg, (char *)&console_sgtty, sizeof(console_sgtty));
		ku.u_rval1 = 0;
		return;
	}
	ku.u_error = 25;
}
