#include "../h/param.h"
#include "../h/systm.h"
#include "../h/dir.h"
#include "../h/user.h"
#include "../h/proc.h"
#include "../h/text.h"
#include "../h/seg.h"

int estabur(unsigned nt, unsigned nd, unsigned ns, int sep, int xrw);

/*
 * v7's sureg() pushed the per-proc u_uisa/u_uisd prototype into the
 * PDP-11's UISA/UISD segment registers at 0177640 / 0177600.  On ARM
 * those literal addresses fall inside l1[0]'s identity-mapped user
 * page (USERPHYS+0xFF80..0xFFFE), so the original loop would silently
 * scribble over the bottom of every process's address space.  ARM
 * userspace runs out of a single 1 MiB identity-mapped window with
 * no per-segment registers to reload, so this is a no-op.
 */
void
sureg(void)
{
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
	register int a, *ap, *dp;

	if(sep) {
		if(cputype == 40)
			goto err;
		if(ctos(nt) > 8 || ctos(nd)+ctos(ns) > 8)
			goto err;
	} else
		if(ctos(nt)+ctos(nd)+ctos(ns) > 8)
			goto err;
	if((int)(nt+nd+ns+USIZE) > maxmem)
		goto err;
	a = 0;
	ap = &u.u_uisa[0];
	dp = &u.u_uisd[0];
	while(nt >= 128) {
		*dp++ = (127<<8) | xrw|TX;
		*ap++ = a;
		a += 128;
		nt -= 128;
	}
	if(nt) {
		*dp++ = ((nt-1)<<8) | xrw|TX;
		*ap++ = a;
	}
	if(sep)
	while(ap < &u.u_uisa[8]) {
		*ap++ = 0;
		*dp++ = 0;
	}
	a = USIZE;
	while(nd >= 128) {
		*dp++ = (127<<8) | RW;
		*ap++ = a;
		a += 128;
		nd -= 128;
	}
	if(nd) {
		*dp++ = ((nd-1)<<8) | RW;
		*ap++ = a;
		a += nd;
	}
	while(ap < &u.u_uisa[8]) {
		if(*dp &ABS) {
			dp++;
			ap++;
			continue;
		}
		*dp++ = 0;
		*ap++ = 0;
	}
	if(sep)
	while(ap < &u.u_uisa[16]) {
		if(*dp & ABS) {
			dp++;
			ap++;
			continue;
		}
		*dp++ = 0;
		*ap++ = 0;
	}
	a += ns;
	while(ns >= 128) {
		a -= 128;
		ns -= 128;
		*--dp = (127<<8) | RW;
		*--ap = a;
	}
	if(ns) {
		*--dp = ((128-ns)<<8) | RW | ED;
		*--ap = a-128;
	}
	if(!sep) {
		ap = &u.u_uisa[0];
		dp = &u.u_uisa[8];
		while(ap < &u.u_uisa[8])
			*dp++ = *ap++;
		ap = &u.u_uisd[0];
		dp = &u.u_uisd[8];
		while(ap < &u.u_uisd[8])
			*dp++ = *ap++;
	}
	sureg();
	return(0);

err:
	u.u_error = ENOMEM;
	return(-1);
}
