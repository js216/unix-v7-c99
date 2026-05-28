#include "../h/param.h"
#include "../h/systm.h"
#include "../h/map.h"
#include "../h/dir.h"
#include "../h/user.h"
#include "../h/proc.h"
#include "../h/buf.h"
#include "../h/reg.h"
#include "../h/inode.h"
#include "../h/seg.h"
#include "../h/acct.h"

struct map;
struct buf;
struct inode;
void exec(void);
void exece(void);
int getxfile(struct inode *ip, int nargc);
void setregs(void);
void rexit(void);
void exit(int rv);
void wait(void);
void fork(void);
void sbreak(void);
int malloc(struct map *mp, int size);
void mfree(struct map *mp, int size, int a);
void panic(char *s);
int fuword(caddr_t addr);
int fubyte(caddr_t addr);
void bawrite(struct buf *bp);
void suword(caddr_t addr, int val);
void brelse(struct buf *bp);
struct buf *bread(dev_t dev, daddr_t blkno);
daddr_t bmap(struct inode *ip, daddr_t bn, int rwflg);
void bcopy(char *from, char *to, unsigned int n);
int schar(void);
void xfree(void);
void xalloc(struct inode *ip);
int estabur(unsigned nt, unsigned nd, unsigned ns, int sep, int xrw);
void expand(int newsize);
void clearseg(int a);
void acct(void);
void wakeup(caddr_t chan);
void swtch(void);
void closef(struct file *fp);
int v7_load_image(char *path, char **argv, char **envp);
extern int *trap_frame;
int fsig(struct proc *p);
void sleep(caddr_t chan, int pri);
int newproc(void);
void copyseg(int from, int to);
void arm_sync_icache(void);
/*
 * exec system call, with and without environments.
 */
struct execa {
	char	*fname;
	char	**argp;
	char	**envp;
};

void
exec(void)
{
	((struct execa *)u.u_ap)->envp = NULL;
	exece();
}

void
exece(void)
{
	register int nc;
	register char *cp;
	register struct buf *bp;
	register struct execa *uap;
	int na, ne, bno, ucp, ap, c;
	struct inode *ip;

	if ((ip = namei(uchar, 0)) == NULL)
		return;
	bno = 0;
	bp = 0;
	if(access(ip, IEXEC))
		goto bad;
	if((ip->i_mode & IFMT) != IFREG ||
	   (ip->i_mode & (IEXEC|(IEXEC>>3)|(IEXEC>>6))) == 0) {
		u.u_error = EACCES;
		goto bad;
	}
	/*
	 * Collect arguments on "file" in swap space.
	 */
	na = 0;
	ne = 0;
	nc = 0;
	uap = (struct execa *)u.u_ap;
	if ((bno = malloc(swapmap,(NCARGS+BSIZE-1)/BSIZE)) == 0)
		panic("Out of swap");
	if (uap->argp) for (;;) {
		ap = NULL;
		if (uap->argp) {
			ap = fuword((caddr_t)uap->argp);
			uap->argp++;
		}
		if (ap==NULL && uap->envp) {
			uap->argp = NULL;
			if ((ap = fuword((caddr_t)uap->envp)) == NULL)
				break;
			uap->envp++;
			ne++;
		}
		if (ap==NULL)
			break;
		na++;
		if(ap == -1)
			u.u_error = EFAULT;
		do {
			if (nc >= NCARGS-1)
				u.u_error = E2BIG;
			if ((c = fubyte((caddr_t)ap++)) < 0)
				u.u_error = EFAULT;
			if (u.u_error)
				goto bad;
			if ((nc&BMASK) == 0) {
				if (bp)
					bawrite(bp);
				bp = getblk(swapdev, swplo+bno+(nc>>BSHIFT));
				cp = bp->b_un.b_addr;
			}
			nc++;
			*cp++ = c;
		} while (c>0);
	}
	if (bp)
		bawrite(bp);
	bp = 0;
	nc = (nc + NBPW-1) & ~(NBPW-1);
	if (getxfile(ip, nc) || u.u_error)
		goto bad;

	/*
	 * copy back arglist
	 */

	ucp = -nc - NBPW;
	ap = ucp - na*NBPW - 3*NBPW;
	u.u_ar0[R6] = ap;
	suword((caddr_t)ap, na-ne);
	nc = 0;
	for (;;) {
		ap += NBPW;
		if (na==ne) {
			suword((caddr_t)ap, 0);
			ap += NBPW;
		}
		if (--na < 0)
			break;
		suword((caddr_t)ap, ucp);
		do {
			if ((nc&BMASK) == 0) {
				if (bp)
					brelse(bp);
				bp = bread(swapdev, swplo+bno+(nc>>BSHIFT));
				cp = bp->b_un.b_addr;
			}
			subyte((caddr_t)ucp++, (c = *cp++));
			nc++;
		} while(c&0377);
	}
	suword((caddr_t)ap, 0);
	suword((caddr_t)ucp, 0);
	setregs();
bad:
	if (bp)
		brelse(bp);
	if(bno)
		mfree(swapmap, (NCARGS+BSIZE-1)/BSIZE, bno);
	iput(ip);
}

