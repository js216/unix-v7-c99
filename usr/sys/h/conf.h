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
struct tty;
extern struct bdevsw
{
	void	(*d_open)(dev_t dev, int flag);
	void	(*d_close)(dev_t dev, int flag);
	void	(*d_strategy)(struct buf *bp);
	struct buf *d_tab;
} bdevsw[];

/*
 * Character device switch.
 */
extern struct cdevsw
{
	void	(*d_open)(dev_t dev, int flag);
	void	(*d_close)(dev_t dev, int flag);
	void	(*d_read)(dev_t dev);
	void	(*d_write)(dev_t dev);
	void	(*d_ioctl)(dev_t dev, int cmd, caddr_t addr, int flag);
	void	(*d_stop)(struct tty *tp);
	struct tty *d_ttys;
} cdevsw[];

/*
 * tty line control switch.
 */
extern struct linesw
{
	void	(*l_open)(dev_t dev, struct tty *tp);
	void	(*l_close)(struct tty *tp);
	int	(*l_read)(struct tty *tp);
	char	*(*l_write)(struct tty *tp);
	void	(*l_ioctl)(int cmd, struct tty *tp, caddr_t addr);
	void	(*l_rint)(int c, struct tty *tp);
	void	(*l_rend)(struct tty *tp, char *pb, char *pe);
	int	(*l_meta)(struct tty *tp);
	void	(*l_start)(struct tty *tp);
	int	(*l_modem)(struct tty *tp);
} linesw[];

struct intr
{
	int	*i_irq;
	void	(*i_fn)(caddr_t pc, int ps);
};
extern struct intr intrtab[];
