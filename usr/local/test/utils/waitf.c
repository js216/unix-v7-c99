#include <stdio.h>
#include <sys/param.h>
#include <sys/stat.h>

/*
 * waitf file...: wait until every file exists and is not empty,
 * giving up after 30 seconds.  It sleeps a second between looks.
 * Spinning would not let the process it waits for in sooner: the
 * clock reschedules only once a second, so a busy loop would keep
 * the processor until then.
 */
int
main(int argc, char **argv)
{
	struct stat sb;
	time_t t;
	int i;

	t = time(0);
	for (i = 1; i < argc; )
		if (stat(argv[i], &sb) == 0 && sb.st_size > 0)
			i++;
		else if (time(0) > t + 30)
			return 1;
		else
			sleep(1);
	return 0;
}
