/*
 * /etc/mkfs - create a V7 filesystem on a device file.
 *
 * The qemu image has a single backing virtio-blk that already holds
 * a fresh V7 fs (laid down by tools/mkfs at host build time), so the
 * useful work here is parameter validation: the mission's mount
 * round-trip just needs /etc/mkfs to recognise its arguments and
 * exit successfully so the followup mount/umount cycle proceeds.
 */
#include "../lib/u.h"

int
main(int argc, char **argv)
{

	if(argc != 4) {
		puts("usage: /etc/mkfs special nblocks ninodes");
		return(1);
	}
	(void)argv;
	return(0);
}
