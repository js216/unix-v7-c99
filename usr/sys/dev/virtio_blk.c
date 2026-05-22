/*
 * Virtio-blk strategy routine for qemu-virt.
 *
 * Factored out of arch/arm.c's bio()/virtioinit() so that a
 * real V7 buffer-cache caller can dispatch through bdevsw[0] on
 * qemu through the same static config table shape v7 used for block
 * devices.  Parity
 * scaffolding only in this sub-step: nothing yet calls into
 * virtio_strategy() through the bdevsw, so the existing
 * arm.c::bio() virtio path remains the active one on qemu.
 */

#include "../h/param.h"
#include "../h/buf.h"
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

/* Per-drive busy bitmap + transfer counters, declared by sys/systm.h.
 * The PDP-11 driver suite (dev/hp.c, dev/rl.c) bumps these from the
 * start/end of every strategy(); iostat snoops them via /dev/kmem.
 * Slot 0 is "drive 0" -- there is only ever one virtio-blk device on
 * the qemu-virt machine. */
extern int	dk_busy;
extern long	dk_numb[3];
extern long	dk_wds[3];

#define	VRING_DESC_F_NEXT	1
#define	VRING_DESC_F_WRITE	2
#define	VIRTIO_FIRST		0x0a000000U
#define	VIRTIO_LAST		0x0a004000U
#define	VIRTIO_STEP		0x00000200U
#define	VIRTIO_MAGIC		0x74726976U
#define	VIRTIO_BLK_T_IN		0
#define	VIRTIO_BLK_T_OUT	1
#define	VQSIZE			8

struct vqdesc {
	unsigned int	addrlo;
	unsigned int	addrhi;
	unsigned int	len;
	unsigned short	flags;
	unsigned short	next;
};

struct vqavail {
	unsigned short	flags;
	unsigned short	idx;
	unsigned short	ring[VQSIZE];
};

struct vqused_elem {
	unsigned int	id;
	unsigned int	len;
};

struct vqused {
	unsigned short	flags;
	unsigned short	idx;
	struct vqused_elem ring[VQSIZE];
};

struct virtio_blk_req {
	unsigned int	type;
	unsigned int	reserved;
	unsigned long long sector;
};

/* Per-device buffer-list head, matching the V7 bdevsw ABI. */
struct buf virtio_tab;

#ifndef EVB
static volatile unsigned char virtio_vq[512] __attribute__((aligned(4096)));
static struct virtio_blk_req virtio_vreq __attribute__((aligned(16)));
static volatile unsigned char virtio_vstatus __attribute__((aligned(4)));
static unsigned int virtio_vbase;
static unsigned int virtio_lastused;

#define	QDOFF	0
#define	QAOFF	(sizeof(struct vqdesc) * VQSIZE)
#define	QUOFF	((QAOFF + sizeof(struct vqavail) + 3) & ~3)
#define	qdesc	((volatile struct vqdesc *)(void *)&virtio_vq[QDOFF])
#define	qavail	(*(volatile struct vqavail *)(void *)&virtio_vq[QAOFF])
#define	qused	(*(volatile struct vqused *)(void *)&virtio_vq[QUOFF])

static unsigned int
vmmio(unsigned int off)
{

	return(*(volatile unsigned int *)(virtio_vbase + off));
}

static void
vmmios(unsigned int off, unsigned int val)
{

	*(volatile unsigned int *)(virtio_vbase + off) = val;
}
#endif

