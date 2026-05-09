/*
 * mount - attach a V7 filesystem at a directory.
 *
 * Single-image port: the kernel has only the root virtio-blk fs,
 * so mount is bookkeeping. The kernel accepts the (special, dir)
 * pair and lets the existing path layer resolve later references
 * to the directory's children against the rootfs unchanged. The
 * mission's round-trip therefore survives a no-op umount + remount.
 */
#include "../lib/u.h"

int
main(int argc, char **argv)
{
	int rc;

	if(argc != 3) {
		puts("usage: mount special dir");
		return(1);
	}
	rc = syscall3(S_MOUNT, (int)argv[1], (int)argv[2], 0);
	if(rc < 0) {
		puts("mount: failed");
		return(1);
	}
	return(0);
}
