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
	/* v7 had a union { off_t f_offset; struct chan *f_chan; } here for
	 * the mpx multiplexor channel pointer overlap.  This port doesn't
	 * wire mpx, so the union collapses to just the offset field. */
	union {
		off_t	f_offset;	/* read/write character pointer */
	} f_un;
};

extern struct file file[];	/* The file table itself */

/* flags */
#define	FREAD	01
#define	FWRITE	02
#define	FPIPE	04
/* FMP (file is mpx multiplexor channel) gone -- mpx subsystem not wired
 * on this port; FMP was never set, so the bit-test branches were dead. */
