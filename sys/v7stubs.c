/* v7 buffer-cache + proc-table storage + stubs for symbols sys/ references. */
#include "../h/param.h"
#include "../h/acct.h"
#include "../h/buf.h"
#include "../h/conf.h"
#include "../h/dir.h"
#include "../h/inode.h"
#include "../h/user.h"
#include "../h/filsys.h"
#include "../h/mount.h"
#include "../h/systm.h"
#include "../h/proto.h"
#include "../h/v7_bridge.h"
/* per-process user struct -- all v7 sys globals land here. */
struct user u;
/* head of available-buffer list */
struct buf bfreelist;
struct buf buf[NBUF];	/* v7 conf/c.c provided this on PDP-11; lives here on ARM */
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
/* fuibyte/suibyte (user I-space) gone -- this port never sets
 * u.u_segflg to 2, so subr.c::passc/cpass never select them. */
int fubyte(caddr_t addr) { return *(unsigned char *)addr; }
int subyte(caddr_t addr, char c) { *(unsigned char *)addr = c; return 0; }
/* Byte-loop bcopy tuned for AAPCS softfloat -- replaces v7's
 * PDP-11-shaped subr.c bcopy (deleted earlier). */
void bcopy(char *f, char *t, unsigned int n) { while(n--) *t++ = *f++; }
/* USERBASE identity-mapped: copyin/copyout = memcpy.  v7's copyiin/
 * copyiout (user I-space) are gone -- rdwri.c never selects them. */
int copyin(caddr_t f, caddr_t t, unsigned int n)   { while(n--) *t++ = *f++; return 0; }
int copyout(caddr_t f, caddr_t t, unsigned int n)  { while(n--) *t++ = *f++; return 0; }
int spl1(void) { return 0; }
int spl7(void) { return 0; }
/* copyseg/clearseg called from sys/sys1.c::sbreak and sys/slp.c::expand
 * -- no-op on this port because every proc is permanently resident in
 * RAM and userspace is identity-mapped. */
void copyseg(int from, int to) { (void)from; (void)to; }
void clearseg(int a) { (void)a; }
/* v7's fuword/suword (int-aligned user->kernel xfer) are gone -- no
 * remaining kernel C code calls them; the syscall path uses copyin/copyout. */
char regloc[9];
void addupc(caddr_t pc, void *prof, int inc) { (void)pc; (void)prof; (void)inc; }
caddr_t waitloc;
/* Per-iteration barrier for v7_pause_call's busy spin.  Cross-TU call
 * defeats register caching of pp->p_sig; the UART write advances qemu's
 * virtual timer (WFI/PL011 reads empirically don't). */
void pause_spin_barrier(void)
{
	putchar('\b');
	__asm__ volatile("dmb ish" ::: "memory");
}
struct inode *acctp;
struct acct acctbuf;
/* uchar/namei/iget/iput come from h/systm.h. */
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
	/* Seed kernel `time` from the superblock's last-modified stamp,
	 * matching v7 iinit().  stime(2) can override later. */
	time = fp->s_time;
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
