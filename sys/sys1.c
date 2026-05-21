#include "../h/param.h"
#include "../h/dir.h"
#include "../h/user.h"
#include "../h/proc.h"
#include "../h/seg.h"
#include "../h/proto.h"

extern int  estabur(unsigned, unsigned, unsigned, int, int);
/* copyseg/clearseg come from h/proto.h. */
extern void expand(int);

/* v7 sys/sys1.c held exec/exece/getxfile/setregs/rexit/exit/wait/fork.
 * On this port they're all reimplemented inline in arch/armboot.c::trap()
 * and v7_exec_call(); the v7 versions are linker-dead.  Only sbreak()
 * (the break(2) syscall, sysent[17]) is kept -- it still drives the v7
 * data-segment grow/shrink via expand()/copyseg(). */


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
