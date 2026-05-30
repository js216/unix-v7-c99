#include "../h/param.h"
#include "../h/acct.h"
#include "../h/buf.h"
#include "../h/conf.h"
#include "../h/dir.h"
#include "../h/file.h"
#include "../h/filsys.h"
#include "../h/inode.h"
#include "../h/mount.h"
#include "../h/proc.h"
#include "../h/systm.h"
#include "../h/text.h"
#include "../h/tty.h"
#include "../h/user.h"

extern struct buf virtio_tab;
extern int virtio_strategy(struct buf *bp);
extern int nodev(void);
extern int nulldev(void);
extern int mmread(dev_t dev);
extern int mmwrite(dev_t dev);
extern int pl011open(dev_t dev, int flag);
extern int pl011close(dev_t dev, int flag);
extern int pl011read(dev_t dev);
extern int pl011write(dev_t dev);
extern int pl011ioctl(dev_t dev, int cmd, caddr_t addr, int flag);
extern int syopen(dev_t dev, int flag);
extern int syread(dev_t dev);
extern int sywrite(dev_t dev);
extern int sysioctl(dev_t dev, int cmd, caddr_t addr, int flag);

static int
nulldev_dev(dev_t dev, int flag)
{
	(void)dev;
	(void)flag;
	return(0);
}

struct bdevsw bdevsw[] = {
	{ nulldev_dev, nulldev_dev, virtio_strategy, &virtio_tab },
	{ 0, 0, 0, 0 }
};

struct cdevsw cdevsw[] = {
	{ pl011open, pl011close, pl011read, pl011write, pl011ioctl, nulldev, 0 },
	{ nulldev_dev, nulldev_dev, mmread, mmwrite, nodev, nodev, 0 },
	{ syopen, nulldev, syread, sywrite, sysioctl, nulldev, 0 },
	{ 0, 0, 0, 0, 0, 0, 0 }
};

struct linesw linesw[] = {
	{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }
};

int	nldisp = 1;

dev_t	rootdev = makedev(0, 0);
dev_t	swapdev = makedev(0, 0);
dev_t	pipedev = makedev(0, 0);

struct buf buf[NBUF];
struct file file[NFILE];
struct inode inode[NINODE];
struct proc proc[NPROC];
struct text text[NTEXT];
struct buf bfreelist;
struct acct acctbuf;
struct inode *acctp;
