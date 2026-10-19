#include <stdio.h>

int eh[13], sh[10];
char a[512], b[512];

int
main(void)
{
	int u, k, i, n, size;

	u = open("/unix", 0);
	k = open("/dev/kmem", 0);
	read(u, (char *)eh, sizeof eh);
	for (i = 0; i < (eh[12] & 0xffff); i++) {
		lseek(u, (long)eh[8] + i * (eh[11] >> 16 & 0xffff), 0);
		read(u, (char *)sh, sizeof sh);
		if (sh[2] & 4)
			break;
	}
	size = sh[5];
	for (n = 0; n < size; n += 512) {
		lseek(u, (long)sh[4] + n, 0);
		lseek(k, (long)sh[3] + n, 0);
		i = size - n < 512 ? size - n : 512;
		if (read(u, a, i) != i || read(k, b, i) != i)
			break;
		while (--i >= 0 && a[i] == b[i])
			;
		if (i >= 0)
			break;
	}
	printf("kernel text %s /unix\n",
	    n >= size && size > 0 ? "is" : "is not");
	return 0;
}
