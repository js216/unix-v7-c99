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
void	getxfile(struct inode *ip, int nargc);
void	setregs(void);

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

#define	NARGPG	((NCARGS+PGSIZE-1)/PGSIZE)
#define	ARGC(n)	(PGADDR(pg[(n)>>PGSHIFT])[(n)&(PGSIZE-1)])

void
exece(void)
{
	register int nc, i;
	register struct execa *uap;
	int na, ne, ucp, ap, c, pg[(NCARGS+PGSIZE-1)/PGSIZE];
	struct inode *ip;

	if ((ip = namei(uchar, 0)) == NULL)
		return;
	for (i = 0; i < NARGPG; i++)
		pg[i] = 0;
	if(access(ip, IEXEC))
		goto bad;
	if((ip->i_mode & IFMT) != IFREG ||
	   (ip->i_mode & (IEXEC|(IEXEC>>3)|(IEXEC>>6))) == 0) {
		u.u_error = EACCES;
		goto bad;
	}
	/*
	 * Collect arguments in pages of core.
	 */
	na = 0;
	ne = 0;
	nc = 0;
	uap = (struct execa *)u.u_ap;
	if (npgfree < NARGPG) {
		u.u_error = ENOMEM;
		goto bad;
	}
	for (i = 0; i < NARGPG; i++)
		pg[i] = pgalloc();
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
			ARGC(nc) = c;
			nc++;
		} while (c>0);
	}
	nc = (nc + NBPW-1) & ~(NBPW-1);
	getxfile(ip, nc+(na+3)*NBPW);
	if (u.u_error)
		goto bad;

	/*
	 * copy back arglist
	 */

	ucp = USRSIZE - nc - NBPW;
	ap = (ucp - na*NBPW - 3*NBPW) & ~7;
	u.u_ar0[SP] = ap;
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
			subyte((caddr_t)ucp++, (c = ARGC(nc)));
			nc++;
		} while(c&0377);
	}
	suword((caddr_t)ap, 0);
	suword((caddr_t)ucp, 0);
	setregs();
bad:
	for (i = 0; i < NARGPG; i++)
		if (pg[i])
			pgfree(pg[i]);
	iput(ip);
}

/*
 * Read count bytes at offset off of the file ip into the kernel;
 * nonzero if they could not all be read
 */
static int
exread(struct inode *ip, caddr_t base, unsigned count, unsigned off)
{
	u.u_base = base;
	u.u_count = count;
	u.u_offset = off;
	u.u_segflg = 1;
	readi(ip);
	u.u_segflg = 0;
	return(u.u_error || u.u_count);
}

/*
 * Read in and set up memory for executed file.
 */
void
getxfile(register struct inode *ip, int nargc)
{
	register unsigned ds;
	register unsigned ts, ss;
	register int i, n;
	unsigned off, type, t0, d0, end;

	/*
	 * read in the ELF header;
	 * the program headers follow,
	 * and the two loadable
	 * segments are the text
	 * and the data
	 */

	if(exread(ip, (caddr_t)&u.u_exdata, sizeof(u.u_exdata), 0)) {
		if(u.u_error == 0)
			u.u_error = ENOEXEC;
		return;
	}
	n = 0;
	if(u.u_exdata.e_ident[0] == 0177 && u.u_exdata.e_ident[1] == 'E' &&
	    u.u_exdata.e_ident[2] == 'L' && u.u_exdata.e_ident[3] == 'F' &&
	    u.u_exdata.e_phentsize >= sizeof(u.u_exdata.ph[0]))
	for(i = 0; i < u.u_exdata.e_phnum; i++) {
		off = u.u_exdata.e_phoff + u.u_exdata.e_phentsize*i;
		if(exread(ip, (caddr_t)&type, sizeof(type), off)) {
			n = 0;
			break;
		}
		if(type != PT_LOAD)
			continue;
		if(n == 2 || exread(ip, (caddr_t)&u.u_exdata.ph[n],
		    sizeof(u.u_exdata.ph[0]), off)) {
			n = 0;
			break;
		}
		n++;
	}
	if(n != 2 ||
	    u.u_exdata.ph[0].p_filesz == 0 ||
	    u.u_exdata.ph[1].p_filesz > u.u_exdata.ph[1].p_memsz) {
		u.u_error = ENOEXEC;
		return;
	}
	if(u.u_exdata.ph[0].p_filesz!=0 && (ip->i_flag&ITEXT)==0 &&
	    ip->i_count!=1) {
		u.u_error = ETXTBSY;
		return;
	}

	/*
	 * find the pages of the text
	 * and data, each at its own
	 * address, and try them out
	 */
	t0 = u.u_exdata.ph[0].p_vaddr >> PGSHIFT;
	end = u.u_exdata.ph[0].p_vaddr + u.u_exdata.ph[0].p_filesz;
	if(end < u.u_exdata.ph[0].p_filesz || end > USRSIZE)
		goto nomem;
	ts = btop(end) - t0;
	d0 = u.u_exdata.ph[1].p_vaddr >> PGSHIFT;
	end = u.u_exdata.ph[1].p_vaddr + u.u_exdata.ph[1].p_memsz;
	if(end < u.u_exdata.ph[1].p_memsz || end > USRSIZE)
		goto nomem;
	ds = btop(end) - d0;
	ss = SSIZE + btop(nargc);
	if(estabur(t0, ts, d0, ds, ss, RO))
		return;

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
		clearseg(imgpage(u.u_procp, i));
	xalloc(ip);

	/*
	 * read in data segment
	 */

	estabur(t0, ts, d0, ds, (unsigned)0, RO);
	u.u_base = (caddr_t)u.u_exdata.ph[1].p_vaddr;
	u.u_offset = u.u_exdata.ph[1].p_offset;
	u.u_count = u.u_exdata.ph[1].p_filesz;
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
	u.u_tsize = ts;
	u.u_dsize = ds;
	u.u_ssize = ss;
	estabur(t0, ts, d0, ds, ss, RO);
	return;

nomem:
	u.u_error = ENOMEM;
}

