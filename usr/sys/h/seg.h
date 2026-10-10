/*
 * KT-11 addresses and bits.
 */

#define	UISD	((physadr)0177600)	/* first user I-space descriptor register */
#define	UISA	((physadr)0177640)	/* first user I-space address register */
#define	UDSA	((physadr)0177660)	/* first user D-space address register */
#define	RO	040		/* access abilities */
#define	RW	060
#define	ED	010		/* extend direction */
#define	TX	020		/* Software: text segment */
#define	ABS	040		/* Software: absolute address */

/*
 * structure used to address
 * a sequence of integers.
 */
extern physadr	ka6;		/* 11/40 KISA6; 11/45 KDSA6 */

/*
 * address to access 11/70 UNIBUS map
 */
#define	UBMAP	((physadr)0170200)
#define	UENTRY_SIGTRAMP	8
#define	CLKADDR(c)	((char *)((unsigned)(c)<<12))
#define	SEC_KERN	0x1140e
#define	SEC_DEV	0x412
#define	PTE_PT	1
#define	PGSHIFT	12
#define	PGSIZE	4096
struct memregion { unsigned start, end, attr; };
