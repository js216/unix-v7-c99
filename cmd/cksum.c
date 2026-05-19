/* cksum -- POSIX CRC32 checksum.  Outputs "CRC LEN [FILE]" per file.
 * V7 had `sum(1)` (a different, weaker algorithm); this is the POSIX
 * cksum standard.  Uses the standard polynomial 0x04C11DB7. */

#include <stdio.h>

static unsigned long crctab[256];
static int crc_inited;

static void
crc_init(void)
{
	unsigned long c;
	int i, k;
	for (i = 0; i < 256; i++) {
		c = (unsigned long)(i & 0xff) << 24;
		for (k = 0; k < 8; k++)
			c = (c & 0x80000000UL) ? (c << 1) ^ 0x04C11DB7UL : c << 1;
		crctab[i] = c & 0xFFFFFFFFUL;
	}
	crc_inited = 1;
}

static unsigned long
crc_buf(unsigned long crc, unsigned char *buf, int n)
{
	int i;
	for (i = 0; i < n; i++)
		crc = (crc << 8) ^ crctab[((crc >> 24) ^ buf[i]) & 0xff];
	return crc & 0xFFFFFFFFUL;
}

static unsigned long
crc_finish(unsigned long crc, unsigned long length)
{
	unsigned char tmp[8];
	int n = 0;
	unsigned long l = length;
	while (l) { tmp[n++] = l & 0xff; l >>= 8; }
	if (n == 0) { tmp[n++] = 0; }
	crc = crc_buf(crc, tmp, n);
	return ~crc & 0xFFFFFFFFUL;
}

static int
process(FILE *fp, char *name)
{
	unsigned char buf[1024];
	unsigned long crc = 0, length = 0;
	int n;
	while ((n = fread((char *)buf, 1, sizeof(buf), fp)) > 0) {
		crc = crc_buf(crc, buf, n);
		length += (unsigned long)n;
	}
	crc = crc_finish(crc, length);
	if (name)
		printf("%lu %lu %s\n", crc, length, name);
	else
		printf("%lu %lu\n", crc, length);
	return 0;
}

int
main(int argc, char *argv[])
{
	int i, rc = 0;
	FILE *fp;
	crc_init();
	if (argc < 2) {
		process(stdin, (char *)0);
		exit(0);
	}
	for (i = 1; i < argc; i++) {
		if ((fp = fopen(argv[i], "r")) == NULL) {
			fprintf(stderr, "cksum: %s: cannot open\n", argv[i]);
			rc = 1;
			continue;
		}
		process(fp, argv[i]);
		fclose(fp);
	}
	exit(rc);
}
