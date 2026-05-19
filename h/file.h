/*
 * One file structure is allocated
 * for each open/creat/pipe call.
 * Main use is to hold the read/write
 * pointer associated with each open
 * file.
 */
struct	file
{
	char	f_flag;
	short	f_count;	/* reference count.  PORT: widened from
				 * char (8-bit, max 255) because every fork
				 * bumps every open file's count by 1; with
				 * sh's 5+ open FDs, ~250 sequential forks
				 * overflowed it and corrupted refcounts. */
	struct inode *f_inode;	/* pointer to inode structure */
	union {
		off_t	f_offset;	/* read/write character pointer */
		struct chan *f_chan;	/* mpx channel pointer */
	} f_un;
};

extern struct file file[];	/* The file table itself */

/* flags */
#define	FREAD	01
#define	FWRITE	02
#define	FPIPE	04
#define FMPX	010
#define	FMPY	020
#define	FMP	030
#define	FKERNEL	040
