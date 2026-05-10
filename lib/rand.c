/* Ported from v7/usr/src/libc/gen/rand.c.
 * K&R prototype -> C99 prototype, void return on srand,
 * explicit `int` for the seed-state and rand return type. */

static long randx = 1;

void
srand(unsigned int x)
{
	randx = x;
}

int
rand(void)
{
	return(((randx = randx*1103515245 + 12345) >> 16) & 077777);
}
