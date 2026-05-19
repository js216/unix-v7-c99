#include "../h/param.h"
#include "../h/buf.h"
#include "../h/proto.h"
/* V7 PDP-11 octal bootstrap; kept verbatim for v7 source link compat. */
int icode[] = {
	0104413, 0000014, 0000010, 0000777,
	0000014, 0000000, 0062457, 0061564,
	0064457, 0064556, 0000164,
};
int szicode = sizeof(icode);
void startup(void)
{
	struct buf *bp;
	unsigned char *raw;
	unsigned int isize, fsize;
	/* Qemu virt's default RAM is 128 MiB at 0x40000000.  Print bytes
	 * directly; the V7 banner shape lets userspace scrape "mem =". */
	printf("mem = %D\n", (long)(128L * 1024 * 1024));
	mmuinit();
	virtio_init();
	binit();
	/* Sentinel: bread the rootfs SUPERB and print isize/fsize.  Decode
	 * raw bytes -- the on-disk layout packs s_fsize at offset 2 (no
	 * alignment padding) while h/filsys.h's struct aligns it to 4. */
	bp = bread((dev_t)rootdev, (daddr_t)SUPERB);
	raw = (unsigned char *)bp->b_un.b_addr;
	isize = (unsigned int)raw[0] | ((unsigned int)raw[1] << 8);
	fsize = (unsigned int)raw[2] | ((unsigned int)raw[3] << 8)
	      | ((unsigned int)raw[4] << 16)
	      | ((unsigned int)raw[5] << 24);
	printf("v7: sb isize=%d fsize=%d\n", (int)isize, (int)fsize);
	brelse(bp);
}
