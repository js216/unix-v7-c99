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

/*
 * exec system call, with and without environments.
 */
struct execa {
	char	*fname;
	char	**argp;
	char	**envp;
};

void
exec()
{
	((struct execa *)u.u_ap)->envp = NULL;
	exece();
}

void
exece()
{
	register struct execa *uap;
	register int nc, c, ap;
	struct inode *ip;
	int i;
	char e_argbuf[UARGLEN];

	if ((ip = namei(uchar, 0)) == NULL)
		return;
	if(access(ip, IEXEC))
		goto bad;
	if((ip->i_mode & IFMT) != IFREG ||
	   (ip->i_mode & (IEXEC|(IEXEC>>3)|(IEXEC>>6))) == 0) {
		u.u_error = EACCES;
		goto bad;
	}
	uap = (struct execa *)u.u_ap;
	nc = 0;
	if (uap->argp) for (;;) {
		ap = fuword((caddr_t)uap->argp);
		uap->argp++;
		if (ap == 0)
			break;
		if (ap == -1) {
			u.u_error = EFAULT;
			goto bad;
		}
		do {
			if ((c = fubyte((caddr_t)ap++)) < 0) {
				u.u_error = EFAULT;
				goto bad;
			}
			if (nc >= UARGLEN-2) {
				u.u_error = E2BIG;
				goto bad;
			}
			e_argbuf[nc++] = c;
		} while (c);
	}
	e_argbuf[nc++] = 0;		/* empty string terminates arg list */
	if (uap->envp) for (;;) {
		ap = fuword((caddr_t)uap->envp);
		uap->envp++;
		if (ap == 0)
			break;
		if (ap == -1) {
			u.u_error = EFAULT;
			goto bad;
		}
		do {
			if ((c = fubyte((caddr_t)ap++)) < 0) {
				u.u_error = EFAULT;
				goto bad;
			}
			if (nc >= UARGLEN-2) {
				u.u_error = E2BIG;
				goto bad;
			}
			e_argbuf[nc++] = c;
		} while (c);
	}
	e_argbuf[nc++] = 0;		/* empty string terminates env list */
	if (getxfile(ip, nc) || u.u_error)
		goto bad;

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
	{
		unsigned int strbase, sp;
		int na, ne, j, k;
		strbase = (USERSIZE - 4U - (unsigned)nc) & ~3U;
		for (i = 0; i < nc; i++)
			subyte((caddr_t)(strbase + (unsigned)i), e_argbuf[i]);
		i = 0;
		na = 0;
		while (e_argbuf[i]) {
			na++;
			while (e_argbuf[i])
				i++;
			i++;
		}
		i++;
		ne = 0;
		while (e_argbuf[i]) {
			ne++;
			while (e_argbuf[i])
				i++;
			i++;
		}
		sp = (strbase - 4U*(unsigned)(na + ne + 3)) & ~7U;
		suword((caddr_t)sp, na);
		i = 0;
		j = 0;
		while (j < na) {
			suword((caddr_t)(sp + 4U*(unsigned)(1 + j)),
			    (int)(strbase + (unsigned)i));
			while (e_argbuf[i])
				i++;
			i++;
			j++;
		}
		suword((caddr_t)(sp + 4U*(unsigned)(1 + na)), 0);
		i++;
		k = 0;
		while (k < ne) {
			suword((caddr_t)(sp + 4U*(unsigned)(1 + na + 1 + k)),
			    (int)(strbase + (unsigned)i));
			while (e_argbuf[i])
				i++;
			i++;
			k++;
		}
		suword((caddr_t)(sp + 4U*(unsigned)(1 + na + 1 + ne)), 0);
		setregs();
		u.u_ar0[R6] = (int)sp;
	}
bad:
	iput(ip);
}

struct elf32_ehdr {
	unsigned char e_ident[16];
	unsigned short e_type;
	unsigned short e_machine;
	unsigned int e_version;
	unsigned int e_entry;
	unsigned int e_phoff;
	unsigned int e_shoff;
	unsigned int e_flags;
	unsigned short e_ehsize;
	unsigned short e_phentsize;
	unsigned short e_phnum;
	unsigned short e_shentsize;
	unsigned short e_shnum;
	unsigned short e_shstrndx;
};

struct elf32_phdr {
	unsigned int p_type;
	unsigned int p_offset;
	unsigned int p_vaddr;
	unsigned int p_paddr;
	unsigned int p_filesz;
	unsigned int p_memsz;
	unsigned int p_flags;
	unsigned int p_align;
};
#define	PT_LOAD	1

