/* v7 buffer-cache + proc-table storage + stubs for symbols sys/ references. */
#include "../h/param.h"
#include "../h/buf.h"
#include "../h/conf.h"
#include "../h/dir.h"
#include "../h/inode.h"
#include "../h/user.h"
#include "../h/proc.h"
#include "../h/file.h"
#include "../h/filsys.h"
#include "../h/ino.h"
#include "../h/mount.h"
#include "../h/systm.h"
#include "../h/proto.h"
/* per-process user struct (referenced by physio() in dev/bio.c) */
struct user u;
/* head of available-buffer list */
struct buf bfreelist;
/* Major 0 = active block device (mp135 DDR on EVB, virtio-blk on qemu). */
dev_t rootdev = 0;
int nblkdev = 0;	/* binit() counts populated bdevsw[] rows from here */
struct buf buf[NBUF];	/* conf/c.c equivalent until conf/c.c is linked in */
/* Trailing empty row terminates the table. */
#ifdef EVB
extern int mp135_strategy(struct buf *);
extern struct buf mp135_tab;
struct bdevsw bdevsw[2] = {
	{ nulldev, nulldev, mp135_strategy, &mp135_tab },
	{ 0, 0, 0, 0 }
};
#else
extern int virtio_strategy(struct buf *);
extern struct buf virtio_tab;
struct bdevsw bdevsw[2] = {
	{ nulldev, nulldev, virtio_strategy, &virtio_tab },
	{ 0, 0, 0, 0 }
};
#endif
/* UNIBUS map release: no-op on ARM. */
void mapfree(struct buf *bp) { (void)bp; }
/* PDP-11 SPL primitives -- ARM has no PSL_IPL, so all no-ops. */
int spl0(void) { return 0; }
int spl6(void) { return 0; }
void splx(int s) { (void)s; }
struct inode inode[NINODE];
/* prele/plock: cooperative scheduling -- never sleep, just flip ILOCK. */
void prele(struct inode *ip)
{ if(ip) ip->i_flag &= ~(ILOCK|IWANT); }
void plock(struct inode *ip)
{ if(ip) { ip->i_flag &= ~IWANT; ip->i_flag |= ILOCK; } }
int fubyte(caddr_t addr) { return *(unsigned char *)addr; }
int fuibyte(caddr_t addr) { return *(unsigned char *)addr; }
int subyte(caddr_t addr, char c) { *(unsigned char *)addr = c; return 0; }
int suibyte(caddr_t addr, char c) { *(unsigned char *)addr = c; return 0; }
/* bcopy/nulldev/nodev for v7 alloc.c without pulling in subr.c. */
void bcopy(char *f, char *t, unsigned int n) { while(n--) *t++ = *f++; }
int nulldev(void) { return 0; }
int nodev(void) { return -1; }
/* USERBASE identity-mapped: copy{in,out,iin,iout} = memcpy (iin/iout unreachable). */
int copyin(caddr_t f, caddr_t t, unsigned int n)   { while(n--) *t++ = *f++; return 0; }
int copyout(caddr_t f, caddr_t t, unsigned int n)  { while(n--) *t++ = *f++; return 0; }
int copyiin(caddr_t f, caddr_t t, unsigned int n)  { while(n--) *t++ = *f++; return 0; }
int copyiout(caddr_t f, caddr_t t, unsigned int n) { while(n--) *t++ = *f++; return 0; }
int spl1(void) { return 0; }
int spl5(void) { return 0; }
int spl7(void) { return 0; }
void display(void) {}
/* Per-proc stubs for sig.c/sys1.c paths we don't exercise yet. */
void savfp(void *fp) { (void)fp; }
void sendsig(caddr_t p, int n) { (void)p; (void)n; }
void copyseg(int from, int to) { (void)from; (void)to; }
void clearseg(int a) { (void)a; }
/* fu*word / su*word -- no live caller; nodev-style stubs. */
int fuiword(caddr_t addr) { (void)addr; return -1; }
int fuword(caddr_t addr) { (void)addr; return -1; }
int suiword(caddr_t addr, int v) { (void)addr; (void)v; return -1; }
int suword(caddr_t addr, int v) { (void)addr; (void)v; return -1; }
char regloc[9];
void addupc(void) {}
caddr_t waitloc;
/* Per-iteration barrier for v7_pause_call's busy spin.  Cross-TU call
 * defeats register caching of pp->p_sig; the UART write advances qemu's
 * virtual timer (WFI/PL011 reads empirically don't). */