/*
 * Read in and set up memory for executed file.
 * Zero return is normal;
 * non-zero means only the text is being replaced
 */
int
getxfile(register struct inode *ip, int nargc)
{
	register unsigned ds;
	register int sep;
	register unsigned ts, ss;
	register int i, overlay;
	long lsize;

	/*
	 * read in first few bytes
	 * of file for segment
	 * sizes:
	 * ux_mag = 407/410/411/405
	 *  407 is plain executable
	 *  410 is RO text
	 *  411 is separated ID
	 *  405 is overlaid text
	 */

	u.u_base = (caddr_t)&u.u_exdata;
	u.u_count = sizeof(u.u_exdata);
	u.u_offset = 0;
	u.u_segflg = 1;
	readi(ip);
	u.u_segflg = 0;
	if(u.u_error)
		goto bad;
	if (u.u_count!=0) {
		u.u_error = ENOEXEC;
		goto bad;
	}
	sep = 0;
	overlay = 0;
	if(u.u_exdata.ux_mag == 0407) {
		lsize = (long)u.u_exdata.ux_dsize + u.u_exdata.ux_tsize;
		u.u_exdata.ux_dsize = lsize;
		if (lsize != (long)u.u_exdata.ux_dsize) {	/* check overflow */
			u.u_error = ENOMEM;
			goto bad;
		}
		u.u_exdata.ux_tsize = 0;
	} else if (u.u_exdata.ux_mag == 0411)
		sep++;
	else if (u.u_exdata.ux_mag == 0405)
		overlay++;
	else if (u.u_exdata.ux_mag != 0410) {
		u.u_error = ENOEXEC;
		goto bad;
	}
	if(u.u_exdata.ux_tsize!=0 && (ip->i_flag&ITEXT)==0 && ip->i_count!=1) {
		u.u_error = ETXTBSY;
		goto bad;
	}

	/*
	 * find text and data sizes
	 * try them out for possible
	 * overflow of max sizes
	 */
	ts = btoc(u.u_exdata.ux_tsize);
	lsize = (long)u.u_exdata.ux_dsize + u.u_exdata.ux_bsize;
	if (lsize != (long)(unsigned)lsize) {
		u.u_error = ENOMEM;
		goto bad;
	}
	ds = btoc(lsize);
	ss = SSIZE + btoc(nargc);
	if (overlay) {
		if ((u.u_sep==0 && ctos(ts) != ctos(u.u_tsize)) || nargc) {
			u.u_error = ENOMEM;
			goto bad;
		}
		ds = u.u_dsize;
		ss = u.u_ssize;
		sep = u.u_sep;
		xfree();
		xalloc(ip);
		u.u_ar0[PC] = u.u_exdata.ux_entloc & ~01;
	} else {
		if(estabur(ts, ds, ss, sep, RO))
			goto bad;
	
		/*
		 * allocate and clear core
		 * at this point, committed
		 * to the new image
		 */
	
		u.u_prof.pr_scale = 0;
		xfree();
		i = USIZE+ds+ss;
		expand(i);
		while(--i >= USIZE)
			clearseg(u.u_procp->p_addr+i);
		xalloc(ip);
	
		/*
		 * read in data segment
		 */
	
		estabur((unsigned)0, ds, (unsigned)0, 0, RO);
		u.u_base = 0;
		u.u_offset = sizeof(u.u_exdata)+u.u_exdata.ux_tsize;
		u.u_count = u.u_exdata.ux_dsize;
		readi(ip);
		/*
		 * set SUID/SGID protections, if no tracing
		 */
		if ((u.u_procp->p_flag&STRC)==0) {
			if(ip->i_mode&ISUID)
				if(u.u_uid != 0) {
					u.u_uid = ip->i_uid;
					u.u_procp->p_uid = ip->i_uid;
				}
			if(ip->i_mode&ISGID)
				u.u_gid = ip->i_gid;
		} else
			psignal(u.u_procp, SIGTRC);
	}
	u.u_tsize = ts;
	u.u_dsize = ds;
	u.u_ssize = ss;
	u.u_sep = sep;
	estabur(ts, ds, ss, sep, RO);
bad:
	return(overlay);
}

