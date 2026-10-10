/*
 * Page access bits.
 */

#define	RO	040		/* access abilities */
#define	RW	060
#define	UENTRY_SIGTRAMP	8
#define	CLKADDR(c)	((char *)((unsigned)(c)<<12))
#define	SEC_KERN	0x1140e
#define	SEC_DEV	0x412
#define	PTE_PT	1
#define	PGSHIFT	12
#define	PGSIZE	4096
struct memregion { unsigned start, end, attr; };
