#include <stdio.h>

extern int errno;
char buf[65536];

static unsigned *
phdr(int k)
{
	unsigned off = *(unsigned *)&buf[28];
	int i, n = *(short *)&buf[44];

	for (i = 0; i < n; i++, off += 32)
		if (*(unsigned *)&buf[off] == 1 && k-- == 0)
			return (unsigned *)&buf[off];
	return 0;
}

static void
try(char *name, int len)
{
	int fd, st;

	fd = creat(name, 0755);
	write(fd, buf, len);
	close(fd);
	fflush(stdout);
	if (fork() == 0) {
		execl(name, name, "ran", (char *)0);
		printf("%s: errno %d\n", name, errno);
		exit(0);
	}
	wait(&st);
	printf("%s: status %d\n", name, st);
	unlink(name);
}

int
main(int argc, char **argv)
{
	int fd, len;
	unsigned *t, *d, save;

	(void)argc;
	fd = open(argv[1], 0);
	len = read(fd, buf, sizeof(buf));
	close(fd);
	t = phdr(0);
	d = phdr(1);
	try("short", 52);
	save = d[4];
	d[4] = d[5] + 4096;
	try("bigdata", len);
	d[4] = save;
	t[2] = 4096;
	t[4] = 0;
	try("notext", len);
	return 0;
}
