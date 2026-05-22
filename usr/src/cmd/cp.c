/*
 * cp oldfile newfile
 * cp f1 ... fn dir
 * cp -r src dir       (recursive)
 */

#define	BSIZE	512
#include <stdio.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/dir.h>
extern int mkdir(char *path, int mode);

struct	stat	stbuf1, stbuf2;
char	iobuf[BSIZE];
int	rflag;

int copy(char *from, char *to);
int copyfile(char *from, char *to);
int copydir(char *from, char *to);

int
main(int argc, char *argv[])
{
	register int i, r;
	int start = 1;

	if (argc >= 2 && argv[1][0] == '-' && argv[1][1] == 'r' &&
	    argv[1][2] == '\0') {
		rflag = 1;
		start = 2;
	}
	if (argc < start + 2)
		goto usage;
	if (argc > start + 2) {
		if (stat(argv[argc-1], &stbuf2) < 0)
			goto usage;
		if ((stbuf2.st_mode&S_IFMT) != S_IFDIR)
			goto usage;
	}
	r = 0;
	for (i = start; i < argc - 1; i++)
		r |= copy(argv[i], argv[argc-1]);
	exit(r);
usage:
	fprintf(stderr, "Usage: cp [-r] f1 f2; or cp [-r] f1 ... fn d2\n");
	exit(1);
}

/* Dispatch to file or directory copy; if target is a dir, append the
 * source basename so cp foo bar/  ->  bar/foo (matching v7 behavior). */
int
copy(char *from, char *to)
{
	static char dest[256];
	register char *p1, *p2, *bp;
	if (stat(from, &stbuf1) < 0) {
		fprintf(stderr, "cp: cannot stat %s\n", from);
		return 1;
	}
	if (stat(to, &stbuf2) >= 0 && (stbuf2.st_mode & S_IFMT) == S_IFDIR) {
		p1 = from; p2 = to; bp = dest;
		while ((*bp++ = *p2++)) ;
		bp[-1] = '/';
		p2 = bp;
		while ((*bp = *p1++)) if (*bp++ == '/') bp = p2;
		to = dest;
	}
	if ((stbuf1.st_mode & S_IFMT) == S_IFDIR) {
		if (!rflag) {
			fprintf(stderr, "cp: %s is a directory (use -r)\n", from);
			return 1;
		}
		return copydir(from, to);
	}
	return copyfile(from, to);
}

int
copyfile(char *from, char *to)
{
	int fold, fnew, n;
	int mode;
	if ((fold = open(from, 0)) < 0) {
		fprintf(stderr, "cp: cannot open %s\n", from);
		return 1;
	}
	fstat(fold, &stbuf1);
	mode = stbuf1.st_mode;
	if (stat(to, &stbuf2) >= 0) {
		if (stbuf1.st_dev == stbuf2.st_dev &&
		    stbuf1.st_ino == stbuf2.st_ino) {
			fprintf(stderr, "cp: cannot copy file to itself.\n");
			close(fold);
			return 1;
		}
	}
	if ((fnew = creat(to, mode)) < 0) {
		fprintf(stderr, "cp: cannot create %s\n", to);
		close(fold);
		return 1;
	}
	while ((n = read(fold, iobuf, BSIZE))) {
		if (n < 0) {
			fprintf(stderr, "cp: read error\n");
			close(fold); close(fnew);
			return 1;
		}
		if (write(fnew, iobuf, n) != n) {
			fprintf(stderr, "cp: write error.\n");
			close(fold); close(fnew);
			return 1;
		}
	}
	close(fold); close(fnew);
	return 0;
}

int
copydir(char *from, char *to)
{
	struct direct dent;
	FILE *df;
	char src[256], dst[256];
	int errs = 0, i, j;

	/* Create the target dir.  If it exists already, that's fine. */
	if (stat(to, &stbuf2) < 0) {
		if (mkdir(to, 0755) < 0) {
			fprintf(stderr, "cp: cannot mkdir %s\n", to);
			return 1;
		}
	} else if ((stbuf2.st_mode & S_IFMT) != S_IFDIR) {
		fprintf(stderr, "cp: %s exists and is not a directory\n", to);
		return 1;
	}
	if ((df = fopen(from, "r")) == NULL) {
		fprintf(stderr, "cp: cannot read dir %s\n", from);
		return 1;
	}
	while (fread((char *)&dent, sizeof(dent), 1, df) == 1) {
		if (dent.d_ino == 0) continue;
		if (dent.d_name[0] == '.' &&
		    (dent.d_name[1] == '\0' ||
		     (dent.d_name[1] == '.' && dent.d_name[2] == '\0')))
			continue;
		for (i = 0; from[i] && i < 200; i++) src[i] = from[i];
		if (i > 0 && src[i-1] != '/') src[i++] = '/';
		for (j = 0; j < DIRSIZ && dent.d_name[j]; j++) src[i++] = dent.d_name[j];
		src[i] = '\0';
		for (i = 0; to[i] && i < 200; i++) dst[i] = to[i];
		if (i > 0 && dst[i-1] != '/') dst[i++] = '/';
		for (j = 0; j < DIRSIZ && dent.d_name[j]; j++) dst[i++] = dent.d_name[j];
		dst[i] = '\0';
		errs += copy(src, dst);
	}
	fclose(df);
	return errs;
}
