/*
 * Make a file system prototype.
 * usage: mkfs filsys proto/size [ m n ]
 */
#define	NIPB	(BSIZE/sizeof(struct dinode))
#define	NINDIR	(BSIZE/sizeof(daddr_t))
#define	NDIRECT	(BSIZE/sizeof(struct direct))
#define	LADDR	10
#define	MAXFILEBLK	(LADDR+NINDIR+(NINDIR*NINDIR))
#define	MAXFN	500
#define	itoo(x)	(int)((x+15)&07)
#ifndef STANDALONE
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <time.h>
#endif
#include "../../include/sys/param.h"
#include "../../include/sys/ino.h"
#include "../../include/sys/inode.h"
#include "../../include/sys/filsys.h"
#include "../../include/sys/fblk.h"
#include "../../include/sys/dir.h"
/* Pack longs into pure LE 24-bit; matches arch/arm.c::addr(). */
int ltol3(cp, lp, n) char *cp; long *lp; int n; {
	int i; long v;
	for(i=0; i<n; i++) {
		v = lp[i];
		*cp++ = v; *cp++ = v >> 8; *cp++ = v >> 16;
	}
	return(0);
}
time_t	utime;
#ifndef STANDALONE
FILE 	*fin;
#else
int	fin;
#endif
int	fsi;
int	fso;
char	*charp;
char	buf[BSIZE];
/* The v7 K&R-era "anonymous struct as union member" idiom (`struct fblk;`
 * inside a union) is not strict C99.  Named members + macro aliases keep
 * the call-site spelling (`fbuf.df_nfree`, `filsys.s_fsize`) unchanged. */
union fbuf_u {
	struct fblk fb;
	char pad1[BSIZE];
} fbuf_storage;
#define fbuf fbuf_storage.fb
char	string[50];
union filsys_u {
	struct filsys fs;
	char pad2[BSIZE];
} filsys_storage;
#define filsys filsys_storage.fs
char	*fsys;
char	*proto;
int	f_n	= MAXFN;
int	f_m	= 3;
int	error;
ino_t	ino;
struct	inode;
long	getnum(void);
daddr_t	alloc(void);
void	cfile(struct inode *par);
void	getstr(void);
int	gmode(int c, char *s, int m0, int m1, int m2, int m3);
void	rdfs(daddr_t bno, char *bf);
void	wtfs(daddr_t bno, char *bf);
void	bfree(daddr_t bno);
void	entry(ino_t inum, char *str, int *adbc, char *db, int *aibc, daddr_t *ib);
void	newblk(int *adbc, char *db, int *aibc, daddr_t *ib);
int	getch(void);
void	bflist(void);
void	iput(struct inode *ip, int *aibc, daddr_t *ib);
int	badblk(daddr_t bno);

