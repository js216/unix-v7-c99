#include "../h/param.h"

#include <stdio.h>


/*
 * Prototypes for the V7 allocator
 * (do NOT include <stdlib.h>)
 */
int  malloc(struct map *mp, int size);
void mfree(struct map *mp, int size, int addr);

/*
 * Simple test map:
 * one free region starting at address 1000
 * size is in allocation units
 */
static struct map testmap[] = {
	{ 100, 1000 },
	{   0,    0 }
};

static void dump_map(const char *msg)
{
	struct map *m;

	printf("%s\n", msg);
	for (m = testmap; m->m_size != 0; m++) {
		printf("  addr=%u size=%u\n",
		       m->m_addr, m->m_size);
	}
}

int main(void)
{
	int a, b;

	dump_map("initial map:");

	a = malloc(testmap, 10);
	printf("allocated a=%d (size 10)\n", a);
	dump_map("after first alloc:");

	b = malloc(testmap, 20);
	printf("allocated b=%d (size 20)\n", b);
	dump_map("after second alloc:");

	mfree(testmap, 10, a);
	printf("freed a\n");
	dump_map("after freeing a:");

	mfree(testmap, 20, b);
	printf("freed b\n");
	dump_map("after freeing b (should coalesce):");

	return 0;
}
