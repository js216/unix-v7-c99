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

/* pl011.c */
void putchar(char c);
int getchar(void);

/* main.c */
void trap(int *frame);
void panictrap(void);
void run_user(unsigned int pc, unsigned int sp);
void mmu_on(unsigned int ttb);
void dmbsy(void);

/* machdep.c */
void startup(void);
void armboot(void);

/* dev/bio.c */
struct buf *bread(dev_t dev, daddr_t blkno);
struct buf *breada(dev_t dev, daddr_t blkno, daddr_t rablkno);
void bwrite(struct buf *bp);
void bdwrite(struct buf *bp);
void bawrite(struct buf *bp);
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
void physio(int (*strat)(), struct buf *bp, dev_t dev, int rw);
void geterror(struct buf *bp);

/* arch/v7stubs.c */
void mapfree(struct buf *bp);
void wakeup(caddr_t chan);
void sleep(caddr_t chan, int pri);
int spl0(void);
int spl6(void);
void splx(int s);
int nulldev(void);
void binit(void);
extern dev_t rootdev;


/* dev/mp135_blk.c */
int mp135_strategy(struct buf *bp);

/* dev/virtio_blk.c */
int virtio_strategy(struct buf *bp);
void virtio_init(void);

#endif
