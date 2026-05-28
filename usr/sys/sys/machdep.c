#include "../h/param.h"
#include "../h/systm.h"
#include "../h/seg.h"

void printf(char *fmt, ...);
void panic(char *s);
void mmu_on(unsigned int ttb);
void mmuinit(void);
void virtio_init(void);

/*
 * Machine-dependent startup code
 */
void startup(void)
{
	printf("mem = %D\n", (long)(128L * 1024 * 1024));
	maxmem = (int)(USERSIZE >> 6) + USIZE;
	mmuinit();
	virtio_init();
}

/*
 * Icode is the bootstrap program executed in user mode
 * to bring up the system.
 */
int	icode[] =
{
	0xe3a00024,	/* mov r0, #init */
	0xe3a01040,	/* mov r1, #initp */
	0xe3a02000,	/* mov r2, #0 */
	0xe3a0700b,	/* mov r7, #exec */
	0xef000000,	/* svc #0 */
	0xe3a00001,	/* mov r0, #1 */
	0xe3a07001,	/* mov r7, #exit */
	0xef000000,	/* svc #0 */
	0xeafffffe,	/* b . */
	0x6374652f,	/* init: </etc/init\0> */
	0x696e692f,
	0x00000074,
	0x00000000,
	0x00000000,
	0x00000000,
	0x00000000,
	0x00000024,	/* initp: init; 0 */
	0x00000000,
};
int	szicode = sizeof(icode);

unsigned int l1[4096] __attribute__((aligned(16384)));

void mmuinit(void)
{
	unsigned int pa;

	for(unsigned int i = 0; i < 4096; i++) l1[i] = 0;
#ifdef EVB
	for(pa=0x40000000U; pa<0x50000000U; pa+=0x00100000U)
		l1[pa>>20] = (pa & 0xfff00000U) | 0x00000402U;
	for(pa=0xC0000000U; pa<0xE0000000U; pa+=0x00100000U)
		l1[pa>>20] = (pa & 0xfff00000U) | 0x00000402U;
	l1[0] = 0xC8000000U | 0x00000c02U;
#else
	for(pa=KERNBASE; pa<0x48000000U; pa+=0x00100000U)
		l1[pa>>20] = (pa & 0xfff00000U) | 0x00000402U;
	for(pa=0x08000000U; pa<0x0c000000U; pa+=0x00100000U)
		l1[pa>>20] = (pa & 0xfff00000U) | 0x00000402U;
	l1[0] = USERPHYS | 0x00000c02U;
#endif
	mmu_on((unsigned int)l1);
}

void
install_sigtramp(char *base)
{
	volatile unsigned int *t = (volatile unsigned int *)(base + UENTRY_SIGTRAMP);

	t[0] = 0xe3a0708bU;
	t[1] = 0xef000000U;
}

void
arm_sync_icache(void)
{
	unsigned int zero = 0;

	__asm__ volatile(
	    "dsb ish\n\t"
	    "mcr p15, 0, %0, c7, c5, 0\n\t"
	    "mcr p15, 0, %0, c7, c5, 6\n\t"
	    "dsb ish\n\t"
	    "isb"
	    :
	    : "r"(zero)
	    : "memory");
}

void
panictrap(void)
{
	panic("trap");
}
