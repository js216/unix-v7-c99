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
#include "../h/buf.h"

void
mmread(int dev)
{
	register int c;
	register char *a;
	int w;

	if(minor(dev) == 2)
		return;
	if(minor(dev) == 0 && devaddr(u.u_offset)) {
		while(u.u_error==0 && u.u_count >= 4 && (u.u_offset&3) == 0 &&
		    (a = devaddr(u.u_offset)) != NULL) {
			w = *(volatile int *)a;
			iomove((caddr_t)&w, 4, B_READ);
		}
		if(u.u_count)
			u.u_error = ENXIO;
		return;
	}
	do {
		if ((c = fumem(dev, u.u_offset)) < 0)
			u.u_error = ENXIO;
	} while(u.u_error==0 && passc(c)>=0);
}

void
mmwrite(int dev)
{
	register int c;
	register char *a;
	int w;

	if(minor(dev) == 2) {
		u.u_count = 0;
		return;
	}
	if(minor(dev) == 0 && devaddr(u.u_offset)) {
		while(u.u_error==0 && u.u_count >= 4 && (u.u_offset&3) == 0 &&
		    (a = devaddr(u.u_offset)) != NULL) {
			iomove((caddr_t)&w, 4, B_WRITE);
			*(volatile int *)a = w;
		}
		if(u.u_count)
			u.u_error = ENXIO;
		return;
	}
	for(;;) {
		if ((c=cpass())<0 || u.u_error!=0)
			break;
		if (sumem(dev, u.u_offset-1, c) < 0)
			u.u_error = ENXIO;
	}
}
