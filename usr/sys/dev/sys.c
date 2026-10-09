/*
 *	indirect driver for controlling tty.
 */
#include "../h/param.h"
#include "../h/systm.h"
#include "../h/conf.h"
#include "../h/dir.h"
#include "../h/user.h"
#include "../h/tty.h"
#include "../h/proc.h"

void
syopen(int dev, int flag)
{

	(void)dev;
	if(u.u_ttyp == NULL) {
		u.u_error = ENXIO;
		return;
	}
	(*cdevsw[major(u.u_ttyd)].d_open)(u.u_ttyd, flag);
}

void
syread(int dev)
{

	(void)dev;
	(*cdevsw[major(u.u_ttyd)].d_read)(u.u_ttyd);
}

void
sywrite(int dev)
{

	(void)dev;
	(*cdevsw[major(u.u_ttyd)].d_write)(u.u_ttyd);
}

void
sysioctl(int dev, int cmd, caddr_t addr, int flag)
{

	(void)dev;
	(*cdevsw[major(u.u_ttyd)].d_ioctl)(u.u_ttyd, cmd, addr, flag);
}
