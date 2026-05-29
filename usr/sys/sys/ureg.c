#include "../h/param.h"
#include "../h/systm.h"
#include "../h/dir.h"
#include "../h/user.h"
#include "../h/proc.h"
#include "../h/text.h"
#include "../h/seg.h"
int estabur(unsigned nt, unsigned nd, unsigned ns, int sep, int xrw);
void arm_sureg(int *uisa, int *uisd, int nseg);

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
	arm_sureg(auisa, &u.u_uisd[0], limudp - &u.u_uisd[0]);
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
	/*
	 * Armv7: user memory is mapped by page tables (arm_sureg), not the
	 * PDP-11 8-segment scheme, so the per-segment limit checks and the
	 * u_uisa/u_uisd prototype build do not apply.  Validate the total
	 * image size against maxmem and (re)load the page tables via sureg().
	 */

	if((int)(nt+nd+ns+USIZE) > maxmem) {
		u.u_error = ENOMEM;
		return(-1);
	}
	sureg();
	return(0);

}
