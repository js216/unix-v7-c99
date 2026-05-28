#include "../h/param.h"
#include "../h/systm.h"
#include "../h/dir.h"
#include "../h/user.h"
#include "../h/filsys.h"
#include "../h/file.h"
#include "../h/conf.h"
#include "../h/inode.h"
#include "../h/mount.h"
#include "../h/acct.h"
void wakeup(caddr_t chan);
void printf(char *fmt, ...);
void fstat(void);
void close(void);
void dup(void);
void seek(void);
void read(void);

/*
 * Convert a user supplied
 * file descriptor into a pointer
 * to a file structure.
 * Only task is to check range
 * of the descriptor.
 */
struct file *
getf(register int f)
{
	register struct file *fp;

	if(0 <= f && f < NOFILE) {
		fp = u.u_ofile[f];
		if(fp != NULL)
			return(fp);
	}
	u.u_error = EBADF;
	return(NULL);
}

/*
 * Internal form of close.
 * Decrement reference count on
 * file structure.
 * Also make sure the pipe protocol
 * does not constipate.
 *
 * Decrement reference count on the inode following
 * removal to the referencing file structure.
 * Call device handler on last close.
 */
void
closef(register struct file *fp)
{
	register struct inode *ip;
	int flag, mode;
	dev_t dev;
	register int (*cfunc)();
	struct chan *cp;

	if(fp == NULL)
		return;
	if (fp->f_count > 1) {
		fp->f_count--;
		return;
	}
	ip = fp->f_inode;
	flag = fp->f_flag;
	cp = fp->f_un.f_chan;
	dev = (dev_t)ip->i_un.i_rdev;
	mode = ip->i_mode;

	plock(ip);
	fp->f_count = 0;
	if(flag & FPIPE) {
		register struct file *ofp;
		ip->i_mode &= ~(IREAD|IWRITE);
		wakeup((caddr_t)ip+1);
		wakeup((caddr_t)ip+2);
		for(ofp = file; ofp < &file[NFILE]; ofp++)
			if(ofp->f_count && ofp->f_inode == ip &&
			   (ofp->f_flag&FPIPE)) {
				if(ip->i_count > 1)
					ip->i_count--;
				prele(ip);
				return;
			}
		if((flag & FWRITE) && ip->i_size != 0) {
			prele(ip);
			return;
		}
	}
	iput(ip);

	switch(mode&IFMT) {

	case IFCHR:
	case IFMPC:
		cfunc = cdevsw[major(dev)].d_close;
		break;

	case IFBLK:
	case IFMPB:
		cfunc = bdevsw[major(dev)].d_close;
		break;
	default:
		return;
	}

	if ((flag & FMP) == 0)
		for(fp=file; fp < &file[NFILE]; fp++)
			if (fp->f_count && fp->f_inode==ip)
				return;
	(*cfunc)(dev, flag, cp);
}

/*
 * openi called to allow handler
 * of special files to initialize and
 * validate before actual IO.
 */
void
openi(register struct inode *ip, int rw)
{
	dev_t dev;
	register unsigned int maj;

	dev = (dev_t)ip->i_un.i_rdev;
	maj = major(dev);
	switch(ip->i_mode&IFMT) {

	case IFCHR:
	case IFMPC:
		if(maj >= (unsigned int)nchrdev)
			goto bad;
		(*cdevsw[maj].d_open)(dev, rw);
		break;

	case IFBLK:
	case IFMPB:
		if(maj >= (unsigned int)nblkdev)
			goto bad;
		(*bdevsw[maj].d_open)(dev, rw);
	}
	return;

bad:
	u.u_error = ENXIO;
}

/*
 * Check mode permission on inode pointer.
 * Mode is READ, WRITE or EXEC.
 * In the case of WRITE, the
 * read-only status of the file
 * system is checked.
 * Also in WRITE, prototype text
 * segments cannot be written.
 * The mode is shifted to select
 * the owner/group/other fields.
 * The super user is granted all
 * permissions.
 */
