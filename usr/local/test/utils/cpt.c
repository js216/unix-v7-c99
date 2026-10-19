#include <stdio.h>
#include <sys/types.h>

struct {
	short	h_magic, h_dev, h_ino, h_mode, h_uid, h_gid, h_nlink,
	    h_rdev;
	unsigned short	h_mtime[4];
	short	h_namesize;
	short	h_filesize[2];
	char	h_name[256];
} hdr;

int
main(int argc, char **argv)
{
	FILE *f;
	unsigned long long u;
	time_t t;
	int i;

	if (argc < 2 || (f = fopen(argv[1], "r")) == NULL)
		return 1;
	if (fread((char *)&hdr, 30, 1, f) != 1 || hdr.h_magic != 070707)
		return 1;
	fread(hdr.h_name, hdr.h_namesize, 1, f);
	u = 0;
	for (i = 0; i < 4; i++)
		u = u << 16 | hdr.h_mtime[i];
	t = u;
	printf("%s %lld %s", hdr.h_name, t, ctime(&t));
	return 0;
}