int
main(int argc, char *argv[])
{
	int f, c;
	long n;

#ifndef STANDALONE
	time(&utime);
	if(argc < 3) {
		printf("usage: mkfs filsys proto/size [ m n ]\n");
		exit(1);
	}
	fsys = argv[1];
	proto = argv[2];
#else
	{
		static char protos[60];

		printf("file sys size: ");
		gets(protos);
		proto = protos;
	}
#endif
#ifdef STANDALONE
	{
		char fsbuf[100];

		do {
			printf("file system: ");
			gets(fsbuf);
			fso = open(fsbuf, 1);
			fsi = open(fsbuf, 0);
		} while (fso < 0 || fsi < 0);
	}
	fin = NULL;
	argc = 0;
#else
	fso = creat(fsys, 0666);
	if(fso < 0) {
		printf("%s: cannot create\n", fsys);
		exit(1);
	}
	fsi = open(fsys, 0);
	if(fsi < 0) {
		printf("%s: cannot open\n", fsys);
		exit(1);
	}
	fin = fopen(proto, "r");
#endif
	if(fin == NULL) {
		n = 0;
		for(f=0; (c=proto[f]); f++) {
			if(c<'0' || c>'9') {
				printf("%s: cannot open\n", proto);
				exit(1);
			}
			n = n*10 + (c-'0');
		}
		filsys.s_fsize = n;
		n = n/25;
		if(n <= 0)
			n = 1;
		if((unsigned long)n > 65500/NIPB)
			n = 65500/NIPB;
		filsys.s_isize = n + 2;
		printf("isize = %ld\n", n*NIPB);
		charp = "d--777 0 0 $ ";
		goto f3;
	}

#ifndef STANDALONE
	/*
	 * get name of boot load program
	 * (skipped: PDP-11 a.out format is not used on this port)
	 */

	getstr();
	f = open(string, 0);
	if(f < 0)
		printf("%s: cannot open init\n", string);
	else

		close(f);

	/*
	 * get total disk size
	 * and inode block size
	 */

	filsys.s_fsize = getnum();
	n = getnum();
	n /= NIPB;
	filsys.s_isize = n + 3;

#endif
f3:
	if(argc >= 5) {
		f_m = atoi(argv[3]);
		f_n = atoi(argv[4]);
		if(f_n <= 0 || f_n >= MAXFN)
			f_n = MAXFN;
		if(f_m <= 0 || f_m > f_n)
			f_m = 3;
	}
	filsys.s_m = f_m;
	filsys.s_n = f_n;
	printf("m/n = %d %d\n", f_m, f_n);
	if(filsys.s_isize >= filsys.s_fsize) {
		printf("%ld/%d: bad ratio\n", filsys.s_fsize, filsys.s_isize-2);
		exit(1);
	}
	filsys.s_tfree = 0;
	filsys.s_tinode = 0;
	for(c=0; c<BSIZE; c++)
		buf[c] = 0;
	for(n=2; n!=filsys.s_isize; n++) {
		wtfs(n, buf);
		filsys.s_tinode += NIPB;
	}
	ino = 0;

	bflist();

	cfile((struct inode *)0);

	filsys.s_time = utime;
	wtfs((long)1, (char *)&filsys);
	exit(error);
}

void
cfile(struct inode *par)
{
	struct inode in;
	int dbc, ibc;
	char db[BSIZE];
	daddr_t ib[MAXFILEBLK];
	int i, f, c;

	/*
	 * get mode, uid and gid
	 */

	getstr();
	in.i_mode = gmode(string[0], "-bcd", IFREG, IFBLK, IFCHR, IFDIR);
	in.i_mode |= gmode(string[1], "-u", 0, ISUID, 0, 0);
	in.i_mode |= gmode(string[2], "-g", 0, ISGID, 0, 0);
	for(i=3; i<6; i++) {
		c = string[i];
		if(c<'0' || c>'7') {
			printf("%c/%s: bad octal mode digit\n", c, string);
			error = 1;
			c = 0;
		}
		in.i_mode |= (c-'0')<<(15-3*i);
	}
	in.i_uid = getnum();
	in.i_gid = getnum();

	/*
	 * general initialization prior to
	 * switching on format
	 */

	ino++;
	in.i_number = ino;
	for(i=0; i<BSIZE; i++)
		db[i] = 0;
	for(i=0; (unsigned)i<MAXFILEBLK; i++)
		ib[i] = (daddr_t)0;
	in.i_nlink = 1;
	in.i_size = 0;
	for(i=0; i<NADDR; i++)
		in.i_un.i_addr[i] = (daddr_t)0;
	if(par == (struct inode *)0) {
		par = &in;
		in.i_nlink--;
	}
	dbc = 0;
	ibc = 0;
	switch(in.i_mode&IFMT) {

	case IFREG:
		/*
		 * regular file
		 * contents is a file name
		 */

		getstr();
		f = open(string, 0);
		if(f < 0) {
			printf("%s: cannot open\n", string);
			error = 1;
			break;
		}
		while((i=read(f, db, BSIZE)) > 0) {
			in.i_size += i;
			newblk(&dbc, db, &ibc, ib);
		}
		close(f);
		break;

	case IFBLK:
	case IFCHR:
		/*
		 * special file
		 * content is maj/min types
		 */

		i = getnum() & 0377;
		f = getnum() & 0377;
		in.i_un.i_addr[0] = (i<<8) | f;
		break;

	case IFDIR:
		/*
		 * directory
		 * put in extra links
		 * call recursively until
		 * name of "$" found
		 */

		par->i_nlink++;
		in.i_nlink++;
		entry(in.i_number, ".", &dbc, db, &ibc, ib);
		entry(par->i_number, "..", &dbc, db, &ibc, ib);
		in.i_size = 2*sizeof(struct direct);
		for(;;) {
			getstr();
			if(string[0]=='$' && string[1]=='\0')
				break;
			entry(ino+1, string, &dbc, db, &ibc, ib);
			in.i_size += sizeof(struct direct);
			cfile(&in);
		}
		break;
	}
	if(dbc != 0)
		newblk(&dbc, db, &ibc, ib);
	iput(&in, &ibc, ib);
}

