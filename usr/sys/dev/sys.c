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
	(*cdevsw[major(u.u_ttyp->t_dev)].d_open)(u.u_ttyp->t_dev, flag);
}

void
syread(int dev)
{

	(void)dev;
	(*cdevsw[major(u.u_ttyp->t_dev)].d_read)(u.u_ttyp->t_dev);
}

void
sywrite(int dev)
{

	(void)dev;
	(*cdevsw[major(u.u_ttyp->t_dev)].d_write)(u.u_ttyp->t_dev);
}

void
sysioctl(int dev, int cmd, caddr_t addr, int flag)
{

	(void)dev;
	(*cdevsw[major(u.u_ttyp->t_dev)].d_ioctl)(u.u_ttyp->t_dev, cmd, addr, flag);
}
