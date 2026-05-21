/*
 * Declaration of block device
 * switch. Each entry (row) is
 * the only link between the
 * main unix code and the driver.
 * The initialization of the
 * device switches is in the
 * file conf.c.
 */
struct buf;
extern struct bdevsw
{
	int	(*d_open)(dev_t dev, int rw);
	int	(*d_close)(dev_t dev, int flag);
	int	(*d_strategy)(struct buf *bp);
	struct buf *d_tab;
} bdevsw[];

/*
 * Character device switch.  v7's d_ioctl, d_stop, d_ttys are gone --
 * cdevsw[] is empty on this port (no char-device drivers wire it).
 */
extern struct cdevsw
{
	int	(*d_open)(dev_t dev, int rw);
	int	(*d_close)(dev_t dev, int flag);
	int	(*d_read)(dev_t dev);
	int	(*d_write)(dev_t dev);
} cdevsw[];

