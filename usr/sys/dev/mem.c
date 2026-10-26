#
/*
 */

/*
 *	Memory special file
 *	minor device 0 is physical memory
 *	minor device 1 is kernel memory
 *	minor device 2 is EOF/RATHOLE
 *	minor device 3 is an endless source of zeros
 */

#include "../h/param.h"
#include "../h/systm.h"
#include "../h/dir.h"
#include "../h/user.h"
#include "../h/conf.h"
#include "../h/buf.h"

static char	zeros[512];

void
mmread(int dev)
{
	register int c;
	register char *a;
	int w;

	if(minor(dev) == 2)
		return;
	if(minor(dev) == 3) {
		while(u.u_error==0 && u.u_count > 0)
			iomove(zeros, u.u_count < sizeof(zeros) ? u.u_count :
			    sizeof(zeros), B_READ);
		return;
	}
	if(devaddr(dev, u.u_offset)) {
		while(u.u_error==0 && u.u_count >= 4 &&
		    (u.u_offset&3) == 0 &&
		    (a = devaddr(dev, u.u_offset)) != NULL) {
			if(fkword((int *)a, &w) < 0)
				break;
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

	if(minor(dev) == 2 || minor(dev) == 3) {
		u.u_count = 0;
		return;
	}
	if(devaddr(dev, u.u_offset)) {
		while(u.u_error==0 && u.u_count >= 4 &&
		    (u.u_offset&3) == 0 &&
		    (a = devaddr(dev, u.u_offset)) != NULL) {
			iomove((caddr_t)&w, 4, B_WRITE);
			if(skword((int *)a, w) < 0)
				u.u_error = ENXIO;
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
