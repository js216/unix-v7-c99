#include "../h/param.h"
#include "../h/buf.h"
#include "../h/systm.h"
struct map;
struct buf;
extern int malloc(struct map *mp, int size);
extern void mfree(struct map *mp, int size, int a);
extern void printf(char *fmt, ...);
extern void panic(char *s);
extern void prdev(char *str, dev_t dev);
extern void putchar(char c);
extern int getchar(void);
extern void trap(int *frame);
extern void panictrap(void);
extern void run_user(unsigned int pc, unsigned int sp);
extern void mmu_on(unsigned int ttb);
extern void dmbsy(void);
extern void mmuinit(void);
extern void startup(void);
extern void armboot(void);
extern void armboot_setrun(int pid);
extern void armboot_swtch(void);
extern int save(int *lp);
extern void resume(int addr, int *lp);
extern struct buf *bread(dev_t dev, daddr_t blkno);
extern struct buf *breada(dev_t dev, daddr_t blkno, daddr_t rablkno);
extern void bwrite(struct buf *bp);
extern void bdwrite(struct buf *bp);
extern void brelse(struct buf *bp);
extern int incore(dev_t dev, daddr_t blkno);
extern struct buf *getblk(dev_t dev, daddr_t blkno);
extern struct buf *geteblk(void);
extern void iowait(struct buf *bp);
extern void notavail(struct buf *bp);
extern void iodone(struct buf *bp);
extern void clrbuf(struct buf *bp);
extern void swap(daddr_t blkno, int coreaddr, int count, int rdflg);
extern void bflush(dev_t dev);
extern void geterror(struct buf *bp);
extern void wakeup(caddr_t chan);
extern void sleep(caddr_t chan, int pri);
extern int spl0(void);
extern int spl1(void);
extern int spl6(void);
extern int spl7(void);
extern void splx(int s);
extern void binit(void);
extern void copyseg(int from, int to);
extern void clearseg(int a);
extern dev_t rootdev;
extern int virtio_strategy(struct buf *bp);
extern void virtio_init(void);
#include "../arch/arm.h"
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
