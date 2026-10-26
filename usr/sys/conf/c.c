#include "../h/param.h"
#include "../h/systm.h"
#include "../h/buf.h"
#include "../h/tty.h"
#include "../h/conf.h"
#include "../h/proc.h"
#include "../h/text.h"
#include "../h/dir.h"
#include "../h/user.h"
#include "../h/file.h"
#include "../h/inode.h"
#include "../h/acct.h"

#include "../h/seg.h"
#include "../h/map.h"
#include "../h/mount.h"
#include "../h/callo.h"
#include "mach.h"

extern struct	buf	rktab;
struct	bdevsw	bdevsw[] =
{
	{nulldev, nulldev, rkstrategy, &rktab}, /* rk 0 */
	{nodev, nodev, nostrat, 0}, /* rp 1 */
	{nodev, nodev, nostrat, 0}, /* rf 2 */
	{nodev, nodev, nostrat, 0}, /* tm 3 */
	{nodev, nodev, nostrat, 0}, /* tc 4 */
	{nodev, nodev, nostrat, 0}, /* hs 5 */
	{nodev, nodev, nostrat, 0}, /* hp 6 */
	{nodev, nodev, nostrat, 0}, /* ht 7 */
	{nodev, nodev, nostrat, 0}, /* rl 8 */
	{0}
};

struct	cdevsw	cdevsw[] =
{
	{klopen, klclose, klread, klwrite, klioctl, nulltty, 0}, /* console 0 */
	{nodev, nodev, nordwr, nordwr, noioctl, nulltty, 0}, /* pc 1 */
	{nodev, nodev, nordwr, nordwr, noioctl, nulltty, 0}, /* lp 2 */
	{nodev, nodev, nordwr, nordwr, noioctl, nulltty, 0}, /* dc 3 */
	{nodev, nodev, nordwr, nordwr, noioctl, nulltty, 0}, /* dh 4 */
	{nodev, nodev, nordwr, nordwr, noioctl, nulltty, 0}, /* dp 5 */
	{nodev, nodev, nordwr, nordwr, noioctl, nulltty, 0}, /* dj 6 */
	{nodev, nodev, nordwr, nordwr, noioctl, nulltty, 0}, /* dn 7 */
	{nulldev, nulldev, mmread, mmwrite, noioctl, nulltty, 0}, /* mem 8 */
	{nulldev, nulldev, rkread, rkwrite, noioctl, nulltty, 0}, /* rk 9 */
	{nodev, nodev, nordwr, nordwr, noioctl, nulltty, 0}, /* rf 10 */
	{nodev, nodev, nordwr, nordwr, noioctl, nulltty, 0}, /* rp 11 */
	{nodev, nodev, nordwr, nordwr, noioctl, nulltty, 0}, /* tm 12 */
	{nodev, nodev, nordwr, nordwr, noioctl, nulltty, 0}, /* hs 13 */
	{nodev, nodev, nordwr, nordwr, noioctl, nulltty, 0}, /* hp 14 */
	{nodev, nodev, nordwr, nordwr, noioctl, nulltty, 0}, /* ht 15 */
	{nodev, nodev, nordwr, nordwr, noioctl, nulltty, 0}, /* du 16 */
	{syopen, nulldev, syread, sywrite, sysioctl, nulltty, 0}, /* tty 17 */
	{nodev, nodev, nordwr, nordwr, noioctl, nulltty, 0}, /* rl 18 */
	{0}
};

struct	linesw	linesw[] =
{
	{ttyopen, nulltty, ttread, ttwrite, nolioctl, ttyinput,
	    0, 0, ttstart, 0}, /* 0 */
	{0}
};

int	rootdev	= makedev(0, 2);
int	swapdev	= makedev(0, 2);
int	pipedev = makedev(0, 2);
int	nldisp = 1;
daddr_t	swplo	= 32768;
int	nswap	= 1048576;

struct	buf	buf[NBUF];
struct	file	file[NFILE];
struct	inode	inode[NINODE];
struct	proc	proc[NPROC];
struct	text	text[NTEXT];
struct	buf	bfreelist;
struct	acct	acctbuf;
struct	inode	*acctp;
int	buffers[NBUF+1][(BSIZE+BSLOP+63)/64*16];
struct	map	coremap[CMAPSIZ];
struct	map	swapmap[SMAPSIZ];
struct	map	ptmap[PMAPSIZ];
struct	mount	mount[NMOUNT];
struct	callo	callout[NCALL];
struct	cblock	cfree[NCLIST];

unsigned int	corebase, coreoff, coretop = CORETOP;
unsigned int	gicdbase = GICDBASE, giccbase = GICCBASE;

struct	memregion	board_map[] =
{
	BOARD_MAP
	{0, 0, 0, 0}
};

extern int	clkirq, klirq, rkirq;
struct	intr	intrtab[] =
{
	{&clkirq, clock},
	{&klirq, klintr},
	{&rkirq, rkintr},
	{0, 0}
};

void	cninit(void) { klinit(); }
void	bdinit(void) { rkinit(); }
void	clock_ddr_init(void) { DDRINIT; }
void	wdinit(void) { WDINIT; }
