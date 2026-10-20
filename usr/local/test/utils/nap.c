#include <stdio.h>
#include <sys/param.h>
#include <sys/times.h>

/*
 * nap: pause until this process has been charged with three clock
 * ticks, about 50 ms, or longer while others run.
 */
int
main(void)
{
	struct tms tb;

	do
		times(&tb);
	while (tb.tms_utime + tb.tms_stime < 3);
	return 0;
}
