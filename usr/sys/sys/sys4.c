#include "../h/param.h"
#include "../h/systm.h"
#include "../h/dir.h"
#include "../h/user.h"
#include "../h/inode.h"
#include "../h/proc.h"
#include "../h/timeb.h"
int spl0(void);
int spl7(void);
void chdirec(struct inode **ipp);
void sleep(caddr_t chan, int pri);
void sysacct(void);
void stat(void);
void saccess(void);
void link(void);
void mknod(void);
void smount(void);
void sumount(void);
struct inode *iget(dev_t dev, ino_t ino);
void iput(struct inode *ip);
void umask(void);
void getuid(void);
void getgid(void);
void getpid(void);
void setuid(void);
void setgid(void);
void sync(void);
void nice(void);
void gtime(void);
void stime(void);
void alarm(void);
void ftime(void);
void times(void);
void profil(void);
void syslock(void);
void v7_proc_set_current(int pid);
struct proc *proc_by_pid(int pid);
extern struct inode *rootdir;

/*
 * Everything in this file is a routine implementing a system call.
 */

/*
 * return the current time (old-style entry)
 */
void
gtime(void)
{
	u.u_r.r_time = time;
}

/*
 * New time entry-- return TOD with milliseconds, timezone,
 * DST flag
 */
void
ftime(void)
{
	register struct a {
		struct	timeb	*tp;
	} *uap;
	struct timeb t;
	register unsigned ms;

	uap = (struct a *)u.u_ap;
	spl7();
	t.time = time;
	ms = lbolt;
	spl0();
	if (ms > HZ) {
		ms -= HZ;
		t.time++;
	}
	t.millitm = (1000*ms)/HZ;
	t.timezone = TIMEZONE;
	t.dstflag = DSTFLAG;
	if (copyout((caddr_t)&t, (caddr_t)uap->tp, sizeof(t)) < 0)
		u.u_error = EFAULT;
}

/*
 * Set the time
 */
void
stime(void)
{
	register struct a {
		time_t	time;
	} *uap;

	uap = (struct a *)u.u_ap;
	if(suser())
		time = uap->time;
}

void
setuid(void)
{
	register int uid;
	register struct a {
		int	uid;
	} *uap;

	uap = (struct a *)u.u_ap;
	uid = uap->uid;
	if(u.u_ruid == uid || suser()) {
		u.u_uid = uid;
		u.u_procp->p_uid = uid;
		u.u_ruid = uid;
	}
}

void
getuid(void)
{

	u.u_r.r_val1 = u.u_ruid;
	u.u_r.r_val2 = u.u_uid;
}

void
setgid(void)
{
	register int gid;
	register struct a {
		int	gid;
	} *uap;

	uap = (struct a *)u.u_ap;
	gid = uap->gid;
	if(u.u_rgid == gid || suser()) {
		u.u_gid = gid;
		u.u_rgid = gid;
	}
}

void
getgid(void)
{

	u.u_r.r_val1 = u.u_rgid;
	u.u_r.r_val2 = u.u_gid;
}

void
getpid(void)
{
	u.u_r.r_val1 = u.u_procp->p_pid;
	u.u_r.r_val2 = u.u_procp->p_ppid;
}

void
sync(void)
{

	update();
}

void
nice(void)
{
	register int n;
	register struct a {
		int	niceness;
	} *uap;

	uap = (struct a *)u.u_ap;
	n = uap->niceness;
	if(n < 0 && !suser())
		n = 0;
	n += u.u_procp->p_nice;
	if(n >= 2*NZERO)
		n = 2*NZERO -1;
	if(n < 0)
		n = 0;
	u.u_procp->p_nice = n;
}

/*
 * Unlink system call.
 * Hard to avoid races here, especially
 * in unlinking directories.
 */
void
unlink(void)
{
	register struct inode *ip, *pp;
	struct a {
		char	*fname;
	};

	pp = namei(uchar, 2);
	if(pp == NULL)
		return;
	/*
	 * Check for unlink(".")
	 * to avoid hanging on the iget
	 */
	if (pp->i_number == u.u_dent.d_ino) {
		ip = pp;
		ip->i_count++;
	} else
		ip = iget(pp->i_dev, u.u_dent.d_ino);
	if(ip == NULL)
		goto out1;
	if((ip->i_mode&IFMT)==IFDIR && !suser())
		goto out;
	/*
	 * Don't unlink a mounted file.
	 */
	if (ip->i_dev != pp->i_dev) {
		u.u_error = EBUSY;
		goto out;
	}
	if (ip->i_flag&ITEXT)
		xrele(ip);	/* try once to free text */
	if (ip->i_flag&ITEXT && ip->i_nlink==1) {
		u.u_error = ETXTBSY;
		goto out;
	}
	u.u_offset -= sizeof(struct direct);
	u.u_base = (caddr_t)&u.u_dent;
	u.u_count = sizeof(struct direct);
	u.u_dent.d_ino = 0;
	writei(pp);
	ip->i_nlink--;
	ip->i_flag |= ICHG;

out:
	iput(ip);
out1:
	iput(pp);
}
void
chdir(void)
{
	chdirec(&u.u_cdir);
}

