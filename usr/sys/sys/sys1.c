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
void printf(char *fmt, ...);
int fuword(caddr_t addr);
int fubyte(caddr_t addr);
int subyte(caddr_t addr, char c);
int suword(caddr_t addr, int v);
int copyout(caddr_t f, caddr_t t, unsigned int n);
void bcopy(char *from, char *to, unsigned int n);
void xfree(void);
void xalloc(struct inode *ip);
int estabur(unsigned nt, unsigned nd, unsigned ns, int sep, int xrw);
void expand(int newsize);
void clearseg(int a);
void acct(void);
void wakeup(caddr_t chan);
void setrun(struct proc *p);
void swtch(void);
void closef(struct file *fp);
int fsig(struct proc *p);
void sleep(caddr_t chan, int pri);
void psignal(struct proc *p, int sig);
int newproc(void);
void copyseg(int from, int to);
void arm_sync_icache(void);
void readi(struct inode *ip);
void iput(struct inode *ip);
int access(struct inode *ip, int mode);
void plock(struct inode *ip);
struct inode *namei(int (*func)(void), int flag);
int uchar(void);
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

/*
 * exece: load and run a new program image.
 *
 * Args/environment are collected (NUL-separated) into a kernel buffer
 * from the old user image, then -- after getxfile() builds the new
 * image -- written as the initial stack frame (see below).  This Armv7
 * image has ample RAM, so no swap round-trip is needed for the arg list.
 */
static char e_argbuf[UARGLEN];
void
exece(void)
{
	register struct execa *uap;
	register int nc, c, ap;
	struct inode *ip;
	int i;

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
	/*
	 * Build the initial user stack frame at the top of the address space
	 * (V7 layout): the NUL-separated string image sits at the very top,
	 * with the argc/argv[]/0/envp[]/0 vector just below it and sp pointing
	 * at argc.  crt0 reads the frame straight off sp.  Placing the strings
	 * at the top is also what lets ps(1) recover a process's command line.
	 */
	{
		unsigned int strbase, sp;
		int na, ne, j, k;
		/* leave the top word zero: ps(1) treats a non-zero top-of-stack
		 * word as an argv pointer, so a string there would mislead it. */
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
		u.u_ar0[R6] = (int)sp;	/* user stack pointer */
	}
bad:
	iput(ip);
}

/*
 * ELF32 header / program-header subset (the Armv7 toolchain emits ELF;
 * this replaces the PDP-11 a.out reader).
 */
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
/*
 * Read in and set up memory for an ELF executable.
 * The Armv7 user image is a flat 1 MB window; arm_sureg maps it, so we
 * allocate the full image, zero it, then read each PT_LOAD segment to
 * its virtual address.  Entry goes through u_exdata.ux_entloc (used by
 * setregs).  Zero return is normal.
 */
int
getxfile(register struct inode *ip, int nargc)
{
	struct elf32_ehdr eh;
	struct elf32_phdr ph;
	register int i;
	int n;
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
	 * Commit to the new image: release old text, allocate and clear
	 * the full user image, and map it.
	 */
	u.u_prof.pr_scale = 0;
	xfree();
	n = USIZE + (int)(USERSIZE >> 6);
	expand(n);
	for(i = USIZE; i < n; i++)
		clearseg(u.u_procp->p_addr + i);
	u.u_tsize = 0;
	u.u_dsize = (USERSIZE >> 6) - SSIZE;
	u.u_ssize = SSIZE;
	u.u_sep = 0;
	if(estabur(0, u.u_dsize, u.u_ssize, 0, RO))
		goto bad;
	/*
	 * Load each PT_LOAD segment to its virtual address.
	 */
	for(i = 0; i < (int)eh.e_phnum; i++) {
		readbytes(ip, (caddr_t)&ph, eh.e_phoff + i*eh.e_phentsize,
		    sizeof(ph));
		if(u.u_error)
			goto bad;
		if(ph.p_type != PT_LOAD || ph.p_filesz == 0)
			continue;
		if(ph.p_vaddr >= USERSIZE || ph.p_filesz > USERSIZE - ph.p_vaddr) {
			u.u_error = ENOMEM;
			goto bad;
		}
		u.u_base = (caddr_t)ph.p_vaddr;
		u.u_count = ph.p_filesz;
		u.u_offset = ph.p_offset;
		u.u_segflg = 0;
		readi(ip);
		if(u.u_error)
			goto bad;
	}
	u.u_exdata.ux_entloc = eh.e_entry;
	arm_sync_icache();
bad:
	return(0);
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
	if(newproc()) {
		/* child: fork() returns 0 */
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