/*
 * Clear registers on exec
 */
void
setregs(void)
{
	register int *rp;
	register char *cp;
	register int i;

	for(rp = &u.u_signal[0]; rp < &u.u_signal[NSIG]; rp++)
		if((*rp & 1) == 0)
			*rp = 0;
	for(cp = &regloc[0]; cp < &regloc[6];)
		u.u_ar0[(int)*cp++] = 0;
	u.u_ar0[PC] = u.u_exdata.ux_entloc & ~01;
	for(rp = (int *)&u.u_fps; rp < (int *)&u.u_fps.u_fpregs[6];)
		*rp++ = 0;
	for(i=0; i<NOFILE; i++) {
		if (u.u_pofile[i]&EXCLOSE) {
			closef(u.u_ofile[i]);
			u.u_ofile[i] = NULL;
			u.u_pofile[i] &= ~EXCLOSE;
		}
	}
	/*
	 * Remember file name for accounting.
	 */
	u.u_acflag &= ~AFORK;
	bcopy((caddr_t)u.u_dbuf, (caddr_t)u.u_comm, DIRSIZ);
}

/*
 * exit system call:
 * pass back caller's arg
 */
void
rexit(void)
{
	register struct a {
		int	rval;
	} *uap;

	uap = (struct a *)u.u_ap;
	exit((uap->rval & 0377) << 8);
}

/*
 * Release resources.
 * Save u. area for parent to look at.
 * Enter zombie state.
 * Wake up parent and init processes,
 * and dispose of children.
 */
void
exit(int rv)
{
	register int i;
	register struct proc *p, *q;
	register struct file *f;

	p = u.u_procp;
	p->p_flag &= ~(STRC|SULOCK);
	p->p_clktim = 0;
	for(i=0; i<NSIG; i++)
		u.u_signal[i] = 1;
	for(i=0; i<NOFILE; i++) {
		f = u.u_ofile[i];
		u.u_ofile[i] = NULL;
		closef(f);
	}
	plock(u.u_cdir);
	iput(u.u_cdir);
	if (u.u_rdir) {
		plock(u.u_rdir);
		iput(u.u_rdir);
	}
	xfree();
	acct();
	mfree(coremap, p->p_size, p->p_addr);
	p->p_stat = SZOMB;
	((struct xproc *)p)->xp_xstat = rv;
	((struct xproc *)p)->xp_utime = u.u_cutime + u.u_utime;
	((struct xproc *)p)->xp_stime = u.u_cstime + u.u_stime;
	for(q = &proc[0]; q < &proc[NPROC]; q++)
		if(q->p_ppid == p->p_pid) {
			wakeup((caddr_t)&proc[1]);
			q->p_ppid = 1;
			if (q->p_stat==SSTOP)
				setrun(q);
		}
	for(q = &proc[0]; q < &proc[NPROC]; q++)
		if(p->p_ppid == q->p_pid) {
			wakeup((caddr_t)q);
			swtch();
			/* no return */
		}
	swtch();
}

