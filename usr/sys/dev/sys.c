/*
 *	indirect driver for controlling tty.
 */
#include "../h/param.h"
#include "../h/conf.h"
#include "../h/dir.h"
#include "../h/user.h"
#include "../h/tty.h"
#include "../h/proc.h"

int
syopen(dev_t dev, int flag)
{

	(void)dev;
	if(u.u_ttyp == NULL) {
		u.u_error = ENXIO;
		return(0);
	}
	(*cdevsw[major(u.u_ttyd)].d_open)(u.u_ttyd, flag);
	return(0);
}

int
syread(dev_t dev)
{

	(void)dev;
	(*cdevsw[major(u.u_ttyd)].d_read)(u.u_ttyd);
	return(0);
}

int
sywrite(dev_t dev)
{

	(void)dev;
	(*cdevsw[major(u.u_ttyd)].d_write)(u.u_ttyd);
	return(0);
}

int
sysioctl(dev_t dev, int cmd, caddr_t addr, int flag)
{

	(void)dev;
	(*cdevsw[major(u.u_ttyd)].d_ioctl)(u.u_ttyd, cmd, addr, flag);
	return(0);
}
