#
/*
 */

/*
 *	Memory special file
 *	minor device 0 is physical memory
 *	minor device 1 is kernel memory
 *	minor device 2 is EOF/RATHOLE
 */

#include "../h/param.h"
#include "../h/systm.h"
#include "../h/dir.h"
#include "../h/user.h"
#include "../h/conf.h"
#include "../h/seg.h"

int
mmread(dev)
int	dev;
{
	register int c;

	if(minor(dev) == 2)
		return(0);
	do {
		if ((c = fumem((unsigned int)u.u_offset)) < 0)
			u.u_error = ENXIO;
	} while(u.u_error==0 && passc(c)>=0);
	return(0);
}

int
mmwrite(dev)
int	dev;
{
	register int c;
	unsigned int off;

	if(minor(dev) == 2) {
		u.u_count = 0;
		return(0);
	}
	for(;;) {
		off = (unsigned int)u.u_offset;
		if ((c=cpass())<0 || u.u_error!=0)
			break;
		if (sumem(off, c) < 0)
			u.u_error = ENXIO;
	}
	return(0);
}
