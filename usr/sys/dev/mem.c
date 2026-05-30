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
#include "../h/dir.h"
#include "../h/user.h"
int passc(int c);
int cpass(void);
int arm_mem_read(unsigned int off, char *buf, unsigned int n);

int
mmread(dev_t dev)
{
	register int c;
	char buf[64];
	unsigned int n, off;

	if(minor(dev) == 2)
		return(0);
	do {
		off = (unsigned int)u.u_offset;
		n = u.u_count;
		if(n > sizeof(buf))
			n = sizeof(buf);
		if(arm_mem_read(off, buf, n) <= 0)
			break;
		for(unsigned int i = 0; i < n; i++) {
			c = buf[i];
			if(passc(c) < 0 || u.u_error != 0)
				return(0);
		}
	} while(u.u_count != 0 && u.u_error == 0);
	return(0);
}

int
mmwrite(dev_t dev)
{
	register int c;

	if(minor(dev) == 2) {
		u.u_count = 0;
		return(0);
	}
	for(;;) {
		if((c = cpass()) < 0 || u.u_error != 0)
			break;
		*(char *)(unsigned int)(u.u_offset-1) = c;
	}
	return(0);
}
