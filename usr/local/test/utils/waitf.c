#include <stdio.h>
#include <sys/param.h>
#include <sys/stat.h>
#include <sys/times.h>

/*
 * waitf file...: wait until every file exists and is not empty,
 * giving up after 30 seconds.  It polls without pause until it has
 * used 12 clock ticks, which catches a quick process within a few
 * milliseconds, and then once a second, so as not to take the
 * processor from a busy one.
 */
int
main(int argc, char **argv)
{
	struct stat sb;
	struct tms tb;
	time_t t;
	int i;

	t = time(0);
	for (i = 1; i < argc; )
		if (stat(argv[i], &sb) == 0 && sb.st_size > 0)
			i++;
		else if (time(0) > t + 30)
			return 1;
		else if (times(&tb), tb.tms_utime + tb.tms_stime >= 12)
			sleep(1);
	return 0;
}
