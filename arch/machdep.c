#include "../h/param.h"
#include "../h/buf.h"
#include "../h/systm.h"
#include "../h/proto.h"
#include "arm.h"
void startup(void)
{
	struct buf *bp;
	unsigned char *raw;
	unsigned int isize, fsize;
	/* Qemu virt's default RAM is 128 MiB at 0x40000000.  Print bytes
	 * directly; the V7 banner shape lets userspace scrape "mem =". */
	printf("mem = %D\n", (long)(128L * 1024 * 1024));
	/* v7's startup() probed core via UISA/fuibyte to compute maxmem,
	 * then capped it at MAXMEM.  On this port userspace is identity-
	 * mapped into a USERSIZE (1 MiB = 16384 click) window, so estabur()'s
	 * `nt+nd+ns+USIZE > maxmem` check passes as long as maxmem covers
	 * that window.  Seed it directly. */
	maxmem = (int)(USERSIZE >> 6) + USIZE;	/* clicks (64 bytes) */
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
