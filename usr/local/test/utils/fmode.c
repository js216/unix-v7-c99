#include <stdio.h>
#include <sys/types.h>
#include <sys/stat.h>

int
main(int argc, char **argv)
{
	struct stat s;

	if (argc < 2 || stat(argv[1], &s) < 0)
		return 1;
	printf("%o\n", s.st_mode & 07777);
	return 0;
}