int
gmode(int c, char *s, int m0, int m1, int m2, int m3)
{
	int i;
	int m[4] = {m0, m1, m2, m3};

	for(i=0; s[i]; i++)
		if(c == s[i])
			return(m[i]);
	printf("%c/%s: bad mode\n", c, string);
	error = 1;
	return(0);
}

long
getnum(void)
{
	int i, c;
	long n;

	getstr();
	n = 0;
	i = 0;
	for(i=0; (c=string[i]) != 0; i++) {
		if(c<'0' || c>'9') {
			printf("%s: bad number\n", string);
			error = 1;
			return((long)0);
		}
		n = n*10 + (c-'0');
	}
	return(n);
}

void
getstr(void)
{
	int i, c;

loop:
	switch(c=getch()) {

	case ' ':
	case '\t':
	case '\n':
		goto loop;

	case '\0':
		printf("EOF\n");
		exit(1);

	case ':':
		while(getch() != '\n');
		goto loop;

	}
	i = 0;

	do {
		string[i++] = c;
		c = getch();
	} while(c!=' '&&c!='\t'&&c!='\n'&&c!='\0');
	string[i] = '\0';
}

void
rdfs(daddr_t bno, char *bf)
{
	int n;

	lseek(fsi, bno*BSIZE, 0);
	n = read(fsi, bf, BSIZE);
	if(n != BSIZE) {
		printf("read error: %ld\n", bno);
		exit(1);
	}
}

void
wtfs(daddr_t bno, char *bf)
{
	int n;

	lseek(fso, bno*BSIZE, 0);
	n = write(fso, bf, BSIZE);
	if(n != BSIZE) {
		printf("write error: %ld\n", bno);
		exit(1);
	}
}

daddr_t
alloc(void)
{
	int i;
	daddr_t bno;

	filsys.s_tfree--;
	bno = filsys.s_free[--filsys.s_nfree];
	if(bno == 0) {
		printf("out of free space\n");
		exit(1);
	}
	if(filsys.s_nfree <= 0) {
		rdfs(bno, (char *)&fbuf);
		filsys.s_nfree = fbuf.df_nfree;
		for(i=0; i<NICFREE; i++)
			filsys.s_free[i] = fbuf.df_free[i];
	}
	return(bno);
}

void
bfree(daddr_t bno)
{
	int i;

	filsys.s_tfree++;
	if(filsys.s_nfree >= NICFREE) {
		fbuf.df_nfree = filsys.s_nfree;
		for(i=0; i<NICFREE; i++)
			fbuf.df_free[i] = filsys.s_free[i];
		wtfs(bno, (char *)&fbuf);
		filsys.s_nfree = 0;
	}
	filsys.s_free[filsys.s_nfree++] = bno;
}

void
entry(ino_t inum, char *str, int *adbc, char *db, int *aibc, daddr_t *ib)
{
	struct direct *dp;
	int i;

	dp = (struct direct *)db;
	dp += *adbc;
	(*adbc)++;
	dp->d_ino = inum;
	for(i=0; i<DIRSIZ; i++)
		dp->d_name[i] = 0;
	for(i=0; i<DIRSIZ; i++)
		if((dp->d_name[i] = str[i]) == 0)
			break;
	if((unsigned)*adbc >= NDIRECT)
		newblk(adbc, db, aibc, ib);
}

void
newblk(int *adbc, char *db, int *aibc, daddr_t *ib)
{
	int i;
	daddr_t bno;

	if((unsigned)*aibc >= MAXFILEBLK) {
		printf("indirect block full\n");
		error = 1;
		return;
	}
	bno = alloc();
	wtfs(bno, db);
	for(i=0; i<BSIZE; i++)
		db[i] = 0;
	*adbc = 0;
	ib[*aibc] = bno;
	(*aibc)++;
}

int
getch(void)
{

#ifndef STANDALONE
	if(charp)
#endif
		return(*charp++);
#ifndef STANDALONE
	return(getc(fin));
#endif
}

