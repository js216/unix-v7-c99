#include <stdio.h>
#include <signal.h>

extern int errno;
void catch(int sig);

void
catch(int sig)
{
	printf("store into text: signal %d\n", sig);
	exit(0);
}

int
main(void)
{
	char *t = "text";
	int fd, r;

	fd = open("/etc/passwd", 0);
	errno = 0;
	r = read(fd, t, 4);
	printf("read into text: %d errno %d, text %s\n", r, errno, t);
	signal(SIGSEGV, catch);
	*t = 'x';
	printf("store into text succeeded\n");
	return 0;
}