void
chroot(void)
{
	if (suser())
		chdirec(&u.u_rdir);
}

void
chdirec(register struct inode **ipp)
{
	register struct inode *ip;
	struct a {
		char	*fname;
	};

	ip = namei(uchar, 0);
	if(ip == NULL)
		return;
	if((ip->i_mode&IFMT) != IFDIR) {
		u.u_error = ENOTDIR;
		goto bad;
	}
	if(access(ip, IEXEC))
		goto bad;
	prele(ip);
	if (*ipp) {
		plock(*ipp);
		iput(*ipp);
	}
	*ipp = ip;
	return;

bad:
	iput(ip);
}

void
chmod(void)
{
	register struct inode *ip;
	register struct a {
		char	*fname;
		int	fmode;
	} *uap;

	uap = (struct a *)u.u_ap;
	if ((ip = owner()) == NULL)
		return;
	ip->i_mode &= ~07777;
	if (u.u_uid)
		uap->fmode &= ~ISVTX;
	ip->i_mode |= uap->fmode&07777;
	ip->i_flag |= ICHG;
	if (ip->i_flag&ITEXT && (ip->i_mode&ISVTX)==0)
		xrele(ip);
	iput(ip);
}

void
chown(void)
{
	register struct inode *ip;
	register struct a {
		char	*fname;
		int	uid;
		int	gid;
	} *uap;

	uap = (struct a *)u.u_ap;
	if (!suser() || (ip = owner()) == NULL)
		return;
	ip->i_uid = uap->uid;
	ip->i_gid = uap->gid;
	ip->i_flag |= ICHG;
	iput(ip);
}

void
ssig(void)
{
	register int a;
	struct a {
		int	signo;
		int	fun;
	} *uap;

	uap = (struct a *)u.u_ap;
	a = uap->signo;
	if(a<=0 || a>=NSIG || a==SIGKIL) {
		u.u_error = EINVAL;
		return;
	}
	u.u_r.r_val1 = u.u_signal[a];
	u.u_signal[a] = uap->fun;
	u.u_procp->p_sig &= ~(1<<(a-1));
}

void
kill(void)
{
	register struct proc *p, *q;
	register int a;
	register struct a {
		int	pid;
		int	signo;
	} *uap;
	int f, priv;

	uap = (struct a *)u.u_ap;
	f = 0;
	a = uap->pid;
	priv = 0;
	if (a==-1 && u.u_uid==0) {
		priv++;
		a = 0;
	}
	q = u.u_procp;
	for(p = &proc[0]; p < &proc[NPROC]; p++) {
		if(p->p_stat == NULL)
			continue;
		if(a != 0 && p->p_pid != a)
			continue;
		if(a==0 && ((p->p_pgrp!=q->p_pgrp&&priv==0) || p<=&proc[1]))
			continue;
		if(u.u_uid != 0 && u.u_uid != p->p_uid)
			continue;
		f++;
		psignal(p, uap->signo);
	}
	if(f == 0)
		u.u_error = ESRCH;
}

void
times(void)
{
	register struct a {
		time_t	(*times)[4];
	} *uap;

	uap = (struct a *)u.u_ap;
	if (copyout((caddr_t)&u.u_utime, (caddr_t)uap->times, sizeof(*uap->times)) < 0)
		u.u_error = EFAULT;
}

void
profil(void)
{
	register struct a {
		short	*bufbase;
		unsigned bufsize;
		unsigned pcoffset;
		unsigned pcscale;
	} *uap;

	uap = (struct a *)u.u_ap;
	u.u_prof.pr_base = uap->bufbase;
	u.u_prof.pr_size = uap->bufsize;
	u.u_prof.pr_off = uap->pcoffset;
	u.u_prof.pr_scale = uap->pcscale;
}

/*
 * alarm clock signal
 */
