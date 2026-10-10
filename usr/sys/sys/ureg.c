#include "../h/param.h"
#include "../h/systm.h"
#include "../h/dir.h"
#include "../h/user.h"
#include "../h/proc.h"
#include "../h/text.h"
#include "../h/seg.h"

extern unsigned user_l2[];
static unsigned	ulo, uhi = USERSIZE/PGSIZE;

/*
 * Load the user hardware segmentation
 * registers from the software prototype.
 * The software registers must have
 * been setup prior by estabur.
 */
void
sureg(void)
{
	register unsigned i, a;
	int taddr, daddr;
	struct text *tp;

	taddr = daddr = u.u_procp->p_addr;
	if ((tp=u.u_procp->p_textp) != NULL)
		taddr = tp->x_caddr;
	while(ulo > 0)
		user_l2[--ulo] = 0;
	while(uhi < USERSIZE/PGSIZE)
		user_l2[uhi++] = 0;
	a = (unsigned)CLKADDR(taddr);
	for(i = 0; i < u.u_ptsize; i++, a += PGSIZE)
		user_l2[ulo++] = a | pguser | u.u_pxrw;
	a = (unsigned)CLKADDR(daddr+USIZE);
	for(i = 0; i < u.u_pdsize; i++, a += PGSIZE)
		user_l2[ulo++] = a | pguser | RW;
	a = (unsigned)CLKADDR(daddr+USIZE+u.u_pdsize+u.u_pssize);
	for(i = 0; i < u.u_pssize; i++)
		user_l2[--uhi] = (a -= PGSIZE) | pguser | RW;
	arm_sync_icache();
}

/*
 * Set up software prototype segmentation
 * registers to implement the 3 pseudo
 * text,data,stack segment sizes passed
 * as arguments.
 * The argument sep specifies if the
 * text and data+stack segments are to
 * be separated.
 * The last argument determines whether the text
 * segment is read-write or read-only.
 */
int
estabur(unsigned nt, unsigned nd, unsigned ns, int sep, int xrw)
{

	if(sep)
		goto err;
	if(ctos(nt)+ctos(nd)+ctos(ns) > USERSIZE/PGSIZE)
		goto err;
	if((int)(nt+nd+ns+USIZE) > maxmem)
		goto err;
	u.u_ptsize = nt;
	u.u_pdsize = nd;
	u.u_pssize = ns;
	u.u_pxrw = xrw;
	sureg();
	return(0);

err:
	u.u_error = ENOMEM;
	return(-1);
}