static void
readbytes(struct inode *ip, caddr_t kbuf, unsigned int off, unsigned int n)
{
	u.u_base = kbuf;
	u.u_count = n;
	u.u_offset = off;
	u.u_segflg = 1;
	readi(ip);
	u.u_segflg = 0;
}
int
getxfile(ip, nargc)
register struct inode *ip;
int	nargc;
{
	struct elf32_ehdr eh;
	struct elf32_phdr ph;
	register int i;
	int n, low, stack;
	unsigned int end, maxend;
	(void)nargc;
	readbytes(ip, (caddr_t)&eh, 0, sizeof(eh));
	if(u.u_error)
		goto bad;
	if(eh.e_ident[0] != 0x7f || eh.e_ident[1] != 'E' ||
	   eh.e_ident[2] != 'L' || eh.e_ident[3] != 'F' || eh.e_type != 2) {
		u.u_error = ENOEXEC;
		goto bad;
	}
	/*
	 * Find text and data sizes, and try them out for possible overflow.
	 */
	maxend = 0;
	for(i = 0; i < (int)eh.e_phnum; i++) {
		readbytes(ip, (caddr_t)&ph, eh.e_phoff + i*eh.e_phentsize,
		    sizeof(ph));
		if(u.u_error)
			goto bad;
		if(ph.p_type != PT_LOAD)
			continue;
		if(ph.p_vaddr >= USERSIZE || ph.p_memsz > USERSIZE - ph.p_vaddr ||
		   ph.p_filesz > ph.p_memsz) {
			u.u_error = ENOMEM;
			goto bad;
		}
		end = ph.p_vaddr + ph.p_memsz;
		if(end > maxend)
			maxend = end;
	}

	u.u_prof.pr_scale = 0;
	xfree();
	n = USIZE + (int)(USERSIZE >> 6);
	expand(n);
	low = (int)btoc(maxend);
	for(i = 0; i < low; i++)
		clearseg(u.u_procp->p_addr + USIZE + i);
	stack = (int)(USERSIZE >> 6) - SSIZE;
	for(i = stack; i < (int)(USERSIZE >> 6); i++)
		clearseg(u.u_procp->p_addr + USIZE + i);
	u.u_tsize = 0;
	u.u_dsize = (unsigned)low;
	u.u_ssize = SSIZE;
	u.u_sep = 0;
	if(estabur(0, u.u_dsize, u.u_ssize, 0, RO))
		goto bad;
	for(i = 0; i < (int)eh.e_phnum; i++) {
		readbytes(ip, (caddr_t)&ph, eh.e_phoff + i*eh.e_phentsize,
		    sizeof(ph));
		if(u.u_error)
			goto bad;
		if(ph.p_type != PT_LOAD || ph.p_filesz == 0)
			continue;
		u.u_base = (caddr_t)ph.p_vaddr;
		u.u_count = ph.p_filesz;
		u.u_offset = ph.p_offset;
		u.u_segflg = 0;
		readi(ip);
		if(u.u_error)
			goto bad;
	}
	u.u_exdata.ux_entloc = eh.e_entry;
	install_sigtramp();
	arm_sync_icache();
bad:
	return(0);
}

/*
 * Clear registers on exec
 */
void
setregs()
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
	u.u_acflag &= ~AFORK;
	/*
	 * Remember file name for accounting.
	 */
	bcopy((caddr_t)u.u_dbuf, (caddr_t)u.u_comm, DIRSIZ);
}

/*
 * exit system call:
 * pass back caller's arg
 */
void
rexit()
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
exit(rv)
int	rv;
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
wait()
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
fork()
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
	if(newproc()) {
		u.u_r.r_val1 = 0;
		u.u_start = time;
		u.u_cstime = 0;
		u.u_stime = 0;
		u.u_cutime = 0;
		u.u_utime = 0;
		u.u_acflag = AFORK;
		return;
	}
	u.u_r.r_val1 = p2->p_pid;

out:	;
}

/*
 * break system call.
 *  -- bad planning: "break" is a dirty word in C.
 */
void
sbreak()
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
	if(estabur(u.u_tsize, u.u_dsize+d, u.u_ssize, u.u_sep, RO))
		return;
	if((unsigned)n > (USERSIZE >> 6) - u.u_ssize) {
		u.u_error = ENOMEM;
		return;
	}

	if(d > 0) {
		a = u.u_procp->p_addr + USIZE + (int)u.u_dsize;
		for(i = 0; i < d; i++)
			clearseg(a + i);
	}
	u.u_dsize += d;
	return;
}
