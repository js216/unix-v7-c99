#include <stdio.h>
#include <a.out.h>

struct nlist nl[] = {
	{ "_swplo", 0, 0 },
	{ "_nswap", 0, 0 },
	{ "", 0, 0 },
};

int
main(void)
{
	long swplo;
	int k, nswap;

	nlist("/unix", nl);
	k = open("/dev/kmem", 0);
	lseek(k, (long)nl[0].n_value, 0);
	read(k, (char *)&swplo, sizeof(swplo));
	lseek(k, (long)nl[1].n_value, 0);
	read(k, (char *)&nswap, sizeof(nswap));
	printf("%ld %ld\n", swplo+1, swplo+1+nswap);
	return 0;
}
