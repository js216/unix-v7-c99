#ifndef PARAM_H
#define PARAM_H

/*
 * tunable variables
 */

#define	NBUF	64		/* size of buffer cache (raised from v7's 29
				 * to help long-running pipelines; 64*512=32KB
				 * BSS, trivial on 128 MiB qemu). */
#define	NINODE	200		/* number of in core inodes */
#define	NFILE	175		/* number of in core file structures */
#define	NMOUNT	8		/* number of mountable file systems */
#define	MAXMEM	(64*32)		/* max core per process - first # is Kw */
/* MAXUPRC, SSIZE, NCARGS were used by sys1.c::fork/exec (deleted -- the
 * armboot path enforces its own per-pid limits and arg-buffer size). */
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
/* PWAIT (wait priority) and PSLEP (pause priority) are gone -- their
 * only sleep() callers were sys1.c::wait and sys4.c::pause, both
 * reimplemented in arch/armboot.c using the multithreading primitives. */
#define	PUSER	50

/*
 * signals
 * dont change
 */

#define	NSIG	17
/*
 * No more than 16 signals (1-16) because they are
 * stored in bits in a word.
 *
 * Only the v7 signal names actually referenced by this kernel are
 * defined here.  SIGINS/IOT/EMT/FPT/BUS/SEG/SYS/TRM are gone -- never
 * raised or named anywhere; userspace gets the long names from
 * <signal.h> instead.  The matching numeric slots (4, 6, 7, 8, 10, 11,
 * 12, 15) remain reserved in u_signal[NSIG]; a7.s raises 4 and 11 by
 * literal integer (see undef_entry / pabort_entry).
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
/* v7 CMASK (initial u.u_cmask from main()) is unused on this port: BSS
 * zero-init of u.u_cmask already gives the same 0. */
#define	NODEV	(dev_t)(-1)
#define	ROOTINO	((ino_t)2)	/* i number of all roots */
#define	SUPERB	((daddr_t)1)	/* block number of the super block */
#define	DIRSIZ	14		/* max characters per directory */
#define	NICINOD	100		/* number of superblock inodes */
#define	NICFREE	50		/* number of superblock free blocks */
/* UBASE (PDP-11 user-block VA) and the clist CBSIZE/CROUND constants
 * are gone -- ARM USERBASE is in arch/arm.h, and the v7 clist subsystem
 * (prim.c) was removed this session. */

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
typedef	long		daddr_t;
typedef char *		caddr_t;
typedef	unsigned short	ino_t;
typedef	long		time_t;
typedef	int		label_t[10];	/* regs 2-7 */
typedef	int		dev_t;
typedef	long		off_t;

/*
 * Machine-dependent bits and macros
 */
#define	UMODE	0170000		/* usermode bits */
#define	USERMODE(ps)	((ps & UMODE)==UMODE)

#define	INTPRI	0340		/* Priority bits */
#define	BASEPRI(ps)	((ps & INTPRI) != 0)

#endif
