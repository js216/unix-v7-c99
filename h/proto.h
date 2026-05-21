#ifndef PROTO_H
#define PROTO_H

#include "../h/param.h"
#include "../h/map.h"

struct buf;

/* malloc.c */
int malloc(struct map *mp, int size);
void mfree(struct map *mp, int size, int a);

/* prf.c */
void printf(char *fmt, ...);
void panic(char *s);
void prdev(char *str, dev_t dev);

/* pl011.c */
void putchar(char c);
int getchar(void);

/* main.c */
void trap(int *frame);
void panictrap(void);
void run_user(unsigned int pc, unsigned int sp);
void mmu_on(unsigned int ttb);
void dmbsy(void);
void mmuinit(void);

/* machdep.c */
void startup(void);
void armboot(void);

/* arch/armboot.c -- v7-side hooks into the multi-thread save-pool. */
void armboot_setrun(int pid);
void armboot_swtch(void);

/* arch/swtch.s -- setjmp-style save/resume over label_t (10 ints). */
int save(int *lp);
void resume(int addr, int *lp);

/* dev/bio.c */
struct buf *bread(dev_t dev, daddr_t blkno);
struct buf *breada(dev_t dev, daddr_t blkno, daddr_t rablkno);
void bwrite(struct buf *bp);
void bdwrite(struct buf *bp);
void brelse(struct buf *bp);
int incore(dev_t dev, daddr_t blkno);
struct buf *getblk(dev_t dev, daddr_t blkno);
struct buf *geteblk(void);
void iowait(struct buf *bp);
void notavail(struct buf *bp);
void iodone(struct buf *bp);
void clrbuf(struct buf *bp);
void swap(daddr_t blkno, int coreaddr, int count, int rdflg);
void bflush(dev_t dev);
void geterror(struct buf *bp);

/* arch/v7stubs.c */
void wakeup(caddr_t chan);
void sleep(caddr_t chan, int pri);
int spl0(void);
int spl1(void);
int spl6(void);
int spl7(void);
void splx(int s);
void binit(void);
void copyseg(int from, int to);
void clearseg(int a);
extern dev_t rootdev;

/* dev/mp135_blk.c */
int mp135_strategy(struct buf *bp);

/* dev/virtio_blk.c */
int virtio_strategy(struct buf *bp);
void virtio_init(void);

#endif
