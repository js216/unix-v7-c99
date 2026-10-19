/*
 * Put the STM32MP1 boot ROM's header, version 2, on a kernel:
 * mkstm32 unix.bin unix.stm32. It loads and enters at SYSRAM.
 */
#include <stdio.h>
#include <string.h>

#define	SYSRAM	0x2ffe0000UL
#define	MAXIMG	(128*1024L - 512)

unsigned char	hdr[512], img[MAXIMG+1];

static void
put4(unsigned char *p, unsigned long v)
{
	p[0] = v;
	p[1] = v >> 8;
	p[2] = v >> 16;
	p[3] = v >> 24;
}

int
main(int argc, char **argv)
{
	FILE *f;
	long n, i;
	unsigned long sum;

	if (argc != 3) {
		fprintf(stderr, "usage: mkstm32 image header+image\n");
		return 1;
	}
	if ((f = fopen(argv[1], "rb")) == NULL) {
		perror(argv[1]);
		return 1;
	}
	n = fread(img, 1, sizeof img, f);
	fclose(f);
	if (n > MAXIMG) {
		fprintf(stderr, "mkstm32: %s too big for SYSRAM\n",
		    argv[1]);
		return 1;
	}
	sum = 0;
	for (i = 0; i < n; i++)
		sum += img[i];
	memcpy(hdr, "STM2", 4);
	put4(hdr+68, sum);
	hdr[74] = 2;
	put4(hdr+76, n);
	put4(hdr+80, SYSRAM);
	put4(hdr+88, SYSRAM);
	put4(hdr+100, 1UL << 31);
	put4(hdr+104, 512 - 128);
	memcpy(hdr+128, "ST\377\377", 4);
	put4(hdr+132, 512 - 128);
	if ((f = fopen(argv[2], "wb")) == NULL) {
		perror(argv[2]);
		return 1;
	}
	if (fwrite(hdr, 1, 512, f) != 512 ||
	    fwrite(img, 1, n, f) != (size_t)n || fclose(f)) {
		perror(argv[2]);
		return 1;
	}
	return 0;
}
