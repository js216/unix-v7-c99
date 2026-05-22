/*
 * QEMU ARM configuration, the static equivalent of v7 conf/c.c.
 */
#include "../../h/param.h"
#include "../../h/buf.h"
#include "../../h/conf.h"
#include "../../h/file.h"
#include "../../h/proc.h"
#include "../../h/proto.h"
#include "../../h/text.h"

extern struct buf virtio_tab;

static int
nulldev_dev(dev_t dev, int flag)
{
	(void)dev;
	(void)flag;
	return 0;
}

dev_t rootdev = 0;
int nblkdev = 0;	/* binit() counts populated bdevsw[] rows from here */

struct bdevsw bdevsw[2] = {
	{ nulldev_dev, nulldev_dev, virtio_strategy, &virtio_tab },
	{ 0, 0, 0, 0 }
};

struct proc proc[NPROC];
struct file file[NFILE];
struct text text[NTEXT];
struct cdevsw cdevsw[1];	/* trailing zero row terminates */
