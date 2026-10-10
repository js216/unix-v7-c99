#include "../h/param.h"
#include "../h/systm.h"
#include "../h/dir.h"
#include "../h/user.h"
#include "../h/reg.h"
#define	EBIT	0x20000000	/* user error bit in PS: C-bit */
static void nullsys(void) { }
static void nosys(void) { u.u_error = EINVAL; }

/*
 * This table is the switch used to transfer
 * to the appropriate routine for processing a system call.
 * Each row contains the number of arguments expected
 * and a pointer to the routine.
 */

struct sysent sysent[64] =
{
	{0, 0, nullsys},		/*  0 = indir */
	{1, 1, rexit},			/*  1 = exit */
	{0, 0, fork},			/*  2 = fork */
	{3, 3, read},			/*  3 = read */
	{3, 3, write},			/*  4 = write */
	{2, 2, open},			/*  5 = open */
	{1, 1, close},			/*  6 = close */
	{0, 0, wait},			/*  7 = wait */
	{2, 2, creat},			/*  8 = creat */
	{2, 2, link},			/*  9 = link */
	{1, 1, unlink},			/* 10 = unlink */
	{2, 2, exec},			/* 11 = exec */
	{1, 1, chdir},			/* 12 = chdir */
	{0, 0, gtime},			/* 13 = time */
	{3, 3, mknod},			/* 14 = mknod */
	{2, 2, chmod},			/* 15 = chmod */
	{3, 3, chown},			/* 16 = chown; now 3 args */
	{1, 1, sbreak},			/* 17 = break */
	{2, 2, stat},			/* 18 = stat */
	{3, 3, seek},			/* 19 = seek; now 3 args */
	{0, 0, getpid},			/* 20 = getpid */
	{3, 3, smount},			/* 21 = mount */
	{1, 1, sumount},		/* 22 = umount */
	{1, 1, setuid},			/* 23 = setuid */
	{0, 0, getuid},			/* 24 = getuid */
	{1, 1, stime},			/* 25 = stime */
	{4, 4, ptrace},			/* 26 = ptrace */
	{1, 1, alarm},			/* 27 = alarm */
	{2, 2, fstat},			/* 28 = fstat */
	{0, 0, pause},			/* 29 = pause */
	{2, 2, utime},			/* 30 = utime */
	{2, 2, stty},			/* 31 = stty */
	{2, 2, gtty},			/* 32 = gtty */
	{2, 2, saccess},		/* 33 = access */
	{1, 1, nice},			/* 34 = nice */
	{1, 1, ftime},			/* 35 = ftime; formerly sleep */
	{0, 0, sync},			/* 36 = sync */
	{2, 2, kill},			/* 37 = kill */
	{0, 0, nullsys},		/* 38 = switch; inoperative */
	{0, 0, nullsys},		/* 39 = setpgrp (not in yet) */
	{0, 0, nosys},			/* 40 = tell (obsolete) */
	{2, 2, dup},			/* 41 = dup */
	{0, 0, pipe},			/* 42 = pipe */
	{1, 1, times},			/* 43 = times */
	{4, 4, profil},			/* 44 = prof */
	{0, 0, nosys},			/* 45 = unused */
	{1, 1, setgid},			/* 46 = setgid */
	{0, 0, getgid},			/* 47 = getgid */
	{2, 2, ssig},			/* 48 = sig */
	{0, 0, nosys},			/* 49 = reserved for USG */
	{0, 0, nosys},			/* 50 = reserved for USG */
	{1, 1, sysacct},		/* 51 = turn acct off/on */
	{3, 3, sysphys},		/* 52 = set user physical addresses */
	{1, 1, syslock},		/* 53 = lock user in core */
	{3, 3, ioctl},			/* 54 = ioctl */
	{0, 0, nosys},			/* 55 = readwrite (in abeyance) */
	{0, 0, nosys},			/* 56 = creat mpx comm channel */
	{0, 0, nosys},			/* 57 = reserved for USG */
	{0, 0, nosys},			/* 58 = reserved for USG */
	{3, 3, exece},			/* 59 = exece */
	{1, 1, umask},			/* 60 = umask */
	{1, 1, chroot},			/* 61 = chroot */
	{0, 0, nosys},			/* 62 = x */
	{0, 0, sigreturn}		/* 63 = sigreturn */
};
char	regloc[9] = { R0, R1, R2, R3, R4, R5, R6, R7, RPS };
void
trap(int *r)
{
	register int i;
	register struct sysent *callp;
	time_t syst;

	syst = u.u_stime;
	u.u_fpsaved = 0;
	u.u_ar0 = r;
	u.u_error = 0;
	r[RPS] &= ~EBIT;
	callp = &sysent[r[7] & 077];
	for(i = 0; i < callp->sy_narg; i++)
		u.u_arg[i] = r[i];
	u.u_dirp = (caddr_t)u.u_arg[0];
	u.u_r.r_val1 = 0;
	u.u_r.r_val2 = r[R1];
	u.u_ap = u.u_arg;
	if (save(u.u_qsav)) {
		if (u.u_error == 0)
			u.u_error = EINTR;
	} else {
		(*callp->sy_call)();
	}
	if (u.u_error) {
		r[RPS] |= EBIT;
		r[R0] = u.u_error;
	} else {
		r[R0] = u.u_r.r_val1;
		r[R1] = u.u_r.r_val2;
	}
	if (issig())
		psig();
	curpri = setpri(u.u_procp);
	if (runrun)
		qswtch();
	if(u.u_prof.pr_scale)
		addupc((caddr_t)r[PC], &u.u_prof, (int)(u.u_stime-syst));
}
void
user_trap_handler(int signo, int *r)
{
	if((r[RPS] & 0x1f) != 0x10) {
		printf("kernel trap sig=%d pc=0x%x cpsr=0x%x dfar=0x%x dfsr=0x%x\n",
		    signo, r[15], r[RPS], dfar(), dfsr());
		panic("kernel trap");
	}
	u.u_fpsaved = 0;
	u.u_ar0 = r;
	psignal(u.u_procp, signo);
	if (issig())
		psig();
	curpri = setpri(u.u_procp);
	if (runrun)
		qswtch();
}
