/*
 * Page access bits.
 */

#define	RO	0300		/* access abilities */
#define	RW	0100
#define	UENTRY_SIGTRAMP	8
#define	PGADDR(c)	((char *)(((unsigned)(c)<<12)+coreoff))
#define	BLK_KERN	0x701ULL
#define	BLK_DEV	0x60000000000405ULL
#define	PTE_TAB	3
#define	PGUSER	0xf03
#define	PGSHIFT	12
#define	BLKSHIFT	21	/* 2 MB blocks */
#define	L1SHIFT	30	/* 1 GB first-level entries */
#define	NPTE	512	/* entries per translation table */
#define	PGSIZE	4096
#define	PTPGB	(NPTE*NPTE)
struct memregion { unsigned va, start, end; unsigned long long attr; };
extern struct memregion board_map[];
extern unsigned long long kl2[], kl3u[], bootl1[];
