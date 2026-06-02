/*
 * ARM user address layout and software segment bits.
 */

#define	RO	02		/* access abilities */
#define	RW	06
#define	ED	010		/* extend direction */
#define	TX	020		/* Software: text segment */
#define	ABS	040		/* Software: absolute address */

/*
 * Physical memory layout (KERNBASE, COREBASE, CORETOP) is board-specific and
 * comes from conf/<board>/memmap.h, selected by the Makefile -I path -- so the
 * kernel sources are identical across boards (no conditional compilation).
 */
#include "memmap.h"

/*
 * User virtual memory layout.
 */
#define USERBASE	0x00000000U
#define USERSIZE	0x00100000U	/* 1 MB user virtual window (VA 0..) */
#define UENTRY		0x00000010U
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
#define NCLICK		((CORETOP-COREBASE)>>6)		/* clicks of user core */
#define CLKADDR(c)	((char *)(COREBASE + ((unsigned)(c) << 6)))
/*
 * Section/page attributes.  Normal memory (kernel, user, DDR) is Normal
 * Write-Back/Write-Allocate, shareable -- CACHED (TEX=001,C=1,B=1,S=1) -- so
 * the CPU runs at full speed instead of stalling on every uncached access.
 * Device memory (MMIO) stays strongly ordered.  mmu_on() enables the L1
 * I/D caches; resume() invalidates the I-cache on context switch because the
 * per-process user region shares VA 0 (VIPT I-cache aliasing); DMA buffers
 * are flushed by the block driver (dcflush) on cache-incoherent hardware.
 */
#define SEC_KERN	0x0001140eU	/* L1 1 MB section, kernel rw, cached */
#define SEC_DEV		0x00000c02U	/* L1 1 MB section, device (uncached) */
#define PTE_PT		0x00000001U	/* L1 entry -> L2 coarse table */
#define PG_RW		0x0000047eU	/* L2 small page, PL0 read/write, cached */
#define PG_RO		0x0000046eU	/* L2 small page, PL0 read-only, cached */
#define PG_KRW		0x0000045eU	/* L2 small page, kernel-only rw, cached */
#define PGSHIFT		12
#define PGSIZE		0x1000U
/*
 * Physical memory map, one entry per [start,end) 1 MB-section range with its
 * L1 attribute (SEC_KERN cached, SEC_DEV device).  The board file supplies a
 * board_map[] terminated by a zero entry; machine_init() (machdep.c) walks it
 * to build the section table -- identical code on every board, so QEMU
 * exercises the same machine_init() the MP135 runs.
 */
struct memregion { unsigned int start, end, attr; };
