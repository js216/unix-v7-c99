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
#include "../h/seg.h"		/* KTABLES_SECTION (board-selected via memmap.h) */

/*
 * Device switch.  The console (cn*) and block device (bd*) entry points are
 * a board-independent interface: the QEMU build links pl011.c + virtio_blk.c,
 * the MP135 build links stm32usart.c + stm32sd.c, and each board's Makefile
 * pulls in exactly one driver implementing these symbols.  This file is the
 * same on both boards; the devices differ only by which driver is linked.
 */
extern struct buf bdtab;
extern int bdstrategy(struct buf *bp);
extern int nodev(void);
extern int nulldev(void);
extern int mmread(dev_t dev);
extern int mmwrite(dev_t dev);
extern int cnopen(dev_t dev, int flag);
extern int cnclose(dev_t dev, int flag);
extern int cnread(dev_t dev);
extern int cnwrite(dev_t dev);
extern int cnioctl(dev_t dev, int cmd, caddr_t addr, int flag);
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
	{ nulldev_dev, nulldev_dev, bdstrategy, &bdtab },
	{ 0, 0, 0, 0 }
};

struct cdevsw cdevsw[] = {
	{ cnopen, cnclose, cnread, cnwrite, cnioctl, nulldev, 0 },
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

/*
 * The large system tables go in KTABLES_SECTION (conf/<board>/memmap.h): on
 * the MP135, whose 128 KB SYSRAM cannot hold them, that is ".ddrbss", which
 * the linker places in DDR and machine_init() zeroes once DRAM is up; on QEMU,
 * where RAM is one block, it is the ordinary ".bss" zeroed by low.s.
 */
#define	DDRBSS	__attribute__((section(KTABLES_SECTION)))
struct buf buf[NBUF]		DDRBSS;
struct file file[NFILE]		DDRBSS;
struct inode inode[NINODE]	DDRBSS;
struct proc proc[NPROC]		DDRBSS;
struct text text[NTEXT]		DDRBSS;
struct buf bfreelist;
struct acct acctbuf;
struct inode *acctp;