int
access(register struct inode *ip, int mode)
{
	register int m;

	m = mode;
	if(m == IWRITE) {
		if(getfs(ip->i_dev)->s_ronly != 0) {
			u.u_error = EROFS;
			return(1);
		}
		if (ip->i_flag&ITEXT)		/* try to free text */
			xrele(ip);
		if(ip->i_flag & ITEXT) {
			u.u_error = ETXTBSY;
			return(1);
		}
	}
	if(u.u_uid == 0)
		return(0);
	if(u.u_uid != ip->i_uid) {
		m >>= 3;
		if(u.u_gid != ip->i_gid)
			m >>= 3;
	}
	if((ip->i_mode&m) != 0)
		return(0);

	u.u_error = EACCES;
	return(1);
}

/*
 * Look up a pathname and test if
 * the resultant inode is owned by the
 * current user.
 * If not, try for super-user.
 * If permission is granted,
 * return inode pointer.
 */
struct inode *
owner(void)
{
	register struct inode *ip;

	ip = namei(uchar, 0);
	if(ip == NULL)
		return(NULL);
	if(u.u_uid == ip->i_uid)
		return(ip);
	if(suser())
		return(ip);
	iput(ip);
	return(NULL);
}

/*
 * Test if the current user is the
 * super user.
 */
int
suser(void)
{

	if(u.u_uid == 0) {
		u.u_acflag |= ASU;
		return(1);
	}
	u.u_error = EPERM;
	return(0);
}

/*
 * Allocate a user file descriptor.
 */
int
ufalloc(void)
{
	register int i;

	for(i=0; i<NOFILE; i++)
		if(u.u_ofile[i] == NULL) {
			u.u_r.r_val1 = i;
			u.u_pofile[i] = 0;
			return(i);
		}
	u.u_error = EMFILE;
	return(-1);
}

/*
 * Allocate a user file descriptor
 * and a file structure.
 * Initialize the descriptor
 * to point at the file structure.
 *
 * no file -- if there are no available
 * 	file structures.
 */