/*
 * Clear registers on exec
 */
void
setregs(void)
{
	register int *rp;
	register int i;

	for(rp = &u.u_signal[0]; rp < &u.u_signal[NSIG]; rp++)
		if((*rp & 1) == 0)
			*rp = 0;
	for(i = 0; i < PC; i++)
		if(i != SP)
			u.u_ar0[i] = 0;
	u.u_r.r_val2 = 0;
	u.u_ar0[PC] = u.u_exdata.e_entry & ~01;
	for(rp = (int *)&u.u_fps; rp < (int *)&u.u_fps.u_fpregs[32];)
		*rp++ = 0;
	u.u_fpsaved = 1;
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
	ptfree(p);
	mapfree(&p->p_map, 0, p->p_size-USIZE);
	pgfree(p->p_addr);
	p->p_stat = SZOMB;
	p->p_xstat = rv;
	p->p_utime = u.u_cutime + u.u_utime;
	p->p_stime = u.u_cstime + u.u_stime;
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
			u.u_r.r_val2 = p->p_xstat;
			u.u_cutime += p->p_utime;
			u.u_cstime += p->p_stime;
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
	 * Make sure there's enough swap space for the
	 * core image, thus reducing chances of running out
	 */
	if ((a = malloc(swapmap, ptod(u.u_procp->p_size))) == 0) {
		u.u_error = ENOMEM;
		goto out;
	}
	mfree(swapmap, ptod(u.u_procp->p_size), a);
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
	/*
	 * The child is made in core, or not at all.
	 */
	a = u.u_procp->p_size;
	if (USIZE + mapneed(0, a-USIZE) > npgfree) {
		u.u_error = ENOMEM;
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
	u.u_ar0[PC] += NBPW;
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
	register struct proc *p;

	/*
	 * set n to new data size
	 * set d to new-old
	 * set n to new total size
	 */

	n = (int)btop((unsigned)((struct a *)u.u_ap)->nsiz) -
	    (int)u.u_pdstart;
	if(n < 0)
		n = 0;
	d = n - u.u_dsize;
	n += USIZE+u.u_ssize;
	if(estabur(u.u_ptstart, u.u_tsize, u.u_pdstart, u.u_dsize+d,
	    u.u_ssize, RO))
		return;
	u.u_dsize += d;
	p = u.u_procp;
	a = n - u.u_ssize - USIZE;
	if(d > 0)
		goto bigger;
	maprot(p->p_map, a, a-d, n-d-USIZE);
	expand(n);
	goto out;

bigger:
	expand(n);
	maprot(p->p_map, a-d, n-d-USIZE, n-USIZE);
	while(d--)
		clearseg(*mapent(p->p_map, --a));
out:
	ptfree(p);
	sureg();
}
