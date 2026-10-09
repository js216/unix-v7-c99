#include "../h/param.h"
#include "../h/systm.h"
#include "../h/dir.h"
#include "../h/user.h"
#include "../h/proc.h"
#include "../h/text.h"
#include "../h/seg.h"

/*
 * Load the user hardware segmentation
 * registers from the software prototype.
 * The software registers must have
 * been setup prior by estabur.
 */
void
sureg(void)
{
	register int *udp, *uap, *rap;
	int auisa[16];
	int *limudp;
	int taddr, daddr;
	struct text *tp;

	taddr = daddr = u.u_procp->p_addr;
	if ((tp=u.u_procp->p_textp) != NULL)
		taddr = tp->x_caddr;
	limudp = &u.u_uisd[16];
	if (cputype==40)
		limudp = &u.u_uisd[8];
	rap = &auisa[0];
	uap = &u.u_uisa[0];
	for (udp = &u.u_uisd[0]; udp < limudp;) {
		*rap++ = *uap++ + (*udp&TX? taddr: (*udp&ABS? 0: daddr));
		udp++;
	}
	arm_sureg();
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
	(void)sep; (void)xrw;

	if((int)(nt+nd+ns+USIZE) > maxmem)
		goto err;
	sureg();
	return(0);

err:
	u.u_error = ENOMEM;
	return(-1);
}
