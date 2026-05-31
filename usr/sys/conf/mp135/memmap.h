/*
 * STM32MP135 physical memory map (selected by the Makefile -I path).
 *
 * The kernel (FSBL) runs from cached SYSRAM (0x2FFE0000, 128 KB); the user
 * core and buffer cache live in external DDR (0xC0000000, 512 MB) -- a
 * separate window, not contiguous with SYSRAM -- mapped Normal-Non-cacheable
 * because the SDMMC IDMA is non-coherent (see board_map + PG_USER below).
 * COREBASE/CORETOP bound the DDR core window from which images are allocated
 * as clicks.
 */
#define KERNBASE	0x2FFE0000U	/* SYSRAM base (kernel) */
/* The linker puts .ddrbss (l1 page table + big system tables + the buffer
 * cache) at the bottom of DDR (0xC0000000, ~1 MB).  The user core window must
 * start ABOVE it: otherwise proc0's u-area and coremap-allocated images alias
 * the live page table and buffer cache, corrupting both. */
#define COREBASE	0xC0100000U	/* DDR user core (1 MB past .ddrbss) */
#define CORETOP		0xE0000000U	/* DDR top (512 MB) */

/* SYSRAM is only 128 KB, so the big tables spill to DDR (.ddrbss). */
#define KTABLES_SECTION	".ddrbss"

/* The SDMMC IDMA is non-coherent, so the DDR core window is mapped Normal
 * Non-cacheable (see board_map); the per-process user pages (arm_sureg) must
 * use the SAME memory type, or the kernel's uncached writes to a freshly
 * forked/exec'd image (copyseg/copyout via the COREBASE window) would not be
 * seen through the process's cached user mapping -- the child would execute
 * stale cache lines and fault.  PG_USER = small page, PL0 rw, Normal
 * Non-cacheable shareable (TEX=001,C=0,B=0,AP=11,S=1). */
#define PG_USER		0x00000472U

/* Cortex-A7 built-in GICv2: distributor at PERIPHBASE+0x1000, CPU IF +0x2000. */
#define GIC_DIST_BASE	0xA0021000U
#define GIC_CPU_BASE	0xA0022000U
