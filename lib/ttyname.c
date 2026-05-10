/*
 * ttyname(f): return "/dev/ttyXX" which the the name of the
 * tty belonging to file f.  NULL if it is not a tty.
 *
 * Ported from v7/usr/src/libc/gen/ttyname.c.  K&R prototype -> C99,
 * register dropped, void casts on close().  Algorithm preserved
 * (read /dev directory entries, fstat each candidate, match
 * (st_dev, st_ino) against fsb).  In this port the rootfs has no
 * /dev directory yet, so ttyname will return NULL until /dev is
 * populated -- the source still ports faithfully.
 */

#define	NULL	0
#include <sys/types.h>
#include <sys/dir.h>
#include <sys/stat.h>

extern int isatty(int);
extern int fstat(int, struct stat *);
extern int stat(char *, struct stat *);
extern int open(char *, int);
extern int close(int);
extern int read(int, char *, int);
extern char *strcpy(char *, char *);
extern char *strcat(char *, char *);

static char dev[] = "/dev/";

char *
ttyname(int f)
{
	struct stat fsb;
	struct stat tsb;
	struct direct db;
	static char rbuf[32];
	int df;

	if(isatty(f) == 0)
		return(NULL);
	if(fstat(f, &fsb) < 0)
		return(NULL);
	if((fsb.st_mode & S_IFMT) != S_IFCHR)
		return(NULL);
	if((df = open(dev, 0)) < 0)
		return(NULL);
	while(read(df, (char *)&db, sizeof(db)) == sizeof(db)) {
		if(db.d_ino == 0)
			continue;
		if(db.d_ino != fsb.st_ino)
			continue;
		strcpy(rbuf, dev);
		strcat(rbuf, db.d_name);
		if(stat(rbuf, &tsb) < 0)
			continue;
		if(tsb.st_dev == fsb.st_dev && tsb.st_ino == fsb.st_ino) {
			(void)close(df);
			return(rbuf);
		}
	}
	(void)close(df);
	return(NULL);
}
