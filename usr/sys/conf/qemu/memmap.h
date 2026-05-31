/*
 * QEMU virt physical memory map (selected by the Makefile -I path).
 *
 * RAM is one contiguous block at 0x40000000; the kernel image and the
 * physical core window are identity-mapped within it.  QEMU exposes no
 * firmware memory map to probe, so -- as v7 itself fixed MAXMEM/NSWAP at
 * config time -- MEMSIZE is built in: set it to match the qemu '-m' value.
 */
#define KERNBASE	0x40000000U	/* physical RAM base */
#define MEMSIZE		0x08000000U	/* 128 MB (match qemu -m) */
#define COREBASE	0x44000000U	/* user core window base */
#define CORETOP		(KERNBASE + MEMSIZE)

/* RAM is one block, so the big tables stay in ordinary .bss (no spill). */
#define KTABLES_SECTION	".bss"

/* QEMU RAM (and the core window) is cached, so the per-process user pages are
 * cached too (matching the core window's memory type) -- small page, PL0 rw,
 * Normal Write-Back/Write-Allocate shareable (TEX=001,C=1,B=1,AP=11,S=1),
 * i.e. the same bits as PG_RW. */
#define PG_USER		0x0000047eU

/* GICv2 distributor + CPU interface (qemu virt). */
#define GIC_DIST_BASE	0x08000000U
#define GIC_CPU_BASE	0x08010000U
