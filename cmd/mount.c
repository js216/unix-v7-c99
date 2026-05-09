/* Ported from v7/usr/src/cmd/mount.c with K&R -> C99 prototype
 * conversion, register dropped, void casts on discarded returns.
 * Algorithm and order of operations are unchanged.  /etc/mtab
 * bookkeeping is preserved; the mount(2) syscall it relies on is
 * the kernel's S_MOUNT (currently a record-only stub on the
 * single-image port). */

#include <stdio.h>

#define	NMOUNT	16
#define	NAMSIZ	32

struct mtab {
	char	file[NAMSIZ];
	char	spec[NAMSIZ];
} mtab[NMOUNT];

extern int mount(char *, char *, int);
extern void perror(char *);

int
main(int argc, char **argv)
{
	int ro;
	struct mtab *mp;
	char *np;
	int mf;

	mf = open("/etc/mtab", 0);
	(void)read(mf, (char *)mtab, NMOUNT * 2 * NAMSIZ);
	if(argc == 1) {
		for(mp = mtab; mp < &mtab[NMOUNT]; mp++)
			if(mp->file[0])
				printf("%s on %s\n", mp->spec, mp->file);
		exit(0);
	}
	if(argc < 3) {
		fprintf(stderr, "arg count\n");
		exit(1);
	}
	ro = 0;
	if(argc > 3)
		ro++;
	if(mount(argv[1], argv[2], ro) < 0) {
		perror("mount");
		exit(1);
	}
	np = argv[1];
	while(*np++)
		;
	np--;
	while(*--np == '/')
		*np = '\0';
	while(np > argv[1] && *--np != '/')
		;
	if(*np == '/')
		np++;
	argv[1] = np;
	for(mp = mtab; mp < &mtab[NMOUNT]; mp++) {
		if(mp->file[0] == 0) {
			for(np = mp->spec; np < &mp->spec[NAMSIZ-1];)
				if((*np++ = *argv[1]++) == 0)
					argv[1]--;
			for(np = mp->file; np < &mp->file[NAMSIZ-1];)
				if((*np++ = *argv[2]++) == 0)
					argv[2]--;
			mp = &mtab[NMOUNT];
			while((--mp)->file[0] == 0)
				;
			mf = creat("/etc/mtab", 0644);
			(void)write(mf, (char *)mtab, (mp - mtab + 1) * 2 * NAMSIZ);
			exit(0);
		}
	}
	exit(0);
	return(0);
}
