#include "tp.h"
#include <stdio.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/dir.h>

int	rseek(), wseek(), tread(), twrite(), seekerr(), swabdir(),
	encode(), decode(), done(), bitmap(), fserr(), callout(),
	expand(), clrent();

struct direct	direct;
struct stat	statb;

int
clrdir()
{
	register int j, *p;

	j = ndirent * (DIRSZ/sizeof(int));
	p = (int *)dir;
	do (*p++ = 0);  while (--j);
	lastd = 0;
	return(0);
}

int
clrent(ptr)
struct	dent *ptr;
{
	register int *p, j;

	p  = (int *)ptr;
	j = DIRSZ/sizeof(int);
	do *p++ = 0;
	   while (--j);
	if (++ptr == lastd) do {
		if (--lastd < dir) {
			lastd = 0;
			return(0);
		}
	} while (lastd->d_namep == 0);
	return(0);
}


int
rddir()
{
	register struct tent *tp;
	register struct dent *p1;
	struct dent  *dptr;
	struct tent  *tptr;
	int	count, i, sum;
	short	reg, *sp;

	sum = 0;
	clrdir();
	rseek(0);
	tread();	/* Read the bootstrap block */
	if ((tpentry[TPB-1].cksum != 0) && (flags & flm)) {
		ndirent = tpentry[TPB-1].cksum;
		if(flags & fls) swab((char *)&ndirent, (char *)&ndirent, sizeof(ndirent));
		if(ndirent < 0 || ndirent > MDIRENT) ndirent = MDIRENT;
		ndentb = ndirent/TPB;
	}
	dptr = &dir[0];
	count = ndirent;
	do {
		if ((count % TPB) == 0) {	/* next block */
			tread();
			tptr = &tpentry[0];
		}
		if(flags & fls)
			swab((char *)tptr, (char *)tptr, sizeof(*tptr));
		sp = (short *)tptr;
		reg = 0;
		for(i=0;i<(int)(sizeof(struct tent)/sizeof(short));i++)
			reg += *sp++;
		if(flags & fls) {
			swab((char *)tptr, (char *)tptr, sizeof(*tptr));
			swabdir(tptr);
		}
		sum |= reg;
		p1 = dptr;
		if (reg == 0) {
			tp = tptr;
			if(tp->pathnam[0] != '\0') {
				lastd = p1;
				encode(tp->pathnam,p1);
				p1->d_mode = tp->mode;
				p1->d_uid = tp->uid;
				p1->d_gid = tp->gid;
				p1->d_size = (((long)tp->size0&0377L)<<16)+(tp->size1&0177777L);
				p1->d_time = tp->time;
				p1->d_tapea = tp->tapea;
			}
		}
		++tptr;		/* bump to next tent */
		(dptr++)->d_mode &= ~OK;
	} while (--count);
	if(sum != 0)
		if(flags & (fls|fli)) {
			printf("Directory checksum\n");
			if ((flags & fli) == 0)		done();
		} else {
			flags |= fls;
			rddir();
			printf("Warning: swabbing required\n");
			return(0);
		}
	bitmap();
	return(0);
}


int
wrdir()
{
	register struct tent *tp;
	register struct dent *dp;
	struct dent *dptr;
	int	count, i;
	short	reg, *sp;

	wseek(0);
	if (flags & flm)
		reg = open(mheader,0);
	else	reg = open(theader,0);
	if (reg >= 0) {
		read(reg,(char *)tapeb,BSIZE);
		close(reg);
		if(flags & fls)
			swab((char *)&ndirent, (char *)&tpentry[TPB-1].cksum, sizeof(ndirent));
		else
			tpentry[TPB-1].cksum = ndirent;
	}
	dptr = &dir[0];
	count = ndirent;
	for (;;) {
		twrite();
		if (count == 0)  return(0);
		tp = &tpentry[0];
		do {
			dp = dptr++;	/* dptr set to next entry */
			if (dp->d_namep)  {
				decode(tp->pathnam,dp);
				tp->mode = dp->d_mode;
				tp->uid = dp->d_uid;
				tp->gid = dp->d_gid;
				tp->time = dp->d_time;
				tp->size0 = dp->d_size >> 16;
				tp->size1 = dp->d_size;
				tp->tapea = dp->d_tapea;
				if(flags & fls) {
					swabdir(tp);
					swab((char *)tp, (char *)tp, sizeof(*tp));
				}
				reg = 0;
				sp = (short *)tp;
				for(i=0;i<(int)(sizeof(struct tent)/sizeof(short))-1;i++)
					reg -= *sp++;
				*sp = reg;
				if(flags & fls)
					swab((char *)tp, (char *)tp, sizeof(*tp));
			} else {
				sp = (short *)tp;
				for(i=0;i<(int)(sizeof(struct tent)/sizeof(short));i++)
					*sp++ = 0;
			}
		tp++;
		} while (--count % TPB);
	}
}

