/*
 * chgrp [-R] gid file ...
 */

#include <stdio.h>
#include <ctype.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/dir.h>
#include <grp.h>

struct	group	*gr,*getgrnam();
struct	stat	stbuf;
int	gid;
int	status;
int	rflag;
int	isnumber(char *s);
int	do_chgrp(char *p);

int
main(int argc, char *argv[])
{
	register int c;
	int start = 1;

	if (argc >= 2 && argv[1][0] == '-' && argv[1][1] == 'R' &&
	    argv[1][2] == '\0') {
		rflag = 1;
		start = 2;
	}
	if (argc < start + 2) {
		printf("usage: chgrp [-R] gid file ...\n");
		exit(4);
	}
	if (isnumber(argv[start])) {
		gid = atoi(argv[start]);
	} else {
		if ((gr = getgrnam(argv[start])) == NULL) {
			printf("unknown group: %s\n", argv[start]);
			exit(4);
		}
		gid = gr->gr_gid;
	}
	for (c = start + 1; c < argc; c++)
		status += do_chgrp(argv[c]);
	exit(status ? 1 : 0);
}

int
do_chgrp(char *p)
{
	struct direct dent;
	FILE *df;
	int errs = 0, i, j;
	char child[256];

	if (stat(p, &stbuf) < 0) {
		perror(p);
		return 1;
	}
	if (chown(p, stbuf.st_uid, gid) < 0) {
		perror(p);
		errs++;
	}
	if (rflag && (stbuf.st_mode & S_IFMT) == S_IFDIR) {
		if ((df = fopen(p, "r")) == NULL)
			return errs;
		while (fread((char *)&dent, sizeof(dent), 1, df) == 1) {
			if (dent.d_ino == 0) continue;
			if (dent.d_name[0] == '.' &&
			    (dent.d_name[1] == '\0' ||
			     (dent.d_name[1] == '.' && dent.d_name[2] == '\0')))
				continue;
			for (i = 0; p[i] && i < 200; i++) child[i] = p[i];
			if (i > 0 && child[i-1] != '/') child[i++] = '/';
			for (j = 0; j < DIRSIZ && dent.d_name[j]; j++) child[i++] = dent.d_name[j];
			child[i] = '\0';
			errs += do_chgrp(child);
		}
		fclose(df);
	}
	return errs;
}

int
isnumber(char *s)
{
	register int c;

	while (c = *s++)
		if (!isdigit(c))
			return(0);
	return(1);
}
