/*
 * ARM user address layout and software segment bits.
 */

#define	RO	02		/* access abilities */
#define	RW	06
#define	ED	010		/* extend direction */
#define	TX	020		/* Software: text segment */
#define	ABS	040		/* Software: absolute address */

/*
 * User virtual memory layout.
 */
#define KERNBASE	0x40000000U	/* physical RAM base (QEMU virt) */
/*
 * Configured machine memory size.  QEMU virt exposes no firmware memory
 * map to probe, so -- as v7 itself fixed MAXMEM/NSWAP at config time --
 * the kernel is built for a known machine: set MEMSIZE to match the qemu
 * '-m' value (default 128 MB).  CORETOP is derived from it.
 */
#define MEMSIZE		0x08000000U	/* 128 MB */
#define USERBASE	0x00000000U
#define USERSIZE	0x00100000U	/* 1 MB user virtual window (VA 0..) */
#define UENTRY		0x00010000U
#define USTACK		0x000f0000U
#define UARGV		0x0000f000U
#define UARGLEN		3072
#define UENTRY_SIGTRAMP	0x0000fe00U
/*
 * Physical core window.  The kernel maps KERNBASE..CORETOP as 1 MB
 * sections (PA==VA), so all of physical core below CORETOP is directly
 * addressable by the kernel.  Process images are allocated from coremap as
 * "clicks" (64 bytes) within [COREBASE, CORETOP); click c is at CLKADDR(c).
 * Click 0 is reserved (malloc returns 0 to mean "no core").
 */
#define COREBASE	0x44000000U
#define CORETOP		(KERNBASE + MEMSIZE)
#define NCLICK		((CORETOP-COREBASE)>>6)		/* clicks of user core */
#define CLKADDR(c)	((char *)(COREBASE + ((unsigned)(c) << 6)))

/*
 * Armv7 short-descriptor page-table bits.  User pages are mapped
 * strongly-ordered (uncached) to match the proven device-style user
 * mapping and sidestep I/D cache aliasing for now.
 */
#define SEC_KERN	0x00000402U	/* L1 1 MB section, kernel rw */
#define SEC_DEV		0x00000c02U	/* L1 1 MB section, device */
#define PTE_PT		0x00000001U	/* L1 entry -> L2 coarse table */
#define PG_RW		0x00000032U	/* L2 small page, PL0 read/write */
#define PG_RO		0x00000022U	/* L2 small page, PL0 read-only */
#define PG_KRW		0x00000012U	/* L2 small page, kernel-only rw */
#define PGSHIFT		12
#define PGSIZE		0x1000U
