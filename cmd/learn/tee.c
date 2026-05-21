int creat(char *path, int mode);
int read(int fd, char *buf, int n);
int write(int fd, char *buf, int n);
int close(int fd);

void put(int c, int f);
void fl(int f);

int
main(void)
{
	int f, c;

	f = creat(".ocopy", 0666);
	while (read(0, (char *)&c, 1) == 1) {
		write (1, (char *)&c, 1);
		put(c, f);
	}
	fl(f);
	close(f);
	return 0;
}

static char ln[512];
char *p = ln;

void
put(int c, int f)
{
	*p++ = c;
	if (c == '\n') {
		fl(f);
		p=ln;
	}
}

void
fl(int f)
{
	register char *s;

	s = ln;
	while (*s == '$' && *(s+1) == ' ')
		s += 2;
	write(f, s, p-s);
}
