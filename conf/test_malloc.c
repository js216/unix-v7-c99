#include "../h/map.h"
#include "../h/param.h"

void printf(char *fmt, ...);

static struct map testmap[] = {
     /* {size, addr} */
	{ 13, 27 },
	{ 15, 47 },
	{  7, 65 },
};

static void dump_map(const char *msg)
{
	struct map *m;

	printf("%s\n", msg);
	printf("  Entry\tSize\tAddress\n");
	int i=0;
	for (m = testmap; ; m++) {
		if (m->m_size == 0) {

		printf("  %u\t%u\t??\n",
		       i++, m->m_size);
		   break;
		} else {
		printf("  %u\t%u\t%u\n",
		       i++, m->m_size, m->m_addr);
		}
	}
}

int main(void)
{
	dump_map("Initial map:");

	int a = malloc(testmap, 7);
	printf("\nallocated a=%d (size 7)\n", a);
	dump_map("after first alloc:");

	mfree(testmap, 7, 40);
	printf("\nfreed 7 units at addr=40\n");
	dump_map("after freeing:");

	return 0;
}
