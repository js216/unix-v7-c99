/*
 * tunable variables
 */

#define	NBUF	64		/* size of buffer cache (matches kernel-side
				 * h/param.h's bumped value). */
#define	NINODE	200		/* number of in core inodes */
#define	NFILE	175		/* number of in core file structures */
#define	NMOUNT	8		/* number of mountable file systems */
#define	MAXMEM	(64*32)		/* max core per process - first # is Kw */
/* MAXUPRC, SSIZE, NCARGS are gone -- see kernel-side h/param.h. */
#define	NOFILE	20		/* max open files per process */
#define	CMAPSIZ	50		/* size of core allocation area */
#define	SMAPSIZ	50		/* size of swap allocation area */
#define	NPROC	150		/* max number of processes */
#define	NTEXT	40		/* max number of pure texts */
#define	HZ	60		/* Ticks/second of the clock */
#define	TIMEZONE (5*60)		/* Minutes westward from Greenwich */
#define	DSTFLAG	1		/* Daylight Saving Time applies in this locality */
#define	MSGBUFS	128		/* Characters saved from error messages */

/*
 * priorities
 * probably should not be
 * altered too much
 */

#define	PSWP	0
#define	PINOD	10
#define	PRIBIO	20
#define	PZERO	25
#define	NZERO	20
#define	PPIPE	26
/* PWAIT and PSLEP gone -- see kernel-side h/param.h. */
#define	PUSER	50

/*
 * signals
 * dont change
 */

#define	NSIG	17
/*
 * No more than 16 signals (1-16) because they are
 * stored in bits in a word.  Only names actually referenced are
 * defined; the rest are reserved slots in u_signal[NSIG].
 */
#define	SIGHUP	1	/* hangup */
#define	SIGINT	2	/* interrupt (rubout) */
#define	SIGQUIT	3	/* quit (FS) */
#define	SIGTRC	5	/* trace or breakpoint */
#define	SIGKIL	9	/* kill, uncatchable termination */
#define	SIGPIPE	13	/* end of pipe */
#define	SIGCLK	14	/* alarm clock */

/*
 * fundamental constants of the implementation--
 * cannot be changed easily
 */

#define	NBPW	sizeof(int)	/* number of bytes in an integer */
#define	BSIZE	512		/* size of secondary block (bytes) */
/* BSLOP was v7 slop for TIU/Spider devices; this port has no such device. */
#define	BSLOP	0
#define	NINDIR	(BSIZE/sizeof(daddr_t))
#define	BMASK	0777		/* BSIZE-1 */
#define	BSHIFT	9		/* LOG2(BSIZE) */
#define	NMASK	0177		/* NINDIR-1 */
#define	NSHIFT	7		/* LOG2(NINDIR) */
#define	USIZE	16		/* size of user block (*64) */
#ifndef NULL
#define	NULL	0
#endif
/* CMASK removed -- see kernel h/param.h. */
#define	NODEV	(dev_t)(-1)
#define	ROOTINO	((ino_t)2)	/* i number of all roots */
#define	SUPERB	((daddr_t)1)	/* block number of the super block */
#define	DIRSIZ	14		/* max characters per directory */
#define	NICINOD	100		/* number of superblock inodes */
#define	NICFREE	50		/* number of superblock free blocks */

/*
 * Some macros for units conversion
 */
/* Core clicks (64 bytes) to segments and vice versa */
#define	ctos(x)	((x+127)/128)
#define stoc(x) ((x)*128)

/* Core clicks (64 bytes) to disk blocks */
#define	ctod(x)	((x+7)>>3)

/* inumber to disk address */
#define	itod(x)	(daddr_t)((((unsigned)x+15)>>3))

/* inumber to disk offset */
#define	itoo(x)	(int)((x+15)&07)

/* clicks to bytes */
#define	ctob(x)	(x<<6)

/* bytes to clicks */
#define	btoc(x)	((((unsigned)x+63)>>6))

/* major part of a device */
#define	major(x)	(int)(((unsigned)x>>8))

/* minor part of a device */
#define	minor(x)	(int)(x&0377)

/* make a device number */
#define	makedev(x,y)	(dev_t)((x)<<8 | (y))

typedef	struct { int r[1]; } *	physadr;
#ifndef SYS_TYPES_H
typedef	long		daddr_t;
typedef char *		caddr_t;
typedef	unsigned short	ino_t;
typedef	long		time_t;
/* label_t mirrors h/param.h (R4..R11 + sp + lr).  Exported here only
 * so cmd/ps + pstat compile their copy of struct user (u_rsav/u_qsav/
 * u_ssav). */
typedef	int		label_t[10];
typedef	int		dev_t;
typedef	long		off_t;
#define	SYS_TYPES_H
#endif

/*
 * Machine-dependent bits and macros
 */
#define	UMODE	0170000		/* usermode bits */
#define	USERMODE(ps)	((ps & UMODE)==UMODE)

#define	INTPRI	0340		/* Priority bits */
#define	BASEPRI(ps)	((ps & INTPRI) != 0)
