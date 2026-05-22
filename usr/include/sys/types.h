#ifndef SYS_TYPES_H
#define SYS_TYPES_H
typedef	long		daddr_t;
typedef	char *		caddr_t;
typedef	unsigned short	ino_t;
typedef	long		time_t;
/* Mirror of the kernel h/param.h label_t (R4..R11 + sp + lr); needed
 * by cmd/ps and pstat through "../h/user.h". */
typedef	int		label_t[10];
typedef	int		dev_t;
typedef	long		off_t;
#endif
