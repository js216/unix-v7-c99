/*
 * ARM user address layout and software segment bits.
 */

#define	RO	02		/* access abilities */
#define	RW	06
#define	ED	010		/* extend direction */
#define	TX	020		/* Software: text segment */
#define	ABS	040		/* Software: absolute address */

#define USERBASE	0x00000000U
#define USERSIZE	0x00100000U	/* 1 MB user virtual window (VA 0..) */
#define UENTRY		0x00000010U
#define USTACK		0x000f0000U
#define UARGV		0x0000f000U
#define UARGLEN		3072
#define UENTRY_SIGTRAMP	0x00000008U	/* below UENTRY, never loaded */
#define NCLICK		((CORETOP-COREBASE)>>6)		/* clicks of user core */
#define CLKADDR(c)	((char *)(COREBASE + ((unsigned)(c) << 6)))
#define SEC_KERN	0x0001140eU	/* L1 1 MB section, kernel rw, cached */
#define SEC_DEV		0x00000c02U	/* L1 1 MB section, device (uncached) */
#define PTE_PT		0x00000001U	/* L1 entry -> L2 coarse table */
#define PG_RW		0x0000047eU	/* L2 small page, PL0 read/write, cached */
#define PG_RO		0x0000046eU	/* L2 small page, PL0 read-only, cached */
#define PG_KRW		0x0000045eU	/* L2 small page, kernel-only rw, cached */
#define PGSHIFT		12
#define PGSIZE		0x1000U
struct memregion { unsigned int start, end, attr; };
