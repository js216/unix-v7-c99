/*
 *   QEMU virt board description
 *
 * The machine-dependent data the shared machine_init() (machdep.c) needs for
 * the QEMU virt machine: the physical memory map and the clock/DRAM hook.
 * RAM is already up when qemu loads the kernel, so clock_ddr_init() is empty.
 * The MP135 build links conf/mp135.c instead.
 */
#include "../h/param.h"
#include "../h/seg.h"

/*
 * QEMU virt sections: kernel + physical core window cached (PA==VA), the
 * GIC/virtio/PL011 device space uncached.  Terminated by a zero entry.
 */
struct memregion board_map[] = {
	{ KERNBASE,	CORETOP,	SEC_KERN },
	{ 0x08000000U,	0x0c000000U,	SEC_DEV },
	{ 0, 0, 0 }
};

void
clock_ddr_init(void)
{
	/* RAM is already up under qemu -kernel; nothing to bring up. */
}
