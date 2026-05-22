/*
 * chmod [ugoa][+-=][rwxstugo] files
 *  change mode of files
 */
#include <stdio.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/dir.h>

#define	USER	05700	/* user's bits */
#define	GROUP	02070	/* group's bits */
#define	OTHER	00007	/* other's bits */
#define	ALL	01777	/* all (note absence of setuid, etc) */

#define	READ	00444	/* read permit */
#define	WRITE	00222	/* write permit */
#define	EXEC	00111	/* exec permit */
#define	SETID	06000	/* set[ug]id */
#define	STICKY	01000	/* sticky bit */

char	*ms;
int	um;
struct	stat st;
int	rflag;
char	*spec;	/* original mode argument; re-bound to ms before each newmode() */
unsigned newmode(unsigned nm);
int abs(void);
int who(void);
int what(void);
int where(int om);
int do_chmod(char *p);

int
main(int argc, char **argv)
{
	register int i;
	int status = 0;
	int start = 1;

	if (argc >= 2 && argv[1][0] == '-' && argv[1][1] == 'R' &&
	    argv[1][2] == '\0') {
		rflag = 1;
		start = 2;
	}
	if (argc < start + 2) {
		fprintf(stderr, "Usage: chmod [-R] [ugoa][+-=][rwxstugo] file ...\n");
		exit(255);
	}
	spec = argv[start];
	ms = spec;
	um = umask(0);
	newmode(0);
	for (i = start + 1; i < argc; i++) {
		status += do_chmod(argv[i]);
	}
	exit(status);
}

/* Apply the mode change to p; if -R and p is a dir, recurse into entries. */
int
do_chmod(char *p)
{
	struct direct dent;
	FILE *df;
	int errs = 0;
	char child[256];
	int i, j;

	if (stat(p, &st) < 0) {
		fprintf(stderr, "chmod: can't access %s\n", p);
		return 1;
	}
	ms = spec;
	if (chmod(p, newmode(st.st_mode)) < 0) {
		fprintf(stderr, "chmod: can't change %s\n", p);
		errs++;
	}
	if (rflag && (st.st_mode & S_IFMT) == S_IFDIR) {
		if ((df = fopen(p, "r")) == NULL)
			return errs;
		while (fread((char *)&dent, sizeof(dent), 1, df) == 1) {
			if (dent.d_ino == 0) continue;
			if (dent.d_name[0] == '.' &&
			    (dent.d_name[1] == '\0' || (dent.d_name[1] == '.' && dent.d_name[2] == '\0')))
				continue;
			for (i = 0; p[i] && i < 200; i++) child[i] = p[i];
			if (i > 0 && child[i-1] != '/') child[i++] = '/';
			for (j = 0; j < DIRSIZ && dent.d_name[j]; j++) child[i++] = dent.d_name[j];
			child[i] = '\0';
			errs += do_chmod(child);
		}
		fclose(df);
	}
	return errs;
}

unsigned
newmode(unsigned nm)
{
	register int o, m, b;

	m = abs();
	if (!*ms)
		return(m);
	do {
		m = who();
		while ((o = what())) {
			b = where(nm);
			switch (o) {
			case '+':
				nm |= b & m;
				break;
			case '-':
				nm &= ~(b & m);
				break;
			case '=':
				nm &= ~m;
				nm |= b & m;
				break;
			}
		}
	} while (*ms++ == ',');
	if (*--ms) {
		fprintf(stderr, "chmod: invalid mode\n");
		exit(255);
	}
	return(nm);
}

int
abs(void)
{
	register int c, i;

	i = 0;
	while ((c = *ms++) >= '0' && c <= '7')
		i = (i << 3) + (c - '0');
	ms--;
	return(i);
}

int
who(void)
{
	register int m;

	m = 0;
	for (;;) switch (*ms++) {
	case 'u':
		m |= USER;
		continue;
	case 'g':
		m |= GROUP;
		continue;
	case 'o':
		m |= OTHER;
		continue;
	case 'a':
		m |= ALL;
		continue;
	default:
		ms--;
		if (m == 0)
			m = ALL & ~um;
		return m;
	}
}

int
what(void)
{
	switch (*ms) {
	case '+':
	case '-':
	case '=':
		return *ms++;
	}
	return(0);
}

int
where(int om)
{
	register int m;

	m = 0;
	switch (*ms) {
	case 'u':
		m = (om & USER) >> 6;
		goto dup;
	case 'g':
		m = (om & GROUP) >> 3;
		goto dup;
	case 'o':
		m = (om & OTHER);
	dup:
		m &= (READ|WRITE|EXEC);
		m |= (m << 3) | (m << 6);
		++ms;
		return m;
	}
	for (;;) switch (*ms++) {
	case 'r':
		m |= READ;
		continue;
	case 'w':
		m |= WRITE;
		continue;
	case 'x':
		m |= EXEC;
		continue;
	case 's':
		m |= SETID;
		continue;
	case 't':
		m |= STICKY;
		continue;
	default:
		ms--;
		return m;
	}
}
