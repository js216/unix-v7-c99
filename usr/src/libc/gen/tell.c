/*
 * return offset in file.
 */

#include <stdio.h>

long tell(int f)
{
	return(lseek(f, 0L, 1));
}
