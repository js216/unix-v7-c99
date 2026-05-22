#include "../h/param.h"
#include "../h/systm.h"
#include "../h/inode.h"
#include "../h/mount.h"
#include "../h/dir.h"
#include "../h/user.h"
#include "../h/buf.h"
struct map;
struct buf;
extern int malloc(struct map *mp, int size);
extern void mfree(struct map *mp, int size, int a);
extern void printf(char *fmt, ...);
extern void panic(char *s);
extern void prdev(char *str, dev_t dev);
extern void putchar(char c);
extern int getchar(void);
extern void trap(int *frame);
extern void panictrap(void);
extern void run_user(unsigned int pc, unsigned int sp);
extern void mmu_on(unsigned int ttb);
extern void dmbsy(void);
extern void mmuinit(void);
extern void startup(void);
extern void armboot(void);
extern void armboot_setrun(int pid);
extern void armboot_swtch(void);
extern int save(int *lp);
extern void resume(int addr, int *lp);
extern struct buf *bread(dev_t dev, daddr_t blkno);
extern struct buf *breada(dev_t dev, daddr_t blkno, daddr_t rablkno);
extern void bwrite(struct buf *bp);
extern void bdwrite(struct buf *bp);
extern void brelse(struct buf *bp);
extern int incore(dev_t dev, daddr_t blkno);
extern struct buf *getblk(dev_t dev, daddr_t blkno);
extern struct buf *geteblk(void);
extern void iowait(struct buf *bp);
extern void notavail(struct buf *bp);
extern void iodone(struct buf *bp);
extern void clrbuf(struct buf *bp);
extern void swap(daddr_t blkno, int coreaddr, int count, int rdflg);
extern void bflush(dev_t dev);
extern void geterror(struct buf *bp);
extern void wakeup(caddr_t chan);
extern void sleep(caddr_t chan, int pri);
extern int spl0(void);
extern int spl1(void);
extern int spl6(void);
extern int spl7(void);
extern void splx(int s);
extern void binit(void);
extern void copyseg(int from, int to);
extern void clearseg(int a);
extern dev_t rootdev;
extern int virtio_strategy(struct buf *bp);
extern void virtio_init(void);

/* bread/brelse come from local declarations.
 * iget/iput/plock/access/bcopy/bmap/fubyte come from h/systm.h. */

/*
 * Convert a pathname into a pointer to
 * an inode. Note that the inode is locked.
 *
 * func = function called to get next char of name
 *	&uchar if name is in user space
 *	&schar if name is in system space
 * flag = 0 if name is sought
 *	1 if name is to be created
 *	2 if name is to be deleted
 */
struct inode *
namei(int (*func)(void), int flag)
{
	register struct inode *dp;
	register int c;
	register char *cp;
	struct buf *bp;
	int i;
	dev_t d;
	off_t eo;

	/*
	 * If name starts with '/' start from
	 * root; otherwise start from current dir.
	 */

	dp = u.u_cdir;
	if((c=(*func)()) == '/')
		if ((dp = u.u_rdir) == NULL)
			dp = rootdir;
	iget(dp->i_dev, dp->i_number);
	while(c == '/')
		c = (*func)();
	if(c == '\0' && flag != 0)
		u.u_error = ENOENT;

cloop:
	/*
	 * Here dp contains pointer
	 * to last component matched.
	 */

	if(u.u_error)
		goto out;
	if(c == '\0')
		return(dp);

	/*
	 * If there is another component,
	 * Gather up name into
	 * users' dir buffer.
	 */

	cp = &u.u_dbuf[0];
	while (c != '/' && c != '\0' && u.u_error == 0 ) {
		if(cp < &u.u_dbuf[DIRSIZ])
			*cp++ = c;
		c = (*func)();
	}
	while(cp < &u.u_dbuf[DIRSIZ])
		*cp++ = '\0';
	while(c == '/')
		c = (*func)();
	/* v7's `path!subpath` mpx multiplexor lookup is gone -- mpxip was
	 * never assigned on this port, so the branch was unreachable. */

seloop:
	/*
	 * dp must be a directory and
	 * must have X permission.
	 */

	if((dp->i_mode&IFMT) != IFDIR)
		u.u_error = ENOTDIR;
	access(dp, IEXEC);
	if(u.u_error)
		goto out;

	/*
	 * set up to search a directory
	 */
	u.u_offset = 0;
	u.u_segflg = 1;
	eo = 0;
	bp = NULL;

eloop:

	/*
	 * If at the end of the directory,
	 * the search failed. Report what
	 * is appropriate as per flag.
	 */

	if(u.u_offset >= dp->i_size) {
		if(bp != NULL)
			brelse(bp);
		if(flag==1 && c=='\0') {
			if(access(dp, IWRITE))
				goto out;
			u.u_pdir = dp;
			if(eo)
				u.u_offset = eo-sizeof(struct direct);
			else
				dp->i_flag |= IUPD|ICHG;
			return(NULL);
		}
		u.u_error = ENOENT;
		goto out;
	}

	/*
	 * If offset is on a block boundary,
	 * read the next directory block.
	 * Release previous if it exists.
	 */

	if((u.u_offset&BMASK) == 0) {
		if(bp != NULL)
			brelse(bp);
		bp = bread(dp->i_dev,
			bmap(dp, (daddr_t)(u.u_offset>>BSHIFT), B_READ));
		if (bp->b_flags & B_ERROR) {
			brelse(bp);
			goto out;
		}
	}

	/*
	 * Note first empty directory slot
	 * in eo for possible creat.
	 * String compare the directory entry
	 * and the current component.
	 * If they do not match, go back to eloop.
	 */

	bcopy(bp->b_un.b_addr+(u.u_offset&BMASK), (caddr_t)&u.u_dent,
		sizeof(struct direct));
	u.u_offset += sizeof(struct direct);
	if(u.u_dent.d_ino == 0) {
		if(eo == 0)
			eo = u.u_offset;
		goto eloop;
	}
	for(i=0; i<DIRSIZ; i++)
		if(u.u_dbuf[i] != u.u_dent.d_name[i])
			goto eloop;

	/*
	 * Here a component matched in a directory.
	 * If there is more pathname, go back to
	 * cloop, otherwise return.
	 */

	if(bp != NULL)
		brelse(bp);
	if(flag==2 && c=='\0') {
		if(access(dp, IWRITE))
			goto out;
		return(dp);
	}
	d = dp->i_dev;
	if(u.u_dent.d_ino == ROOTINO)
	if(dp->i_number == ROOTINO)
	if(u.u_dent.d_name[1] == '.')
		for(i=1; i<NMOUNT; i++)
			if(mount[i].m_bufp != NULL)
			if(mount[i].m_dev == d) {
				iput(dp);
				dp = mount[i].m_inodp;
				dp->i_count++;
				plock(dp);
				goto seloop;
			}
	iput(dp);
	dp = iget(d, u.u_dent.d_ino);
	if(dp == NULL)
		return(NULL);
	goto cloop;

out:
	iput(dp);
	return(NULL);
}

/* schar() (kernel-side name-fetcher passed to namei) was only used by
 * sys/sig.c::core() which is gone on this port; uchar() remains for the
 * user-space namei path. */

/*
 * Return the next character from the
 * user string pointed at by dirp.
 */
int
uchar(void)
{
	register int c;

	c = fubyte(u.u_dirp++);
	if(c == -1)
		u.u_error = EFAULT;
	return(c);
}
