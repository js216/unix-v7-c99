#include "../h/param.h"
#include "../h/systm.h"
#include "../h/dir.h"
#include "../h/user.h"
#include "../h/inode.h"
#include "../h/file.h"
#include "../h/proto.h"

/* readi/writei/plock/prele/psignal/min come from h/systm.h.
 * sleep/wakeup come from h/proto.h. */

/*
 * Max allowable buffering per pipe.
 * This is also the max size of the
 * file created to implement the pipe.
 * If this size is bigger than 5120,
 * pipes will be implemented with large
 * files, which is probably not good.
 */
#define	PIPSIZ	4096

/* v7's pipe(2) implementation (allocate inode + two file structs + wire
 * FREAD/FWRITE) is gone -- arch/arm.c::sys_pipe maintains its own
 * pipes[NPIPES] table that doesn't touch the v7 inode[]/file[] arrays.
 * readp() and writep() are still kept because v7's read(2)/write(2)
 * fast path on FPIPE-flagged file structs lands here, even though new
 * pipe creation no longer creates such structs in this port. */

/*
 * Read call directed to a pipe.
 */
void
readp(register struct file *fp)
{
	register struct inode *ip;

	ip = fp->f_inode;

loop:
	/*
	 * Very conservative locking.
	 */

	plock(ip);
	/*
	 * If nothing in the pipe, wait.
	 */
	if (ip->i_size == 0) {
		/*
		 * If there are not both reader and
		 * writer active, return without
		 * satisfying read.
		 */
		prele(ip);
		if(ip->i_count < 2)
			return;
		ip->i_mode |= IREAD;
		sleep((caddr_t)ip+2, PPIPE);
		goto loop;
	}

	/*
	 * Read and return
	 */

	u.u_offset = fp->f_un.f_offset;
	readi(ip);
	fp->f_un.f_offset = u.u_offset;
	/*
	 * If reader has caught up with writer, reset
	 * offset and size to 0.
	 */
	if (fp->f_un.f_offset == ip->i_size) {
		fp->f_un.f_offset = 0;
		ip->i_size = 0;
		if(ip->i_mode & IWRITE) {
			ip->i_mode &= ~IWRITE;
			wakeup((caddr_t)ip+1);
		}
	}
	prele(ip);
}

/*
 * Write call directed to a pipe.
 */
void
writep(register struct file *fp)
{
	register int c;
	register struct inode *ip;

	ip = fp->f_inode;
	c = u.u_count;

loop:

	/*
	 * If all done, return.
	 */

	plock(ip);
	if(c == 0) {
		prele(ip);
		u.u_count = 0;
		return;
	}

	/*
	 * If there are not both read and
	 * write sides of the pipe active,
	 * return error and signal too.
	 */

	if(ip->i_count < 2) {
		prele(ip);
		u.u_error = EPIPE;
		psignal(u.u_procp, SIGPIPE);
		return;
	}

	/*
	 * If the pipe is full,
	 * wait for reads to deplete
	 * and truncate it.
	 */

	if(ip->i_size >= PIPSIZ) {
		ip->i_mode |= IWRITE;
		prele(ip);
		sleep((caddr_t)ip+1, PPIPE);
		goto loop;
	}

	/*
	 * Write what is possible and
	 * loop back.
	 * If writing less than PIPSIZ, it always goes.
	 * One can therefore get a file > PIPSIZ if write
	 * sizes do not divide PIPSIZ.
	 */

	u.u_offset = ip->i_size;
	u.u_count = min((unsigned)c, (unsigned)PIPSIZ);
	c -= u.u_count;
	writei(ip);
	prele(ip);
	if(ip->i_mode&IREAD) {
		ip->i_mode &= ~IREAD;
		wakeup((caddr_t)ip+2);
	}
	goto loop;
}

/* v7's plock/prele are in sys/v7stubs.c -- cooperative-scheduling
 * variants that just flip ILOCK without ever sleeping, since the ARM
 * port runs without the v7 sleep()/wakeup() handoff path. */
