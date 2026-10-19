/*
 * The user structure.
 * One allocated per process.
 * Contains all per process data
 * that doesn't need to be referenced
 * while the process is swapped.
 * The user block is USIZE*4096 bytes
 * long; resides at virtual kernel
 * loc 0xFFE00000; contains the system
 * stack per user; is cross referenced
 * with the proc structure for the
 * same process.
 */

#define	EXCLOSE	01

struct	user
{
	label_t	u_rsav;			/* save info when exchanging stacks */
	int	u_fper;			/* FP error register */
	int	u_fpsaved;		/* FP regs saved for this proc */
	struct {
		int	u_fpsr;		/* FP status register */
		double	u_fpregs[32];	/* FP registers */
	} u_fps;
	char	u_segflg;		/* IO flag: 0:user D; 1:system; 2:user I */
	char	u_error;		/* return error code */
	short	u_uid;			/* effective user id */
	short	u_gid;			/* effective group id */
	short	u_ruid;			/* real user id */
	short	u_rgid;			/* real group id */
	struct proc *u_procp;		/* pointer to proc structure */
	int	*u_ap;			/* pointer to arglist */
	union {				/* syscall return values */
		struct	{
			int	r_val1;
			int	r_val2;
		} u_pair;
		off_t	r_off;
		time_t	r_time;
	} u_r;
#define	r_val1	u_pair.r_val1
#define	r_val2	u_pair.r_val2
	caddr_t	u_base;			/* base address for IO */
	unsigned int u_count;		/* bytes remaining for IO */
	off_t	u_offset;		/* offset in file for IO */
	struct inode *u_cdir;		/* pointer to inode of current directory */
	struct inode *u_rdir;		/* root directory of current process */
	char	u_dbuf[DIRSIZ];		/* current pathname component */
	caddr_t	u_dirp;			/* pathname pointer */
	struct direct u_dent;		/* current directory entry */
	struct inode *u_pdir;		/* inode of parent directory of dirp */
	unsigned u_ptsize, u_pdsize, u_pssize;	/* prototype sizes */
	int	u_pxrw;			/* prototype of text access */
	struct file *u_ofile[NOFILE];	/* pointers to file structures of open files */
	char	u_pofile[NOFILE];	/* per-process flags of open files */
	int	u_arg[5];		/* arguments to current system call */
	unsigned u_tsize;		/* text size (pages) */
	unsigned u_dsize;		/* data size (pages) */
	unsigned u_ssize;		/* stack size (pages) */
	label_t	u_qsav;			/* label variable for quits and interrupts */
	label_t	u_ssav;			/* label variable for swapping */
	int	u_signal[NSIG];		/* disposition of signals */
	time_t	u_utime;		/* this process user time */
	time_t	u_stime;		/* this process system time */
	time_t	u_cutime;		/* sum of childs' utimes */
	time_t	u_cstime;		/* sum of childs' stimes */
	int	*u_ar0;			/* address of users saved R0 */
	struct uprof {			/* profile arguments */
		short	*pr_base;	/* buffer base */
		unsigned pr_size;	/* buffer size */
		unsigned pr_off;	/* pc offset */
		unsigned pr_scale;	/* pc scaling */
	} u_prof;
	char	u_intflg;		/* catch intr from sys */
	char	u_sep;			/* flag for I and D separation */
	struct tty *u_ttyp;		/* controlling tty pointer */
	dev_t	u_ttyd;			/* controlling tty dev */
	struct {			/* header of executable file */
		int	ux_mag;		/* magic number */
		int	ux_x[5];
		unsigned ux_entloc;	/* entry location */
		unsigned ux_phoff;
		int	ux_y[3];
		short	ux_phnum, ux_z[3];
		struct {
			unsigned p_type, p_off, p_addr, p_paddr;
			unsigned p_size, p_msize;
		} ux_ph[2];		/* text and data segments */
	} u_exdata;
#define	ux_tsize	ux_ph[0].p_size	/* text size */
#define	ux_dsize	ux_ph[1].p_size	/* data size */
	char	u_comm[DIRSIZ];
	time_t	u_start;
	char	u_acflag;
	short	u_fpflag;		/* unused now, will be later */
	short	u_cmask;		/* mask for file creation */
	int	u_stack[1];
					/* kernel stack per user
					 * extends from u + USIZE*4096
					 * backward not to reach here
					 */
};

extern struct user u;

/* u_error codes */
#define	EPERM	1
#define	ENOENT	2
#define	ESRCH	3
#define	EINTR	4
#define	EIO	5
#define	ENXIO	6
#define	E2BIG	7
#define	ENOEXEC	8
#define	EBADF	9
#define	ECHILD	10
#define	EAGAIN	11
#define	ENOMEM	12
#define	EACCES	13
#define	EFAULT	14
#define	ENOTBLK	15
#define	EBUSY	16
#define	EEXIST	17
#define	EXDEV	18
#define	ENODEV	19
#define	ENOTDIR	20
#define	EISDIR	21
#define	EINVAL	22
#define	ENFILE	23
#define	EMFILE	24
#define	ENOTTY	25
#define	ETXTBSY	26
#define	EFBIG	27
#define	ENOSPC	28
#define	ESPIPE	29
#define	EROFS	30
#define	EMLINK	31
#define	EPIPE	32
#define	EDOM	33
#define	ERANGE	34
