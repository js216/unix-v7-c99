#include <dirent.h>
#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

#define	BSIZE	512
#define	DIRSIZ	14
#define	DIRENT	16
#define	NADDR	13
#define	NICFREE	50
#define	NICINOD	100
#define	IFDIR	0040000
#define	IFREG	0100000
#define	ROOTINO	2
#define	FSSIZE	4096
#define	ISIZE	16
#define	MAXINO	128
#define	MAXBLK	4096

struct node {
	char path[128];
	char host[256];
	int ino;
	int mode;
	int size;
	int blocks[MAXBLK];
	int nblock;
};

static unsigned char image[FSSIZE][BSIZE];
static struct node nodes[MAXINO];
static int nnodes;
static int nextino = ROOTINO;
static int nextblk = 2 + ISIZE;

static void
put16(unsigned char *p, unsigned int v)
{

	p[0] = v & 0377;
	p[1] = (v >> 8) & 0377;
}

static void
put32(unsigned char *p, unsigned int v)
{

	p[0] = v & 0377;
	p[1] = (v >> 8) & 0377;
	p[2] = (v >> 16) & 0377;
	p[3] = (v >> 24) & 0377;
}

static void
put24(unsigned char *p, unsigned int v)
{

	p[0] = v & 0377;
	p[1] = (v >> 8) & 0377;
	p[2] = (v >> 16) & 0377;
}

static struct node *
find(char *path)
{
	int i;

	for(i=0; i<nnodes; i++)
		if(strcmp(nodes[i].path, path) == 0)
			return(&nodes[i]);
	return(NULL);
}

static struct node *
addnode(char *path, int mode)
{
	struct node *np;

	np = find(path);
	if(np != NULL)
		return(np);
	if(nnodes >= MAXINO)
		exit(2);
	np = &nodes[nnodes++];
	memset(np, 0, sizeof(*np));
	(void)snprintf(np->path, sizeof(np->path), "%s", path);
	np->ino = nextino++;
	np->mode = mode;
	return(np);
}

static void
parent(char *path, char *buf)
{
	char *p;

	(void)snprintf(buf, 128, "%s", path);
	p = strrchr(buf, '/');
	if(p == buf)
		p[1] = 0;
	else if(p != NULL)
		*p = 0;
}

static char *
base(char *path)
{
	char *p;

	p = strrchr(path, '/');
	return(p == NULL ? path : p+1);
}

static void
mkdirs(char *path)
{
	char tmp[128];
	char *p;

	(void)snprintf(tmp, sizeof(tmp), "%s", path);
	for(p=tmp+1; *p; p++)
		if(*p == '/') {
			*p = 0;
			(void)addnode(tmp, IFDIR | 0755);
			*p = '/';
		}
}

static void
addfile(char *path, char *host)
{
	struct node *np;

	mkdirs(path);
	np = addnode(path, IFREG | 0755);
	(void)snprintf(np->host, sizeof(np->host), "%s", host);
}

static void
allocblock(struct node *np, unsigned char *data, int n)
{

	if(np->nblock >= MAXBLK || nextblk >= MAXBLK)
		exit(3);
	np->blocks[np->nblock++] = nextblk;
	memcpy(image[nextblk], data, n);
	nextblk++;
}

static void
loadfiles(void)
{
	FILE *fp;
	unsigned char buf[BSIZE];
	int i, n;

	for(i=0; i<nnodes; i++) {
		if((nodes[i].mode & IFREG) == 0)
			continue;
		fp = fopen(nodes[i].host, "rb");
		if(fp == NULL) {
			perror(nodes[i].host);
			exit(1);
		}
		while((n = (int)fread(buf, 1, sizeof(buf), fp)) > 0) {
			allocblock(&nodes[i], buf, n);
			nodes[i].size += n;
			memset(buf, 0, sizeof(buf));
		}
		(void)fclose(fp);
	}
}

static void
dirent(unsigned char *p, int ino, char *name)
{

	memset(p, 0, DIRENT);
	put16(p, (unsigned int)ino);
	(void)strncpy((char *)p+2, name, DIRSIZ);
}