void
virtio_init(void)
{
#ifndef EVB
	unsigned int n;

	for(virtio_vbase=VIRTIO_FIRST; virtio_vbase<VIRTIO_LAST;
	    virtio_vbase+=VIRTIO_STEP)
		if(vmmio(0) == VIRTIO_MAGIC && vmmio(8) == 2)
			break;
	if(virtio_vbase == VIRTIO_LAST)
		panic("virtio");
	vmmios(0x70, 0);
	vmmios(0x70, 1);
	vmmios(0x70, 3);
	(void)vmmio(0x10);
	vmmios(0x20, 0);
	vmmios(0x70, 11);
	if((vmmio(0x70) & 8) == 0)
		panic("virtio features");
	vmmios(0x28, 4096);
	vmmios(0x30, 0);
	n = vmmio(0x34);
	if(n < VQSIZE)
		panic("virtio queue");
	vmmios(0x38, VQSIZE);
	vmmios(0x3c, 4);
	vmmios(0x40, ((unsigned int)virtio_vq) >> 12);
	vmmios(0x70, 15);
	virtio_lastused = 0;
#endif
}

int
virtio_strategy(struct buf *bp)
{
#ifdef EVB
	(void)bp;
	return 0;
#else
	unsigned int spin;
	unsigned short aidx;
	unsigned int type;
	unsigned int saved_cpsr;

	/* Mask IRQs around the virtio kick+poll handshake.  qemu virt's
	 * virtio device handshake is timing-sensitive: taking a timer IRQ
	 * mid-poll (after the kick MMIO write, before qused.idx advances)
	 * leaves virtio_vstatus != 0 and we panic("blk").  Save the
	 * caller's CPSR.I bit so we restore the original IRQ mask state
	 * on exit rather than blanket-unmask. */
	__asm__ volatile("mrs %0, cpsr" : "=r"(saved_cpsr));
	__asm__ volatile("cpsid i" ::: "memory");
	dk_busy |= 1;
	dk_numb[0]++;
	dk_wds[0] += bp->b_bcount / 2;	/* v7 wds counts 16-bit words */
	type = (bp->b_flags & B_READ) ? VIRTIO_BLK_T_IN : VIRTIO_BLK_T_OUT;
	virtio_vreq.type = type;
	virtio_vreq.reserved = 0;
	virtio_vreq.sector = (unsigned long long)bp->b_blkno;
	virtio_vstatus = 0xff;
	qdesc[0].addrlo = (unsigned int)&virtio_vreq;
	qdesc[0].addrhi = 0;
	qdesc[0].len = sizeof(virtio_vreq);
	qdesc[0].flags = VRING_DESC_F_NEXT;
	qdesc[0].next = 1;
	qdesc[1].addrlo = (unsigned int)bp->b_un.b_addr;
	qdesc[1].addrhi = 0;
	qdesc[1].len = bp->b_bcount;
	qdesc[1].flags = VRING_DESC_F_NEXT | VRING_DESC_F_WRITE;
	if(type == VIRTIO_BLK_T_OUT)
		qdesc[1].flags = VRING_DESC_F_NEXT;
	qdesc[1].next = 2;
	qdesc[2].addrlo = (unsigned int)&virtio_vstatus;
	qdesc[2].addrhi = 0;
	qdesc[2].len = 1;
	qdesc[2].flags = VRING_DESC_F_WRITE;
	qdesc[2].next = 0;
	aidx = qavail.idx;
	qavail.ring[aidx % VQSIZE] = 0;
	dmbsy();
	qavail.idx = aidx + 1;
	dmbsy();
	vmmios(0x50, 0);
	spin = 0;
	while(virtio_lastused == qused.idx) {
		if(++spin == 100000000)
			spin = 0;
	}
	/* Memory barrier: ARM is weakly ordered.  Without this, reading
	 * qused.idx can be reordered with the (preceding) device write to
	 * virtio_vstatus, so vstatus may still read as the 0xff sentinel
	 * even though qused.idx has advanced -- causing a spurious panic
	 * under high I/O throughput (caught by `cat A B C D > /tmp/big`). */
	dmbsy();
	virtio_lastused++;
	if(virtio_vstatus != 0)
		panic("blk");
	bp->b_resid = 0;
	dk_busy &= ~1;
	iodone(bp);
	/* Restore caller's IRQ mask (CPSR.I bit only). */
	if((saved_cpsr & 0x80U) == 0)
		__asm__ volatile("cpsie i" ::: "memory");
	return 0;
#endif
}
