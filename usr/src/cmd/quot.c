/*
 * Disk usage by user
 */

char	*dargv[] = {
	"/dev/rrp3",
	0
};

#include <stdio.h>
#include <ctype.h>
#include <pwd.h>
#include <sys/param.h>
#include <sys/ino.h>
#include <sys/inode.h>
#include <sys/filsys.h>

#define	ITABSZ	256
#define	ISIZ	(BSIZE/sizeof(struct dinode))
#define	NUID	300
struct	filsys	sblock;
struct	dinode	itab[ITABSZ];
struct du
{
	long	blocks;
	long	nfiles;
	int	uid;
	char	*name;
} du[NUID];
#define	TSIZE	500
int	sizes[TSIZE];
long	overflow;

int	nflg;
int	fflg;
int	cflg;

int	fi;
unsigned	ino;
unsigned	nfiles;

char	*copy(char *s);
void	check(char *file), acct(struct dinode *ip);
void	bread(unsigned bno, char *buf, int cnt), report(void);

int
main(int argc, char **argv)
{
	register int n;
	register struct passwd *lp;
	register char **p;

	for(n=0; n<NUID; n++)
		du[n].uid = n;
	while((lp=getpwent()) != 0) {
		n = lp->pw_uid;
		if (n<0 || n>=NUID)
			continue;
		if(du[n].name)
			continue;
		du[n].name = copy(lp->pw_name);
	}
	if (argc == 1) {
		for (p = dargv; *p;) {
			check(*p++);
			report();
		}
		return(0);
	}
	while (--argc) {
		argv++;
		if (argv[0][0]=='-') {
			if (argv[0][1]=='n')
				nflg++;
			else if (argv[0][1]=='f')
				fflg++;
			else if (argv[0][1]=='c')
				cflg++;
		} else {
			check(*argv);
			report();
		}
	}
	return(0);
}

void
check(char *file)
{
	register unsigned i, j;
	register int c;
	struct du t;

	fi = open(file, 0);
	if (fi < 0) {
		printf("cannot open %s\n", file);
		return;
	}
	printf("%s:\n", file);
	for (i=0; i<NUID; i++) {
		while ((c = du[i].uid) != (int)i) {
			t = du[c];
			du[c] = du[i];
			du[i] = t;
		}
		du[i].blocks = du[i].nfiles = 0;
	}
	for (i=0; i<TSIZE; i++)
		sizes[i] = 0;
	overflow = 0;
	sync();
	bread(1, (char *)&sblock, sizeof sblock);
	nfiles = (sblock.s_isize-2)*(BSIZE/sizeof(struct dinode));
	ino = 0;
	if (nflg) {
		if (isdigit(c = getchar()))
			ungetc(c, stdin);
		else while (c!='\n' && c != EOF)
			c = getchar();
	}
	for(i=2; ino<nfiles; i += ITABSZ/ISIZ) {
		bread(i, (char *)itab, sizeof itab);
		for (j=0; j<ITABSZ && ino<nfiles; j++) {
			ino++;
			acct(&itab[j]);
		}
	}
}

void
acct(register struct dinode *ip)
{
	register int n;
	register char *np;
	static int fino;

	if ((ip->di_mode&IFMT) == 0 || ip->di_size < 0)
		return;
	if (cflg) {
		if ((ip->di_mode&IFMT)!=IFDIR && (ip->di_mode&IFMT)!=IFREG)
			return;
		n = ip->di_size/BSIZE + (ip->di_size%BSIZE != 0);
		if (n >= TSIZE) {
			overflow += n;
			n = TSIZE-1;
		}
		sizes[n]++;
		return;
	}
	if ((unsigned)ip->di_uid >= NUID)
		return;
	du[ip->di_uid].blocks += ip->di_size/BSIZE +
	    (ip->di_size%BSIZE != 0);
	du[ip->di_uid].nfiles++;
	if (nflg) {
	tryagain:
		if (fino==0)
			if (scanf("%d", &fino)<=0)
				return;
		if (fino > (int)ino)
			return;
		if (fino<(int)ino) {
			while ((n=getchar())!='\n' && n!=EOF)
				;
			fino = 0;
			goto tryagain;
		}
		if ((np = du[ip->di_uid].name))
			printf("%.7s	", np);
		else
			printf("%d	", ip->di_uid);
		while ((n = getchar())==' ' || n=='\t')
			;
		while (n!=EOF) {
			putchar(n);
			if (n=='\n')
				break;
			n = getchar();
		}
		fino = 0;
	}
}

void
bread(unsigned bno, char *buf, int cnt)
{

	lseek(fi, (long)bno*BSIZE, 0);
	if (read(fi, buf, cnt) != cnt) {
		printf("read error %u\n", bno);
		exit(1);
	}
}

static int
qcmp(char *a, char *b)
{
	register struct du *p1 = (struct du *)a, *p2 = (struct du *)b;
	if (p1->blocks > p2->blocks)
		return(-1);
	if (p1->blocks < p2->blocks)
		return(1);
	return(strcmp(p1->name? p1->name: "", p2->name? p2->name: ""));
}

void
report(void)
{
	register int i;

	if (nflg)
		return;
	if (cflg) {
		long t = 0;
		for (i=0; i<TSIZE-1; i++)
			if (sizes[i]) {
				t += i*sizes[i];
				printf("%d	%d	%D\n", i, sizes[i], t);
			}
		printf("%d	%d	%D\n", TSIZE-1, sizes[TSIZE-1], overflow+t);
		return;
	}
	qsort((char *)du, NUID, sizeof(du[0]), qcmp);
	for (i=0; i<NUID; i++) {
		if (du[i].blocks==0)
			return;
		printf("%5D\t", du[i].blocks);
		if (fflg)
			printf("%5D\t", du[i].nfiles);
		if (du[i].name)
			printf("%s\n", du[i].name);
		else
			printf("#%d\n", du[i].uid);
	}
}

char *
copy(char *s)
{
	register char *p;
	register int n;

	for(n=0; s[n]; n++)
		;
	p = malloc((unsigned)n+1);
	for(n=0; (p[n] = s[n]); n++)
		;
	return(p);
}