static void
makedirs(void)
{
	struct node *dp;
	unsigned char buf[BSIZE];
	char par[128];
	int i, off;

	for(i=0; i<nnodes; i++) {
		dp = &nodes[i];
		if((dp->mode & IFDIR) == 0)
			continue;
		memset(buf, 0, sizeof(buf));
		off = 0;
		dirent(&buf[off], dp->ino, ".");
		off += DIRENT;
		parent(dp->path, par);
		dirent(&buf[off], find(par)->ino, "..");
		off += DIRENT;
		for(int j=0; j<nnodes; j++) {
			parent(nodes[j].path, par);
			if(strcmp(par, dp->path) == 0 && strcmp(nodes[j].path, dp->path) != 0) {
				if(off + DIRENT > BSIZE) {
					allocblock(dp, buf, BSIZE);
					memset(buf, 0, sizeof(buf));
					off = 0;
				}
				dirent(&buf[off], nodes[j].ino, base(nodes[j].path));
				off += DIRENT;
			}
		}
		dp->size = off;
		if(dp->nblock)
			dp->size += (dp->nblock * BSIZE);
		allocblock(dp, buf, BSIZE);
	}
}

static void
writeinode(struct node *np)
{
	unsigned char *p;
	int i, b, o, ib, dib, n;

	b = (np->ino + 15) / 8;
	o = ((np->ino + 15) & 7) * 64;
	p = &image[b][o];
	put16(p+0, (unsigned int)np->mode);
	put16(p+2, 1);
	put16(p+4, 0);
	put16(p+6, 0);
	put32(p+8, (unsigned int)np->size);
	for(i=0; i<np->nblock && i<NADDR-3; i++)
		put24(p+12+i*3, (unsigned int)np->blocks[i]);
	if(np->nblock > NADDR-3) {
		if(nextblk >= MAXBLK)
			exit(3);
		ib = nextblk++;
		put24(p+12+(NADDR-3)*3, (unsigned int)ib);
		for(i=NADDR-3; i<np->nblock && i<NADDR-3+128; i++)
			put32(&image[ib][(i-(NADDR-3))*4], (unsigned int)np->blocks[i]);
	}
	if(np->nblock > NADDR-3+128) {
		if(nextblk >= MAXBLK)
			exit(3);
		dib = nextblk++;
		put24(p+12+(NADDR-2)*3, (unsigned int)dib);
		for(i=NADDR-3+128; i<np->nblock; i++) {
			n = i - (NADDR-3+128);
			if(n % 128 == 0) {
				if(nextblk >= MAXBLK)
					exit(3);
				ib = nextblk++;
				put32(&image[dib][(n/128)*4], (unsigned int)ib);
			}
			put32(&image[ib][(n%128)*4], (unsigned int)np->blocks[i]);
		}
	}
}

static void
super(void)
{
	unsigned char *p;

	p = image[1];
	put16(p+0, ISIZE);
	put32(p+2, FSSIZE);
	put16(p+6, 0);
	put16(p+6+4*NICFREE, 0);
	put32(p+6+4*NICFREE+2+4*NICINOD+4, 1);
}

int
main(int argc, char **argv)
{
	FILE *fp;
	int i;
	char *eq;

	if(argc < 3) {
		(void)fprintf(stderr, "usage: mkfs image path=file ...\n");
		return(1);
	}
	memset(image, 0, sizeof(image));
	addnode("/", IFDIR | 0755);
	for(i=2; i<argc; i++) {
		eq = strchr(argv[i], '=');
		if(eq == NULL)
			return(1);
		*eq++ = 0;
		addfile(argv[i], eq);
	}
	loadfiles();
	makedirs();
	for(i=0; i<nnodes; i++)
		writeinode(&nodes[i]);
	super();
	fp = fopen(argv[1], "wb");
	if(fp == NULL) {
		perror(argv[1]);
		return(1);
	}
	(void)fwrite(image, sizeof(image), 1, fp);
	(void)fclose(fp);
	return(0);
}
