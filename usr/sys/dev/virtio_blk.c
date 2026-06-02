#include "../h/param.h"
#include "../h/buf.h"

#ifdef VIRTIO

void panic(char *s);
void dmbsy(void);
void iodone(struct buf *bp);
void deverror(struct buf *bp, int o1, int o2);
int intr_disable(void);
void intr_restore(int s);

extern int	dk_busy;
extern long	dk_numb[3];
extern long	dk_wds[3];

int	bd_irq;		/* GIC INTID of the block device (0 if none) */

#define	VRING_DESC_F_NEXT	1
#define	VRING_DESC_F_WRITE	2
#define	VIRTIO_FIRST		0x0a000000U
#define	VIRTIO_LAST		0x0a004000U
#define	VIRTIO_STEP		0x00000200U
#define	VIRTIO_IRQ_BASE		48		/* QEMU virt: SPI 16 -> INTID 48 */
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

struct buf bdtab;

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
bdinit(void)
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
	bd_irq = VIRTIO_IRQ_BASE +
	    (virtio_vbase - VIRTIO_FIRST) / VIRTIO_STEP;
	bdtab.b_actf = NULL;
	bdtab.b_active = 0;
#endif
}

#ifndef EVB
/*
 * Program the virtqueue for the buffer at the head of the queue and notify
 * the device.  Returns at once; completion arrives as an interrupt.
 * (cf. v7 rk.c rkstart.)
 */
static void
virtio_start(void)
{
	register struct buf *bp;
	unsigned short aidx;
	unsigned int type;

	if((bp = bdtab.b_actf) == NULL)
		return;
	bdtab.b_active++;
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
	vmmios(0x50, 0);		/* QueueNotify */
	dk_busy |= 1;
	dk_numb[0]++;
	dk_wds[0] += bp->b_bcount / 2;
}

/*
 * Block-device strategy: queue the buffer and, if the controller is idle,
 * start it.  Returns at once; bio.c's iowait() sleeps on the buffer until
 * the completion interrupt runs iodone().  (cf. v7 rk.c rkstrategy.)
 */
int
bdstrategy(struct buf *bp)
{
	int s;

	bp->av_forw = NULL;
	s = intr_disable();
	if(bdtab.b_actf == NULL)
		bdtab.b_actf = bp;
	else
		bdtab.b_actl->av_forw = bp;
	bdtab.b_actl = bp;
	if(bdtab.b_active == 0)
		virtio_start();
	intr_restore(s);
	return(0);
}

/*
 * Completion interrupt (GIC INTID bd_irq).  Acknowledge the device,
 * finish the active buffer, and start the next queued one.
 * (cf. v7 rk.c rkintr.)
 */
int
bdintr(void)
{
	register struct buf *bp;
	unsigned int is;

	is = vmmio(0x60);		/* InterruptStatus */
	vmmios(0x64, is);		/* InterruptACK */
	if(bdtab.b_active == 0)
		return(0);
	if(qused.idx == virtio_lastused)
		return(0);
	dmbsy();
	virtio_lastused++;
	dk_busy &= ~1;
	bp = bdtab.b_actf;
	bdtab.b_active = 0;
	if(virtio_vstatus != 0) {
		deverror(bp, virtio_vstatus, 0);
		bp->b_flags |= B_ERROR;
	}
	bdtab.b_actf = bp->av_forw;
	bp->b_resid = 0;
	iodone(bp);
	virtio_start();
	return(0);
}
#else
int
bdstrategy(struct buf *bp)
{
	(void)bp;
	return(0);
}
int
bdintr(void)
{
	return(0);
}
#endif

#endif