void
alarm(void)
{
	register struct proc *p;
	register int c;
	register struct a {
		int	deltat;
	} *uap;

	uap = (struct a *)u.u_ap;
	p = u.u_procp;
	c = p->p_clktim;
	p->p_clktim = uap->deltat;
	u.u_r.r_val1 = c;
}

/*
 * indefinite wait.
 * no one should wakeup(&u)
 */
void
pause(void)
{

	for(;;)
		sleep((caddr_t)&u, PSLEP);
}

/*
 * mode mask for creation of files
 */
void
umask(void)
{
	register struct a {
		int	mask;
	} *uap;
	register int t;

	uap = (struct a *)u.u_ap;
	t = u.u_cmask;
	u.u_cmask = uap->mask & 0777;
	u.u_r.r_val1 = t;
}

/*
 * Set IUPD and IACC times on file.
 * Can't set ICHG.
 */
void
utime(void)
{
	register struct a {
		char	*fname;
		time_t	*tptr;
	} *uap;
	register struct inode *ip;
	time_t tv[2];

	uap = (struct a *)u.u_ap;
	if ((ip = owner()) == NULL)
		return;
	if (copyin((caddr_t)uap->tptr, (caddr_t)tv, sizeof(tv))) {
		u.u_error = EFAULT;
		return;
	}
	ip->i_flag |= IACC|IUPD|ICHG;
	iupdat(ip, &tv[0], &tv[1]);
	iput(ip);
}
static void
v7_path_prep(char *path, int *args)
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
int
v7_chroot_call(char *path)
{
	v7_path_prep(path, NULL);
	chroot();
	return(u.u_error);
}
int
v7_chmod_call(char *path, int mode)
{
	int args[2] = { (int)(long)path, mode };
	v7_path_prep(path, args);
	chmod();
	return(u.u_error);
}
int
v7_sysacct_call(char *path)
{
	int args[1] = { (int)(long)path };
	v7_path_prep(path, args);
	sysacct();
	return(u.u_error);
}
int
v7_chown_call(char *path, int uid, int gid)
{
	int args[3] = { (int)(long)path, uid, gid };
	v7_path_prep(path, args);
	chown();
	return(u.u_error);
}
int
v7_utime_call(char *path, void *tptr)
{
	int args[2] = { (int)(long)path, (int)(long)tptr };
	v7_path_prep(path, args);
	utime();
	return(u.u_error);
}
int
v7_stat_call(char *path, void *ubuf)
{
	int args[2] = { (int)(long)path, (int)(long)ubuf };
	v7_path_prep(path, args);
	stat();
	return(u.u_error);
}
int
v7_access_call(char *path, int mode)
{
	int args[2] = { (int)(long)path, mode };
	v7_path_prep(path, args);
	u.u_gid = u.u_rgid = 0;
	saccess();
	return(u.u_error);
}
int
v7_unlink_call(char *path)
{
	int args[1] = { (int)(long)path };
	v7_path_prep(path, args);
	unlink();
	return(u.u_error);
}
int
v7_link_call(char *from, char *to)
{
	int args[2] = { (int)(long)from, (int)(long)to };
	v7_path_prep(from, args);
	link();
	return(u.u_error);
}
int
v7_mknod_call(char *path, int mode, int dev)
{
	int args[3] = { (int)(long)path, mode, dev };
	v7_path_prep(path, args);
	u.u_gid = u.u_rgid = 0;
	mknod();
	return(u.u_error);
}
int
v7_mount_call(char *special, char *dir, int ro)
{
	int args[3] = { (int)(long)special, (int)(long)dir, ro };
	(void)dir;
	v7_path_prep(special, args);
	smount();
	return(u.u_error);
}
int
v7_umount_call(char *special)
{
	int args[1] = { (int)(long)special };
	v7_path_prep(special, args);
	sumount();
	return(u.u_error);
}
void *
v7_cdir_save(void)
{
	struct inode *ip = u.u_cdir, *held;
	if(ip == NULL) return(NULL);
	held = iget(ip->i_dev, ip->i_number);
	if(held) held->i_flag &= ~ILOCK;
	return((void *)held);
}
void
v7_cdir_restore(void *p)
{
	struct inode *old = u.u_cdir;
	u.u_cdir = (struct inode *)p;
	if(old) iput(old);
}
void *
v7_rdir_save(void)
{
	struct inode *ip = u.u_rdir, *held;
	if(ip == NULL) return(NULL);
	held = iget(ip->i_dev, ip->i_number);
	if(held) held->i_flag &= ~ILOCK;
	return((void *)held);
}
void
v7_rdir_restore(void *p)
{
	struct inode *old = u.u_rdir;
	u.u_rdir = (struct inode *)p;
	if(old) iput(old);
}
void
v7_call_prep(int *args)
{
	u.u_ap = args;
	if(args != NULL)
		u.u_dirp = (caddr_t)args[0];
	u.u_error = 0;
	u.u_r.r_val1 = u.u_r.r_val2 = 0;
}
int
v7_umask_call(int *args, int kumask)
{
	u.u_cmask = (short)kumask;
	v7_call_prep(args);
	umask();
	return(u.u_r.r_val1);
}
int
v7_getuid_call(int kuid)
{
	u.u_uid = u.u_ruid = (short)kuid;
	v7_call_prep(NULL);
	getuid();
	return(u.u_r.r_val1);
}
int
v7_getgid_call(int kgid)
{
	u.u_gid = u.u_rgid = (short)kgid;
	v7_call_prep(NULL);
	getgid();
	return(u.u_r.r_val1);
}
int
v7_getpid_call(int curpid, int ppid)
{
	(void)ppid;
	v7_proc_set_current(curpid);
	if(u.u_procp == NULL || u.u_procp == &proc[0]) u.u_procp = &proc[1];
	v7_call_prep(NULL);
	getpid();
	return(u.u_r.r_val1);
}
int
v7_getppid_call(int curpid)
{
	v7_proc_set_current(curpid);
	if(u.u_procp == NULL || u.u_procp == &proc[0]) u.u_procp = &proc[1];
	return((int)u.u_procp->p_ppid);
}
int
v7_setuid_call(int kuid, int *args)
{
	u.u_uid = u.u_ruid = proc[0].p_uid = (short)kuid;
	u.u_procp = &proc[0];
	v7_call_prep(args);
	setuid();
	return(u.u_uid);
}
int
v7_setgid_call(int kgid, int *args)
{
	u.u_gid = u.u_rgid = (short)kgid;
	u.u_uid = u.u_ruid = 0;
	v7_call_prep(args);
	setgid();
	return(u.u_gid);
}
int
v7_sync_call(void)
{
	v7_call_prep(NULL);
	sync();
	return(0);
}
int
v7_nice_call(int *args, int curpid)
{
	struct proc *me = proc_by_pid(curpid);
	if(me == NULL) me = &proc[0];
	u.u_procp = me;
	u.u_uid = u.u_ruid = me->p_uid;
	v7_call_prep(args);
	nice();
	return(me->p_nice);
}
long
v7_gtime_call(void)
{
	u.u_error = 0;
	u.u_r.r_time = 0;
	gtime();
	return(u.u_r.r_time);
}
long
v7_stime_call(int *args)
{
	u.u_uid = u.u_ruid = 0;
	v7_call_prep(args);
	stime();
	return(time);
}
int
v7_ftime_call(int *args)
{
	v7_call_prep(args);
	ftime();
	return(u.u_error);
}
int
v7_times_call(int *args)
{
	v7_call_prep(args);
	times();
	return(u.u_error);
}
void
v7_u_times_snapshot(long *utp, long *stp)
{
	*utp = (long)u.u_utime + (long)u.u_cutime;
	*stp = (long)u.u_stime + (long)u.u_cstime;
}
void
v7_u_times_add_child(long ut, long st)
{
	u.u_cutime += ut;
	u.u_cstime += st;
}
int
v7_profil_call(int *args)
{
	v7_call_prep(args);
	profil();
	return(u.u_error);
}
int
v7_lock_call(int *args, int curpid)
{
	v7_proc_set_current(curpid);
	u.u_uid = u.u_procp->p_uid;
	v7_call_prep(args);
	syslock();
	return(u.u_error);
}
void
v7_u_times_save(long *out_utime, long *out_stime,
    long *out_cutime, long *out_cstime)
{
	*out_utime  = (long)u.u_utime;
	*out_stime  = (long)u.u_stime;
	*out_cutime = (long)u.u_cutime;
	*out_cstime = (long)u.u_cstime;
	u.u_utime = u.u_stime = u.u_cutime = u.u_cstime = 0;
}
void
v7_u_times_restore(long in_utime, long in_stime,
    long in_cutime, long in_cstime)
{
	u.u_utime  = (time_t)in_utime;
	u.u_stime  = (time_t)in_stime;
	u.u_cutime = (time_t)in_cutime;
	u.u_cstime = (time_t)in_cstime;
}