/*
 * Wait system call.
 * Search for a terminated (zombie) child,
 * finally lay it to rest, and collect its status.
 * Look also for stopped (traced) children,
 * and pass back status from them.
 */
void
wait(void)
{
	register int f;
	register struct proc *p;

	f = 0;

loop:
	for(p = &proc[0]; p < &proc[NPROC]; p++)
	if(p->p_ppid == u.u_procp->p_pid) {
		f++;
		if(p->p_stat == SZOMB) {
			u.u_r.r_val1 = p->p_pid;
			u.u_r.r_val2 = ((struct xproc *)p)->xp_xstat;
			u.u_cutime += ((struct xproc *)p)->xp_utime;
			u.u_cstime += ((struct xproc *)p)->xp_stime;
			p->p_pid = 0;
			p->p_ppid = 0;
			p->p_pgrp = 0;
			p->p_sig = 0;
			p->p_flag = 0;
			p->p_wchan = 0;
			p->p_stat = NULL;
			return;
		}
		if(p->p_stat == SSTOP) {
			if((p->p_flag&SWTED) == 0) {
				p->p_flag |= SWTED;
				u.u_r.r_val1 = p->p_pid;
				u.u_r.r_val2 = (fsig(p)<<8) | 0177;
				return;
			}
			continue;
		}
	}
	if(f) {
		sleep((caddr_t)u.u_procp, PWAIT);
		goto loop;
	}
	u.u_error = ECHILD;
}

/*
 * fork system call.
 */
void
fork(void)
{
	register struct proc *p1, *p2;
	register int a;

	/*
	 * Make sure there's enough swap space for max
	 * core image, thus reducing chances of running out
	 */
	if ((a = malloc(swapmap, ctod(MAXMEM))) == 0) {
		u.u_error = ENOMEM;
		goto out;
	}
	mfree(swapmap, ctod(MAXMEM), a);
	a = 0;
	p2 = NULL;
	for(p1 = &proc[0]; p1 < &proc[NPROC]; p1++) {
		if (p1->p_stat==NULL && p2==NULL)
			p2 = p1;
		else {
			if (p1->p_uid==u.u_uid && p1->p_stat!=NULL)
				a++;
		}
	}
	/*
	 * Disallow if
	 *  No processes at all;
	 *  not su and too many procs owned; or
	 *  not su and would take last slot.
	 */
	if (p2==NULL || (u.u_uid!=0 && (p2==&proc[NPROC-1] || a>MAXUPRC))) {
		u.u_error = EAGAIN;
		goto out;
	}
	p1 = u.u_procp;
	if(newproc()) {
		u.u_r.r_val1 = p1->p_pid;
		u.u_start = time;
		u.u_cstime = 0;
		u.u_stime = 0;
		u.u_cutime = 0;
		u.u_utime = 0;
		u.u_acflag = AFORK;
		return;
	}
	u.u_r.r_val1 = p2->p_pid;

out:
	u.u_ar0[R7] += NBPW;
}

/*
 * break system call.
 *  -- bad planning: "break" is a dirty word in C.
 */
