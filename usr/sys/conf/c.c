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
extern int passc(int c);
extern int cpass(void);
extern int getchar(void);
extern void putchar(char c);
extern int mmread(dev_t dev);
extern int mmwrite(dev_t dev);
extern struct ttiocb console_sgtty;

static int
nulldev_dev(dev_t dev, int flag)
{
	(void)dev;
	(void)flag;
	return(0);
}

/*
 * Console open.  This port has no general tty layer, but the controlling
 * -terminal/process-group handshake of v7 ttyopen() (dev/tty.c) is what
 * lets a session's processes carry a p_pgrp.  Replicate just that: the
 * first pgrp-less opener becomes the console's group leader, and every
 * later pgrp-less opener joins that group.
 */
static int console_pgrp = 0;
static int
console_open(dev_t dev, int flag)
{
	register struct proc *pp;

	(void)dev;
	(void)flag;
	pp = u.u_procp;
	if(pp->p_pgrp == 0) {
		if(console_pgrp == 0)
			console_pgrp = pp->p_pid;
		pp->p_pgrp = console_pgrp;
	}
	return(0);
}

static int
console_read(dev_t dev)
{
	register int c;

	(void)dev;
	while(u.u_count != 0) {
		c = getchar();
		if(c == '\r')
			c = '\n';
		if(console_sgtty.ioc_flags & ECHO)
			putchar(c);
		if(passc(c) < 0)
			break;
		if(c == '\n')
			break;
	}
	return(0);
}

static int
console_write(dev_t dev)
{
	register int c;

	(void)dev;
	while((c = cpass()) >= 0)
		putchar(c);
	return(0);
}

struct bdevsw bdevsw[] = {
	{ nulldev_dev, nulldev_dev, virtio_strategy, &virtio_tab },
	{ 0, 0, 0, 0 }
};

struct cdevsw cdevsw[] = {
	{ console_open, nulldev_dev, console_read, console_write, nodev,
	    nodev, 0 },
	{ nulldev_dev, nulldev_dev, mmread, mmwrite, nodev, nodev, 0 },
	{ 0, 0, 0, 0, 0, 0, 0 }
};

struct linesw linesw[] = {
	{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }
};

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
