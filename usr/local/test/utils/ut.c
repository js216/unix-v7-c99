#include <stdio.h>
#include <sys/types.h>
#include <sys/stat.h>

int
main(int argc, char **argv)
{
	struct stat sb;
	time_t tv[2];

	if (argc > 3) {
		sscanf(argv[2], "%lld", &tv[0]);
		sscanf(argv[3], "%lld", &tv[1]);
		if (utime(argv[1], tv) < 0)
			printf("utime failed\n");
	}
	if (stat(argv[1], &sb) < 0) {
		printf("stat failed\n");
		return 1;
	}
	printf("%lld %s", sb.st_mtime, ctime(&sb.st_mtime));
	return 0;
}