void
bflist(void)
{
	struct inode in;
	daddr_t ib[NINDIR];
	int ibc;
	char flg[MAXFN];
	int adr[MAXFN];
	int i, j;
	daddr_t f, d;

	for(i=0; i<f_n; i++)
		flg[i] = 0;
	i = 0;
	for(j=0; j<f_n; j++) {
		while(flg[i])
			i = (i+1)%f_n;
		adr[j] = i+1;
		flg[i]++;
		i = (i+f_m)%f_n;
	}

	ino++;
	in.i_number = ino;
	in.i_mode = IFREG;
	in.i_uid = 0;
	in.i_gid = 0;
	in.i_nlink = 0;
	in.i_size = 0;
	for(i=0; i<NADDR; i++)
		in.i_un.i_addr[i] = (daddr_t)0;

	for(i=0; (unsigned)i<NINDIR; i++)
		ib[i] = (daddr_t)0;
	ibc = 0;
	bfree((daddr_t)0);
	d = filsys.s_fsize-1;
	while(d%f_n)
		d++;
	for(; d > 0; d -= f_n)
	for(i=0; i<f_n; i++) {
		f = d - adr[i];
		if(f < filsys.s_fsize && f >= filsys.s_isize) {
			if(badblk(f)) {
				if((unsigned)ibc >= NINDIR) {
					printf("too many bad blocks\n");
					error = 1;
					ibc = 0;
				}
				ib[ibc] = f;
				ibc++;
			} else
				bfree(f);
		}
	}
	iput(&in, &ibc, ib);
}

void
iput(struct inode *ip, int *aibc, daddr_t *ib)
{
	struct dinode *dp;
	daddr_t d, single[NINDIR], dbl[NINDIR];
	int i, j, k, n;

	filsys.s_tinode--;
	d = itod(ip->i_number);
	if(d >= filsys.s_isize) {
		if(error == 0)
			printf("ilist too small\n");
		error = 1;
		return;
	}
	rdfs(d, buf);
	dp = (struct dinode *)buf;
	dp += itoo(ip->i_number);

	dp->di_mode = ip->i_mode;
	dp->di_nlink = ip->i_nlink;
	dp->di_uid = ip->i_uid;
	dp->di_gid = ip->i_gid;
	dp->di_size = ip->i_size;
	dp->di_atime = utime;
	dp->di_mtime = utime;
	dp->di_ctime = utime;

	switch(ip->i_mode&IFMT) {

	case IFDIR:
	case IFREG:
		for(i=0; (unsigned)i<NINDIR; i++) {
			single[i] = (daddr_t)0;
			dbl[i] = (daddr_t)0;
		}
		for(i=0; i<*aibc && i<LADDR; i++)
			ip->i_un.i_addr[i] = ib[i];
		if((unsigned)*aibc > LADDR) {
			n = *aibc - LADDR;
			if((unsigned)n > NINDIR)
				n = (int)NINDIR;
			for(i=0; i<n; i++)
				single[i] = ib[LADDR+i];
			ip->i_un.i_addr[LADDR] = alloc();
			wtfs(ip->i_un.i_addr[LADDR], (char *)single);
		}
		if((unsigned)*aibc > LADDR+NINDIR) {
			n = *aibc - LADDR - NINDIR;
			if((unsigned)n > NINDIR*NINDIR) {
				printf("indirect block full\n");
				error = 1;
				n = (int)(NINDIR*NINDIR);
			}
			ip->i_un.i_addr[LADDR+1] = alloc();
			k = LADDR + NINDIR;
			for(i=0; (unsigned)i<NINDIR && n>0; i++) {
				for(j=0; (unsigned)j<NINDIR; j++)
					single[j] = (daddr_t)0;
				for(j=0; (unsigned)j<NINDIR && n>0; j++) {
					single[j] = ib[k++];
					n--;
				}
				dbl[i] = alloc();
				wtfs(dbl[i], (char *)single);
			}
			wtfs(ip->i_un.i_addr[LADDR+1], (char *)dbl);
		}
		/* fall through */

	case IFBLK:
	case IFCHR:
		ltol3(dp->di_addr, ip->i_un.i_addr, NADDR);
		break;

	default:
		printf("bad mode %o\n", ip->i_mode);
		exit(1);
	}
	wtfs(d, buf);
}

int
badblk(daddr_t bno)
{

	(void)bno;
	return(0);
}
