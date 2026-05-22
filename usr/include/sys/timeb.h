#ifndef SYS_TIMEB_H
#define SYS_TIMEB_H
#include <sys/types.h>
/*
 * Structure returned by ftime system call
 */
struct timeb {
	time_t	time;
	unsigned short millitm;
	short	timezone;
	short	dstflag;
};
#endif