void pause_spin_barrier(void)
{
	putchar('\b');
	__asm__ volatile("dmb ish" ::: "memory");
}
/* idle reached = scheduler bug (no runnable peers + v7 sleep()). */
void idle(void) { panic("idle reached"); }
struct inode *acctp;
struct acct {
	char ac_comm[10];
	long ac_utime, ac_stime, ac_etime;
	time_t ac_btime;
	short ac_uid, ac_gid, ac_mem, ac_io;
	dev_t ac_tty;
	char ac_flag;
} acctbuf;
extern int uchar(void);
extern struct inode *namei(int (*func)(void), int flag);
extern struct inode *iget(dev_t dev, ino_t ino);
extern void iput(struct inode *ip);
/* Path -> inum bridge over v7's namei.  First call iget's rootdir +
 * u.u_cdir as separate refs (sys/main.c) so child chdir-iput doesn't
 * drop rootdir to 0 and break later absolute-path walks. */
ino_t v7_namei_inum(char *path)
{
	struct inode *ip;
	ino_t inum;
	if(rootdir == NULL) {
		rootdir = iget(rootdev, (ino_t)ROOTINO);
		if(rootdir == NULL) return (ino_t)0;
		rootdir->i_flag &= ~ILOCK;
		u.u_cdir = iget(rootdev, (ino_t)ROOTINO);
		if(u.u_cdir == NULL) return (ino_t)0;
		u.u_cdir->i_flag &= ~ILOCK;
	}
	u.u_dirp = (caddr_t)path;
	u.u_error = 0;
	u.u_segflg = 1;
	if((ip = namei(uchar, 0)) == NULL) return (ino_t)0;
	inum = ip->i_number;
	iput(ip);
	return inum;
}
/* Populate mount[0] for rootdev (idempotent; mirrors sys3.c::smount). */
int v7_mount_init(void)
{
	struct buf *bp, *mb;
	struct filsys *fp;
	if(mount[0].m_bufp != NULL) return 0;
	if(rootdir == NULL) return -1;	/* caller must seed rootdir first */
	bp = bread(rootdev, (daddr_t)SUPERB);
	if(bp->b_flags & B_ERROR) { brelse(bp); return -1; }
	mb = geteblk();
	bcopy((char *)bp->b_un.b_addr, (char *)mb->b_un.b_addr,
	    (unsigned int)BSIZE);
	fp = mb->b_un.b_filsys;
	fp->s_ilock = fp->s_flock = fp->s_ronly = 0;
	brelse(bp);
	mount[0].m_dev = rootdev;
	mount[0].m_bufp = mb;
	mount[0].m_inodp = rootdir;
	return 0;
}
/* Bridge armboot's addr[NADDR] <-> v7's i_un.i_addr[] (loop-copy, layout-agnostic). */
void v7_inode_pack_addr(struct inode *ip, unsigned int *addrs)
{
	if(ip && addrs)
		for(int i = 0; i < NADDR; i++)
			ip->i_un.i_addr[i] = (daddr_t)addrs[i];
}
void v7_inode_unpack_addr(struct inode *ip, unsigned int *addrs)
{
	if(ip && addrs)
		for(int i = 0; i < NADDR; i++)
			addrs[i] = (unsigned int)ip->i_un.i_addr[i];
}
