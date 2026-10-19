#include "../h/param.h"
#include "../h/systm.h"
#include "../h/dir.h"
#include "../h/user.h"
#include "../h/reg.h"

#define	EBIT	0x20000000	/* user error bit in PS: C-bit */

/*
 * Offsets of the user's registers relative to
 * the saved r0. See reg.h
 */
char	regloc[9] =
{
	R0, R1, R2, R3, R4, R5, SP, PC, PSR
};

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
	r[PSR] &= ~EBIT;
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
		r[PSR] |= EBIT;
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
		addupc((caddr_t)r[PC], &u.u_prof,
		    (int)(u.u_stime-syst));
	if (u.u_fpsaved)
		restfp(&u.u_fps);
}
void
user_trap_handler(int signo, int *r, unsigned a)
{
	if(!USERMODE(r[PSR])) {
		printf("kernel trap sig=%d pc=0x%x cpsr=0x%x dfar=0x%x "
		    "dfsr=0x%x\n",
		    signo, r[PC], r[PSR], dfar(), dfsr());
		panic("kernel trap");
	}
	u.u_fpsaved = 0;
	u.u_ar0 = r;
	if(signo == SIGINS && r[PSR]&0x20 &&
	    (fubyte((caddr_t)r[PC]-1)&0xf8) >= 0xe8)
		r[PC] += 2;
	if(signo && (signo != SIGSEG || a+256 < (unsigned)r[SP] ||
	    grow(a) == 0))
		psignal(u.u_procp, signo);
	if (issig())
		psig();
	curpri = setpri(u.u_procp);
	if (runrun)
		qswtch();
	if (u.u_fpsaved)
		restfp(&u.u_fps);
}

/*
 * nonexistent system call-- set fatal error code.
 */
void
nosys(void)
{
	u.u_error = EINVAL;
}

/*
 * Ignored system call
 */
void
nullsys(void)
{
}
