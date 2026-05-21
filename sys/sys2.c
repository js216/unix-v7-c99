#include "../h/param.h"
#include "../h/systm.h"
#include "../h/dir.h"
#include "../h/user.h"
#include "../h/file.h"
#include "../h/inode.h"

/* getf/namei/uchar/maknode/closef/access/readi/writei/plock/prele/iput/suser
 * come from h/systm.h. */
extern void readp(struct file *);
extern void writep(struct file *);
extern void wdir(struct inode *);

void rdwr(int mode);

/* v7's write(), open(), creat() and open1() are gone -- on this port
 * sys_{write,open,creat}_v7 in arch/armboot.c implement those syscalls
 * directly (pipe/console fast paths + kopen/kcreat for the file tree),
 * so the v7 entry points were linker-dead.  read() is still routed
 * here via v7_read_call. */

/*
 * read system call
 */
void
read(void)
{
	rdwr(FREAD);
}

/*
 * common code for read and write calls:
 * check permissions, set base, count, and offset,
 * and switch out to readi, writei, or pipe code.
 */
void
rdwr(register int mode)
{
	register struct file *fp;
	register struct inode *ip;
	register struct a {
		int	fdes;
		char	*cbuf;
		unsigned count;
	} *uap;

	uap = (struct a *)u.u_ap;
	fp = getf(uap->fdes);
	if(fp == NULL)
		return;
	if((fp->f_flag&mode) == 0) {
		u.u_error = EBADF;
		return;
	}
	u.u_base = (caddr_t)uap->cbuf;
	u.u_count = uap->count;
	u.u_segflg = 0;
	if((fp->f_flag&FPIPE) != 0) {
		if(mode == FREAD)
			readp(fp);
		else
			writep(fp);
	} else {
		ip = fp->f_inode;
		u.u_offset = fp->f_un.f_offset;
		if((ip->i_mode&(IFCHR&IFBLK)) == 0)
			plock(ip);
		if(mode == FREAD)
			readi(ip);
		else
			writei(ip);
		if((ip->i_mode&(IFCHR&IFBLK)) == 0)
			prele(ip);
		fp->f_un.f_offset += uap->count-u.u_count;
	}
	u.u_r.r_val1 = uap->count-u.u_count;
}

/*
 * close system call
 */
void
close(void)
{
	register struct file *fp;
	register struct a {
		int	fdes;
	} *uap;

	uap = (struct a *)u.u_ap;
	fp = getf(uap->fdes);
	if(fp == NULL)
		return;
	u.u_ofile[uap->fdes] = NULL;
	closef(fp);
}

/*
 * seek system call
 */
void
seek(void)
{
	register struct file *fp;
	register struct a {
		int	fdes;
		off_t	off;
		int	sbase;
	} *uap;

	uap = (struct a *)u.u_ap;
	fp = getf(uap->fdes);
	if(fp == NULL)
		return;
	if(fp->f_flag&FPIPE) {
		u.u_error = ESPIPE;
		return;
	}
	if(uap->sbase == 1)
		uap->off += fp->f_un.f_offset;
	else if(uap->sbase == 2)
		uap->off += fp->f_inode->i_size;
	fp->f_un.f_offset = uap->off;
	u.u_r.r_off = uap->off;
}

/*
 * link system call
 */
void
link(void)
{
	register struct inode *ip, *xp;
	register struct a {
		char	*target;
		char	*linkname;
	} *uap;

	uap = (struct a *)u.u_ap;
	ip = namei(uchar, 0);
	if(ip == NULL)
		return;
	if((ip->i_mode&IFMT)==IFDIR && !suser())
		goto out;
	/*
	 * Unlock to avoid possibly hanging the namei.
	 * Sadly, this means races. (Suppose someone
	 * deletes the file in the meantime?)
	 * Nor can it be locked again later
	 * because then there will be deadly
	 * embraces.
	 */
	prele(ip);
	u.u_dirp = (caddr_t)uap->linkname;
	xp = namei(uchar, 1);
	if(xp != NULL) {
		u.u_error = EEXIST;
		iput(xp);
		goto out;
	}
	if (u.u_error)
		goto out;
	if(u.u_pdir->i_dev != ip->i_dev) {
		iput(u.u_pdir);
		u.u_error = EXDEV;
		goto out;
	}
	wdir(ip);
	if (u.u_error==0) {
		ip->i_nlink++;
		ip->i_flag |= ICHG;
	}

out:
	iput(ip);
}

/*
 * mknod system call
 */
void
mknod(void)
{
	register struct inode *ip;
	register struct a {
		char	*fname;
		int	fmode;
		int	dev;
	} *uap;

	uap = (struct a *)u.u_ap;
	if(suser()) {
		ip = namei(uchar, 1);
		if(ip != NULL) {
			u.u_error = EEXIST;
			goto out;
		}
	}
	if(u.u_error)
		return;
	ip = maknode(uap->fmode);
	if (ip == NULL)
		return;
	ip->i_un.i_rdev = (dev_t)uap->dev;

out:
	iput(ip);
}

/*
 * access system call
 */
void
saccess(void)
{
	register int svuid, svgid;
	register struct inode *ip;
	register struct a {
		char	*fname;
		int	fmode;
	} *uap;

	uap = (struct a *)u.u_ap;
	svuid = u.u_uid;
	svgid = u.u_gid;
	u.u_uid = u.u_ruid;
	u.u_gid = u.u_rgid;
	ip = namei(uchar, 0);
	if (ip != NULL) {
		if (uap->fmode&(IREAD>>6))
			access(ip, IREAD);
		if (uap->fmode&(IWRITE>>6))
			access(ip, IWRITE);
		if (uap->fmode&(IEXEC>>6))
			access(ip, IEXEC);
		iput(ip);
	}
	u.u_uid = svuid;
	u.u_gid = svgid;
}