int
tread()
{
	register int j, *ptr;

	if (read(fio,(char *)tapeb,BSIZE) != BSIZE) {
		printf("Tape read error\n");
		if ((flags & fli) == 0)		done();
		ptr = (int *)tapeb;
		j = BSIZE/sizeof(int);
		while(j--) *ptr++ = 0;
	}
	rseeka++;
	return(0);
}

int
twrite()
{
	if (write(fio, (char *)tapeb,BSIZE) != BSIZE) {
		printf("Tape write error\n");
		done();
	}
	++wseeka;
	return(0);
}

int
rseek(blk)
int blk;
{
	rseeka = blk;
	if (lseek(fio,(long)blk*BSIZE,0) < 0)	seekerr();
	return(0);
}

int
wseek(blk)
int blk;
{
	register int amt, b;

	amt = b = blk;
	if ((amt -= wseeka) < 0)	amt = -amt;
	if (amt > 25 && b) {
		lseek(fio, (long)(b-1)*BSIZE, 0);	/* seek previous block */
		read(fio, (char *)&wseeka, 1);  /* read next block */
	}
	wseeka = b;
	if (lseek(fio, (long)b*BSIZE, 0) < 0)	seekerr();
	return(0);
}

int
seekerr()
{
	printf("Tape seek error\n");
	done();
	return(0);
}

int
verify(key)
int key;
{
	register int c;

	if ((flags & (flw | flv)) == 0)
		return(0);
repeat:	printf("%c %s ", key, name);
	if ((flags & flw) == 0) {
		printf("\n");
		return(0);
	}
	c = getchar();
	if (c == 'n' && getchar() == '\n')
		done();
	if (c == '\n')
		return(-1);
	if (c == 'y' && getchar() == '\n')
		return(0);
	while (getchar() != '\n');
	goto repeat;
}

int
getfiles()
{

	if ((narg -= 2) == 0) {
		strcpy(name, ".");
		callout();
	} else while (--narg >= 0) {
		strcpy(name, *parg++);
		callout();
	}
	return(0);
}


int
expand()
{
	register  char *p0, *save0;
	int n, fid;

	if ((fid = open(name,0)) < 0)		fserr();
	for (;;) {
		if ((n = read(fid, (char *)&direct, sizeof(direct))) != sizeof(direct)) {
			if (n == 0) {
				close(fid);
				return(0);
			}
			fserr();
		}
		if (direct.d_ino == 0)	/* null entry */
			continue;
		p0 = name;
		if (direct.d_name[0] == '.')		/* don't save .xxxx */
			continue;
		while (*p0++);
		save0 = --p0;		/* save loc of \0 */
		if (p0[-1] != '/')
			*p0++ = '/';
		strcpy(p0, direct.d_name);
			callout();
		*save0 = 0;		/* restore */
	}
}

int
fserr()
{
	printf("%s -- Cannot open file\n", name);
	done();
	return(0);
}

int
callout()
{
	register struct dent *d;
	register char *ptr1, *ptr0;
	struct dent *empty;
	int mode;

	if (stat(name,&statb) < 0)	fserr();
	mode = statb.st_mode;
	if ((mode &= S_IFMT) != 0) {
		if (mode == S_IFDIR)  /* directory */
			expand();
		if(mode != S_IFREG) return(0);
	}
	/* when we reach here we have recursed until we found 
	 * an ordinary file.  Now we look for it in "dir".
	 */
	empty = 0;
	d = &dir[0];
	do  {
		if (d->d_namep == 0) {	/* empty directory slot */
			if (empty == 0) /* remember the first one */
				empty = d;
			continue;
		}
		decode(name1,d);
		ptr0 = name;
		ptr1 = name1;
		do	if (*ptr0++ != *ptr1)   goto cont;
		    while (*ptr1++);
		/* veritably the same name */
		if (flags & flu) {  /* check the times */
			if (d->d_time >= statb.st_mtime)
				return(0);
		}
		if (verify('r') < 0)	return(0);
		goto copydir;
cont:		continue;
	}  while (++d <= lastd);
	/* name not found in directory */
	if ((d = empty) == 0) {
		d = lastd +1;
		if (d >= edir) {
			printf("Directory overflow\n");
			done();
		}
	}
	if (verify('a') < 0)		return(0);
	if (d > lastd)		lastd = d;
	encode(name,d);
copydir:
	d->d_mode = statb.st_mode | OK;
	d->d_uid = statb.st_uid;
	d->d_gid = statb.st_gid;
	d->d_size = statb.st_size;
	d->d_time = statb.st_mtime;
	return(0);
}

int
swabdir(tp)
register struct tent *tp;
{
	swab((char *)tp, (char *)tp, sizeof(*tp));
	swab(tp->pathnam, tp->pathnam, NAMELEN);
	swab((char *)&tp->uid, (char *)&tp->uid, 4); /* uid,gid,spare,size0 */
	return(0);
}
