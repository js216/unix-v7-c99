/*
 * Page access bits.
 */

#define	RO	0300		/* access abilities */
#define	RW	0100
#define	UENTRY_SIGTRAMP	8
#define	CLKADDR(c)	((char *)(((unsigned)(c)<<12)+coreoff))
#define	BLK_KERN	0x701ULL
#define	BLK_DEV	0x60000000000405ULL
#define	PTE_TAB	3
#define	PGSHIFT	12
#define	PGSIZE	4096
#define	PTPGB	(512*512)
struct memregion { unsigned va, start, end; unsigned long long attr; };
