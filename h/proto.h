#ifndef PROTO_H
#define PROTO_H

#include "../h/map.h"

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

#endif