void
sbreak(void)
{
	struct a {
		char	*nsiz;
	};
	register int a, n, d;
	int i;

	/*
	 * set n to new data size
	 * set d to new-old
	 * set n to new total size
	 */

	n = btoc((int)((struct a *)u.u_ap)->nsiz);
	if(!u.u_sep)
		n -= ctos(u.u_tsize) * stoc(1);
	if(n < 0)
		n = 0;
	d = n - u.u_dsize;
	n += USIZE+u.u_ssize;
	if(estabur(u.u_tsize, u.u_dsize+d, u.u_ssize, u.u_sep, RO))
		return;
	u.u_dsize += d;
	if(d > 0)
		goto bigger;
	a = u.u_procp->p_addr + n - u.u_ssize;
	i = n;
	n = u.u_ssize;
	while(n--) {
		copyseg(a-d, a);
		a++;
	}
	expand(i);
	return;

bigger:
	expand(n);
	a = u.u_procp->p_addr + n;
	n = u.u_ssize;
	while(n--) {
		a--;
		copyseg(a-d, a);
	}
	while(d--)
		clearseg(--a);
}
static char argbuf[UARGLEN];
#define	KENOEXEC		8
char *slot_user_base(int slot);
void install_sigtramp(char *base);
void usermap(int slot);
int slot_by_pid(int pid);
extern int curpid, live_slot;
#define	NPROCSAVE	32
#define	V7_STACK_TOP	0x10000U
#define	PROC_SLOT_BYTES	0x100000
#define	SIG_DFL		0L
#define	SIG_IGN		1L
extern unsigned char usermem[NPROCSAVE][PROC_SLOT_BYTES];
extern unsigned int pending;
void arm_exec_reset_signals(void);
static void bzero(char *p, unsigned int n) { while(n--) *p++ = 0; }
static int kexec(char *path)
{
	struct inode *ip;
	struct buf *bp;
	unsigned int insn;
	unsigned int size, off, n, on;
	daddr_t bn;
	int slot;
	char *base;
	u.u_dirp = path;
	u.u_error = 0;
	u.u_segflg = 1;
	ip = namei(schar, 0);
	if(ip == NULL) return -2;
	if((ip->i_mode & IFMT) != IFREG) { iput(ip); return -13; }
	if((ip->i_mode & 0111) == 0) { iput(ip); return -13; }
	size = (unsigned int)ip->i_size;
	if(size >= USERSIZE - UENTRY) { iput(ip); return -2; }
	if(size < sizeof(insn)) { iput(ip); return -KENOEXEC; }
	ip->i_count++;
	slot = slot_by_pid(curpid);
	base = slot >= 0 ? slot_user_base(slot) : (char *)USERBASE;
	__asm__ volatile("cpsid i" ::: "memory");
	bzero(base, USERSIZE);
	__asm__ volatile("cpsie i\n\tisb" ::: "memory");
	for(off = 0; off < size; off += n) {
		on = off & BMASK;
		n = BSIZE - on;
		if(n > size - off)
			n = size - off;
		bn = bmap(ip, off >> BSHIFT, B_READ);
		if(u.u_error || (long)bn < 0) {
			iput(ip);
			iput(ip);
			return -5;
		}
		bp = bread(ip->i_dev, bn);
		if(bp->b_flags & B_ERROR) {
			brelse(bp);
			iput(ip);
			iput(ip);
			return -5;
		}
		bcopy(bp->b_un.b_addr + on, base + UENTRY + off, n);
		brelse(bp);
	}
	__asm__ volatile("cpsid i" ::: "memory");
	if(slot >= 0 && base != (char *)usermem[slot])
		bcopy(base, (char *)usermem[slot], USERSIZE);
	insn = *(volatile unsigned int *)(base + UENTRY);
	if((insn & 0xff000000U) != 0xeb000000U) {
		iput(ip);
		iput(ip);
		return -KENOEXEC;
	}
	iput(ip);
	iput(ip);
	u.u_tsize = 0;
	u.u_dsize = 0;
	u.u_ssize = SSIZE;
	u.u_sep = 0;
	if(u.u_procp)
		u.u_procp->p_size = USIZE + SSIZE;
	install_sigtramp(base);
	arm_exec_reset_signals();
	pending = 0;
	if(slot >= 0) {
		usermap(slot);
		live_slot = slot;
	}
	arm_sync_icache();
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
int
v7_exec_call(char *path, char **argv, char **envp)
{
	int rc;
	rc = v7_load_image(path, argv, envp);
	if(rc != 0)
		return(rc < 0 ? -rc : 1);
	for(int i = 0; i < NOFILE; i++)
		if(u.u_pofile[i] & EXCLOSE) {
			if(u.u_ofile[i])
				closef(u.u_ofile[i]);
			u.u_ofile[i] = NULL;
			u.u_pofile[i] &= ~EXCLOSE;
		}
	for(int i = 1; i < NSIG; i++)
		if(u.u_signal[i] != 1)
			u.u_signal[i] = 0;
	if(trap_frame) {
		trap_frame[13] = (int)USTACK;
		trap_frame[14] = 0;
		trap_frame[15] = (int)UENTRY;
	}
	u.u_ap = NULL;
	return(0);
}
