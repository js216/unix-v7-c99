/* Ported from v7/usr/src/cmd/umount.c with K&R -> C99 prototype
 * conversion, register dropped, void casts on discarded syscall
 * returns.  Algorithm preserved. */

#define	NMOUNT	16
#define	NAMSIZ	32

#include <stdio.h>

struct mtab {
	char	file[NAMSIZ];
	char	spec[NAMSIZ];
} mtab[NMOUNT];

extern int umount(char *);
extern void perror(char *);

int
main(int argc, char **argv)
{
	struct mtab *mp;
	char *p1, *p2;
	int mf;

	(void)sync();
	mf = open("/etc/mtab", 0);
	(void)read(mf, (char *)mtab, NMOUNT * 2 * NAMSIZ);
	if(argc != 2) {
		printf("arg count\n");
		return(1);
	}
	if(umount(argv[1]) < 0) {
		perror("umount");
		return(1);
	}
	p1 = argv[1];
	while(*p1++)
		;
	p1--;
	while(*--p1 == '/')
		*p1 = '\0';
	while(p1 > argv[1] && *--p1 != '/')
		;
	if(*p1 == '/')
		p1++;
	argv[1] = p1;
	for(mp = mtab; mp < &mtab[NMOUNT]; mp++) {
		p1 = argv[1];
		p2 = &mp->spec[0];
		while(*p1++ == *p2)
			if(*p2++ == 0) {
				for(p1 = mp->file; p1 < &mp->file[NAMSIZ*2];)
					*p1++ = 0;
				mp = &mtab[NMOUNT];
				while((--mp)->file[0] == 0)
					;
				mf = creat("/etc/mtab", 0644);
				(void)write(mf, (char *)mtab, (mp - mtab + 1) * 2 * NAMSIZ);
				return(0);
			}
	}
	printf("%s not in mount table\n", argv[1]);
	return(1);
}