struct file *
falloc(void)
{
	register struct file *fp;
	register int i;

	i = ufalloc();
	if(i < 0)
		return(NULL);
	for(fp = &file[0]; fp < &file[NFILE]; fp++)
		if(fp->f_count == 0) {
			u.u_ofile[i] = fp;
			fp->f_count++;
			fp->f_un.f_offset = 0;
			return(fp);
		}
	printf("no file\n");
	u.u_error = ENFILE;
	return(NULL);
}
extern dev_t rootdev;
struct inode *iget(dev_t dev, ino_t ino);
void iput(struct inode *ip);
void bcopy(char *from, char *to, unsigned int n);
void v7_inode_pack_addr(struct inode *ip, unsigned int *addrs);
void v7_inode_unpack_addr(struct inode *ip, unsigned int *addrs);
void
v7_ofile_clear(int fd)
{
	struct file *fp;
	if(fd < 0 || fd >= NOFILE) return;
	if((fp = u.u_ofile[fd]) == NULL) return;
	u.u_ofile[fd] = NULL;
	u.u_pofile[fd] = 0;
	closef(fp);
}
void
v7_ofile_set(int fd, ino_t ino, int flag)
{
	struct inode *ip;
	struct file *fp;
	if(fd < 0 || fd >= NOFILE) return;
	if(u.u_ofile[fd]) v7_ofile_clear(fd);
	if((ip = iget(rootdev, ino)) == NULL) return;
	ip->i_flag &= ~ILOCK;
	for(fp = &file[0]; fp < &file[NFILE]; fp++)
		if(fp->f_count == 0) {
			fp->f_count = 1;
			fp->f_flag = (char)flag;
			fp->f_inode = ip;
			fp->f_un.f_offset = 0;
			u.u_ofile[fd] = fp;
			u.u_pofile[fd] = 0;
			return;
		}
	iput(ip);
}
void
v7_ofile_dup(int from, int to)
{
	struct file *fp;
	if(from < 0 || from >= NOFILE || to < 0 || to >= NOFILE) return;
	fp = u.u_ofile[from];
	if(fp == NULL) {
		if(u.u_ofile[to]) v7_ofile_clear(to);
		return;
	}
	if(u.u_ofile[to] == fp) return;
	if(u.u_ofile[to]) v7_ofile_clear(to);
	u.u_ofile[to] = fp;
	u.u_pofile[to] = 0;
	fp->f_count++;
}
void v7_ofile_save(void *buf)
{ bcopy((char *)u.u_ofile, (char *)buf, sizeof(u.u_ofile)); }
void v7_ofile_restore(void *buf)
{ bcopy((char *)buf, (char *)u.u_ofile, sizeof(u.u_ofile)); }
void v7_pofile_save(void *buf)
{ bcopy((char *)u.u_pofile, (char *)buf, sizeof(u.u_pofile)); }
void v7_pofile_restore(void *buf)
{ bcopy((char *)buf, (char *)u.u_pofile, sizeof(u.u_pofile)); }
void v7_pofile_excl_set(int fd)
{ if(fd >= 0 && fd < NOFILE) u.u_pofile[fd] |= EXCLOSE; }
void v7_pofile_excl_clear(int fd)
{ if(fd >= 0 && fd < NOFILE) u.u_pofile[fd] &= (char)~EXCLOSE; }
void
v7_ofile_fork_bump(void)
{
	int i;
	for(i = 0; i < NOFILE; i++)
		if(u.u_ofile[i])
			u.u_ofile[i]->f_count++;
}
void
v7_ofile_drop_all(void)
{
	int i;
	for(i = 0; i < NOFILE; i++)
		if(u.u_ofile[i])
			v7_ofile_clear(i);
}
static int
v7_fd_prep(int fd, int *args)
{
	if(fd < 0 || fd >= NOFILE || u.u_ofile[fd] == NULL) return(-1);
	u.u_ap = args;
	u.u_segflg = 1;
	u.u_error = 0;
	u.u_r.r_val1 = u.u_r.r_val2 = 0;
	return(0);
}
int
v7_u_error_get(void)
{
	return((int)u.u_error);
}
void
v7_inode_drop(void *p)
{
	struct inode *ip = (struct inode *)p;
	if(ip) iput(ip);
}
int
v7_fstat_call(int fd, void *ubuf)
{
	int args[2] = { fd, (int)(long)ubuf };
	if(v7_fd_prep(fd, args) < 0) return(-1);
	fstat();
	return((int)u.u_error);
}
static struct file *
fd_file(int fd)
{
	return((fd < 0 || fd >= NOFILE) ? NULL : u.u_ofile[fd]);
}
long
v7_get_offset(int fd)
{
	struct file *fp = fd_file(fd);
	return(fp ? (long)fp->f_un.f_offset : 0);
}
int
v7_ofile_isset(int fd)
{
	return(fd_file(fd) != NULL);
}
void
v7_set_offset(int fd, long off)
{
	struct file *fp = fd_file(fd);
	if(fp) fp->f_un.f_offset = (off_t)off;
}
static struct inode *
fd_inode(int fd)
{
	struct file *fp;
	if(fd < 0 || fd >= NOFILE) return(NULL);
	fp = u.u_ofile[fd];
	return(fp ? fp->f_inode : NULL);
}
void
v7_inode_refresh(int fd, unsigned int size, unsigned int *addrs)
{
	struct inode *ip = fd_inode(fd);
	if(ip == NULL) return;
	ip->i_size = (off_t)size;
	v7_inode_pack_addr(ip, addrs);
}
void
v7_inode_mark_dirty(int fd)
{
	struct inode *ip = fd_inode(fd);
	if(ip == NULL) return;
	ip->i_flag |= IUPD | ICHG;
}
void
v7_inode_writeback(int fd, unsigned int *size_out, unsigned int *addrs_out)
{
	struct inode *ip = fd_inode(fd);
	if(ip == NULL) return;
	*size_out = (unsigned int)ip->i_size;
	v7_inode_unpack_addr(ip, addrs_out);
	ip->i_flag |= IUPD | ICHG;
}
