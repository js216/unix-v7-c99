/* Ported from v7/usr/src/libc/gen/abs.c.
 * K&R proto -> C99 with explicit `int` (v7 relied on default-int). */

int
abs(int arg)
{

	if(arg < 0)
		arg = -arg;
	return(arg);
}
