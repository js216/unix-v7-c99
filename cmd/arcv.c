/*
 * Convert old to new archive format
 */

#include <signal.h>
#include <stdio.h>
#include <ar.h>

#define	OMAG	0177555

struct oar_hdr {
	char	oname[8];
	char	odate[4];
	char	ouid;
	char	omode;
	char	osize[2];
};

static char	*tmp;
static int	f;
static int	tf;
static union {
	char	buf[512];
	char	magic[2];
} b;

static unsigned short
getshort(char *p)
{
	return ((unsigned short)(unsigned char)p[0]) |
	    ((unsigned short)(unsigned char)p[1] << 8);
}

static void
putshort(char *p, unsigned short v)
{
	p[0] = v & 0377;
	p[1] = (v >> 8) & 0377;
}

static void
putlong(char *p, char *v)
{
	p[0] = v[0];
	p[1] = v[1];
	p[2] = v[2];
	p[3] = v[3];
}

static void
putarhdr(char *p, struct oar_hdr *oh)
{
	int i;

	for(i = 0; i < 8; i++)
		p[i] = oh->oname[i];
	for(; i < 14; i++)
		p[i] = 0;
	putlong(&p[14], oh->odate);
	p[18] = oh->ouid;
	p[19] = 1;
	putshort(&p[20], 0666);
	putshort(&p[22], getshort(oh->osize));
	putshort(&p[24], 0);
}

static void
conv(char *fil)
{
	unsigned int i, n;
	struct oar_hdr oh;
	char nh[26];

	f = open(fil, 2);
	if(f < 0) {
		printf("arcv: cannot open %s\n", fil);
		return;
	}
	close(creat(tmp, 0600));
	tf = open(tmp, 2);
	if(tf < 0) {
		printf("arcv: cannot open temp\n");
		close(f);
		return;
	}
	b.magic[0] = 0;
	b.magic[1] = 0;
	read(f, b.magic, sizeof(b.magic));
	if(getshort(b.magic) != OMAG) {
		printf("arcv: %s not archive format\n", fil);
		close(tf);
		close(f);
		return;
	}
	putshort(b.magic, ARMAG);
	write(tf, b.magic, sizeof(b.magic));
loop:
	i = read(f, (char *)&oh, sizeof(oh));
	if(i != sizeof(oh))
		goto out;
	putarhdr(nh, &oh);
	n = (getshort(oh.osize)+1) & ~01;
	write(tf, nh, sizeof(nh));
	while(n > 0) {
		i = 512;
		if(n < i)
			i = n;
		read(f, b.buf, i);
		write(tf, b.buf, i);
		n -= i;
	}
	goto loop;
out:
	lseek(f, 0L, 0);
	lseek(tf, 0L, 0);
	while((i = read(tf, b.buf, 512)) > 0)
		write(f, b.buf, i);
	close(f);
	close(tf);
}

int
main(int argc, char **argv)
{
	int i;
	char tbuf[] = "/tmp/arcXXXXX";

	tmp = mktemp(tbuf);
	for(i = 1; i < 4; i++)
		signal(i, SIG_IGN);
	for(i = 1; i < argc; i++)
		conv(argv[i]);
	unlink(tmp);
	return 0;
}
